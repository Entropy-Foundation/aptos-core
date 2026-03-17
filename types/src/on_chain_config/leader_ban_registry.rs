use derive_getters::Getters;
use derive_more::Constructor;
use serde::{Deserialize, Serialize};

use crate::on_chain_config::OnChainConfig;

/// Configuration for a [`BanRegistry`]. Stored in the Move state and updated via governance.
///
/// This enum allows for future versions of the configuration to be added without breaking
/// the backwards compatibility constraints enforced by BCS.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub enum BanRegistryParameters {
    V0(BanRegistryParametersV0),
}

impl Default for BanRegistryParameters {
    fn default() -> Self {
        BanRegistryParameters::V0(BanRegistryParametersV0::default())
    }
}

impl OnChainConfig for BanRegistryParameters {
    const MODULE_IDENTIFIER: &'static str = "leader_ban_registry";
    const TYPE_IDENTIFIER: &'static str = "BanRegistryParameters";
}

/// The parameters of the consensus leader [`BanRegistry`].
///
/// BCS field order **must** match the Move struct `BanRegistryParametersV0`:
/// `initial_elections_denied, max_elections_denied, minimum_unbanned_proposers, probation_elections`.
/// 
/// The [`Default`] values of the parameters disable banning.
#[derive(Clone, Constructor, Debug, Default, Deserialize, Getters, Serialize)]
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
