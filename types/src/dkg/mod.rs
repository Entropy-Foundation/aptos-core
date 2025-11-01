// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{validator_public_keys::ConsensusPublicKey, dkg::dkg_committee::DkgCommittee};
use anyhow::{anyhow, Result};
use aptos_crypto::bls12381::PublicKey;
use crypto::utils::{get_clan_node_indices, get_family_node_indices};
use move_core_types::account_address::AccountAddress;

pub mod dkg_committee;
pub mod events;
pub mod state;
pub mod transactions;

/// The threshold required to ensure the presence of honest majority in clan where
/// N = 2f+1 with f byzantine nodes
fn clan_threshold(total: u64) -> u64 {
    total / 2 + 1
}

pub fn get_clan_nodes_bls_keys_from_indices(
    dealer_committee: &DkgCommittee,
    signers: &Vec<u32>,
    random_seed: &Vec<u8>,
) -> Result<Vec<PublicKey>> {
    let committee = &dealer_committee.committee;
    let dealer_clan_committee_indices =
        get_clan_node_indices(committee.len() as u32, random_seed.clone());

    let mut clan_committee_bls_keys = Vec::new();
    if let Some(clan_committee_indices) = dealer_clan_committee_indices {
        let clan_threshold = clan_threshold(clan_committee_indices.len() as u64);

        if signers.len() as u64 != clan_threshold {
            return Err(anyhow!("dkg::number of signers must match clan_threshold"));
        }

        for signer in signers {
            let clan_node_index = clan_committee_indices[*signer as usize];
            let clan_node_pk =
                ConsensusPublicKey::try_from(committee[clan_node_index].dkg_pubkey.clone())
                    .map_err(|e| {
                        anyhow!("dkg::node consensus public key deserialization failed: {e}")
                    })?;
            let clan_node_bls_pubkey_bytes = clan_node_pk
                .bls_key
                .ok_or_else(|| anyhow!("dkg::node consensus bls key not found"))?;
            let clan_node_bls_pubkey =
                PublicKey::try_from(clan_node_bls_pubkey_bytes.as_slice())
                    .map_err(|e| anyhow!("dkg::node bls public key deserialization failed: {e}"))?;
            clan_committee_bls_keys.push(clan_node_bls_pubkey);
        }
        Ok(clan_committee_bls_keys)
    } else {
        Err(anyhow!("dkg::cannot derive clan committee"))
    }
}

pub fn is_node_family_committee_member(
    addr: AccountAddress,
    dealer_committee: &DkgCommittee,
    random_seed: &Vec<u8>,
) -> bool {
    let family_committee_indices =
        get_family_node_indices(dealer_committee.committee.len() as u32, random_seed.clone());

    if let Some(family_node_indices) = family_committee_indices {
        let result = family_node_indices
            .iter()
            .any(|x| dealer_committee.committee[*x].addr == addr);
        return result;
    }
    false
}
