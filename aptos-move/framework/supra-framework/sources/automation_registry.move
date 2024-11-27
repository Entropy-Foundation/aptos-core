/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry {

    use std::signer;

    use supra_framework::account;
    use supra_framework::account::SignerCapability;
    use supra_framework::enumerable_map::{Self, EnumerableMap};
    use supra_framework::event;
    use supra_framework::reconfiguration;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;
    use supra_framework::transaction_context;

    /// Registry Id not found
    const EREGITRY_NOT_FOUND: u64 = 1;
    /// Expiry time does not go beyond upper cap duration
    const EEXPIRY_TIME_UPPER: u64 = 2;

    /// Default automation gas limit
    const DEFAULT_AUTOMATION_GAS_LIMIT: u64 = 1000000;
    /// Default upper gas duration in seconds
    const DEFAULT_DURATION_UPPER_LIMIT: u64 = 2592000;
    /// Registry resource creation seed
    const REGISTRY_RESOURCE_SEED: vector<u8> = b"supra_framework::automation_registry";

    /// It tracks entries both pending and completed, organized by unique indices.
    struct AutomationRegistry has key, store {
        /// The current unique index counter for registered tasks. This value increments as new tasks are added.
        current_index: u64,
        /// Automation task gas limit
        automation_gas_limit: u64,
        /// Automation task duration upper limit.
        duration_upper_limit: u64,
        /// It's resource address which is use to deposit user automation fee
        registry_fee_address: address,
        /// Resource account signature capability
        registry_fee_address_signer_cap: SignerCapability,
        /// A collection of automation task entries that are active state.
        tasks: EnumerableMap<u64, AutomationTaskMetaData>,
    }

    #[event]
    /// `AutomationTaskMetaData` represents a single automation task item, containing metadata.
    struct AutomationTaskMetaData has copy, store, drop {
        /// Automation task index in registry
        id: u64,
        /// The address of the task owner.
        owner: address,
        /// The function signature associated with the registry entry.
        payload_tx: vector<u8>,
        /// Expiry of the task, represented in a timestamp in second.
        expiry_time: u64,
        /// The transaction hash of the request transaction.
        tx_hash: vector<u8>,
        /// Max gas amount of automation task
        max_gas_amount: u64,
        /// Maximum gas price cap for the task
        gas_price_cap: u64,
        /// Registration epoch number
        registration_epoch: u64,
        /// Registration epoch time
        registration_time: u64,
        /// Flag indicating whether the task is active.
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
            tasks: enumerable_map::new_map(),
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
        max_gas_amount: u64,
        gas_price_cap: u64
    ) acquires AutomationRegistry {
        let registry_data = borrow_global_mut<AutomationRegistry>(@supra_framework);

        // todo : well formedness check of payload_tx
        // todo : pre-paid amount collect from the user
        // todo : duration/expiry in seconds
        // Expiry time does not go beyond upper cap duration set by admin/governance
        assert!(expiry_time < registry_data.duration_upper_limit, EEXPIRY_TIME_UPPER);
        // todo : expiry should not be before the start of next epoch
        // todo : automation_gas_limit check
        // todo : gas_price_cap should not below chain minimum

        registry_data.current_index = registry_data.current_index + 1;

        let automation_task_metadata = AutomationTaskMetaData {
            id: registry_data.current_index,
            owner: signer::address_of(owner),
            payload_tx,
            expiry_time,
            max_gas_amount,
            gas_price_cap,
            is_active: false,
            registration_epoch: reconfiguration::current_epoch(),
            registration_time: timestamp::now_seconds(),
            tx_hash: transaction_context::get_transaction_hash() // todo : need to double check is that work or not
        };

        enumerable_map::add_value(&mut registry_data.tasks, registry_data.current_index, automation_task_metadata);

        event::emit(automation_task_metadata);
    }

    #[view]
    /// List all the automation task ids
    public fun get_active_task_ids(): vector<u64> acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        enumerable_map::get_map_list(&automation_registry.tasks)
    }

    #[view]
    /// Retrieves the details of a automation task entry by its ID.
    /// Returns a tuple where the first element indicates if the registry is completed/failed (`true`) or pending (`false`),
    /// and the second element contains the `AutomationTaskMetaData` details.
    public fun get_task_details(id: u64): AutomationTaskMetaData acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        assert!(enumerable_map::contains(&automation_task_metadata.tasks, id), EREGITRY_NOT_FOUND);
        enumerable_map::get_value(&automation_task_metadata.tasks, id)
    }
}
