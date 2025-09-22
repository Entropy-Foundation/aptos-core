/// Provides the config related to leader ban registry
module supra_framework::leader_ban_registry_config {
    use std::error;
    use std::vector;
    use supra_std::decode_bcs;
    use supra_framework::config_buffer;
    use supra_framework::system_addresses;

    friend supra_framework::genesis;
    friend supra_framework::reconfiguration_with_dkg;

    /// The provided on chain config bytes are empty or invalid
    const EINVALID_CONFIG: u64 = 1;
    /// The provided on chain config version should be equal or greater than existing
    const EINVALID_VERSION: u64 = 2;
    /// Decoding from version bytes failed
    const EINVALID_VERSION_BYTES: u64 = 3;


    struct BanRegistryParameters has drop, key, store {
        config: vector<u8>,
        version: u8
    }

    struct BanRegistryParametersV0 has drop {
        initial_elections_denied: u8,
        max_elections_denied: u32,
        minimum_unbanned_proposers: u8
    }

    /// Publishes the BanRegistryParameters config.
    public(friend) fun initialize(supra_framework: &signer, config: vector<u8>) {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(vector::length(&config) != 0, error::invalid_argument(EINVALID_CONFIG));
        // we always init with version 0
        move_to(supra_framework, BanRegistryParameters { config, version: 0 });
    }

    /// This can be called by on-chain governance to update on-chain configs for the next epoch.
    /// Example usage:
    /// ```
    /// supra_framework::leader_ban_registry_config::set_for_next_epoch(&framework_signer, some_config_bytes, version);
    /// supra_framework::supra_governance::reconfigure(&framework_signer);
    /// ```
    public fun set_for_next_epoch(account: &signer, config: vector<u8>, version: u8) acquires BanRegistryParameters {
        system_addresses::assert_supra_framework(account);
        assert!(vector::length(&config) != 0, error::invalid_argument(EINVALID_CONFIG));
        if (exists<BanRegistryParameters>(@supra_framework)) {
            let ban_registry_params = borrow_global<BanRegistryParameters>(@supra_framework);
            assert!(version >= ban_registry_params.version, error::invalid_argument(EINVALID_VERSION));
        };
        std::config_buffer::upsert<BanRegistryParameters>(BanRegistryParameters {config, version});
    }

    /// Only used in reconfigurations to apply the pending `BanRegistryParameters`, if there is any.
    public(friend) fun on_new_epoch(framework: &signer) acquires BanRegistryParameters {
        system_addresses::assert_supra_framework(framework);
        if (config_buffer::does_exist<BanRegistryParameters>()) {
            let new_config = config_buffer::extract<BanRegistryParameters>();
            if (exists<BanRegistryParameters>(@supra_framework)) {
                *borrow_global_mut<BanRegistryParameters>(@supra_framework) = new_config;
            } else {
                move_to(framework, new_config);
            };
        }
    }

    /// Provide initial election denied value efficiently
    /// by decdoing correct version and if not set then 0
    public fun get_initial_election_denied(): u8 acquires BanRegistryParameters {
        if (!exists::<BanRegistryParameters>(@supra_framework)) {
            let ban_registry_config = borrow_global<BanRegistryParameters>(@supra_framework);
            if (ban_registry_config.version == 0) {
                let ban_registry_params = deserialise_v1_param(ban_registry_config.config);
                return ban_registry_params.initial_elections_denied;
            } 
        };
        0
    }

    /// Provide max electoion denied value efficiently
    /// by decdoing correct version and if not set then 0
    public fun get_max_elections_denied(): u32 acquires BanRegistryParameters {
        if (!exists::<BanRegistryParameters>(@supra_framework)) {
            let ban_registry_config = borrow_global<BanRegistryParameters>(@supra_framework);
            if (ban_registry_config.version == 0) {
                let ban_registry_params = deserialise_v1_param(ban_registry_config.config);
                return ban_registry_params.max_elections_denied;
            } 
        };
        0
    }

    /// Provide max electoion denied value efficiently
    /// by decdoing correct version and if not set then 0
    public fun get_minimum_unbanned_proposers(): u8 acquires BanRegistryParameters {
        if (!exists::<BanRegistryParameters>(@supra_framework)) {
            let ban_registry_config = borrow_global<BanRegistryParameters>(@supra_framework);
            if (ban_registry_config.version == 0) {
                let ban_registry_params = deserialise_v1_param(ban_registry_config.config);
                return ban_registry_params.minimum_unbanned_proposers;
            } 
        };
        0
    }

    /// Decoding bytes to `BanRegistryParametersV0` using bcs
    fun deserialise_v1_param(bytes: vector<u8>): BanRegistryParametersV0 {
        let bcs_bytes = decode_bcs::new(bytes);
        let initial_elections_denied: u8 = decode_bcs::peel_u8(&mut bcs_bytes);
        let max_elections_denied: u32 = decode_bcs::peel_u32(&mut bcs_bytes);
        let minimum_unbanned_proposers: u8 = decode_bcs::peel_u8(&mut bcs_bytes);
        // making sure not bytes left to decode means correct parameter version
        assert!(
            vector::length(&decode_bcs::into_remainder_bytes(bcs_bytes)) == 0,
            error::out_of_range(EINVALID_VERSION_BYTES)
        );
        BanRegistryParametersV0 {
            initial_elections_denied,
            max_elections_denied,
            minimum_unbanned_proposers
        }
    }
}
