use crate::{
    dkg::dkg_committee::{DkgCommittee, ReceiverCommittee},
    on_chain_config::OnChainConfig,
};
use serde::{Deserialize, Serialize};

// Reflection of `0x1::supra_dkg::DKGSessionMetadata` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionMetadata {
    pub dealer_epoch: u64,
    pub randomness_seed: Vec<u8>,
    pub dealer_committee: DkgCommittee,
    pub target_committees: Vec<ReceiverCommittee>,
}

impl DKGSessionMetadata {
    pub fn target_committee_cloned(&self) -> Vec<ReceiverCommittee> {
        self.target_committees.clone()
    }

    pub fn dealer_committee_cloned(&self) -> DkgCommittee {
        self.dealer_committee.clone()
    }
}

/// Reflection of Move type `0x1::supra_dkg::DKGSessionState`.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionState {
    pub metadata: DKGSessionMetadata,
    pub start_time_us: u64,
    pub dkg_meta_transcript: Vec<u8>,
    pub target_committees_public_key_shares: Vec<u8>,
}

impl DKGSessionState {
    pub fn target_epoch(&self) -> u64 {
        self.metadata.dealer_epoch + 1
    }
}
/// Reflection of Move type `0x1::supra_dkg::DKGState`.
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
    const MODULE_IDENTIFIER: &'static str = "supra_dkg";
    const TYPE_IDENTIFIER: &'static str = "DKGState";
}
