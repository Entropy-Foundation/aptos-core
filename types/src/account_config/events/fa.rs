use derive_getters::Getters;
use move_core_types::{account_address::AccountAddress, ident_str, identifier::IdentStr, move_resource::MoveStructType};
use serde::{Deserialize, Serialize};

/// Represents a Deposit event for a Fungible Asset.
#[derive(Debug, Serialize, Deserialize, Getters)]
pub struct FaDeposit {
    store: AccountAddress,
    amount: u64,
}

/// Represents a Withdraw event for a Fungible Asset.
#[derive(Debug, Serialize, Deserialize, Getters)]
pub struct FaWithdraw {
    store: AccountAddress,
    amount: u64,
}

impl MoveStructType for FaDeposit {
    const MODULE_NAME: &'static IdentStr = ident_str!("fungible_asset");
    const STRUCT_NAME: &'static IdentStr = ident_str!("Deposit");
}

impl MoveStructType for FaWithdraw {
    const MODULE_NAME: &'static IdentStr = ident_str!("fungible_asset");
    const STRUCT_NAME: &'static IdentStr = ident_str!("Withdraw");
}
