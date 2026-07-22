// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use self::real_dkg::RealDKG;
use crate::{
    dkg::{
        dkg_committee::DkgCommittee,
        real_dkg::{rounding::DKGRoundingProfile, Transcripts},
    },
    on_chain_config::{OnChainConfig, OnChainRandomnessConfig, RandomnessConfigMoveStruct},
    validator_public_keys::ValidatorPublicKeys,
    validator_verifier::{
        ValidatorConsensusInfo, ValidatorConsensusInfoMoveStruct, ValidatorVerifier,
    },
};
use anyhow::{anyhow, Context, Result};
use aptos_crypto::{bls12381::PublicKey, Uniform};
use aptos_crypto_derive::{BCSCryptoHash, CryptoHasher};
use crypto::utils::get_clan_node_indices;
use move_core_types::{
    account_address::AccountAddress, ident_str, identifier::IdentStr, language_storage::TypeTag,
    move_resource::MoveStructType,
};
use once_cell::sync::Lazy;
use rand::{CryptoRng, RngCore};
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeSet,
    fmt::{Debug, Formatter},
    time::Duration,
};

pub mod dummy_dkg;
pub mod real_dkg;

pub type DefaultDKG = RealDKG;

pub mod dkg_committee;
pub mod events;
pub mod state;
pub mod transactions;

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq, Eq, CryptoHasher, BCSCryptoHash)]
pub struct DKGTranscriptMetadata {
    pub epoch: u64,
    pub author: AccountAddress,
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

/// DKG transcript and its metadata.
#[derive(Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DKGTranscript {
    pub metadata: DKGTranscriptMetadata,
    #[serde(with = "serde_bytes")]
    pub transcript_bytes: Vec<u8>,
}

impl Debug for DKGTranscript {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("DKGTranscript")
            .field("metadata", &self.metadata)
            .field("transcript_bytes_len", &self.transcript_bytes.len())
            .finish()
    }
}

impl DKGTranscript {
    pub fn new(epoch: u64, author: AccountAddress, transcript_bytes: Vec<u8>) -> Self {
        Self {
            metadata: DKGTranscriptMetadata { epoch, author },
            transcript_bytes,
        }
    }

    pub fn dummy() -> Self {
        Self {
            metadata: DKGTranscriptMetadata {
                epoch: 0,
                author: AccountAddress::ZERO,
            },
            transcript_bytes: vec![],
        }
    }

    pub(crate) fn verify(&self, verifier: &ValidatorVerifier) -> Result<()> {
        let transcripts: Transcripts = bcs::from_bytes(&self.transcript_bytes)
            .context("Transcripts deserialization failed")?;
        RealDKG::verify_transcript_extra(&transcripts, verifier, true, None)
    }
}

/// Reflection of `0x1::dkg::DKGSessionMetadata` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionMetadata {
    pub dealer_epoch: u64,
    pub randomness_config: RandomnessConfigMoveStruct,
    pub dealer_validator_set: Vec<ValidatorConsensusInfoMoveStruct>,
    pub target_validator_set: Vec<ValidatorConsensusInfoMoveStruct>,
}

impl DKGSessionMetadata {
    pub fn target_validator_consensus_infos_cloned(&self) -> Vec<ValidatorConsensusInfo> {
        self.target_validator_set
            .clone()
            .into_iter()
            .map(|obj| obj.try_into().unwrap())
            .collect()
    }

    pub fn dealer_consensus_infos_cloned(&self) -> Vec<ValidatorConsensusInfo> {
        self.dealer_validator_set
            .clone()
            .into_iter()
            .map(|obj| obj.try_into().unwrap())
            .collect()
    }

    pub fn randomness_config_derived(&self) -> Option<OnChainRandomnessConfig> {
        OnChainRandomnessConfig::try_from(self.randomness_config.clone()).ok()
    }
}

impl MayHaveRoundingSummary for DKGSessionMetadata {
    fn rounding_summary(&self) -> Option<&RoundingSummary> {
        None
    }
}

/// Reflection of Move type `0x1::dkg::DKGSessionState`.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionState {
    pub metadata: DKGSessionMetadata,
    pub start_time_us: u64,
    pub transcript: Vec<u8>,
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

    pub fn last_complete(&self) -> &DKGSessionState {
        self.last_completed.as_ref().unwrap()
    }
}

impl OnChainConfig for DKGState {
    const MODULE_IDENTIFIER: &'static str = "dkg";
    const TYPE_IDENTIFIER: &'static str = "DKGState";
}

#[derive(Clone, Debug, Default)]
pub struct RoundingSummary {
    pub method: String,
    pub output: DKGRoundingProfile,
    pub error: Option<String>,
    pub exec_time: Duration,
}

pub trait MayHaveRoundingSummary {
    fn rounding_summary(&self) -> Option<&RoundingSummary>;
}

pub trait DKGTrait: Debug {
    type DealerPrivateKey;
    type PublicParams: Clone + Debug + Send + Sync + MayHaveRoundingSummary;
    type Transcript: Clone + Send + Sync + Serialize + for<'a> Deserialize<'a>;
    type InputSecret: Uniform;
    type DealtSecret;
    type DealtSecretShare;
    type DealtPubKeyShare;
    type NewValidatorDecryptKey: Uniform;

    fn new_public_params(dkg_session_metadata: &DKGSessionMetadata) -> Self::PublicParams;
    fn aggregate_input_secret(secrets: Vec<Self::InputSecret>) -> Self::InputSecret;
    fn dealt_secret_from_input(
        pub_params: &Self::PublicParams,
        input: &Self::InputSecret,
    ) -> Self::DealtSecret;
    fn generate_transcript<R: CryptoRng + RngCore>(
        rng: &mut R,
        params: &Self::PublicParams,
        input_secret: &Self::InputSecret,
        my_index: u64,
        sk: &Self::DealerPrivateKey,
    ) -> Self::Transcript;

    /// NOTE: used in VM.
    fn verify_transcript(params: &Self::PublicParams, trx: &Self::Transcript) -> Result<()>;

    fn verify_transcript_extra(
        trx: &Self::Transcript,
        verifier: &ValidatorVerifier,
        checks_voting_power: bool,
        ensures_single_dealer: Option<AccountAddress>,
    ) -> Result<()>;

    fn aggregate_transcripts(
        params: &Self::PublicParams,
        accumulator: &mut Self::Transcript,
        element: Self::Transcript,
    );

    fn decrypt_secret_share_from_transcript(
        pub_params: &Self::PublicParams,
        trx: &Self::Transcript,
        player_idx: u64,
        dk: &Self::NewValidatorDecryptKey,
    ) -> Result<(Self::DealtSecretShare, Self::DealtPubKeyShare)>;

    fn reconstruct_secret_from_shares(
        pub_params: &Self::PublicParams,
        player_share_pairs: Vec<(u64, Self::DealtSecretShare)>,
    ) -> Result<Self::DealtSecret>;
    fn get_dealers(transcript: &Self::Transcript) -> BTreeSet<u64>;
}

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
    let committee = dealer_committee.committee();
    let dealer_clan_committee_indices =
        get_clan_node_indices(committee.len() as u32, random_seed.clone());

    let mut clan_committee_bls_keys = Vec::new();
    if let Some(clan_committee_indices) = dealer_clan_committee_indices {
        let clan_threshold = clan_threshold(clan_committee_indices.len() as u64);

        if signers.len() as u64 != clan_threshold {
            return Err(anyhow!("dkg::number of signers must match clan_threshold"));
        }

        for signer in signers {
            let clan_node_index = clan_committee_indices
                .get(*signer as usize)
                .ok_or(anyhow!("dkg::node Invalid signer index: {signer}"))?;
            let clan_node_key = committee
                .get(*clan_node_index)
                .ok_or(anyhow!("dkg::node Invalid clan node index: {signer}"))?
                .dkg_pubkey();
            let clan_node_pk = ValidatorPublicKeys::try_from(clan_node_key).map_err(|e| {
                anyhow!("dkg::node validator public key deserialization failed: {e}")
            })?;
            let clan_node_bls_pubkey_bytes = clan_node_pk.supra_keys().bls_multisig_key();
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
