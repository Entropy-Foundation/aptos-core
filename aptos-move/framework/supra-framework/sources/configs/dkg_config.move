// Copyright (c) 2026 Supra.
/// DKG configuration module for configurable DKG parameters.
/// This config can be updated via governance and takes effect at the next epoch.
module supra_framework::dkg_config {
    use std::error;
    use std::option;
    use std::vector;
    use supra_framework::config_buffer;
    use supra_framework::features;
    use supra_framework::supra_dkg;
    use supra_framework::system_addresses;
    use supra_framework::validator_public_keys::{
        CertificateThresholdType,
        bcft_quorum_certificate_type,
        bcft_validity_certificate_type,
        clan_majority_certificate_type,
        quorum_certificate_type,
        validity_certificate_type
    };
    #[test_only]
    use supra_framework::validator_public_keys::unanimous_certificate_type;

    friend supra_framework::genesis;
    friend supra_framework::reconfiguration_with_dkg;

    /// Error: Receiver committees vector cannot be empty.
    const EEMPTY_RECEIVER_COMMITTEES: u64 = 1;
    /// Error: Cannot enable resharing for a threshold type that doesn't exist in current config.
    const ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE: u64 = 2;
    /// Error: Cannot enable resharing when no DKG session has ever completed.
    /// Resharing pulls prior secret material from validators' disks, which only
    /// exists once a DKG has produced shares. Without a prior session, the
    /// dealer committee for the next DKG cannot be constrained to validators
    /// holding prior data, so reject the config at proposal time rather than
    /// aborting deeper inside `reconfiguration_with_dkg::try_start`.
    const ERESHARING_WITHOUT_PRIOR_SESSION: u64 = 3;

    /// Configuration for a single receiver committee in DKG.
    struct ReceiverCommitteeConfig has copy, drop, store {
        /// Whether this committee uses resharing from the previous epoch's public key.
        is_resharing: bool,
        /// The threshold type for this committee (e.g., quorum, clan_majority).
        committee_threshold_type: CertificateThresholdType,
        /// The threshold type for output keys in DKG for this committee (e.g., validity, quorum).
        dkg_threshold_type: CertificateThresholdType
    }

    /// Main DKG configuration stored at @supra_framework.
    /// Controls DKG parameters that can be updated via governance.
    struct DkgConfig has copy, drop, key, store {
        /// Threshold type for the dealer committee. (e.g., quorum, clan_majority).
        dealer_committee_threshold_type: CertificateThresholdType,
        /// Configuration for each receiver committee.
        /// Default: [(false, validity), (false, quorum)]
        receiver_committees: vector<ReceiverCommitteeConfig>
    }

    // ========================
    // Initialization
    // ========================

    // TODO: Add the ability to configure DKG during genesis via the genesis config files.
    // This is not necessary for the initial release.
    //
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
    public fun set_for_next_epoch(
        framework: &signer, new_config: DkgConfig
    ) acquires DkgConfig {
        system_addresses::assert_supra_framework(framework);

        // Validate: receiver_committees cannot be empty
        assert!(
            vector::length(&new_config.receiver_committees) > 0,
            error::invalid_argument(EEMPTY_RECEIVER_COMMITTEES)
        );

        // Validate: if resharing is enabled for any receiver committee, both:
        //   (a) the dkg threshold type must already exist in the current config,
        //       so that prior shares of that type exist to be reshared. This is
        //       a per-committee check.
        //   (b) a DKG session must have completed at least once, so that
        //       validators have prior secret material on disk and the dealer
        //       committee can be constrained to those validators in
        //       `reconfiguration_with_dkg::try_start`. This is a per-proposal
        //       check, asserted once below the loop.
        let current_config = current();
        let any_resharing = false;
        let i = 0;
        let len = vector::length(&new_config.receiver_committees);
        while (i < len) {
            let new_rc = vector::borrow(&new_config.receiver_committees, i);
            if (new_rc.is_resharing) {
                any_resharing = true;
                // (a) Per-committee: threshold type must exist in current config.
                assert!(
                    has_key_threshold_type(&current_config, new_rc.dkg_threshold_type),
                    error::invalid_argument(ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE)
                );
            };
            i = i + 1;
        };
        // (b) Per-proposal: at least one prior DKG must have completed.
        //     Only relevant if any receiver actually enables resharing, so this
        //     is guarded by `any_resharing` and only reads `DKGState` in that case.
        if (any_resharing) {
            assert!(
                option::is_some(&supra_dkg::last_completed_session()),
                error::invalid_state(ERESHARING_WITHOUT_PRIOR_SESSION)
            );
        };

        config_buffer::upsert(new_config);
    }

    /// Check if a threshold type exists in the config's receiver committees.
    fun has_key_threshold_type(
        config: &DkgConfig, threshold_type: CertificateThresholdType
    ): bool {
        let i = 0;
        let len = vector::length(&config.receiver_committees);
        while (i < len) {
            let rc = vector::borrow(&config.receiver_committees, i);
            if (rc.dkg_threshold_type == threshold_type) {
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
        dealer_committee_threshold_type: CertificateThresholdType,
        receiver_committees: vector<ReceiverCommitteeConfig>
    ): DkgConfig {
        DkgConfig { dealer_committee_threshold_type, receiver_committees }
    }

    /// Create a new ReceiverCommitteeConfig.
    public fun new_receiver_committee_config(
        is_resharing: bool,
        committee_threshold_type: CertificateThresholdType,
        dkg_threshold_type: CertificateThresholdType
    ): ReceiverCommitteeConfig {
        ReceiverCommitteeConfig {
            is_resharing,
            committee_threshold_type,
            dkg_threshold_type
        }
    }

    /// Returns the default DKG configuration.
    ///
    /// Assumes that the `SUPRA_BCFT_CERTIFICATES` feature flag is enabled.
    public fun default(): DkgConfig {
        DkgConfig {
            dealer_committee_threshold_type: quorum_certificate_type(),
            receiver_committees: vector[
                ReceiverCommitteeConfig {
                    is_resharing: false,
                    committee_threshold_type: quorum_certificate_type(),
                    dkg_threshold_type: bcft_quorum_certificate_type()
                },
                ReceiverCommitteeConfig {
                    is_resharing: false,
                    committee_threshold_type: quorum_certificate_type(),
                    dkg_threshold_type: bcft_validity_certificate_type()
                },
                ReceiverCommitteeConfig {
                    is_resharing: false,
                    committee_threshold_type: quorum_certificate_type(),
                    dkg_threshold_type: clan_majority_certificate_type()
                }
            ]
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
            // This branch should not be executed:
            //     1. If the network is started from genesis then the default config should be
            //        applied during genesis.
            //     2. If the DKG feature flag is enabled in an existing network, then governance
            //        should set a config before enabling the feature flag.
            //
            // This branch exists as a fallback that ensures that the `BlockMetadata` transaction
            // does not fail in case of misconfiguration.
            default()
        }
    }

    /// Get the dealer threshold type from the config.
    public fun get_dealer_committee_threshold_type(config: &DkgConfig):
        CertificateThresholdType {
        config.dealer_committee_threshold_type
    }

    /// Get the receiver committee configs from the DkgConfig.
    public fun get_receiver_committee_configs(config: &DkgConfig):
        vector<ReceiverCommitteeConfig> {
        config.receiver_committees
    }

    /// Get is_resharing from a ReceiverCommitteeConfig.
    public fun get_is_resharing(config: &ReceiverCommitteeConfig): bool {
        config.is_resharing
    }

    /// Get committee_threshold_type from a ReceiverCommitteeConfig.
    public fun get_committee_threshold_type(
        config: &ReceiverCommitteeConfig
    ): CertificateThresholdType {
        config.committee_threshold_type
    }

    /// Get dkg_threshold_type from a ReceiverCommitteeConfig.
    public fun get_dkg_threshold_type(config: &ReceiverCommitteeConfig):
        CertificateThresholdType {
        config.dkg_threshold_type
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
    fun test_set_for_next_epoch(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);
        // Resharing requires a prior completed session per
        // ERESHARING_WITHOUT_PRIOR_SESSION; install a fake one for the test.
        supra_dkg::setup_fake_last_completed_session_for_test(
            &framework,
            quorum_certificate_type(),
            vector[quorum_certificate_type()],
        );

        // Create new config with resharing enabled
        let new_config =
            new(
                validity_certificate_type(), // Change dealer to validity
                vector[
                    new_receiver_committee_config(
                        true,
                        quorum_certificate_type(),
                        bcft_quorum_certificate_type()
                    ),
                    new_receiver_committee_config(
                        true,
                        quorum_certificate_type(),
                        clan_majority_certificate_type()
                    )
                ]
            );

        // Stage for next epoch
        set_for_next_epoch(&framework, new_config);

        // Config should not change yet
        let config = current();
        assert!(
            !get_is_resharing(
                vector::borrow(&get_receiver_committee_configs(&config), 0)
            ),
            1
        );

        // Apply on new epoch
        on_new_epoch(&framework);

        // Now config should be updated
        let config = current();
        assert!(
            get_dealer_committee_threshold_type(&config) == validity_certificate_type(),
            2
        );
        let receivers = get_receiver_committee_configs(&config);
        assert!(get_is_resharing(vector::borrow(&receivers, 0)), 3);
        assert!(get_is_resharing(vector::borrow(&receivers, 1)), 4);
    }

    #[test(framework = @0x1)]
    #[expected_failure(abort_code = 65537, location = Self)]
    // EEMPTY_RECEIVER_COMMITTEES
    fun test_set_for_next_epoch_empty_receivers_fails(framework: signer) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Try to set config with empty receiver committees - should fail
        let bad_config = new(
            quorum_certificate_type(),
            vector[] // Empty!
        );
        set_for_next_epoch(&framework, bad_config);
    }

    #[test(framework = @0x1)]
    #[expected_failure(abort_code = 65538, location = Self)]
    // ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE
    fun test_set_for_next_epoch_resharing_nonexistent_type_fails(
        framework: signer
    ) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Default config has validity and quorum threshold types.
        // Try to enable resharing for unanimous_certificate_type which doesn't exist.
        let bad_config =
            new(
                quorum_certificate_type(),
                vector[
                    new_receiver_committee_config(
                        true, quorum_certificate_type(), unanimous_certificate_type()
                    ) // This type doesn't exist!
                ]
            );
        set_for_next_epoch(&framework, bad_config);
    }

    #[test(framework = @0x1)]
    fun test_set_for_next_epoch_resharing_existing_type_succeeds(
        framework: signer
    ) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);
        // Resharing requires a prior completed session per
        // ERESHARING_WITHOUT_PRIOR_SESSION; install a fake one for the test.
        supra_dkg::setup_fake_last_completed_session_for_test(
            &framework,
            quorum_certificate_type(),
            vector[quorum_certificate_type()],
        );

        // Enable resharing for types that DO exist in current config (validity and quorum)
        let good_config =
            new(
                quorum_certificate_type(),
                vector[
                    new_receiver_committee_config(
                        true,
                        quorum_certificate_type(),
                        bcft_quorum_certificate_type()
                    ),
                    new_receiver_committee_config(
                        true,
                        quorum_certificate_type(),
                        clan_majority_certificate_type()
                    )
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
    #[expected_failure(abort_code = 196611, location = Self)]
    // ERESHARING_WITHOUT_PRIOR_SESSION (3) wrapped by error::invalid_state (0x3xxxx).
    // Encoded: (0x3 << 16) | 3 = 196611.
    fun test_set_for_next_epoch_resharing_without_prior_session_fails(
        framework: signer
    ) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);
        // Deliberately skip setup_fake_last_completed_session_for_test so that
        // supra_dkg::last_completed_session() returns None.

        // Build a resharing config that passes ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE
        // (the threshold types exist in the default config) so we exercise the
        // new ERESHARING_WITHOUT_PRIOR_SESSION check, not the older one.
        let resharing_config =
            new(
                quorum_certificate_type(),
                vector[
                    new_receiver_committee_config(
                        true,
                        quorum_certificate_type(),
                        bcft_quorum_certificate_type()
                    )
                ]
            );
        set_for_next_epoch(&framework, resharing_config);
    }

    #[test(framework = @0x1)]
    fun test_add_new_threshold_type_without_resharing_succeeds(
        framework: signer
    ) acquires DkgConfig {
        account::create_account_for_test(@0x1);
        initialize_for_testing(&framework);

        // Adding a new threshold type without resharing should succeed
        let config_with_new_type =
            new(
                quorum_certificate_type(),
                vector[
                    new_receiver_committee_config(
                        false, quorum_certificate_type(), validity_certificate_type()
                    ),
                    new_receiver_committee_config(
                        false, quorum_certificate_type(), quorum_certificate_type()
                    ),
                    new_receiver_committee_config(
                        false, quorum_certificate_type(), unanimous_certificate_type()
                    ) // New type, no resharing
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
