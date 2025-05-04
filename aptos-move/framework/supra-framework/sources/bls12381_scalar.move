module supra_framework::bls12381_scalar {

    #[test_only]
    use std::vector;

    public fun bls12381_hash_to_scalar(
        dst: vector<u8>,
        msg: vector<u8>,
    ): vector<u8> {
        native_hash_to_scalar(dst, msg)
    }

    native fun native_hash_to_scalar(
        dst: vector<u8>,
        msg: vector<u8>,
    ): vector<u8>;

    #[test]
    public fun test_hash_to_scalar() {

        let msg: vector<u8> = b"1234";
        let dst: vector<u8> = b"5678";

        let scalar_bytes = bls12381_hash_to_scalar(msg, dst);
        assert!(!vector::is_empty(&scalar_bytes), 1);
    }

}
