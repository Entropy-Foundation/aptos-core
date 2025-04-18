use crate::{
    on_chain_config::{OnChainConfig},
};
use move_core_types::{
    account_address::AccountAddress, ident_str, identifier::IdentStr, language_storage::TypeTag,
    move_resource::MoveStructType,
};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};
use std::{
    fmt::Debug,
};

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

/// Reflection of `0x1::dkg::DKGSessionMetadata` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionMetadata {
    pub dealer_epoch: u64,
    pub dkg_config: DkgConfig,
}

/// Reflection of `0x1::dkg_config::DkgConfig` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DkgConfig {
    pub dealer_clan_committee: Vec<DkgNodeConfig>,
    pub family_committee: Vec<DkgNodeConfig>,
    pub target_committee: Vec<DkgNodeConfig>,
}

/// Reflection of `0x1::dkg_config::DkgNodeConfig` in rust.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DkgNodeConfig {
    pub addr: AccountAddress,
    pub network_address: Vec<u8>,
    pub ed_pubkey: Vec<u8>,
    pub bls_pubkey: Vec<u8>,
    pub cg_pubkey: Vec<u8>,
}

impl DKGSessionMetadata {
    pub fn dkg_config(&self) -> DkgConfig {
        self.dkg_config.clone()
    }
}

/// Reflection of Move type `0x1::dkg::DKGSessionState`.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGSessionState {
    pub metadata: DKGSessionMetadata,
    pub start_time_us: u64,
    pub dkg_meta_transcript: Option<DKGMeta>,
}

/// Reflection of Move type `0x1::dkg::DKGMeta`.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DKGMeta {
    pub committee_pk: Vec<u8>,
    pub accumulation_value: Vec<u8>
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
