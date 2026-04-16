module supra_framework::evm_config {

    use std::error;
    use std::string::{Self,String};
    use std::vector;
    use aptos_std::copyable_any;
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    use aptos_std::type_info;
    use aptos_std::bcs;
    use supra_framework::config_buffer;
    use supra_framework::event;
    use supra_framework::system_addresses;

    friend supra_framework::genesis;
    friend supra_framework::reconfiguration_with_dkg;

    /// Empty keys/values to update config.
    const EEMPTY_DATA: u64 = 1;

    /// Input keys and values should have the same amount of data
    const EKEYS_VALUES_MISMATCH: u64 = 2;

    /// Invalid EVM address, valid EVM address must fit in 20 bytes
    const EINVALID_EVM_ADDRESS: u64 = 3;

    /// Requested key does not exist in the map
    const EKEY_NOT_FOUND: u64 = 4;

    /// Required Key is missing or value type is incorrect for a key
    const EMISSING_KEY_OR_INCORRECT_VAL_TYPE: u64 = 5;

    /// Well-known config key for the EVM gas normalisation denominator.
    /// This u64 value is used to scale EVM gas units into Supra gas units.
    const CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM: vector<u8> = b"evm_gas_normalization_denom";

    #[event]
    struct EvmContractsDetails has key, copy, store, drop {
        details: SimpleMap<String, address>,
    }

    /// key-value map of EVM config parameters.
    /// Values are stored as self-describing copyable_any::Any so the Rust
    /// layer can decode them by type name without any per-key special-casing.
    #[event]
    struct EvmConfig has key, copy, store, drop {
        config: SimpleMap<String, copyable_any::Any>
    }

    /// Publishes the EvmContractInfo details.
    /// `config_values` are raw BCS bytes and `config_type_names` are the
    /// corresponding Move type-name strings (as produced by
    /// `type_info::type_name<T>()`).  The two vectors must have the same
    /// length; each (type_name, data) pair is wrapped into a copyable_any::Any
    /// before being stored.
    public(friend) fun initialize(
        supra_framework: &signer,
        contract_keys: vector<String>,
        contract_values: vector<address>,
        config_keys: vector<String>,
        config_type_names: vector<String>,
        config_values: vector<vector<u8>>
    ) {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(!vector::is_empty(&contract_keys), error::invalid_argument(EEMPTY_DATA));
        assert!(!vector::is_empty(&config_keys), error::invalid_argument(EEMPTY_DATA));
        assert!(
            vector::length(&contract_keys) == vector::length(&contract_values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        assert!(
            vector::length(&config_keys) == vector::length(&config_values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        assert!(
            vector::length(&config_type_names) == vector::length(&config_values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        // Reject any config values with empty BCS payloads - they cannot be decoded.
        let value_empty = vector::any(&config_values, |v| { vector::is_empty(v) });
        assert!(!value_empty, error::invalid_argument(EEMPTY_DATA));
        
        // Check that no contract value is invalid EVM address
        let not_valid_evm_address = vector::any(&contract_values,
        |v|{ !is_valid_evm_address(v) });

        let contract_details = EvmContractsDetails {
            details: simple_map::new_from(contract_keys, contract_values)
        };
        move_to(supra_framework, contract_details);
        event::emit(contract_details);

        // Zip type names and raw BCS bytes into self-describing Any values.
        let any_values = vector::zip_map(config_type_names, config_values, |type_name, data| {
            copyable_any::new(type_name, data)
        });
        let evm_config = EvmConfig {
            config: simple_map::new_from(config_keys, any_values)
        };
        validate_config(&evm_config);
        move_to(supra_framework, evm_config);
        event::emit(evm_config);
    }

    /// This can be called by on-chain governance to update on-chain evm contract
    /// details for the next epoch.
    /// Example usage:
    /// ```
    /// supra_framework::evm_config::upsert_evm_contract_details_for_next_epoch(
    ///     &framework_signer, vector["contract1_name"], vector[contract1_address]);
    /// supra_framework::supra_governance::reconfigure(&framework_signer);
    /// ```
    public fun upsert_evm_contract_details_for_next_epoch(
        account: &signer,
        keys: vector<String>,
        values: vector<address>
    ) acquires EvmContractsDetails {
        system_addresses::assert_supra_framework(account);
        assert!(!vector::is_empty(&keys), error::invalid_argument(EEMPTY_DATA));
        assert!(
            vector::length(&keys) == vector::length(&values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        let not_evm_address = vector::any(&values, |v| { !is_valid_evm_address(v) });
        assert!(!not_evm_address, error::invalid_argument(EINVALID_EVM_ADDRESS));
        if (!exists<EvmContractsDetails>(@supra_framework)) {
            std::config_buffer::upsert<EvmContractsDetails>(
                EvmContractsDetails { details: simple_map::new_from(keys, values) }
            );
            return
        };
        let updated_config = *borrow_global<EvmContractsDetails>(@supra_framework);
        vector::zip(keys, values, |key, value| {
            simple_map::upsert(&mut updated_config.details, key, value);
        });
        std::config_buffer::upsert<EvmContractsDetails>(updated_config);
    }

    /// This can be called by on-chain governance to update on-chain evm config
    /// for the next epoch.  Values must be self-describing copyable_any::Any
    /// instances with non-empty data payloads.
    /// Example usage:
    /// ```
    /// supra_framework::evm_config::upsert_config_for_next_epoch(
    ///     &framework_signer, vector["config_key"], vector[config_any_value]);
    /// supra_framework::supra_governance::reconfigure(&framework_signer);
    /// ```
    public fun upsert_config_for_next_epoch(
        account: &signer,
        keys: vector<String>,
        values: vector<copyable_any::Any>
    ) acquires EvmConfig {
        system_addresses::assert_supra_framework(account);
        assert!(!vector::is_empty(&keys), error::invalid_argument(EEMPTY_DATA));
        assert!(
            vector::length(&keys) == vector::length(&values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        // Reject Any values whose data payload is empty - they cannot be decoded.
        let value_empty = vector::any(&values, |v| { copyable_any::is_empty(v) });
        assert!(!value_empty, error::invalid_argument(EEMPTY_DATA));
        if (!exists<EvmConfig>(@supra_framework)) {
            let evm_config = 
                EvmConfig { config: simple_map::new_from(keys, values) };
            // Config did not exist earlier, so validate the config for
            // presence of required keys and value type match
            validate_config(&evm_config);
            std::config_buffer::upsert<EvmConfig>(evm_config);
        };
        let updated_config = *borrow_global<EvmConfig>(@supra_framework);
        // We are never removing existing keys so by induction if all required
        // keys are present in config during initialization
        // they will be there later as well, so no need to validate here
        vector::zip(keys, values, |key, value| {
            simple_map::upsert(&mut updated_config.config, key, value);
        });
        std::config_buffer::upsert<EvmConfig>(updated_config);
    }

    #[view]
    /// Returns the contract address stored under `key` in the EvmContractsDetails map.
    /// Aborts with EKEY_NOT_FOUND if the resource has not been initialised or the key
    /// is not present in the map.
    public fun get_contract_value(key: String): address acquires EvmContractsDetails {
        assert!(exists<EvmContractsDetails>(@supra_framework), error::not_found(EKEY_NOT_FOUND));
        let details = borrow_global<EvmContractsDetails>(@supra_framework);
        assert!(
            simple_map::contains_key(&details.details, &key),
            error::not_found(EKEY_NOT_FOUND)
        );
        *simple_map::borrow(&details.details, &key)
    }

    #[view]
    /// Returns the self-describing Any value stored under `key` in the EvmConfig map.
    /// Aborts with EKEY_NOT_FOUND if the resource has not been initialised or the key
    /// is not present in the map.
    public fun get_config_value(key: String): copyable_any::Any acquires EvmConfig {
        assert!(exists<EvmConfig>(@supra_framework), error::not_found(EKEY_NOT_FOUND));
        let config = borrow_global<EvmConfig>(@supra_framework);
        assert!(
            simple_map::contains_key(&config.config, &key),
            error::not_found(EKEY_NOT_FOUND)
        );
        *simple_map::borrow(&config.config, &key)
    }

    #[view]
    /// Returns the EVM gas normalisation denominator stored in the config.
    /// Aborts with EKEY_NOT_FOUND if the key is absent, or with a BCS decode
    /// error if the stored value is not a u64.
    public fun get_evm_gas_normalization_denom(): u64 acquires EvmConfig {
        let key = std::string::utf8(CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM);
        let any_val = get_config_value(key);
        copyable_any::unpack<u64>(any_val)
    }

    fun validate_config(evm_config: &EvmConfig) {
        let required_keys = vector[string::utf8(CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM)];
        let required_value_types = vector[type_info::type_name<u64>()];

        let all_valid = true;
        // Check that all the required keys are present and value type matches
        vector::zip_reverse<String, String>(required_keys, required_value_types, |rk, rvt| {
            // Assert that all required keys exist and value type matches
            assert!((simple_map::contains_key<String,copyable_any::Any>(&evm_config.config,&rk) &&
                    copyable_any::type_name(simple_map::borrow(&evm_config.config,&rk)) == &rvt ), error::invalid_argument(EMISSING_KEY_OR_INCORRECT_VAL_TYPE));
        });
        
    }

    fun is_valid_evm_address(addr: &address): bool {
        // BCS serialises a Move `address` as a raw fixed-size 32-byte array in
        // big-endian order (most-significant byte first).  An EVM address is only
        // 20 bytes wide, so when a 20-byte EVM address is stored in a 32-byte Move
        // address the EVM bytes occupy the last 20 positions (indices 12-31) and the
        // leading 12 bytes (indices 0-11) must all be zero.
        // We iterate only over that prefix and bail immediately on the first non-zero
        // byte to avoid unnecessary work.
        let evm_addr_bytes = bcs::to_bytes(addr);

        // Sanity check: BCS encoding of an address is always 32 bytes. If somehow
        // the length differs, the address cannot be valid.
        if (vector::length(&evm_addr_bytes) != 32) {
            return false
        };

        // Check that all 12 high-order prefix bytes are zero.  A non-zero byte here
        // means the value cannot fit in 20 bytes and is therefore not a valid EVM address.
        let i = 0u64;
        while (i < 12) {
            if (*vector::borrow(&evm_addr_bytes, i) != 0u8) {
                // Non-zero prefix byte found - not a valid 20-byte EVM address.
                return false
            };
            i = i + 1;
        };

        true
    }

    /// Only used in reconfigurations to apply the pending configs in buffer, if any.
    /// If supra_framework already holds the resource, overwrite it; otherwise move it in.
    public(friend) fun on_new_epoch(framework: &signer) acquires EvmConfig, EvmContractsDetails {
        system_addresses::assert_supra_framework(framework);
        if (config_buffer::does_exist<EvmContractsDetails>()) {
            let new_config = config_buffer::extract<EvmContractsDetails>();
            if (!exists<EvmContractsDetails>(@supra_framework)) {
                move_to(framework, new_config);
            } else {
                let old_config = borrow_global_mut<EvmContractsDetails>(@supra_framework);
                *old_config = new_config;
            };
            event::emit(new_config)
        };
        if (config_buffer::does_exist<EvmConfig>()) {
            let new_config = config_buffer::extract<EvmConfig>();
            if (!exists<EvmConfig>(@supra_framework)) {
                move_to(framework, new_config);
            } else {
                let old_config = borrow_global_mut<EvmConfig>(@supra_framework);
                *old_config = new_config;
            };
            event::emit(new_config)
        };
    }

    // -------------------------------------------------------------------------
    // Tests
    // -------------------------------------------------------------------------

    #[test]
    /// Verifies that a small address value (@0x1) is accepted as a valid EVM address.
    ///
    /// @0x1 is the 256-bit integer 1.  BCS serialises a Move address as a raw
    /// big-endian 32-byte array, so the most-significant byte is at index 0 and the
    /// least-significant byte (0x01) is at index 31.  The 12 leading bytes
    /// (indices 0-11) are therefore all zero, and the function must return true.
    fun test_valid_evm_address_small_value() {
        // BCS big-endian layout for @0x1 (32 bytes):
        //   index  0 : 0x00
        //   ...
        //   index 30 : 0x00
        //   index 31 : 0x01
        // Leading bytes 0-11 are all 0x00 -> valid 20-byte EVM address.
        assert!(is_valid_evm_address(&@0x1), 0);
    }

    #[test]
    /// Verifies that a full 32-byte address is rejected as an invalid EVM address.
    ///
    /// @0x1000...000 (64 hex digits, most-significant nibble = 1) is the 256-bit
    /// value 2^252.  BCS serialises it as a big-endian byte array, so the
    /// most-significant byte (0x10) lands at index 0 - which falls inside the
    /// leading window [0, 11] that must be entirely zero for a valid EVM address.
    /// The function must therefore return false.
    fun test_invalid_evm_address_full_32_bytes() {
        // BCS big-endian layout for @0x1000...000 (32 bytes):
        //   index  0 : 0x10   <- non-zero prefix byte -> invalid EVM address
        //   index  1 : 0x00
        //   ...
        //   index 31 : 0x00
        assert!(
            !is_valid_evm_address(
                &@0x1000000000000000000000000000000000000000000000000000000000000000
            ),
            0
        );
    }

    #[test(supra_framework = @supra_framework)]
    /// Happy-path test: both get_contract_value and get_config_value return the
    /// values that were seeded into their respective resources.
    fun test_get_contract_and_config_value_success(supra_framework: signer) acquires EvmContractsDetails, EvmConfig {
        // Seed EvmContractsDetails with a single entry.
        let contract_key = std::string::utf8(b"usdc_contract");
        let contract_addr = @0xA550C18;
        move_to(&supra_framework, EvmContractsDetails {
            details: simple_map::new_from(vector[contract_key], vector[contract_addr])
        });

        // Seed EvmConfig with a single entry using a typed Any value.
        let config_key = std::string::utf8(b"evm_gas_normalization_denom");
        let config_value = copyable_any::pack<u64>(42u64);
        move_to(&supra_framework, EvmConfig {
            config: simple_map::new_from(vector[config_key], vector[config_value])
        });

        // Both lookups must return the exact values that were inserted above.
        assert!(get_contract_value(std::string::utf8(b"usdc_contract")) == contract_addr, 0);
        assert!(
            copyable_any::unpack<u64>(
                get_config_value(std::string::utf8(b"evm_gas_normalization_denom"))
            ) == 42u64,
            0
        );
    }

    #[test(supra_framework = @supra_framework)]
    /// Failure test: get_contract_value aborts when the requested key is absent.
    ///
    /// The expected abort code is error::not_found(EKEY_NOT_FOUND)
    /// = (NOT_FOUND_CATEGORY=6 << 16) | EKEY_NOT_FOUND=4 = 0x60004.
    #[expected_failure(abort_code = 0x60004, location = supra_framework::evm_config)]
    fun test_get_contract_value_key_not_found(supra_framework: signer) acquires EvmContractsDetails {
        move_to(&supra_framework, EvmContractsDetails {
            details: simple_map::new_from(
                vector[std::string::utf8(b"existing_key")],
                vector[@0x1]
            )
        });
        get_contract_value(std::string::utf8(b"nonexistent_key"));
    }

    #[test(supra_framework = @supra_framework)]
    /// Failure test: get_config_value aborts when the requested key is absent.
    ///
    /// The expected abort code is error::not_found(EKEY_NOT_FOUND)
    /// = (NOT_FOUND_CATEGORY=6 << 16) | EKEY_NOT_FOUND=4 = 0x60004.
    #[expected_failure(abort_code = 0x60004, location = supra_framework::evm_config)]
    fun test_get_config_value_key_not_found(supra_framework: signer) acquires EvmConfig {
        move_to(&supra_framework, EvmConfig {
            config: simple_map::new_from(
                vector[std::string::utf8(b"existing_key")],
                vector[copyable_any::pack<u64>(1u64)]
            )
        });
        get_config_value(std::string::utf8(b"nonexistent_key"));
    }

    #[test]
    /// Success test: validate_config must not abort when all required keys are
    /// present with the correct value types.
    ///
    /// evm_gas_normalization_denom is the sole required key and its type must be
    /// u64.  A config seeded with exactly that key/type pair must pass validation.
    fun test_validate_config_success() {
        let config_key = std::string::utf8(CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM);
        // pack<u64> records type_info::type_name<u64>() as the type_name inside
        // the Any value, which is what validate_config compares against.
        let config_value = copyable_any::pack<u64>(100u64);
        let evm_config = EvmConfig {
            config: simple_map::new_from(vector[config_key], vector[config_value])
        };
        // Must complete without aborting.
        validate_config(&evm_config);
    }

    #[test]
    /// Failure test: validate_config aborts when the required key is present but
    /// its value has the wrong type.
    ///
    /// evm_gas_normalization_denom must carry a u64 value; packing a u8 instead
    /// causes the type_name comparison to fail.
    /// The expected abort code is error::invalid_argument(EMISSING_KEY_OR_INCORRECT_VAL_TYPE)
    /// = (INVALID_ARGUMENT_CATEGORY=1 << 16) | EMISSING_KEY_OR_INCORRECT_VAL_TYPE=5 = 0x10005.
    #[expected_failure(abort_code = 0x10005, location = supra_framework::evm_config)]
    fun test_validate_config_wrong_value_type() {
        let config_key = std::string::utf8(CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM);
        // Key is present but packed as u8 instead of the required u64.
        // type_info::type_name<u8>() != type_info::type_name<u64>(), so validation aborts.
        let config_value = copyable_any::pack<u8>(42u8);
        let evm_config = EvmConfig {
            config: simple_map::new_from(vector[config_key], vector[config_value])
        };
        validate_config(&evm_config);
    }
}
