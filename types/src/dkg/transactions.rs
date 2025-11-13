use aptos_crypto_derive::{BCSCryptoHash, CryptoHasher};
use derive_getters::Getters;
use move_core_types::account_address::AccountAddress;
use serde::{Deserialize, Serialize};
use std::fmt::{Debug, Formatter};

#[derive(Clone, Serialize, Deserialize, Debug, PartialEq, Eq)]
pub enum DKGTransactionType {
    DKGMeta,
    PublicKeyShares,
}

#[derive(
    Clone, Serialize, Deserialize, Debug, PartialEq, Eq, CryptoHasher, BCSCryptoHash, Getters,
)]
pub struct DKGTransactionMetadata {
    epoch: u64,
    author: AccountAddress,
    bls_aggregate_signature: Vec<u8>,
    signer_indices_clan_committee: Vec<u32>,
    transaction_type: DKGTransactionType,
}

/// DKG transcript and its metadata.
#[derive(Clone, Serialize, Deserialize, PartialEq, Eq, Getters)]
pub struct DKGTransactionData {
    metadata: DKGTransactionMetadata,
    #[serde(with = "serde_bytes")]
    data_bytes: Vec<u8>,
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
    pub fn new(
        epoch: u64,
        author: AccountAddress,
        transcript_bytes: Vec<u8>,
        bls_aggregate_signature: Vec<u8>,
        signer_indices_clan_committee: Vec<u32>,
        transaction_type: DKGTransactionType,
    ) -> Self {
        Self {
            metadata: DKGTransactionMetadata {
                epoch,
                author,
                bls_aggregate_signature,
                signer_indices_clan_committee,
                transaction_type,
            },
            data_bytes: transcript_bytes,
        }
    }
}

#[cfg(test)]
impl DKGTransactionData {
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
