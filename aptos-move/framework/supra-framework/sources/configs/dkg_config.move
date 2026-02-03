// Copyright (c) 2026 Supra.
/// DKG configuration module for configurable DKG parameters.
/// This config can be updated via governance and takes effect at the next epoch.
module supra_framework::dkg_config {
    use std::error;
    use std::vector;
    use supra_framework::config_buffer;
    use supra_framework::system_addresses;
    use supra_framework::validator_public_keys::{
        CertificateThresholdType,
        validity_certificate_type,
        quorum_certificate_type
    };
    #[test_only]
    use supra_framework::validator_public_keys::unanimous_certificate_type;

    friend supra_framework::genesis;
    friend supra_framework::reconfiguration_with_dkg;

    /// Error: Receiver committees vector cannot be empty.
    const EEMPTY_RECEIVER_COMMITTEES: u64 = 1;
    /// Error: Cannot enable resharing for a threshold type that doesn't exist in current config.
    const ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE: u64 = 2;

    /// Configuration for a single receiver committee in DKG.
    struct ReceiverCommitteeConfig has copy, drop, store {
        /// Whether this committee uses resharing from the previous epoch's public key.
        is_resharing: bool,
        /// The threshold type for this committee (e.g., validity, quorum).
        threshold_type: CertificateThresholdType,
    }

    /// Main DKG configuration stored at @supra_framework.
    /// Controls DKG parameters that can be updated via governance.
    struct DkgConfig has copy, drop, key, store {
        /// Threshold type for the dealer committee.
        dealer_threshold_type: CertificateThresholdType,
        /// Configuration for each receiver committee.
        /// Default: [(false, validity), (false, quorum)]
        receiver_committees: vector<ReceiverCommitteeConfig>,
    }

    // ========================
    // Initialization
    // ========================

    /// Initialize DKG config during genesis.
    public(friend) fun initialize(framework: &signer) {
        system_addresses::assert_supra_framework(framework);
        if (!exists<DkgConfig>(@supra_framework)) {
            move_to(framework, default());
        }
    }

    // ========================
    // Config Update (Governance)
    // ========================

    /// Set a new DKG config for the next epoch.
    /// This can only be called by on-chain governance.
    /// Example usage:
    /// ```
    /// let new_config = dkg_config::new(
    ///     quorum_certificate_type(),
    ///     vector[
    ///         dkg_config::new_receiver_committee_config(true, validity_certificate_type()),
    ///         dkg_config::new_receiver_committee_config(true, quorum_certificate_type()),
    ///     ]
    /// );
    /// dkg_config::set_for_next_epoch(&framework_signer, new_config);
    /// supra_governance::reconfigure(&framework_signer);
    /// ```
    public fun set_for_next_epoch(framework: &signer, new_config: DkgConfig) acquires DkgConfig {
        system_addresses::assert_supra_framework(framework);
        
        // Validate: receiver_committees cannot be empty
        assert!(
            vector::length(&new_config.receiver_committees) > 0,
            error::invalid_argument(EEMPTY_RECEIVER_COMMITTEES)
        );
        
        // Validate: if resharing is enabled for a threshold type, it must exist in current config
        let current_config = current();
        let i = 0;
        let len = vector::length(&new_config.receiver_committees);
        while (i < len) {
            let new_rc = vector::borrow(&new_config.receiver_committees, i);
            if (new_rc.is_resharing) {
                // Check if this threshold type exists in current config
                assert!(
                    has_threshold_type(&current_config, new_rc.threshold_type),
                    error::invalid_argument(ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE)
                );
            };
            i = i + 1;
        };
        
        config_buffer::upsert(new_config);
    }
    
    /// Check if a threshold type exists in the config's receiver committees.
    fun has_threshold_type(config: &DkgConfig, threshold_type: CertificateThresholdType): bool {
        let i = 0;
        let len = vector::length(&config.receiver_committees);
        while (i < len) {
            let rc = vector::borrow(&config.receiver_committees, i);
            if (rc.threshold_type == threshold_type) {
                return true
            };
            i = i + 1;
        };
        false
    }

    /// Apply any pending DKG config at epoch boundary.
    /// Called from reconfiguration_with_dkg::finish().
    public(friend) fun on_new_epoch(framework: &signer) acquires DkgConfig {
        system_addresses::assert_supra_framework(framework);
        if (config_buffer::does_exist<DkgConfig>()) {
            let new_config = config_buffer::extract<DkgConfig>();
            if (exists<DkgConfig>(@supra_framework)) {
                *borrow_global_mut<DkgConfig>(@supra_framework) = new_config;
            } else {
                move_to(framework, new_config);
            }
        }
    }

    // ========================
    // Constructors
    // ========================

    /// Create a new DkgConfig.
    public fun new(
        dealer_threshold_type: CertificateThresholdType,
        receiver_committees: vector<ReceiverCommitteeConfig>
    ): DkgConfig {
        DkgConfig {
            dealer_threshold_type,
            receiver_committees,
        }
    }

    /// Create a new ReceiverCommitteeConfig.
    public fun new_receiver_committee_config(
        is_resharing: bool,
        threshold_type: CertificateThresholdType
    ): ReceiverCommitteeConfig {
        ReceiverCommitteeConfig {
            is_resharing,
            threshold_type,
        }
    }

    /// Returns the default DKG configuration:
    /// - Dealer threshold: quorum_certificate_type()
    /// - Receiver committees: [(false, validity), (false, quorum)]
    public fun default(): DkgConfig {
        DkgConfig {
            dealer_threshold_type: quorum_certificate_type(),
            receiver_committees: vector[
                ReceiverCommitteeConfig {
                    is_resharing: false,
                    threshold_type: validity_certificate_type(),
                },
                ReceiverCommitteeConfig {
                    is_resharing: false,
                    threshold_type: quorum_certificate_type(),
                },
            ],
        }
    }

    // ========================
    // Getters
    // ========================

    /// Get the current DKG config.
    public fun current(): DkgConfig acquires DkgConfig {
        if (exists<DkgConfig>(@supra_framework)) {
            *borrow_global<DkgConfig>(@supra_framework)
        } else {
            default()
        }
    }

    /// Get the dealer threshold type from the config.
    public fun get_dealer_threshold_type(config: &DkgConfig): CertificateThresholdType {
        config.dealer_threshold_type
    }

    /// Get the receiver committee configs from the DkgConfig.
    public fun get_receiver_committee_configs(config: &DkgConfig): vector<ReceiverCommitteeConfig> {
        config.receiver_committees
    }

    /// Get is_resharing from a ReceiverCommitteeConfig.
    public fun get_is_resharing(config: &ReceiverCommitteeConfig): bool {
        config.is_resharing
    }

    /// Get threshold_type from a ReceiverCommitteeConfig.
    public fun get_threshold_type(config: &ReceiverCommitteeConfig): CertificateThresholdType {
        config.threshold_type
    }

    // ========================
    // Tests
    // ========================

    #[test_only]
    use supra_framework::account;

    #[test_only]
    fun initialize_for_testing(framework: &signer) {
        config_buffer::initialize(framework);
        initialize(framework);
    }

    #[test(framework = @0x1)]
    fun test_default_config(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        let config = current();
        
        // Check dealer threshold type is quorum
        assert!(
            get_dealer_threshold_type(&config) == quorum_certificate_type(),
            1
        );

        // Check receiver committees
        let receivers = get_receiver_committee_configs(&config);
        assert!(vector::length(&receivers) == 2, 2);

        // First receiver: (false, validity)
        let r0 = vector::borrow(&receivers, 0);
        assert!(!get_is_resharing(r0), 3);
        assert!(get_threshold_type(r0) == validity_certificate_type(), 4);

        // Second receiver: (false, quorum)
        let r1 = vector::borrow(&receivers, 1);
        assert!(!get_is_resharing(r1), 5);
        assert!(get_threshold_type(r1) == quorum_certificate_type(), 6);
    }

    #[test(framework = @0x1)]
    fun test_set_for_next_epoch(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Create new config with resharing enabled
        let new_config = new(
            validity_certificate_type(),  // Change dealer to validity
            vector[
                new_receiver_committee_config(true, validity_certificate_type()),
                new_receiver_committee_config(true, quorum_certificate_type()),
            ]
        );

        // Stage for next epoch
        set_for_next_epoch(&framework, new_config);

        // Config should not change yet
        let config = current();
        assert!(!get_is_resharing(vector::borrow(&get_receiver_committee_configs(&config), 0)), 1);

        // Apply on new epoch
        on_new_epoch(&framework);

        // Now config should be updated
        let config = current();
        assert!(get_dealer_threshold_type(&config) == validity_certificate_type(), 2);
        let receivers = get_receiver_committee_configs(&config);
        assert!(get_is_resharing(vector::borrow(&receivers, 0)), 3);
        assert!(get_is_resharing(vector::borrow(&receivers, 1)), 4);
    }

    #[test(framework = @0x1)]
    #[expected_failure(abort_code = 65537, location = Self)] // EEMPTY_RECEIVER_COMMITTEES
    fun test_set_for_next_epoch_empty_receivers_fails(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Try to set config with empty receiver committees - should fail
        let bad_config = new(
            quorum_certificate_type(),
            vector[]  // Empty!
        );
        set_for_next_epoch(&framework, bad_config);
    }

    #[test(framework = @0x1)]
    #[expected_failure(abort_code = 65538, location = Self)] // ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE
    fun test_set_for_next_epoch_resharing_nonexistent_type_fails(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Default config has validity and quorum threshold types.
        // Try to enable resharing for unanimous_certificate_type which doesn't exist.
        let bad_config = new(
            quorum_certificate_type(),
            vector[
                new_receiver_committee_config(true, unanimous_certificate_type()),  // This type doesn't exist!
            ]
        );
        set_for_next_epoch(&framework, bad_config);
    }

    #[test(framework = @0x1)]
    fun test_set_for_next_epoch_resharing_existing_type_succeeds(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Enable resharing for types that DO exist in current config (validity and quorum)
        let good_config = new(
            quorum_certificate_type(),
            vector[
                new_receiver_committee_config(true, validity_certificate_type()),   // Exists in default
                new_receiver_committee_config(true, quorum_certificate_type()),     // Exists in default
            ]
        );
        
        // Should succeed
        set_for_next_epoch(&framework, good_config);
        on_new_epoch(&framework);
        
        let config = current();
        let receivers = get_receiver_committee_configs(&config);
        assert!(get_is_resharing(vector::borrow(&receivers, 0)), 1);
        assert!(get_is_resharing(vector::borrow(&receivers, 1)), 2);
    }

    #[test(framework = @0x1)]
    fun test_add_new_threshold_type_without_resharing_succeeds(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Adding a new threshold type without resharing should succeed
        let config_with_new_type = new(
            quorum_certificate_type(),
            vector[
                new_receiver_committee_config(false, validity_certificate_type()),
                new_receiver_committee_config(false, quorum_certificate_type()),
                new_receiver_committee_config(false, unanimous_certificate_type()),  // New type, no resharing
            ]
        );
        
        // Should succeed because resharing is false
        set_for_next_epoch(&framework, config_with_new_type);
        on_new_epoch(&framework);
        
        let config = current();
        let receivers = get_receiver_committee_configs(&config);
        assert!(vector::length(&receivers) == 3, 1);
    }
}
