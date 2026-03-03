use derive_getters::Getters;
use move_core_types::account_address::AccountAddress;
use serde::{Deserialize, Serialize};

/// Reflection of `0x1::dkg_committee::DkgNodeConfig` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, Getters)]
pub struct DkgNodeConfig {
    pool_address: AccountAddress,
    identity: Vec<u8>,
    dkg_pubkey: Vec<u8>,
}

impl DkgNodeConfig {
    pub fn new(pool_address: AccountAddress, identity: Vec<u8>, dkg_pubkey: Vec<u8>) -> Self {
        Self {
            pool_address,
            identity,
            dkg_pubkey,
        }
    }
}

/// Reflection of `0x1::dkg_committee::DkgCommittee` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, Getters)]
pub struct DkgCommittee {
    committee: Vec<DkgNodeConfig>,
    threshold_type: u8,
}

impl DkgCommittee {
    pub fn new(committee: Vec<DkgNodeConfig>, threshold_type: u8) -> Self {
        Self {
            committee,
            threshold_type,
        }
    }
}

/// Reflection of `0x1::dkg_committee::ReceiverCommittee` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, Getters)]
pub struct ReceiverCommittee {
    is_resharing: bool,
    dkg_threshold_type: u8,
    committee: DkgCommittee,
}

impl ReceiverCommittee {
    pub fn new(is_resharing: bool, dkg_threshold_type: u8, committee: DkgCommittee) -> Self {
        Self {
            is_resharing,
            dkg_threshold_type,
            committee,
        }
    }
}
