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

    /// Invalid expiry time: it cannot be earlier than the current time
    const EINVALID_EXPIRY_TIME: u64 = 1;
    /// Invalid gas price: it cannot be zero
    const EINVALID_GAS_PRICE: u64 = 2;
    /// Invalid max gas amount for automated task: it cannot be zero
    const EINVALID_MAX_GAS_AMOUNT: u64 = 3;
    /// Task with provided Id not found
    const EAUTOMATION_TASK_NOT_FOUND: u64 = 4;
    /// Gas amount does not go beyond upper cap limit
    const EGAS_AMOUNT_UPPER: u64 = 5;
    /// Unauthorized access: the caller is not the owner of the task
    const EUNAUTHORIZED_TASK_OWNER: u64 = 6;
    /// Upon new epoch entry failed to propertly calculated committed gas for the next epoch.
    /// It is greater than current epoch committed gas.
    const EINVALID_COMMITTED_GAS_CALCULATION: u64 = 7;
    /// Transactoin hash that registring current task is invalid. Lenght should be 32.
    const EINVALID_TXN_HASH: u64 = 8;
    /// Current committed gas amount is greater than the automation gas limit.
    const EUNACCEPTABLE_AUTOMATION_GAS_LIMIT: u64 = 9;
    /// Trying to cancel a task which is already cancelled.
    const EINVALID_CANCELLATION: u64 = 10;

    /// The lenght of the transaction hash.
    const TXN_HASH_LENGTH: u64 = 32;

    /// Conversion factor between microseconds and second
    const MICROSECS_CONVERSION_FACTOR: u64 = 1_000_000;

    /// Constants describing task state.
    const PENDING: u8 = 0;
    const ACTIVE: u8 = 1;
    const CANCELLED: u8 = 2;

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
        /// Flag indicating whether the task is active, canclled or pending.
        state: u8
    }

    #[event]
    /// Update automation gas limit event
    struct UpdateAutomationGasLimit has drop, store {
        automation_gas_limit: u64
    }

    #[event]
    /// Remove automation task registry event
    struct CanclledAutomationTask has drop, store {
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
        let gas_committed_for_next_epoch = 0;

        // Perform clean up and updation of state
        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value_mut(&mut state.tasks, id);

            // Tasks that are active during next epoch and are not cancled
            if (task.state != CANCELLED && task.expiry_time > (current_time + epoch_interval_secs) ) {
                gas_committed_for_next_epoch = gas_committed_for_next_epoch + task.max_gas_amount;
            };

            // Drop or activate task
            if (task.expiry_time <= current_time || task.state == CANCELLED) {
                enumerable_map::remove_value(&mut state.tasks, id);
            } else {
                task.state = ACTIVE;
            }
        });

        state.gas_committed_for_next_epoch = gas_committed_for_next_epoch;
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
        let registration_time = timestamp::now_seconds();

        assert!(expiry_time > registration_time, EINVALID_EXPIRY_TIME);
        assert!(gas_price_cap > 0, EINVALID_GAS_PRICE);
        assert!(max_gas_amount > 0, EINVALID_MAX_GAS_AMOUNT);
        assert!(vector::length(&tx_hash) == TXN_HASH_LENGTH, EINVALID_TXN_HASH);

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
            state: PENDING,
            registration_epoch,
            registration_time,
            tx_hash,
        };

        enumerable_map::add_value(&mut registry_data.tasks, task_index, automation_task_metadata);
        registry_data.current_index = registry_data.current_index + 1;
        event::emit(automation_task_metadata);
    }

    /// Cancel Automation task with specified id.
    /// If the task was active its state is updated to be CANCELLED. Otherwise task is removed form the list.
    /// Committed gas-limit is updated accordingly.
    /// Only existing task can be cancled and only by task onwer.
    public (friend) fun cancel_task(owner: &signer, id: u64): AutomationTaskMetaData acquires AutomationRegistryState {
        let state = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        assert!(enumerable_map::contains(&state.tasks, id), EAUTOMATION_TASK_NOT_FOUND);

        let automation_task_metadata = enumerable_map::get_value(&state.tasks, id);
        assert!(automation_task_metadata.owner == signer::address_of(owner), EUNAUTHORIZED_TASK_OWNER);
        assert!(automation_task_metadata.state != CANCELLED, EINVALID_CANCELLATION);
        if (automation_task_metadata.state == PENDING) {
            enumerable_map::remove_value(&mut state.tasks, id);
        } else if (automation_task_metadata.state == ACTIVE) {
            automation_task_metadata.state = CANCELLED;
            enumerable_map::update_value(&mut state.tasks, id, automation_task_metadata);
        };

        // Adjust the gas committed for the next epoch by subtracting the gas amount of the cancelled task
        state.gas_committed_for_next_epoch = state.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

        event::emit(CanclledAutomationTask { id: automation_task_metadata.id });
        automation_task_metadata
    }

    /// Update Automation gas limit
    public (friend) fun update_automation_gas_limit(
        supra_framework: &signer,
        automation_gas_limit: u64
    ) acquires AutomationRegistryState {
        system_addresses::assert_supra_framework(supra_framework);

        let state = borrow_global_mut<AutomationRegistryState>(@supra_framework);
        assert!(state.gas_committed_for_next_epoch < automation_gas_limit, EUNACCEPTABLE_AUTOMATION_GAS_LIMIT);

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
            if (task.state != PENDING) {
                vector::push_back(&mut active_task_ids, id);
            };
        });
        return active_task_ids
    }

    /// Retrieves the details of a automation task entry by its ID.
    /// Error will be returned if entry with specified ID does not exist.
    public (friend) fun get_task_details(id: u64): AutomationTaskMetaData acquires AutomationRegistryState {
        let automation_task_metadata = borrow_global<AutomationRegistryState>(@supra_framework);
        assert!(enumerable_map::contains(&automation_task_metadata.tasks, id), EAUTOMATION_TASK_NOT_FOUND);
        enumerable_map::get_value(&automation_task_metadata.tasks, id)
    }

    /// Checks whether there is an active task in registry with specified input task id.
    public(friend) fun has_active_task_with_id(id: u64): bool acquires AutomationRegistryState {
        let automation_task_metadata = borrow_global<AutomationRegistryState>(@supra_framework);
        if (enumerable_map::contains(&automation_task_metadata.tasks, id)) {
            let value = enumerable_map::get_value(&automation_task_metadata.tasks, id);
            value.state != PENDING
        } else  {
            false
        }
    }
    #[test_only]
    fun has_task_with_id(id: u64): bool acquires AutomationRegistryState {
        let automation_task_metadata = borrow_global<AutomationRegistryState>(@supra_framework);
        enumerable_map::contains(&automation_task_metadata.tasks, id)
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
    const PARENT_HASH: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
    #[test_only]
    const PAYLOAD: vector<u8> = x"0102030405060708090a0b0c0d0e0f0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20101112131415161718191a1b1c1d1e1f20";

    #[test_only]
    fun initialize_registry_state_test(framework: &signer) {
        timestamp::set_time_has_started_for_testing(framework);
        initialize(framework, 100);
    }

    #[test(framework = @supra_framework)]
    fun check_automation_gas_limit_success_update(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);
        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            100,
            50,
            20,
            1,
            PARENT_HASH,
        );

        // Next epoch gas committed gas is less than the new limit value.
        update_automation_gas_limit(&framework, 75);
        let state = borrow_global<AutomationRegistryState>(@supra_framework);
        assert!(state.automation_gas_limit == 75, 1);
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EUNACCEPTABLE_AUTOMATION_GAS_LIMIT, location = Self)]
    fun check_automation_gas_limit_failed_update(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);
        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            100,
            50,
            20,
            1,
            PARENT_HASH,
        );

        // Next epoch gas committed gas is greater than the new limit value.
        update_automation_gas_limit(&framework, 45);
    }

    #[test(framework = @supra_framework)]
    fun check_task_registration(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
        100,
        10,
        20,
        1,
        PARENT_HASH,
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(10 == get_gas_committed_for_next_epoch(), 1)
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EINVALID_EXPIRY_TIME, location = Self)]
    fun check_registration_invalid_expiry_time(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        timestamp::update_global_time_for_test_secs(50);
        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            25,
            70,
            20,
            1,
            PARENT_HASH,
        );
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EINVALID_GAS_PRICE, location = Self)]
    fun check_registration_invalid_gas_price_cap(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            25,
            70,
            0,
            1,
            PARENT_HASH,
        );
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EINVALID_MAX_GAS_AMOUNT, location = Self)]
    fun check_registration_invalid_max_gas_amount(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            25,
            0,
            70,
            1,
            PARENT_HASH,
        );
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EINVALID_TXN_HASH, location = Self)]
    fun check_registration_invalid_parent_hash(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            25,
            10,
            70,
            1,
            vector<u8>[0, 1, 2, 3],
        );
    }


    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EGAS_AMOUNT_UPPER, location = Self)]
    fun check_registration_with_overflow_gas_limit(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            100,
            70,
            20,
            1,
            PARENT_HASH
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(70 == get_gas_committed_for_next_epoch(), 1);
        register(&account,
            PAYLOAD,
            100,
            70,
            20,
            1,
            PARENT_HASH
        );
    }

    #[test(framework = @supra_framework)]
    fun check_task_activation_on_new_epoch(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            100,
            10,
            20,
            1,
            PARENT_HASH
        );
        // When moving to next epoch this task will be considered as expired
        register(&account,
            PAYLOAD,
            25,
            10,
            20,
            1,
            PARENT_HASH
        );
        register(&account,
            PAYLOAD,
            150,
            10,
            20,
            1,
            PARENT_HASH
        );
        // When moving to next epoch this task will be considered as expired for the updcoming new epoch
        register(&account,
            PAYLOAD,
            75,
            10,
            20,
            1,
            PARENT_HASH
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
        });
    }

    #[test(framework = @supra_framework)]
    fun check_task_successful_cancellation(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            100,
            10,
            20,
            1,
            PARENT_HASH
        );
        // When moving to next epoch this task will be considered as expired
        register(&account,
            PAYLOAD,
            25,
            10,
            20,
            1,
            PARENT_HASH
        );
        register(&account,
            PAYLOAD,
            150,
            10,
            20,
            1,
            PARENT_HASH
        );
        // When moving to next epoch this task will be considered as expired for the updcoming new epoch
        register(&account,
            PAYLOAD,
            75,
            10,
            20,
            1,
            PARENT_HASH
        );

        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch(30 * MICROSECS_CONVERSION_FACTOR);
        // Committed gas for the next epoch only for 2 tasks 0 and 2, the task 3 will not be active during upcoming epoch
        assert!(20 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        // But here task 3 is in the active list as it is still active in this new epoch.
        let expected_ids = vector<u64>[0, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        });

        // Cancle task 2. The committed gas for the next epoch will be updated,
        // but when requested active task it will be still available in the list
        cancel_task(&account, 2);
        // Task will be still available in the registry but with cancled state
        let task_2_details = get_task_details(2);
        assert!(task_2_details.state == CANCELLED, 1);

        assert!(10 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        });

        // Add and cancel the task in the same epoch. Task index will be 4
        assert!(get_next_task_index() == 4, 1);
        register(&account,
            PAYLOAD,
            75,
            10,
            20,
            1,
            PARENT_HASH
        );
        cancel_task(&account, 4);
        assert!(10 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        });
        // there is no task with index 4 and the next task index will be 5.
        assert!(!has_task_with_id(4), 1);
        assert!(get_next_task_index() == 5, 1)
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EAUTOMATION_TASK_NOT_FOUND, location = Self)]
    fun check_cancellation_of_non_existing_task(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        cancel_task(&account, 1);
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EUNAUTHORIZED_TASK_OWNER, location = Self)]
    fun check_unauthorized_cancellation_(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account1 = account::create_account_for_test(@0x123456);
        let account2 = account::create_account_for_test(@0x654321);
        register(&account1,
            PAYLOAD,
            75,
            10,
            20,
            1,
            PARENT_HASH
        );
        cancel_task(&account2, 0);
    }

    #[test(framework = @supra_framework)]
    #[expected_failure(abort_code = EINVALID_CANCELLATION, location = Self)]
    fun check_cacellation_of_cancelled_task(framework: signer) acquires AutomationRegistryState {
        initialize_registry_state_test(&framework);

        let account = account::create_account_for_test(@0x123456);
        register(&account,
            PAYLOAD,
            100,
            10,
            20,
            1,
            PARENT_HASH
        );
        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch(30 * MICROSECS_CONVERSION_FACTOR);
        // Cancel the same task 2 times
        cancel_task(&account, 0);
        cancel_task(&account, 0);
    }
}
