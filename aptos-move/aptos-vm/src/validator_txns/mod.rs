// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{
    move_vm_ext::{AptosMoveResolver, SessionId},
    AptosVM,
};
use aptos_types::{on_chain_config::FeatureFlag, validator_txn::ValidatorTransaction};
use aptos_vm_logging::log_schema::AdapterLogSchema;
use aptos_vm_types::{
    module_and_script_storage::module_storage::AptosModuleStorage, output::VMOutput,
};
use move_core_types::vm_status::{StatusCode, VMStatus};

impl AptosVM {
    pub(crate) fn process_validator_transaction(
        &self,
        resolver: &impl AptosMoveResolver,
        module_storage: &impl AptosModuleStorage,
        txn: ValidatorTransaction,
        log_context: &AdapterLogSchema,
    ) -> Result<(VMStatus, VMOutput), VMStatus> {
        let session_id = SessionId::validator_txn(&txn);
        match txn {
            ValidatorTransaction::DKG(dkg_node) => {
                if !self.features().is_enabled(FeatureFlag::SUPRA_DKG) {
                    return Err(VMStatus::error(StatusCode::FEATURE_UNDER_GATING, None));
                }

                self.process_dkg_transaction(resolver, module_storage, log_context, session_id, dkg_node)
            },
            ValidatorTransaction::ObservedJWKUpdate(jwk_update) => self.process_jwk_update(
                resolver,
                module_storage,
                log_context,
                session_id,
                jwk_update,
            ),
            ValidatorTransaction::DKGResult(_) => Err(VMStatus::Error {
                status_code: StatusCode::UNREACHABLE,
                sub_status: None,
                message: Some("Unsupported ValidatorTransaction variant".to_string()),
            }),
        }
    }
}

mod dkg;
mod jwk;
