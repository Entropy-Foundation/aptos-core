// Copyright (c) 2024 Supra.
module supra_framework::validator_public_keys {
    use std::bcs;
    use std::error;
    use std::option;
    use aptos_std::any;
    use aptos_std::bls12381;
    use aptos_std::ed25519;
    use aptos_std::type_info;
    use supra_std::class_groups;
    #[test_only]
    use aptos_std::bls12381::public_key_with_pop_to_normal;
    #[test_only]
    use supra_framework::validator_public_keys;

    /// The integer should match the Rust enum value representation in `CertificateThresholdType`.
    /// f+1, given there are f Byzantine nodes in the [Committee].
    const CERTIFICATE_THRESHOLD_TYPE_VALIDITY: u8 = 0;
    /// The integer should match the Rust enum value representation in `CertificateThresholdType`.
    /// 2f+1, given there are f Byzantine nodes in the [Committee] and n >= 3f + 1 nodes in total.
    const CERTIFICATE_THRESHOLD_TYPE_QUORUM: u8 = 1;
    /// The integer should match the Rust enum value representation in `CertificateThresholdType`.
    /// n, where n is the total number of nodes in the [Committee].
    const CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS: u8 = 2;
    /// The integer should match the Rust enum value representation in `CertificateThresholdType`.
    /// f+1, given there are f Byzantine nodes and c crash-only nodes in the [Committee] with n >= 3f + 2c + 1 nodes.
    const CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY: u8 = 3;
    /// The integer should match the Rust enum value representation in `CertificateThresholdType`
    /// 2f + c + 1, given there are f Byzantine nodes and c crash-only nodes in the [Committee] with n >= 3f + 2c + 1 nodes.
    const CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM: u8 = 4;
    /// The integer should match the Rust enum value representation in `CertificateThresholdType`.
    /// n - f - c, given there are f Byzantine nodes and c crash-only nodes in the [Committee] with n >= 3f + 2c + 1 nodes.
    const CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE: u8 = 5;
    /// The integer should match the Rust enum value representation in `CertificateThresholdType`.
    /// f+1, given there are f Byzantine nodes in the [Committee] with n >= 2f + 1 nodes.
    const CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY: u8 = 6;

    /// Error: Unknown certificate threshold type.
    const EUNKNOWN_THRESHOLD_TYPE: u64 = 1;

    /// Internal tag wrapper
    struct CertificateThresholdType has copy, drop, store { tag: u8 }

    public fun validity_certificate_type(): CertificateThresholdType { CertificateThresholdType { tag: CERTIFICATE_THRESHOLD_TYPE_VALIDITY } }
    public fun quorum_certificate_type(): CertificateThresholdType { CertificateThresholdType { tag: CERTIFICATE_THRESHOLD_TYPE_QUORUM } }
    public fun unanimous_certificate_type(): CertificateThresholdType { CertificateThresholdType { tag: CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS } }
    public fun bcft_validity_certificate_type(): CertificateThresholdType { CertificateThresholdType { tag: CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY } }
    public fun bcft_quorum_certificate_type(): CertificateThresholdType { CertificateThresholdType { tag: CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM } }
    public fun bcft_fallback_view_change_certificate_type(): CertificateThresholdType { CertificateThresholdType { tag: CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE } }
    public fun clan_majority_certificate_type(): CertificateThresholdType { CertificateThresholdType { tag: CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY } }
     
    public fun is_validity_certificate_type(t: &CertificateThresholdType): bool { t.tag == CERTIFICATE_THRESHOLD_TYPE_VALIDITY }
    public fun is_quorum_certificate_type(t: &CertificateThresholdType): bool { t.tag == CERTIFICATE_THRESHOLD_TYPE_QUORUM }
    public fun is_unanimous_certificate_type(t: &CertificateThresholdType): bool { t.tag == CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS }
    public fun is_bcft_validity_certificate_type(t: &CertificateThresholdType): bool { t.tag == CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY }
    public fun is_bcft_quorum_certificate_type(t: &CertificateThresholdType): bool { t.tag == CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM }
    public fun is_bcft_fallback_view_change_certificate_type(t: &CertificateThresholdType): bool { t.tag == CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE }
    public fun is_clan_majority_certificate_type(t: &CertificateThresholdType): bool { t.tag == CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY }

    /// The size of a serialized ed25519 public key, in bytes.
    const ED25519_PUBLIC_KEY_NUM_BYTES: u64 = 32;
    /// The size of a serialized bls12381 G1 public key, in bytes.
    const BLS12381_G1_PUBLIC_KEY_NUM_BYTES: u64 = 48;

    /// InternalPublicKeys consists of:
    /// 1. bls multisig key
    /// 2. bls threshold key shares for various certificate types
    /// 3. classgroup key
    /// 4. ed25519 key
    struct InternalPublicKeys has copy, drop, store {
        bls_multisig_key: bls12381::PublicKey,
        bls_threshold_validity_certificate_key: option::Option<bls12381::PublicKey>,
        bls_threshold_quorum_certificate_key: option::Option<bls12381::PublicKey>,
        bls_threshold_unanimous_certificate_key: option::Option<bls12381::PublicKey>,
        bls_threshold_bcft_validity_certificate_key: option::Option<bls12381::PublicKey>,
        bls_threshold_bcft_quorum_certificate_key: option::Option<bls12381::PublicKey>,
        bls_threshold_bcft_fallback_view_change_certificate_key: option::Option<bls12381::PublicKey>,
        bls_threshold_clan_majority_certificate_key: option::Option<bls12381::PublicKey>,
        class_group_key: class_groups::CGPublicKey,
        ed25519_key: ed25519::ValidatedPublicKey,
    }

    /// ValidatorPublicKeys consists of:
    /// 1. network key
    /// 2. supra's internal keys
    struct ValidatorPublicKeys has copy, drop, store {
        network_key: ed25519::ValidatedPublicKey,
        supra_keys: InternalPublicKeys,
    }

    #[test_only]
    /// This struct holds calidator secret key that can be used during testing.
    struct ValidatorSecretKeys has drop {
        network_key: ed25519::SecretKey,
        supra_bls_multi_sig_bls_key: bls12381::SecretKey,
        supra_bls_threshold_validity_key: option::Option<bls12381::SecretKey>,
        supra_bls_threshold_quorum_key: option::Option<bls12381::SecretKey>,
        supra_bls_threshold_unanimous_key: option::Option<bls12381::SecretKey>,
        supra_bls_threshold_bcft_validity_key: option::Option<bls12381::SecretKey>,
        supra_bls_threshold_bcft_quorum_key: option::Option<bls12381::SecretKey>,
        supra_bls_threshold_bcft_fallback_view_change_key: option::Option<bls12381::SecretKey>,
        supra_bls_threshold_clan_majority_key: option::Option<bls12381::SecretKey>,
        cg_key: class_groups::SecretKey,
        supra_ed_key: ed25519::SecretKey,
    }

    public fun validator_public_keys_from_bytes(bytes: vector<u8>): ValidatorPublicKeys {
        // bcs deserialization
        let bytes_serialized = any::new(type_info::type_name<ValidatorPublicKeys>(), bytes);
        let validator_public_keys = any::unpack<ValidatorPublicKeys>(bytes_serialized);
        validator_public_keys
    }

    public fun public_key_to_bytes(pk: ValidatorPublicKeys): vector<u8>{
        // bcs deserialization
        bcs::to_bytes<ValidatorPublicKeys>(&pk)
    }

    public fun get_network_key(pk: &ValidatorPublicKeys): ed25519::ValidatedPublicKey{
        pk.network_key
    }

    public fun get_supra_bls_multi_sig_pub_key(pk: &ValidatorPublicKeys): bls12381::PublicKey{
        pk.supra_keys.bls_multisig_key
    }

    public fun get_supra_cg_key(pk: &ValidatorPublicKeys): class_groups::CGPublicKey{
        pk.supra_keys.class_group_key
    }

    public fun get_supra_ed_key(pk: &ValidatorPublicKeys): ed25519::ValidatedPublicKey{
        pk.supra_keys.ed25519_key
    }

    public fun rotate_supra_bls_threshold_validity_key(pk: &mut ValidatorPublicKeys, new_bls_threshold_validity_key: bls12381::PublicKey) {
        pk.supra_keys.bls_threshold_validity_certificate_key = option::some(new_bls_threshold_validity_key);
    }

    public fun rotate_supra_bls_threshold_quorum_key(pk: &mut ValidatorPublicKeys, new_bls_threshold_quorum_key: bls12381::PublicKey) {
        pk.supra_keys.bls_threshold_quorum_certificate_key = option::some(new_bls_threshold_quorum_key);
    }

    public fun rotate_supra_bls_threshold_unanimous_key(pk: &mut ValidatorPublicKeys, new_key: bls12381::PublicKey) {
        pk.supra_keys.bls_threshold_unanimous_certificate_key = option::some(new_key);
    }

    public fun rotate_supra_bls_threshold_bcft_validity_key(pk: &mut ValidatorPublicKeys, new_key: bls12381::PublicKey) {
        pk.supra_keys.bls_threshold_bcft_validity_certificate_key = option::some(new_key);
    }

    public fun rotate_supra_bls_threshold_bcft_quorum_key(pk: &mut ValidatorPublicKeys, new_key: bls12381::PublicKey) {
        pk.supra_keys.bls_threshold_bcft_quorum_certificate_key = option::some(new_key);
    }

    public fun rotate_supra_bls_threshold_bcft_fallback_view_change_key(pk: &mut ValidatorPublicKeys, new_key: bls12381::PublicKey) {
        pk.supra_keys.bls_threshold_bcft_fallback_view_change_certificate_key = option::some(new_key);
    }

    public fun rotate_supra_bls_threshold_clan_majority_key(pk: &mut ValidatorPublicKeys, new_key: bls12381::PublicKey) {
        pk.supra_keys.bls_threshold_clan_majority_certificate_key = option::some(new_key);
    }

    /// Rotate a threshold key based on the threshold type tag.
    /// threshold_type: 0=validity, 1=quorum, 2=unanimous, 3=bcft_validity, 4=bcft_quorum, 5=bcft_fallback_view_change, 6=clan_majority
    public fun rotate_supra_bls_threshold_key_by_type(pk: &mut ValidatorPublicKeys, threshold_type: u8, new_key: bls12381::PublicKey) {
        if (threshold_type == CERTIFICATE_THRESHOLD_TYPE_VALIDITY) {
            rotate_supra_bls_threshold_validity_key(pk, new_key);
        } else if (threshold_type == CERTIFICATE_THRESHOLD_TYPE_QUORUM) {
            rotate_supra_bls_threshold_quorum_key(pk, new_key);
        } else if (threshold_type == CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS) {
            rotate_supra_bls_threshold_unanimous_key(pk, new_key);
        } else if (threshold_type == CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY) {
            rotate_supra_bls_threshold_bcft_validity_key(pk, new_key);
        } else if (threshold_type == CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM) {
            rotate_supra_bls_threshold_bcft_quorum_key(pk, new_key);
        } else if (threshold_type == CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE) {
            rotate_supra_bls_threshold_bcft_fallback_view_change_key(pk, new_key);
        } else if (threshold_type == CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY) {
            rotate_supra_bls_threshold_clan_majority_key(pk, new_key);
        } else {
            abort error::invalid_argument(EUNKNOWN_THRESHOLD_TYPE)
        };
    }

    #[test_only]
    /// Generates validator key pair for testing.
    public fun generate_keys(): (ValidatorSecretKeys, ValidatorPublicKeys) {
        let (network_key_sk, network_key_pk) = ed25519::generate_keys();
        let (supra_bls12381_multi_sig_sk, supra_bls12381_multi_sig_pk) = bls12381::generate_keys();
        let (supra_cg_sk, supra_cg_pk) = class_groups::generate_keys();
        let (supra_ed_key_sk, supra_ed_key_pk) = ed25519::generate_keys();

        let sk = ValidatorSecretKeys{
            network_key: network_key_sk,
            supra_bls_multi_sig_bls_key: supra_bls12381_multi_sig_sk,
            supra_bls_threshold_validity_key: option::none(),
            supra_bls_threshold_quorum_key: option::none(),
            supra_bls_threshold_unanimous_key: option::none(),
            supra_bls_threshold_bcft_validity_key: option::none(),
            supra_bls_threshold_bcft_quorum_key: option::none(),
            supra_bls_threshold_bcft_fallback_view_change_key: option::none(),
            supra_bls_threshold_clan_majority_key: option::none(),
            cg_key: supra_cg_sk,
            supra_ed_key: supra_ed_key_sk,
        };

        let pk = ValidatorPublicKeys {
            network_key: network_key_pk,
            supra_keys: InternalPublicKeys{
                bls_multisig_key: public_key_with_pop_to_normal(&supra_bls12381_multi_sig_pk),
                bls_threshold_validity_certificate_key: option::none(),
                bls_threshold_quorum_certificate_key: option::none(),
                bls_threshold_unanimous_certificate_key: option::none(),
                bls_threshold_bcft_validity_certificate_key: option::none(),
                bls_threshold_bcft_quorum_certificate_key: option::none(),
                bls_threshold_bcft_fallback_view_change_certificate_key: option::none(),
                bls_threshold_clan_majority_certificate_key: option::none(),
                class_group_key: supra_cg_pk,
                ed25519_key: supra_ed_key_pk,
            },
        };

        (sk, pk)
    }

    #[test]
    fun test_serde_roundtrip() {
        // Generate full keypair
        let (_sk, pk) = validator_public_keys::generate_keys();

        // Serialize
        let bytes = validator_public_keys::public_key_to_bytes(pk);

        // Parse
        let parsed = validator_public_keys::validator_public_keys_from_bytes(bytes);

        // Compare network key
        let ed0 = get_network_key(&pk);
        let ed1 = get_network_key(&parsed);
        assert!(ed0 == ed1, 1001);

        // BLS multi sig equal
        let b0 = get_supra_bls_multi_sig_pub_key(&pk);
        let b1 = get_supra_bls_multi_sig_pub_key(&parsed);
        assert!(b0 == b1, 1002);

        // CG key equal
        let c0 = get_supra_cg_key(&pk);
        let c1 = get_supra_cg_key(&parsed);
        assert!(c0 == c1, 1003);

        // Compare ED bytes
        let ed0 = get_supra_ed_key(&pk);
        let ed1 = get_supra_ed_key(&parsed);
        assert!(ed0 == ed1, 1004);
    }
}
