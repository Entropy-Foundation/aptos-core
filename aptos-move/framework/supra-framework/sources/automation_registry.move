/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry {

    use std::signer;
    use std::vector;

    use supra_std::enumerable_map::{Self, EnumerableMap};

    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::block;
    use supra_framework::event;
    use supra_framework::reconfiguration;
    use supra_framework::supra_account;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;
    use supra_framework::transaction_context;

    /// Registry Id not found
    const EREGITRY_NOT_FOUND: u64 = 1;
    /// Invalid expiry time: it cannot be earlier than the current time
    const EINVALID_EXPIRY_TIME: u64 = 2;
    /// Expiry time does not go beyond upper cap duration
    const EEXPIRY_TIME_UPPER: u64 = 3;
    /// Expiry time must be after the start of the next epoch
    const EEXPIRY_BEFORE_NEXT_EPOCH: u64 = 4;
    /// Gas amount does not go beyond upper cap limit
    const EGAS_AMOUNT_UPPER: u64 = 5;
    /// Invalid gas price: it cannot be zero
    const EINVALID_GAS_PRICE: u64 = 6;

    /// The default automation task gas limit
    const DEFAULT_AUTOMATION_GAS_LIMIT: u64 = 100000000;
    /// The default upper limit duration for automation task, specified in seconds (30 days).
    const DEFAULT_DURATION_UPPER_LIMIT: u64 = 2592000;
    /// Conversion factor between microseconds and millisecond || millisecond and second
    const MILLISECOND_CONVERSION_FACTOR: u64 = 1000;
    /// Registry resource creation seed
    const REGISTRY_RESOURCE_SEED: vector<u8> = b"supra_framework::automation_registry";

    /// It tracks entries both pending and completed, organized by unique indices.
    struct AutomationRegistry has key, store {
        /// The current unique index counter for registered tasks. This value increments as new tasks are added.
        current_index: u64,
        /// Automation task gas limit.
        automation_gas_limit: u64,
        /// Automation task duration upper limit.
        duration_upper_limit: u64,
        /// Gas committed for next epoch
        gas_committed_for_next_epoch: u64,
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
            gas_committed_for_next_epoch: 0,
            registry_fee_address: signer::address_of(&registry_fee_resource_signer),
            registry_fee_address_signer_cap,
            tasks: enumerable_map::new_map(),
        })
    }

    // todo withdraw amount from resource account to specified address
    fun withdraw() {}

    public(friend) fun on_new_epoch() acquires AutomationRegistry {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);

        let current_time = timestamp::now_seconds();

        // Perform clean up and updation of state
        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value_mut(&mut automation_registry.tasks, id);
            if (task.expiry_time < current_time) {
                enumerable_map::remove_value(&mut automation_registry.tasks, id);
            } else if (!task.is_active && task.expiry_time > current_time) {
                task.is_active = true;
            }
        });

        // todo : sumup gas_committed_for_next_epoch whatever is add or remove
    }

    /// Update Automation gas limit
    public entry fun update_automation_gas_limit(
        supra_framework: &signer,
        automation_gas_limit: u64
    ) acquires AutomationRegistry {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        automation_registry.automation_gas_limit = automation_gas_limit;
    }

    /// Update duration upper limit
    public entry fun update_duration_upper_limit(
        supra_framework: &signer,
        duration_upper_limit: u64
    ) acquires AutomationRegistry {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        automation_registry.duration_upper_limit = duration_upper_limit;
    }

    /// Calculate and collect registry charge from user
    fun collect_from_owner(owner: &signer, _expiry_time: u64, _max_gas_amount: u64) {
        // todo : calculate and collect pre-paid amount from the user
        let static_amount = 100000000; // 1 Aptos
        let registry_fee_address = get_registry_fee_address();
        supra_account::transfer(owner, registry_fee_address, static_amount);
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

        let current_time = timestamp::now_seconds();
        assert!(expiry_time > current_time, EINVALID_EXPIRY_TIME);
        assert!((expiry_time - current_time) < registry_data.duration_upper_limit, EEXPIRY_TIME_UPPER);

        let epoch_interval = block::get_epoch_interval_secs();
        let last_epoch_time_ms = reconfiguration::last_reconfiguration_time() / MILLISECOND_CONVERSION_FACTOR;
        let last_epoch_time = last_epoch_time_ms / MILLISECOND_CONVERSION_FACTOR;
        assert!(expiry_time > (last_epoch_time + epoch_interval), EEXPIRY_BEFORE_NEXT_EPOCH);

        registry_data.gas_committed_for_next_epoch = registry_data.gas_committed_for_next_epoch + max_gas_amount;
        assert!(registry_data.gas_committed_for_next_epoch < registry_data.automation_gas_limit, EGAS_AMOUNT_UPPER);

        assert!(gas_price_cap > 0, EINVALID_GAS_PRICE);

        collect_from_owner(owner, expiry_time, max_gas_amount);

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
            tx_hash: transaction_context::txn_app_hash()
        };

        enumerable_map::add_value(&mut registry_data.tasks, registry_data.current_index, automation_task_metadata);

        event::emit(automation_task_metadata);
    }

    #[view]
    /// List all the automation task ids
    public fun get_active_task_ids(): vector<u64> acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);

        let active_task_ids = vector[];
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);

        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value(&automation_registry.tasks, id);
            if (task.is_active) {
                vector::push_back(&mut active_task_ids, id);
            };
        });
        return active_task_ids
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

    #[view]
    public fun get_registry_fee_address(): address {
        account::create_resource_address(&@supra_framework, REGISTRY_RESOURCE_SEED)
    }
}
