module supra_std::vector_utils {

    /// Sorts values in ascending order.
    public fun sort_vector_u64(values: vector<u64>) : vector<u64> {
        native_sort_vector_u64(values)
    }

    /// Sorts values based on the input keys in ascending order.
    /// The keys and values should match in lenght, otherwise function will abort.
    public fun sort_vector_u64_by_keys(keys: vector<u64>, values: vector<u64>) : vector<u64> {
        native_sort_vector_u64_by_key(keys, values)
    }

    /// Sorts values in ascending order.
    native fun native_sort_vector_u64(values: vector<u64>): vector<u64>;

    /// Sorts values based on the input keys in ascending order.
    /// The keys and values should match in lenght, otherwise function will abort.
    native fun native_sort_vector_u64_by_key(keys: vector<u64>, values: vector<u64>): vector<u64>;
}
