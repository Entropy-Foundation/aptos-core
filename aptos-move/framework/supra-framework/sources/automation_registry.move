/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
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
        /// A collection of automation task entries that are active state.
        pending_registries: table::Table<u64, AutomationTaskMetaData>,
    }

    #[event]
    /// `AutomationTaskMetaData` represents a single automation task item, containing metadata.
    struct AutomationTaskMetaData has copy, store, drop {
        id: u64,
        /// The address of the registry owner.
        owner: address,
        /// The function signature associated with the registry entry.
        payload_tx: vector<u8>,
        /// Expiry of the registry entry, represented in either epoch time or a timestamp.
        expiry_time: u64,
        /// The transaction hash of the request transaction.
        tx_hash: vector<u8>,
        /// A boolean is_active indicating whether the registry entry processed or not. If it's expired -> false
        is_active: bool
    }

    // todo : this function should call during initialzation, but since we already done genesis in that case who can access the function
    fun initialize(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        move_to(supra_framework, RegistryData {
            current_index: 0,
            pending_registries: table::new(),
        })
    }

    /// Registers a new automation task entry.
    public entry fun register(owner: &signer, payload_tx: vector<u8>, expiry_time: u64) acquires RegistryData {
        // todo : well formedness check of payload_tx
        // todo : pre-paid amount collect from the user
        // todo : duration/expiry in seconds
        // todo : expiry does not go beyond upper cap duration set by admin/governance
        // todo : expiry should not be before the start of next epoch

        let registry_data = borrow_global_mut<RegistryData>(@supra_framework);
        registry_data.current_index = registry_data.current_index + 1;

        let automation_task_metadata = AutomationTaskMetaData {
            id: registry_data.current_index,
            owner: signer::address_of(owner),
            payload_tx,
            expiry_time,
            is_active: false,
            tx_hash: transaction_context::get_transaction_hash() // todo : need to double check is that work or not
        };

        table::add(&mut registry_data.pending_registries, registry_data.current_index, automation_task_metadata);

        event::emit(automation_task_metadata);
    }

    #[view]
    /// Retrieves the details of a automation task entry by its ID.
    /// Returns a tuple where the first element indicates if the registry is completed/failed (`true`) or pending (`false`),
    /// and the second element contains the `AutomationTaskMetaData` details.
    public fun get_task_details(id: u64): AutomationTaskMetaData acquires RegistryData {
        let automation_task_metadata = borrow_global<RegistryData>(@supra_framework);
        assert!(table::contains(&automation_task_metadata.pending_registries, id), EREGITRY_NOT_FOUND);
        *table::borrow(&automation_task_metadata.pending_registries, id)
    }
}
