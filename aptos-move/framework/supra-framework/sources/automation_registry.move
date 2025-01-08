/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry {

    use std::signer;
    use std::vector;

    use supra_std::enumerable_map::{Self, EnumerableMap};

    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::event;
    use supra_framework::supra_account;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;

    friend supra_framework::genesis;
    friend supra_framework::block;
    friend supra_framework::reconfiguration;

    /// Invalid expiry time: it cannot be earlier than the current time
    const EINVALID_EXPIRY_TIME: u64 = 1;
    /// Expiry time does not go beyond upper cap duration
    const EEXPIRY_TIME_UPPER: u64 = 2;
    /// Expiry time must be after the start of the next epoch
    const EEXPIRY_BEFORE_NEXT_EPOCH: u64 = 3;
    /// Invalid gas price: it cannot be zero
    const EINVALID_GAS_PRICE: u64 = 4;
    /// Invalid max gas amount for automated task: it cannot be zero
    const EINVALID_MAX_GAS_AMOUNT: u64 = 5;
    /// Task with provided Id not found
    const EAUTOMATION_TASK_NOT_FOUND: u64 = 6;
    /// Gas amount does not go beyond upper cap limit
    const EGAS_AMOUNT_UPPER: u64 = 7;
    /// Unauthorized access: the caller is not the owner of the task
    const EUNAUTHORIZED_TASK_OWNER: u64 = 8;
    /// Transactoin hash that registring current task is invalid. Lenght should be 32.
    const EINVALID_TXN_HASH: u64 = 9;
    /// Current committed gas amount is greater than the automation gas limit.
    const EUNACCEPTABLE_AUTOMATION_GAS_LIMIT: u64 = 10;
    /// Task is already cancelled.
    const EALREADY_CANCELLED: u64 = 11;

    /// The default automation task gas limit
    const DEFAULT_AUTOMATION_GAS_LIMIT: u64 = 10_00_00_000;
    /// The default upper limit duration for automation task, specified in seconds (30 days).
    const DEFAULT_DURATION_UPPER_LIMIT: u64 = 2592000;
    /// The default Automation unit price for per second, in Quants
    const DEFAULT_AUTOMATION_UNIT_PRICE: u64 = 1000;
    /// The lenght of the transaction hash.
    const TXN_HASH_LENGTH: u64 = 32;
    /// Conversion factor between microseconds and second
    const MICROSECS_CONVERSION_FACTOR: u64 = 1_000_000;
    /// Registry resource creation seed
    const REGISTRY_RESOURCE_SEED: vector<u8> = b"supra_framework::automation_registry";

    /// Constants describing task state.
    const PENDING: u8 = 0;
    const ACTIVE: u8 = 1;
    const CANCELLED: u8 = 2;

    /// It tracks entries both pending and completed, organized by unique indices.
    struct AutomationRegistry has key, store {
        /// A collection of automation task entries that are active state.
        tasks: EnumerableMap<u64, AutomationTaskMetaData>,
        /// Automation task id which increase
        current_index: u64,
        /// Gas committed for next epoch
        gas_committed_for_next_epoch: u64,
        /// Automation task max gas limit
        automation_gas_limit: u64,
        /// Automation task duration upper limit.
        duration_upper_limit: u64,
        /// Automation task unit price per second
        automation_unit_price: u64,
        /// It's resource address which is use to deposit user automation fee
        registry_fee_address: address,
        /// Resource account signature capability
        registry_fee_address_signer_cap: SignerCapability,
    }

    /// Epoch state
    struct EpochState has key {
        /// Epoch expected duration at the beginning of the new epoch, Based on this and actual
        /// epoch_duration which will be (current_time - last_reconfiguration_time) automation tasks
        /// refunds will be calculated.
        /// it will be updated upon each new epoch start with epoch_interval value.
        /// Although we should be careful with refunds if block production interval is quite high.
        expected_epoch_duration: u64,
        /// Epoch interval that can be updated any moment of the time
        epoch_interval: u64,
        /// Current epoch start time which is the same as last_reconfiguration_time
        start_time: u64,
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
        /// Registration epoch time
        registration_time: u64,
        /// Flag indicating whether the task is active, canclled or pending.
        state: u8
    }

    #[event]
    /// Withdraw user's registration fee event
    struct FeeWithdrawnAdmin has drop, store {
        to: address,
        amount: u64
    }

    #[event]
    /// Withdraw user's registration fee event
    struct RefundFeeUser has drop, store {
        user: address,
        amount: u64
    }

    #[event]
    /// Update duration upper limit event
    struct UpdateDurationUpperLimit has drop, store {
        duration_upper_limit: u64
    }

    #[event]
    /// Update automation gas limit event
    struct UpdateAutomationGasLimit has drop, store {
        automation_gas_limit: u64
    }

    #[event]
    /// Cancelled automation task registry event
    struct CancelledAutomationTask has drop, store {
        id: u64
    }

    /// Initialization of Automation Registry
    public fun initialize(supra_framework: &signer, epoch_interval_microsecs: u64) {
        system_addresses::assert_supra_framework(supra_framework);

        let (registry_fee_resource_signer, registry_fee_address_signer_cap) = account::create_resource_account(
            supra_framework,
            REGISTRY_RESOURCE_SEED
        );

        move_to(supra_framework, AutomationRegistry {
            tasks: enumerable_map::new_map(),
            current_index: 0,
            gas_committed_for_next_epoch: 0,
            automation_gas_limit: DEFAULT_AUTOMATION_GAS_LIMIT,
            duration_upper_limit: DEFAULT_DURATION_UPPER_LIMIT,
            automation_unit_price: DEFAULT_AUTOMATION_UNIT_PRICE,
            registry_fee_address: signer::address_of(&registry_fee_resource_signer),
            registry_fee_address_signer_cap,
        });

        move_to(supra_framework, EpochState {
            expected_epoch_duration: 0,
            epoch_interval: epoch_interval_microsecs / MICROSECS_CONVERSION_FACTOR,
            start_time: 0,
        });
    }

    /// On new epoch this function will be triggered and update the automation registry state
    public(friend) fun on_new_epoch() acquires AutomationRegistry, EpochState {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);

        let epoch_state = borrow_global_mut<EpochState>(@supra_framework);

        let current_time = timestamp::now_seconds();
        let gas_committed_for_next_epoch = 0;

        // Perform clean up and updation of state
        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value_mut(&mut automation_registry.tasks, id);

            // Tasks that are active during next epoch and are not canceled
            // current_time shows the start time of the current new epoch.
            if (task.state != CANCELLED && task.expiry_time > (current_time + epoch_state.epoch_interval)) {
                gas_committed_for_next_epoch = gas_committed_for_next_epoch + task.max_gas_amount;
            };

            // Drop or activate task for this current epoch.
            if (task.expiry_time <= current_time || task.state == CANCELLED) {
                enumerable_map::remove_value(&mut automation_registry.tasks, id);
            } else {
                task.state = ACTIVE;
            }
        });

        automation_registry.gas_committed_for_next_epoch = gas_committed_for_next_epoch;
        epoch_state.start_time = current_time;
    }

    /// Withdraw accumulated automation task fees from the resource account - access by admin
    public fun withdraw_automation_task_fees(
        supra_framework: &signer,
        to: address,
        amount: u64
    ) acquires AutomationRegistry {
        system_addresses::assert_supra_framework(supra_framework);
        transfer_fee_to_account_internal(to, amount);
        event::emit(FeeWithdrawnAdmin { to, amount });
    }

    /// Transfers the specified fee amount from the resource account to the target account.
    fun transfer_fee_to_account_internal(to: address, amount: u64) acquires AutomationRegistry {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        supra_account::transfer(&resource_signer, to, amount);
    }

    /// Update Automation gas limit.
    /// If the committed gas amount for the next epoch is greater then the new gas limit, then error is reported.
    public entry fun update_automation_gas_limit(
        supra_framework: &signer,
        automation_gas_limit: u64
    ) acquires AutomationRegistry {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        assert!(
            automation_registry.gas_committed_for_next_epoch < automation_gas_limit,
            EUNACCEPTABLE_AUTOMATION_GAS_LIMIT
        );

        automation_registry.automation_gas_limit = automation_gas_limit;

        event::emit(UpdateAutomationGasLimit { automation_gas_limit });
    }

    /// Update duration upper limit
    public entry fun update_duration_upper_limit(
        supra_framework: &signer,
        duration_upper_limit: u64
    ) acquires AutomationRegistry {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        automation_registry.duration_upper_limit = duration_upper_limit;

        event::emit(UpdateDurationUpperLimit { duration_upper_limit });
    }

    /// Deducts the automation fee from the user's account based on the selected expiry time.
    fun charge_automation_fee_from_user(
        owner: &signer,
        automation_unit_price: u64,
        task_duration: u64,
        registry_fee_address: address
    ) {
        let automation_base_fee = task_duration * automation_unit_price;
        // todo : dynamic price calculation is pending
        supra_account::transfer(owner, registry_fee_address, automation_base_fee);
    }

    /// Registers a new automation task entry.
    public fun register(
        owner: &signer,
        payload_tx: vector<u8>,
        expiry_time: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
        tx_hash: vector<u8>
    ) acquires AutomationRegistry, EpochState {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let epoch_state = borrow_global<EpochState>(@supra_framework);
        //Well-formedness check of payload_tx is done in native layer beforehand.

        let registration_time = timestamp::now_seconds();
        assert!(expiry_time > registration_time, EINVALID_EXPIRY_TIME);
        let task_duration = expiry_time - registration_time;
        assert!(task_duration < automation_registry.duration_upper_limit, EEXPIRY_TIME_UPPER);

        // Check that task is valid at least in the next epoch
        assert!(
            expiry_time > (epoch_state.start_time + epoch_state.epoch_interval),
            EEXPIRY_BEFORE_NEXT_EPOCH
        );

        assert!(gas_price_cap > 0, EINVALID_GAS_PRICE);
        assert!(max_gas_amount > 0, EINVALID_MAX_GAS_AMOUNT);
        assert!(vector::length(&tx_hash) == TXN_HASH_LENGTH, EINVALID_TXN_HASH);

        let committed_gas = automation_registry.gas_committed_for_next_epoch + max_gas_amount;
        assert!(committed_gas < automation_registry.automation_gas_limit, EGAS_AMOUNT_UPPER);
        automation_registry.gas_committed_for_next_epoch = committed_gas;
        let task_index = automation_registry.current_index;

        let automation_task_metadata = AutomationTaskMetaData {
            id: task_index,
            owner: signer::address_of(owner),
            payload_tx,
            expiry_time,
            max_gas_amount,
            gas_price_cap,
            state: PENDING,
            registration_time,
            tx_hash,
        };

        enumerable_map::add_value(&mut automation_registry.tasks, task_index, automation_task_metadata);
        automation_registry.current_index = automation_registry.current_index + 1;
        event::emit(automation_task_metadata);

        charge_automation_fee_from_user(
            owner,
            automation_registry.automation_unit_price,
            task_duration,
            automation_registry.registry_fee_address);
    }

    /// Cancel Automation task with specified id.
    /// Only existing task, which is PENDING or ACTIVE, can be cancled and only by task onwer.
    /// If the task is
    ///   - active, its state is updated to be CANCELLED.
    ///   - pending, it is removed form the list.
    ///   - cancelled, an error is reported
    /// Committed gas-limit is updated by reducing it with the max-gas-amount of the cancelled task.
    public entry fun cancel_task(owner: &signer, id: u64) acquires AutomationRegistry {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        assert!(enumerable_map::contains(&automation_registry.tasks, id), EAUTOMATION_TASK_NOT_FOUND);

        let automation_task_metadata = enumerable_map::get_value(&automation_registry.tasks, id);
        assert!(automation_task_metadata.owner == signer::address_of(owner), EUNAUTHORIZED_TASK_OWNER);
        assert!(automation_task_metadata.state != CANCELLED, EALREADY_CANCELLED);
        if (automation_task_metadata.state == PENDING) {
            enumerable_map::remove_value(&mut automation_registry.tasks, id);
        } else if (automation_task_metadata.state == ACTIVE) {
            automation_task_metadata.state = CANCELLED;
            enumerable_map::update_value(&mut automation_registry.tasks, id, automation_task_metadata);
        };

        // Adjust the gas committed for the next epoch by subtracting the gas amount of the cancelled task
        automation_registry.gas_committed_for_next_epoch = automation_registry.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

        event::emit(CancelledAutomationTask { id: automation_task_metadata.id });
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        refund_automation_task_fee(
            signer::address_of(owner),
            automation_task_metadata,
            automation_registry.automation_unit_price
        );
    }

    /// Refunds the automation task fee to the user who has removed their task registration from the list.
    fun refund_automation_task_fee(
        user: address,
        automation_task_metadata: AutomationTaskMetaData,
        automation_unit_price: u64,
    ) acquires AutomationRegistry {
        let current_time = timestamp::now_seconds();
        let expiry_time_duration = automation_task_metadata.expiry_time - current_time;

        let refund_amount = expiry_time_duration * automation_unit_price;
        transfer_fee_to_account_internal(user, refund_amount);
        event::emit(RefundFeeUser { user, amount: refund_amount });
    }

    /// Update epoch interval in registry while actually update happens in block module
    public(friend) fun update_epoch_interval_in_registry(epoch_interval_microsecs: u64) acquires EpochState {
        if (exists<AutomationRegistry>(@supra_framework)) {
            let epoch_state = borrow_global_mut<EpochState>(@supra_framework);
            epoch_state.epoch_interval = epoch_interval_microsecs / MICROSECS_CONVERSION_FACTOR;
        };
    }

    #[view]
    /// Returns next task index in registry
    public fun get_next_task_index(): u64 acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        automation_registry.current_index
    }

    #[view]
    /// List all active automation task ids for the current epoch.
    /// Note that the tasks with CANCELLED state are still considered active for the current epoch,
    /// as cancellation takes effect in the next epoch only.
    public fun get_active_task_ids(): vector<u64> acquires AutomationRegistry {
        let state = borrow_global<AutomationRegistry>(@supra_framework);

        enumerable_map::filter_map(&state.tasks, |task| {
            let task: AutomationTaskMetaData = task; // we need to define task type here to avoid compiler error
            if (task.state != PENDING) (true, task.id)
            else (false, task.id)
        })
    }

    #[view]
    /// Retrieves the details of a automation task entry by its ID.
    /// Error will be returned if entry with specified ID does not exist.
    public fun get_task_details(id: u64): AutomationTaskMetaData acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        assert!(enumerable_map::contains(&automation_task_metadata.tasks, id), EAUTOMATION_TASK_NOT_FOUND);
        enumerable_map::get_value(&automation_task_metadata.tasks, id)
    }

    #[view]
    /// Checks whether there is an active task in registry with specified input task id.
    public fun has_sender_active_task_with_id(sender: address, id: u64): bool acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        if (enumerable_map::contains(&automation_task_metadata.tasks, id)) {
            let value = enumerable_map::get_value_ref(&automation_task_metadata.tasks, id);
            value.state != PENDING && value.owner == sender
        } else {
            false
        }
    }

    #[view]
    /// Get registry fee resource account address
    public fun get_registry_fee_address(): address {
        account::create_resource_address(&@supra_framework, REGISTRY_RESOURCE_SEED)
    }

    #[view]
    /// Get gas committed for next epoch
    public fun get_gas_committed_for_next_epoch(): u64 acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        automation_registry.gas_committed_for_next_epoch
    }

    #[test_only]
    /// Value defined in microsecond
    const EPOCH_INTERVAL_FOR_TEST: u64 = 7200000000;
    #[test_only]
    const PARENT_HASH: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
    #[test_only]
    const PAYLOAD: vector<u8> = x"0102030405060708090a0b0c0d0e0f0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20101112131415161718191a1b1c1d1e1f20";

    #[test_only]
    fun initialize_registry_test(supra_framework: &signer, user: &signer) {
        use supra_framework::coin;
        use supra_framework::supra_coin::{Self, SupraCoin};

        let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
        account::create_account_for_test(@supra_framework);

        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(supra_framework);
        coin::register<SupraCoin>(user);
        supra_coin::mint(supra_framework, user_addr, 10000000000);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        timestamp::set_time_has_started_for_testing(supra_framework);

        initialize(supra_framework, EPOCH_INTERVAL_FOR_TEST);
    }

    #[test_only]
    fun has_task_with_id(id: u64): bool acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        enumerable_map::contains(&automation_registry.tasks, id)
    }

    #[test(supra_framework = @supra_framework, user = @0x1cafe)]
    fun test_registry(supra_framework: &signer, user: &signer) acquires AutomationRegistry, EpochState {
        initialize_registry_test(supra_framework, user);

        let payload = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f4041424344";
        let parent_hash = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
        register(user, payload, 86400, 1000, 100000, parent_hash);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_automation_gas_limit_success_update(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            50,
            20,
            PARENT_HASH,
        );

        // Next epoch gas committed gas is less than the new limit value.
        update_automation_gas_limit(framework, 75);
        let state = borrow_global<AutomationRegistry>(@supra_framework);
        assert!(state.automation_gas_limit == 75, 1);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EUNACCEPTABLE_AUTOMATION_GAS_LIMIT, location = Self)]
    fun check_automation_gas_limit_failed_update(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            50,
            20,
            PARENT_HASH,
        );

        // Next epoch gas committed gas is greater than the new limit value.
        update_automation_gas_limit(framework, 45);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_registration(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH,
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(10 == get_gas_committed_for_next_epoch(), 1)
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_EXPIRY_TIME, location = Self)]
    fun check_registration_invalid_expiry_time(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);

        timestamp::update_global_time_for_test_secs(50);
        register(user,
            PAYLOAD,
            25,
            70,
            20,
            PARENT_HASH,
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EEXPIRY_BEFORE_NEXT_EPOCH, location = Self)]
    fun check_registration_invalid_expiry_time_before_next_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            EPOCH_INTERVAL_FOR_TEST / MICROSECS_CONVERSION_FACTOR / 2,
            70,
            20,
            PARENT_HASH,
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_GAS_PRICE, location = Self)]
    fun check_registration_invalid_gas_price_cap(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            70,
            0,
            PARENT_HASH,
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_MAX_GAS_AMOUNT, location = Self)]
    fun check_registration_invalid_max_gas_amount(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            0,
            70,
            PARENT_HASH,
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_TXN_HASH, location = Self)]
    fun check_registration_invalid_parent_hash(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            10,
            70,
            vector<u8>[0, 1, 2, 3],
        );
    }


    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EGAS_AMOUNT_UPPER, location = Self)]
    fun check_registration_with_overflow_gas_limit(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            60000000,
            20,
            PARENT_HASH
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(60000000 == get_gas_committed_for_next_epoch(), 1);
        register(user,
            PAYLOAD,
            86400,
            50000000,
            20,
            PARENT_HASH
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_activation_on_new_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );

        // No active task and committed gas for the next epoch is total of the all registered tasks
        assert!(40 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        assert!(active_task_ids == vector[], 1);

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST / MICROSECS_CONVERSION_FACTOR);
        on_new_epoch();
        assert!(40 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        // But here task 3 is in the active list as it is still active in this new epoch.
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        });
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_successful_cancellation(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST / MICROSECS_CONVERSION_FACTOR);
        on_new_epoch();
        assert!(40 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        });

        // Cancle task 2. The committed gas for the next epoch will be updated,
        // but when requested active task it will be still available in the list
        cancel_task(user, 2);
        // Task will be still available in the registry but with cancled state
        let task_2_details = get_task_details(2);
        assert!(task_2_details.state == CANCELLED, 1);

        assert!(30 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        });

        // Add and cancel the task in the same epoch. Task index will be 4
        assert!(get_next_task_index() == 4, 1);
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        cancel_task(user, 4);
        assert!(30 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |id| {
            assert!(vector::contains(&expected_ids, &id), 1);
        });
        // there is no task with index 4 and the next task index will be 5.
        assert!(!has_task_with_id(4), 1);
        assert!(get_next_task_index() == 5, 1)
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EAUTOMATION_TASK_NOT_FOUND, location = Self)]
    fun check_cancellation_of_non_existing_task(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry {
        initialize_registry_test(framework, user);

        cancel_task(user, 1);
    }

    #[test(framework = @supra_framework, user = @0x1cafe, user2 = @0x1cafa)]
    #[expected_failure(abort_code = EUNAUTHORIZED_TASK_OWNER, location = Self)]
    fun check_unauthorized_cancellation_task(
        framework: &signer,
        user: &signer,
        user2: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        cancel_task(user2, 0);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EALREADY_CANCELLED, location = Self)]
    fun check_cacellation_of_cancelled_task(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, EpochState {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            PARENT_HASH
        );
        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch();
        // Cancel the same task 2 times
        cancel_task(user, 0);
        cancel_task(user, 0);
    }
}
