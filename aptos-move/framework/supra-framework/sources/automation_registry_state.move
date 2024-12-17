/// Supra Automation Registry State
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry_state {

    use std::signer;
    use std::vector;
    use supra_framework::event;

    use supra_std::enumerable_map::{Self, EnumerableMap};

    use supra_framework::system_addresses;
    use supra_framework::timestamp;

    friend supra_framework::genesis;
    friend supra_framework::automation_registry;
    friend supra_framework::block;

    /// Registry Id not found
    const EREGITRY_NOT_FOUND: u64 = 1;
    /// Gas amount does not go beyond upper cap limit
    const EGAS_AMOUNT_UPPER: u64 = 2;
    /// Automation task not found
    const EAUTOMATION_TASK_NOT_EXIST: u64 = 3;
    /// Unauthorized access: the caller is not the owner of the task
    const EUNAUTHORIZED_TASK_OWNER: u64 = 4;

    /// It tracks entries both pending and completed, organized by unique indices.
    struct AutomationRegistryState has key, store {
        /// A collection of automation task entries that are active state.
        tasks: EnumerableMap<u64, AutomationTaskMetaData>,
        current_index: u64,
        gas_committed_for_next_epoch: u64,
        automation_gas_limit: u64,
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

    #[event]
    /// Update automation gas limit event
    struct UpdateAutomationGasLimit has drop, store {
        automation_gas_limit: u64
    }

    #[event]
    /// Remove automation task registry event
    struct RemoveAutomationTask has drop, store {
        id: u64
    }

    public fun task_expiry_time(task: &AutomationTaskMetaData): u64 {
        task.expiry_time
    }

    // todo : this function should call during initialzation, but since we already done genesis in that case who can access the function
    public(friend) fun initialize(supra_framework: &signer, automation_gas_limit: u64) {
        system_addresses::assert_supra_framework(supra_framework);

        move_to(supra_framework, AutomationRegistryState {
            tasks: enumerable_map::new_map(),
            current_index: 0,
            gas_committed_for_next_epoch: 0,
            automation_gas_limit
        })
    }
    public(friend) fun on_new_epoch(epoch_interval: u64) acquires AutomationRegistryState {
        let state = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        let ids = enumerable_map::get_map_list(&state.tasks);

        let current_time = timestamp::now_seconds();
        let expired_task_gas = 0;

        // Perform clean up and updation of state
        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value_mut(&mut state.tasks, id);

            // Tasks that are active during this new epoch but will be already expired for the next epoch
            if (task.expiry_time <= (current_time + epoch_interval)) {
                expired_task_gas = expired_task_gas + task.max_gas_amount;
            };

            if (task.expiry_time <= current_time) {
                enumerable_map::remove_value(&mut state.tasks, id);
            } else {
                task.is_active = true;
            }
        });

        // Adjust the gas committed for the next epoch by subtracting the gas amount of the expired task
        state.gas_committed_for_next_epoch = state.gas_committed_for_next_epoch - expired_task_gas;
    }


    /// Registers a new automation task entry.
    public(friend) fun register(
        owner: &signer,
        payload_tx: vector<u8>,
        expiry_time: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
        registration_epoch: u64,
        tx_hash: vector<u8>,
    ) acquires AutomationRegistryState {
        let registry_data = borrow_global_mut<AutomationRegistryState>(@supra_framework);

        let committed_gas = registry_data.gas_committed_for_next_epoch + max_gas_amount;
        assert!(committed_gas < registry_data.automation_gas_limit, EGAS_AMOUNT_UPPER);
        registry_data.gas_committed_for_next_epoch = committed_gas;
        let task_index = registry_data.current_index;

        let automation_task_metadata = AutomationTaskMetaData {
            id: task_index,
            owner: signer::address_of(owner),
            payload_tx,
            expiry_time,
            max_gas_amount,
            gas_price_cap,
            is_active: false,
            registration_epoch,
            registration_time: timestamp::now_seconds(),
            tx_hash,
        };

        enumerable_map::add_value(&mut registry_data.tasks, task_index, automation_task_metadata);
        registry_data.current_index = registry_data.current_index + 1;
        event::emit(automation_task_metadata);
    }

    /// Remove Automatioon task entry.
    public (friend) fun remove_task(owner: &signer, id: u64): AutomationTaskMetaData acquires AutomationRegistryState {
        let automation_registry = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        assert!(enumerable_map::contains(&automation_registry.tasks, id), EAUTOMATION_TASK_NOT_EXIST);

        let automation_task_metadata = enumerable_map::get_value(&automation_registry.tasks, id);
        assert!(automation_task_metadata.owner == signer::address_of(owner), EUNAUTHORIZED_TASK_OWNER);

        enumerable_map::remove_value(&mut automation_registry.tasks, id);

        // Adjust the gas committed for the next epoch by subtracting the gas amount of the expired task
        automation_registry.gas_committed_for_next_epoch = automation_registry.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

        event::emit(RemoveAutomationTask { id: automation_task_metadata.id });
        // todo : return refund amount to user
        automation_task_metadata
    }

    /// Update Automation gas limit
    public (friend) fun update_automation_gas_limit(
        supra_framework: &signer,
        automation_gas_limit: u64
    ) acquires AutomationRegistryState {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        automation_registry.automation_gas_limit = automation_gas_limit;

        event::emit(UpdateAutomationGasLimit { automation_gas_limit });
    }

    /// List all the automation task ids
    public(friend) fun get_active_task_ids(): vector<u64> acquires AutomationRegistryState {
        let automation_registry = borrow_global<AutomationRegistryState>(@supra_framework);

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

    /// Retrieves the details of a automation task entry by its ID.
    /// Returns a tuple where the first element indicates if the registry is completed/failed (`true`) or pending (`false`),
    /// and the second element contains the `AutomationTaskMetaData` details.
    public (friend) fun get_task_details(id: u64): AutomationTaskMetaData acquires AutomationRegistryState {
        let automation_task_metadata = borrow_global<AutomationRegistryState>(@supra_framework);
        assert!(enumerable_map::contains(&automation_task_metadata.tasks, id), EREGITRY_NOT_FOUND);
        enumerable_map::get_value(&automation_task_metadata.tasks, id)
    }

    /// Checks whether there is an active task in registry with specified input task id.
    public fun has_active_task_with_id(id: u64): bool acquires AutomationRegistryState {
        let automation_task_metadata = borrow_global<AutomationRegistryState>(@supra_framework);
        if (enumerable_map::contains(&automation_task_metadata.tasks, id)) {
            // TODO: uncomment when activation of the tasks on new epoch is enabled.
            let value = enumerable_map::get_value(&automation_task_metadata.tasks, id);
            value.is_active
        } else  {
            false
        }
    }

    /// Returns next task index in registry
    public (friend) fun get_next_task_index(): u64 acquires AutomationRegistryState {
        let state = borrow_global<AutomationRegistryState>(@supra_framework);
        state.current_index
    }

}
