#[test_only]
module std::test_leader_ban_registry {
    use std::bcs;
    use std::option;
    use std::vector;
    use aptos_std::ed25519;
    use supra_framework::supra_coin;
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::stake;
    use supra_framework::leader_ban_registry;
    use supra_framework::leader_ban_registry_config;
    use std::signer;
    use supra_framework::account;

    fun setup_staking_modules(
        sender: &signer,
        validator_1: &signer,
        validator_2: &signer,
        validator_3: &signer,
        validator_4: &signer
    ) {
        // initialise stake module
        let (_v_1_s_key, v_1_p_key) = ed25519::generate_keys();
        let (_v_2_s_key, v_2_p_key) = ed25519::generate_keys();
        let (_v_3_s_key, v_3_p_key) = ed25519::generate_keys();
        let (_v_4_s_key, v_4_p_key) = ed25519::generate_keys();

        stake::initialize_for_test(sender);
        account::create_account_for_test(signer::address_of(validator_1));
        coin::register<SupraCoin>(validator_1);
        supra_coin::mint(sender, signer::address_of(validator_1), 10000000000);

        account::create_account_for_test(signer::address_of(validator_2));
        coin::register<SupraCoin>(validator_2);
        supra_coin::mint(sender, signer::address_of(validator_2), 10000000000);

        account::create_account_for_test(signer::address_of(validator_3));
        coin::register<SupraCoin>(validator_3);
        supra_coin::mint(sender, signer::address_of(validator_3), 10000000000);

        account::create_account_for_test(signer::address_of(validator_4));
        coin::register<SupraCoin>(validator_4);
        supra_coin::mint(sender, signer::address_of(validator_4), 10000000000);

        let active_coin = coin::withdraw<SupraCoin>(validator_1, 500);
        let pending_coin = coin::withdraw<SupraCoin>(validator_1, 1000);
        stake::create_stake_pool(
            validator_1,
            active_coin,
            pending_coin,
            500000000
        );

        let active_coin = coin::withdraw<SupraCoin>(validator_2, 500);
        let pending_coin = coin::withdraw<SupraCoin>(validator_2, 1000);
        stake::create_stake_pool(
            validator_2,
            active_coin,
            pending_coin,
            500000000
        );

        let active_coin = coin::withdraw<SupraCoin>(validator_3, 500);
        let pending_coin = coin::withdraw<SupraCoin>(validator_3, 1000);
        stake::create_stake_pool(
            validator_3,
            active_coin,
            pending_coin,
            500000000
        );

        let active_coin = coin::withdraw<SupraCoin>(validator_4, 500);
        let pending_coin = coin::withdraw<SupraCoin>(validator_4, 1000);
        stake::create_stake_pool(
            validator_4,
            active_coin,
            pending_coin,
            500000000
        );

        stake::join_validator_set_for_test(
            &ed25519::public_key_to_unvalidated(&v_4_p_key),
            validator_4,
            signer::address_of(validator_4),
            false
        );
        stake::join_validator_set_for_test(
            &ed25519::public_key_to_unvalidated(&v_3_p_key),
            validator_3,
            signer::address_of(validator_3),
            false
        );
        stake::join_validator_set_for_test(
            &ed25519::public_key_to_unvalidated(&v_2_p_key),
            validator_2,
            signer::address_of(validator_2),
            false
        );
        stake::join_validator_set_for_test(
            &ed25519::public_key_to_unvalidated(&v_1_p_key),
            validator_1,
            signer::address_of(validator_1),
            true
        ); // on epoch change
    }

    #[
        test(
            sender = @supra_framework,
            validator_1 = @0xdead01,
            validator_2 = @0xdead02,
            validator_3 = @0xdead03,
            validator_4 = @0xdead04
        )
    ]
    fun test_ban_registy_e2e(
        sender: &signer,
        validator_1: &signer,
        validator_2: &signer,
        validator_3: &signer,
        validator_4: &signer
    ) {
        // initialise ban registry config
        let ban_params = leader_ban_registry_config::get_test_ban_registry_params_v0();
        let ban_config_bytes = bcs::to_bytes(&ban_params);
        leader_ban_registry_config::initialize(sender, ban_config_bytes);

        // initialise ban registry
        leader_ban_registry::initialize_leader_ban_registry(sender);
        setup_staking_modules(
            sender,
            validator_1,
            validator_2,
            validator_3,
            validator_4
        );

        // update ban registry
        leader_ban_registry::update_ban_registry(0, 0, option::some(0), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 0, 1);

        // Let's say for round 1 validator 2 failed to propose
        leader_ban_registry::update_ban_registry(0, 1, option::some(2), vector[1]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 1, 2);
        assert!(
            signer::address_of(validator_2)
                == leader_ban_registry::get_pool_address_from_vp(
                    vector::borrow(&ban_registry, 0)
                ),
            3
        );

        // Let's say for round 5 validator 2 failed to propose again
        leader_ban_registry::update_ban_registry(0, 5, option::some(2), vector[1]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 1, 4);

        // If on round 9 the validator 2 is able to propose then it will be removed from registry
        leader_ban_registry::update_ban_registry(0, 9, option::some(1), vector[]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 0, 5);

        // Now let's say validator 1 is unable to propose
        leader_ban_registry::update_ban_registry(0, 12, option::some(1), vector[0]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(
            signer::address_of(validator_1)
                == leader_ban_registry::get_pool_address_from_vp(vp),
            6
        );

        leader_ban_registry::update_ban_registry(
            0, 12 + (4 * 1), option::some(1), vector[0]
        );
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 1, 8);
        assert!(vector::length(&ban_registry) == 1, 9);

        leader_ban_registry::update_ban_registry(
            0, 12 + (4 * 2), option::some(1), vector[0]
        );
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 2, 8);
        assert!(vector::length(&ban_registry) == 1, 9);

        leader_ban_registry::update_ban_registry(
            0, 12 + (4 * 3), option::some(1), vector[0]
        );
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 3, 8);
        assert!(vector::length(&ban_registry) == 1, 9);

        // At round 28, validator 1 is banned again, consecutive_bans=4
        // Ban duration = min(4 * 2^4, 20) = 20 rounds (capped at max)
        // With the reset, the ban starts fresh from round 28
        leader_ban_registry::update_ban_registry(
            0, 12 + (4 * 4), option::some(1), vector[0]
        );
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 4, 8);
        assert!(vector::length(&ban_registry) == 1, 9);

        // Now test ban expiry WITHOUT re-banning the validator
        // The ban was set at round 28 with duration 20, so ban expires at round 28 + 20 = 48
        // Then probation lasts for 4 rounds (probation_elections=1 * committee_size=4)
        // Full reinstatement happens at round 48 + 4 = 52

        // At round 47, the ban should still be active (1 round remaining)
        leader_ban_registry::update_ban_registry(0, 47, option::some(1), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 1, 10);
        let vp = vector::borrow(&ban_registry, 0);
        assert!(!leader_ban_registry::is_on_probation_from_vp(vp), 100); // Still banned, not on probation

        // At round 48, the ban expires and validator transitions to probation
        leader_ban_registry::update_ban_registry(0, 48, option::some(1), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 1, 11); // Still in registry (on probation)
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::is_on_probation_from_vp(vp), 101); // Now on probation

        // At round 51, probation should still be active (1 round remaining)
        leader_ban_registry::update_ban_registry(0, 51, option::some(1), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 1, 12);
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::is_on_probation_from_vp(vp), 102);

        // At round 52, probation expires and validator is fully reinstated
        leader_ban_registry::update_ban_registry(0, 52, option::some(1), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 0, 13); // Fully removed from registry

        // Now lets try to fail 3 of them
        leader_ban_registry::update_ban_registry(0, 60, option::some(3), vector[0, 1, 2]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        // only 2 will be banned because of proposer limit of 2
        assert!(vector::length(&ban_registry) == 2, 14);

        // Re-ban both validators to increase consecutive count
        // Round 64: re-ban, consecutive_bans=1, duration=8, resets from round 64
        leader_ban_registry::update_ban_registry(
            0, 60 + (4 * 1), option::some(2), vector[0, 1]
        );
        // Round 68: re-ban, consecutive_bans=2, duration=16, resets from round 68
        leader_ban_registry::update_ban_registry(
            0, 60 + (4 * 2), option::some(2), vector[0, 1]
        );

        // Now test ban expiry across epoch change WITHOUT re-banning
        // Ban was set at round 68 with duration 16, so ban expires at round 68 + 16 = 84
        // Then probation lasts for 4 rounds, full reinstatement at round 84 + 4 = 88
        // First trigger epoch change
        leader_ban_registry::on_new_epoch(); // assuming every time this is called first before any epoch change

        // In epoch 1, advance rounds without re-banning to let the ban expire naturally
        // Previous epoch ended at round 68, rounds_served_in_previous_epochs will be updated
        // For validators banned at epoch 0 round 68:
        // After on_new_epoch: rounds_served_in_previous_epochs = 0 + (68 - 68) = 0
        // (since epoch_earned == latest_view.epoch, we use latest_view.round - round_earned)

        // At epoch 1 round 0, ban should still be active (rounds_served = 0 + 0 = 0, need 16)
        leader_ban_registry::update_ban_registry(1, 0, option::some(2), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 2, 15);
        let vp = vector::borrow(&ban_registry, 0);
        assert!(!leader_ban_registry::is_on_probation_from_vp(vp), 103);

        // At epoch 1 round 15, ban should still be active (rounds_served = 0 + 15 = 15, need 16)
        leader_ban_registry::update_ban_registry(1, 15, option::some(2), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 2, 16);

        // At epoch 1 round 16, ban expires and validators transition to probation
        leader_ban_registry::update_ban_registry(1, 16, option::some(2), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 2, 17); // Still in registry (on probation)
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::is_on_probation_from_vp(vp), 104);

        // At epoch 1 round 19, probation still active (1 round remaining)
        leader_ban_registry::update_ban_registry(1, 19, option::some(2), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 2, 18);

        // At epoch 1 round 20, probation expires and validators are fully reinstated
        leader_ban_registry::update_ban_registry(1, 20, option::some(2), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        // after epoch change and enough rounds, the ban and probation have been lifted correctly
        assert!(vector::length(&ban_registry) == 0, 19);

        // Test: Re-banning during probation should increase consecutive count
        // Ban validator 1 fresh
        leader_ban_registry::update_ban_registry(1, 25, option::some(2), vector[0]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 1, 20);
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 0, 105);
        assert!(!leader_ban_registry::is_on_probation_from_vp(vp), 106);

        // Ban duration = 4 rounds, so ban expires at round 25 + 4 = 29
        // Transition to probation at round 29
        leader_ban_registry::update_ban_registry(1, 29, option::some(2), vector::empty());
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::is_on_probation_from_vp(vp), 107);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 0, 108);

        // Re-ban during probation should increase consecutive count and reset to banned state
        leader_ban_registry::update_ban_registry(1, 30, option::some(2), vector[0]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        let vp = vector::borrow(&ban_registry, 0);
        assert!(leader_ban_registry::get_consecutive_count_from_vp(vp) == 1, 109); // Consecutive count increased
        assert!(!leader_ban_registry::is_on_probation_from_vp(vp), 110); // Back to banned state

    }
}
