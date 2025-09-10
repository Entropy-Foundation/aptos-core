// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    aptos_vm::get_or_vm_startup_failure,
    errors::expect_only_successful_execution,
    move_vm_ext::{AptosMoveResolver, SessionId},
    system_module_names::{FINISH_WITH_DKG_RESULT, RECONFIGURATION_WITH_DKG_MODULE},
    validator_txns::dkg::{
        ExecutionFailure::{Expected, Unexpected},
        ExpectedFailure::*,
    },
    AptosVM,
};
use aptos_types::{
    dkg::{DKGState, DKGTransactionData},
    fee_statement::FeeStatement,
    move_utils::as_move_value::AsMoveValue,
    on_chain_config::{ConfigurationResource, OnChainConfig},
    transaction::{ExecutionStatus, TransactionStatus},
};
use aptos_types::dkg::DKGTransactionType;
use aptos_vm_logging::log_schema::AdapterLogSchema;
use aptos_vm_types::output::VMOutput;
use move_core_types::{
    account_address::AccountAddress,
    value::{serialize_values, MoveValue},
    vm_status::{AbortLocation, StatusCode, VMStatus},
};
use move_vm_runtime::module_traversal::{TraversalContext, TraversalStorage};
use move_vm_types::gas::UnmeteredGasMeter;
use crate::system_module_names::SET_DKG_META;

#[derive(Debug)]
enum ExpectedFailure {
    // Move equivalent: `errors::invalid_argument(*)`
    EpochNotCurrent = 0x10001,
    DKGMetaVerificationFailed = 0x10002,
    DKGMetaAlreadySet = 0x10003,
    DKGMetaNotSet = 0x10004,

    // Move equivalent: `errors::invalid_state(*)`
    MissingResourceDKGState = 0x30001,
    MissingResourceInprogressDKGSession = 0x30002,
    MissingResourceConfiguration = 0x30003,
}

enum ExecutionFailure {
    Expected(ExpectedFailure),
    Unexpected(VMStatus),
}

impl AptosVM {
    pub(crate) fn process_dkg_transaction(
        &self,
        resolver: &impl AptosMoveResolver,
        log_context: &AdapterLogSchema,
        session_id: SessionId,
        dkg_transaction_data: DKGTransactionData,
    ) -> Result<(VMStatus, VMOutput), VMStatus> {
        match self.process_dkg_transaction_inner(resolver, log_context, session_id, dkg_transaction_data) {
            Ok((vm_status, vm_output)) => Ok((vm_status, vm_output)),
            Err(Expected(failure)) => {
                // Pretend we are inside Move, and expected failures are like Move aborts.
                Ok((
                    VMStatus::MoveAbort(AbortLocation::Script, failure as u64),
                    VMOutput::empty_with_status(TransactionStatus::Discard(StatusCode::ABORTED)),
                ))
            },
            Err(Unexpected(vm_status)) => Err(vm_status),
        }
    }

    fn process_dkg_transaction_inner(
        &self,
        resolver: &impl AptosMoveResolver,
        log_context: &AdapterLogSchema,
        session_id: SessionId,
        dkg_transaction: DKGTransactionData,
    ) -> Result<(VMStatus, VMOutput), ExecutionFailure> {
        let dkg_state = OnChainConfig::fetch_config(resolver)
            .ok_or_else(|| Expected(MissingResourceDKGState))?;
        let config_resource = ConfigurationResource::fetch_config(resolver)
            .ok_or_else(|| Expected(MissingResourceConfiguration))?;
        let DKGState { in_progress, .. } = dkg_state;
        let in_progress_session_state =
            in_progress.ok_or_else(|| Expected(MissingResourceInprogressDKGSession))?;

        // Check epoch number.
        if dkg_transaction.metadata.epoch != config_resource.epoch() {
            return Err(Expected(EpochNotCurrent));
        }

        match dkg_transaction.metadata.transaction_type {
            DKGTransactionType::DKGMeta => {
                // dkg meta should not be already set
                if in_progress_session_state.dkg_meta_transcript.len() != 0{
                    return Err(Expected(DKGMetaAlreadySet));
                }
            }
            DKGTransactionType::PublicKeyShares => {
                // dkg meta should be already set
                if in_progress_session_state.dkg_meta_transcript.len() == 0{
                    return Err(Expected(DKGMetaNotSet));
                }
            }
        }

        // verify transaction multi-signature
        dkg_transaction.verify_transaction(&in_progress_session_state.metadata.dealer_committee, &in_progress_session_state.metadata.randomness_seed)
            .map_err(|_| Expected(DKGMetaVerificationFailed))?;

        let function_name;
        let args;

        match dkg_transaction.metadata.transaction_type {
            DKGTransactionType::DKGMeta => {
                function_name = SET_DKG_META;
                args = vec![
                    dkg_transaction.data_bytes.as_move_value(),
                ];
            }
            DKGTransactionType::PublicKeyShares => {
                function_name = FINISH_WITH_DKG_RESULT;
                args = vec![
                    MoveValue::Signer(AccountAddress::ONE),
                    dkg_transaction.data_bytes.as_move_value(),
                ];
            }
        }

        // All check passed, invoke VM to publish DKG result on chain.
        let mut gas_meter = UnmeteredGasMeter;
        let mut session = self.new_session(resolver, session_id, None);

        let module_storage = TraversalStorage::new();
        session
            .execute_function_bypass_visibility(
                &RECONFIGURATION_WITH_DKG_MODULE,
                function_name,
                vec![],
                serialize_values(&args),
                &mut gas_meter,
                &mut TraversalContext::new(&module_storage),
            )
            .map_err(|e| {
                expect_only_successful_execution(e, function_name.as_str(), log_context)
            })
            .map_err(|r| Unexpected(r.unwrap_err()))?;

        let output = crate::aptos_vm::get_system_transaction_output(
            session,
            FeeStatement::zero(),
            ExecutionStatus::Success,
            &get_or_vm_startup_failure(&self.storage_gas_params, log_context)
                .map_err(Unexpected)?
                .change_set_configs,
        )
        .map_err(Unexpected)?;

        Ok((VMStatus::Executed, output))
    }
}
