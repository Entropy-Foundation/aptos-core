/// Copyright (c) 2025 Supra
///
/// Microchain Registry Module
///
/// This module manages the registration and lifecycle of microchains on Supra-L1.
///
/// 1. To enable support for a new microchain on Supra-L1, it must be first registered by Supra Governance
///    using the `register_microchain` method of this module.
/// 2. If a registered microchain misbehaves, it can be deactivated by Supra Governance through the `deactivate_microchain` method.
/// 3. A previously deactivated microchain can be reactivated by Supra Governance using the `reactivate_microchain` method.
/// 4. Although the registry data is updated immediately, the changes are only considered by Supra-L1 validators
///    after an epoch change. Therefore, it is strongly recommended to trigger an epoch change by invoking
///    `0x1::supra_governance::reconfigure`.
/// 5. Supra-L1 validators consider the updated registry data only after the epoch change. Hence, it is
///    highly recommended to perform an epoch change whenever the following methods are invoked:
///     a. `register_microchain`
///     b. `deactivate_microchain`
///     c. `reactivate_microchain`
module supra_framework::microchain_registry {
    use std::error;
    use std::string::String;
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};

    use supra_framework::event;
    use supra_framework::system_addresses;

    friend supra_framework::genesis;
    #[test_only]
    friend supra_framework::microchain_registry_tests;


    /// The microchain with the given chain ID is already registered in the microchain registry.
    const EMICROCHAIN_ALREADY_REGISTERED: u64 = 1;

    /// The microchain with the given chain ID is not found in the microchain registry.
    const EMICROCHAIN_NOT_REGISTERED: u64 = 2;

    /// The chain ID falls within a reserved range and cannot be used for registration.
    const ECHAIN_ID_RESERVED: u64 = 3;

    /// The microchain is already in the `INACTIVE` state and cannot be deactivated again.
    const EMICROCHAIN_ALREADY_DEACTIVATED: u64 = 4;

    /// The microchain is already in the `ACTIVE` state and cannot be reactivated.
    const EMICROCHAIN_ALREADY_ACTIVE: u64 = 5;

    /// The `MicrochainRegistry` resource has not been initialized at @supra_framework.
    const EREGISTRY_NOT_INITIALIZED: u64 = 6;

    /// The provided range is invalid, start value must be less than or equal to end value.
    const EINVALID_RANGE: u64 = 7;


    /// Registered as a microchain, but decommissioned from the Supra-L1.
    const STATE_INACTIVE: u8 = 0;
    /// Registered as a microchain and actively working.
    const STATE_ACTIVE: u8 = 1;
    /// Never registered as a microchain.
    const STATE_UNKNOWN: u8 = 2;

    /// Represents reserved chain ID range.
    struct ReservedRange has store, copy, drop {
        start: u8,
        end: u8
    }

    /// Represents information about the registered microchain.
    struct MicrochainInfo has store, copy, drop {
        state: u8,
        metadata_link: String,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Global microchain registry resource.
    struct MicrochainRegistry has key {
        /// Map from chain ID to microchain info.
        microchains: SimpleMap<u8, MicrochainInfo>,
        /// Reserved chain ID ranges.
        reserved_ranges: vector<ReservedRange>,
    }


    #[event]
    struct MicrochainRegistered has store, drop {
        chain_id: u8,
        metadata_link: String,
    }

    #[event]
    struct MicrochainDeactivated has store, drop {
        chain_id: u8,
    }

    #[event]
    struct MicrochainReactivated has store, drop {
        chain_id: u8,
    }

    #[event]
    struct MicrochainMetadataLinkUpdated has store, drop {
        chain_id: u8,
        old_metadata_link: String,
        new_metadata_link: String,
    }

    /// Initializes the microchain registry.
    public(friend) fun initialize(supra_framework: &signer, reserved_ranges: vector<ReservedRange>) {
        system_addresses::assert_supra_framework(supra_framework);

        move_to(supra_framework, MicrochainRegistry {
            microchains: simple_map::new(),
            reserved_ranges,
        });
    }

    /// Registers a new microchain.
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
    /// supra_framework::microchain_registry::register_microchain(&supra_framework, chain_id, metadata_link);
    /// supra_framework::supra_governance::reconfigure(&supra_framework);
    /// ```
    public fun register_microchain(
        supra_framework: &signer,
        chain_id: u8,
        metadata_link: String,
    ) acquires MicrochainRegistry {
        let microchain_registry = borrow_global_mut_microchain_registry(supra_framework);

        // Checks if given chain ID is reserved.
        assert!(
            !is_chain_id_reserved_internal(chain_id, &microchain_registry.reserved_ranges),
            error::invalid_argument(ECHAIN_ID_RESERVED)
        );
        // Checks if a microchain is already registered.
        assert!(
            !simple_map::contains_key(&microchain_registry.microchains, &chain_id),
            error::already_exists(EMICROCHAIN_ALREADY_REGISTERED)
        );

        let microchain_info = MicrochainInfo {
            state: STATE_ACTIVE,
            metadata_link,
        };
        simple_map::add(&mut microchain_registry.microchains, chain_id, microchain_info);

        event::emit(MicrochainRegistered {
            chain_id,
            metadata_link,
        });
    }

    /// Deactivates the already registered microchain.
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
    /// supra_framework::microchain_registry::deactivate_microchain(&supra_framework, chain_id);
    /// supra_framework::supra_governance::reconfigure(&supra_framework);
    /// ```
    public fun deactivate_microchain(
        supra_framework: &signer,
        chain_id: u8,
    ) acquires MicrochainRegistry {
        let microchain_registry = borrow_global_mut_microchain_registry(supra_framework);
        assert_microchain_registered(&microchain_registry.microchains, &chain_id);

        let microchain_infp = simple_map::borrow_mut(&mut microchain_registry.microchains, &chain_id);
        assert!(microchain_infp.state == STATE_ACTIVE, error::invalid_state(EMICROCHAIN_ALREADY_DEACTIVATED));

        microchain_infp.state = STATE_INACTIVE;

        event::emit(MicrochainDeactivated {
            chain_id,
        });
    }

    /// Reactivates the deactivated microchain.
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
    /// supra_framework::microchain_registry::reactivate_microchain(&supra_framework, chain_id);
    /// supra_framework::supra_governance::reconfigure(&supra_framework);
    /// ```
    public fun reactivate_microchain(
        supra_framework: &signer,
        chain_id: u8,
    ) acquires MicrochainRegistry {
        let microchain_registry = borrow_global_mut_microchain_registry(supra_framework);
        assert_microchain_registered(&microchain_registry.microchains, &chain_id);

        let microchain_infp = simple_map::borrow_mut(&mut microchain_registry.microchains, &chain_id);
        assert!(microchain_infp.state == STATE_INACTIVE, error::invalid_state(EMICROCHAIN_ALREADY_ACTIVE));

        microchain_infp.state = STATE_ACTIVE;

        event::emit(MicrochainReactivated {
            chain_id,
        });
    }

    /// Updates metadata link of a registered microchain.
    public fun update_microchain_metadata_link(
        supra_framework: &signer,
        chain_id: u8,
        new_metadata_link: String,
    ) acquires MicrochainRegistry {
        let microchain_registry = borrow_global_mut_microchain_registry(supra_framework);
        assert_microchain_registered(&microchain_registry.microchains, &chain_id);

        let microchain_infp = simple_map::borrow_mut(&mut microchain_registry.microchains, &chain_id);
        let old_metadata_link = microchain_infp.metadata_link;
        microchain_infp.metadata_link = new_metadata_link;

        event::emit(MicrochainMetadataLinkUpdated {
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
    ) acquires MicrochainRegistry {
        let microchain_registry = borrow_global_mut_microchain_registry(supra_framework);
        assert!(start <= end, error::invalid_argument(EINVALID_RANGE));

        vector::push_back(&mut microchain_registry.reserved_ranges, ReservedRange { start, end });
    }


    /// Constructor to create an instance of the `ReservedRange`.
    /// This will be utilized in move-script to initialize the microchain registry with reserved ranges.
    public fun new_reserved_range(
        start: u8,
        end: u8,
    ): ReservedRange {
        assert!(start <= end, error::invalid_argument(EINVALID_RANGE));
        ReservedRange { start, end }
    }


    #[view]
    /// Get the state of a microchain.
    public fun microchain_state(chain_id: u8): u8 acquires MicrochainRegistry {
        let microchain_registry = borrow_global_microchain_registry();
        if (simple_map::contains_key(&microchain_registry.microchains, &chain_id)) {
            return simple_map::borrow(&microchain_registry.microchains, &chain_id).state;
        };

        STATE_UNKNOWN
    }

    #[view]
    /// Check if a microchain is active.
    public fun is_microchain_active(chain_id: u8): bool acquires MicrochainRegistry {
        microchain_state(chain_id) == STATE_ACTIVE
    }

    #[view]
    /// Get chain IDs of all microchain with `Active` state.
    public fun active_microchains(): vector<u8> acquires MicrochainRegistry {
        let microchain_registry = borrow_global_microchain_registry();
        let microchains_chain_id = simple_map::keys(&microchain_registry.microchains);
        let microchains_info = simple_map::values(&microchain_registry.microchains);
        let active_microchains_chain_id = vector::empty<u8>();
        vector::zip_reverse<u8, MicrochainInfo>(microchains_chain_id, microchains_info, |chain_id, microchain_info|{
            // New helper variable with explicit type annotation is required due to Move's lambda type inference
            // limitations. When I don't use this new variable with explicit type declaration, compiler throws error
            // and ask to infer the type.
            let info: MicrochainInfo = microchain_info;
            if (info.state == STATE_ACTIVE) {
                vector::push_back(&mut active_microchains_chain_id, chain_id);
            }
        });
        active_microchains_chain_id
    }

    #[view]
    /// Get microchain metadata link.
    public fun microchain_metadata_link(chain_id: u8): String acquires MicrochainRegistry {
        let microchain_registry = borrow_global_microchain_registry();
        assert_microchain_registered(&microchain_registry.microchains, &chain_id);

        simple_map::borrow(&microchain_registry.microchains, &chain_id).metadata_link
    }

    #[view]
    /// Get microchain info.
    public fun microchain_info(chain_id: u8): (u8, String) acquires MicrochainRegistry {
        let microchain_registry = borrow_global_microchain_registry();
        assert_microchain_registered(&microchain_registry.microchains, &chain_id);

        let microchain = simple_map::borrow(&microchain_registry.microchains, &chain_id);
        (microchain.state, microchain.metadata_link)
    }

    #[view]
    /// Check if a chain ID falls within reserved ranges.
    public fun is_chain_id_reserved(chain_id: u8): bool acquires MicrochainRegistry {
        is_chain_id_reserved_internal(chain_id, &borrow_global_microchain_registry().reserved_ranges)
    }


    inline fun borrow_global_microchain_registry(): &MicrochainRegistry acquires MicrochainRegistry {
        assert!(exists<MicrochainRegistry>(@supra_framework), error::not_found(EREGISTRY_NOT_INITIALIZED));
        borrow_global<MicrochainRegistry>(@supra_framework)
    }

    inline fun borrow_global_mut_microchain_registry(
        supra_framework: &signer
    ): &mut MicrochainRegistry acquires MicrochainRegistry {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(exists<MicrochainRegistry>(@supra_framework), error::not_found(EREGISTRY_NOT_INITIALIZED));
        borrow_global_mut<MicrochainRegistry>(@supra_framework)
    }

    inline fun assert_microchain_registered(microchains: &SimpleMap<u8, MicrochainInfo>, chain_id: &u8) {
        assert!(
            simple_map::contains_key(microchains, chain_id),
            error::not_found(EMICROCHAIN_NOT_REGISTERED)
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
