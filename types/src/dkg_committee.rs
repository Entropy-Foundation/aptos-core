use serde::{Deserialize, Serialize};
use move_core_types::account_address::AccountAddress;

/// Reflection of `0x1::types::DkgCommitteeType` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum DkgCommitteeType{
    Clan,
    Tribe,
}

/// Reflection of `0x1::types::DkgNodeConfig` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DkgNodeConfig {
    pub addr: AccountAddress,
    pub bls_pubkey: Vec<u8>,
}

/// Reflection of `0x1::types::DkgCommittee` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DkgCommittee {
    pub committee_type: DkgCommitteeType,
    pub committee: Vec<DkgNodeConfig>,
}
