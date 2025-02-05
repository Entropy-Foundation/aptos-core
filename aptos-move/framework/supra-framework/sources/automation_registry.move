/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry {

    use std::signer;
    use std::string::{Self, String};
    use std::vector;
    use aptos_std::math64;

    use supra_std::enumerable_map::{Self, EnumerableMap};

    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::coin::balance;
    use supra_framework::config_buffer;
    use supra_framework::create_signer::create_signer;
    use supra_framework::event;
    use supra_framework::supra_account;
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;

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
    /// Task with provided task index not found
    const EAUTOMATION_TASK_NOT_FOUND: u64 = 6;
    /// Gas amount must not go beyond upper cap limit
    const EGAS_AMOUNT_UPPER: u64 = 7;
    /// Unauthorized access: the caller is not the owner of the task
    const EUNAUTHORIZED_TASK_OWNER: u64 = 8;
    /// Transactoin hash that registring current task is invalid. Lenght should be 32.
    const EINVALID_TXN_HASH: u64 = 9;
    /// Current committed gas amount is greater than the automation gas limit.
    const EUNACCEPTABLE_AUTOMATION_GAS_LIMIT: u64 = 10;
    /// Task is already cancelled.
    const EALREADY_CANCELLED: u64 = 11;
    /// The gas committed for next epoch value is overflow after adding new max gas
    const EGAS_COMMITTEED_VALUE_OVERFLOW: u64 = 12;
    /// The gas committed for next epoch value is underflow after remove old max gas
    const EGAS_COMMITTEED_VALUE_UNDERFLOW: u64 = 13;
    /// Auxiliary data during registration is not supported
    const ENO_AUX_DATA_SUPPORTED: u64 = 14;

    /// The lenght of the transaction hash.
    const TXN_HASH_LENGTH: u64 = 32;
    /// Conversion factor between microseconds and second
    const MICROSECS_CONVERSION_FACTOR: u64 = 1_000_000;
    /// Registry resource creation seed
    const REGISTRY_RESOURCE_SEED: vector<u8> = b"supra_framework::automation_registry";
    /// Max U64 value
    const MAX_U64: u128 = 18446744073709551615;
    /// Decimal place to make
    const DECIMAL: u256 = 100000000; // 10^8 Power

    /// Constants describing task state.
    const PENDING: u8 = 0;
    const ACTIVE: u8 = 1;
    const CANCELLED: u8 = 2;

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct ActiveAutomationRegistryConfig has key {
        main_config: AutomationRegistryConfig,
        /// Will be the same as main_config.registry_max_gas_cap, unless updated during the epoch.
        next_epoch_registry_max_gas_cap: u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    #[event]
    /// Automation registry config
    struct AutomationRegistryConfig has key, store, drop, copy {
        /// Maximum allowable duration (in seconds) from the registration time that an automation task can run.
        /// If the expiration time exceeds this duration, the task registration will fail.
        task_duration_cap_in_secs: u64,
        /// Maximum gas allocation for automation tasks per epoch
        /// Exceeding this limit during task registration will cause failure and is used in fee calculation.
        registry_max_gas_cap: u64,
        /// Base fee per second for the full capacity of the automation registry, measured in quants/sec.
        /// The capacity is considered full if the total committed gas of all registered tasks equals registry_max_gas_cap.
        automation_base_fee_in_quants_per_sec: u64,
        /// Flat registration fee charged by default for each task.
        flat_registration_fee_in_quants: u64,
        /// Ratio (in the range [0;100]) representing the acceptable upper limit of committed gas amount
        /// relative to registry_max_gas_cap. Beyond this threshold, congestion fees apply.
        congestion_threshold_percentage: u8,
        /// Base fee per second for the full capacity of the automation registry when the congestion threshold is exceeded.
        congestion_base_fee_in_quants_per_sec: u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// It tracks entries both pending and completed, organized by unique indices.
    struct AutomationRegistry has key, store {
        /// A collection of automation task entries that are active state.
        tasks: EnumerableMap<u64, AutomationTaskMetaData>,
        /// Automation task index which increase
        current_index: u64,
        /// Gas committed for next epoch
        gas_committed_for_next_epoch: u64,
        /// It's resource address which is use to deposit user automation fee
        registry_fee_address: address,
        /// Resource account signature capability
        registry_fee_address_signer_cap: SignerCapability,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Epoch state
    struct AutomationEpochInfo has key {
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

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    #[event]
    /// `AutomationTaskMetaData` represents a single automation task item, containing metadata.
    struct AutomationTaskMetaData has key, copy, store, drop {
        /// Automation task index in registry
        task_index: u64,
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
        /// Maximum automation fee for epoch to be paid ever.
        automation_fee_cap_for_epoch: u64,
        /// Auxiliary data specified for the task to aid registration.
        /// Not used currently. Reserved for future extentions.
        aux_data: vector<vector<u8>>,
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
    struct AutomationCancellationRefund has drop, store {
        user: address,
        task_index: u64,
        amount: u64
    }

    #[event]
    /// Cancelled automation task registry event
    struct CancelledAutomationTask has drop, store {
        task_index: u64
    }

    #[event]
    /// Event emitted when a transaction fee is charged for an automation task in an epoch.
    struct AutomationEpochTransactionFeeCharged has drop, store {
        task_index: u64,
        owner: address,
        fee: u64,
    }

    #[event]
    /// Event emitted when an automation task is canceled due to insufficient balance.
    struct AutomationTaskAutoCanceled has drop, store {
        task_index: u64,
        owner: address,
        fee: u64,
        reason: String,
    }

    /// Represents the fee charged for an automation task execution and some additional information.
    struct AutomationTaskFee has drop {
        task_index: u64,
        owner: address,
        fee: u64,
        // Need max gas amount to calculate "gas_committed_for_next_epoch"
        max_gas_amount: u64,
        // Need expiry time to calculate "gas_committed_for_next_epoch"
        expiry_time: u64,
        automation_fee_cap_for_epoch: u64,
    }

    /// This is temporary function : until we have initialization flow properly implemented
    public fun initializate_by_default(supra_framework: &signer, epoch_interval_microsecs: u64) {
        initialize(
            supra_framework,
            epoch_interval_microsecs,
            2_626_560,
            100_000_000,
            1000,
            100_000_000, // 1 supra
            80,
            100,
        );
    }

    /// Initialization of Automation Registry
    public fun initialize(
        supra_framework: &signer,
        epoch_interval_microsecs: u64,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        automation_base_fee_in_quants_per_sec: u64,
        flat_registration_fee_in_quants: u64,
        congestion_threshold_percentage: u8,
        congestion_base_fee_in_quants_per_sec: u64,
    ) {
        system_addresses::assert_supra_framework(supra_framework);

        let (registry_fee_resource_signer, registry_fee_address_signer_cap) = account::create_resource_account(
            supra_framework,
            REGISTRY_RESOURCE_SEED
        );

        move_to(supra_framework, AutomationRegistry {
            tasks: enumerable_map::new_map(),
            current_index: 0,
            gas_committed_for_next_epoch: 0,
            registry_fee_address: signer::address_of(&registry_fee_resource_signer),
            registry_fee_address_signer_cap,
        });

        move_to(supra_framework, ActiveAutomationRegistryConfig {
            main_config: AutomationRegistryConfig {
                task_duration_cap_in_secs,
                registry_max_gas_cap,
                automation_base_fee_in_quants_per_sec,
                flat_registration_fee_in_quants,
                congestion_threshold_percentage,
                congestion_base_fee_in_quants_per_sec,
            },
            next_epoch_registry_max_gas_cap: registry_max_gas_cap
        });

        let epoch_interval = epoch_interval_microsecs / MICROSECS_CONVERSION_FACTOR;
        move_to(supra_framework, AutomationEpochInfo {
            expected_epoch_duration: epoch_interval,
            epoch_interval,
            start_time: 0,
        });
    }

    /// On new epoch this function will be triggered and update the automation registry state
    public(friend) fun on_new_epoch() acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let automation_epoch_info = borrow_global_mut<AutomationEpochInfo>(@supra_framework);

        // Apply the latest configuration if any parameter has been updated.
        update_config_from_buffer();
        let automation_registry_config = borrow_global_mut<ActiveAutomationRegistryConfig>(
            @supra_framework
        ).main_config;

        // Accumulated maximum gas amount of the registered tasks for the current epoch
        let current_time = timestamp::now_seconds();
        let tcmg = cleanup_and_activate_tasks(automation_registry, current_time);

        let tasks_automation_fees = calculate_tasks_automation_fees(
            automation_registry,
            automation_epoch_info,
            &automation_registry_config,
            current_time,
            tcmg
        );

        let gas_committed_for_next_epoch = try_withdraw_task_automation_fees(
            automation_registry,
            tasks_automation_fees,
            current_time,
            automation_epoch_info.epoch_interval
        );

        automation_registry.gas_committed_for_next_epoch = gas_committed_for_next_epoch;
        automation_epoch_info.start_time = current_time;
        automation_epoch_info.expected_epoch_duration = automation_epoch_info.epoch_interval;
    }

    /// Cleanup and actiavete the automation task also it's calculate and return total committed max gas
    fun cleanup_and_activate_tasks(automation_registry: &mut AutomationRegistry, current_time: u64): u256 {
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);
        let tcmg = 0;

        // Perform clean up and updation of state
        vector::for_each(ids, |task_index| {
            let task = enumerable_map::get_value_mut(&mut automation_registry.tasks, task_index);

            // Drop or activate task for this current epoch.
            if (task.expiry_time <= current_time || task.state == CANCELLED) {
                enumerable_map::remove_value(&mut automation_registry.tasks, task_index);
            } else {
                task.state = ACTIVE;
                tcmg = tcmg + (task.max_gas_amount as u256);
            }
        });
        tcmg
    }

    /// Charges automation task fees for all active tasks at the beginning of a new epoch.
    fun calculate_tasks_automation_fees(
        automation_registry: &AutomationRegistry,
        aei: &AutomationEpochInfo,
        arc: &AutomationRegistryConfig,
        current_time: u64,
        tcmg: u256
    ): vector<AutomationTaskFee> {
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);
        // Compute the automation congestion fee (acf) for the epoch
        let acf = calculate_automation_congestion_fee(arc, tcmg);
        let task_with_fees = vector[];

        // Process each active task and apply the fee charges for the new epoch
        vector::for_each(ids, |task_index| {
            let task = enumerable_map::get_value(&automation_registry.tasks, task_index);
            if (task.state == ACTIVE) {
                let task_fee = calculate_task_fee(aei, arc, &task, current_time, acf);
                vector::push_back(&mut task_with_fees, AutomationTaskFee {
                    task_index: task.task_index,
                    owner: task.owner,
                    fee: task_fee,
                    max_gas_amount: task.max_gas_amount,
                    expiry_time: task.expiry_time,
                    automation_fee_cap_for_epoch: task.automation_fee_cap_for_epoch,
                });
            }
        });
        task_with_fees
    }

    /// Charges automation task fees for a single task at the time of new epoch.
    /// This is supposed to be called only after removing expired task and must not be called for expired task.
    /// It's return
    fun calculate_task_fee(
        aei: &AutomationEpochInfo,
        arc: &AutomationRegistryConfig,
        task: &AutomationTaskMetaData,
        current_time: u64,
        acf: u256
    ): u64 {
        let abf = (arc.automation_base_fee_in_quants_per_sec as u256);
        let max_gas_cap = (arc.registry_max_gas_cap as u256);
        let task_max_gas = (task.max_gas_amount as u256);

        let epoch_interval = aei.epoch_interval;

        // Subtraction is safe here, as we already removed expiry tasks
        let remaining_time = task.expiry_time - current_time;
        let min_interval = (math64::min(remaining_time, epoch_interval) as u256);
        let task_occupancy_ratio_by_duration = min_interval * task_max_gas / max_gas_cap;

        // Compute the base automation fee (taf). Total base fee for the interval
        let taf = abf * task_occupancy_ratio_by_duration;

        // Compute the congestion fee per task (tcf)
        let tcf = acf * task_occupancy_ratio_by_duration;

        (taf + tcf as u64)
    }

    /// Calculate automation congestion fee for the epoch
    fun calculate_automation_congestion_fee(arc: &AutomationRegistryConfig, tcmg: u256): u256 {
        let max_gas_cap = (arc.registry_max_gas_cap as u256);
        let threshold_percentage = (arc.congestion_threshold_percentage as u256) * DECIMAL;

        // Calculate congestion threshold surplus for the current epoch
        let threshold_usage = (tcmg * DECIMAL / max_gas_cap) * 100;
        if (threshold_usage < threshold_percentage) 0
        else {
            let threshold_surplus = threshold_usage - threshold_percentage;
            // Compute the automation congestion fee (acf) for the epoch
            let acf = ((arc.congestion_base_fee_in_quants_per_sec as u256) * threshold_surplus / 100) / DECIMAL;
            acf
        }
    }

    /// Processes automation task fees by checking user balances.
    /// - If the user has sufficient balance, deducts the fee and emits a success event.
    /// - If the balance is insufficient, removes the task and emits a cancellation event.
    fun try_withdraw_task_automation_fees(
        automation_registry: &mut AutomationRegistry,
        tasks_automation_fees: vector<AutomationTaskFee>,
        current_time: u64,
        epoch_interval: u64,
    ): u64 {
        let gas_committed_for_next_epoch = 0;

        vector::for_each(tasks_automation_fees, |task| {
            let task: AutomationTaskFee = task;
            let user_balance = balance<SupraCoin>(task.owner);

            // Remove the automation task if the epoch fee cap is exceeded
            if (task.fee > task.automation_fee_cap_for_epoch) {
                enumerable_map::remove_value(&mut automation_registry.tasks, task.task_index);
                event::emit(AutomationTaskAutoCanceled {
                    task_index: task.task_index,
                    owner: task.owner,
                    fee: task.fee,
                    reason: string::utf8(b"Epoch Fee Cap Reached"),
                });
            } else if (user_balance < task.fee) {
                // If the user does not have enough balance, remove the task and emit an event
                enumerable_map::remove_value(&mut automation_registry.tasks, task.task_index);
                event::emit(AutomationTaskAutoCanceled {
                    task_index: task.task_index,
                    owner: task.owner,
                    fee: task.fee,
                    reason: string::utf8(b"Insufficient Balance"),
                });
            } else {
                // Charge the fee and emit a success event
                supra_account::transfer(&create_signer(task.owner), automation_registry.registry_fee_address, task.fee);
                event::emit(AutomationEpochTransactionFeeCharged {
                    task_index: task.task_index,
                    owner: task.owner,
                    fee: task.fee,
                });

                // Calculate gas commitment for the next epoch only for valid active tasks
                if (task.expiry_time > (current_time + epoch_interval)) {
                    gas_committed_for_next_epoch = gas_committed_for_next_epoch + task.max_gas_amount;
                };
            };
        });
        gas_committed_for_next_epoch
    }

    /// The function updates the ActiveAutomationRegistryConfig structure with values extracted from the buffer, if the buffer exists.
    fun update_config_from_buffer() acquires ActiveAutomationRegistryConfig {
        if (config_buffer::does_exist<AutomationRegistryConfig>()) {
            let buffer = config_buffer::extract<AutomationRegistryConfig>();
            let automation_registry_config = &mut borrow_global_mut<ActiveAutomationRegistryConfig>(
                @supra_framework
            ).main_config;
            automation_registry_config.task_duration_cap_in_secs = buffer.task_duration_cap_in_secs;
            automation_registry_config.registry_max_gas_cap = buffer.registry_max_gas_cap;
            automation_registry_config.automation_base_fee_in_quants_per_sec = buffer.automation_base_fee_in_quants_per_sec;
            automation_registry_config.flat_registration_fee_in_quants = buffer.flat_registration_fee_in_quants;
            automation_registry_config.congestion_threshold_percentage = buffer.congestion_threshold_percentage;
            automation_registry_config.congestion_base_fee_in_quants_per_sec = buffer.congestion_base_fee_in_quants_per_sec;
        };
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

    /// Update Automation Registry Config
    public fun update_config(
        supra_framework: &signer,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        automation_base_fee_in_quants_per_sec: u64,
        flat_registration_fee_in_quants: u64,
        congestion_threshold_percentage: u8,
        congestion_base_fee_in_quants_per_sec: u64,
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);

        assert!(
            automation_registry.gas_committed_for_next_epoch < registry_max_gas_cap,
            EUNACCEPTABLE_AUTOMATION_GAS_LIMIT
        );

        let new_automation_registry_config = AutomationRegistryConfig {
            task_duration_cap_in_secs,
            registry_max_gas_cap,
            automation_base_fee_in_quants_per_sec,
            flat_registration_fee_in_quants,
            congestion_threshold_percentage,
            congestion_base_fee_in_quants_per_sec,
        };
        config_buffer::upsert(copy new_automation_registry_config);

        // next_epoch_registry_max_gas_cap will be update instantly
        let automation_registry_config = borrow_global_mut<ActiveAutomationRegistryConfig>(@supra_framework);
        automation_registry_config.next_epoch_registry_max_gas_cap = registry_max_gas_cap;

        event::emit(new_automation_registry_config);
    }

    /// Registers a new automation task entry.
    fun register(
        owner: &signer,
        payload_tx: vector<u8>,
        expiry_time: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
        automation_fee_cap_for_epoch: u64,
        tx_hash: vector<u8>,
        aux_data: vector<vector<u8>>
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        assert!(vector::is_empty(&aux_data), ENO_AUX_DATA_SUPPORTED);
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let automation_registry_config = borrow_global<ActiveAutomationRegistryConfig>(@supra_framework);
        let automation_epoch_info = borrow_global<AutomationEpochInfo>(@supra_framework);

        //Well-formedness check of payload_tx is done in native layer beforehand.

        let registration_time = timestamp::now_seconds();
        let task_duration = check_registration_task_duration(
            expiry_time,
            registration_time,
            &automation_registry_config.main_config,
            automation_epoch_info
        );

        assert!(gas_price_cap > 0, EINVALID_GAS_PRICE);
        assert!(max_gas_amount > 0, EINVALID_MAX_GAS_AMOUNT);
        assert!(vector::length(&tx_hash) == TXN_HASH_LENGTH, EINVALID_TXN_HASH);

        let committed_gas = (automation_registry.gas_committed_for_next_epoch as u128) + (max_gas_amount as u128);
        assert!(committed_gas <= MAX_U64, EGAS_COMMITTEED_VALUE_OVERFLOW);

        let committed_gas = (committed_gas as u64);
        assert!(committed_gas < automation_registry_config.next_epoch_registry_max_gas_cap, EGAS_AMOUNT_UPPER);
        automation_registry.gas_committed_for_next_epoch = committed_gas;
        let task_index = automation_registry.current_index;

        let automation_task_metadata = AutomationTaskMetaData {
            task_index,
            owner: signer::address_of(owner),
            payload_tx,
            expiry_time,
            max_gas_amount,
            gas_price_cap,
            automation_fee_cap_for_epoch,
            aux_data,
            state: PENDING,
            registration_time,
            tx_hash,
        };

        enumerable_map::add_value(&mut automation_registry.tasks, task_index, automation_task_metadata);
        automation_registry.current_index = automation_registry.current_index + 1;

        // Charge flate registration fee from the user at the time of registration
        supra_account::transfer(
            owner,
            automation_registry.registry_fee_address,
            automation_registry_config.main_config.flat_registration_fee_in_quants
        );

        event::emit(automation_task_metadata);
    }

    fun check_registration_task_duration(
        expiry_time: u64,
        registration_time: u64,
        automation_registry_config: &AutomationRegistryConfig,
        automation_epoch_info: &AutomationEpochInfo
    ): u64 {
        assert!(expiry_time > registration_time, EINVALID_EXPIRY_TIME);
        let task_duration = expiry_time - registration_time;
        assert!(task_duration < automation_registry_config.task_duration_cap_in_secs, EEXPIRY_TIME_UPPER);

        // Check that task is valid at least in the next epoch
        assert!(
            expiry_time > (automation_epoch_info.start_time + automation_epoch_info.epoch_interval),
            EEXPIRY_BEFORE_NEXT_EPOCH
        );
        task_duration
    }

    /// Cancel Automation task with specified task_index.
    /// Only existing task, which is PENDING or ACTIVE, can be cancled and only by task onwer.
    /// If the task is
    ///   - active, its state is updated to be CANCELLED.
    ///   - pending, it is removed form the list.
    ///   - cancelled, an error is reported
    /// Committed gas-limit is updated by reducing it with the max-gas-amount of the cancelled task.
    public entry fun cancel_task(owner: &signer, task_index: u64) acquires AutomationRegistry {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        assert!(enumerable_map::contains(&automation_registry.tasks, task_index), EAUTOMATION_TASK_NOT_FOUND);

        let automation_task_metadata = enumerable_map::get_value(&mut automation_registry.tasks, task_index);
        assert!(automation_task_metadata.owner == signer::address_of(owner), EUNAUTHORIZED_TASK_OWNER);
        assert!(automation_task_metadata.state != CANCELLED, EALREADY_CANCELLED);
        if (automation_task_metadata.state == PENDING) {
            enumerable_map::remove_value(&mut automation_registry.tasks, task_index);
        } else if (automation_task_metadata.state == ACTIVE) {
            let automation_task_metadata_mut = enumerable_map::get_value_mut(
                &mut automation_registry.tasks,
                task_index
            );
            automation_task_metadata_mut.state = CANCELLED;
        };

        assert!(
            automation_registry.gas_committed_for_next_epoch >= automation_task_metadata.max_gas_amount,
            EGAS_COMMITTEED_VALUE_UNDERFLOW
        );
        // Adjust the gas committed for the next epoch by subtracting the gas amount of the cancelled task
        automation_registry.gas_committed_for_next_epoch = automation_registry.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

        event::emit(CancelledAutomationTask { task_index: automation_task_metadata.task_index });
    }

    /// Update epoch interval in registry while actually update happens in block module
    public(friend) fun update_epoch_interval_in_registry(epoch_interval_microsecs: u64) acquires AutomationEpochInfo {
        if (exists<AutomationEpochInfo>(@supra_framework)) {
            let automation_epoch_info = borrow_global_mut<AutomationEpochInfo>(@supra_framework);
            automation_epoch_info.epoch_interval = epoch_interval_microsecs / MICROSECS_CONVERSION_FACTOR;
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
            if (task.state != PENDING) (true, task.task_index)
            else (false, task.task_index)
        })
    }

    #[view]
    /// Retrieves the details of a automation task entry by its task index.
    /// Error will be returned if entry with specified task index does not exist.
    public fun get_task_details(task_index: u64): AutomationTaskMetaData acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        assert!(enumerable_map::contains(&automation_task_metadata.tasks, task_index), EAUTOMATION_TASK_NOT_FOUND);
        enumerable_map::get_value(&automation_task_metadata.tasks, task_index)
    }

    #[view]
    /// Checks whether there is an active task in registry with specified input task index.
    public fun has_sender_active_task_with_id(sender: address, task_index: u64): bool acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        if (enumerable_map::contains(&automation_task_metadata.tasks, task_index)) {
            let value = enumerable_map::get_value_ref(&automation_task_metadata.tasks, task_index);
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

    #[view]
    /// Get automation registry configration
    public fun get_automation_registry_config(): AutomationRegistryConfig acquires ActiveAutomationRegistryConfig {
        borrow_global<ActiveAutomationRegistryConfig>(@supra_framework).main_config
    }

    #[view]
    /// Get automation registry configration
    public fun get_next_epoch_registry_max_gas_cap(): u64 acquires ActiveAutomationRegistryConfig {
        borrow_global<ActiveAutomationRegistryConfig>(@supra_framework).next_epoch_registry_max_gas_cap
    }

    #[test_only]
    const AUTOMATION_MAX_GAS_TEST: u64 = 100_000_000;
    #[test_only]
    const TTL_UPPER_BOUND_TEST: u64 = 2_626_560;
    #[test_only]
    const AUTOMATION_BASE_FEE_TEST: u64 = 1000;
    #[test_only]
    const FLATE_REGISTRATION_FEE_TEST: u64 = 500000000;
    #[test_only]
    const CONGESTION_THRESHOLD_TEST: u8 = 80;
    #[test_only]
    const CONGESTION_BASE_FEE_TEST: u64 = 100;
    #[test_only]
    /// Value defined in microsecond
    const EPOCH_INTERVAL_FOR_TEST: u64 = 7200000000;
    #[test_only]
    const PARENT_HASH: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
    #[test_only]
    const PAYLOAD: vector<u8> = x"0102030405060708090a0b0c0d0e0f0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20101112131415161718191a1b1c1d1e1f20";
    #[test_only]
    const AUX_DATA: vector<vector<u8>> = vector[];


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

        initialize(
            supra_framework,
            EPOCH_INTERVAL_FOR_TEST,
            TTL_UPPER_BOUND_TEST,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLATE_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
        );
    }

    #[test_only]
    fun has_task_with_id(task_index: u64): bool acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        enumerable_map::contains(&automation_registry.tasks, task_index)
    }

    #[test(supra_framework = @supra_framework, user = @0x1cafe)]
    fun test_registry(
        supra_framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(supra_framework, user);

        let payload = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132";
        let parent_hash = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
        register(user, payload, 86400, 1000, 100000, 100_000_00, parent_hash, AUX_DATA);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_update_config_success_update(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            50,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        config_buffer::initialize(framework);
        // Next epoch gas committed gas is less than the new limit value.
        // Configration parameter will update after on new epoch
        update_config(framework, 1_626_560, 75, 1005, 700000000, 70, 2000);

        let state = borrow_global<ActiveAutomationRegistryConfig>(@supra_framework);
        assert!(state.main_config.registry_max_gas_cap == AUTOMATION_MAX_GAS_TEST, 1);
        assert!(state.next_epoch_registry_max_gas_cap == 75, 1);

        // Automation gas limit
        on_new_epoch();
        let state = borrow_global<ActiveAutomationRegistryConfig>(@supra_framework).main_config;
        assert!(state.registry_max_gas_cap == 75, 2);
        assert!(state.task_duration_cap_in_secs == 1_626_560, 3);
        assert!(state.automation_base_fee_in_quants_per_sec == 1005, 4);
        assert!(state.flat_registration_fee_in_quants == 700000000, 5);
        assert!(state.congestion_threshold_percentage == 70, 6);
        assert!(state.congestion_base_fee_in_quants_per_sec == 2000, 7);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EUNACCEPTABLE_AUTOMATION_GAS_LIMIT, location = Self)]
    fun check_automation_gas_limit_failed_update(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            50,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );

        // Next epoch gas committed gas is greater than the new limit value.
        update_config(
            framework,
            TTL_UPPER_BOUND_TEST,
            45,
            AUTOMATION_BASE_FEE_TEST,
            FLATE_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_registration(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(10 == get_gas_committed_for_next_epoch(), 1)
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_EXPIRY_TIME, location = Self)]
    fun check_registration_invalid_expiry_time(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        timestamp::update_global_time_for_test_secs(50);
        register(user,
            PAYLOAD,
            25,
            70,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EEXPIRY_BEFORE_NEXT_EPOCH, location = Self)]
    fun check_registration_invalid_expiry_time_before_next_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            EPOCH_INTERVAL_FOR_TEST / MICROSECS_CONVERSION_FACTOR / 2,
            70,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_GAS_PRICE, location = Self)]
    fun check_registration_invalid_gas_price_cap(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            70,
            0,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_MAX_GAS_AMOUNT, location = Self)]
    fun check_registration_invalid_max_gas_amount(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            0,
            70,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_TXN_HASH, location = Self)]
    fun check_registration_invalid_parent_hash(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            10,
            70,
            1000,
            vector<u8>[0, 1, 2, 3],
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = ENO_AUX_DATA_SUPPORTED, location = Self)]
    fun check_registration_with_aux_data(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        let new_param1 = vector[0u8, 1, 2];
        let aux_data = vector[new_param1];
        register(user,
            PAYLOAD,
            86400,
            10,
            70,
            1000,
            PARENT_HASH,
            aux_data
        );
    }


    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EGAS_AMOUNT_UPPER, location = Self)]
    fun check_registration_with_overflow_gas_limit(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            60000000,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(60000000 == get_gas_committed_for_next_epoch(), 1);
        register(user,
            PAYLOAD,
            86400,
            50000000,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_activation_on_new_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
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
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
        });
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_successful_cancellation(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST / MICROSECS_CONVERSION_FACTOR);
        on_new_epoch();
        assert!(40 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
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
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
        });

        // Add and cancel the task in the same epoch. Task index will be 4
        assert!(get_next_task_index() == 4, 1);
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        cancel_task(user, 4);
        assert!(30 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
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
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        cancel_task(user2, 0);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EALREADY_CANCELLED, location = Self)]
    fun check_cacellation_of_cancelled_task(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch();
        // Cancel the same task 2 times
        cancel_task(user, 0);
        cancel_task(user, 0);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_normal_fee_charge_on_new_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            1_000_000, // normal gas amount
            20,
            100000,
            PARENT_HASH,
            AUX_DATA
        );

        // check user balance after registred new task
        let balance = balance<SupraCoin>(signer::address_of(user));
        assert!(balance == 10000000000 - FLATE_REGISTRATION_FEE_TEST, 11);

        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch();

        // check user balance after on new epoch fee applied
        let balance = balance<SupraCoin>(signer::address_of(user));
        assert!(balance == 9499928000, 12);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_congestion_fee_charge_on_new_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            86400,
            85_000_000, // congestion threashold reach
            20,
            10000000,
            PARENT_HASH,
            AUX_DATA
        );

        // check user balance after registred new task
        let balance = balance<SupraCoin>(signer::address_of(user));
        assert!(balance == 10000000000 - FLATE_REGISTRATION_FEE_TEST, 11);

        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch();

        // check user balance after on new epoch fee applied
        let balance = balance<SupraCoin>(signer::address_of(user));
        assert!(balance == 9493849400, 12);
    }
}
