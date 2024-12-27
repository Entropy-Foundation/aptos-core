#[cfg(any(test, feature = "fuzzing"))]
use crate::test_utils::{self, KeyPair};
use crate::{
    blsttc::{BlsSignature},
    traits::*,
};
use aptos_crypto_derive::{SilentDebug, SilentDisplay};
use core::convert::TryFrom;
#[cfg(any(test, feature = "fuzzing"))]
use proptest::prelude::*;
use serde::{Deserialize, Serialize};
use std::fmt;
use blsttc::{SecretKey, PublicKeyG2};

/// An Ed25519 private key
#[derive(Deserialize, Serialize, SilentDebug, SilentDisplay)]
pub struct BlsPrivateKey(pub(crate) SecretKey);

#[cfg(feature = "assert-private-keys-not-cloneable")]
static_assertions::assert_not_impl_any!(BlsPrivateKey: Clone);

#[cfg(any(test, feature = "cloneable-private-keys"))]
impl Clone for BlsPrivateKey {
    fn clone(&self) -> Self {
        let serialized: [u8;32] = self.0.to_bytes();
        BlsPrivateKey( SecretKey::from_bytes(serialized).unwrap() )
    }
}

/// An Ed25519 public key
#[derive(Deserialize, Clone, Serialize)]
pub struct BlsPublicKey(pub(crate) PublicKeyG2);

impl BlsPrivateKey {
    /// The length of the BlsPrivateKey
    pub const LENGTH: usize = 32;

    /// Serialize an BlsPrivateKey.
    pub fn to_bytes(&self) -> [u8; 32] {
        self.0.to_bytes()
    }

    pub fn generate_random() -> Self {
        Self(blsttc::SecretKey::random())
    }
    

    /// Deserialize an BlsPrivateKey without any validation checks apart from expected key size.
    fn from_bytes_unchecked(
        bytes: [u8;32],
    ) -> std::result::Result<BlsPrivateKey, CryptoMaterialError> {
        match SecretKey::from_bytes(bytes) {
            Ok(secret_key) => Ok(BlsPrivateKey(secret_key)),
            Err(_) => Err(CryptoMaterialError::DeserializationError),
        }
    }


    /// Private function aimed at minimizing code duplication between sign
    /// methods of the SigningKey implementation. This should remain private.
    fn sign_arbitrary_message(&self, message: &[u8]) -> BlsSignature {
        let secret_key: &SecretKey = &self.0;
        let sig = secret_key.sign_to_g1(message);
        BlsSignature(sig)
    }

}

impl PrivateKey for BlsPrivateKey {
    type PublicKeyMaterial = BlsPublicKey;
}


impl Uniform for BlsPrivateKey {
    fn generate<R>(rng: &mut R) -> Self
    where
        R: ::rand::RngCore + ::rand::CryptoRng + ::rand_core::CryptoRng + ::rand_core::RngCore,
    {
        BlsPrivateKey(SecretKey::random())
    }
}

impl PartialEq<Self> for BlsPrivateKey {
    fn eq(&self, other: &Self) -> bool {
        self.to_bytes() == other.to_bytes()
    }
}

impl Eq for BlsPrivateKey {}

impl TryFrom<&[u8]> for BlsPrivateKey {
    type Error = CryptoMaterialError;

    /// Deserialize an BlsPrivateKey. This method will check for private key validity: i.e.,
    /// correct key length.
    fn try_from(bytes: &[u8]) -> std::result::Result<BlsPrivateKey, CryptoMaterialError> {
        // Note that the only requirement is that the size of the key is 32 bytes, something that
        // is already checked during deserialization of ed25519_dalek::SecretKey
        //
        // Also, the underlying ed25519_dalek implementation ensures that the derived public key
        // is safe and it will not lie in a small-order group, thus no extra check for PublicKey
        // validation is required.
        let bytes: [u8;32] = bytes.try_into().unwrap();
        BlsPrivateKey::from_bytes_unchecked(bytes)
    }
}

impl Length for BlsPrivateKey {
    fn length(&self) -> usize {
        Self::LENGTH
    }
}

impl ValidCryptoMaterial for BlsPrivateKey {
    fn to_bytes(&self) -> Vec<u8> {
        self.to_bytes().to_vec()
    }
}

impl Genesis for BlsPrivateKey {
    fn genesis() -> Self {
        Self(SecretKey::random())
    }
}

impl BlsPublicKey {
    /// The maximum size in bytes.
    pub const LENGTH: usize = 96;

    /// Serialize an BlsPublicKey.
    pub fn to_bytes(&self) -> [u8; 96] {
        self.0.to_bytes()
    }

    pub fn from_publickeyg2(
        key: PublicKeyG2,
    ) -> Self {
        Self(key)
    }

    pub fn to_publickeyg2(
        &self
    ) -> blsttc::PublicKeyG2 {
        self.0.clone()
    }

    /// Deserialize an BlsPublicKey without any validation checks apart from expected key size
    /// and valid curve point, although not necessarily in the prime-order subgroup.
    ///
    /// This function does NOT check the public key for membership in a small subgroup.
    pub fn from_bytes_unchecked(
        bytes: [u8;96],
    ) -> std::result::Result<BlsPublicKey, CryptoMaterialError> {
        match PublicKeyG2::from_bytes(bytes) {
            Ok(public_key) => Ok(BlsPublicKey(public_key)),
            Err(_) => Err(CryptoMaterialError::DeserializationError),
        }
    }
}

impl From<&BlsPrivateKey> for BlsPublicKey {
    fn from(private_key: &BlsPrivateKey) -> Self {
        let secret: &SecretKey = &private_key.0;
        let public: PublicKeyG2 = secret.public_key_g2();
        BlsPublicKey(public)
    }
}

impl PublicKey for BlsPublicKey {
    type PrivateKeyMaterial = BlsPrivateKey;
}

impl std::hash::Hash for BlsPublicKey {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        let encoded_pubkey = self.to_bytes();
        state.write(&encoded_pubkey);
    }
}

// Those are required by the implementation of hash above
impl PartialEq for BlsPublicKey {
    fn eq(&self, other: &BlsPublicKey) -> bool {
        self.to_bytes() == other.to_bytes()
    }
}

impl Eq for BlsPublicKey {}

impl fmt::Display for BlsPublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", hex::encode(self.0.to_bytes()))
    }
}

impl fmt::Debug for BlsPublicKey {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "BlsPublicKey({})", self)
    }
}

impl TryFrom<&[u8]> for BlsPublicKey {
    type Error = CryptoMaterialError;

    /// Deserialize an BlsPublicKey. This method will NOT check for key validity, which means
    /// the returned public key could be in a small subgroup. Nonetheless, our signature
    /// verification implicitly checks if the public key lies in a small subgroup, so canonical
    /// uses of this library will not be susceptible to small subgroup attacks.
    fn try_from(bytes: &[u8]) -> std::result::Result<BlsPublicKey, CryptoMaterialError> {
        let bytes : [u8;96] = bytes.try_into().unwrap();
        Ok(BlsPublicKey(PublicKeyG2::from_bytes(bytes).unwrap()))
    }
}

impl Length for BlsPublicKey {
    fn length(&self) -> usize {
        96
    }
}

impl ValidCryptoMaterial for BlsPublicKey {
    fn to_bytes(&self) -> Vec<u8> {
        self.0.to_bytes().to_vec()
    }
}

/// Produces a uniformly random Ed25519 keypair from a seed
#[cfg(any(test, feature = "fuzzing"))]
pub fn keypair_strategy() -> impl Strategy<Value = KeyPair<BlsPrivateKey, BlsPublicKey>> {
    test_utils::uniform_keypair_strategy::<BlsPrivateKey, BlsPublicKey>()
}

/// Produces a uniformly random Ed25519 public key
#[cfg(any(test, feature = "fuzzing"))]
impl proptest::arbitrary::Arbitrary for BlsPublicKey {
    type Parameters = ();
    type Strategy = BoxedStrategy<Self>;

    fn arbitrary_with(_args: Self::Parameters) -> Self::Strategy {
        crate::test_utils::uniform_keypair_strategy::<BlsPrivateKey, BlsPublicKey>()
            .prop_map(|v| v.public_key)
            .boxed()
    }
}
