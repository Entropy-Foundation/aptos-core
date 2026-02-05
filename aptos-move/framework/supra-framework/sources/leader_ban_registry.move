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
    friend supra_framework::genesis;
    friend supra_framework::reconfiguration;

    #[test_only]
    friend supra_framework::test_leader_ban_registry;

    /// Leader ban registry already initialized
    const EBAN_REGISTRY_ALREADY_EXISTS: u64 = 1;
    /// Leader ban registry not initialized
    const EBAN_REGISTRY_NOT_INITIALIZED: u64 = 2;
    /// Latest view already initialized
    const ELATEST_VIEW_ALREADY_EXISTS: u64 = 3;

    /// Holds metrics for banned round, epoch and round served in prev epoch
    struct ActiveBan has store, drop, copy {
        /// Epoch in which the ban was issued
        epoch_earned: u64,
        /// Round in which the ban was issued
        round_earned: u64,
        /// Round count incremented on every epoch change
        rounds_served_in_previous_epochs: u64
    }

    /// Holds validator metrics regarding duration pool address etc
    struct ValidatorBansWithAddress has store, drop, copy {
        /// Holds active ban counts
        active: ActiveBan,
        /// Consecutive ban count
        consecutive_bans: u32,
        /// Validator's pool address
        pool_address: address,
        /// Whether the validator is on probation (ban expired but still in registry)
        on_probation: bool
    }

    /// Holds ban registry
    struct BanRegistry has drop, store, key {
        /// List of validator active bans with pool address
        bans: vector<ValidatorBansWithAddress>
    }

    /// Holds latest processed round and epoch
    struct LatestView has drop, store, key, copy {
        /// Epoch
        epoch: u64,
        /// Round
        round: u64
    }

    #[event]
    /// Emits when validator receives a ban or consucutive ban occurred
    struct Banned has drop, store {
        /// Validator's pool address
        pool_address: address,
        /// Epoch
        epoch: u64,
        /// Round
        round: u64,
        /// Consecutive bans count
        consecutive_bans: u32
    }

    #[event]
    /// Emits when validator ban lifted and probation period starts
    struct ReinstatedWithProbation has drop, store {
        /// Validator's pool address
        pool_address: address,
        /// Epoch
        epoch: u64,
        /// Round
        round: u64
    }

    #[event]
    /// Emits when validator probation period ends and is fully reinstated
    struct Reinstated has drop, store {
        /// Validator's pool address
        pool_address: address,
        /// Epoch
        epoch: u64,
        /// Round
        round: u64
    }

    /// Initialise leader ban registry
    public(friend) fun initialize_leader_ban_registry(
        supra_framework: &signer
    ) {
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
    /// Returns list of validators active ban with it's pool address
    public fun get_ban_registry(): vector<ValidatorBansWithAddress> acquires BanRegistry {
        if (!exists<BanRegistry>(@supra_framework)) {
            return vector::empty()
        };
        let ban_registry = borrow_global<BanRegistry>(@supra_framework);
        ban_registry.bans
    }

    #[view]
    /// Return initial ban duration
    public fun get_latest_view(): LatestView acquires LatestView {
        if (!exists<LatestView>(@supra_framework)) {
            return LatestView { epoch: 0, round: 0 }
        };
        let latest_view = borrow_global<LatestView>(@supra_framework);
        *latest_view
    }

    #[view]
    /// Return initial ban duration
    public fun get_initial_ban_duration(): u64 {
        let initial_elections_denied =
            leader_ban_registry_config::get_initial_elections_denied();
        let committee_size = stake::get_committee_size();
        committee_size * (initial_elections_denied as u64)
    }

    #[view]
    /// Returns max ban duration
    public fun get_max_ban_duration(): u64 {
        let max_elections_denied = leader_ban_registry_config::get_max_elections_denied();
        let committee_size = stake::get_committee_size();
        committee_size * (max_elections_denied as u64)
    }

    #[view]
    /// Returns probation duration (constant, does not change based on consecutive bans)
    public fun get_probation_duration(): u64 {
        let probation_elections = leader_ban_registry_config::get_probation_elections();
        let committee_size = stake::get_committee_size();
        committee_size * (probation_elections as u64)
    }

    /// Add or update the ban registry as per block metadata
    public(friend) fun update_ban_registry(
        current_epoch: u64,
        current_round: u64,
        proposer_index: Option<u64>,
        failed_proposer_indices: vector<u64>
    ) acquires BanRegistry, LatestView {
        if (!exists<BanRegistry>(@supra_framework)) { return };
        if (!exists<LatestView>(@supra_framework)) { return };
        let ban_registry = borrow_global_mut<BanRegistry>(@supra_framework);
        let latest_view = borrow_global_mut<LatestView>(@supra_framework);
        latest_view.epoch = current_epoch;
        latest_view.round = current_round;

        // ban the failed proposers
        ban_failed_proposers(latest_view, failed_proposer_indices, ban_registry);

        // remove expired bans
        reinstate_expired_bans(latest_view, ban_registry);

        // unban the proposer
        if (std::option::is_some(&proposer_index)) {
            let extracted_proposer_index = *std::option::borrow(&mut proposer_index);
            reinstate_proposer(latest_view, extracted_proposer_index, ban_registry);
        };
    }

    /// Adds failed proposer indices to ban registry
    fun ban_failed_proposers(
        latest_view: &LatestView,
        failed_proposer_indices: vector<u64>,
        ban_registry: &mut BanRegistry
    ) {
        let initial_ban_duration = get_initial_ban_duration();
        if (initial_ban_duration == 0) { return };

        vector::for_each(
            failed_proposer_indices,
            |failed_validator_index| {
                let validator_pool_address_opt =
                    stake::get_pool_address_from_index(failed_validator_index);
                if (option::is_some(&validator_pool_address_opt)) {
                    let validator_pool_address =
                        option::extract(&mut validator_pool_address_opt);
                    let (is_banned, index) = vector::find(
                        &ban_registry.bans,
                        |v| {
                            let v: &ValidatorBansWithAddress = v;
                            validator_pool_address == v.pool_address
                        }
                    );
                    if (is_banned) {
                        // Validator is already in registry (either banned or on probation)
                        // Re-banning resets the ban period and increases consecutive count
                        let bans = vector::borrow_mut(&mut ban_registry.bans, index);
                        bans.consecutive_bans = bans.consecutive_bans + 1;
                        bans.active.round_earned = latest_view.round;
                        bans.active.epoch_earned = latest_view.epoch;
                        bans.active.rounds_served_in_previous_epochs = 0;
                        bans.on_probation = false; // Reset to banned state
                        if (features::module_event_enabled()) {
                            event::emit(
                                Banned {
                                    pool_address: validator_pool_address,
                                    epoch: latest_view.epoch,
                                    round: latest_view.round,
                                    consecutive_bans: bans.consecutive_bans
                                }
                            );
                        }
                    } else {
                        let ban_registry_len = vector::length(&ban_registry.bans);
                        if (can_be_banned(ban_registry_len)) {
                            let ban_with_address = ValidatorBansWithAddress {
                                active: ActiveBan {
                                    epoch_earned: latest_view.epoch,
                                    round_earned: latest_view.round,
                                    rounds_served_in_previous_epochs: 0
                                },
                                consecutive_bans: 0,
                                pool_address: validator_pool_address,
                                on_probation: false
                            };
                            vector::push_back(&mut ban_registry.bans, ban_with_address);

                            if (features::module_event_enabled()) {
                                event::emit(
                                    Banned {
                                        pool_address: ban_with_address.pool_address,
                                        epoch: ban_with_address.active.epoch_earned,
                                        round: ban_with_address.active.round_earned,
                                        consecutive_bans: ban_with_address.consecutive_bans
                                    }
                                );
                            }
                        }
                    };
                };
            }
        );
    }

    /// Handles ban and probation expiry:
    /// - When ban expires: transitions to probation, emits ReinstatedWithProbation
    /// - When probation expires: removes from registry, emits Reinstated
    fun reinstate_expired_bans(
        latest_view: &LatestView, ban_registry: &mut BanRegistry
    ) {
        let probation_duration = get_probation_duration();

        // First pass: transition expired bans to probation
        let pool_addresses_to_probation = vector::empty();
        vector::for_each_ref(
            &ban_registry.bans,
            |v| {
                let v: &ValidatorBansWithAddress = v;
                if (!v.on_probation && remaining_ban_duration(v, latest_view) == 0) {
                    vector::push_back(&mut pool_addresses_to_probation, v.pool_address);
                }
            }
        );

        vector::for_each_ref(
            &pool_addresses_to_probation,
            |p| {
                let (found, index) = vector::find(
                    &ban_registry.bans,
                    |v| {
                        let v: &ValidatorBansWithAddress = v;
                        &v.pool_address == p
                    }
                );
                if (found) {
                    let ban = vector::borrow_mut(&mut ban_registry.bans, index);
                    ban.on_probation = true;
                    // Reset active fields so probation duration is calculated from this point
                    ban.active.epoch_earned = latest_view.epoch;
                    ban.active.round_earned = latest_view.round;
                    ban.active.rounds_served_in_previous_epochs = 0;
                    if (features::module_event_enabled()) {
                        event::emit(
                            ReinstatedWithProbation {
                                epoch: latest_view.epoch,
                                round: latest_view.round,
                                pool_address: *p
                            }
                        )
                    }
                }
            }
        );

        // Second pass: remove validators whose probation has expired
        let pool_addresses_for_full_reinstatement = vector::empty();
        vector::for_each_ref(
            &ban_registry.bans,
            |v| {
                let v: &ValidatorBansWithAddress = v;
                if (v.on_probation
                    && remaining_probation_duration(v, latest_view, probation_duration) == 0) {
                    vector::push_back(&mut pool_addresses_for_full_reinstatement, v.pool_address);
                }
            }
        );

        vector::for_each_ref(
            &pool_addresses_for_full_reinstatement,
            |p| {
                let (found, index) = vector::find(
                    &ban_registry.bans,
                    |v| {
                        let v: &ValidatorBansWithAddress = v;
                        &v.pool_address == p
                    }
                );
                if (found) {
                    vector::swap_remove(&mut ban_registry.bans, index);
                    if (features::module_event_enabled()) {
                        event::emit(
                            Reinstated {
                                epoch: latest_view.epoch,
                                round: latest_view.round,
                                pool_address: *p
                            }
                        )
                    }
                }
            }
        );
    }

    /// Remvoing an entry of validator from registry if found at proposer index
    fun reinstate_proposer(
        latest_view: &LatestView, proposer_index: u64, ban_registry: &mut BanRegistry
    ) {
        let validator_pool_address_opt =
            stake::get_pool_address_from_index(proposer_index);
        if (option::is_some(&validator_pool_address_opt)) {
            let validator_pool_address = option::extract(
                &mut validator_pool_address_opt
            );
            let (is_banned, index) = vector::find(
                &ban_registry.bans,
                |v| {
                    let v: &ValidatorBansWithAddress = v;
                    validator_pool_address == v.pool_address
                }
            );
            if (is_banned) {
                vector::swap_remove(&mut ban_registry.bans, index);
                if (features::module_event_enabled()) {
                    event::emit(
                        Reinstated {
                            round: latest_view.round,
                            epoch: latest_view.epoch,
                            pool_address: validator_pool_address
                        }
                    )
                }
            };
        };
    }

    /// Update counts on every epoch
    /// Only run after committee has been updated from reconfigure
    public(friend) fun on_new_epoch() acquires BanRegistry, LatestView {
        if (!exists<LatestView>(@supra_framework)) { return };
        if (!exists<BanRegistry>(@supra_framework)) { return };
        let latest_view = borrow_global<LatestView>(@supra_framework);
        let ban_registry = borrow_global_mut<BanRegistry>(@supra_framework);

        // The pool addresses of the validators for the new epoch.
        let new_committee_pool_addresses = stake::get_committee_pool_addresses();
        // The pool addresses of the validators that have left the committee.
        let retired_validators = vector::empty();
        vector::for_each_mut(
            &mut ban_registry.bans,
            |v| {
                let v: &mut ValidatorBansWithAddress = v;
                if (has_started(&v.active, latest_view)) {
                    if (latest_view.epoch > v.active.epoch_earned) {
                        v.active.rounds_served_in_previous_epochs = v.active.rounds_served_in_previous_epochs
                            + latest_view.round;
                    } else {
                        v.active.rounds_served_in_previous_epochs = v.active.rounds_served_in_previous_epochs
                            + latest_view.round - v.active.round_earned;
                    }
                };
                if (!vector::contains(&new_committee_pool_addresses, &v.pool_address)) {
                    vector::push_back(&mut retired_validators, v.pool_address)
                }
            }
        );

        vector::for_each_ref(
            &retired_validators,
            |p| {
                let (is_banned, index) = vector::find(
                    &ban_registry.bans,
                    |v| {
                        let v: &ValidatorBansWithAddress = v;
                        &v.pool_address == p
                    }
                );
                if (is_banned) {
                    vector::swap_remove(&mut ban_registry.bans, index);
                    if (features::module_event_enabled()) {
                        event::emit(
                            Reinstated {
                                pool_address: *p,
                                epoch: latest_view.epoch,
                                round: latest_view.round
                            }
                        );
                    }
                }
            }
        );
    }

    /// Checks if ban has already started
    fun has_started(active_ban: &ActiveBan, latest_view: &LatestView): bool {
        active_ban.epoch_earned < latest_view.epoch
            || (
                active_ban.epoch_earned == latest_view.epoch
                    && active_ban.round_earned < latest_view.round
            )
    }

    /// Calculate the number of rounds remaining in a given ban (not including probation).
    fun remaining_ban_duration(
        ban: &ValidatorBansWithAddress, latest_view: &LatestView
    ): u64 {
        let initial_ban_duration = get_initial_ban_duration();
        let max_ban_duration = get_max_ban_duration();
        let duration = initial_ban_duration * pow(2, (ban.consecutive_bans as u64));
        let duration = min(duration, max_ban_duration);
        let rounds_served =
            if (latest_view.epoch > ban.active.epoch_earned) {
                ban.active.rounds_served_in_previous_epochs + latest_view.round
            } else {
                latest_view.round - ban.active.round_earned
            };
        if (duration >= rounds_served) {
            duration - rounds_served
        } else { 0 }
    }

    /// Calculate the number of rounds remaining in probation.
    /// Probation duration is constant and does not scale with consecutive bans.
    fun remaining_probation_duration(
        ban: &ValidatorBansWithAddress, latest_view: &LatestView, probation_duration: u64
    ): u64 {
        let rounds_served =
            if (latest_view.epoch > ban.active.epoch_earned) {
                ban.active.rounds_served_in_previous_epochs + latest_view.round
            } else {
                latest_view.round - ban.active.round_earned
            };
        if (probation_duration >= rounds_served) {
            probation_duration - rounds_served
        } else { 0 }
    }

    /// Returns true until ban registry size + minimum proposers required count less than committee size
    fun can_be_banned(ban_registry_len: u64): bool {
        let minimum_unbanned_proposers =
            leader_ban_registry_config::get_minimum_unbanned_proposers();
        let committee_size = stake::get_committee_size();
        committee_size > ban_registry_len + (minimum_unbanned_proposers as u64)
    }

    /// Validates registry initialised if not aborted with `EBAN_REGISTRY_NOT_INITIALIZED`
    fun assert_registry_initialized() {
        assert!(
            exists<BanRegistry>(@supra_framework),
            error::invalid_state(EBAN_REGISTRY_NOT_INITIALIZED)
        );
    }

    #[test_only]
    public fun get_pool_address_from_vp(
        validator_with_pool_addr: &ValidatorBansWithAddress
    ): address {
        validator_with_pool_addr.pool_address
    }

    #[test_only]
    public fun get_consecutive_count_from_vp(
        validator_with_pool_addr: &ValidatorBansWithAddress
    ): u32 {
        validator_with_pool_addr.consecutive_bans
    }

    #[test_only]
    public fun is_on_probation_from_vp(
        validator_with_pool_addr: &ValidatorBansWithAddress
    ): bool {
        validator_with_pool_addr.on_probation
    }
}
