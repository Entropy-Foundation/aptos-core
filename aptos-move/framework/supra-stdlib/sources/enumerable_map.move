/// This module provides an implementation of an enumerable map, a data structure that maintains key-value pairs with
/// efficient operations for addition, removal, and retrieval.
/// It allows for enumeration of keys in insertion order, bulk operations, and updates while ensuring data consistency.
/// The module includes error handling and a suite of test functions for validation.
module supra_std::enumerable_map {
    use std::error;
    use std::vector;
    use aptos_std::table;

    /// Key is already present in the map
    const EKEY_ALREADY_ADDED: u64 = 1;
    /// Key is absent in the map
    const EKEY_ABSENT: u64 = 2;
    /// Vector is empty
    const EVECTOR_EMPTY: u64 = 3;

    /// Enumerable Map to store the key value pairs
    struct EnumerableMap<K : copy + drop, V : store+drop+copy> has store {
        /// List of all keys
        list: vector<K>,
        /// Key mapped to a tuple containing the (position of key in list and value corresponding to the key)
        map: table::Table<K, Tuple<V>>,
    }

    /// Tuple to store the position of key in list and value corresponding to the key
    struct Tuple<V : store+drop+copy> has store, copy, drop {
        position: u64,
        value: V,
    }

    /// Return type
    struct KeyValue<K : copy + drop, V : store+drop+copy> has store, copy, drop {
        key: K,
        value: V,
    }

    /// To create an empty enum map
    public fun new_map<K : copy + drop, V : store+drop+copy>(): EnumerableMap<K, V> {
        return EnumerableMap<K, V> { list: vector::empty<K>(), map: table::new<K, Tuple<V>>() }
    }

    /// Add Single Key in the Enumerable Map
    public fun add_value<K : copy+drop, V : store+drop+copy>(map: &mut EnumerableMap<K, V>, key: K, value: V) {
        assert!(!contains(map, key), error::already_exists(EKEY_ALREADY_ADDED));
        table::add(&mut map.map, key, Tuple<V> { position: vector::length(&map.list), value });
        vector::push_back(&mut map.list, key);
    }

    /// Add Multiple Keys in the Enumerable Map
    public fun add_value_bulk<K: copy+drop, V : store+drop+copy>(
        map: &mut EnumerableMap<K, V>,
        keys: vector<K>,
        values: vector<V>
    ): vector<K> {
        assert!(!vector::is_empty(&values), error::invalid_argument(EVECTOR_EMPTY));
        let current_key_list_length = vector::length(&map.list);
        let updated_keys = vector::empty<K>();

        vector::zip_reverse(keys, values, |key, value| {
            if (!contains(map, key)) {
                table::add(&mut map.map, key, Tuple<V> { position: current_key_list_length, value });
                vector::push_back(&mut map.list, key);
                current_key_list_length = current_key_list_length + 1;

                vector::push_back(&mut updated_keys, key);
            };
        });

        return updated_keys
    }

    /// Update the value of a key thats already present in the Enumerable Map
    public fun update_value<K: copy+drop, V : store+drop+copy>(
        map: &mut EnumerableMap<K, V>,
        key: K,
        new_value: V
    ): KeyValue<K, V> {
        assert!(contains(map, key), error::not_found(EKEY_ABSENT));
        table::borrow_mut(&mut map.map, key).value = new_value;
        KeyValue { key, value: new_value }
    }

    /// Remove single Key from the Enumerable Map
    public fun remove_value<K : copy+drop, V : store+drop+copy>(map: &mut EnumerableMap<K, V>, key: K) {
        assert!(contains(map, key), error::not_found(EKEY_ABSENT));

        let map_last_index = vector::length(&map.list) - 1;
        let index_of_element = table::borrow(&map.map, key).position;
        let tuple_to_modify = table::borrow_mut(&mut map.map, *vector::borrow(&map.list, map_last_index));

        vector::swap(&mut map.list, index_of_element, map_last_index);
        tuple_to_modify.position = index_of_element;
        vector::pop_back(&mut map.list);
        table::remove(&mut map.map, key);
    }

    /// Remove Multiple Keys from the Enumerable Map
    public fun remove_value_bulk<K : copy+drop, V : store+drop+copy>(
        map: &mut EnumerableMap<K, V>,
        keys: vector<K>
    ): vector<K> {
        assert!(!vector::is_empty(&keys), error::invalid_argument(EVECTOR_EMPTY));

        let map_length = vector::length(&map.list);
        let removed_keys = vector::empty<K>();

        vector::for_each_reverse(keys, |key| {
            if (contains(map, key)) {
                let index_of_element = table::borrow(&map.map, key).position;
                map_length = map_length - 1;
                let tuple_to_modify = table::borrow_mut(&mut map.map, *vector::borrow(&map.list, map_length));
                vector::swap(&mut map.list, index_of_element, map_length);
                tuple_to_modify.position = index_of_element;
                vector::pop_back(&mut map.list);
                table::remove(&mut map.map, key);

                vector::push_back(&mut removed_keys, key);
            };
        });

        return removed_keys
    }

    /// Will clear the entire data from the Enumerable Map
    public fun clear<K : copy+drop, V : store+drop+copy>(map: &mut EnumerableMap<K, V>) {
        let list = get_map_list(map);
        remove_value_bulk(map, list);
    }

    /// Returns the value of a key that is present in Enumerable Map
    public fun get_value<K : copy+drop, V : store+drop+copy>(map: & EnumerableMap<K, V>, key: K): V {
        table::borrow(&map.map, key).value
    }

    /// Returns the list of keys that the Enumerable Map contains
    public fun get_map_list<K : copy+drop, V : store+drop+copy>(map: &EnumerableMap<K, V>): vector<K> {
        return map.list
    }

    /// Check whether Key is present into the Enumerable map or not
    public fun contains<K: copy+drop, V : store+drop+copy>(map: &EnumerableMap<K, V>, key: K): bool {
        table::contains(&map.map, key)
    }

    /// Return current length of the EnumerableSetRing
    public fun length<K : copy+drop, V : store+drop+copy>(set: &EnumerableMap<K, V>): u64 {
        return vector::length(&set.list)
    }

    #[test_only]
    struct EnumerableMapTest<K: copy + drop, V : store+drop+copy> has key {
        e: EnumerableMap<K, V>
    }

    #[test(owner= @0x1111)]
    public fun test_add_value(owner: &signer) {
        let enum_map = new_map<u256, u256>();

        add_value(&mut enum_map, 1, 1);
        add_value(&mut enum_map, 2, 2);
        add_value(&mut enum_map, 3, 3);
        add_value(&mut enum_map, 4, 4);
        add_value(&mut enum_map, 5, 5);
        add_value(&mut enum_map, 6, 6);

        assert!(contains(&enum_map, 3), 1);
        assert!(length(&enum_map) == 6, 2);

        move_to(owner, EnumerableMapTest { e: enum_map })
    }

    #[test(owner= @0x1111)]
    public fun test_add_value_bulk(owner: &signer) {
        let enum_map = new_map<u256, u256>();

        add_value(&mut enum_map, 1, 1);
        add_value(&mut enum_map, 2, 2);
        add_value(&mut enum_map, 3, 3);
        add_value(&mut enum_map, 4, 4);
        add_value(&mut enum_map, 5, 5);
        add_value(&mut enum_map, 6, 6);

        add_value_bulk(&mut enum_map, vector[7, 8, 9], vector[7, 8, 9]);

        assert!(contains(&enum_map, 8), 1);
        assert!(length(&enum_map) == 9, 2);

        move_to(owner, EnumerableMapTest { e: enum_map });
    }

    #[test(owner= @0x1111)]
    #[expected_failure(abort_code = 1, location = Self)]
    public fun test_remove_value(owner: &signer) {
        let enum_map = new_map<u256, u256>();

        add_value(&mut enum_map, 1, 1);
        add_value(&mut enum_map, 2, 2);
        add_value(&mut enum_map, 3, 3);
        add_value(&mut enum_map, 4, 4);
        add_value(&mut enum_map, 5, 5);
        add_value(&mut enum_map, 6, 6);

        remove_value(&mut enum_map, 1);
        remove_value(&mut enum_map, 2);
        remove_value(&mut enum_map, 3);

        assert!(contains(&enum_map, 3), 1);
        assert!(length(&enum_map) == 3, 2);

        move_to(owner, EnumerableMapTest { e: enum_map })
    }

    #[test(owner= @0x1111)]
    #[expected_failure(abort_code = 2, location = Self)]
    public fun test_remove_bulk_value(owner: &signer) {
        let enum_map = new_map<u256, u256>();

        add_value(&mut enum_map, 1, 1);
        add_value(&mut enum_map, 2, 2);
        add_value(&mut enum_map, 3, 3);
        add_value(&mut enum_map, 4, 4);
        add_value(&mut enum_map, 5, 5);
        add_value(&mut enum_map, 6, 6);

        remove_value_bulk(&mut enum_map, vector[1, 2, 3]);

        assert!(contains(&enum_map, 4), 1);
        assert!(length(&enum_map) == 6, 2);

        move_to(owner, EnumerableMapTest { e: enum_map })
    }

    #[test(owner= @0x1111)]
    #[expected_failure(abort_code = 3, location = Self)]
    public fun test_update_value(owner: &signer) {
        let enum_map = new_map<u256, u256>();

        add_value(&mut enum_map, 1, 1);
        add_value(&mut enum_map, 2, 2);
        add_value(&mut enum_map, 3, 3);
        add_value(&mut enum_map, 4, 4);
        add_value(&mut enum_map, 5, 5);
        add_value(&mut enum_map, 6, 6);

        update_value(&mut enum_map, 1, 7);

        assert!(contains(&enum_map, 4), 1);
        assert!(length(&enum_map) == 6, 2);
        assert!(get_value(&enum_map, 1) == 1, 3);

        move_to(owner, EnumerableMapTest { e: enum_map })
    }

    #[test(owner= @0x1111)]
    public fun test_clear(owner: &signer) {
        let enum_map = new_map<u256, u256>();

        add_value(&mut enum_map, 1, 1);
        add_value(&mut enum_map, 2, 2);
        add_value(&mut enum_map, 3, 3);
        add_value(&mut enum_map, 4, 4);
        add_value(&mut enum_map, 5, 5);
        add_value(&mut enum_map, 6, 6);

        clear(&mut enum_map);

        assert!(length(&enum_map) == 0, 2);

        move_to(owner, EnumerableMapTest { e: enum_map })
    }
}