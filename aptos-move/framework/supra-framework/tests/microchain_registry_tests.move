/// Copywrite (c) 2025 Supra
/// Microchain Registry Module testcases.
#[test_only]
module supra_framework::microchain_registry_tests {
    use std::string;
    use std::vector;

    use supra_framework::account;
    use supra_framework::microchain_registry;


    /// Never registered as a mirochain.
    const STATE_UNKNOWN: u8 = 0;
    /// Registered as a microchain and actively working.
    const STATE_ACTIVE: u8 = 1;
    /// Registered as a microchain, but decommissioned from the Supra-L1.
    const STATE_INACTIVE: u8 = 2;

    // Test constants
    const TEST_CHAIN_ID_1: u8 = 10;
    const TEST_CHAIN_ID_2: u8 = 20;
    const TEST_CHAIN_ID_3: u8 = 30;
    const RESERVED_CHAIN_ID: u8 = 5;


    fun setup_test(): signer {
        let supra_framework = account::create_account_for_test(@supra_framework);
        microchain_registry::initialize(&supra_framework, vector::empty());
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
        microchain_registry::initialize(
            &supra_framework,
            vector[
                microchain_registry::new_reserved_range(0, 0),
                microchain_registry::new_reserved_range(1, 10)
            ]
        );
        assert!(microchain_registry::microchain_state(TEST_CHAIN_ID_1) == STATE_UNKNOWN, 1);
        assert!(microchain_registry::is_chain_id_reserved(6), 2)
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = supra_framework::system_addresses)]
    fun test_initialize_with_non_supra_framework() {
        let non_supra_framework = account::create_account_for_test(@0x123);
        microchain_registry::initialize(&non_supra_framework, vector::empty());
    }


    // Register Microchain Tests.

    #[test]
    fun test_register_microchain() {
        let supra_framework = setup_test();
        let metadata = create_metadata_link(b"chain1");
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            metadata
        );
        assert!(microchain_registry::microchain_state(TEST_CHAIN_ID_1) == STATE_ACTIVE, 1);
        assert!(microchain_registry::is_microchain_active(TEST_CHAIN_ID_1), 2);
        assert!(microchain_registry::microchain_metadata_link(TEST_CHAIN_ID_1) == metadata, 3);

        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_2,
            create_metadata_link(b"chain2")
        );
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_3,
            create_metadata_link(b"chain3")
        );
        assert!(microchain_registry::is_microchain_active(TEST_CHAIN_ID_2), 4);
        assert!(microchain_registry::is_microchain_active(TEST_CHAIN_ID_3), 5);
        assert!(microchain_registry::active_microchains() == vector[30, 20, 10], 6)
    }


    #[test]
    #[expected_failure(abort_code = 0x60006, location = supra_framework::microchain_registry)]
    fun test_register_microchain_without_initialization() {
        let supra_framework = account::create_account_for_test(@supra_framework);
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x50003, location = supra_framework::system_addresses)]
    fun test_register_microchain_with_non_supra_framework_signer() {
        let _ = setup_test();
        let non_supra_framework = account::create_account_for_test(@0x123);
        microchain_registry::register_microchain(
            &non_supra_framework,
            RESERVED_CHAIN_ID,
            create_metadata_link(b"reserved")
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x80001, location = supra_framework::microchain_registry)]
    fun test_register_microchain_with_already_registered_microchain() {
        let supra_framework = setup_test();
        let metadata = create_metadata_link(b"chain1");
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            metadata
        );
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1_duplicate")
        );
    }

    #[test]
    #[expected_failure(abort_code = 0x10003, location = supra_framework::microchain_registry)]
    fun test_register_microchain_with_reserved_chain_id() {
        let supra_framework = setup_test();
        microchain_registry::add_reserved_range(&supra_framework, 1, 10);

        microchain_registry::register_microchain(
            &supra_framework,
            RESERVED_CHAIN_ID,
            create_metadata_link(b"reserved")
        );
    }


    // Deactivate Microchain Tests.

    #[test]
    fun test_deactivate_microchain_success() {
        let supra_framework = setup_test();
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        microchain_registry::deactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);

        assert!(microchain_registry::microchain_state(TEST_CHAIN_ID_1) == STATE_INACTIVE, 1);
        assert!(!microchain_registry::is_microchain_active(TEST_CHAIN_ID_1), 2);
    }

    #[test]
    #[expected_failure(abort_code = 0x60002, location = supra_framework::microchain_registry)]
    fun test_deactivate_microchain_with_unregistered_microchain() {
        let supra_framework = setup_test();
        microchain_registry::deactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);
    }

    #[test]
    #[expected_failure(abort_code = 0x30004, location = supra_framework::microchain_registry)]
    fun test_deactivate_microchain_with_already_deactivated_microchain() {
        let supra_framework = setup_test();
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        // Here, we are deactivating it first time.
        microchain_registry::deactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);
        // Now, again we are trying to deactivate the microchain and this should cause failure.
        microchain_registry::deactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);
    }


    // Reactivate Microchain Tests.

    #[test]
    fun test_reactivate_microchain() {
        let supra_framework = setup_test();
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        microchain_registry::deactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);
        microchain_registry::reactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);

        assert!(microchain_registry::microchain_state(TEST_CHAIN_ID_1) == STATE_ACTIVE, 1);
        assert!(microchain_registry::is_microchain_active(TEST_CHAIN_ID_1), 2);
    }

    #[test]
    #[expected_failure(abort_code = 0x60002, location = supra_framework::microchain_registry)]
    fun test_reactivate_microchain_with_unregistered_microchain() {
        let supra_framework = setup_test();
        microchain_registry::reactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);
    }

    #[test]
    #[expected_failure(abort_code = 0x30005, location = supra_framework::microchain_registry)]
    fun test_reactivate_microchain_with_already_active_microchain() {
        let supra_framework = setup_test();
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
        microchain_registry::reactivate_microchain(&supra_framework, TEST_CHAIN_ID_1);
    }


    // Update Microchain Metadata Link Tests.

    #[test]
    fun test_update_microchain_metadata_link() {
        let supra_framework = setup_test();
        let initial_metadata = create_metadata_link(b"chain1");
        let new_metadata = create_metadata_link(b"chain1_updated");
        microchain_registry::register_microchain(
            &supra_framework,
            TEST_CHAIN_ID_1,
            initial_metadata
        );
        assert!(microchain_registry::microchain_metadata_link(TEST_CHAIN_ID_1) == initial_metadata, 1);

        // Now, Updating the metadata link.
        microchain_registry::update_microchain_metadata_link(
            &supra_framework,
            TEST_CHAIN_ID_1,
            new_metadata
        );
        assert!(microchain_registry::microchain_metadata_link(TEST_CHAIN_ID_1) == new_metadata, 2);
    }

    #[test]
    #[expected_failure(abort_code = 0x60002, location = supra_framework::microchain_registry)]
    fun test_update_microchain_metadata_link_with_unregistered_microchain() {
        let supra_framework = setup_test();
        microchain_registry::update_microchain_metadata_link(
            &supra_framework,
            TEST_CHAIN_ID_1,
            create_metadata_link(b"chain1")
        );
    }


    // Add Reserved Ranges Tests.

    #[test]
    fun test_add_reserved_range() {
        let supra_framework = setup_test();
        microchain_registry::add_reserved_range(&supra_framework, 1, 10);
        microchain_registry::add_reserved_range(&supra_framework, 200, 255);

        // Verify reserved ranges
        assert!(microchain_registry::is_chain_id_reserved(1), 1);
        assert!(microchain_registry::is_chain_id_reserved(5), 2);
        assert!(microchain_registry::is_chain_id_reserved(10), 3);
        assert!(!microchain_registry::is_chain_id_reserved(50), 4);
        assert!(microchain_registry::is_chain_id_reserved(220), 5);
        assert!(!microchain_registry::is_chain_id_reserved(0), 6);

        // Reserving single range, trying 0-0.
        microchain_registry::add_reserved_range(&supra_framework, 0, 0);
        assert!(microchain_registry::is_chain_id_reserved(0), 7);
    }

    #[test]
    fun test_overlapping_reserved_ranges() {
        let supra_framework = setup_test();

        microchain_registry::add_reserved_range(&supra_framework, 10, 20);
        microchain_registry::add_reserved_range(&supra_framework, 15, 25);
        microchain_registry::add_reserved_range(&supra_framework, 20, 30);

        // All overlapping IDs should be reserved
        assert!(microchain_registry::is_chain_id_reserved(10), 1);
        assert!(microchain_registry::is_chain_id_reserved(15), 2);
        assert!(microchain_registry::is_chain_id_reserved(20), 3);
        assert!(microchain_registry::is_chain_id_reserved(25), 4);
        assert!(microchain_registry::is_chain_id_reserved(30), 5);
    }

    #[test]
    #[expected_failure(abort_code = 0x10007, location = supra_framework::microchain_registry)]
    fun test_add_reserved_range_with_invalid_range() {
        let supra_framework = setup_test();
        microchain_registry::add_reserved_range(&supra_framework, 20, 10);
    }
}