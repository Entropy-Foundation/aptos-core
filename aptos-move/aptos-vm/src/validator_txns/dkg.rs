// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    aptos_vm::get_or_vm_startup_failure,
    errors::expect_only_successful_execution,
    move_vm_ext::{AptosMoveResolver, SessionId},
    system_module_names::{FINISH_WITH_DKG_RESULT, RECONFIGURATION_WITH_DKG_MODULE, SET_DKG_META},
    AptosVM, VMValidator,
};
use aptos_types::{
    dkg::transactions::{DKGTransactionData, DKGTransactionType},
    fee_statement::FeeStatement,
    move_utils::as_move_value::AsMoveValue,
    transaction::{ExecutionStatus, TransactionStatus},
    vm_status::DiscardedVMStatus,
};
use aptos_vm_logging::log_schema::AdapterLogSchema;
use aptos_vm_types::output::VMOutput;
use move_core_types::{
    account_address::AccountAddress,
    value::{serialize_values, MoveValue},
    vm_status::VMStatus,
};
use move_vm_runtime::module_traversal::{TraversalContext, TraversalStorage};
use move_vm_types::gas::UnmeteredGasMeter;

enum ExecutionFailure {
    Expected(DiscardedVMStatus),
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
        match self.process_dkg_transaction_inner(
            resolver,
            log_context,
            session_id,
            dkg_transaction_data,
        ) {
            Ok((vm_status, vm_output)) => Ok((vm_status, vm_output)),
            Err(ExecutionFailure::Expected(status)) => {
                // Pretend we are inside Move, and expected failures are like Move aborts.
                Ok((
                    VMStatus::error(status, None),
                    VMOutput::empty_with_status(TransactionStatus::Discard(status)),
                ))
            },
            Err(ExecutionFailure::Unexpected(vm_status)) => Err(vm_status),
        }
    }

    fn process_dkg_transaction_inner(
        &self,
        resolver: &impl AptosMoveResolver,
        log_context: &AdapterLogSchema,
        session_id: SessionId,
        dkg_transaction: DKGTransactionData,
    ) -> Result<(VMStatus, VMOutput), ExecutionFailure> {
        // Verify the dkg transaction before execution
        if let Some(status) = self
            .validate_dkg_validator_transaction(dkg_transaction.clone(), resolver)
            .status()
        {
            return Err(ExecutionFailure::Expected(status));
        }

        let (function_name, args) = match dkg_transaction.metadata().transaction_type() {
            DKGTransactionType::DKGMeta => (SET_DKG_META, vec![dkg_transaction
                .data_bytes()
                .as_move_value()]),
            DKGTransactionType::PublicKeyShares => (FINISH_WITH_DKG_RESULT, vec![
                MoveValue::Signer(AccountAddress::ONE),
                dkg_transaction.data_bytes().as_move_value(),
            ]),
        };

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
            .map_err(|e| expect_only_successful_execution(e, function_name.as_str(), log_context))
            .map_err(|r| ExecutionFailure::Unexpected(r.unwrap_err()))?;

        let output = crate::aptos_vm::get_system_transaction_output(
            session,
            FeeStatement::zero(),
            ExecutionStatus::Success,
            &get_or_vm_startup_failure(&self.storage_gas_params, log_context)
                .map_err(ExecutionFailure::Unexpected)?
                .change_set_configs,
        )
        .map_err(ExecutionFailure::Unexpected)?;

        Ok((VMStatus::Executed, output))
    }
}
