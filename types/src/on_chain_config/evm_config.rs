// Copyright (c) 2026 Supra.
// SPDX-License-Identifier: Apache-2.0

use crate::on_chain_config::OnChainConfig;
use move_core_types::account_address::AccountAddress;
use move_core_types::value::MoveValue;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fmt::{Display, Formatter};
use std::str::FromStr;

// -- EvmContractName -----------------------------------------------------------

/// Evm Contract Names deployed by Supra at genesis or later to be part of Supra EVM main state.
/// Currently only system targeted contracts have dedicated enum variants, the rest will be stored
/// as instance of [Self::Custom] variant.
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize, Hash, PartialOrd, Ord)]
pub enum EvmContractName {
    BlockMetadata,
    AutomationController,
    AutomationRegistry,
    Custom(String),
}

impl FromStr for EvmContractName {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "BlockMetadata" => Ok(EvmContractName::BlockMetadata),
            "AutomationCore" => Ok(EvmContractName::AutomationController),
            "AutomationRegistry" => Ok(EvmContractName::AutomationRegistry),
            n => Ok(EvmContractName::Custom(n.to_string())),
        }
    }
}

impl Display for EvmContractName {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            EvmContractName::BlockMetadata => write!(f, "BlockMetadata"),
            EvmContractName::AutomationController => write!(f, "AutomationCore"),
            EvmContractName::AutomationRegistry => write!(f, "AutomationRegistry"),
            EvmContractName::Custom(n) => write!(f, "{n}"),
        }
    }
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub(crate) struct EvmContractsDetails {
    details: Vec<(String, AccountAddress)>,
}

pub const EVM_ADDRESS_LENGTH: usize = 20;
type RawEvmAddress = [u8; EVM_ADDRESS_LENGTH];

/// The Genesis configuration for EVM that can only be set once at genesis epoch.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct OnChainEvmContractsDetails {
    pub name_to_addresses: BTreeMap<EvmContractName, RawEvmAddress>,
}

impl OnChainEvmContractsDetails {
    /// Converts keys and values to [`MoveValue`] and returns as tuple.
    pub fn to_move_values(self) -> (MoveValue, MoveValue) {
        let (keys, values): (Vec<_>, Vec<_>) = self
            .name_to_addresses
            .into_iter()
            .map(|(key, value)| {
                // A Move `address` is 32 bytes serialised by BCS in big-endian order
                // (most-significant byte at index 0).  An EVM address is only 20 bytes,
                // so we zero-pad the leading 12 bytes and place the EVM bytes at the
                // tail (indices 12-31).  This matches the invariant enforced by
                // `is_valid_evm_address` in evm_config.move, which asserts that
                // indices 0-11 are all zero.
                let mut padded = [0u8; AccountAddress::LENGTH];
                padded[AccountAddress::LENGTH - EVM_ADDRESS_LENGTH..].copy_from_slice(&value);
                (
                    MoveValue::vector_u8(key.to_string().into_bytes()),
                    AccountAddress::from(padded),
                )
            })
            .unzip();
        (MoveValue::Vector(keys), MoveValue::vector_address(values))
    }

    pub fn get(&self, contract_name: EvmContractName) -> Option<&RawEvmAddress> {
        self.name_to_addresses.get(&contract_name)
    }

    pub fn has_all_keys(&self, keys: &[EvmContractName]) -> bool {
        keys.into_iter()
            .all(|key| self.name_to_addresses.contains_key(key))
    }
}

impl OnChainConfig for OnChainEvmContractsDetails {
    const MODULE_IDENTIFIER: &'static str = "evm_config";
    const TYPE_IDENTIFIER: &'static str = "EvmContractsDetails";

    fn deserialize_into_config(bytes: &[u8]) -> anyhow::Result<Self> {
        let raw_details = bcs::from_bytes::<EvmContractsDetails>(bytes)?;
        let details = raw_details
            .details
            .into_iter()
            .filter_map(|(key, value)| {
                let name = EvmContractName::from_str(&key).ok()?;
                // BCS serialises a Move `address` as a raw 32-byte big-endian
                // array.  `to_move_values` places the 20-byte EVM address in the
                // tail (indices 12-31) with the leading 12 bytes zeroed, so we
                // must read from the back to recover the original EVM address.
                let evm_address: RawEvmAddress = value.into_bytes()
                    [AccountAddress::LENGTH - EVM_ADDRESS_LENGTH..]
                    .try_into()
                    .ok()?;
                Some((name, evm_address))
            })
            .collect::<BTreeMap<_, _>>();
        Ok(Self {
            name_to_addresses: details,
        })
    }
}

// -- EvmScalarConfigKey --------------------------------------------------------

/// Typed keys for entries stored in the on-chain `EvmScalarConfig` resource.
/// Only keys whose string representation is known at compile time are listed
/// here; unknown keys are silently skipped during deserialization so that an
/// older node binary can still read a config that was extended with new keys.
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize, Hash, PartialOrd, Ord)]
pub enum EvmScalarConfigKey {
    EvmGasNormalizationDenom,
}

impl EvmScalarConfigKey {
    /// The set of keys that MUST be present in the on-chain config.
    /// Deserialization hard-fails if any of these is missing.
    pub fn required_keys() -> &'static [EvmScalarConfigKey] {
        &[EvmScalarConfigKey::EvmGasNormalizationDenom]
    }
}

impl FromStr for EvmScalarConfigKey {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "evm_gas_normalization_denom" => Ok(EvmScalarConfigKey::EvmGasNormalizationDenom),
            _ => Err(anyhow::anyhow!("unknown evm scalar config key: {}", s)),
        }
    }
}

impl Display for EvmScalarConfigKey {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        // Mirror FromStr: Display produces the canonical snake_case string that
        // operators see in logs and error messages.
        match self {
            EvmScalarConfigKey::EvmGasNormalizationDenom => {
                write!(f, "evm_gas_normalization_denom")
            }
        }
    }
}

// -- Internal BCS mirror struct ------------------------------------------------

/// BCS mirror of the on-chain `EvmScalarConfig` resource.
/// `SimpleMap<K, V>` serializes as `Vec<(K, V)>` in BCS.
/// All config values are plain u128 scalars; the Move type system enforces
/// type correctness at compile time.
#[derive(Deserialize, Serialize)]
struct RawEvmScalarConfig {
    config: Vec<(String, u128)>,
}

// -- OnChainEvmConfig ----------------------------------------------------------

/// The decoded, type-safe representation of the on-chain `EvmScalarConfig` resource.
#[derive(Clone, Debug, PartialEq)]
pub struct OnChainEvmConfig {
    pub config: BTreeMap<EvmScalarConfigKey, u128>,
}

impl OnChainEvmConfig {
    /// Convenience accessor for the EVM gas normalisation denominator.
    pub fn evm_gas_normalization_denom(&self) -> anyhow::Result<u128> {
        self.config
            .get(&EvmScalarConfigKey::EvmGasNormalizationDenom)
            .copied()
            .ok_or_else(|| anyhow::anyhow!("evm_gas_normalization_denom not found in EvmScalarConfig"))
    }
}

// `OnChainConfig` requires `DeserializeOwned` as a supertrait, but
// `OnChainEvmConfig` uses a fully custom `deserialize_into_config` path
// (parsing via `RawEvmScalarConfig`) so the standard serde path is never used.
// A manual impl that returns a clear error satisfies the bound without
// silently producing wrong data.
impl<'de> serde::Deserialize<'de> for OnChainEvmConfig {
    fn deserialize<D: serde::Deserializer<'de>>(_deserializer: D) -> Result<Self, D::Error> {
        Err(serde::de::Error::custom(
            "OnChainEvmConfig cannot be deserialised directly via serde; \
             use OnChainConfig::deserialize_into_config instead",
        ))
    }
}

impl OnChainConfig for OnChainEvmConfig {
    const MODULE_IDENTIFIER: &'static str = "evm_config";
    const TYPE_IDENTIFIER: &'static str = "EvmScalarConfig";

    fn deserialize_into_config(bytes: &[u8]) -> anyhow::Result<Self> {
        let raw: RawEvmScalarConfig = bcs::from_bytes(bytes)
            .map_err(|e| anyhow::anyhow!("failed to BCS-decode RawEvmScalarConfig: {}", e))?;

        let mut config = BTreeMap::new();
        for (key_str, value) in raw.config {
            // Skip keys that are not (yet) known to this codebase; this allows
            // the on-chain config to grow new entries without breaking older nodes.
            let key = match EvmScalarConfigKey::from_str(&key_str) {
                Ok(k) => k,
                Err(_) => continue,
            };
            config.insert(key, value);
        }

        // Hard-fail if any required key is absent - the node cannot operate
        // correctly without the full set of mandatory config values.
        for required_key in EvmScalarConfigKey::required_keys() {
            if !config.contains_key(required_key) {
                return Err(anyhow::anyhow!(
                    "required EvmScalarConfig key '{}' is missing from on-chain state",
                    required_key  // Display -> "evm_gas_normalization_denom"
                ));
            }
        }

        Ok(Self { config })
    }
}

#[cfg(test)]
mod unit_tests {
    use super::*;
    use crate::on_chain_config::{InMemoryOnChainConfig, OnChainConfig, OnChainConfigProvider};
    use std::collections::HashMap;

    // -- Helpers ---------------------------------------------------------------

    /// Returns a minimal `RawEvmScalarConfig` with `evm_gas_normalization_denom = denom`.
    fn raw_evm_scalar_config_with_denom(denom: u128) -> RawEvmScalarConfig {
        RawEvmScalarConfig {
            config: vec![(
                "evm_gas_normalization_denom".to_string(),
                denom,
            )],
        }
    }

    // -- OnChainEvmConfig deserialization --------------------------------------

    #[test]
    fn test_deserialize_evm_config_happy_path() {
        let bytes = bcs::to_bytes(&raw_evm_scalar_config_with_denom(100)).unwrap();
        let config = OnChainEvmConfig::deserialize_into_config(&bytes).unwrap();
        assert_eq!(config.evm_gas_normalization_denom().unwrap(), 100u128);
        // Exactly one known key decoded - no phantom entries.
        assert_eq!(config.config.len(), 1);
    }

    #[test]
    fn test_deserialize_evm_config_missing_required_key() {
        // Empty config - required key is absent.
        let raw = RawEvmScalarConfig { config: vec![] };
        let bytes = bcs::to_bytes(&raw).unwrap();
        let result = OnChainEvmConfig::deserialize_into_config(&bytes);
        assert!(result.is_err(), "expected Err when required key is missing");
        // Error message must name the missing key so operators can act on it.
        assert!(
            result
                .unwrap_err()
                .to_string()
                .contains("evm_gas_normalization_denom"),
            "error should identify the missing key"
        );
    }

    #[test]
    fn test_deserialize_evm_config_unknown_key_skipped() {
        // Unknown keys must be silently dropped so an older node binary can still
        // read a config that was extended with new keys by a newer software version.
        let raw = RawEvmScalarConfig {
            config: vec![
                ("evm_gas_normalization_denom".to_string(), 42u128),
                ("completely_unknown_key".to_string(), 7u128),
            ],
        };
        let bytes = bcs::to_bytes(&raw).unwrap();
        let config = OnChainEvmConfig::deserialize_into_config(&bytes).unwrap();
        assert_eq!(config.evm_gas_normalization_denom().unwrap(), 42u128);
        // Only the one known key should appear in the decoded map.
        assert_eq!(config.config.len(), 1);
    }

    // -- OnChainEvmContractsDetails round-trip ---------------------------------

    #[test]
    fn test_evm_contracts_details_round_trip() {
        // 20-byte EVM address placed in the lower 20 bytes of a 32-byte Move
        // address (upper 12 zeroed), matching the to_move_values encoding.
        let evm_bytes: RawEvmAddress = [
            0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd,
            0xee, 0xff, 0x00, 0x11, 0x22, 0x33,
        ];
        let original = OnChainEvmContractsDetails {
            name_to_addresses: [(EvmContractName::BlockMetadata, evm_bytes)].into(),
        };

        // Build the AccountAddress as to_move_values produces it on the wire.
        let mut padded = [0u8; AccountAddress::LENGTH];
        padded[AccountAddress::LENGTH - EVM_ADDRESS_LENGTH..].copy_from_slice(&evm_bytes);
        let on_chain_addr = AccountAddress::from(padded);

        // BCS-encode the on-chain representation (SimpleMap -> Vec<(K, V)>).
        let raw = EvmContractsDetails {
            details: vec![("BlockMetadata".to_string(), on_chain_addr)],
        };
        let bytes = bcs::to_bytes(&raw).unwrap();

        let recovered = OnChainEvmContractsDetails::deserialize_into_config(&bytes).unwrap();
        assert_eq!(recovered, original);
    }

    // -- Tier 2: InMemoryOnChainConfig provider --------------------------------

    #[test]
    fn test_fetch_evm_config_via_provider() {
        // Validates the full path: raw BCS bytes -> ConfigID lookup ->
        // deserialize_into_config -> typed accessor, without a running VM.
        let bytes = bcs::to_bytes(&raw_evm_scalar_config_with_denom(999)).unwrap();
        let mut map = HashMap::new();
        map.insert(OnChainEvmConfig::CONFIG_ID, bytes);
        let provider = InMemoryOnChainConfig::new(map);

        let config = provider.get::<OnChainEvmConfig>().unwrap();
        assert_eq!(config.evm_gas_normalization_denom().unwrap(), 999u128);
    }

    #[test]
    fn test_fetch_evm_contracts_details_via_provider() {
        // Same end-to-end path for OnChainEvmContractsDetails.
        let evm_bytes: RawEvmAddress = [
            0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
        ];
        let mut padded = [0u8; AccountAddress::LENGTH];
        padded[AccountAddress::LENGTH - EVM_ADDRESS_LENGTH..].copy_from_slice(&evm_bytes);

        let raw = EvmContractsDetails {
            details: vec![("BlockMetadata".to_string(), AccountAddress::from(padded))],
        };
        let bytes = bcs::to_bytes(&raw).unwrap();

        let mut map = HashMap::new();
        map.insert(OnChainEvmContractsDetails::CONFIG_ID, bytes);
        let provider = InMemoryOnChainConfig::new(map);

        let recovered = provider.get::<OnChainEvmContractsDetails>().unwrap();
        assert_eq!(recovered.get(EvmContractName::BlockMetadata), Some(&evm_bytes));
    }
}
