// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use crate::network_address::NetworkAddress;
use aptos_crypto::ed25519::PublicKey;
use derive_getters::Getters;
use derive_more::Constructor;
use move_core_types::{
    ident_str,
    identifier::IdentStr,
    move_resource::{MoveResource, MoveStructType},
};
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
    pub consensus_public_keys: ValidatorConfigPublicKeys,
    /// This is an bcs serialized `Vec<NetworkAddress>`
    pub validator_network_addresses: Vec<u8>,
    /// This is an bcs serialized `Vec<NetworkAddress>`
    pub fullnode_network_addresses: Vec<u8>,
    pub validator_index: u64,
}

#[derive(Clone, Debug, Eq, PartialEq, Constructor, Getters)]
#[cfg_attr(any(test, feature = "fuzzing"), derive(Arbitrary))]
pub struct ValidatorConfigPublicKeys {
    ed25519_public_key: PublicKey,
}

impl Serialize for ValidatorConfigPublicKeys {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        let bytes = self.ed25519_public_key.to_bytes().to_vec();
        Serialize::serialize(&bytes, serializer)
    }
}

impl<'de> Deserialize<'de> for ValidatorConfigPublicKeys {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: serde::Deserializer<'de>,
    {
        let bytes: Vec<u8> = Deserialize::deserialize(deserializer)?;
        if bytes.len() != 32 {
            return Err(serde::de::Error::invalid_length(
                bytes.len(),
                &"expected 32 bytes for ed25519 public key",
            ));
        }
        let ed25519_public_key =
            PublicKey::try_from(&bytes[..]).map_err(serde::de::Error::custom)?;
        Ok(ValidatorConfigPublicKeys { ed25519_public_key })
    }
}

impl ValidatorConfig {
    pub fn new(
        consensus_public_keys: ValidatorConfigPublicKeys,
        validator_network_addresses: Vec<u8>,
        fullnode_network_addresses: Vec<u8>,
        validator_index: u64,
    ) -> Self {
        ValidatorConfig {
            consensus_public_keys,
            validator_network_addresses,
            fullnode_network_addresses,
            validator_index,
        }
    }

    pub fn fullnode_network_addresses(&self) -> Result<Vec<NetworkAddress>, bcs::Error> {
        bcs::from_bytes(&self.fullnode_network_addresses)
    }

    pub fn validator_network_addresses(&self) -> Result<Vec<NetworkAddress>, bcs::Error> {
        bcs::from_bytes(&self.validator_network_addresses)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use aptos_crypto::ed25519::{PrivateKey, PublicKey};
    use aptos_crypto::Uniform;

    #[test]
    fn test_validator_config_public_key_serde() {
        let private_key = PrivateKey::generate_for_testing();
        let public_key = PublicKey::from(&private_key);
        let validator_config_public_keys = ValidatorConfigPublicKeys::new(public_key.clone());

        let serialized =
            bcs::to_bytes(&validator_config_public_keys).expect("Failed to serialize public key");
        assert_eq!(serialized.len(), 33);
        let deserialized: ValidatorConfigPublicKeys =
            bcs::from_bytes(&serialized).expect("Failed to deserialize public key");

        assert_eq!(
            validator_config_public_keys, deserialized,
            "Deserialized public key does not match the original"
        );
        assert_eq!(
            &serialized[1..],
            public_key.to_bytes().as_slice(),
            "Deserialized public key does not match by representation"
        );
    }
}
