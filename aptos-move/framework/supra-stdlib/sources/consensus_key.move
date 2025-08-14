module supra_std::consensus_key {

    use std::error;
    use std::option;
    use std::option::Option;
    use std::vector;
    use aptos_std::bls12381;
    use aptos_std::ed25519;
    use supra_std::class_groups;
    #[test_only]
    use aptos_std::bls12381::public_key_with_pop_to_normal;

    /// Wrong number of bytes were given as input when deserializing an consensus public key.
    const E_WRONG_PUBKEY_SIZE: u64 = 1;

    /// Invalid consensus public key
    const EINVALID_PUBLIC_KEY: u64 = 2;

    /// The size of a serialized ed25519 public key, in bytes.
    const ED25519_PUBLIC_KEY_NUM_BYTES: u64 = 32;
    /// The size of a serialized bls12381 G1 public key, in bytes.
    const BLS12381_G1_PUBLIC_KEY_NUM_BYTES: u64 = 48;

    /// Consensus public key consists of:
    /// 1. Ed25519 key
    /// 2. Bls12381 G1 key
    /// 3. Class group encryption key
    struct ConsensusPublicKey has copy, drop, store {
        ed_key: ed25519::ValidatedPublicKey,
        bls_key: option::Option<bls12381::PublicKey>,
        cg_key: option::Option<class_groups::CGPublicKey>,
    }

    #[test_only]
    /// This struct holds consensus secret key that can be used during testing.
    struct SecretKey has drop {
        ed_key: ed25519::SecretKey,
        bls_key: bls12381::SecretKey,
        cg_key: class_groups::SecretKey,
    }

    public fun consensus_public_key_from_bytes(bytes: vector<u8>): Option<ConsensusPublicKey>{
        //todo: pop for ed and bls
        if (vector::length(&bytes) == ED25519_PUBLIC_KEY_NUM_BYTES){
            let ed_key_bytes = vector::slice(&bytes, 0, ED25519_PUBLIC_KEY_NUM_BYTES);
            let valid_ed_public_key = ed25519::new_validated_public_key_from_bytes(ed_key_bytes);
            assert!(option::is_some(&valid_ed_public_key), error::invalid_argument(EINVALID_PUBLIC_KEY));
            option::some(ConsensusPublicKey {
                ed_key: option::extract(&mut valid_ed_public_key),
                bls_key: option::none<bls12381::PublicKey>(),
                cg_key: option::none<class_groups::CGPublicKey>()
            })
        }
        else if (vector::length(&bytes) > ED25519_PUBLIC_KEY_NUM_BYTES + BLS12381_G1_PUBLIC_KEY_NUM_BYTES){

            let ed_key_bytes = vector::slice(&bytes, 0, ED25519_PUBLIC_KEY_NUM_BYTES);
            let bls_key_bytes = vector::slice(&bytes, ED25519_PUBLIC_KEY_NUM_BYTES, ED25519_PUBLIC_KEY_NUM_BYTES + BLS12381_G1_PUBLIC_KEY_NUM_BYTES);
            let cg_key_bytes = vector::slice(&bytes, ED25519_PUBLIC_KEY_NUM_BYTES + BLS12381_G1_PUBLIC_KEY_NUM_BYTES, vector::length(&bytes));

            let valid_ed_public_key = ed25519::new_validated_public_key_from_bytes(ed_key_bytes);
            assert!(option::is_some(&valid_ed_public_key), error::invalid_argument(EINVALID_PUBLIC_KEY));

            let valid_bls_public_key = bls12381::public_key_from_bytes(bls_key_bytes);
            assert!(option::is_some(&valid_bls_public_key), error::invalid_argument(EINVALID_PUBLIC_KEY));

            let valid_cg_public_key = class_groups::public_key_from_bytes(cg_key_bytes);
            assert!(option::is_some(&valid_cg_public_key), error::invalid_argument(EINVALID_PUBLIC_KEY));

            option::some(ConsensusPublicKey {
                ed_key: option::extract(&mut valid_ed_public_key),
                bls_key: valid_bls_public_key,
                cg_key: valid_cg_public_key
            })

        }
        else {
            option::none<ConsensusPublicKey>()
        }
    }

    public fun public_key_to_bytes(pk: ConsensusPublicKey): vector<u8>{

        let out = vector::empty<u8>();
        let ed_bytes  = ed25519::validated_public_key_to_bytes(&pk.ed_key);
        vector::append(&mut out, ed_bytes);

        if(option::is_some(&pk.bls_key) && option::is_some(&pk.cg_key)){
            let bls_key = option::extract(&mut pk.bls_key);
            let bls_bytes = bls12381::public_key_to_bytes(&bls_key);
            vector::append(&mut out, bls_bytes);

            let cg_key = option::extract(&mut pk.cg_key);
            let cg_bytes  = class_groups::public_key_to_bytes(&cg_key);
            vector::append(&mut out, cg_bytes);
        };
        out
    }

    #[test_only]
    /// Generates an Consensus key pair.
    public fun generate_keys(): (SecretKey, ConsensusPublicKey) {
        let (ed_sk, ed_pk) = ed25519::generate_keys();
        let (bls12381_sk, bls12381_pk) = bls12381::generate_keys();
        let (cg_sk, cg_pk) = class_groups::generate_keys();

        let sk = SecretKey{
            ed_key: ed_sk,
            bls_key: bls12381_sk,
            cg_key: cg_sk
        };

        let pk = ConsensusPublicKey{
            ed_key: ed_pk,
            bls_key: option::some(public_key_with_pop_to_normal(&bls12381_pk)),
            cg_key: option::some(cg_pk)
        };

        (sk,pk)
    }

}
