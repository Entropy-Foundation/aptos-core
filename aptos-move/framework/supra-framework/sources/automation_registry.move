/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry {

    use std::signer;
    use aptos_std::table;
    use supra_framework::timestamp;
    use supra_framework::reconfiguration;
    use supra_framework::account;
    use supra_framework::account::SignerCapability;
    use supra_framework::event;
    use supra_framework::transaction_context;
    use supra_framework::system_addresses;

    /// Registry Id not found
    const EREGITRY_NOT_FOUND: u64 = 1;

    /// Default automation gas limit
    const DEFAULT_AUTOMATION_GAS_LIMIT: u64 = 1000000;
    /// Default upper gas duration in seconds
    const DEFAULT_DURATION_UPPER_LIMIT: u64 = 2592000;
    /// Registry resource creation seed
    const REGISTRY_RESOURCE_SEED: vector<u8> = b"supra_framework::automation_registry";

    /// It tracks entries both pending and completed, organized by unique indices.
    struct AutomationRegistry has key, store {
        /// The current unique index counter for registries. This value increments as new registries are added.
        current_index: u64,
        /// automation gas limit
        automation_gas_limit: u64,
        /// duration upper limit
        duration_upper_limit: u64,
        /// it's resource address which is use to deposit user automation fee
        registry_fee_address: address,
        /// resource account signature capability
        registry_fee_address_signer_cap: SignerCapability,
        /// A collection of automation task entries that are active state.
        registries: table::Table<u64, AutomationTaskMetaData>,
    }

    #[event]
    /// `AutomationTaskMetaData` represents a single automation task item, containing metadata.
    struct AutomationTaskMetaData has copy, store, drop {
        /// Automation task request id which is unique
        id: u64,
        /// The address of the registry owner.
        owner: address,
        /// The function signature associated with the registry entry.
        payload_tx: vector<u8>,
        /// Expiry of the registry entry, represented in a timestamp.
        expiry_time: u64,
        /// The transaction hash of the request transaction.
        tx_hash: vector<u8>,
        /// Max gas fee of automation task
        max_gas: u64,
        /// maximum gas price cap for the task
        gas_price_cap: u64,
        /// registration epoch number
        registration_epoch: u64,
        /// registration epoch time
        registration_time: u64,
        /// A boolean is_active indicating whether the registry entry start processing or not
        is_active: bool
    }

    // todo : this function should call during initialzation, but since we already done genesis in that case who can access the function
    fun initialize(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);

        let (registry_fee_resource_signer, registry_fee_address_signer_cap) = account::create_resource_account(
            supra_framework,
            REGISTRY_RESOURCE_SEED
        );

        move_to(supra_framework, AutomationRegistry {
            current_index: 0,
            automation_gas_limit: DEFAULT_AUTOMATION_GAS_LIMIT,
            duration_upper_limit: DEFAULT_DURATION_UPPER_LIMIT,
            registry_fee_address: signer::address_of(&registry_fee_resource_signer),
            registry_fee_address_signer_cap,
            registries: table::new(),
        })
    }

    // todo withdraw amount from resource accoun to specified address
    fun withdraw() {}


    public(friend) fun on_new_epoch() {
        // todo : should perform clean up and updation of state
    }

    /// Registers a new automation task entry.
    public entry fun register(
        owner: &signer,
        payload_tx: vector<u8>,
        expiry_time: u64,
        max_gas: u64,
        gas_price_cap: u64
    ) acquires AutomationRegistry {
        // todo : well formedness check of payload_tx
        // todo : pre-paid amount collect from the user
        // todo : duration/expiry in seconds
        // todo : expiry does not go beyond upper cap duration set by admin/governance
        // todo : expiry should not be before the start of next epoch
        // todo : automation_gas_limit check
        // todo : gas_price_cap should not below chain minimum

        let registry_data = borrow_global_mut<AutomationRegistry>(@supra_framework);
        registry_data.current_index = registry_data.current_index + 1;

        let automation_task_metadata = AutomationTaskMetaData {
            id: registry_data.current_index,
            owner: signer::address_of(owner),
            payload_tx,
            expiry_time,
            max_gas,
            gas_price_cap,
            is_active: false,
            registration_epoch: reconfiguration::current_epoch(),
            registration_time: timestamp::now_seconds(),
            tx_hash: transaction_context::get_transaction_hash() // todo : need to double check is that work or not
        };

        table::add(&mut registry_data.registries, registry_data.current_index, automation_task_metadata);

        event::emit(automation_task_metadata);
    }

    #[view]
    /// List all the active automation task
    public fun get_active_tasks(): vector<AutomationTaskMetaData> acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        // todo : It's depends upto are we using vector or table
        vector[]
    }

    #[view]
    /// Retrieves the details of a automation task entry by its ID.
    /// Returns a tuple where the first element indicates if the registry is completed/failed (`true`) or pending (`false`),
    /// and the second element contains the `AutomationTaskMetaData` details.
    public fun get_task_details(id: u64): AutomationTaskMetaData acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        assert!(table::contains(&automation_task_metadata.registries, id), EREGITRY_NOT_FOUND);
        *table::borrow(&automation_task_metadata.registries, id)
    }
}
