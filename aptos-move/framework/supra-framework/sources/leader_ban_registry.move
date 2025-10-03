/// Maintains the list of banned validators and updates counters on every epoch
module supra_framework::leader_ban_registry {
    use std::error;
    use std::features;
    use std::option;
    use std::option::Option;
    use supra_framework::system_addresses;
    use std::vector;
    use aptos_std::math64::{pow, min};
    use supra_framework::event;
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
    struct ActiveBan has store, drop, copy {
        epoch_earned: u64, // EPOCH
        round_earned: u64, // ROUND
        rounds_served_in_previous_epochs: u64 // ROUND
    }

    /// Holds validator metrics regarding duration pool address etc
    struct ValidatorBansWithAddress has store, drop, copy {
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
    struct Bannned has drop, store {
        pool_address: address,
        epoch: u64,
        round: u64,
        consecutive_bans: u32
    }

    #[event]
    struct Reinstated has drop, store {
        pool_address: address,
        epoch: u64,
        round: u64
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
        move_to(supra_framework, LatestView { epoch: 0, round: 0 });
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
        let initial_elections_denied = leader_ban_registry_config::get_initial_elections_denied();
        let committee_size = stake::get_committee_size();
        committee_size * (initial_elections_denied as u64)
    }

    #[view]
    public fun get_max_ban_duration(): u64 {
        let max_elections_denied = leader_ban_registry_config::get_max_elections_denied();
        let committee_size = stake::get_committee_size();
        committee_size * (max_elections_denied as u64)
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
        bans(latest_view, failed_proposer_indices, ban_registry);

        // removing bans whose duration is over
        reinstate_bans(latest_view, ban_registry);

        // unban the proposer
        if (std::option::is_some(&proposer_index)) {
            let extracted_proposer_index = *std::option::borrow(&mut proposer_index);
            reinstate_proposer(latest_view, extracted_proposer_index, ban_registry);
        };
    }

    /// Adds failed proposer indices to ban registry
    fun bans(
        latest_view: &LatestView,
        failed_proposer_indices: vector<u64>,
        ban_registry: &mut BanRegistry,
    )
    {
        let initial_ban_duration = get_initial_ban_duration();
        if (initial_ban_duration == 0) {
            return;
        };

        vector::for_each(failed_proposer_indices, |failed_validator_index| {
            let validator_pool_address_opt = stake::get_pool_address_from_index(failed_validator_index);
            if (option::is_some(&validator_pool_address_opt)) {
                let validator_pool_address = option::extract(&mut validator_pool_address_opt);
                let (is_ban_exists, index) = vector::find(&ban_registry.bans, |v| {
                    let v: &ValidatorBansWithAddress = v;
                    validator_pool_address == v.pool_address
                });
                if (is_ban_exists) {
                    let bans = vector::borrow_mut(&mut ban_registry.bans, index);
                    bans.consecutive_bans = bans.consecutive_bans + 1;
                    if (remaining_duration(bans, latest_view) == 0) {
                        vector::swap_remove(&mut ban_registry.bans, index);
                        if (features::module_event_enabled()) {
                            event::emit(Reinstated {
                                pool_address: validator_pool_address,
                                epoch: latest_view.epoch,
                                round: latest_view.round
                            });
                        }
                    } else {
                        if (features::module_event_enabled()) {
                            event::emit(Bannned {
                                pool_address: validator_pool_address,
                                epoch: latest_view.epoch,
                                round: latest_view.round,
                                consecutive_bans: bans.consecutive_bans
                            });
                        }
                    }
                } else {
                    let ban_registry_len = vector::length(&ban_registry.bans);
                    if (can_be_added_in_ban(ban_registry_len)) {
                        let ban_with_address = ValidatorBansWithAddress {
                            active: ActiveBan {
                                epoch_earned: latest_view.epoch,
                                round_earned: latest_view.round,
                                rounds_served_in_previous_epochs: 0
                            },
                            consecutive_bans: 0,
                            pool_address: validator_pool_address
                        };
                        vector::push_back(&mut ban_registry.bans, ban_with_address);

                        if (features::module_event_enabled()) {
                            event::emit(Bannned {
                                pool_address: ban_with_address.pool_address,
                                epoch: ban_with_address.active.epoch_earned,
                                round: ban_with_address.active.round_earned,
                                consecutive_bans: ban_with_address.consecutive_bans
                            });
                        }
                    }
                };
            };
        });
    }

    /// Removes bans for those validator which duration is over
    fun reinstate_bans(latest_view: &LatestView, ban_registry: &mut BanRegistry) {
        let pool_address_for_duration_over = vector::empty();
        vector::for_each_ref(&ban_registry.bans, |v| {
            if (remaining_duration(v, latest_view) == 0 ) {
                vector::push_back(&mut pool_address_for_duration_over, v.pool_address);
            }
        });
        vector::for_each_ref(&pool_address_for_duration_over, |p| {
            let (exists, index) = vector::find(&ban_registry.bans, |v| {
                let v : &ValidatorBansWithAddress = v;
                &v.pool_address == p
            });
            if (exists) {
                vector::swap_remove(&mut ban_registry.bans, index);
                if (features::module_event_enabled()) {
                    event::emit(Reinstated {
                        epoch: latest_view.epoch,
                        round: latest_view.round,
                        pool_address: *p
                    })
                }
            }
        });
    }

    /// Remvoing an entry of validator from registry if found at proposer index
    fun reinstate_proposer(latest_view: &LatestView, proposer_index: u64, ban_registry: &mut BanRegistry)
    {
        let validator_pool_address_opt= stake::get_pool_address_from_index(proposer_index);
        if (option::is_some(&validator_pool_address_opt)) {
            let validator_pool_address = option::extract(&mut validator_pool_address_opt);
            let (is_banned, index) = vector::find(&ban_registry.bans, |v| {
                let v: &ValidatorBansWithAddress = v;
                validator_pool_address == v.pool_address
            });
            if (is_banned) {
                vector::swap_remove(&mut ban_registry.bans, index);
                if (features::module_event_enabled()) {
                    event::emit(Reinstated {
                        round: latest_view.round,
                        epoch: latest_view.epoch,
                        pool_address: validator_pool_address
                    })
                }
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

        let updated_pool_addresses = stake::get_committee_pool_addresses();
        let pool_addresses_to_remove = vector::empty();
        vector::for_each_mut(&mut ban_registry.bans, |v| {
            let v: &mut ValidatorBansWithAddress = v;
            if (has_started(&v.active, latest_view)) {
                if (latest_view.epoch > v.active.epoch_earned) {
                    v.active.rounds_served_in_previous_epochs = v.active.rounds_served_in_previous_epochs + latest_view.round;
                } else {
                    v.active.rounds_served_in_previous_epochs = v.active.rounds_served_in_previous_epochs + latest_view.round - v.active.round_earned;
                }
            };
            if (vector::contains(&updated_pool_addresses, &v.pool_address)) {
                vector::push_back(&mut pool_addresses_to_remove, v.pool_address)
            }
        });

        vector::for_each_ref(&pool_addresses_to_remove, |p| {
            let (is_exist, index) = vector::find(&ban_registry.bans, |v|{
                let v : &ValidatorBansWithAddress = v;
                &v.pool_address == p
            });
            if (is_exist) {
                vector::swap_remove(&mut ban_registry.bans, index);
                if (features::module_event_enabled()) {
                    event::emit(Reinstated {
                        pool_address: *p,
                        epoch: latest_view.epoch,
                        round: latest_view.round
                    });
                }
            }
        });
    }

    /// Checks if ban has already started
    fun has_started(active_ban: &ActiveBan, latest_view: &LatestView): bool {
        active_ban.epoch_earned <= latest_view.epoch && active_ban.round_earned < latest_view.round
    }

    /// Calculate the number of rounds remaining in the a given ban.
    fun remaining_duration(ban: &ValidatorBansWithAddress, latest_view: &LatestView): u64 {
        let initial_ban_duration = get_initial_ban_duration();
        let max_ban_duration = get_max_ban_duration();
        let duration = initial_ban_duration * pow(2, (ban.consecutive_bans as u64));
        let duration = min(duration, max_ban_duration);
        let rounds_served = ban.active.rounds_served_in_previous_epochs + latest_view.round;
        if (duration >= rounds_served) {
            duration - rounds_served
        } else {
            0
        }
    }

    /// Returns true until ban registry size + minimum proposers required count less than committee size
    fun can_be_added_in_ban(ban_registry_len: u64) : bool {
        let minimum_unbanned_proposers = leader_ban_registry_config::get_minimum_unbanned_proposers();
        let committee_size = stake::get_committee_size();
        committee_size >= ban_registry_len + (minimum_unbanned_proposers as u64)
    }

    /// Validates registry initialised if not aborted with `EBAN_REGISTRY_NOT_INITIALIZED`
    fun assert_registry_initialized() {
        assert!(
            exists<BanRegistry>(@supra_framework),
            error::invalid_state(EBAN_REGISTRY_NOT_INITIALIZED)
        );
    }
}
