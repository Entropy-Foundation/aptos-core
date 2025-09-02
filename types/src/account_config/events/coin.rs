use derive_getters::Getters;
use move_core_types::{
    account_address::AccountAddress, ident_str, identifier::IdentStr, move_resource::MoveStructType
};
use serde::{Deserialize, Serialize};


/// Module event emitted when some amount of a coin is deposited into an account.
#[derive(Debug, Serialize, Deserialize, Getters)]
pub struct CoinDeposit {
    coin_type: String,
    account: AccountAddress,
    amount: u64,
}

/// Module event emitted when some amount of a coin is withdrawn from an account.
#[derive(Debug, Serialize, Deserialize, Getters)]
pub struct CoinWithdraw {
    coin_type: String,
    account: AccountAddress,
    amount: u64,
}

impl MoveStructType for CoinWithdraw {
    const MODULE_NAME: &'static IdentStr = ident_str!("coin");
    const STRUCT_NAME: &'static IdentStr = ident_str!("CoinWithdraw");
}

impl MoveStructType for CoinDeposit {
    const MODULE_NAME: &'static IdentStr = ident_str!("coin");
    const STRUCT_NAME: &'static IdentStr = ident_str!("CoinDeposit");
}