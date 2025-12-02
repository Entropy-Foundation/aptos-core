/// Copyright (c) 2025 Supra
///
/// Appchain Registry Module
///
/// This module manages the registration and lifecycle of appchains on Supra-L1.
///
/// 1. To enable support for a new appchain on Supra-L1, it must be first registered by Supra Governance
///    using the `register_appchain` method of this module.
/// 2. If a registered appchain misbehaves, it can be deactivated by Supra Governance through the `deactivate_appchain` method.
/// 3. A previously deactivated appchain can be reactivated by Supra Governance using the `reactivate_appchain` method.
/// 4. Although the registry data is updated immediately, the changes are only considered by Supra-L1 validators
///    after an epoch change. Therefore, it is strongly recommended to trigger an epoch change by invoking
///    `0x1::supra_governance::reconfigure`.
/// 5. Supra-L1 validators consider the updated registry data only after the epoch change. Hence, it is
///    highly recommended to perform an epoch change whenever the following methods are invoked:
///     a. `register_appchain`
///     b. `deactivate_appchain`
///     c. `reactivate_appchain`
module supra_framework::appchain_registry {
    use std::error;
    use std::string::String;
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};

    use supra_framework::event;
    use supra_framework::system_addresses;

    friend supra_framework::genesis;
    #[test_only]
    friend supra_framework::appchain_registry_tests;


    /// The appchain with the given chain ID is already registered in the appchain registry.
    const EAPPCHAIN_ALREADY_REGISTERED: u64 = 1;

    /// The appchain with the given chain ID is not found in the appchain registry.
    const EAPPCHAIN_NOT_REGISTERED: u64 = 2;

    /// The chain ID falls within a reserved range and cannot be used for registration.
    const ECHAIN_ID_RESERVED: u64 = 3;

    /// The appchain is already in the `INACTIVE` state and cannot be deactivated again.
    const EAPPCHAIN_ALREADY_DEACTIVATED: u64 = 4;

    /// The appchain is already in the `ACTIVE` state and cannot be reactivated.
    const EAPPCHAIN_ALREADY_ACTIVE: u64 = 5;

    /// The `AppchainRegistry` resource has not been initialized at @supra_framework.
    const EREGISTRY_NOT_INITIALIZED: u64 = 6;

    /// The provided range is invalid, start value must be less than or equal to end value.
    const EINVALID_RANGE: u64 = 7;


    /// Registered as a appchain, but decommissioned from the Supra-L1.
    const STATE_INACTIVE: u8 = 0;
    /// Registered as a appchain and actively working.
    const STATE_ACTIVE: u8 = 1;
    /// Never registered as a appchain.
    const STATE_UNKNOWN: u8 = 2;

    /// Represents reserved chain ID range.
    struct ReservedRange has store, copy, drop {
        start: u8,
        end: u8
    }

    /// Represents information about the registered appchain.
    struct AppchainInfo has store, copy, drop {
        state: u8,
        metadata_link: String,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Global appchain registry resource.
    struct AppchainRegistry has key {
        /// Map from chain ID to appchain info.
        appchains: SimpleMap<u8, AppchainInfo>,
        /// Reserved chain ID ranges.
        reserved_ranges: vector<ReservedRange>,
    }


    #[event]
    struct AppchainRegistered has store, drop {
        chain_id: u8,
        metadata_link: String,
    }

    #[event]
    struct AppchainDeactivated has store, drop {
        chain_id: u8,
    }

    #[event]
    struct AppchainReactivated has store, drop {
        chain_id: u8,
    }

    #[event]
    struct AppchainMetadataLinkUpdated has store, drop {
        chain_id: u8,
        old_metadata_link: String,
        new_metadata_link: String,
    }

    /// Initializes the appchain registry.
    public(friend) fun initialize(supra_framework: &signer, reserved_ranges: vector<ReservedRange>) {
        system_addresses::assert_supra_framework(supra_framework);

        move_to(supra_framework, AppchainRegistry {
            appchains: simple_map::new(),
            reserved_ranges,
        });
    }

    /// Registers a new appchain.
    ///
    /// This method requires the `supra_framework` as a signer. Therefore, externally (out of the supra-framework package),
    /// it can only be invoked through a governance proposal move-script.
    ///
    /// It is strongly recommended to trigger an epoch change by calling `0x1::supra_governance::reconfigure`
    /// after invoking this method. While this method could perform the reconfiguration internally, it
    /// intentionally does not. This is because governance proposal move-scripts may need to invoke
    /// additional methods after this one, so the responsibility of reconfiguration is left to the caller.
    ///
    /// Example usage:
    /// ```
    /// supra_framework::appchain_registry::register_appchain(&supra_framework, chain_id, metadata_link);
    /// supra_framework::supra_governance::reconfigure(&supra_framework);
    /// ```
    public fun register_appchain(
        supra_framework: &signer,
        chain_id: u8,
        metadata_link: String,
    ) acquires AppchainRegistry {
        let appchain_registry = borrow_global_mut_appchain_registry(supra_framework);

        // Checks if given chain ID is reserved.
        assert!(
            !is_chain_id_reserved_internal(chain_id, &appchain_registry.reserved_ranges),
            error::invalid_argument(ECHAIN_ID_RESERVED)
        );
        // Checks if a appchain is already registered.
        assert!(
            !simple_map::contains_key(&appchain_registry.appchains, &chain_id),
            error::already_exists(EAPPCHAIN_ALREADY_REGISTERED)
        );

        let appchain_info = AppchainInfo {
            state: STATE_ACTIVE,
            metadata_link,
        };
        simple_map::add(&mut appchain_registry.appchains, chain_id, appchain_info);

        event::emit(AppchainRegistered {
            chain_id,
            metadata_link,
        });
    }

    /// Deactivates the already registered appchain.
    ///
    /// This method requires the `supra_framework` as a signer. Therefore, externally (out of the supra-framework package),
    /// it can only be invoked through a governance proposal move-script.
    ///
    /// It is strongly recommended to trigger an epoch change by calling `0x1::supra_governance::reconfigure`
    /// after invoking this method. While this method could perform the reconfiguration internally, it
    /// intentionally does not. This is because governance proposal move-scripts may need to invoke
    /// additional methods after this one, so the responsibility of reconfiguration is left to the caller.
    ///
    /// Example usage:
    /// ```
    /// supra_framework::appchain_registry::deactivate_appchain(&supra_framework, chain_id);
    /// supra_framework::supra_governance::reconfigure(&supra_framework);
    /// ```
    public fun deactivate_appchain(
        supra_framework: &signer,
        chain_id: u8,
    ) acquires AppchainRegistry {
        let appchain_registry = borrow_global_mut_appchain_registry(supra_framework);
        assert_appchain_registered(&appchain_registry.appchains, &chain_id);

        let appchain_info = simple_map::borrow_mut(&mut appchain_registry.appchains, &chain_id);
        assert!(appchain_info.state == STATE_ACTIVE, error::invalid_state(EAPPCHAIN_ALREADY_DEACTIVATED));

        appchain_info.state = STATE_INACTIVE;

        event::emit(AppchainDeactivated {
            chain_id,
        });
    }

    /// Reactivates the deactivated appchain.
    ///
    /// This method requires the `supra_framework` as a signer. Therefore, externally (out of the supra-framework package),
    /// it can only be invoked through a governance proposal move-script.
    ///
    /// It is strongly recommended to trigger an epoch change by calling `0x1::supra_governance::reconfigure`
    /// after invoking this method. While this method could perform the reconfiguration internally, it
    /// intentionally does not. This is because governance proposal move-scripts may need to invoke
    /// additional methods after this one, so the responsibility of reconfiguration is left to the caller.
    ///
    /// Example usage:
    /// ```
    /// supra_framework::appchain_registry::reactivate_appchain(&supra_framework, chain_id);
    /// supra_framework::supra_governance::reconfigure(&supra_framework);
    /// ```
    public fun reactivate_appchain(
        supra_framework: &signer,
        chain_id: u8,
    ) acquires AppchainRegistry {
        let appchain_registry = borrow_global_mut_appchain_registry(supra_framework);
        assert_appchain_registered(&appchain_registry.appchains, &chain_id);

        let appchain_info = simple_map::borrow_mut(&mut appchain_registry.appchains, &chain_id);
        assert!(appchain_info.state == STATE_INACTIVE, error::invalid_state(EAPPCHAIN_ALREADY_ACTIVE));

        appchain_info.state = STATE_ACTIVE;

        event::emit(AppchainReactivated {
            chain_id,
        });
    }

    /// Updates metadata link of a registered appchain.
    public fun update_appchain_metadata_link(
        supra_framework: &signer,
        chain_id: u8,
        new_metadata_link: String,
    ) acquires AppchainRegistry {
        let appchain_registry = borrow_global_mut_appchain_registry(supra_framework);
        assert_appchain_registered(&appchain_registry.appchains, &chain_id);

        let appchain_info = simple_map::borrow_mut(&mut appchain_registry.appchains, &chain_id);
        let old_metadata_link = appchain_info.metadata_link;
        appchain_info.metadata_link = new_metadata_link;

        event::emit(AppchainMetadataLinkUpdated {
            chain_id,
            old_metadata_link,
            new_metadata_link,
        });
    }

    /// Adds a reserved chain ID range.
    public fun add_reserved_range(
        supra_framework: &signer,
        start: u8,
        end: u8,
    ) acquires AppchainRegistry {
        let appchain_registry = borrow_global_mut_appchain_registry(supra_framework);
        assert!(start <= end, error::invalid_argument(EINVALID_RANGE));

        vector::push_back(&mut appchain_registry.reserved_ranges, ReservedRange { start, end });
    }


    /// Constructor to create an instance of the `ReservedRange`.
    /// This will be utilized in move-script to initialize the appchain registry with reserved ranges.
    public fun new_reserved_range(
        start: u8,
        end: u8,
    ): ReservedRange {
        assert!(start <= end, error::invalid_argument(EINVALID_RANGE));
        ReservedRange { start, end }
    }


    #[view]
    /// Get the state of a appchain.
    public fun appchain_state(chain_id: u8): u8 acquires AppchainRegistry {
        let appchain_registry = borrow_global_appchain_registry();
        if (simple_map::contains_key(&appchain_registry.appchains, &chain_id)) {
            return simple_map::borrow(&appchain_registry.appchains, &chain_id).state;
        };

        STATE_UNKNOWN
    }

    #[view]
    /// Check if a appchain is active.
    public fun is_appchain_active(chain_id: u8): bool acquires AppchainRegistry {
        appchain_state(chain_id) == STATE_ACTIVE
    }

    #[view]
    /// Get chain IDs of all appchain with `Active` state.
    public fun active_appchains(): vector<u8> acquires AppchainRegistry {
        let appchain_registry = borrow_global_appchain_registry();
        let appchains_chain_id = simple_map::keys(&appchain_registry.appchains);
        let appchains_info = simple_map::values(&appchain_registry.appchains);
        let active_appchains_chain_id = vector::empty<u8>();
        vector::zip_reverse<u8, AppchainInfo>(appchains_chain_id, appchains_info, |chain_id, appchain_info|{
            // New helper variable with explicit type annotation is required due to Move's lambda type inference
            // limitations. When I don't use this new variable with explicit type declaration, compiler throws error
            // and ask to infer the type.
            let info: AppchainInfo = appchain_info;
            if (info.state == STATE_ACTIVE) {
                vector::push_back(&mut active_appchains_chain_id, chain_id);
            }
        });
        active_appchains_chain_id
    }

    #[view]
    /// Get appchain metadata link.
    public fun appchain_metadata_link(chain_id: u8): String acquires AppchainRegistry {
        let appchain_registry = borrow_global_appchain_registry();
        assert_appchain_registered(&appchain_registry.appchains, &chain_id);

        simple_map::borrow(&appchain_registry.appchains, &chain_id).metadata_link
    }

    #[view]
    /// Get appchain info.
    public fun appchain_info(chain_id: u8): (u8, String) acquires AppchainRegistry {
        let appchain_registry = borrow_global_appchain_registry();
        assert_appchain_registered(&appchain_registry.appchains, &chain_id);

        let appchain = simple_map::borrow(&appchain_registry.appchains, &chain_id);
        (appchain.state, appchain.metadata_link)
    }

    #[view]
    /// Check if a chain ID falls within reserved ranges.
    public fun is_chain_id_reserved(chain_id: u8): bool acquires AppchainRegistry {
        is_chain_id_reserved_internal(chain_id, &borrow_global_appchain_registry().reserved_ranges)
    }


    inline fun borrow_global_appchain_registry(): &AppchainRegistry acquires AppchainRegistry {
        assert!(exists<AppchainRegistry>(@supra_framework), error::not_found(EREGISTRY_NOT_INITIALIZED));
        borrow_global<AppchainRegistry>(@supra_framework)
    }

    inline fun borrow_global_mut_appchain_registry(
        supra_framework: &signer
    ): &mut AppchainRegistry acquires AppchainRegistry {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(exists<AppchainRegistry>(@supra_framework), error::not_found(EREGISTRY_NOT_INITIALIZED));
        borrow_global_mut<AppchainRegistry>(@supra_framework)
    }

    inline fun assert_appchain_registered(appchains: &SimpleMap<u8, AppchainInfo>, chain_id: &u8) {
        assert!(
            simple_map::contains_key(appchains, chain_id),
            error::not_found(EAPPCHAIN_NOT_REGISTERED)
        );
    }


    fun is_chain_id_reserved_internal(
        chain_id: u8,
        reserved_ranges: &vector<ReservedRange>
    ): bool {
        let i = 0;
        let total_ranges = vector::length(reserved_ranges);
        while (i < total_ranges) {
            let range = vector::borrow(reserved_ranges, i);
            if (chain_id >= range.start && chain_id <= range.end) {
                return true
            };
            i = i + 1;
        };

        false
    }
}
