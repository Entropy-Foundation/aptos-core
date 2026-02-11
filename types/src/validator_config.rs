// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use crate::network_address::NetworkAddress;
use aptos_crypto::ed25519;
use aptos_crypto::ed25519::PublicKey as Ed25519PublicKey;
use move_core_types::{
    ident_str,
    identifier::IdentStr,
    move_resource::{MoveResource, MoveStructType},
};
use nidkg_helper::{cgdkg::CGPublicKey, BlsPublicKey};
#[cfg(any(test, feature = "fuzzing"))]
use proptest_derive::Arbitrary;
use serde::{Deserialize, Serialize};

impl MoveStructType for ValidatorConfig {
    const MODULE_NAME: &'static IdentStr = ident_str!("stake");
    const STRUCT_NAME: &'static IdentStr = ident_str!("ValidatorConfig");
}

impl MoveResource for ValidatorConfig {}

#[derive(Debug, Deserialize, Serialize, Clone, Eq, PartialEq, Default)]
pub struct ValidatorOperatorConfigResource {
    pub human_name: Vec<u8>,
}

impl MoveStructType for ValidatorOperatorConfigResource {
    const MODULE_NAME: &'static IdentStr = ident_str!("validator_operator_config");
    const STRUCT_NAME: &'static IdentStr = ident_str!("ValidatorOperatorConfig");
}

impl MoveResource for ValidatorOperatorConfigResource {}

#[derive(Clone, Debug, Eq, PartialEq, Deserialize, Serialize)]
#[cfg_attr(any(test, feature = "fuzzing"), derive(Arbitrary))]
pub struct ValidatorConfig {
    consensus_public_key: Vec<u8>,
    /// This is an bcs serialized `Vec<NetworkAddress>`
    pub validator_network_addresses: Vec<u8>,
    /// This is an bcs serialized `Vec<NetworkAddress>`
    pub fullnode_network_addresses: Vec<u8>,
    pub validator_index: u64,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
struct InternalPublicKeysOnChainReprezentation {
    bls_multisig_key: BlsPublicKey,
    bls_threshold_validity_certificate_key: Option<BlsPublicKey>, // f+1 threshold
    bls_threshold_quorum_certificate_key: Option<BlsPublicKey>,   // 2f+1 threshold
    bls_threshold_unanimous_certificate_key: Option<BlsPublicKey>,
    bls_threshold_bcft_validity_certificate_key: Option<BlsPublicKey>,
    bls_threshold_bcft_quorum_certificate_key: Option<BlsPublicKey>,
    bls_threshold_bcft_fallback_view_change_certificate_key: Option<BlsPublicKey>,
    bls_threshold_clan_majority_certificate_key: Option<BlsPublicKey>,
    class_group_key: CGPublicKey,
    ed25519_key: Ed25519PublicKey,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
struct ValidatorPublicKeysOnChainReprezentation {
    network_key: Ed25519PublicKey,
    supra_keys: InternalPublicKeysOnChainReprezentation,
}

impl ValidatorConfig {
    pub fn new(
        consensus_public_key: ed25519::PublicKey,
        validator_network_addresses: Vec<u8>,
        fullnode_network_addresses: Vec<u8>,
        validator_index: u64,
    ) -> Self {
        ValidatorConfig {
            consensus_public_key: consensus_public_key.to_bytes().to_vec(),
            validator_network_addresses,
            fullnode_network_addresses,
            validator_index,
        }
    }

    pub fn consensus_key_raw(&self) -> Vec<u8> {
        self.consensus_public_key.clone()
    }

    pub fn consensus_public_key(&self) -> Ed25519PublicKey {
        let keys =
            bcs::from_bytes::<ValidatorPublicKeysOnChainReprezentation>(&self.consensus_public_key);
        if let Ok(keys) = keys {
            return keys.supra_keys.ed25519_key;
        }

        Ed25519PublicKey::try_from(&self.consensus_public_key[..])
            .expect("Failed to deserialize consensus public key from on-chain representation")
    }

    pub fn fullnode_network_addresses(&self) -> Result<Vec<NetworkAddress>, bcs::Error> {
        bcs::from_bytes(&self.fullnode_network_addresses)
    }

    pub fn validator_network_addresses(&self) -> Result<Vec<NetworkAddress>, bcs::Error> {
        bcs::from_bytes(&self.validator_network_addresses)
    }
}
