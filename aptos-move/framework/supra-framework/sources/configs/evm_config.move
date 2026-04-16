module supra_framework::evm_config {

    use std::error;
    use std::signer;
    use std::string::{Self,String};
    use std::vector;
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
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

    /// Resource already exist at address
    const ERESOURCE_ALREADY_EXISTS: u64 = 6;

    /// Well-known config key for the EVM gas normalisation denominator.
    /// This u64 value is used to scale EVM gas units into Supra gas units.
    const CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM: vector<u8> = b"evm_gas_normalization_denom";

    /// Evm and Move address length
    const EVM_ADDRESS_BYTE_LENGTH : u64 = 12;
    const MOVE_ADDRESS_BYTE_LENGTH: u64 = 32;

    #[event]
    struct EvmContractsDetails has key, copy, store, drop {
        details: SimpleMap<String, address>,
    }

    /// key-value map of EVM scalar config parameters.
    /// Values are plain u128 integers; the Move type system enforces type safety
    /// at compile time, eliminating the need for self-describing Any wrappers.
    #[event]
    struct EvmScalarConfig has key, copy, store, drop {
        config: SimpleMap<String, u128>
    }

    /// Publishes both the EVM contract address map and the scalar config map.
    /// `contract_keys`/`contract_values` must be the same length and every address
    /// must be a valid 20-byte EVM address (upper 12 bytes of the 32-byte Move
    /// address must be zero).  `config_keys`/`config_values` must be the same
    /// length and must include all required keys (e.g. evm_gas_normalization_denom).
    public(friend) fun initialize(
        supra_framework: &signer,
        contract_keys: vector<String>,
        contract_values: vector<address>,
        config_keys: vector<String>,
        config_values: vector<u128>
    ) {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(!vector::is_empty(&contract_keys), error::invalid_argument(EEMPTY_DATA));
        assert!(!vector::is_empty(&config_keys), error::invalid_argument(EEMPTY_DATA));
        let supra_framework_addr = signer::address_of(supra_framework);
        assert!(!exists<EvmContractsDetails>(supra_framework_addr),error::invalid_state(ERESOURCE_ALREADY_EXISTS));
        assert!(!exists<EvmScalarConfig>(supra_framework_addr),error::invalid_state(ERESOURCE_ALREADY_EXISTS));
        assert!(
            vector::length(&contract_keys) == vector::length(&contract_values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        assert!(
            vector::length(&config_keys) == vector::length(&config_values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        
        // Check that no contract value is invalid EVM address
        let all_valid_evm_address = vector::all(&contract_values,
        |v|{ is_valid_evm_address(v) });
        assert!(all_valid_evm_address, error::invalid_argument(EINVALID_EVM_ADDRESS));

        let contract_details = EvmContractsDetails {
            details: simple_map::new_from(contract_keys, contract_values)
        };
        move_to(supra_framework, contract_details);
        event::emit(contract_details);

        let evm_config = EvmScalarConfig {
            config: simple_map::new_from(config_keys, config_values)
        };
        validate_scalar_config(&evm_config);
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
        let all_valid_evm_address = vector::all(&values, |v| { is_valid_evm_address(v) });
        assert!(all_valid_evm_address, error::invalid_argument(EINVALID_EVM_ADDRESS));
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
    /// for the next epoch.  Values are plain u128 scalars.
    /// Example usage:
    /// ```
    /// supra_framework::evm_config::upsert_config_for_next_epoch(
    ///     &framework_signer, vector["config_key"], vector[new_value]);
    /// supra_framework::supra_governance::reconfigure(&framework_signer);
    /// ```
    public fun upsert_config_for_next_epoch(
        account: &signer,
        keys: vector<String>,
        values: vector<u128>
    ) acquires EvmScalarConfig {
        system_addresses::assert_supra_framework(account);
        assert!(!vector::is_empty(&keys), error::invalid_argument(EEMPTY_DATA));
        assert!(
            vector::length(&keys) == vector::length(&values),
            error::invalid_argument(EKEYS_VALUES_MISMATCH)
        );
        if (!exists<EvmScalarConfig>(@supra_framework)) {
            let evm_config = 
                EvmScalarConfig { config: simple_map::new_from(keys, values) };
            // Config did not exist earlier, so validate the config for
            // presence of required keys and value type match
            validate_scalar_config(&evm_config);
            std::config_buffer::upsert<EvmScalarConfig>(evm_config);
            return;
        };
        // Copy existing config
        let updated_config = *borrow_global<EvmScalarConfig>(@supra_framework);
        // We are never removing existing keys so by induction if all required
        // keys are present in config during initialization
        // they will be there later as well, so no need to validate here
        vector::zip(keys, values, |key, value| {
            simple_map::upsert(&mut updated_config.config, key, value);
        });
        std::config_buffer::upsert<EvmScalarConfig>(updated_config);
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
    /// Returns the u128 value stored under `key` in the EvmScalarConfig map.
    /// Aborts with EKEY_NOT_FOUND if the resource has not been initialised or the key
    /// is not present in the map.
    public fun get_scalar_config_value(key: String): u128 acquires EvmScalarConfig {
        assert!(exists<EvmScalarConfig>(@supra_framework), error::not_found(EKEY_NOT_FOUND));
        let config = borrow_global<EvmScalarConfig>(@supra_framework);
        assert!(
            simple_map::contains_key(&config.config, &key),
            error::not_found(EKEY_NOT_FOUND)
        );
        *simple_map::borrow(&config.config, &key)
    }

    fun validate_scalar_config(evm_config: &EvmScalarConfig) {
        let required_keys = vector[string::utf8(CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM)];
        // With u128 as the value type, the Move type system prevents type mismatches at
        // compile time. The only meaningful runtime check is key presence.
        vector::for_each_reverse(required_keys, |rk| {
            assert!(
                simple_map::contains_key<String, u128>(&evm_config.config, &rk),
                error::invalid_argument(EMISSING_KEY_OR_INCORRECT_VAL_TYPE)
            );
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
        if (vector::length(&evm_addr_bytes) != MOVE_ADDRESS_BYTE_LENGTH) {
            return false
        };

        // Check that all 12 high-order prefix bytes are zero.  A non-zero byte here
        // means the value cannot fit in 20 bytes and is therefore not a valid EVM address.
        let i = 0u64;
        let addr_length_diff = MOVE_ADDRESS_BYTE_LENGTH - EVM_ADDRESS_BYTE_LENGTH;
        while (i < addr_length_diff) {
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
    public(friend) fun on_new_epoch(framework: &signer) acquires EvmScalarConfig, EvmContractsDetails {
        system_addresses::assert_supra_framework(framework);
        if (config_buffer::does_exist<EvmContractsDetails>()) {
            //TODO: change to extract_v2 when extract_v2 is merged and available
            let new_config = config_buffer::extract<EvmContractsDetails>();
            if (!exists<EvmContractsDetails>(@supra_framework)) {
                move_to(framework, new_config);
            } else {
                let old_config = borrow_global_mut<EvmContractsDetails>(@supra_framework);
                *old_config = new_config;
            };
            event::emit(new_config)
        };
        if (config_buffer::does_exist<EvmScalarConfig>()) {
            // change to extract_v2 when it is available
            let new_config = config_buffer::extract<EvmScalarConfig>();
            if (!exists<EvmScalarConfig>(@supra_framework)) {
                move_to(framework, new_config);
            } else {
                let old_config = borrow_global_mut<EvmScalarConfig>(@supra_framework);
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
    /// Happy-path test: both get_contract_value and get_scalar_config_value return the
    /// values that were seeded into their respective resources.
    fun test_get_contract_and_config_value_success(supra_framework: signer) acquires EvmContractsDetails, EvmScalarConfig {
        // Seed EvmContractsDetails with a single entry.
        let contract_key = std::string::utf8(b"usdc_contract");
        let contract_addr = @0xA550C18;
        move_to(&supra_framework, EvmContractsDetails {
            details: simple_map::new_from(vector[contract_key], vector[contract_addr])
        });

        // Seed EvmScalarConfig with a single entry using a plain u128 value.
        let config_key = std::string::utf8(b"evm_gas_normalization_denom");
        let config_value = 42u128;
        move_to(&supra_framework, EvmScalarConfig {
            config: simple_map::new_from(vector[config_key], vector[config_value])
        });

        // Both lookups must return the exact values that were inserted above.
        assert!(get_contract_value(std::string::utf8(b"usdc_contract")) == contract_addr, 0);
        assert!(
            get_scalar_config_value(std::string::utf8(b"evm_gas_normalization_denom")) == 42u128,
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
    /// Failure test: get_scalar_config_value aborts when the requested key is absent.
    ///
    /// The expected abort code is error::not_found(EKEY_NOT_FOUND)
    /// = (NOT_FOUND_CATEGORY=6 << 16) | EKEY_NOT_FOUND=4 = 0x60004.
    #[expected_failure(abort_code = 0x60004, location = supra_framework::evm_config)]
    fun test_get_config_value_key_not_found(supra_framework: signer) acquires EvmScalarConfig {
        move_to(&supra_framework, EvmScalarConfig {
            config: simple_map::new_from(
                vector[std::string::utf8(b"existing_key")],
                vector[1u128]
            )
        });
        get_scalar_config_value(std::string::utf8(b"nonexistent_key"));
    }

    #[test]
    /// Success test: validate_scalar_config must not abort when all required keys are present.
    ///
    /// evm_gas_normalization_denom is the sole required key. A config seeded with that
    /// key and a plain u128 value must pass validation.
    fun test_validate_config_success() {
        let config_key = std::string::utf8(CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM);
        let evm_config = EvmScalarConfig {
            config: simple_map::new_from(vector[config_key], vector[100u128])
        };
        // Must complete without aborting.
        validate_scalar_config(&evm_config);
    }

    #[test]
    /// Failure test: validate_scalar_config aborts when a required key is absent.
    ///
    /// An empty config is missing evm_gas_normalization_denom, so validation must abort.
    /// The expected abort code is error::invalid_argument(EMISSING_KEY_OR_INCORRECT_VAL_TYPE)
    /// = (INVALID_ARGUMENT_CATEGORY=1 << 16) | EMISSING_KEY_OR_INCORRECT_VAL_TYPE=5 = 0x10005.
    #[expected_failure(abort_code = 0x10005, location = supra_framework::evm_config)]
    fun test_validate_config_missing_required_key() {
        // An empty config is missing the sole required key -> must abort.
        let evm_config = EvmScalarConfig { config: simple_map::new() };
        validate_scalar_config(&evm_config);
    }

    #[test(supra_framework = @supra_framework)]
    /// Failure test: upsert_evm_contract_details_for_next_epoch aborts when any
    /// address in the values vector is not a valid EVM address.
    ///
    /// The call passes one valid address (@0x1, which fits in 20 bytes with all
    /// leading bytes zero) alongside one invalid address whose most-significant
    /// byte is non-zero (@0x1000...000).  The presence of the invalid address
    /// must trigger EINVALID_EVM_ADDRESS regardless of position in the vector.
    /// The expected abort code is error::invalid_argument(EINVALID_EVM_ADDRESS)
    /// = (INVALID_ARGUMENT_CATEGORY=1 << 16) | EINVALID_EVM_ADDRESS=3 = 0x10003.
    #[expected_failure(abort_code = 0x10003, location = supra_framework::evm_config)]
    fun test_upsert_evm_contract_details_mixed_invalid_address(supra_framework: signer) acquires EvmContractsDetails {
        let keys = vector[
            std::string::utf8(b"valid_contract"),
            std::string::utf8(b"invalid_contract")
        ];
        let values = vector[
            @0x1,                                                                       // valid: fits in 20 bytes
            @0x1000000000000000000000000000000000000000000000000000000000000000         // invalid: high byte non-zero
        ];
        upsert_evm_contract_details_for_next_epoch(&supra_framework, keys, values);
    }


}
