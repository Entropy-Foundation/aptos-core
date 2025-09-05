module supra_std::rlp {

    use std::bcs;
    use std::features;
    use std::vector;

    /// SUPRA_RLP_ENCODE feature APIs are disabled.
    const ERLP_ENCODE_FEATURE_DISABLED: u64 = 1;


    // Encode/Decode for type T
    // Types supported: bool, u8, u16, u32, u64, u128, address, vector<u8>
    // Attempting to encode any other type results in E_UNSUPPORTED_TYPE error
    public fun encode<T>(x: T): vector<u8> {
        assert!(features::supra_rlp_enabled(), ERLP_ENCODE_FEATURE_DISABLED);
        native_rlp_encode(x)
    }

    public fun decode<T>(encoded_rlp: vector<u8>): T {
        assert!(features::supra_rlp_enabled(), ERLP_ENCODE_FEATURE_DISABLED);
        native_rlp_decode(encoded_rlp)
    }

    // Encode/Decode for list
    // Type of lists supported: bool, u8, u16, u32, u64, u128, address
    // Attempting to encode any other type results in E_UNSUPPORTED_TYPE error
    public fun encode_list_scalar<T: drop>(data: vector<T>): vector<u8> {
        assert!(features::supra_rlp_enabled(), ERLP_ENCODE_FEATURE_DISABLED);
        native_rlp_encode_list_scalar<T>(bcs::to_bytes(&data))
    }

    public fun decode_list_scalar<T>(encoded_rlp: vector<u8>): vector<T> {
        assert!(features::supra_rlp_enabled(), ERLP_ENCODE_FEATURE_DISABLED);
        native_rlp_decode_list_scalar<T>(encoded_rlp)
    }

    // Encode/Decode for list of byte arrays: (vec[vec[u8], vec[u8], ..])
    public fun encode_list_byte_array(data: vector<vector<u8>>): vector<u8> {
        assert!(features::supra_rlp_enabled(), ERLP_ENCODE_FEATURE_DISABLED);
        native_rlp_encode_list_byte_array(bcs::to_bytes(&data))
    }

    /// Helper function for deserializing output of native_rlp_decode_list_byte_array
    /// Deserializes a vector<u8> into a vector<vector<u8>>.
    /// Format: [len1 (u32), data1, len2 (u32), data2, ...]
    fun deserialize_vec_vec_u8(serialized: vector<u8>): vector<vector<u8>> {
        let result = vector::empty<vector<u8>>();
        let i:u64 = 0;
        let len = vector::length(&serialized);

        while (i < len) {
            // Read the next 4 bytes as the length of the inner vector
            let len_inner = read_u32(&serialized, i);
            i = i + 4;

            // Extract the next len_inner bytes as the inner vector
            let inner_vec = vector::empty<u8>();
            let j = 0;
            while (j < len_inner) {
                vector::push_back(&mut inner_vec, *vector::borrow(&serialized, i + (j as u64)));
                j = j + 1;
            };
            vector::push_back(&mut result, inner_vec);
            i = i + (len_inner as u64);
        };
        result
    }

    /// Reads a u32 from a vector<u8> at position i in little-endian order.
    fun read_u32(data: &vector<u8>, i: u64): u32 {
        let b0 = (*vector::borrow(data, i) as u32);
        let b1 = (*vector::borrow(data, i + 1) as u32);
        let b2 = (*vector::borrow(data, i + 2) as u32);
        let b3 = (*vector::borrow(data, i + 3) as u32);
        b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    public fun decode_list_byte_array(encoded_rlp: vector<u8>): vector<vector<u8>> {
        assert!(features::supra_rlp_enabled(), ERLP_ENCODE_FEATURE_DISABLED);
        let ser_result = native_rlp_decode_list_byte_array(encoded_rlp);
        deserialize_vec_vec_u8(ser_result)
    }

    //
    // Native functions
    //
    native fun native_rlp_encode<T>(x: T): vector<u8>;
    native fun native_rlp_decode<T>(data: vector<u8>): T;

    native fun native_rlp_encode_list_scalar<T>(x: vector<u8>): vector<u8>;
    native fun native_rlp_decode_list_scalar<T>(data: vector<u8>): vector<T>;

    native fun native_rlp_encode_list_byte_array(x: vector<u8>): vector<u8>;
    native fun native_rlp_decode_list_byte_array(data: vector<u8>): vector<u8>;
}
