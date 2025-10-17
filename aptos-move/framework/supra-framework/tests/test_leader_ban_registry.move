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

    #[test(sender = @supra_framework, validator_1 = @0xdead01, validator_2 = @0xdead02, validator_3 = @0xdead03, validator_4 = @0xdead04)]
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
        leader_ban_registry_config::initialize(sender,ban_config_bytes);

        // initialise ban registry
        leader_ban_registry::initialize_leader_ban_registry(sender);

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
        stake::create_stake_pool(validator_1, active_coin, pending_coin, 500000000);

        let active_coin = coin::withdraw<SupraCoin>(validator_2, 500);
        let pending_coin = coin::withdraw<SupraCoin>(validator_2, 1000);
        stake::create_stake_pool(validator_2, active_coin, pending_coin, 500000000);

        let active_coin = coin::withdraw<SupraCoin>(validator_3, 500);
        let pending_coin = coin::withdraw<SupraCoin>(validator_3, 1000);
        stake::create_stake_pool(validator_3, active_coin, pending_coin, 500000000);

        let active_coin = coin::withdraw<SupraCoin>(validator_4, 500);
        let pending_coin = coin::withdraw<SupraCoin>(validator_4, 1000);
        stake::create_stake_pool(validator_4, active_coin, pending_coin, 500000000);

        stake::join_validator_set_for_test(&ed25519::public_key_to_unvalidated(&v_4_p_key), validator_4, signer::address_of(validator_4), false);
        stake::join_validator_set_for_test(&ed25519::public_key_to_unvalidated(&v_3_p_key), validator_3,signer::address_of(validator_3), false);
        stake::join_validator_set_for_test(&ed25519::public_key_to_unvalidated(&v_2_p_key), validator_2, signer::address_of(validator_2), false);
        stake::join_validator_set_for_test(&ed25519::public_key_to_unvalidated(&v_1_p_key), validator_1, signer::address_of(validator_1), true); // on epoch change

        // update ban registry
        leader_ban_registry::update_ban_registry(0, 0, option::some(0), vector::empty());

        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 0, 1);

        leader_ban_registry::update_ban_registry(0, 1, option::some(2), vector[1]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        assert!(vector::length(&ban_registry) == 1, 1);

        aptos_std::debug::print(&ban_registry);
        aptos_std::debug::print(&stake::get_committee_pool_addresses());

        assert!(signer::address_of(validator_2) == leader_ban_registry::get_pool_address_from_vp(vector::borrow(&ban_registry, 0)), 2 );

        leader_ban_registry::update_ban_registry(0, 8, option::some(2), vector[1]);
        let ban_registry = leader_ban_registry::get_ban_registry();
        aptos_std::debug::print(&ban_registry);
    }
}
