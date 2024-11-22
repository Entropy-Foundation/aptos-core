use crate::chain_id::ChainId;
use crate::transaction::{RawTransaction, Transaction, TransactionPayload};
use aptos_crypto::HashValue;
use move_core_types::account_address::AccountAddress;
use once_cell::sync::OnceCell;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::fmt::Debug;

/// A transaction that has been created based on the automation-task in automation registry.
///
/// A `AutomatedTransaction` is a single transaction that can be atomically executed.
/// `AutomatedTransaction`s are considered as internal transactions and submitted by the application
/// layer based on the registered tasks.
///
#[derive(Clone, Eq, Serialize, Deserialize)]
pub struct AutomatedTransaction {
    /// The raw transaction
    raw_txn: RawTransaction,

    /// Hash of the transaction which registered this automated transaction.
    authenticator: HashValue,

    /// Height of the block for which this transaction has been scheduled for execution.
    block_height: u64,

    /// A cached size of the raw transaction bytes.
    /// Prevents serializing the same transaction multiple times to determine size.
    #[serde(skip)]
    raw_txn_size: OnceCell<usize>,

    /// A cached hash of the transaction.
    #[serde(skip)]
    hash: OnceCell<HashValue>,
}

/// PartialEq ignores the cached OnceCell fields that may or may not be initialized.
impl PartialEq for AutomatedTransaction {
    fn eq(&self, other: &Self) -> bool {
        self.raw_txn == other.raw_txn && self.authenticator == other.authenticator
    }
}

impl Debug for AutomatedTransaction {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(
            f,
            "AutomatedTransaction {{ \n \
             {{ raw_txn: {:#?}, \n \
             authenticator: {:#?}, \n \
             }} \n \
             }}",
            self.raw_txn, self.authenticator
        )
    }
}

impl AutomatedTransaction {
    pub fn new(raw_txn: RawTransaction, authenticator: HashValue, block_height: u64) -> Self {
        Self {
            raw_txn,
            authenticator,
            block_height,
            raw_txn_size: Default::default(),
            hash: Default::default(),
        }
    }

    pub fn authenticator(&self) -> HashValue {
        self.authenticator
    }

    pub fn authenticator_ref(&self) -> &HashValue {
        &self.authenticator
    }

    pub fn sender(&self) -> AccountAddress {
        self.raw_txn.sender
    }

    pub fn into_raw_transaction(self) -> RawTransaction {
        self.raw_txn
    }

    pub fn raw_transaction_ref(&self) -> &RawTransaction {
        &self.raw_txn
    }

    pub fn sequence_number(&self) -> u64 {
        self.raw_txn.sequence_number
    }

    pub fn chain_id(&self) -> ChainId {
        self.raw_txn.chain_id
    }

    pub fn payload(&self) -> &TransactionPayload {
        &self.raw_txn.payload
    }

    pub fn max_gas_amount(&self) -> u64 {
        self.raw_txn.max_gas_amount
    }

    pub fn gas_unit_price(&self) -> u64 {
        self.raw_txn.gas_unit_price
    }

    pub fn expiration_timestamp_secs(&self) -> u64 {
        self.raw_txn.expiration_timestamp_secs
    }

    pub fn raw_txn_bytes_len(&self) -> usize {
        *self.raw_txn_size.get_or_init(|| {
            bcs::serialized_size(&self.raw_txn).expect("Unable to serialize RawTransaction")
        })
    }

    pub fn txn_bytes_len(&self) -> usize {
        let authenticator_size = HashValue::LENGTH;
        self.raw_txn_bytes_len() + authenticator_size
    }

    /// Returns the hash of the transaction.
    pub fn hash(&self) -> HashValue {
        *self.hash.get_or_init(|| {
            HashValue::sha3_256_of(
                &bcs::to_bytes(&self).expect("Unable to serialize AutomatedTransaction"),
            )
        })
    }
}

impl From<AutomatedTransaction> for Transaction {
    fn from(value: AutomatedTransaction) -> Self {
        Transaction::AutomatedTransaction(value)
    }
}
