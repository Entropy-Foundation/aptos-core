/// Maintains the list of banned validators and updates counters on every epoch
module supra_framework::leader_ban_registry {
    use std::error;
    use supra_std::enumerable_map;
    use supra_framework::system_addresses;

    /// Leader ban registry already initialized
    const EBAN_REGISTRY_ALREADY_EXISTS: u64 = 1;
    /// Leader ban registry not initialized
    const EBAN_REGISTRY_NOT_INITIALIZED: u64 = 2;
    /// Validator already exists in registry
    const EVALIDATOR_ALREADY_EXISTS: u64 = 3;
    /// Validator not exists in registry
    const EVALIDATOR_DOESNT_EXISTS: u64 = 4;

    /// Holds metrics for banned round, epoch and round server in prev epoch
    struct ActiveBan has store, drop {
        epoch_earned: u64, // EPOCH
        round_earned: u64, // ROUND
        rounds_served_in_previous_epochs: u64 // ROUND
    }

    /// Holds validator metrics regarding duration pool address etc
    struct ValidatorBansWithAddress has store, drop {
        active: ActiveBan,
        consecutive_bans: u32,
        pool_address: address,
    }

    /// Holds ban registry
    struct BanRegistry has drop, store, key {
        bans: enumerable_map::EnumerableMap<address, ValidatorBansWithAddress>
    }

    /// Initialise leader ban registry
    public(friend) fun initialize_leader_ban_registry(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(
            !exists<BanRegistry>(@supra_framework),
            error::already_exists(EBAN_REGISTRY_ALREADY_EXISTS)
        );
        move_to(supra_framework, BanRegistry { bans: enumerable_map::new_map() });
    }

    /// Adding an entry for new validator
    public entry fun add_new_ban_entry(
        supra_framework: &signer, validator_address: address, pool_address: address, epoch_earned: u64, round_earned: u64
    )
    acquires BanRegistry
    {
        // TODO: epoch can be retrived from reconfigure
        // TODO: what about round
        // TODO: Validator address and index can be fetched pool address see stake.move

        system_addresses::assert_supra_framework(supra_framework);
        assert_registry_initialized();
        let ban_registry = borrow_global_mut<BanRegistry>(@supra_framework);

        if (enumerable_map::contains<address, ValidatorBansWithAddress>(&ban_registry.bans, validator_address)) {
            abort error::already_exists(EVALIDATOR_ALREADY_EXISTS)
        };

        enumerable_map::add_value(&mut ban_registry.bans, validator_address, ValidatorBansWithAddress {
            active: ActiveBan {
                epoch_earned,
                round_earned,
                rounds_served_in_previous_epochs: 0
            },
            consecutive_bans:0,
            pool_address
        })
    }

    /// Remvoing an entry of validator from registry
    public entry fun remove_ban_entry(supra_framework: &signer, validator_address: address)
    acquires BanRegistry
    {
        system_addresses::assert_supra_framework(supra_framework);
        assert_registry_initialized();
        let ban_registry = borrow_global_mut<BanRegistry>(@supra_framework);

        if (!enumerable_map::contains<address, ValidatorBansWithAddress>(&ban_registry.bans, validator_address)) {
            abort error::not_found(EVALIDATOR_DOESNT_EXISTS)
        };

        enumerable_map::remove_value(&mut ban_registry.bans, validator_address)
    }

    /// Update countes on every epoch
    public(friend) fun on_new_epoch() {
        /// TODO: What are the use cases configuration here?
    }

    /// Validates registry initialised if not aborted with `EBAN_REGISTRY_NOT_INITIALIZED`
    fun assert_registry_initialized() {
        assert!(
            exists<BanRegistry>(@supra_framework),
            error::invalid_state(EBAN_REGISTRY_NOT_INITIALIZED)
        );
    }
}
