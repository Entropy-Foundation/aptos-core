// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::{aptos_dkg::DKGTranscript, dkg::transactions::DKGTransactionData, jwks};
use aptos_crypto_derive::{BCSCryptoHash, CryptoHasher};
use serde::{Deserialize, Serialize};
use std::fmt::Debug;

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize, CryptoHasher, BCSCryptoHash)]
pub enum ValidatorTransaction {
    DKG(DKGTransactionData),
    DKGResult(DKGTranscript),
    ObservedJWKUpdate(jwks::QuorumCertifiedUpdate),
}

impl ValidatorTransaction {
    #[cfg(any(test, feature = "fuzzing"))]
    pub fn dummy(payload: Vec<u8>) -> Self {
        Self::DKG(DKGTransactionData::new(
            999,
            move_core_types::account_address::AccountAddress::ZERO,
            payload,
            vec![],
            vec![],
            crate::dkg::transactions::DKGTransactionType::DKGMeta,
        ))
    }

    pub fn size_in_bytes(&self) -> usize {
        bcs::serialized_size(self).unwrap()
    }

    pub fn topic(&self) -> Topic {
        match self {
            ValidatorTransaction::DKG(_) => Topic::DKG,
            ValidatorTransaction::DKGResult(_) => Topic::DKG_RESULT,
            ValidatorTransaction::ObservedJWKUpdate(update) => {
                Topic::JWK_CONSENSUS(update.update.issuer.clone())
            },
        }
    }

    pub fn type_name(&self) -> &'static str {
        match self {
            ValidatorTransaction::DKG(_) => "validator_transaction__dkg",
            ValidatorTransaction::DKGResult(_) => "validator_transaction__dkg_result",
            ValidatorTransaction::ObservedJWKUpdate(_) => {
                "validator_transaction__observed_jwk_update"
            },
        }
    }
}

#[derive(Clone, Debug, Eq, Hash, PartialEq)]
#[allow(non_camel_case_types)]
pub enum Topic {
    DKG,
    DKG_RESULT,
    JWK_CONSENSUS(jwks::Issuer),
}
