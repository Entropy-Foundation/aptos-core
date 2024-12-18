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
    #[test_only]
    use supra_framework::account;

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
    /// Upon new epoch entry failed to propertly calculated committed gas for the next epoch.
    /// It is greater than current epoch committed gas.
    const EINVALID_COMMITTED_GAS_CALCULATION: u64 = 5;

    /// Conversion factor between microseconds and second
    const MICROSECS_CONVERSION_FACTOR: u64 = 1_000_000;
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
    public(friend) fun on_new_epoch(epoch_interval_micro: u64) acquires AutomationRegistryState {
        let state = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        let ids = enumerable_map::get_map_list(&state.tasks);

        let epoch_interval_secs = epoch_interval_micro / MICROSECS_CONVERSION_FACTOR;
        let current_time = timestamp::now_seconds();
        let expired_task_gas = 0;

        // Perform clean up and updation of state
        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value_mut(&mut state.tasks, id);

            // Tasks that are active during this new epoch but will be already expired for the next epoch
            if (task.expiry_time <= (current_time + epoch_interval_secs)) {
                expired_task_gas = expired_task_gas + task.max_gas_amount;
            };

            if (task.expiry_time <= current_time) {
                enumerable_map::remove_value(&mut state.tasks, id);
            } else {
                task.is_active = true;
            }
        });
        assert!(expired_task_gas <= state.gas_committed_for_next_epoch, EINVALID_COMMITTED_GAS_CALCULATION);

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
        let state = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        assert!(enumerable_map::contains(&state.tasks, id), EAUTOMATION_TASK_NOT_EXIST);

        let automation_task_metadata = enumerable_map::get_value(&state.tasks, id);
        assert!(automation_task_metadata.owner == signer::address_of(owner), EUNAUTHORIZED_TASK_OWNER);

        enumerable_map::remove_value(&mut state.tasks, id);

        // Adjust the gas committed for the next epoch by subtracting the gas amount of the expired task
        state.gas_committed_for_next_epoch = state.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

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

        let state = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        state.automation_gas_limit = automation_gas_limit;

        event::emit(UpdateAutomationGasLimit { automation_gas_limit });
    }

    /// List all the automation task ids
    public(friend) fun get_active_task_ids(): vector<u64> acquires AutomationRegistryState {
        let state = borrow_global<AutomationRegistryState>(@supra_framework);

        let active_task_ids = vector[];
        let ids = enumerable_map::get_map_list(&state.tasks);

        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value(&state.tasks, id);
            if (task.is_active) {
                vector::push_back(&mut active_task_ids, id);
            };
        });
        return active_task_ids
    }

    /// Retrieves the details of a automation task entry by its ID.
    /// Error will be returned if entry with specified ID does not exist.
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

    /// Ge gas committed for next epoch
    public(friend) fun get_gas_committed_for_next_epoch(): u64 acquires AutomationRegistryState {
        let state = borrow_global<AutomationRegistryState>(@supra_framework);
        state.gas_committed_for_next_epoch
    }

    #[test_only]
    fun initialize_registry_state_test(framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        initialize(framework, 100);
    }

    #[test(framework = @supra_framework)]
    fun check_task_registration(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            vector[0, 1, 2, 3, 4],
        100,
        10,
        20,
        1,
        vector[0, 1, 2 ,3],
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(10 == get_gas_committed_for_next_epoch(), 1)
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = 2)]
    fun check_registration_with_overflow_gas_limit(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            vector[0, 1, 2, 3, 4],
            100,
            70,
            20,
            1,
            vector[0, 1, 2 ,3],
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(70 == get_gas_committed_for_next_epoch(), 1);
        register(&account,
            vector[0, 1, 2, 3, 4],
            100,
            70,
            20,
            1,
            vector[0, 1, 2 ,3],
        );
    }

    #[test(framework = @supra_framework)]
    fun check_task_activation_on_new_epoch(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);
        let payload_tx = vector<u8>[0, 1, 2, 3, 4];
        let txn_hash = vector<u8>[1, 2, 3, 4, 5];

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            payload_tx,
            100,
            10,
            20,
            1,
            txn_hash,
        );
        // When moving to next epoch this task will be considered as expired
        register(&account,
            payload_tx,
            25,
            10,
            20,
            1,
            txn_hash,
        );
        register(&account,
            payload_tx,
            150,
            10,
            20,
            1,
            txn_hash,
        );
        // When moving to next epoch this task will be considered as expired for the updcoming new epoch
        register(&account,
            payload_tx,
            75,
            10,
            20,
            1,
            txn_hash,
        );
        // No active task and committed gas for the next epoch is total of the all registered tasks
        assert!(40 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        assert!(active_task_ids == vector[], 1);

        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch(30 * MICROSECS_CONVERSION_FACTOR);
        // Committed gas for the next epoch only for 2 tasks 0 and 2, the task 3 will not be active during upcoming epoch
        assert!(20 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        // But here task 3 is in the active list as it is still active in this new epoch.
        let expected_ids = vector<u64>[0, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        })
    }
}
