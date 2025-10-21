// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use anyhow::{anyhow, Result};
use aptos_crypto_derive::{BCSCryptoHash, CryptoHasher};
use move_core_types::{
    ident_str, identifier::IdentStr, language_storage::TypeTag,
    move_resource::MoveStructType,
};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use std::{
    fmt::{Debug, Formatter},
};
use crate::dkg_committee::DkgCommittee;
use crate::on_chain_config::OnChainConfig;
use crypto::utils::{get_clan_node_indices, get_family_node_indices};
use aptos_crypto::bls12381::PublicKey;
use move_core_types::account_address::AccountAddress;
use crate::consensus_key::ConsensusPublicKey;

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq, Eq)]
pub enum DKGTransactionType{
    DKGMeta,
    PublicKeyShares,
}

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq, Eq, CryptoHasher, BCSCryptoHash)]
pub struct DKGTransactionMetadata {
    pub epoch: u64,
    pub author: AccountAddress,
    pub bls_aggregate_signature: Vec<u8>,
    pub signer_indices_clan_committee: Vec<u32>,
    pub transaction_type: DKGTransactionType
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DKGStartEvent {
    pub session_metadata: DKGSessionMetadata,
    pub start_time_us: u64,
}

impl MoveStructType for DKGStartEvent {
    const MODULE_NAME: &'static IdentStr = ident_str!("dkg");
    const STRUCT_NAME: &'static IdentStr = ident_str!("DKGStartEvent");
}

pub static DKG_START_EVENT_MOVE_TYPE_TAG: Lazy<TypeTag> =
    Lazy::new(|| TypeTag::Struct(Box::new(DKGStartEvent::struct_tag())));

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DKGMetaSetEvent {
    pub dkg_meta_transcript: Vec<u8>,
}

impl MoveStructType for DKGMetaSetEvent {
    const MODULE_NAME: &'static IdentStr = ident_str!("dkg");
    const STRUCT_NAME: &'static IdentStr = ident_str!("DKGMetaSetEvent");
}

pub static DKG_META_SET_EVENT_MOVE_TYPE_TAG: Lazy<TypeTag> =
    Lazy::new(|| TypeTag::Struct(Box::new(DKGMetaSetEvent::struct_tag())));

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct DKGFinishEvent {
    pub target_committees_public_key_shares: Vec<u8>
}

impl MoveStructType for DKGFinishEvent {
    const MODULE_NAME: &'static IdentStr = ident_str!("dkg");
    const STRUCT_NAME: &'static IdentStr = ident_str!("DKGFinishEvent");
}

pub static DKG_FINISH_EVENT_MOVE_TYPE_TAG: Lazy<TypeTag> =
    Lazy::new(|| TypeTag::Struct(Box::new(DKGFinishEvent::struct_tag())));

/// DKG transcript and its metadata.
#[derive(Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DKGTransactionData {
    pub metadata: DKGTransactionMetadata,
    #[serde(with = "serde_bytes")]
    pub data_bytes: Vec<u8>,
}

impl Debug for DKGTransactionData {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DKGTransactionData")
            .field("metadata", &self.metadata)
            .field("data_bytes_len", &self.data_bytes.len())
            .finish()
    }
}

impl DKGTransactionData {
    pub fn new(epoch: u64, author: AccountAddress, transcript_bytes: Vec<u8>, bls_aggregate_signature: Vec<u8>, signer_indices_clan_committee: Vec<u32>, transaction_type: DKGTransactionType) -> Self {
        Self {
            metadata: DKGTransactionMetadata { epoch, author, bls_aggregate_signature, signer_indices_clan_committee, transaction_type },
            data_bytes: transcript_bytes,
        }
    }

    pub fn dummy() -> Self {
        Self {
            metadata: DKGTransactionMetadata {
                epoch: 0,
                author: AccountAddress::ZERO,
                bls_aggregate_signature: vec![],
                signer_indices_clan_committee: vec![],
                transaction_type: DKGTransactionType::DKGMeta,
            },
            data_bytes: vec![],
        }
    }
}

/// Reflection of `0x1::dkg::DKGSessionMetadata` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionMetadata {
    pub dealer_epoch: u64,
    pub randomness_seed: Vec<u8>,
    pub dealer_committee: DkgCommittee,
    pub target_committees: Vec<DkgCommittee>,
}

impl DKGSessionMetadata {
    pub fn target_committee_cloned(&self) -> Vec<DkgCommittee> {
        self.target_committees
            .clone()
    }

    pub fn dealer_committee_cloned(&self) -> DkgCommittee {
        self.dealer_committee
            .clone()
    }
}

/// Reflection of Move type `0x1::dkg::DKGSessionState`.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionState {
    pub metadata: DKGSessionMetadata,
    pub start_time_us: u64,
    pub dkg_meta_transcript: Vec<u8>,
    pub target_committees_public_key_shares: Vec<u8>
}

impl DKGSessionState {
    pub fn target_epoch(&self) -> u64 {
        self.metadata.dealer_epoch + 1
    }
}
/// Reflection of Move type `0x1::dkg::DKGState`.
#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGState {
    pub last_completed: Option<DKGSessionState>,
    pub in_progress: Option<DKGSessionState>,
}

impl DKGState {
    pub fn maybe_last_complete(&self, epoch: u64) -> Option<&DKGSessionState> {
        match &self.last_completed {
            Some(session) if session.target_epoch() == epoch => Some(session),
            _ => None,
        }
    }

    pub fn maybe_in_progress(&self, epoch: u64) -> Option<&DKGSessionState> {
        match &self.in_progress {
            Some(session) if session.target_epoch() == epoch => Some(session),
            _ => None,
        }
    }

    pub fn last_complete(&self) -> &DKGSessionState {
        self.last_completed.as_ref().unwrap()
    }
}

impl OnChainConfig for DKGState {
    const MODULE_IDENTIFIER: &'static str = "dkg";
    const TYPE_IDENTIFIER: &'static str = "DKGState";
}

/// Reflection of Move type `0x1::dkg::DKGResharing`.
#[derive(Clone, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGResharing {
    pub is_resharing: bool,
}

impl OnChainConfig for DKGResharing {
    const MODULE_IDENTIFIER: &'static str = "dkg";
    const TYPE_IDENTIFIER: &'static str = "DKGResharing";
}

/// The threshold required to ensure the presence of honest majority in clan where
/// N = 2f+1 with f byzantine nodes
fn clan_threshold(total: u64)-> u64 {
    total / 2 + 1
}

pub fn get_clan_nodes_bls_keys_from_indices(dealer_committee: &DkgCommittee, signers: &Vec<u32>, random_seed: &Vec<u8>) -> Result<Vec<PublicKey>>{

    let committee = &dealer_committee.committee;
    let dealer_clan_committee_indices = get_clan_node_indices(committee.len() as u32, random_seed.clone());

    let mut clan_committee_bls_keys = Vec::new();
    if let Some(clan_committee_indices) = dealer_clan_committee_indices {
        let clan_threshold = clan_threshold(clan_committee_indices.len() as u64);

        if signers.len() as u64 !=  clan_threshold{
            return Err(anyhow!("dkg::number of signers must match clan_threshold"));
        }

        for signer in signers{
            let clan_node_index = clan_committee_indices[*signer as usize];
            let clan_node_pk = ConsensusPublicKey::try_from(committee[clan_node_index].dkg_pubkey.clone())
                .map_err(|e| anyhow!("dkg::node consensus public key deserialization failed: {e}"))?;
            let clan_node_bls_pubkey_bytes = clan_node_pk.bls_key
                .ok_or_else(|| anyhow!("dkg::node consensus bls key not found"))?;
            let clan_node_bls_pubkey = PublicKey::try_from(clan_node_bls_pubkey_bytes.as_slice())
                .map_err(|e| anyhow!("dkg::node bls public key deserialization failed: {e}"))?;
            clan_committee_bls_keys.push(clan_node_bls_pubkey);
        }
        Ok(clan_committee_bls_keys)
    }
    else {
        Err(anyhow!("dkg::cannot derive clan committee"))
    }
}

pub fn is_node_family_committee_member(addr: AccountAddress, dealer_committee: &DkgCommittee, random_seed: &Vec<u8>) -> bool {

    let family_committee_indices
        = get_family_node_indices(dealer_committee.committee.len() as u32, random_seed.clone());

    if let Some(family_node_indices) = family_committee_indices{
        let result = family_node_indices.iter().any(|x| dealer_committee.committee[*x].addr == addr);
        return result;
    }
    false
}
