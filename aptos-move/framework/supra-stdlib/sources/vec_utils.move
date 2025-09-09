module supra_std::vec_utils {
    use std::features;
    use std::vector;

    /// VEC_UTILS feature APIs are disabled.
    const EVEC_UTILS_FEATURE_DISABLED: u64 = 1;

    /// Function for serializing a vector<vector<u8>> into a vector<u8>.
    /// Serializes data to the format: [(length1 || data1), (length2 || data2), ...]
    /// Assumes each length is a u32 in little-endian order.
    public fun flatten_nested_vec_to_vec(data: vector<vector<u8>>): vector<u8>{
        assert!(features::supra_vec_utils_enabled(), EVEC_UTILS_FEATURE_DISABLED);
        let result = native_flatten_nested_vec_to_vec(data);
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

    /// Function for deserializing a vector<u8> into a vector<vector<u8>>.
    /// Input Format: [(length1 || data1), (length2 || data2), ...]
    /// Assumes each length is a u32 in little-endian order.
    public fun unflatten_vec_to_nested_vec(serialized: vector<u8>): vector<vector<u8>> {
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

    native fun native_flatten_nested_vec_to_vec(data: vector<vector<u8>>): vector<u8>;
}
