// Copyright (c) Supra Foundation
// SPDX-License-Identifier: Apache-2.0

use super::OnChainConfig;
use crate::chain_id::ChainId;
use anyhow::{anyhow, Result};
use serde::{Deserialize, Serialize};

/// The Genesis configuration for EVM that can only be set once at genesis epoch.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct OnChainEvmGenesisConfig {
    /// The EVM chain ID, derived from the Move chain ID.
    chain_id: u64,
    /// The EOA configurations for pre-funding at genesis.
    eoas: Vec<GenesisEOA>,
    /// The contract configurations for deployment at genesis.
    contracts: Vec<GenesisContract>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct GenesisEOA {
    /// The address of the EOA to be funded
    pub address: String,
    /// The amount of native token to fund the EOA with.
    pub amount: u128,
}

/// The Creator address and nonce determines the contract' deployment address.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct GenesisContract {
    /// The creator address of the contract.
    pub creator: String,
    /// The nonce of the creator.
    pub nonce: u64,
    /// The amount of native token to fund the contract with.
    pub amount: u128,
    /// The bytecode of the contract to deploy.
    pub bytecode: Vec<u8>,
}

impl OnChainEvmGenesisConfig {
    /// Create a new OnChainEvmGenesisConfig with the given parameters.
    pub fn new(chain_id: ChainId, eoas: Vec<GenesisEOA>, contracts: Vec<GenesisContract>) -> Self {
        let chain_id = Self::derive_evm_chain_id_from_move_chain_id(chain_id);

        Self {
            chain_id,
            eoas,
            contracts,
        }
    }

    /// Derive the EVM chain ID from the Move chain ID.
    fn derive_evm_chain_id_from_move_chain_id(move_chain_id: ChainId) -> u64 {
        let chain_id = move_chain_id.id() as u64;
        chain_id << 32 | chain_id << 16 | chain_id
    }
}

/// This onchain config does not exist from genesis, until it is added by the governance proposal.
/// If the config is not found, Evm should not be enabled.
impl OnChainConfig for OnChainEvmGenesisConfig {
    const MODULE_IDENTIFIER: &'static str = "evm_genesis_config";
    const TYPE_IDENTIFIER: &'static str = "EvmGenesisConfig";

    /// The Move resource is
    /// ```ignore
    /// struct EvmGenesisConfig has copy, drop, store {
    ///    config: vector<u8>,
    /// }
    /// ```
    /// so we need two rounds of bcs deserilization to turn it back to EvmGenesisConfig
    fn deserialize_into_config(bytes: &[u8]) -> Result<Self> {
        let raw_bytes: Vec<u8> = bcs::from_bytes(bytes)?;
        bcs::from_bytes(&raw_bytes).map_err(|e| {
            anyhow!(
                "[on-chain evm genesis config] Failed to deserialize into config: {}",
                e
            )
        })
    }
}
