use derive_getters::Getters;
use move_core_types::account_address::AccountAddress;
use serde::{Deserialize, Serialize};

/// Reflection of `0x1::types::DkgCommitteeType` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum DkgCommitteeType {
    Clan,
    Tribe,
}

/// Reflection of `0x1::dkg_committee::DkgNodeConfig` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, Getters)]
pub struct DkgNodeConfig {
    pool_address: AccountAddress,
    identity: Vec<u8>,
    dkg_pubkey: Vec<u8>,
}

/// Reflection of `0x1::dkg_committee::DkgCommittee` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, Getters)]
pub struct DkgCommittee {
    committee_type: DkgCommitteeType,
    committee: Vec<DkgNodeConfig>,
}
