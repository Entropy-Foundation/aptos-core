use crate::dkg::state::DKGSessionMetadata;
use move_core_types::{
    ident_str, identifier::IdentStr, language_storage::TypeTag, move_resource::MoveStructType,
};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

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
    pub target_committees_public_key_shares: Vec<u8>,
}

impl MoveStructType for DKGFinishEvent {
    const MODULE_NAME: &'static IdentStr = ident_str!("dkg");
    const STRUCT_NAME: &'static IdentStr = ident_str!("DKGFinishEvent");
}

pub static DKG_FINISH_EVENT_MOVE_TYPE_TAG: Lazy<TypeTag> =
    Lazy::new(|| TypeTag::Struct(Box::new(DKGFinishEvent::struct_tag())));
