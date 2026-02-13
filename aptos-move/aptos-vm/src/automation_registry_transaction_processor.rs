// Copyright (c) 2025 Supra.
// SPDX-License-Identifier: Apache-2.0

use crate::aptos_vm::get_system_transaction_output;
use crate::counters::SYSTEM_TRANSACTIONS_EXECUTED;
use crate::errors::discarded_output;
use crate::gas::make_prod_gas_meter;
use crate::move_vm_ext::{AptosMoveResolver, SessionExt, SessionId};
use crate::AptosVM;
use aptos_types::account_config;
use aptos_types::fee_statement::FeeStatement;
use aptos_types::on_chain_config::FeatureFlag;
use aptos_types::transaction::automation::AutomationRegistryRecord;
use aptos_types::transaction::TransactionStatus;
use aptos_vm_logging::log_schema::AdapterLogSchema;
use aptos_vm_types::module_and_script_storage::code_storage::AptosCodeStorage;
use aptos_vm_types::module_write_set::ModuleWriteSet;
use aptos_vm_types::output::VMOutput;
use aptos_vm_types::resolver::BlockSynchronizationKillSwitch;
use aptos_vm_types::storage::change_set_configs::ChangeSetConfigs;
use move_binary_format::errors::VMError;
use move_core_types::vm_status::{StatusCode, VMStatus};
use move_vm_runtime::module_traversal::{TraversalContext, TraversalStorage};
use std::ops::Deref;
use aptos_vm_types::module_and_script_storage::module_storage::AptosModuleStorage;

pub struct AutomationRegistryTransactionProcessor<'m> {
    aptos_vm: &'m AptosVM,
}

impl Deref for AutomationRegistryTransactionProcessor<'_> {
    type Target = AptosVM;

    fn deref(&self) -> &Self::Target {
        self.aptos_vm
    }
}

impl<'m> AutomationRegistryTransactionProcessor<'m> {
    pub(crate) fn new(aptos_vm: &'m AptosVM) -> Self {
        Self { aptos_vm }
    }

    /// Executes an automation registry transaction using the unmetered gas meter as they are
    /// considered as system transactions
    pub fn execute_transaction(
        &self,
        resolver: &impl AptosMoveResolver,
        code_storage: &(impl AptosCodeStorage + BlockSynchronizationKillSwitch),
        action_record: &AutomationRegistryRecord,
        log_context: &AdapterLogSchema,
    ) -> Result<(VMStatus, VMOutput), VMStatus> {
        if !self.features().is_enabled(FeatureFlag::SUPRA_AUTOMATION_V2) {
            return Ok((
                VMStatus::Error {
                    status_code: StatusCode::FEATURE_UNDER_GATING,
                    sub_status: None,
                    message: Some(
                        "The Supra Native Automation cycle is not enabled yet.".to_string(),
                    ),
                },
                discarded_output(StatusCode::FEATURE_UNDER_GATING),
            ));
        }
        let gas_params = self.gas_params(log_context)?.vm.clone();
        let storage_gas_params = self.storage_gas_params(log_context)?;
        let max_gas_amount = gas_params.txn.maximum_number_of_gas_units;
        let mut gas_meter = make_prod_gas_meter(
            self.gas_feature_version(),
            gas_params,
            storage_gas_params.clone(),
            false,
            max_gas_amount,
            code_storage,
        );
        let mut session = self.new_session(
            resolver,
            SessionId::automation_registry_action(action_record),
            None,
        );

        let args = action_record.serialize_args_with_sender(account_config::reserved_vm_address());

        let storage = TraversalStorage::new();
        let result = session
            .execute_function_bypass_visibility(
                action_record.module_id(),
                action_record.function(),
                action_record.ty_args(),
                args,
                &mut gas_meter,
                &mut TraversalContext::new(&storage),
                code_storage,
            )
            .map(|_return_vals| ());
        SYSTEM_TRANSACTIONS_EXECUTED.inc();

        match result {
            Ok(_) => {
                let output = get_system_transaction_output(
                    session,
                    code_storage,
                    &storage_gas_params.change_set_configs,
                )?;
                Ok((VMStatus::Executed, output))
            },
            Err(vm_err) => self.get_transaction_error_output(
                session,
                code_storage,
                &storage_gas_params.change_set_configs,
                vm_err,
            ),
        }
    }

    fn get_transaction_error_output(
        &self,
        session: SessionExt<impl AptosMoveResolver>,
        module_storage: &impl AptosModuleStorage,
        change_set_configs: &ChangeSetConfigs,
        vm_err: VMError,
    ) -> Result<(VMStatus, VMOutput), VMStatus> {
        let vm_status = VMStatus::from(vm_err);
        let txn_status = TransactionStatus::from_vm_status(vm_status.clone(), self.features());

        let change_set = session.finish(change_set_configs, module_storage)?;

        let output = VMOutput::new(
            change_set,
            ModuleWriteSet::empty(),
            FeeStatement::zero(),
            txn_status,
        );
        Ok((vm_status, output))
    }
}
