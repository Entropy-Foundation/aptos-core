// Copyright (c) Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

// // Copyright (c) 2024 Supra.
// // SPDX-License-Identifier: Apache-2.0

use crate::gas::{make_prod_gas_meter, ProdGasMeter};
use crate::AptosVM;
use aptos_types::state_store::StateView;
use aptos_types::transaction::{ViewFunction, ViewFunctionOutput};
use aptos_vm_environment::environment::AptosEnvironment;
use aptos_vm_logging::log_schema::AdapterLogSchema;
use aptos_vm_types::module_and_script_storage::AsAptosCodeStorage;
use aptos_vm_types::resolver::NoopBlockSynchronizationKillSwitch;
use move_vm_runtime::module_traversal::{TraversalContext, TraversalStorage};
use crate::move_vm_ext::SessionId::Void;

/// Move VM with only view function API.
/// Convenient to use when more than one view function needs to be executed on the same state-view,
/// as it avoids to set up AptosVM upon each function execution.
pub struct AptosVMViewer<'t, SV: StateView> {
    vm: AptosVM,
    state_view: &'t SV,
    log_context: AdapterLogSchema,
}

impl<'t, SV: StateView> AptosVMViewer<'t, SV> {
    /// Creates a new VM instance, initializing the runtime environment from the state.
    pub fn new(state_view: &'t SV) -> Self {
        let aptos_environemnt = AptosEnvironment::new(state_view);
        let vm = AptosVM::new(&aptos_environemnt, state_view);
        let log_context = AdapterLogSchema::new(state_view.id(), 0);
        Self {
            vm,
            state_view,
            log_context,
        }
    }

    fn create_gas_meter(&self, max_gas_amount: u64) -> anyhow::Result<ProdGasMeter<NoopBlockSynchronizationKillSwitch>> {
        let vm_gas_params = self.vm.gas_params(&self.log_context).map_err(|err| anyhow::Error::msg(err.to_string()))?.vm.clone();
        let storage_gas_params =
        self.vm.storage_gas_params(&self.log_context).map_err(|err| anyhow::Error::msg(err.to_string()))?;

        let gas_meter = make_prod_gas_meter(
            self.vm.gas_feature_version(),
            vm_gas_params,
            storage_gas_params.clone(),
            /* is_approved_gov_script */ false,
            max_gas_amount.into(),
            &NoopBlockSynchronizationKillSwitch {},
        );
        Ok(gas_meter)
    }

    pub fn execute_view_function(
        &self,
        function: ViewFunction,
        max_gas_amount: u64,
    ) -> ViewFunctionOutput {
        let resolver = self.vm.as_move_resolver(self.state_view);
        let mut session = self.vm.new_session(&resolver, Void, None);
        let mut gas_meter = match self.create_gas_meter(max_gas_amount) {
            Ok(meter) => meter,
            Err(e) => return ViewFunctionOutput::new_error_message(e.to_string(), None, 0),
        };
        let (module_id, func_name, type_args, arguments) = function.into_inner();

        let traversal_storage = TraversalStorage::new();
        let mut traversal_context = TraversalContext::new(&traversal_storage);
        let module_storage = self.state_view.as_aptos_code_storage(self.vm.environment_ref());
        let execution_result = AptosVM::execute_view_function_in_vm(
            &mut session,
            &self.vm,
            module_id,
            func_name,
            type_args,
            arguments,
            &mut gas_meter,
            &mut traversal_context,
            &module_storage
        );
        let gas_used = AptosVM::gas_used(max_gas_amount.into(), &gas_meter);
        match execution_result {
            Ok(result) => ViewFunctionOutput::new(Ok(result), gas_used),
            Err(e) => self.vm.view_function_output_from_error(e, gas_used, &module_storage, &traversal_context, &self.log_context),
        }
    }
}
