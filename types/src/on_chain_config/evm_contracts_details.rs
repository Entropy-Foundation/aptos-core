// Copyright (c) 2026 Supra.
// SPDX-License-Identifier: Apache-2.0

use crate::on_chain_config::OnChainConfig;
use move_core_types::account_address::AccountAddress;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fmt::{Display, Formatter};
use std::str::FromStr;
use move_core_types::value::MoveValue;

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
            "AutomationController" => Ok(EvmContractName::AutomationController),
            "AutomationRegistry" => Ok(EvmContractName::AutomationRegistry),
            n => Ok(EvmContractName::Custom(n.to_string())),
        }
    }
}

impl Display for EvmContractName {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        match self {
            EvmContractName::BlockMetadata => write!(f, "BlockMetadata"),
            EvmContractName::AutomationController => write!(f, "AutomationController"),
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
        let (keys, values):(Vec<_>, Vec<_>) = self.name_to_addresses.into_iter().map(|(key, value)| {
            let mut padded = [0u8; AccountAddress::LENGTH];
            padded[..EVM_ADDRESS_LENGTH].copy_from_slice(&value);
            (MoveValue::vector_u8(key.to_string().into_bytes()),
                AccountAddress::from(padded)
            )
        }).unzip();
        (MoveValue::Vector(keys), MoveValue::vector_address(values))

    }

    pub fn get(&self, contract_name: EvmContractName) -> Option<&RawEvmAddress> {
        self.name_to_addresses.get(&contract_name)
    }

    pub fn has_all_keys(&self, keys: &[EvmContractName]) -> bool {
        keys.into_iter().all(|key| self.name_to_addresses.contains_key(key))
    }

}

impl OnChainConfig for OnChainEvmContractsDetails {
    const MODULE_IDENTIFIER: &'static str = "evm_contracts_details";
    const TYPE_IDENTIFIER: &'static str = "EvmContractsDetails";

    fn deserialize_into_config(bytes: &[u8]) -> anyhow::Result<Self> {
        let raw_details = bcs::from_bytes::<EvmContractsDetails>(bytes)?;
        let details = raw_details
            .details
            .into_iter()
            .filter_map(|(key, value)| {
                let name = EvmContractName::from_str(&key).ok()?;
                let evm_address: RawEvmAddress =
                    value.into_bytes()[..EVM_ADDRESS_LENGTH].try_into().ok()?;
                Some((name, evm_address))
            })
            .collect::<BTreeMap<_, _>>();
        Ok(Self {
            name_to_addresses: details,
        })
    }
}
