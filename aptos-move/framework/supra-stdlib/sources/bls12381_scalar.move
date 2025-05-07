module supra_std::bls12381_scalar {

    use std::option::Option;
    use aptos_std::bls12381_algebra::{Fr, FormatFrLsb};
    use aptos_std::crypto_algebra::{deserialize, Element};
    #[test_only]
    use std::option;
    #[test_only]
    use aptos_std::crypto_algebra::{eq, zero};

    public fun bls12381_hash_to_scalar(
        dst: vector<u8>,
        msg: vector<u8>,
    ): Option<Element<Fr>> {
        let scalar_bytes = native_hash_to_scalar(dst, msg);
        deserialize<Fr, FormatFrLsb>(&scalar_bytes)
    }

    native fun native_hash_to_scalar(
        dst: vector<u8>,
        msg: vector<u8>,
    ): vector<u8>;

    #[test]
    public fun test_hash_to_scalar() {

        let msg: vector<u8> = b"1234";
        let dst: vector<u8> = b"5678";

        let scalar = bls12381_hash_to_scalar(msg, dst);
        assert!(!eq<Fr>(&option::extract(&mut scalar), &zero<Fr>()) , 1);
    }

}
