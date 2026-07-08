// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::move_utils::move_event_v2::MoveEventV2Type;
use derive_getters::Getters;
use move_core_types::{
    account_address::AccountAddress, ident_str, identifier::IdentStr, language_storage::TypeTag,
    move_resource::MoveStructType,
};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

/// Struct that represents a Withdraw event.
#[derive(Debug, Serialize, Deserialize, Getters)]
pub struct WithdrawFAEvent {
    pub store: AccountAddress,
    pub amount: u64,
}

impl MoveEventV2Type for WithdrawFAEvent {}

impl MoveStructType for WithdrawFAEvent {
    const MODULE_NAME: &'static IdentStr = ident_str!("fungible_asset");
    const STRUCT_NAME: &'static IdentStr = ident_str!("Withdraw");
}

/// Struct that represents a Deposit event.
#[derive(Debug, Serialize, Deserialize, Getters)]
pub struct DepositFAEvent {
    pub store: AccountAddress,
    pub amount: u64,
}

impl MoveEventV2Type for DepositFAEvent {}

impl MoveStructType for DepositFAEvent {
    const MODULE_NAME: &'static IdentStr = ident_str!("fungible_asset");
    const STRUCT_NAME: &'static IdentStr = ident_str!("Deposit");
}

pub static FA_WITHDRAW_EVENT_TYPE_TAG: Lazy<TypeTag> =
    Lazy::new(|| TypeTag::Struct(Box::new(WithdrawFAEvent::struct_tag())));

pub static FA_DEPOSIT_EVENT_TYPE_TAG: Lazy<TypeTag> =
    Lazy::new(|| TypeTag::Struct(Box::new(DepositFAEvent::struct_tag())));
