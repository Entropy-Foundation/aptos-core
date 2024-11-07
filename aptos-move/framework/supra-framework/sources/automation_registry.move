/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated registry entries
module supra_framework::automation_registry {

    use std::signer;
    use aptos_std::table;
    use supra_framework::event;
    use supra_framework::transaction_context;
    use supra_framework::system_addresses;

    /// Registry Id not found
    const EREGITRY_NOT_FOUND: u64 = 1;

    /// It tracks entries both pending and completed, organized by unique indices.
    struct RegistryData has key, store {
        /// The current unique index counter for registries. This value increments as new registries are added.
        current_index: u64,
        /// A collection of registry entries that are pending completion.
        pending_registries: table::Table<u64, RegistryEntry>,
        /// A collection of registry entries that have been marked as completed or expired.
        completed_registries: table::Table<u64, RegistryEntry>,
    }

    #[event]
    /// `RegistryEntry` represents a single registry item, containing metadata.
    struct RegistryEntry has copy, store, drop {
        registry_id: u64,
        /// The address of the registry owner.
        owner: address,
        /// The function signature associated with the registry entry.
        function_sig: vector<u8>,
        /// Expiry of the registry entry, represented in either epoch time or a timestamp.
        /// todo : duration either epoch or timestamp - needs to be confirm,
        expiry: u64,
        /// The transaction hash of the request transaction.
        tx_hash: vector<u8>,
        /// A boolean status indicating whether the registry entry processed or not. If it's expired -> false
        status: bool
    }

    // todo : this function should call during initialzation, but since we already done genesis in that case who can access the function
    fun initialize(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        move_to(supra_framework, RegistryData {
            current_index: 0,
            pending_registries: table::new(),
            completed_registries: table::new()
        })
    }

    /// Registers a new registry entry.
    public entry fun register(owner: &signer, function_sig: vector<u8>, expiry: u64) acquires RegistryData {
        // todo : well formedness check of function_sig

        // todo : pre-paid amount collect from the user

        let registry_data = borrow_global_mut<RegistryData>(@supra_framework);
        registry_data.current_index = registry_data.current_index + 1;

        let registry_entry = RegistryEntry {
            registry_id: registry_data.current_index,
            owner: signer::address_of(owner),
            function_sig,
            expiry,
            status: false,
            tx_hash: transaction_context::get_transaction_hash() // todo : need to double check is that work or not
        };

        table::add(&mut registry_data.pending_registries, registry_data.current_index, registry_entry);

        event::emit(registry_entry);
    }

    #[view]
    /// Retrieves the details of a registry entry by its ID.
    /// Returns a tuple where the first element indicates if the registry is completed/failed (`true`) or pending (`false`),
    /// and the second element contains the `RegistryEntry` details.
    public fun get_registry(registry_id: u64): (bool, RegistryEntry) acquires RegistryData {
        let registry = borrow_global<RegistryData>(@supra_framework);
        if (table::contains(&registry.pending_registries, registry_id)) {
            (false, *table::borrow(&registry.pending_registries, registry_id))
        } else if (table::contains(&registry.completed_registries, registry_id)) {
            (true, *table::borrow(&registry.completed_registries, registry_id))
        } else {
            abort EREGITRY_NOT_FOUND
        }
    }
}
