use serde::{Deserialize, Serialize};
use move_core_types::account_address::AccountAddress;

/// Reflection of `0x1::types::DkgCommitteeType` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum DkgCommitteeType{
    Clan,
    Tribe,
}

/// Reflection of `0x1::dkg_committee::DkgNodeConfig` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DkgNodeConfig {
    pub addr: AccountAddress,
    pub identity: Vec<u8>,
    pub dkg_pubkey: Vec<u8>,
}

/// Reflection of `0x1::dkg_committee::DkgCommittee` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DkgCommittee {
    pub committee_type: DkgCommitteeType,
    pub committee: Vec<DkgNodeConfig>,
}
