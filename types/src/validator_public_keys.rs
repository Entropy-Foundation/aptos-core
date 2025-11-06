use std::fmt;

//TODO: Update this type according to ValidatorPublicKeys
/// Consensus public key consists of:
/// 1. Ed25519 key
/// 2. Bls12381 G1 key
/// 3. Class group encryption key
pub struct ConsensusPublicKey {
    pub ed_key: Vec<u8>,
    pub bls_key: Option<Vec<u8>>,
    pub cg_key: Option<Vec<u8>>,
}

#[derive(Debug)]
pub enum ConsensusKeyError {
    InvalidLength,
    InvalidPublicKey,
}

impl fmt::Display for ConsensusKeyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConsensusKeyError::InvalidLength => write!(f, "Invalid key length"),
            ConsensusKeyError::InvalidPublicKey => write!(f, "Invalid public key format"),
        }
    }
}

impl std::error::Error for ConsensusKeyError {}

impl TryFrom<Vec<u8>> for ConsensusPublicKey {
    type Error = ConsensusKeyError;

    fn try_from(bytes: Vec<u8>) -> Result<Self, Self::Error> {
        // Case 1: Only ED key present
        if bytes.len() == aptos_crypto::ed25519::ED25519_PUBLIC_KEY_LENGTH {
            Ok(Self {
                ed_key: bytes,
                bls_key: None,
                cg_key: None,
            })
        }
        // Case 2: ED + BLS + CG present
        else if bytes.len()
            > aptos_crypto::ed25519::ED25519_PUBLIC_KEY_LENGTH
                + aptos_crypto::bls12381::PublicKey::LENGTH
        {
            let ed_end = aptos_crypto::ed25519::ED25519_PUBLIC_KEY_LENGTH;
            let bls_end = ed_end + aptos_crypto::bls12381::PublicKey::LENGTH;

            let ed_key = bytes[0..ed_end].to_vec();
            let bls_key = Some(bytes[ed_end..bls_end].to_vec());
            let cg_key = Some(bytes[bls_end..].to_vec());

            Ok(Self {
                ed_key,
                bls_key,
                cg_key,
            })
        }
        // Otherwise: invalid input
        else {
            Err(ConsensusKeyError::InvalidLength)
        }
    }
}

impl ConsensusPublicKey {
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = self.ed_key.clone();

        if let (Some(bls_key), Some(cg_key)) = (&self.bls_key, &self.cg_key) {
            bytes.extend(bls_key);
            bytes.extend(cg_key);
        }
        bytes
    }
}
