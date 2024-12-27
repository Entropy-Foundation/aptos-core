use crate::{
    ed25519::{Ed25519PrivateKey, Ed25519PublicKey, ED25519_SIGNATURE_LENGTH},
    hash::CryptoHash,
    traits::*,
};
use anyhow::{anyhow, Result};
use aptos_crypto_derive::{DeserializeKey, SerializeKey};
use blsttc::SignatureG1;
use core::convert::TryFrom;
use serde::{Deserialize, Serialize};
use std::{cmp::Ordering, fmt};

/// An Ed25519 signature
#[derive(Deserialize, Clone, Serialize)]
pub struct BlsSignature(pub(crate) SignatureG1);

impl BlsSignature {
    /// The length of the BlsSignature
    pub const LENGTH: usize = 48;

    /// Serialize an BlsSignature.
    pub fn to_bytes(&self) -> [u8; 48] {
        self.0.to_bytes()
    }
}