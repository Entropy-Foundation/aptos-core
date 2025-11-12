/// Copyright (c) 2025 Supra
///
/// Funnel Node Registry Module
///
/// This module manages a list of registered funnel nodes' IP/DNS addresses.
module supra_framework::funnel_node_registry {
    use std::error;
    use std::string::String;

    use supra_framework::event;
    use supra_framework::system_addresses;

    friend supra_framework::genesis;
    #[test_only]
    friend supra_framework::funnel_node_registry_tests;


    /// The `FunnelNodeRegistry` resource has not been initialized at @supra_framework.
    const EREGISTRY_NOT_INITIALIZED: u64 = 1;


    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Global funnel node registry resource.
    struct FunnelNodeRegistry has key {
        funnel_nodes: vector<String>,
    }

    #[event]
    struct FunnelNodesUpdated has store, drop {
        old_funnel_nodes: vector<String>,
        new_funnel_nodes: vector<String>,
    }


    /// Initializes the funnel node registry.
    public(friend) fun initialize(supra_framework: &signer, funnel_nodes: vector<String>) {
        system_addresses::assert_supra_framework(supra_framework);

        move_to(supra_framework, FunnelNodeRegistry {
            funnel_nodes,
        });
    }

    /// Updates the funnel nodes in the funnel node registry.
    ///
    /// This method replaces the existing list of funnel nodes with the provided list. Therefore, it is
    /// strongly recommended that the new list contains valid Socket-Addresses for all funnel nodes, and that the nodes
    /// are ordered based on their reputation and trust level.
    ///
    /// Technically, deduplication of `new_funnel_nodes` is necessary. However, performing it consumes a
    /// significant amount of execution gas. Since this method is expected to be invoked by microchain
    /// governance - which is assumed to perform governance operations carefully - the `new_funnel_nodes`
    /// list is **not** deduplicated internally. As a result, it is possible to pass a list containing duplicate
    /// entries without triggering an error. Therefore, deduplication should be performed as part of
    /// the validator node's sanity checks.
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
    /// supra_framework::funnel_node_registry::update_funnel_nodes(&supra_framework, new_funnel_nodes);
    /// supra_framework::supra_governance::reconfigure(&supra_framework);
    /// ```
    public fun update_funnel_nodes(
        supra_framework: &signer,
        new_funnel_nodes: vector<String>
    ) acquires FunnelNodeRegistry {
        system_addresses::assert_supra_framework(supra_framework);
        assert_registry_initialized();

        let funnel_node_registry = borrow_global_mut<FunnelNodeRegistry>(@supra_framework);
        let old_funnel_nodes = funnel_node_registry.funnel_nodes;
        funnel_node_registry.funnel_nodes = new_funnel_nodes;
        event::emit(FunnelNodesUpdated {
            old_funnel_nodes,
            new_funnel_nodes
        })
    }

    #[view]
    /// Get funnel nodes list.
    public fun funnel_nodes(): vector<String> acquires FunnelNodeRegistry {
        assert_registry_initialized();
        borrow_global_mut<FunnelNodeRegistry>(@supra_framework).funnel_nodes
    }

    inline fun assert_registry_initialized() {
        assert!(exists<FunnelNodeRegistry>(@supra_framework), error::not_found(EREGISTRY_NOT_INITIALIZED));
    }
}
