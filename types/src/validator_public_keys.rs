use derive_getters::Getters;
use serde::{Deserialize, Serialize};
use std::fmt;

/// Reflection of supra_framework::validator_public_keys::InternalPublicKeys in Rust
#[derive(Clone, Debug, Serialize, Deserialize, Getters)]
pub struct InternalPublicKeys {
    bls_multisig_key: Vec<u8>,
    bls_threshold_validity_certificate_key: Option<Vec<u8>>,
    bls_threshold_quorum_certificate_key: Option<Vec<u8>>,
    bls_threshold_unanimous_certificate_key: Option<Vec<u8>>,
    bls_threshold_bcft_validity_certificate_key: Option<Vec<u8>>,
    bls_threshold_bcft_quorum_certificate_key: Option<Vec<u8>>,
    bls_threshold_bcft_fallback_view_change_certificate_key: Option<Vec<u8>>,
    bls_threshold_clan_majority_certificate_key: Option<Vec<u8>>,
    class_group_key: Vec<u8>,
    ed25519_key: Vec<u8>,
}

/// Reflection of supra_framework::validator_public_keys::ValidatorPublicKeys in Rust
#[derive(Clone, Debug, Serialize, Deserialize, Getters)]
pub struct ValidatorPublicKeys {
    network_key: Vec<u8>,
    supra_keys: InternalPublicKeys,
}

impl ValidatorPublicKeys {
    pub fn new(
        network_key: Vec<u8>,
        bls_multisig_key: Vec<u8>,
        bls_threshold_validity_certificate_key: Option<Vec<u8>>,
        bls_threshold_quorum_certificate_key: Option<Vec<u8>>,
        bls_threshold_unanimous_certificate_key: Option<Vec<u8>>,
        bls_threshold_bcft_validity_certificate_key: Option<Vec<u8>>,
        bls_threshold_bcft_quorum_certificate_key: Option<Vec<u8>>,
        bls_threshold_bcft_fallback_view_change_certificate_key: Option<Vec<u8>>,
        bls_threshold_clan_majority_certificate_key: Option<Vec<u8>>,
        class_group_key: Vec<u8>,
        ed25519_key: Vec<u8>,
    ) -> Self {
        ValidatorPublicKeys {
            network_key,
            supra_keys: InternalPublicKeys {
                bls_multisig_key,
                bls_threshold_validity_certificate_key,
                bls_threshold_quorum_certificate_key,
                bls_threshold_unanimous_certificate_key,
                bls_threshold_bcft_validity_certificate_key,
                bls_threshold_bcft_quorum_certificate_key,
                bls_threshold_bcft_fallback_view_change_certificate_key,
                bls_threshold_clan_majority_certificate_key,
                class_group_key,
                ed25519_key,
            },
        }
    }
}

#[derive(Debug)]
pub enum ValidatorPublicKeysError {
    InvalidPublicKey,
}

impl fmt::Display for ValidatorPublicKeysError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ValidatorPublicKeysError::InvalidPublicKey => write!(f, "Invalid public key format"),
        }
    }
}

impl std::error::Error for ValidatorPublicKeysError {}

impl TryFrom<&Vec<u8>> for ValidatorPublicKeys {
    type Error = ValidatorPublicKeysError;

    fn try_from(bytes: &Vec<u8>) -> Result<Self, Self::Error> {
        let validator_public_keys: ValidatorPublicKeys =
            bcs::from_bytes(bytes).map_err(|_| ValidatorPublicKeysError::InvalidPublicKey)?;
        Ok(validator_public_keys)
    }
}
