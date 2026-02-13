// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

// Copyright (c) 2024 Supra.
// SPDX-License-Identifier: Apache-2.0

use crate::aptos_vm::{unwrap_or_discard, SerializedSigners};
use crate::counters::TXN_GAS_USAGE;
use crate::errors::discarded_output;
use crate::gas::{check_gas, make_prod_gas_meter};
use crate::move_vm_ext::session::user_transaction_sessions::epilogue::EpilogueSession;
use crate::move_vm_ext::session::user_transaction_sessions::prologue::PrologueSession;
use crate::move_vm_ext::session::user_transaction_sessions::user::UserSession;
use crate::move_vm_ext::{AptosMoveResolver, SessionExt};
use crate::transaction_metadata::TransactionMetadata;
use crate::{transaction_validation, AptosVM};
use aptos_gas_algebra::Gas;
use aptos_gas_meter::{AptosGasMeter, GasAlgebra};
use aptos_gas_schedule::VMGasParameters;
use aptos_types::fee_statement::FeeStatement;
use aptos_types::on_chain_config::FeatureFlag;
use aptos_types::transaction::automated_transaction::AutomatedTransaction;
use aptos_types::transaction::automation::AutomationTaskType;
use aptos_types::transaction::{
    EntryFunction, ExecutionStatus, TransactionPayload, TransactionStatus,
};
use aptos_vm_logging::log_schema::AdapterLogSchema;
use aptos_vm_types::output::VMOutput;
use aptos_vm_types::storage::change_set_configs::ChangeSetConfigs;
use aptos_vm_types::storage::StorageGasParameters;
use fail::fail_point;
use move_binary_format::errors::Location;
use move_core_types::vm_status::{StatusCode, VMStatus};
use move_vm_runtime::module_traversal::{TraversalContext, TraversalStorage};
use std::ops::Deref;
use aptos_vm_types::module_and_script_storage::code_storage::AptosCodeStorage;
use aptos_vm_types::module_and_script_storage::module_storage::AptosModuleStorage;
use aptos_vm_types::resolver::BlockSynchronizationKillSwitch;
use move_vm_runtime::ModuleStorage;
use crate::move_vm_ext::session::user_transaction_sessions::session_change_sets::SystemSessionChangeSet;

pub struct AutomatedTransactionProcessor<'m> {
    aptos_vm: &'m AptosVM,
    task_type: AutomationTaskType,
}

impl Deref for AutomatedTransactionProcessor<'_> {
    type Target = AptosVM;

    fn deref(&self) -> &Self::Target {
        self.aptos_vm
    }
}

impl<'m> AutomatedTransactionProcessor<'m> {
    pub(crate) fn new(aptos_vm: &'m AptosVM, task_type: AutomationTaskType) -> Self {
        Self {
            aptos_vm,
            task_type,
        }
    }

    fn validate_automated_transaction(
        &self,
        session: &mut SessionExt<impl AptosMoveResolver>,
        module_storage: &impl ModuleStorage,
        transaction: &AutomatedTransaction,
        transaction_data: &TransactionMetadata,
        log_context: &AdapterLogSchema,
        traversal_context: &mut TraversalContext,
    ) -> Result<(), VMStatus> {
        let TransactionPayload::EntryFunction(_entry_function) = transaction.payload() else {
            return Err(VMStatus::error(StatusCode::INVALID_AUTOMATED_PAYLOAD, None));
        };
        check_gas(
            self.gas_params(log_context)?,
            self.gas_feature_version(),
            session.resolver,
            module_storage,
            transaction_data,
            self.features(),
            false,
            log_context,
        )?;
        if self
            .features()
            .is_enabled(FeatureFlag::SUPRA_AUTOMATION_V2)
        {
            transaction_validation::run_automated_transaction_prologue_v2(
                session,
                module_storage,
                transaction_data,
                self.task_type,
                log_context,
                traversal_context,
            )
        } else {
            transaction_validation::run_automated_transaction_prologue(
                session,
                module_storage,
                transaction_data,
                log_context,
                traversal_context,
            )
        }
    }

    fn success_transaction_cleanup(
        &self,
        mut epilogue_session: EpilogueSession,
        module_storage: &impl AptosModuleStorage,
        gas_meter: &impl AptosGasMeter,
        txn_data: &TransactionMetadata,
        log_context: &AdapterLogSchema,
        change_set_configs: &ChangeSetConfigs,
        traversal_context: &mut TraversalContext,
    ) -> Result<(VMStatus, VMOutput), VMStatus> {
        if self.gas_feature_version() >= 12 {
            // Check if the gas meter's internal counters are consistent.
            //
            // It's better to fail the transaction due to invariant violation than to allow
            // potentially bogus states to be committed.
            if let Err(err) = gas_meter.algebra().check_consistency() {
                println!(
                    "[aptos-vm][gas-meter][success-epilogue] {}",
                    err.message()
                        .unwrap_or("No message found -- this should not happen.")
                );
                return Err(err.finish(Location::Undefined).into());
            }
        }

        let assessed_fee_statement = AptosVM::fee_statement_from_gas_meter(
            txn_data,
            gas_meter,
            u64::from(epilogue_session.get_storage_fee_refund()),
        );
        epilogue_session.execute(|session| {
            transaction_validation::run_automated_txn_success_epilogue(
                session,
                module_storage,
                gas_meter.balance(),
                assessed_fee_statement,
                self.features(),
                txn_data,
                self.task_type,
                log_context,
                traversal_context,
            )
        })?;
        let output = epilogue_session.finish(
            self.get_fee_statement_for_output(assessed_fee_statement),
            ExecutionStatus::Success,
            change_set_configs,
            module_storage,
        )?;

        Ok((VMStatus::Executed, output))
    }

    fn execute_entry_function<'a, 'r>(
        &self,
        resolver: &'r impl AptosMoveResolver,
        code_storage: &impl AptosCodeStorage,
        mut session: UserSession<'r>,
        gas_meter: &mut impl AptosGasMeter,
        traversal_context: &mut TraversalContext<'a>,
        serialized_signers: &SerializedSigners,
        txn_data: &TransactionMetadata,
        entry_function: &'a EntryFunction,
        log_context: &AdapterLogSchema,
        change_set_configs: &ChangeSetConfigs,
    ) -> Result<(VMStatus, VMOutput), VMStatus> {
        fail_point!(
            "aptos_vm::automated_transaction_processor::execute_payload",
            |_| {
                Err(VMStatus::Error {
                status_code: StatusCode::UNKNOWN_INVARIANT_VIOLATION_ERROR,
                sub_status: Some(move_core_types::vm_status::sub_status::unknown_invariant_violation::EPARANOID_FAILURE),
                message: None,
            })
            }
        );

        gas_meter.charge_intrinsic_gas_for_transaction(txn_data.transaction_size())?;
        session.execute(|session| {
            self.validate_and_execute_entry_function(
                code_storage,
                session,
                serialized_signers,
                gas_meter,
                traversal_context,
                entry_function,
            )
        })?;

        let user_session_change_set = self.resolve_pending_code_publish_and_finish_user_session(
            session,
            resolver,
            code_storage,
            gas_meter,
            traversal_context,
            change_set_configs,
        )?;

        let epilogue_session = self.charge_change_set_and_respawn_session(
            user_session_change_set,
            resolver,
            code_storage,
            gas_meter,
            txn_data,
        )?;

        // ============= Gas fee cannot change after this line =============

        self.success_transaction_cleanup(
            epilogue_session,
            code_storage,
            gas_meter,
            txn_data,
            log_context,
            change_set_configs,
            traversal_context,
        )
    }

    // Called when the execution of the transaction fails, in order to discard the
    // transaction, or clean up the failed state.
    fn on_transaction_execution_failure(
        &self,
        prologue_change_set: SystemSessionChangeSet,
        err: VMStatus,
        resolver: &impl AptosMoveResolver,
        module_storage: &impl AptosModuleStorage,
        txn_data: &TransactionMetadata,
        log_context: &AdapterLogSchema,
        gas_meter: &mut impl AptosGasMeter,
        change_set_configs: &ChangeSetConfigs,
        traversal_context: &mut TraversalContext,
    ) -> (VMStatus, VMOutput) {

        self.failed_transaction_cleanup(
            prologue_change_set,
            err,
            gas_meter,
            txn_data,
            resolver,
            module_storage,
            log_context,
            change_set_configs,
            traversal_context,
        )
    }
    pub(crate) fn execute_transaction_impl<'a>(
        &self,
        resolver: &impl AptosMoveResolver,
        code_storage: &impl AptosCodeStorage,
        txn: &AutomatedTransaction,
        txn_data: TransactionMetadata,
        gas_meter: &mut impl AptosGasMeter,
        log_context: &AdapterLogSchema,
    ) -> (VMStatus, VMOutput) {
        let traversal_storage = TraversalStorage::new();
        let mut traversal_context = TraversalContext::new(&traversal_storage);

        // Revalidate the transaction.
        let mut prologue_session =
            PrologueSession::new(self.aptos_vm, &txn_data, resolver);

        let exec_result = prologue_session.execute(|session| {
            self.validate_automated_transaction(
                session,
                code_storage,
                txn,
                &txn_data,
                log_context,
                &mut traversal_context,
            )
        });
        unwrap_or_discard!(exec_result);
        let storage_gas_params = unwrap_or_discard!(self.storage_gas_params(log_context));
        let change_set_configs = &storage_gas_params.change_set_configs;
        let (prologue_change_set, user_session) = unwrap_or_discard!(prologue_session
            .into_user_session(
                self,
                &txn_data,
                resolver,
                change_set_configs,
                code_storage,
            ));
        let TransactionPayload::EntryFunction(automated_entry_function) = txn.payload() else {
            return (
                VMStatus::error(StatusCode::INVALID_AUTOMATED_PAYLOAD, None),
                discarded_output(StatusCode::INVALID_AUTOMATED_PAYLOAD),
            );
        };

        let serialized_signers = SerializedSigners::from((txn_data.senders(), None));

        // // We keep track of whether any newly published modules are loaded into the Vm's loader
        // // cache as part of executing transactions. This would allow us to decide whether the cache
        // // should be flushed later.
        let result = self.execute_entry_function(
            resolver,
            code_storage,
            user_session,
            gas_meter,
            &mut traversal_context,
            &serialized_signers,
            &txn_data,
            automated_entry_function,
            log_context,
            change_set_configs,
        );

        let gas_usage = txn_data
            .max_gas_amount()
            .checked_sub(gas_meter.balance())
            .expect("Balance should always be less than or equal to max gas amount set");
        TXN_GAS_USAGE.observe(u64::from(gas_usage) as f64);

        result.unwrap_or_else(|err| {
            self.on_transaction_execution_failure(
                prologue_change_set,
                err,
                resolver,
                code_storage,
                &txn_data,
                log_context,
                gas_meter,
                change_set_configs,
                &mut traversal_context,
            )
        })
    }

    /// Main entrypoint for executing a user transaction that also allows the customization of the
    /// gas meter to be used.
    pub fn execute_transaction_with_custom_gas_meter<'a, C, G, F>(
        &self,
        resolver: &impl AptosMoveResolver,
        code_storage: &'a C,
        txn: &AutomatedTransaction,
        log_context: &AdapterLogSchema,
        make_gas_meter: F,
    ) -> Result<(VMStatus, VMOutput, G), VMStatus>
    where
        C: AptosCodeStorage + BlockSynchronizationKillSwitch + 'a,
        G: AptosGasMeter,
        F: FnOnce(u64, VMGasParameters, StorageGasParameters, bool, Gas, &'a C) -> G,
    {
        let txn_metadata = TransactionMetadata::from(txn);

        let balance = txn.max_gas_amount().into();
        let mut gas_meter = make_gas_meter(
            self.gas_feature_version(),
            self.gas_params(log_context)?.vm.clone(),
            self.storage_gas_params(log_context)?.clone(),
            false,
            balance,
            code_storage,
        );
        let (status, output) =
            self.execute_transaction_impl(resolver, code_storage, txn, txn_metadata, &mut gas_meter, log_context);

        Ok((status, output, gas_meter))
    }

    /// Executes an automated transaction using the production gas meter.
    pub fn execute_transaction(
        &self,
        resolver: &impl AptosMoveResolver,
        code_storage: &(impl AptosCodeStorage + BlockSynchronizationKillSwitch),
        txn: &AutomatedTransaction,
        log_context: &AdapterLogSchema,
    ) -> (VMStatus, VMOutput) {
        match self.execute_transaction_with_custom_gas_meter(
            resolver,
            code_storage,
            txn,
            log_context,
            make_prod_gas_meter,
        ) {
            Ok((vm_status, vm_output, _gas_meter)) => (vm_status, vm_output),
            Err(vm_status) => {
                let vm_output = discarded_output(vm_status.status_code());
                (vm_status, vm_output)
            },
        }
    }

    fn failed_transaction_cleanup(
        &self,
        prologue_change_set: SystemSessionChangeSet,
        error_vm_status: VMStatus,
        gas_meter: &mut impl AptosGasMeter,
        txn_data: &TransactionMetadata,
        resolver: &impl AptosMoveResolver,
        module_storage: &impl AptosModuleStorage,
        log_context: &AdapterLogSchema,
        change_set_configs: &ChangeSetConfigs,
        traversal_context: &mut TraversalContext,
    ) -> (VMStatus, VMOutput) {
        if self.gas_feature_version() >= 12 {
            // Check if the gas meter's internal counters are consistent.
            //
            // Since we are already in the failure epilogue, there is not much we can do
            // other than logging the inconsistency.
            //
            // This is a tradeoff. We have to either
            //   1. Continue to calculate the gas cost based on the numbers we have.
            //   2. Discard the transaction.
            //
            // Option (2) does not work, since it would enable DoS attacks.
            // Option (1) is not ideal, but optimistically, it should allow the network
            // to continue functioning, less the transactions that run into this problem.
            if let Err(err) = gas_meter.algebra().check_consistency() {
                println!(
                    "[aptos-vm][gas-meter][failure-epilogue] {}",
                    err.message()
                        .unwrap_or("No message found -- this should not happen.")
                );
            }
        }

        let txn_status = TransactionStatus::from_vm_status(
            error_vm_status.clone(),
            self.features(),
        );

        match txn_status {
            TransactionStatus::Keep(status) => {
                // The transaction should be kept. Run the appropriate post transaction workflows
                // including epilogue. This runs a new session that ignores any side effects that
                // might abort the execution (e.g., spending additional funds needed to pay for
                // gas). Even if the previous failure occurred while running the epilogue, it
                // should not fail now. If it somehow fails here, there is no choice but to
                // discard the transaction.
                let txn_output = self.finish_aborted_transaction(
                    prologue_change_set,
                    gas_meter,
                    txn_data,
                    resolver,
                    module_storage,
                    status,
                    log_context,
                    change_set_configs,
                    traversal_context,
                ).unwrap_or_else(|status| discarded_output(status.status_code()));
                (error_vm_status, txn_output)
            },
            TransactionStatus::Discard(status_code) => {
                let discarded_output = discarded_output(status_code);
                (error_vm_status, discarded_output)
            },
            TransactionStatus::Retry => unreachable!(),
        }
    }

    fn finish_aborted_transaction(
        &self,
        prologue_change_set: SystemSessionChangeSet,
        gas_meter: &mut impl AptosGasMeter,
        txn_data: &TransactionMetadata,
        resolver: &impl AptosMoveResolver,
        module_storage: &impl AptosModuleStorage,
        status: ExecutionStatus,
        log_context: &AdapterLogSchema,
        change_set_configs: &ChangeSetConfigs,
        traversal_context: &mut TraversalContext,
    ) -> Result<VMOutput, VMStatus> {
        // Storage refund is zero since no slots are deleted in aborted transactions.
        const ZERO_STORAGE_REFUND: u64 = 0;

        let mut epilogue_session = EpilogueSession::on_user_session_failure(
            &self.aptos_vm,
            txn_data,
            resolver,
            prologue_change_set,
        );

        let status = self.inject_abort_info_if_available(
            module_storage,
            traversal_context,
            log_context,
            status);

        let fee_statement =
            AptosVM::fee_statement_from_gas_meter(txn_data, gas_meter, ZERO_STORAGE_REFUND);
        epilogue_session.execute(|session| {
            transaction_validation::run_automated_txn_failure_epilogue(
                session,
                module_storage,
                gas_meter.balance(),
                fee_statement,
                self.features(),
                txn_data,
                self.task_type,
                log_context,
                traversal_context,
            )
        })?;
        epilogue_session
            .finish(self.get_fee_statement_for_output(fee_statement), status, change_set_configs, module_storage)
    }

    /// The actual charged fee statement for executed automated transaction.
    /// The input [`fee_statement`] is the assessed fee charges based on the gas-meter, but
    /// the output fee-statement will be based on the task type. As system tasks are not charged at all
    /// the output will contain `zero` gas information.
    /// This function is utilized to define fee-statement of VMOutput.
    fn get_fee_statement_for_output(&self, fee_statement: FeeStatement) -> FeeStatement {
        match self.task_type {
            AutomationTaskType::User => {
                fee_statement
            }
            AutomationTaskType::System => {
                FeeStatement::zero()
            }
        }
    }
}
