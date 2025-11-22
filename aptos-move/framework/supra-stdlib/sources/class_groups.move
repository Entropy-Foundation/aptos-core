// Copyright (c) 2024 Supra.
module supra_std::class_groups {

    use std::option;
    use std::option::Option;

    struct CGPublicKey has copy, drop, store {
        bytes: vector<u8>
    }

    #[test_only]
    struct SecretKey has copy, drop {
        bytes: vector<u8>,
    }

    /// Creates a new public key from a sequence of bytes.
    public fun public_key_from_bytes(bytes: vector<u8>): Option<CGPublicKey> {
        if (validate_pubkey_internal(bytes)) {
            option::some(CGPublicKey {
                bytes
            })
        } else {
            option::none<CGPublicKey>()
        }
    }

    /// Serializes a public key to a sequence of bytes.
    public fun public_key_to_bytes(pk: &CGPublicKey): vector<u8> {
        pk.bytes
    }

    #[test_only]
    /// Generates a class group key-pair: a secret key with its corresponding public key.
    public fun generate_keys(): (SecretKey, CGPublicKey) {
        let (sk_bytes, pk_bytes) = generate_keys_internal();
        let sk = SecretKey {
            bytes: sk_bytes
        };
        let pk = CGPublicKey {
            bytes: pk_bytes
        };
        (sk, pk)
    }

    native fun validate_pubkey_internal(public_key: vector<u8>): bool;
    #[test_only]
    native fun generate_keys_internal(): (vector<u8>, vector<u8>);
}
