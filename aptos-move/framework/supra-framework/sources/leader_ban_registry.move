/// Maintains the list of banned validators and updates counters on every epoch
module supra_framework::leader_ban_registry {
    use std::error;
    use std::option;
    use std::option::Option;
    use supra_framework::system_addresses;
    use std::vector;
    use supra_framework::stake;
    use supra_framework::leader_ban_registry_config;

    friend supra_framework::block;

    /// Leader ban registry already initialized
    const EBAN_REGISTRY_ALREADY_EXISTS: u64 = 1;
    /// Leader ban registry not initialized
    const EBAN_REGISTRY_NOT_INITIALIZED: u64 = 2;
    /// Latest view already initialized
    const ELATEST_VIEW_ALREADY_EXISTS: u64 = 3;

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
        pool_address: address
    }

    /// Holds ban registry
    struct BanRegistry has drop, store, key {
        bans: vector<ValidatorBansWithAddress>
    }

    /// Holds latest processed round and epoch
    struct LatestView has drop, store, key {
        epoch: u64,
        round: u64
    }

    #[event]
    struct BanAdded has drop {
        pool_address: address,
        epoch: u64,
        round: u64,
        consecutive_count: u64
    }

    #[event]
    struct BanRemoved has drop {
        pool_address: address,
        epoch: u64,
        round: u64,
    }

    /// Initialise leader ban registry
    public(friend) fun initialize_leader_ban_registry(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(
            !exists<BanRegistry>(@supra_framework),
            error::already_exists(EBAN_REGISTRY_ALREADY_EXISTS)
        );
        assert!(
            !exists<LatestView>(@supra_framework),
            error::already_exists(EBAN_REGISTRY_ALREADY_EXISTS)
        );
        move_to(supra_framework, BanRegistry { bans: vector::empty() });
    }

    #[view]
    public fun get_ban_registry() : vector<ValidatorBansWithAddress> acquires BanRegistry {
        if (!exists<BanRegistry>(@supra_framework)) {
            return (vector::empty());
        };
        let ban_registry = borrow_global<BanRegistry>(@supra_framework);
        ban_registry.bans
    }

    #[view]
    public fun get_initial_ban_duration(): u64 {
        let initail_election_denied = leader_ban_registry_config::get_initial_election_denied() as u64;
        let committee_size = stake::get_committe_size();
        committee_size * initail_election_denied
    }

    #[view]
    public fun get_max_ban_duration(): u64 {
        let max_ban_election_denied = leader_ban_registry_config::get_max_elections_denied() as u64;
        let committee_size = stake::get_committe_size();
        committee_size * max_ban_election_denied
    }

    /// Add or update the ban registry as per block metadata
    public(friend) fun update_ban_registry(
        epoch_earned: u64, round_earned: u64, proposer_index: Option<u64>, failed_proposer_indices: vector<u64>
    )
    acquires BanRegistry, LatestView
    {
        if (!exists<BanRegistry>(@supra_framework)) {
            return ;
        };
        if (!exists<LatestView>(@supra_framework)) {
            return ;
        };
        let ban_registry = borrow_global_mut<BanRegistry>(@supra_framework);
        let latest_view = borrow_global_mut<LatestView>(@supra_framework);
        latest_view.epoch = epoch_earned;
        latest_view.round = round_earned;

        // ban the failed proposer indices
        ban(epoch_earned, round_earned, failed_proposer_indices, ban_registry);

        // unban the proposer
        if (std::option::is_some(&proposer_index)) {
            let extracted_proposer_index = *std::option::borrow(&mut proposer_index);
            unban(epoch_earned, round_earned, extracted_proposer_index, ban_registry);
        };
    }

    /// Adds failed proposer indices to ban registry
    fun ban(epoch_earned: u64, round_earned: u64, failed_proposer_indices: vector<u64>, ban_registry: &mut BanRegistry)
    {
        let initial_ban_duration = get_initial_ban_duration();
        if (initial_ban_duration == 0) {
            return;
        };

        vector::for_each(failed_proposer_indices, |failed_validator_index| {
            let validator_pool_address_opt= stake::get_pool_address_from_index(failed_validator_index);
            if (option::is_some(&validator_pool_address_opt)) {
                let validator_pool_address = option::extract(&mut validator_pool_address_opt);
                let (is_exists, index) = is_pool_exists(&ban_registry.bans, validator_pool_address);
                if (is_exists) {
                    let bans = vector::borrow_mut(&mut ban_registry.bans, index);
                    bans.consecutive_bans += 1;
                    // TODO: we can update the registry here if max duration already passed
                } else {
                    vector::push_back(&mut ban_registry.bans, ValidatorBansWithAddress {
                        active: ActiveBan {
                            epoch_earned,
                            round_earned,
                            rounds_served_in_previous_epochs: 0
                        },
                        consecutive_bans: 0,
                        pool_address: validator_pool_address
                    });
                };
            };
        });
    }

    /// Remvoing an entry of validator from registry if found at proposer index
    fun unban(epoch_earned: u64, round_earned: u64, proposer_index: u64, ban_registry: &mut BanRegistry)
    {
        let validator_pool_address_opt= stake::get_pool_address_from_index(proposer_index);
        if (option::is_some(&validator_pool_address_opt)) {
            let validator_pool_address = option::extract(&mut validator_pool_address_opt);
            let (exists, index) = is_pool_exists(&ban_registry.bans, validator_pool_address);
            if (exists) {
                vector::swap_remove(&mut ban_registry.bans, index);
            };
        };
    }

    /// Update counts on every epoch
    public(friend) fun on_new_epoch() acquires BanRegistry,LatestView {
        if (!exists<LatestView>(@supra_framework)) {
            return;
        };
        if (!exists<BanRegistry>(@supra_framework)) {
            return;
        };
        let latest_view = borrow_global<LatestView>(@supra_framework);
        let ban_registry = borrow_global_mut<BanRegistry>(@supra_framework);

        vector::for_each_mut(&mut ban_registry.bans, |v| {
            if (has_started(&v.active, latest_view)) {
                if (latest_view.epoch > v.active.epoch_earned) {
                    v.active.rounds_served_in_previous_epochs += latest_view.round;
                } else {
                    v.active.rounds_served_in_previous_epochs += latest_view.round - v.active.round_earned;
                }
            };
        });
        // TODO: Do we need update the list here ? for those entreis which max duration already passed?
    }

    /// Checks whether pool entry exists or not
    fun is_pool_exists(bans: &vector<ValidatorBansWithAddress>, addr: address) : (bool, u64) {
        let (is_exist, index) = vector::find(bans, |v| {
           v.pool_address == addr
        });
        (is_exist, index)
    }

    /// Checks if ban has already started
    fun has_started(active_ban: &ActiveBan, latest_view: &LatestView): bool {
        active_ban.epoch_earned <= latest_view.epoch && active_ban.round_earned < latest_view.round
    }

    /// Validates registry initialised if not aborted with `EBAN_REGISTRY_NOT_INITIALIZED`
    fun assert_registry_initialized() {
        assert!(
            exists<BanRegistry>(@supra_framework),
            error::invalid_state(EBAN_REGISTRY_NOT_INITIALIZED)
        );
    }
}
