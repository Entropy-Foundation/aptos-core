module supra_std::vector_utils {

    use std::vector;

    /// Input vectors length does not match.
    const EINVALID_VECTOR_LENGHT: u64 = 1;

    /// Sorts values in ascending order.
    public fun sort_vector_u64(values: vector<u64>) : vector<u64> {
        native_sort_vector_u64(values)
    }

    /// Sorts values based on the input keys in ascending order.
    /// The keys and values should match in length, otherwise function will abort.
    public fun sort_vector_u64_by_keys(keys: vector<u64>, values: vector<u64>) : vector<u64> {
        assert!(vector::length(&keys) != vector::length(&values), EINVALID_VECTOR_LENGHT);
        native_sort_vector_u64_by_key(keys, values)
    }

    /// Sorts values in ascending order.
    native fun native_sort_vector_u64(values: vector<u64>): vector<u64>;

    /// Sorts values based on the input keys in ascending order.
    native fun native_sort_vector_u64_by_key(keys: vector<u64>, values: vector<u64>): vector<u64>;


    #[test_only]
    fun create_vector(size: u64): vector<u64> {
        let i = 0;
        let result = vector<u64>[];
        while (i < size) {
            if (i % 5 > 3) {
                vector::push_back(&mut result, i)
            } else {
                vector::insert(&mut result, 0, i)
            };
            i = i + 1
        };
        result
    }

    #[test]
    fun check_vector_u64() {
        let values = create_vector(500);
        let sorted = sort_vector_u64(values);
        // vector::enumerate_ref(&sorted, |idx, v| {
        //     assert!(idx == *v, 1);
        // });
    }
}
