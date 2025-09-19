// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{aptos_vm::get_or_vm_startup_failure, errors::expect_only_successful_execution, move_vm_ext::{AptosMoveResolver, SessionId}, system_module_names::{FINISH_WITH_DKG_RESULT, RECONFIGURATION_WITH_DKG_MODULE}, AptosVM, VMValidator};
use aptos_types::{
    dkg::DKGTransactionData,
    fee_statement::FeeStatement,
    move_utils::as_move_value::AsMoveValue,
    transaction::ExecutionStatus,
};
use aptos_types::dkg::DKGTransactionType;
use aptos_types::validator_txn::ValidatorTransaction;
use aptos_vm_logging::log_schema::AdapterLogSchema;
use aptos_vm_types::output::VMOutput;
use move_core_types::{
    account_address::AccountAddress,
    value::{serialize_values, MoveValue},
    vm_status:: VMStatus,
};
use move_vm_runtime::module_traversal::{TraversalContext, TraversalStorage};
use move_vm_types::gas::UnmeteredGasMeter;
use crate::system_module_names::SET_DKG_META;

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
            Err(vm_status) => Err(vm_status),
        }
    }

    fn process_dkg_transaction_inner(
        &self,
        resolver: &impl AptosMoveResolver,
        log_context: &AdapterLogSchema,
        session_id: SessionId,
        dkg_transaction: DKGTransactionData,
    ) -> Result<(VMStatus, VMOutput), VMStatus> {

        // Verify the dkg transaction before execution
        if let Some(status) =  self.validate_dkg_validator_transaction(
            ValidatorTransaction::DKG(dkg_transaction.clone()),
            resolver).status(){
            return Err(VMStatus::Error {
                status_code: status,
                sub_status: None,
                message: None,
            });
        }

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
            .map_err(|r| r.unwrap_err())?;

        let output = crate::aptos_vm::get_system_transaction_output(
            session,
            FeeStatement::zero(),
            ExecutionStatus::Success,
            &get_or_vm_startup_failure(&self.storage_gas_params, log_context)?
                .change_set_configs,
        )?;

        Ok((VMStatus::Executed, output))
    }
}
