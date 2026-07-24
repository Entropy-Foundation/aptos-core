use derive_getters::Getters;
use derive_more::Constructor;
use move_core_types::{
    account_address::AccountAddress,
    value::{serialize_values, MoveValue},
};
use serde::{Deserialize, Serialize};
use anyhow::{format_err, Result};

use crate::on_chain_config::OnChainConfig;

/// Configuration for a [`BanRegistry`]. Stored in the Move state and updated via governance.
///
/// This enum allows for future versions of the configuration to be added without breaking
/// the backwards compatibility constraints enforced by BCS.
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub enum BanRegistryParameters {
    V0(BanRegistryParametersV0),
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
struct MoveBanRegistryParams {
    pub config: Vec<u8>,
    pub version: u8
}

impl Default for BanRegistryParameters {
    fn default() -> Self {
        BanRegistryParameters::V0(BanRegistryParametersV0::default())
    }
}

impl OnChainConfig for BanRegistryParameters {
    const MODULE_IDENTIFIER: &'static str = "leader_ban_registry_config";
    const TYPE_IDENTIFIER: &'static str = "BanRegistryParameters";

    fn deserialize_default_impl(bytes: &[u8]) -> Result<Self> {
        let move_ban_registry = bcs::from_bytes::<MoveBanRegistryParams>(bytes)
            .map_err(|e| format_err!("[on-chain config] Failed to deserialize into config: {}", e))?;
        match move_ban_registry.version {
            0 => {
                let params_v0 = bcs::from_bytes::<BanRegistryParametersV0>(&move_ban_registry.config)
                .map_err(|e| format_err!("[on-chain config] Failed to deserialize into config BanRegistryParametersV0: {}", e))?;
                Ok(BanRegistryParameters::V0(params_v0))
            },
            _ => {
                Err(format_err!("[on-chain config] Failed to deserialize into config: Invalid Version: {}", move_ban_registry.version))
            }
        }
    }
}

impl BanRegistryParameters {
    pub fn serialize_into_move_values_with_signer(&self, signer_address: AccountAddress) -> Vec<Vec<u8>> {
        let arguments:Vec<MoveValue> = match &self {
            BanRegistryParameters::V0(ban_registry_parameters_v0) => {
                let params_bytes = bcs::to_bytes(ban_registry_parameters_v0).expect("serialisation of leader ban config failed");
                vec![
                    MoveValue::Signer(signer_address),
                    MoveValue::vector_u8(params_bytes),
                ]
            },
        };
        serialize_values(&arguments)
    }
}

/// The parameters of the consensus leader [`BanRegistry`].
///
/// BCS field order **must** match the Move struct `BanRegistryParametersV0`:
/// `initial_elections_denied, max_elections_denied, minimum_unbanned_proposers, probation_elections`.
/// 
/// The [`Default`] values of the parameters disable banning.
#[derive(Clone, Constructor, Debug, Default, Deserialize, Eq, PartialEq, Getters, Serialize)]
pub struct BanRegistryParametersV0 {
    /// The (approximate) initial number of election opportunities denied to a validator that
    /// fails to propose a committed block when elected as leader.
    ///
    /// This number is scaled in proportion to the size of the [`Committee`] for the current epoch to
    /// derive the total number of consensus rounds for which a validator is banned. This enables the
    /// ban duration to remain roughly constant, regardless of the number of validators in the committee.
    initial_elections_denied: u8,
    /// The (approximate) maximum number of election opportunities denied to a validator that
    /// consecutively fails to propose a committed block when elected as leader.
    max_elections_denied: u32,
    /// The lower bound on the number of validators that must remain eligible to be elected as
    /// consensus leader. If banning a validator would cause the number of eligible validators to
    /// drop below this number, the ban is not applied.
    minimum_unbanned_proposers: u8,
    /// The number of elections a validator must serve on probation after their ban expires.
    /// During probation, the validator is eligible for election but will be banned for a longer
    /// period (with `consecutive_bans` incremented) if it fails again. If the validator completes
    /// probation without failing, the ban record is fully removed.
    probation_elections: u8,
}
