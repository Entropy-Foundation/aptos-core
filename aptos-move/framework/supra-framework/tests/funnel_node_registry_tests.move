#[test_only]
module supra_framework::funnel_node_registry_tests {
    use std::string::{Self, String};
    use std::vector;

    use supra_framework::account;
    use supra_framework::funnel_node_registry;


    // Test helper to create a vector of funnel node Socket-Address
    fun create_test_funnel_nodes(): vector<String> {
        let nodes = vector::empty<String>();
        vector::push_back(&mut nodes, string::utf8(b"1.1.1.1:26000"));
        vector::push_back(&mut nodes, string::utf8(b"2.1.1.1:26000"));
        vector::push_back(&mut nodes, string::utf8(b"3.1.1.1:26000"));
        nodes
    }


    // Test helper to create updated funnel nodes
    fun create_updated_funnel_nodes(): vector<String> {
        let nodes = vector::empty<String>();
        vector::push_back(&mut nodes, string::utf8(b"4.1.1.1:26000"));
        vector::push_back(&mut nodes, string::utf8(b"5.1.1.1:26000"));
        nodes
    }


    // Module Initialization Tests.

    #[test]
    fun test_initialize() {
        let supra_framework = account::create_account_for_test(@supra_framework);
        let funnel_nodes = create_test_funnel_nodes();
        funnel_node_registry::initialize(&supra_framework, funnel_nodes);

        let stored_nodes = funnel_node_registry::funnel_nodes();
        assert!(vector::length(&stored_nodes) == 3, 1);
        assert!(vector::borrow(&stored_nodes, 0) == vector::borrow(&funnel_nodes, 0), 2);
        assert!(vector::borrow(&stored_nodes, 1) == vector::borrow(&funnel_nodes, 1), 3);
        assert!(vector::borrow(&stored_nodes, 2) == vector::borrow(&funnel_nodes, 2), 4);
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = supra_framework::system_addresses)]
    fun test_initialize_fails_non_framework() {
        let non_supra_framework = account::create_account_for_test(@123);
        let funnel_nodes = create_test_funnel_nodes();
        funnel_node_registry::initialize(&non_supra_framework, funnel_nodes);
    }


    // Update Funnel Nodes Tests.

    #[test]
    fun test_update_funnel_nodes() {
        let supra_framework = account::create_account_for_test(@supra_framework);
        let initial_funnel_nodes = create_test_funnel_nodes();
        funnel_node_registry::initialize(&supra_framework, initial_funnel_nodes);

        let new_funnel_nodes = create_updated_funnel_nodes();
        funnel_node_registry::update_funnel_nodes(&supra_framework, new_funnel_nodes);
        let stored_nodes = funnel_node_registry::funnel_nodes();
        assert!(vector::length(&stored_nodes) == 2, 1);
        assert!(vector::borrow(&stored_nodes, 0) == vector::borrow(&new_funnel_nodes, 0), 2);
        assert!(vector::borrow(&stored_nodes, 1) == vector::borrow(&new_funnel_nodes, 1), 3);
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = supra_framework::system_addresses)]
    fun test_update_fails_non_framework() {
        let supra_framework = account::create_account_for_test(@supra_framework);
        let initial_funnel_nodes = create_test_funnel_nodes();
        funnel_node_registry::initialize(&supra_framework, initial_funnel_nodes);

        let non_supra_framework = account::create_account_for_test(@123);
        let new_funnel_nodes = create_updated_funnel_nodes();
        funnel_node_registry::update_funnel_nodes(&non_supra_framework, new_funnel_nodes);
    }

    #[test]
    #[expected_failure(abort_code = 0x60001, location = supra_framework::funnel_node_registry)]
    fun test_update_fails_not_initialized() {
        let supra_framework = account::create_account_for_test(@supra_framework);
        let new_funnel_nodes = create_updated_funnel_nodes();
        funnel_node_registry::update_funnel_nodes(&supra_framework, new_funnel_nodes);
    }
}