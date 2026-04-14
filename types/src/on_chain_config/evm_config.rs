// Copyright (c) 2026 Supra.
// SPDX-License-Identifier: Apache-2.0

use crate::on_chain_config::OnChainConfig;
use move_core_types::account_address::AccountAddress;
use move_core_types::language_storage::TypeTag;
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

// -- EvmConfigKey --------------------------------------------------------------

/// Typed keys for entries stored in the on-chain `EvmConfig` resource.
/// Only keys whose string representation is known at compile time are listed
/// here; unknown keys are silently skipped during deserialization.
#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize, Hash, PartialOrd, Ord)]
pub enum EvmConfigKey {
    EvmGasNormalizationDenom,
}

impl EvmConfigKey {
    /// The set of keys that MUST be present in the on-chain config.
    /// Deserialization will hard-fail if any of these is missing.
    pub fn required_keys() -> &'static [EvmConfigKey] {
        &[EvmConfigKey::EvmGasNormalizationDenom]
    }
}

impl FromStr for EvmConfigKey {
    type Err = anyhow::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "evm_gas_normalization_denom" => Ok(EvmConfigKey::EvmGasNormalizationDenom),
            _ => Err(anyhow::anyhow!("unknown evm config key: {}", s)),
        }
    }
}

impl Display for EvmConfigKey {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        // Mirror FromStr: Display produces the canonical snake_case string that
        // operators see in logs and error messages.
        match self {
            EvmConfigKey::EvmGasNormalizationDenom => write!(f, "evm_gas_normalization_denom"),
        }
    }
}

// -- EvmConfigValue ------------------------------------------------------------

/// Typed values decoded from the self-describing `copyable_any::Any` entries
/// stored in the on-chain `EvmConfig` resource.
///
/// Only the primitive Move types and shallow vector variants that are
/// realistically needed for EVM config are included.  Deeply nested or
/// generic types are not expected and are rejected at deserialization time.
#[derive(Clone, Debug, PartialEq)]
pub enum EvmConfigValue {
    U8(u8),
    U16(u16),
    U32(u32),
    U64(u64),
    U128(u128),
    U256(move_core_types::u256::U256),
    Bool(bool),
    Address(AccountAddress),
    VecU8(Vec<u8>),
    VecU16(Vec<u16>),
    VecU32(Vec<u32>),
    VecU64(Vec<u64>),
    VecU128(Vec<u128>),
    VecAddress(Vec<AccountAddress>),
}

impl EvmConfigValue {
    /// Decode a raw `Any` value given its Move `TypeTag` and BCS-encoded bytes.
    fn decode(type_tag: &TypeTag, data: &[u8]) -> anyhow::Result<Self> {
        match type_tag {
            TypeTag::U8 => Ok(Self::U8(bcs::from_bytes(data)?)),
            TypeTag::U16 => Ok(Self::U16(bcs::from_bytes(data)?)),
            TypeTag::U32 => Ok(Self::U32(bcs::from_bytes(data)?)),
            TypeTag::U64 => Ok(Self::U64(bcs::from_bytes(data)?)),
            TypeTag::U128 => Ok(Self::U128(bcs::from_bytes(data)?)),
            TypeTag::U256 => Ok(Self::U256(bcs::from_bytes(data)?)),
            TypeTag::Bool => Ok(Self::Bool(bcs::from_bytes(data)?)),
            TypeTag::Address => Ok(Self::Address(bcs::from_bytes(data)?)),
            TypeTag::Vector(inner) => match inner.as_ref() {
                TypeTag::U8 => Ok(Self::VecU8(bcs::from_bytes(data)?)),
                TypeTag::U16 => Ok(Self::VecU16(bcs::from_bytes(data)?)),
                TypeTag::U32 => Ok(Self::VecU32(bcs::from_bytes(data)?)),
                TypeTag::U64 => Ok(Self::VecU64(bcs::from_bytes(data)?)),
                TypeTag::U128 => Ok(Self::VecU128(bcs::from_bytes(data)?)),
                TypeTag::Address => Ok(Self::VecAddress(bcs::from_bytes(data)?)),
                other => Err(anyhow::anyhow!(
                    "unsupported vector element type: {}",
                    other
                )),
            },
            other => Err(anyhow::anyhow!(
                "unsupported evm config value type: {}",
                other
            )),
        }
    }

    /// Convenience accessor - returns the inner u64 or an error.
    pub fn as_u64(&self) -> anyhow::Result<u64> {
        match self {
            Self::U64(v) => Ok(*v),
            other => Err(anyhow::anyhow!("expected U64, got {:?}", other)),
        }
    }
}

// -- Internal BCS mirror structs -----------------------------------------------

/// BCS mirror of `copyable_any::Any` as it is stored on-chain.
/// The `type_name` field holds the string produced by `type_info::type_name<T>()`,
/// which is identical to the string that `TypeTag`'s `Display` impl emits, making
/// `TypeTag::from_str` the canonical inverse parser - no brittle hand-rolled matching.
#[derive(Deserialize, Serialize)]
struct RawAny {
    type_name: String,
    data: Vec<u8>,
}

/// BCS mirror of the on-chain `EvmConfig` resource.
/// `SimpleMap<K, V>` serializes as `Vec<(K, V)>` in BCS.
#[derive(Deserialize, Serialize)]
struct RawEvmConfig {
    config: Vec<(String, RawAny)>,
}

// -- OnChainEvmConfig ----------------------------------------------------------

/// The decoded, type-safe representation of the on-chain `EvmConfig` resource.
#[derive(Clone, Debug, PartialEq)]
pub struct OnChainEvmConfig {
    pub config: BTreeMap<EvmConfigKey, EvmConfigValue>,
}

impl OnChainEvmConfig {
    /// Convenience accessor for the EVM gas normalisation denominator.
    pub fn evm_gas_normalization_denom(&self) -> anyhow::Result<u64> {
        self.config
            .get(&EvmConfigKey::EvmGasNormalizationDenom)
            .ok_or_else(|| anyhow::anyhow!("evm_gas_normalization_denom not found in EvmConfig"))?
            .as_u64()
    }
}

// `OnChainConfig` requires `DeserializeOwned` as a supertrait, but
// `OnChainEvmConfig` uses a fully custom `deserialize_into_config` path
// (parsing via `RawEvmConfig`) so the standard serde path is never invoked.
// `EvmConfigValue` contains `U256` which only gets serde under a feature flag,
// so `#[derive(Deserialize)]` is not available here.  A manual impl that
// returns a clear error satisfies the bound without silently producing wrong data.
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
    const TYPE_IDENTIFIER: &'static str = "EvmConfig";

    fn deserialize_into_config(bytes: &[u8]) -> anyhow::Result<Self> {
        let raw: RawEvmConfig = bcs::from_bytes(bytes)
            .map_err(|e| anyhow::anyhow!("failed to BCS-decode RawEvmConfig: {}", e))?;

        let mut config = BTreeMap::new();
        for (key_str, raw_any) in raw.config {
            // Skip keys that are not (yet) known to this codebase; this allows
            // the on-chain config to grow new entries without breaking older nodes.
            let key = match EvmConfigKey::from_str(&key_str) {
                Ok(k) => k,
                Err(_) => continue,
            };
            // `type_info::type_name<T>()` in Move produces the same string that
            // `TypeTag`'s `Display` impl emits, so `TypeTag::from_str` is the
            // canonical inverse - no brittle hand-rolled string matching needed.
            let type_tag = TypeTag::from_str(&raw_any.type_name).map_err(|e| {
                anyhow::anyhow!(
                    "failed to parse type tag '{}' for key '{}': {}",
                    raw_any.type_name,
                    key_str,
                    e
                )
            })?;
            let value = EvmConfigValue::decode(&type_tag, &raw_any.data).map_err(|e| {
                anyhow::anyhow!(
                    "failed to decode value for key '{}' (type '{}'): {}",
                    key_str,
                    raw_any.type_name,
                    e
                )
            })?;
            config.insert(key, value);
        }

        // Hard-fail if any required key is absent - the node cannot operate
        // correctly without the full set of mandatory config values.
        for required_key in EvmConfigKey::required_keys() {
            if !config.contains_key(required_key) {
                return Err(anyhow::anyhow!(
                    "required EvmConfig key '{}' is missing from on-chain state",
                    required_key // Display -> "evm_gas_normalization_denom"
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
    use move_core_types::language_storage::TypeTag;
    use std::collections::HashMap;

    // -- Helpers ---------------------------------------------------------------

    /// Returns a minimal `RawEvmConfig` with `evm_gas_normalization_denom = denom`.
    fn raw_evm_config_with_denom(denom: u64) -> RawEvmConfig {
        RawEvmConfig {
            config: vec![(
                "evm_gas_normalization_denom".to_string(),
                RawAny {
                    // "u64" is the exact string type_info::type_name<u64>() produces
                    // in Move, which TypeTag::from_str("u64") = TypeTag::U64 round-trips.
                    type_name: "u64".to_string(),
                    data: bcs::to_bytes(&denom).unwrap(),
                },
            )],
        }
    }

    // -- OnChainEvmConfig deserialization --------------------------------------

    #[test]
    fn test_deserialize_evm_config_happy_path() {
        let bytes = bcs::to_bytes(&raw_evm_config_with_denom(100)).unwrap();
        let config = OnChainEvmConfig::deserialize_into_config(&bytes).unwrap();
        assert_eq!(config.evm_gas_normalization_denom().unwrap(), 100u64);
        // Exactly one known key decoded - no phantom entries.
        assert_eq!(config.config.len(), 1);
    }

    #[test]
    fn test_deserialize_evm_config_missing_required_key() {
        // Empty config - required key is absent.
        let raw = RawEvmConfig { config: vec![] };
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
        let raw = RawEvmConfig {
            config: vec![
                (
                    "evm_gas_normalization_denom".to_string(),
                    RawAny {
                        type_name: "u64".to_string(),
                        data: bcs::to_bytes(&42u64).unwrap(),
                    },
                ),
                (
                    "completely_unknown_key".to_string(),
                    RawAny {
                        type_name: "u8".to_string(),
                        data: bcs::to_bytes(&7u8).unwrap(),
                    },
                ),
            ],
        };
        let bytes = bcs::to_bytes(&raw).unwrap();
        let config = OnChainEvmConfig::deserialize_into_config(&bytes).unwrap();
        assert_eq!(config.evm_gas_normalization_denom().unwrap(), 42u64);
        // Only the one known key should appear in the decoded map.
        assert_eq!(config.config.len(), 1);
    }

    #[test]
    fn test_deserialize_evm_config_invalid_type_tag() {
        // A malformed type-name string must cause a clear error rather than
        // silently producing a wrong value.
        let raw = RawEvmConfig {
            config: vec![(
                "evm_gas_normalization_denom".to_string(),
                RawAny {
                    type_name: "not_a_valid_move_type".to_string(),
                    data: bcs::to_bytes(&100u64).unwrap(),
                },
            )],
        };
        let bytes = bcs::to_bytes(&raw).unwrap();
        assert!(
            OnChainEvmConfig::deserialize_into_config(&bytes).is_err(),
            "expected Err for an unrecognised type tag string"
        );
    }

    #[test]
    fn test_deserialize_evm_config_type_data_mismatch() {
        // type_name claims u64 (8 bytes) but data is a BCS bool (1 byte).
        // bcs::from_bytes::<u64> must fail on the short payload.
        let raw = RawEvmConfig {
            config: vec![(
                "evm_gas_normalization_denom".to_string(),
                RawAny {
                    type_name: "u64".to_string(),
                    data: bcs::to_bytes(&true).unwrap(), // 1-byte bool; u64 needs 8
                },
            )],
        };
        let bytes = bcs::to_bytes(&raw).unwrap();
        assert!(
            OnChainEvmConfig::deserialize_into_config(&bytes).is_err(),
            "expected Err when data bytes do not match declared type"
        );
    }

    // -- EvmConfigValue::decode ------------------------------------------------

    #[test]
    fn test_evm_config_value_decode_primitives() {
        // U8
        assert_eq!(
            EvmConfigValue::decode(&TypeTag::U8, &bcs::to_bytes(&7u8).unwrap()).unwrap(),
            EvmConfigValue::U8(7)
        );
        // U16
        assert_eq!(
            EvmConfigValue::decode(&TypeTag::U16, &bcs::to_bytes(&300u16).unwrap()).unwrap(),
            EvmConfigValue::U16(300)
        );
        // U32
        assert_eq!(
            EvmConfigValue::decode(&TypeTag::U32, &bcs::to_bytes(&70_000u32).unwrap()).unwrap(),
            EvmConfigValue::U32(70_000)
        );
        // U64
        assert_eq!(
            EvmConfigValue::decode(&TypeTag::U64, &bcs::to_bytes(&1_000_000u64).unwrap()).unwrap(),
            EvmConfigValue::U64(1_000_000)
        );
        // U128
        assert_eq!(
            EvmConfigValue::decode(&TypeTag::U128, &bcs::to_bytes(&u128::MAX).unwrap()).unwrap(),
            EvmConfigValue::U128(u128::MAX)
        );
        // Bool
        assert_eq!(
            EvmConfigValue::decode(&TypeTag::Bool, &bcs::to_bytes(&true).unwrap()).unwrap(),
            EvmConfigValue::Bool(true)
        );
        // Address
        assert_eq!(
            EvmConfigValue::decode(
                &TypeTag::Address,
                &bcs::to_bytes(&AccountAddress::ONE).unwrap()
            )
            .unwrap(),
            EvmConfigValue::Address(AccountAddress::ONE)
        );
    }

    #[test]
    fn test_evm_config_value_decode_vectors() {
        // VecU8
        let v: Vec<u8> = vec![1, 2, 3];
        assert_eq!(
            EvmConfigValue::decode(
                &TypeTag::Vector(Box::new(TypeTag::U8)),
                &bcs::to_bytes(&v).unwrap()
            )
            .unwrap(),
            EvmConfigValue::VecU8(v)
        );
        // VecU64
        let v: Vec<u64> = vec![10, 20, 30];
        assert_eq!(
            EvmConfigValue::decode(
                &TypeTag::Vector(Box::new(TypeTag::U64)),
                &bcs::to_bytes(&v).unwrap()
            )
            .unwrap(),
            EvmConfigValue::VecU64(v)
        );
        // VecAddress
        let v = vec![AccountAddress::ONE, AccountAddress::TWO];
        assert_eq!(
            EvmConfigValue::decode(
                &TypeTag::Vector(Box::new(TypeTag::Address)),
                &bcs::to_bytes(&v).unwrap()
            )
            .unwrap(),
            EvmConfigValue::VecAddress(v)
        );
    }

    #[test]
    fn test_evm_config_value_decode_unsupported_nested_vector() {
        // vector<vector<u8>> is not a supported config value type - must Err.
        let tag = TypeTag::Vector(Box::new(TypeTag::Vector(Box::new(TypeTag::U8))));
        let data = bcs::to_bytes(&vec![vec![1u8, 2u8]]).unwrap();
        assert!(
            EvmConfigValue::decode(&tag, &data).is_err(),
            "nested vector should be rejected as unsupported"
        );
    }

    #[test]
    fn test_evm_config_value_as_u64() {
        assert_eq!(EvmConfigValue::U64(42).as_u64().unwrap(), 42u64);
        assert!(EvmConfigValue::U8(1).as_u64().is_err());
        assert!(EvmConfigValue::Bool(true).as_u64().is_err());
        assert!(EvmConfigValue::Address(AccountAddress::ONE)
            .as_u64()
            .is_err());
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
        let bytes = bcs::to_bytes(&raw_evm_config_with_denom(999)).unwrap();
        let mut map = HashMap::new();
        map.insert(OnChainEvmConfig::CONFIG_ID, bytes);
        let provider = InMemoryOnChainConfig::new(map);

        let config = provider.get::<OnChainEvmConfig>().unwrap();
        assert_eq!(config.evm_gas_normalization_denom().unwrap(), 999u64);
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
