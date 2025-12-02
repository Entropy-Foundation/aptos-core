#[test_only]
module supra_framework::appchain_registry_tests {
    use std::string;
    use std::vector;

    use supra_framework::account;
    use supra_framework::appchain_registry;


    /// Registered as a appchain, but decommissioned from the Supra-L1.
    const STATE_INACTIVE: u8 = 0;
    /// Registered as a appchain and actively working.
    const STATE_ACTIVE: u8 = 1;
    /// Never registered as a appchain.
    const STATE_UNKNOWN: u8 = 2;

    // Test constants
    const TEST_CHAIN_ID_1: u16 = 10;
    const TEST_CHAIN_ID_2: u16 = 20;
    const TEST_CHAIN_ID_3: u16 = 30;
    const RESERVED_CHAIN_ID: u16 = 5;


    fun setup_test(): signer {
        let supra_framework = account::create_account_for_test(@supra_framework);
        appchain_registry::initialize(&supra_framework, vector::empty());
        supra_framework
    }

    fun create_metadata_link(suffix: vector<u8>): string::String {
        let base = b"https://temp.com/temp/";
        vector::append(&mut base, suffix);
        string::utf8(base)
    }

    // Module Initialization Tests.

    #[test]
    fun test_initialize() {
        let supra_framework = account::create_account_for_test(@supra_framework);
        appchain_registry::initialize(
            &supra_framework,
            vector[
                appchain_registry::new_reserved_range(0, 0),
                appchain_registry::new_reserved_range(1, 10)
            ]
        );
        assert!(appchain_registry::appchain_state(TEST_CHAIN_ID_1) == STATE_UNKNOWN, 1);
        assert!(appchain_registry::is_chain_id_reserved(6), 2)
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = supra_framework::system_addresses)]
    fun test_initialize_with_non_supra_framework() {
        let non_supra_framework = account::create_account_for_test(@0x123);
        appchain_registry::initialize(&non_supra_framework, vector::empty());
    }


    // Register Appchain Tests.

    #[test]
    fun test_register_appchain() {
        let supra_framework = setup_test();
        let metadata = create_metadata_link(b"chain1");
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            metadata
        );
        assert!(appchain_registry::appchain_state(TEST_CHAIN_ID_1) == STATE_ACTIVE, 1);
        assert!(appchain_registry::is_appchain_active(TEST_CHAIN_ID_1), 2);
        assert!(appchain_registry::appchain_metadata_link(TEST_CHAIN_ID_1) == metadata, 3);

        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_2,
            create_metadata_link(b"chain2")
        );
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_3,
            create_metadata_link(b"chain3")
        );
        assert!(appchain_registry::is_appchain_active(TEST_CHAIN_ID_2), 4);
        assert!(appchain_registry::is_appchain_active(TEST_CHAIN_ID_3), 5);
        assert!(appchain_registry::active_appchains() == vector[30, 20, 10], 6)
    }


    #[test]
    #[expected_failure(abort_code = 0x60006, location = supra_framework::appchain_registry)]
    fun test_register_appchain_without_initialization() {
        let supra_framework = account::create_account_for_test(@supra_framework);
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = supra_framework::system_addresses)]
    fun test_register_appchain_with_non_supra_framework_signer() {
        let _ = setup_test();
        let non_supra_framework = account::create_account_for_test(@0x123);
        appchain_registry::register_appchain(
            &non_supra_framework,
            RESERVED_CHAIN_ID,
            create_metadata_link(b"reserved")
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x80001, location = supra_framework::appchain_registry)]
    fun test_register_appchain_with_already_registered_appchain() {
        let supra_framework = setup_test();
        let metadata = create_metadata_link(b"chain1");
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            metadata
        );
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1_duplicate")
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x10003, location = supra_framework::appchain_registry)]
    fun test_register_appchain_with_reserved_chain_id() {
        let supra_framework = setup_test();
        appchain_registry::add_reserved_range(&supra_framework, 1, 10);

        appchain_registry::register_appchain(
            &supra_framework,
            RESERVED_CHAIN_ID,
            create_metadata_link(b"reserved")
        );
    }


    // Deactivate Appchain Tests.

    #[test]
    fun test_deactivate_appchain_success() {
        let supra_framework = setup_test();
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        appchain_registry::deactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);

        assert!(appchain_registry::appchain_state(TEST_CHAIN_ID_1) == STATE_INACTIVE, 1);
        assert!(!appchain_registry::is_appchain_active(TEST_CHAIN_ID_1), 2);
    }

    #[test]
    #[expected_failure(abort_code = 0x60002, location = supra_framework::appchain_registry)]
    fun test_deactivate_appchain_with_unregistered_appchain() {
        let supra_framework = setup_test();
        appchain_registry::deactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);
    }

    #[test]
    #[expected_failure(abort_code = 0x30004, location = supra_framework::appchain_registry)]
    fun test_deactivate_appchain_with_already_deactivated_appchain() {
        let supra_framework = setup_test();
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        // Here, we are deactivating it first time.
        appchain_registry::deactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);
        // Now, again we are trying to deactivate the appchain and this should cause failure.
        appchain_registry::deactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);
    }


    // Reactivate Appchain Tests.

    #[test]
    fun test_reactivate_appchain() {
        let supra_framework = setup_test();
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        appchain_registry::deactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);
        appchain_registry::reactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);

        assert!(appchain_registry::appchain_state(TEST_CHAIN_ID_1) == STATE_ACTIVE, 1);
        assert!(appchain_registry::is_appchain_active(TEST_CHAIN_ID_1), 2);
    }

    #[test]
    #[expected_failure(abort_code = 0x60002, location = supra_framework::appchain_registry)]
    fun test_reactivate_appchain_with_unregistered_appchain() {
        let supra_framework = setup_test();
        appchain_registry::reactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);
    }

    #[test]
    #[expected_failure(abort_code = 0x30005, location = supra_framework::appchain_registry)]
    fun test_reactivate_appchain_with_already_active_appchain() {
        let supra_framework = setup_test();
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        appchain_registry::reactivate_appchain(&supra_framework, TEST_CHAIN_ID_1);
    }


    // Update Appchain Metadata Link Tests.

    #[test]
    fun test_update_appchain_metadata_link() {
        let supra_framework = setup_test();
        let initial_metadata = create_metadata_link(b"chain1");
        let new_metadata = create_metadata_link(b"chain1_updated");
        appchain_registry::register_appchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            initial_metadata
        );
        assert!(appchain_registry::appchain_metadata_link(TEST_CHAIN_ID_1) == initial_metadata, 1);

        // Now, Updating the metadata link.
        appchain_registry::update_appchain_metadata_link(
            &supra_framework,
            TEST_CHAIN_ID_1,
            new_metadata
        );
        assert!(appchain_registry::appchain_metadata_link(TEST_CHAIN_ID_1) == new_metadata, 2);
    }

    #[test]
    #[expected_failure(abort_code = 0x60002, location = supra_framework::appchain_registry)]
    fun test_update_appchain_metadata_link_with_unregistered_appchain() {
        let supra_framework = setup_test();
        appchain_registry::update_appchain_metadata_link(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
    }


    // Add Reserved Ranges Tests.

    #[test]
    fun test_add_reserved_range() {
        let supra_framework = setup_test();
        appchain_registry::add_reserved_range(&supra_framework, 1, 10);
        appchain_registry::add_reserved_range(&supra_framework, 200, 255);

        // Verify reserved ranges
        assert!(appchain_registry::is_chain_id_reserved(1), 1);
        assert!(appchain_registry::is_chain_id_reserved(5), 2);
        assert!(appchain_registry::is_chain_id_reserved(10), 3);
        assert!(!appchain_registry::is_chain_id_reserved(50), 4);
        assert!(appchain_registry::is_chain_id_reserved(220), 5);
        assert!(!appchain_registry::is_chain_id_reserved(0), 6);

        // Reserving single range, trying 0-0.
        appchain_registry::add_reserved_range(&supra_framework, 0, 0);
        assert!(appchain_registry::is_chain_id_reserved(0), 7);
    }

    #[test]
    fun test_overlapping_reserved_ranges() {
        let supra_framework = setup_test();

        appchain_registry::add_reserved_range(&supra_framework, 10, 20);
        appchain_registry::add_reserved_range(&supra_framework, 15, 25);
        appchain_registry::add_reserved_range(&supra_framework, 20, 30);

        // All overlapping IDs should be reserved
        assert!(appchain_registry::is_chain_id_reserved(10), 1);
        assert!(appchain_registry::is_chain_id_reserved(15), 2);
        assert!(appchain_registry::is_chain_id_reserved(20), 3);
        assert!(appchain_registry::is_chain_id_reserved(25), 4);
        assert!(appchain_registry::is_chain_id_reserved(30), 5);
    }

    #[test]
    #[expected_failure(abort_code = 0x10007, location = supra_framework::appchain_registry)]
    fun test_add_reserved_range_with_invalid_range() {
        let supra_framework = setup_test();
        appchain_registry::add_reserved_range(&supra_framework, 20, 10);
    }
}
