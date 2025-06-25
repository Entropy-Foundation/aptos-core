/// Supra Automation tegistry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry {

    use std::features;
    use std::signer;
    use std::vector;
    use aptos_std::math64;
    use supra_framework::system_addresses::assert_supra_framework;
    use supra_framework::coin::{Coin, destroy_zero};

    use supra_std::enumerable_map::{Self, EnumerableMap};

    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::coin;
    use supra_framework::config_buffer;
    use supra_framework::create_signer::create_signer;
    use supra_framework::event;
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;

    #[test_only]
    use std::signer::address_of;

    friend supra_framework::block;
    friend supra_framework::genesis;
    friend supra_framework::reconfiguration_with_dkg;

    /// Invalid expiry time: it cannot be earlier than the current time
    const EINVALID_EXPIRY_TIME: u64 = 1;
    /// Expiry time does not go beyond upper cap duration
    const EEXPIRY_TIME_UPPER: u64 = 2;
    /// Expiry time must be after the start of the next cycle
    const EEXPIRY_BEFORE_NEXT_CYCLE: u64 = 3;
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
    /// Transaction hash that registering current task is invalid. Length should be 32.
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
    /// Supra native automation feature is not initialized or enabled
    const EDISABLED_AUTOMATION_FEATURE: u64 = 15;
    /// Insufficient balance in the resource wallet for withdrawal
    const EINSUFFICIENT_BALANCE: u64 = 16;
    /// Requested amount exceeds the locked balance
    const EREQUEST_EXCEEDS_LOCKED_BALANCE: u64 = 17;
    /// Current automation cycle interval is greater than specified task duration cap.
    const EUNACCEPTABLE_TASK_DURATION_CAP: u64 = 18;
    /// Congestion threshold should not exceed 100.
    const EMAX_CONGESTION_THRESHOLD: u64 = 19;
    /// Congestion exponent must be non-zero.
    const ECONGESTION_EXP_NON_ZERO: u64 = 20;
    /// Automation fee capacity for the epoch should not be less than estimated one.
    const EINSUFFICIENT_AUTOMATION_FEE_CAP_FOR_EPOCH: u64 = 21;
    /// Automation registry max gas capacity cannot be zero.
    const EREGISTRY_MAX_GAS_CAP_NON_ZERO: u64 = 22;
    /// Registry task capacity has reached.
    const EREGISTRY_IS_FULL: u64 = 23;
    /// Task registration is currently disabled.
    const ETASK_REGISTRATION_DISABLED: u64 = 24;
    /// Task index list is empty.
    const EEMPTY_TASK_INDEXES: u64 = 25;
    /// Resource Account does not have sufficient balance to process the refund for the specified task.
    const EINSUFFICIENT_BALANCE_FOR_REFUND: u64 = 26;
    /// Failed to unlock/refund deposit for a task. Internal error, for more details see emitted error events.
    const EDEPOSIT_REFUND: u64 = 27;
    /// Failed to unlock/refund epoch fee for a task. Internal error, for more details see emitted error events.
    const EEPOCH_FEE_REFUND: u64 = 28;
    /// Deprecated function call since cycle based automation release.
    const EDEPRECATED_SINCE_V2: u64 = 29;
    /// Automation registry max gas capacity cannot be zero.
    const ECYCLE_DURATION_NON_ZERO: u64 = 30;
    /// Attempt to do migration to cycle based automation which is already enabled.
    const EINVALID_MIGRATION_ACTION: u64 = 31;
    /// Attempt to register an automation task while cycle transition is in progress.
    const ECYCLE_TRANSITION_IN_PROGRESS: u64 = 32;
    /// Attempt to run operation in invalid registry state.
    const EINVALID_REGISTRY_STATE: u64 = 33;
    /// Attempt to run charge action with inconsistent input values compared to internal state.
    const EINVALID_CHARGE_ACTION: u64 = 34;

    /// The length of the transaction hash.
    const TXN_HASH_LENGTH: u64 = 32;
    /// Conversion factor between microseconds and second
    const MICROSECS_CONVERSION_FACTOR: u64 = 1_000_000;
    /// Registry resource creation seed
    const REGISTRY_RESOURCE_SEED: vector<u8> = b"supra_framework::automation_registry";
    /// Max U64 value
    const MAX_U64: u128 = 18446744073709551615;
    /// Decimal place to make
    // 10^8 Power
    const DECIMAL: u256 = 100_000_000;
    /// 100 Percentage
    const MAX_PERCENTAGE: u8 = 100;
    const REFUND_FRACTION: u64 = 2;

    /// Constants describing task state.
    const PENDING: u8 = 0;
    const ACTIVE: u8 = 1;
    const CANCELLED: u8 = 2;

    /// Constants describing CYCLE state.
    /// State transition flaw is:
    /// READY_TO_START -> CYCLE_STARTED
    /// CYCLE_STARTED -> { CYCLE_FINISHED, CYCLE_SUSPENDED }
    /// CYCLE_FINISHED ->  { CYCLE_STARTED}
    /// CYCLE_SUSPENDED ->  {READY_TO_START, STARTED}
    const READY_TO_START_NEW_CYCLE: u8 = 0;
    /// Triggered eigther when SUPRA_NATIVE_AUTOMATION feature is enabled or by autoamtion cycle manager in native layer.
    const CYCLE_STARTED: u8 = 1;
    /// Triggered when cycle end is identified.
    const CYCLE_FINISHED: u8 = 2;
    /// State describing the entire lifecycle of automation being suspended.
    /// Triggered when SUPRA_NATIVE_AUTOMATION feature is disabled.
    const CYCLE_SUSPENDED: u8 = 3;

    /// Constants describing REFUND TYPE
    const DEPOSIT_EPOCH_FEE: u8 = 0;
    const EPOCH_FEE: u8 = 1;

    /// Defines divisor for refunds of deposit fees with penalty
    /// Factor of `2` suggests that `1/2` of the deposit will be refunded.
    const REFUND_FACTOR: u64 = 2;

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct ActiveAutomationRegistryConfig has key {
        main_config: AutomationRegistryConfig,
        /// Will be the same as main_config.registry_max_gas_cap, unless updated during the epoch.
        next_epoch_registry_max_gas_cap: u64,
        /// Flag indicating whether the task registration is enabled or paused.
        /// If paused a new task registration will fail.
        registration_enabled: bool,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    #[event]
    /// Automation registry configuration parameters
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
        /// The congestion fee increases exponentially based on this value, ensuring higher fees as the registry approaches full capacity.
        congestion_exponent: u8,
        /// Maximum number of tasks that registry can hold.
        task_capacity: u16,
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
        /// Total fee charged to users during the epoch, which is not withdrawable
        epoch_locked_fees: u64,
        /// Total committed max gas amount at the beginning of the current epoch.
        gas_committed_for_this_epoch: u256,
        /// It's resource address which is use to deposit user automation fee
        registry_fee_address: address,
        /// Resource account signature capability
        registry_fee_address_signer_cap: SignerCapability,
        /// Cached active task indexes for the current epoch.
        epoch_active_task_ids: vector<u64>
    }

    /// It tracks entries both pending and completed, organized by unique indices.
    struct TransitionState has key, copy, drop, store {
        /// Duration of the new cycle.
        new_cycle_duration: u64,
        /// Calculated automation fee per second for the new cycle.
        automation_fee_per_sec: u64,
        /// Gas committed for the new cycle being transitioned.
        gas_committed_for_this_cycle: u64,
        /// Gas committed for next cycle
        gas_committed_for_next_cycle: u64,
        /// Total fee charged to users during the cycle, which is not withdrawable
        locked_fees: u64,
        /// Number of the tasks to be processed during transition.
        expected_tasks_to_be_processed: vector<u64>,
        /// So far processed tasks during transition
        /// In case if transition spans between multiple blocks then
        /// upon recovery execution component will know the breaking point and can recover from it.
        actual_processed_tasks: vector<u64>
    }

    fun is_transition_finalized(state: &TransitionState): bool {
        vector::length(&state.expected_tasks_to_be_processed) == vector::length(&state.actual_processed_tasks)
    }
    fun is_transition_in_progress(state: &TransitionState): bool {
        vector::length(&state.actual_processed_tasks) != 0
    }

    fun update_processed_tasks(state: &mut TransitionState, task_indexes: vector<u64>) {
        vector::append(&mut state.actual_processed_tasks, task_indexes);
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Epoch state. Deprecated since SUPRA_AUTOMATION_CYCLE version.
    struct AutomationEpochInfo has key, copy {
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

    /// Cycle Duration wrapper to store in the config-buffer.
    #[event]
    struct AutomationCycleDuration has drop, store, copy {
        /// Automation cycle duration in seconds.
        duration_secs: u64,
    }

    /// Cycle state.
    struct AutomationCycleInfo has key, copy, drop, store {
        /// Current cycle id. Incremented when a start of the new cycle is processed.
        index: u64,
        /// State of the current cycle.
        state: u8,
        /// Current cycle start time which is updated with the current chain time when a cycle is increamented.
        start_time: u64,
        /// Automation cycle duration in seconds.
        duration_secs: u64,
    }

    #[event]
    /// Event emitted in the cycle-state.
    struct AutomationCycleEvent has key, copy, drop, store {
        /// Updated cycle state information.
        cycle_state_info: AutomationCycleInfo,
        /// The state transitioned from
        old_state: u8,
        /// Timestamp of the state transition event registration
        event_time: u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Cycle state.
    struct AutomationCycleDetails has key, copy, drop, store {
        /// Cycle index corresponding to the current state. Incremented when a transition to the new cycle is finalized.
        index: u64,
        /// State of the current cycle.
        state: u8,
        /// Current cycle start time which is updated with the current chain time when a cycle is increamented.
        start_time: u64,
        /// Automation cycle duration in seconds.
        duration_secs: u64,
        /// Intermediate state of cycle transition to next one or suspended state.
        transition_state: std::option::Option<TransitionState>,
    }


    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Automation Deposited fee bookkeeping configs
    struct AutomationRefundBookkeeping has key, copy {
        /// Total deposited fee so far which is locked in resource account unless refund of it (fully or partially) is done.
        /// Regardless of the refunded amount the actual deposited amount is deduced to unlock it from the resource account.
        total_deposited_automation_fee: u64
        // TODO here we can have also configuration parameter like REFUND_FACTOR
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
        /// Not used currently. Reserved for future extensions.
        aux_data: vector<vector<u8>>,
        /// Registration timestamp in seconds
        registration_time: u64,
        /// Flag indicating whether the task is active, cancelled or pending.
        state: u8,
        /// Deposit fee locked for the task equal to the automation-fee-cap for epoch specified for it.
        /// It will be refunded fully when active task is expired or cancelled by user
        /// and partially if a pending task is cancelled by user or an active task is cancelled by the system due to
        /// insufficient balance to  pay the automation fee for the epoch
        locked_fee_for_next_epoch: u64,
    }

    #[event]
    /// Event on task registration fee withdrawal from owner account upon registration.
    struct TaskRegistrationFeeWithdraw has drop, store {
        task_index: u64,
        owner: address,
        fee: u64,
    }

    #[event]
    /// Event on task registration fee withdrawal from owner account upon registration.
    struct TaskRegistrationDepositFeeWithdraw has drop, store {
        task_index: u64,
        owner: address,
        registration_fee: u64,
        locked_deposit_fee: u64,
    }

    #[event]
    /// Emitted on withdrawal of specified amount from automation registry fee address to the specified address.
    struct RegistryFeeWithdraw has drop, store {
        to: address,
        amount: u64
    }

    #[event]
    /// Event emitted when an automation fee is charged for an automation task for the epoch.
    struct TaskEpochFeeWithdraw has drop, store {
        task_index: u64,
        owner: address,
        fee: u64,
    }

    #[event]
    /// Event emitted when an automation fee is refunded for an automation task at the end of the epoch for excessive
    /// duration paid at the beginning of the epoch due to epoch-duration reduction by governance.
    struct TaskFeeRefund has drop, store {
        task_index: u64,
        owner: address,
        amount: u64,
    }

    #[event]
    /// Event emitted when a deposit fee is refunded for an automation task.
    struct TaskDepositFeeRefund has drop, store {
        task_index: u64,
        owner: address,
        amount: u64,
    }

    #[event]
    /// Event emitted when an automation fee is being refunded but inner state bookkeeping total locked deposits is less than
    /// potential locked deposit for the task.
    struct ErrorUnlockTaskDepositFee has drop, store {
        task_index: u64,
        total_registered_deposit: u64,
        locked_deposit: u64
    }

    #[event]
    /// Event emitted when a task epoch fee is being refunded but locked epoch fees is less than
    /// potential requested refund.
    struct ErrorUnlockTaskEpochFee has drop, store {
        task_index: u64,
        locked_epoch_fees: u64,
        refund: u64
    }

    #[event]
    /// Event emitted on automation task cancellation by owner.
    struct TaskCancelled has drop, store {
        task_index: u64,
        owner: address,
    }

    #[event]
    /// Event emitted on automation tasks stopped by owner.
    struct TasksStopped has drop, store {
        tasks: vector<TaskStopped>,
        owner: address,
    }

    struct TaskStopped has drop, store {
        task_index: u64,
        deposit_refund: u64,
        epoch_fee_refund: u64,
    }

    #[event]
    /// Event emitted when an automation task is cancelled due to insufficient balance.
    struct TaskCancelledInsufficentBalance has drop, store {
        task_index: u64,
        owner: address,
        fee: u64,
    }

    #[event]
    /// Event emitted when an automation task is cancelled due to automation fee capacity surpass.
    struct TaskCancelledCapacitySurpassed has drop, store {
        task_index: u64,
        owner: address,
        fee: u64,
        automation_fee_cap: u64,
    }

    #[event]
    /// Event emitted on epoch transition containing removed task indexes.
    struct RemovedTasks has drop, store {
        task_indexes: vector<u64>
    }

    #[event]
    /// Event emitted on epoch transition containing active task indexes for the new epoch.
    struct ActiveTasks has drop, store {
        task_indexes: vector<u64>
    }

    #[event]
    /// Event emitted when on new epoch a task is accessed with index of the task for the expected list
    /// but value does not exist in the map
    struct ErrorTaskDoesNotExist has drop, store {
        task_index: u64,
    }

    #[event]
    /// Event emitted when on new epoch a task is accessed with index of the task automation fee withdrawal
    /// but it does not exist in the list.
    struct ErrorTaskDoesNotExistForWithdrawal has drop, store {
        task_index: u64,
    }

    #[event]
    /// Event emitted during epoch transition when refunds to be paid is not possible due to insufficient resource account balance.
    /// Type of the refund can be related either to the deposit paid during registration (0), or to epoch-fee caused by
    /// the shortening of the epoch (1)
    struct ErrorInsufficientBalanceToRefund has drop, store {
        refund_type: u8,
        task_index: u64,
        owner: address,
        amount: u64,
    }
    #[event]
    /// Event emitted when on new epoch inconsistent state of the registry has been identified.
    /// When automation is in suspended state, there are no tasks expected.
    struct ErrorInconsistentSuspendedState has drop, store {}

    #[event]
    /// Emitted when the registration in the automation registry is enabled.
    struct EnabledRegistrationEvent has drop, store {}

    #[event]
    /// Emitted when the registration in the automation registry is disabled.
    struct DisabledRegistrationEvent has drop, store {}

    /// Represents the fee charged for an automation task execution and some additional information.
    struct AutomationTaskFeeMeta has drop {
        task_index: u64,
        owner: address,
        fee: u64,
        automation_fee_cap: u64,
        expiry_time: u64,
        max_gas_amount: u64,
        locked_deposit_fee: u64
    }

    /// Represents intermediate state of the registry on epoch change.
    /// Deprecated in production, substituted with `IntermediateStateOfEpochChange`.
    /// Kept for backward compatible framework upgrade.
    struct IntermediateState has drop {
        active_task_ids: vector<u64>,
        gas_committed_for_next_epoch: u64,
        epoch_locked_fees: u64,
    }

    /// Represents intermediate state of the registry on epoch change.
    struct IntermediateStateOfEpochChange {
        removed_tasks: vector<u64>,
        gas_committed_for_new_epoch: u64,
        gas_committed_for_next_epoch: u64,
        epoch_locked_fees: Coin<SupraCoin>,
    }

    #[view]
    /// Checks whether all required resources are created.
    public fun is_initialized(): bool {
        exists<AutomationRegistry>(@supra_framework)
            && exists<AutomationRefundBookkeeping>(@supra_framework)
            && exists<ActiveAutomationRegistryConfig>(@supra_framework)
            && exists<AutomationCycleDetails>(@supra_framework)
    }

    #[view]
    /// Means to query by user whether the automation registry has been properly initialized and ready to be utilized.
    public fun is_feature_enabled_and_initialized(): bool {
        features::supra_native_automation_enabled() && is_initialized()
    }

    #[view]
    /// Returns next task index in registry
    public fun get_next_task_index(): u64 acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        automation_registry.current_index
    }

    #[view]
    /// Returns number of available tasks.
    public fun get_task_count(): u64 acquires AutomationRegistry {
        let state = borrow_global<AutomationRegistry>(@supra_framework);
        enumerable_map::length(&state.tasks)
    }

    #[view]
    /// List all automation task ids available in register.
    public fun get_task_ids(): vector<u64> acquires AutomationRegistry {
        let state = borrow_global<AutomationRegistry>(@supra_framework);
        enumerable_map::get_map_list(&state.tasks)
    }

    #[view]
    /// Get locked balance of the resource account in terms of epoch-fees
    public fun get_epoch_locked_balance(): u64 acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        automation_registry.epoch_locked_fees
    }

    #[view]
    /// Get locked balance of the resource account in terms of deposited automation fees.
    public fun get_locked_deposit_balance(): u64 acquires AutomationRefundBookkeeping {
        let refund_bookkeeping = borrow_global<AutomationRefundBookkeeping>(@supra_framework);
        refund_bookkeeping.total_deposited_automation_fee
    }

    #[view]
    /// Get total locked balance of the resource account.
    public fun get_registry_total_locked_balance(): u64 acquires AutomationRefundBookkeeping, AutomationRegistry {
        get_epoch_locked_balance() + get_locked_deposit_balance()
    }

    #[view]
    /// List all active automation task ids for the current epoch.
    /// Note that the tasks with CANCELLED state are still considered active for the current epoch,
    /// as cancellation takes effect in the next epoch only.
    public fun get_active_task_ids(): vector<u64> acquires AutomationRegistry {
        let state = borrow_global<AutomationRegistry>(@supra_framework);
        state.epoch_active_task_ids
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
    /// Retrieves the details of a automation tasks entry by their task index.
    /// If a task does not exist, it is not included in the result, and no error is reported
    public fun get_task_details_bulk(task_indexes: vector<u64>): vector<AutomationTaskMetaData> acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        let task_details = vector[];
        vector::for_each(task_indexes, |task_index| {
            if (enumerable_map::contains(&automation_task_metadata.tasks, task_index)) {
                vector::push_back(&mut task_details, enumerable_map::get_value(&automation_task_metadata.tasks, task_index))
            }
        });
        task_details
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
    /// Get gas committed for the current epoch at the beginning of the epoch.
    public fun get_gas_committed_for_current_epoch(): u64 acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        (automation_registry.gas_committed_for_this_epoch as u64)
    }

    #[view]
    /// Get automation registry configuration
    public fun get_automation_registry_config(): AutomationRegistryConfig acquires ActiveAutomationRegistryConfig {
        borrow_global<ActiveAutomationRegistryConfig>(@supra_framework).main_config
    }

    #[view]
    /// Get automation registry maximum gas capacity for the next epoch
    public fun get_next_epoch_registry_max_gas_cap(): u64 acquires ActiveAutomationRegistryConfig {
        borrow_global<ActiveAutomationRegistryConfig>(@supra_framework).next_epoch_registry_max_gas_cap
    }

    #[view]
    /// Get automation epoch info
    public fun get_automation_epoch_info(): AutomationEpochInfo {
        assert!(false, EDEPRECATED_SINCE_V2);
        AutomationEpochInfo {
            expected_epoch_duration: 0,
            epoch_interval: 0,
            start_time: 0,

        }
    }

    #[view]
    /// Estimates automation fee for the next epoch for specified task occupancy for the configured epoch-interval
    /// referencing the current automation registry fee parameters, current total occupancy and registry maximum allowed
    /// occupancy for the next epoch.
    public fun estimate_automation_fee(
        task_occupancy: u64
    ): u64 acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig {
        let registry = borrow_global<AutomationRegistry>(@supra_framework);
        estimate_automation_fee_with_committed_occupancy(task_occupancy, registry.gas_committed_for_next_epoch)
    }

    #[view]
    /// Estimates automation fee the next epoch for specified task occupancy for the configured epoch-interval
    /// referencing the current automation registry fee parameters, specified total/committed occupancy and registry
    /// maximum allowed occupancy for the next epoch.
    public fun estimate_automation_fee_with_committed_occupancy(
        task_occupancy: u64,
        committed_occupancy: u64
    ): u64 acquires AutomationCycleDetails, ActiveAutomationRegistryConfig {
        let cycle_info = borrow_global<AutomationCycleDetails>(@supra_framework);
        let config = borrow_global<ActiveAutomationRegistryConfig>(@supra_framework);
        estimate_automation_fee_with_committed_occupancy_internal(
            task_occupancy,
            committed_occupancy,
            cycle_info.duration_secs,
            config
        )
    }

    #[view]
    /// Returns the current status of the registration in the automation registry.
    public fun is_registration_enabled(): bool acquires ActiveAutomationRegistryConfig {
        borrow_global<ActiveAutomationRegistryConfig>(@supra_framework).registration_enabled
    }

    #[view]
    /// Returns the current duration of the automation cycle.
    public fun get_cycle_duration(): u64 acquires AutomationCycleDetails {
        borrow_global<AutomationCycleDetails>(@supra_framework).duration_secs
    }

    #[view]
    /// Returns the current status of the registration in the automation registry.
    public fun get_cycle_info(): AutomationCycleInfo acquires AutomationCycleDetails {
        let details = borrow_global<AutomationCycleDetails>(@supra_framework);
        into_automation_cycle_info(details)
    }

    // Public entry functions

    /// Withdraw accumulated automation task fees from the resource account - access by admin
    public fun withdraw_automation_task_fees(
        supra_framework: &signer,
        to: address,
        amount: u64
    ) acquires AutomationRegistry , AutomationRefundBookkeeping {
        system_addresses::assert_supra_framework(supra_framework);
        transfer_fee_to_account_internal(to, amount);
        event::emit(RegistryFeeWithdraw { to, amount });
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
        congestion_exponent: u8,
        task_capacity: u16,
    ) {
        assert!(false, EDEPRECATED_SINCE_V2);
    }

    /// Update Automation Registry Config along with cycle duration.
    public fun update_config_v2(
        supra_framework: &signer,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        automation_base_fee_in_quants_per_sec: u64,
        flat_registration_fee_in_quants: u64,
        congestion_threshold_percentage: u8,
        congestion_base_fee_in_quants_per_sec: u64,
        congestion_exponent: u8,
        task_capacity: u16,
        cycle_duration_secs: u64,
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig {
        system_addresses::assert_supra_framework(supra_framework);


        update_registration_config_internal(
            supra_framework,
            task_duration_cap_in_secs,
            registry_max_gas_cap,
            automation_base_fee_in_quants_per_sec,
            flat_registration_fee_in_quants,
            congestion_threshold_percentage,
            congestion_base_fee_in_quants_per_sec,
            congestion_exponent,
            task_capacity,
            cycle_duration_secs,
        );

        // Update cycle duration in buffer
        assert!(cycle_duration_secs > 0, ECYCLE_DURATION_NON_ZERO);
        let new_cycle_duration = AutomationCycleDuration {
            duration_secs: cycle_duration_secs
        };
        config_buffer::upsert(copy new_cycle_duration);
        event::emit(new_cycle_duration);
    }

    /// Enables the registration process in the automation registry.
    public fun enable_registration(supra_framework: &signer) acquires ActiveAutomationRegistryConfig {
        system_addresses::assert_supra_framework(supra_framework);
        let automation_registry_config = borrow_global_mut<ActiveAutomationRegistryConfig>(@supra_framework);
        automation_registry_config.registration_enabled = true;
        event::emit(EnabledRegistrationEvent {});
    }

    /// Disables the registration process in the automation registry.
    public fun disable_registration(supra_framework: &signer) acquires ActiveAutomationRegistryConfig {
        system_addresses::assert_supra_framework(supra_framework);
        let automation_registry_config = borrow_global_mut<ActiveAutomationRegistryConfig>(@supra_framework);
        automation_registry_config.registration_enabled = false;
        event::emit(DisabledRegistrationEvent {});
    }

    /// Cancel Automation task with specified task_index.
    /// Only existing task, which is PENDING or ACTIVE, can be cancelled and only by task owner.
    /// If the task is
    ///   - active, its state is updated to be CANCELLED.
    ///   - pending, it is removed form the list.
    ///   - cancelled, an error is reported
    /// Committed gas-limit is updated by reducing it with the max-gas-amount of the cancelled task.
    public entry fun cancel_task(
        owner_signer: &signer,
        task_index: u64
    ) acquires AutomationRegistry, AutomationCycleDetails, AutomationRefundBookkeeping{
        assert!(features::supra_native_automation_enabled(), EDISABLED_AUTOMATION_FEATURE);
        let cycle_info = borrow_global<AutomationCycleDetails>(@supra_framework);
        assert!(cycle_info.state == CYCLE_STARTED, ECYCLE_TRANSITION_IN_PROGRESS);
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(@supra_framework);
        assert!(enumerable_map::contains(&automation_registry.tasks, task_index), EAUTOMATION_TASK_NOT_FOUND);

        let automation_task_metadata = enumerable_map::get_value(&mut automation_registry.tasks, task_index);
        let owner = signer::address_of(owner_signer);
        assert!(automation_task_metadata.owner == owner, EUNAUTHORIZED_TASK_OWNER);
        assert!(automation_task_metadata.state != CANCELLED, EALREADY_CANCELLED);
        if (automation_task_metadata.state == PENDING) {
            let resource_signer = account::create_signer_with_capability(
                &automation_registry.registry_fee_address_signer_cap
            );
            // When Pending tasks are cancelled, refund of the deposit fee is done with penalty
            let result = safe_deposit_refund(
                refund_bookkeeping,
                &resource_signer,
                automation_registry.registry_fee_address,
                automation_task_metadata.task_index,
                owner,
                automation_task_metadata.locked_fee_for_next_epoch / REFUND_FACTOR,
                automation_task_metadata.locked_fee_for_next_epoch);
            assert!(result, EDEPOSIT_REFUND);
            enumerable_map::remove_value(&mut automation_registry.tasks, task_index);
        } else { // it is safe not to check the state as above, the cancelled tasks are already rejected.
            // Active tasks will be refunded the deposited amount fully at the end of the epoch
            let automation_task_metadata_mut = enumerable_map::get_value_mut(
                &mut automation_registry.tasks,
                task_index
            );
            automation_task_metadata_mut.state = CANCELLED;
        };

        // This check means the task was expected to be executed in the next cycle, but it has been cancelled.
        // We need to remove its gas commitment from `gas_committed_for_next_epoch` for this particular task.
        if (automation_task_metadata.expiry_time > (cycle_info.start_time + cycle_info.duration_secs)) {
            assert!(
                automation_registry.gas_committed_for_next_epoch >= automation_task_metadata.max_gas_amount,
                EGAS_COMMITTEED_VALUE_UNDERFLOW
            );
            // Adjust the gas committed for the next epoch by subtracting the gas amount of the cancelled task
            automation_registry.gas_committed_for_next_epoch = automation_registry.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;
        };

        event::emit(TaskCancelled { task_index: automation_task_metadata.task_index, owner });
    }

    /// Immediately stops automation tasks for the specified `task_indexes`.
    /// Only tasks that exist and are owned by the sender can be stopped.
    /// If any of the specified tasks are not owned by the sender, the transaction will abort.
    /// When a task is stopped, the committed gas for the next epoch is reduced
    /// by the max gas amount of the stopped task. Half of the remaining task fee is refunded.
    public entry fun stop_tasks(
        owner_signer: &signer,
        task_indexes: vector<u64>
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationCycleDetails, AutomationRefundBookkeeping {
        assert!(features::supra_native_automation_enabled(), EDISABLED_AUTOMATION_FEATURE);
        let cycle_info = borrow_global<AutomationCycleDetails>(@supra_framework);
        assert!(cycle_info.state == CYCLE_STARTED, ECYCLE_TRANSITION_IN_PROGRESS);
        // Ensure that task indexes are provided
        assert!(!vector::is_empty(&task_indexes), EEMPTY_TASK_INDEXES);

        let owner = signer::address_of(owner_signer);
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let arc = borrow_global<ActiveAutomationRegistryConfig>(@supra_framework).main_config;
        let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(@supra_framework);

        let tcmg = automation_registry.gas_committed_for_this_epoch;

        // Compute the automation fee multiplier for epoch
        let automation_fee_per_sec = calculate_automation_fee_multiplier_for_epoch(&arc, tcmg, arc.registry_max_gas_cap);

        let stopped_task_details = vector[];
        let total_refund_fee = 0;
        let epoch_locked_fees = automation_registry.epoch_locked_fees;

        // Calculate refundable fee for this remaining time task in current epoch
        let current_time = timestamp::now_seconds();
        let cycle_end_time = cycle_info.duration_secs + cycle_info.start_time;
        let residual_interval = if (cycle_end_time <= current_time) {
            0
        } else {
            cycle_end_time - current_time
        };

        // Loop through each task index to validate and stop the task
        vector::for_each(task_indexes, |task_index| {
            if (enumerable_map::contains(&automation_registry.tasks, task_index)) {
                // Remove task from registry
                let task = enumerable_map::remove_value(&mut automation_registry.tasks, task_index);

                // Ensure only the task owner can stop it
                assert!(task.owner == owner, EUNAUTHORIZED_TASK_OWNER);

                vector::remove_value(&mut automation_registry.epoch_active_task_ids, &task_index);

                // This check means the task was expected to be executed in the next epoch, but it has been stopped.
                // We need to remove its gas commitment from `gas_committed_for_next_epoch` for this particular task.
                // Also it checks that task should not be cancelled.
                if (task.state != CANCELLED && task.expiry_time > cycle_end_time) {
                    // Prevent underflow in gas committed
                    assert!(
                        automation_registry.gas_committed_for_next_epoch >= task.max_gas_amount,
                        EGAS_COMMITTEED_VALUE_UNDERFLOW
                    );

                    // Reduce committed gas by the stopped task's max gas
                    automation_registry.gas_committed_for_next_epoch = automation_registry.gas_committed_for_next_epoch - task.max_gas_amount;
                };

                let (epoch_fee_refund, deposit_refund) = if (task.state != PENDING) {
                    let task_fee = calculate_task_fee(
                        &arc,
                        &task,
                        residual_interval,
                        current_time,
                        automation_fee_per_sec
                    );
                    // Refund full deposit and the half of the remaining run-time fee when task is active or cancelled stage
                    (task_fee / REFUND_FRACTION, task.locked_fee_for_next_epoch)
                } else {
                    (0, (task.locked_fee_for_next_epoch / REFUND_FRACTION))
                };
                let result = safe_unlock_locked_deposit(
                    refund_bookkeeping,
                    task.locked_fee_for_next_epoch,
                    task.task_index);
                assert!(result, EDEPOSIT_REFUND);
                let (result, remaining_epoch_locked_fees) = safe_unlock_locked_epoch_fee(
                    epoch_locked_fees,
                    epoch_fee_refund,
                    task.task_index);
                assert!(result, EEPOCH_FEE_REFUND);
                epoch_locked_fees = remaining_epoch_locked_fees;

                total_refund_fee = total_refund_fee + (epoch_fee_refund + deposit_refund);

                vector::push_back(
                    &mut stopped_task_details,
                    TaskStopped { task_index, deposit_refund, epoch_fee_refund }
                );
            }
        });

        // Refund and emit event if any tasks were stopped
        if (!vector::is_empty(&stopped_task_details)) {
            let resource_signer = account::create_signer_with_capability(
                &automation_registry.registry_fee_address_signer_cap
            );

            let resource_account_balance = coin::balance<SupraCoin>(automation_registry.registry_fee_address);
            assert!(resource_account_balance >= total_refund_fee, EINSUFFICIENT_BALANCE_FOR_REFUND);
            coin::transfer<SupraCoin>(&resource_signer, owner, total_refund_fee);

            // Emit task stopped event
            event::emit(TasksStopped {
                tasks: stopped_task_details,
                owner
            });
        };
    }

    // Public transition functions from version to version

    /// Public entry function to initialize bookeeping resource when feature enabling automation deposit fee charges is released.
    public fun initialize_refund_bookkeeping_resource(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        move_to(supra_framework, AutomationRefundBookkeeping {
            total_deposited_automation_fee: 0
        });
    }

    /// API to gracfully migrate from automation feature v1 inplementation to v2 where bookkeeping of the tasks is
    /// detached from epoch-change.
    /// IMPORTANT: Should alwasy be followed by supra_governance::reconfiguration otherwise registry/chain will
    /// end-up in inconsistent state.
    ///
    /// monitor_cycle_end (block_prologue->automation_registry::monitor_cycle_end) which will lead to panic and node will stop
    /// thus not causing any inconcistensy in the chain
    public fun migrate_v2(supra_framework: &signer, cycle_duration_secs: u64
    ) acquires AutomationRegistry, AutomationEpochInfo, ActiveAutomationRegistryConfig, AutomationCycleDetails {
        assert_supra_framework(supra_framework);
        assert!(!features::supra_automation_cycle_enabled(), EINVALID_MIGRATION_ACTION);

        // Prepare the state for migration
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let automation_epoch_info = borrow_global<AutomationEpochInfo>(@supra_framework);

        let automation_registry_config = borrow_global<ActiveAutomationRegistryConfig>(
            @supra_framework
        ).main_config;

        let current_time = timestamp::now_seconds();
        // Refund the epoch fees as epoch will be cut short and on_new_epoch will be dummy due to migration,
        // so this is the only place to do the refunds
        update_state_for_migration(
            automation_registry,
            &automation_registry_config,
            automation_epoch_info,
            current_time
        );

        // Start migration by enabling feature, initializing the cycle releated resouces
        features::change_feature_flags_for_next_epoch(
            supra_framework,
            vector[features::get_supra_automation_cycle_feature()],
            vector[]);
        let id = 0;
        move_to(supra_framework, AutomationCycleDetails {
            start_time: current_time,
            index: id,
            duration_secs: cycle_duration_secs,
            state: READY_TO_START_NEW_CYCLE,
            transition_state: std::option::none()
        });
        // Remain in READY_TO_START statey if feature is not enabled or registry is not fully initialized
        if (!is_feature_enabled_and_initialized()) {
            return
        };
        // Emit cycle end which will lead the native layer to start preparation to the new cycle.
        assert_automation_cycle_management_support();
        let cycle_info = borrow_global_mut<AutomationCycleDetails>(@supra_framework);
        on_cycle_end_internal(cycle_info)
    }

    // Public friend api

    /// Initialization of Automation Registry with configuration parameters is expected metrics.
    /// Deprecated in favor of initialize_v2
    public(friend) fun initialize(
        supra_framework: &signer,
        epoch_interval_secs: u64,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        automation_base_fee_in_quants_per_sec: u64,
        flat_registration_fee_in_quants: u64,
        congestion_threshold_percentage: u8,
        congestion_base_fee_in_quants_per_sec: u64,
        congestion_exponent: u8,
        task_capacity: u16,
    ) {
        assert!(false, EDEPRECATED_SINCE_V2);
    }

    /// Initialization of Automation Registry with configuration parameters for SUPRA_AUTOMATION_CYCLE version.
    /// Expected to have this function call either at genesis startup or as part of the SUPRA_FRAMEWORK upgrade where
    /// automation feature is being introduced very first time.
    /// In case if framework upgrade is happening on the chain where automation feature is already released and
    /// is in ongoing state, then migrate_v2 function should be utilized instead.
    public(friend) fun initialize_v2(
        supra_framework: &signer,
        cycle_duration_secs: u64,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        automation_base_fee_in_quants_per_sec: u64,
        flat_registration_fee_in_quants: u64,
        congestion_threshold_percentage: u8,
        congestion_base_fee_in_quants_per_sec: u64,
        congestion_exponent: u8,
        task_capacity: u16,
    ) {
        system_addresses::assert_supra_framework(supra_framework);
        validate_configuration_parameters_common(
            cycle_duration_secs,
            task_duration_cap_in_secs,
            registry_max_gas_cap,
            congestion_threshold_percentage,
            congestion_exponent);

        let (registry_fee_resource_signer, registry_fee_address_signer_cap) = create_registry_resource_account(
            supra_framework
        );

        move_to(supra_framework, AutomationRegistry {
            tasks: enumerable_map::new_map(),
            current_index: 0,
            gas_committed_for_next_epoch: 0,
            epoch_locked_fees: 0,
            gas_committed_for_this_epoch: 0,
            registry_fee_address: signer::address_of(&registry_fee_resource_signer),
            registry_fee_address_signer_cap,
            epoch_active_task_ids: vector[],
        });

        move_to(supra_framework, ActiveAutomationRegistryConfig {
            main_config: AutomationRegistryConfig {
                task_duration_cap_in_secs,
                registry_max_gas_cap,
                automation_base_fee_in_quants_per_sec,
                flat_registration_fee_in_quants,
                congestion_threshold_percentage,
                congestion_base_fee_in_quants_per_sec,
                congestion_exponent,
                task_capacity,
            },
            next_epoch_registry_max_gas_cap: registry_max_gas_cap,
            registration_enabled: true,
        });

        let (cycle_state, cycle_id) = if (features::supra_automation_cycle_enabled()) {
            (CYCLE_STARTED, 1)
        } else {
            (READY_TO_START_NEW_CYCLE, 0)
        };

        move_to(supra_framework, AutomationCycleDetails {
            start_time: timestamp::now_seconds(),
            index: cycle_id,
            duration_secs: cycle_duration_secs,
            state: cycle_state,
            transition_state: std::option::none<TransitionState>(),
        });

        initialize_refund_bookkeeping_resource(supra_framework);

    }

    /// Checks the cycle end and emit an event on it.
    /// Does nothig if SUPRA_NATIVE_AUTOMATION is disabled
    public(friend) fun monitor_cycle_end() acquires AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRegistry {
        if (!is_feature_enabled_and_initialized()) {
            return
        };
        assert_automation_cycle_management_support();
        let cycle_info = borrow_global_mut<AutomationCycleDetails>(@supra_framework);
        if (cycle_info.state != CYCLE_STARTED
            || cycle_info.start_time + cycle_info.duration_secs < timestamp::now_seconds()) {
            return
        };
        on_cycle_end_internal(cycle_info)
    }

    /// On new epoch caused by reconfiguration this function will be triggered and update the automation registry state.
    /// If registry is not fully initialized nothing is done. Epoch change can be caused by governance action or by DKG
    /// finalization. In case of the later case execution should not fail.
    ///
    /// If native automation feature is disabled then automation lifecycle is suspended. And detached managment will
    /// initiate refund and cealnup actions.
    ///
    /// If native automation feature is enabled and automation lifecycle has been in suspended state,
    /// then lifecycle is restarted.
    public(friend) fun on_new_epoch() acquires AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRegistry {
        if (!is_initialized()) {
            return
        };
        let cycle_info = borrow_global_mut<AutomationCycleDetails>(@supra_framework);
        let registry_data = borrow_global<AutomationRegistry>(@supra_framework);
        if (features::supra_native_automation_enabled()) {
            // If the lifecycle has been suspended and we are recovering from it, then we update config from buffer and
            // then start a new cycle directly.
            // Unless we are in READY_TO_START state feature flag being enabled will not have any effect.
            // All the other states mean that we are in the middle of previous transition, which should end
            // before reenabling the feature.
            if (cycle_info.state == READY_TO_START_NEW_CYCLE) {
                if (enumerable_map::length(&registry_data.tasks) != 0) {
                    event::emit(ErrorInconsistentSuspendedState {});
                    return
                };
                update_config_from_buffer(cycle_info);
                move_to_started_state(cycle_info);
            };
            return
        };
        // We do not update config here, as due to feature being disabled, cycle ends early so it is expected
        // that native layer will detect this state and generate refund transactions for a cycle that has been kept short.
        // So the confing should remain intact.
        if (cycle_info.state == CYCLE_STARTED) {
            move_to_suspended_state(registry_data, cycle_info);
        } else if (cycle_info.state == CYCLE_FINISHED && std::option::is_some(&cycle_info.transition_state)) {
            let trasition_state = std::option::borrow(&cycle_info.transition_state);
            if (!is_transition_in_progress(trasition_state)) {
                // Just entered cycle-end phase, and meanwhile also feature has been disabled so it is safe to move to suspended state.
                move_to_suspended_state(registry_data, cycle_info);
            }
            // Otherwise wait of the cycle transition to end and then feature flag value will be taken into account.
        }
        // If in already SUSPENED state or in READY state then do nothing.
    }

    /// Update epoch interval in registry while actually update happens in block module
    /// Deprecated since SUPRA_AUTOMATION_CYCLE feature release in favor of monitor_cycle_end
    public(friend) fun update_epoch_interval_in_registry(_epoch_interval_microsecs: u64) {
        assert!(false, EDEPRECATED_SINCE_V2);
    }

    // Private Native VM referenced api

    /// Registers a new automation task entry.
    fun register(
        owner_signer: &signer,
        payload_tx: vector<u8>,
        expiry_time: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
        automation_fee_cap_for_epoch: u64,
        tx_hash: vector<u8>,
        aux_data: vector<vector<u8>>
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        // Guarding registration if feature is not enabled.
        assert!(features::supra_native_automation_enabled(), EDISABLED_AUTOMATION_FEATURE);
        assert!(vector::is_empty(&aux_data), ENO_AUX_DATA_SUPPORTED);

        let automation_registry_config = borrow_global<ActiveAutomationRegistryConfig>(@supra_framework);
        let automation_cycle_info = borrow_global<AutomationCycleDetails>(@supra_framework);
        assert!(automation_registry_config.registration_enabled, ETASK_REGISTRATION_DISABLED);
        assert!(automation_cycle_info.state == CYCLE_STARTED, ECYCLE_TRANSITION_IN_PROGRESS);

        // If registry is full, reject task registration
        assert!((get_task_count() as u16) < automation_registry_config.main_config.task_capacity, EREGISTRY_IS_FULL);

        let owner = signer::address_of(owner_signer);
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);

        //Well-formedness check of payload_tx is done in native layer beforehand.

        let registration_time = timestamp::now_seconds();
        check_registration_task_duration(
            expiry_time,
            registration_time,
            &automation_registry_config.main_config,
            automation_cycle_info
        );

        assert!(gas_price_cap > 0, EINVALID_GAS_PRICE);
        assert!(max_gas_amount > 0, EINVALID_MAX_GAS_AMOUNT);
        assert!(vector::length(&tx_hash) == TXN_HASH_LENGTH, EINVALID_TXN_HASH);

        let committed_gas = (automation_registry.gas_committed_for_next_epoch as u128) + (max_gas_amount as u128);
        assert!(committed_gas <= MAX_U64, EGAS_COMMITTEED_VALUE_OVERFLOW);

        let committed_gas = (committed_gas as u64);
        assert!(committed_gas <= automation_registry_config.next_epoch_registry_max_gas_cap, EGAS_AMOUNT_UPPER);

        // Check the automation fee capacity
        let estimated_automation_fee_for_epoch = estimate_automation_fee_with_committed_occupancy_internal(
            max_gas_amount,
            automation_registry.gas_committed_for_next_epoch,
            automation_cycle_info.duration_secs,
            automation_registry_config);
        assert!(automation_fee_cap_for_epoch >= estimated_automation_fee_for_epoch,
            EINSUFFICIENT_AUTOMATION_FEE_CAP_FOR_EPOCH
        );

        automation_registry.gas_committed_for_next_epoch = committed_gas;
        let task_index = automation_registry.current_index;

        let automation_task_metadata = AutomationTaskMetaData {
            task_index,
            owner,
            payload_tx,
            expiry_time,
            max_gas_amount,
            gas_price_cap,
            automation_fee_cap_for_epoch,
            aux_data,
            state: PENDING,
            registration_time,
            tx_hash,
            locked_fee_for_next_epoch: automation_fee_cap_for_epoch
        };

        enumerable_map::add_value(&mut automation_registry.tasks, task_index, automation_task_metadata);
        automation_registry.current_index = automation_registry.current_index + 1;

        // Charge flat registration fee from the user at the time of registration and deposit for automation_fee for epoch.
        let fee = automation_registry_config.main_config.flat_registration_fee_in_quants + automation_fee_cap_for_epoch;

        let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(@supra_framework);
        refund_bookkeeping.total_deposited_automation_fee = refund_bookkeeping.total_deposited_automation_fee + automation_fee_cap_for_epoch;

        coin::transfer<SupraCoin>(owner_signer, automation_registry.registry_fee_address, fee);

        event::emit(TaskRegistrationDepositFeeWithdraw {
            task_index,
            owner,
            registration_fee: automation_registry_config.main_config.flat_registration_fee_in_quants ,
            locked_deposit_fee: automation_fee_cap_for_epoch
        });
        event::emit(automation_task_metadata);
    }

    /// Called by MoveVm on `AutomationBookkeepingAction::Drop` action emitted by native layer ahead of cycle transition
    fun on_drop(vm: signer, task_indexes: vector<u64> ) acquires AutomationCycleDetails, AutomationRegistry, AutomationRefundBookkeeping {
        // Operational constraint: can only be invoked by the VM
        system_addresses::assert_vm(&vm);
        if (vector::is_empty(&task_indexes)) {
            return
        };

        let cycle_info = borrow_global_mut<AutomationCycleDetails>(@supra_framework);
        assert!(cycle_info.state == CYCLE_FINISHED, EINVALID_REGISTRY_STATE);
        assert!(std::option::is_some(&cycle_info.transition_state), EINVALID_REGISTRY_STATE);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(@supra_framework);
        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );

        let removed_tasks = vector[];
        vector::for_each(task_indexes, |task_index| {
            if (enumerable_map::contains(&automation_registry.tasks, task_index)) {
                let task = enumerable_map::remove_value(&mut automation_registry.tasks, task_index);

                safe_deposit_refund(
                    refund_bookkeeping,
                    &resource_signer,
                    automation_registry.registry_fee_address,
                    task_index,
                    task.owner,
                    task.locked_fee_for_next_epoch,
                    task.locked_fee_for_next_epoch);
                vector::push_back(&mut removed_tasks, task_index);
            };
        });

        update_cycle_transition_state_from_finished(automation_registry, cycle_info, removed_tasks);
        event::emit(RemovedTasks {
            task_indexes: removed_tasks
        });

    }

    /// Called by MoveVm on `AutomationBookkeepingAction::Charge` action emitted by native layer ahead of cycle transition
    fun on_charge(vm: signer, automation_fee_per_sec: u64, task_indexes: vector<u64>, gas_committed_for_new_cycle: u64)
    acquires AutomationCycleDetails, AutomationRefundBookkeeping, AutomationRegistry, ActiveAutomationRegistryConfig {
        // Operational constraint: can only be invoked by the VM
        system_addresses::assert_vm(&vm);

        if (vector::is_empty(&task_indexes)) {
            return
        };

        let cycle_info = borrow_global_mut<AutomationCycleDetails>(@supra_framework);
        assert!(cycle_info.state == CYCLE_FINISHED, EINVALID_REGISTRY_STATE);
        assert!(std::option::is_some(&cycle_info.transition_state), EINVALID_REGISTRY_STATE);

        let transition_state = std::option::borrow_mut(&mut cycle_info.transition_state);
        if (transition_state.gas_committed_for_this_cycle == 0) {
            transition_state.gas_committed_for_this_cycle = gas_committed_for_new_cycle;
            transition_state.automation_fee_per_sec = automation_fee_per_sec;
        } else {
            assert!(transition_state.gas_committed_for_this_cycle == gas_committed_for_new_cycle, EINVALID_CHARGE_ACTION);
            assert!(transition_state.automation_fee_per_sec == automation_fee_per_sec, EINVALID_CHARGE_ACTION);
        };

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(@supra_framework);
        let automation_registry_config = borrow_global<ActiveAutomationRegistryConfig>(@supra_framework);
        let intermedate_result = IntermediateStateOfEpochChange {
            removed_tasks: vector[],
            gas_committed_for_new_epoch: gas_committed_for_new_cycle,
            gas_committed_for_next_epoch: 0,
            epoch_locked_fees: coin::zero()
        };

        let processed_tasks = try_charge_tasks_automation_fees(
            automation_registry,
            refund_bookkeeping,
            &automation_registry_config.main_config,
            (automation_fee_per_sec as u256),
        transition_state.new_cycle_duration,
        timestamp::now_seconds(),
            task_indexes,
            &mut intermedate_result
        );
        let IntermediateStateOfEpochChange {
            removed_tasks,
            gas_committed_for_new_epoch,
            gas_committed_for_next_epoch,
            epoch_locked_fees
        } = intermedate_result;

        transition_state.locked_fees = transition_state.locked_fees + coin::value(&epoch_locked_fees);
        transition_state.gas_committed_for_next_cycle = transition_state.gas_committed_for_next_cycle + gas_committed_for_next_epoch;
        coin::deposit(automation_registry.registry_fee_address, epoch_locked_fees);

        update_cycle_transition_state_from_finished(automation_registry, cycle_info, processed_tasks);

        if (!vector::is_empty(&removed_tasks)) {
            event::emit(RemovedTasks{
                task_indexes: removed_tasks
            })
        }
    }

    /// Called by MoveVm on `AutomationBookkeepingAction::RefundAndCleanup` action.
    /// Action from native layer will be tiggered by move layer when automation registy cycle is updated to SUSPENDED.
    fun on_refund_and_cleanup(vm: signer, duration: u64, automation_fee_per_sec: u64, task_indexes: vector<u64> )
    acquires AutomationCycleDetails, AutomationRefundBookkeeping, AutomationRegistry, ActiveAutomationRegistryConfig {
        // Operational constraint: can only be invoked by the VM
        system_addresses::assert_vm(&vm);

        if (vector::is_empty(&task_indexes)) {
            return
        };

        let cycle_info = borrow_global_mut<AutomationCycleDetails>(@supra_framework);
        assert!(cycle_info.state == CYCLE_SUSPENDED, EINVALID_REGISTRY_STATE);
        assert!(std::option::is_some(&cycle_info.transition_state), EINVALID_REGISTRY_STATE);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(@supra_framework);
        let arc = borrow_global_mut<ActiveAutomationRegistryConfig>(@supra_framework);
        let current_time = timestamp::now_seconds();

        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        let removed_tasks = vector[];
        let epoch_locked_fees = automation_registry.epoch_locked_fees;
        vector::for_each(task_indexes, |task_index| {
            if (enumerable_map::contains(&automation_registry.tasks, task_index)) {
                let task = enumerable_map::remove_value(&mut automation_registry.tasks, task_index);

                if (task.state != PENDING) {
                    let refund = calculate_task_fee(
                        &arc.main_config,
                        &task,
                        duration,
                        current_time,
                        (automation_fee_per_sec as u256));
                    let (_, remaining_epoch_locked_fees) = safe_fee_refund(
                        epoch_locked_fees,
                        &resource_signer,
                        automation_registry.registry_fee_address,
                        task.task_index,
                        task.owner,
                        refund);
                    epoch_locked_fees = remaining_epoch_locked_fees;
                };

                safe_deposit_refund(
                    refund_bookkeeping,
                    &resource_signer,
                    automation_registry.registry_fee_address,
                    task.task_index,
                    task.owner,
                    task.locked_fee_for_next_epoch,
                    task.locked_fee_for_next_epoch);
                vector::push_back(&mut removed_tasks, task_index);
            };
        });

        update_cycle_transition_state_from_suspended(automation_registry, cycle_info, removed_tasks);
        event::emit(RemovedTasks {
            task_indexes: removed_tasks
        });
    }

    // Private helper functions

    fun into_automation_cycle_info(details: &AutomationCycleDetails): AutomationCycleInfo {
        AutomationCycleInfo {
            index: details.index,
            state: details.state,
            start_time: details.start_time,
            duration_secs: details.duration_secs
        }
    }

    /// Updates the transition state with newly processed tasks and if transition is identified to be finalized, then
    /// moves to the next state.
    /// As transition happens from suspended state and while transition was in progress the feature was enabled back,
    /// then the transition will happend direclty to starated state, otherwise the transition will be done to the ready state.
    /// In both cases config will be updated. In this case we will make sure to keep the consistency of state when transition to ready state happens
    /// through path Started -> Suspended -> Ready or Started-> {Finished, Suspended} -> Ready or Started -> Finished -> {Started, Suspended}
    fun update_cycle_transition_state_from_suspended(
        automation_registry: &mut AutomationRegistry,
        cycle_info: &mut AutomationCycleDetails,
        processed_tasks: vector<u64>) acquires  ActiveAutomationRegistryConfig  {
        assert!(std::option::is_some(&cycle_info.transition_state), EINVALID_REGISTRY_STATE);
        let transition_state = std::option::borrow_mut(&mut cycle_info.transition_state);
        update_processed_tasks(transition_state, processed_tasks);

        if (!is_transition_finalized(transition_state)) {
            return
        };
        automation_registry.gas_committed_for_next_epoch = 0;
        automation_registry.gas_committed_for_this_epoch = 0;
        automation_registry.epoch_active_task_ids = vector[];
        automation_registry.epoch_locked_fees = 0;

        update_config_from_buffer(cycle_info);
        if (features::supra_native_automation_enabled()) {
            move_to_started_state(cycle_info)
        } else {
            move_to_ready_state(cycle_info)
        }
    }

    /// Updates the transition state with newly processed tasks and if transition is identified to be finalized, then
    /// moves to the next state.
    /// First it moves to the next cycle. But if happened so that there was a suspension during cycle transition which was ignored,
    /// then immediately cycle state is updated to suspended.
    /// Expectation will be that native layer catches this double transition and will issue refunds for the new cycle
    /// which will not proceeded farther in any case.
    fun update_cycle_transition_state_from_finished(
        automation_registry: &mut AutomationRegistry,
        cycle_info: &mut AutomationCycleDetails,
        processed_tasks: vector<u64>
    ) {
        assert!(std::option::is_some(&cycle_info.transition_state), EINVALID_REGISTRY_STATE);

        let transition_state = std::option::borrow_mut(&mut cycle_info.transition_state);
        // TODO maybe do this via native function where duplicates will be avoided
        update_processed_tasks(transition_state, processed_tasks);
        let transition_finalized = is_transition_finalized(transition_state);

        if (transition_finalized) {
            on_cycle_start_internal(automation_registry, cycle_info);
        };
        if (transition_finalized  && !features::supra_native_automation_enabled()) {
            move_to_suspended_state(automation_registry, cycle_info)
        }
    }

    /// Estimates automation fee the next epoch for specified task occupancy for the configured epoch-interval
    /// referencing the current automation registry fee parameters, specified total/committed occupancy and registry
    /// maximum allowed occupancy for the next epoch.
    /// Note it is expected that committed_occupancy does not include currnet task's occupancy.
    fun estimate_automation_fee_with_committed_occupancy_internal(
        task_occupancy: u64,
        committed_occupancy: u64,
        duration: u64,
        active_config: &ActiveAutomationRegistryConfig
    ): u64 {
        let total_committed_max_gas = committed_occupancy + task_occupancy;

        // Compute the automation fee multiplier for epoch
        let automation_fee_per_sec = calculate_automation_fee_multiplier_for_epoch(
            &active_config.main_config,
            (total_committed_max_gas as u256),
            active_config.next_epoch_registry_max_gas_cap);

        if (automation_fee_per_sec == 0) {
            return 0
        };

        calculate_automation_fee_for_interval(
            duration,
            task_occupancy,
            automation_fee_per_sec,
            active_config.next_epoch_registry_max_gas_cap)
    }

    fun validate_configuration_parameters_common(
        cycle_duration_secs: u64,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        congestion_threshold_percentage: u8,
        congestion_exponent: u8,
    ) {
        assert!(congestion_threshold_percentage <= MAX_PERCENTAGE, EMAX_CONGESTION_THRESHOLD);
        assert!(congestion_exponent > 0, ECONGESTION_EXP_NON_ZERO);
        assert!(task_duration_cap_in_secs > cycle_duration_secs, EUNACCEPTABLE_TASK_DURATION_CAP);
        assert!(registry_max_gas_cap > 0, EREGISTRY_MAX_GAS_CAP_NON_ZERO);
    }

    fun create_registry_resource_account(supra_framework: &signer): (signer, SignerCapability) {
        let (registry_fee_resource_signer, registry_fee_address_signer_cap) = account::create_resource_account(
            supra_framework,
            REGISTRY_RESOURCE_SEED
        );
        coin::register<SupraCoin>(&registry_fee_resource_signer);
        (registry_fee_resource_signer, registry_fee_address_signer_cap)
    }

    fun on_cycle_start_internal(
        automation_registry: &mut AutomationRegistry,
        cycle_info: &mut AutomationCycleDetails
    ) {
        // Indicates that moving to cycle start from transition state.
        assert!(std::option::is_some(&cycle_info.transition_state), EINVALID_REGISTRY_STATE);
        let transition_state = std::option::borrow_mut(&mut cycle_info.transition_state);

        automation_registry.gas_committed_for_next_epoch = transition_state.gas_committed_for_next_cycle;
        automation_registry.gas_committed_for_this_epoch = (transition_state.gas_committed_for_this_cycle as u256);
        automation_registry.epoch_active_task_ids = enumerable_map::get_map_list(&automation_registry.tasks);
        automation_registry.epoch_locked_fees = transition_state.locked_fees;

        // Set current timestamp as cycle start_time
        // Increase cycle and update the state to Started
        move_to_started_state(cycle_info);
        if (!vector::is_empty(&automation_registry.epoch_active_task_ids)) {
            event::emit(ActiveTasks {
                task_indexes: automation_registry.epoch_active_task_ids
            });
        }
    }

    fun on_cycle_end_internal(cycle_info: &mut AutomationCycleDetails) acquires ActiveAutomationRegistryConfig, AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        let transition_state = TransitionState {
            new_cycle_duration: cycle_info.duration_secs,
            automation_fee_per_sec: 0,
            gas_committed_for_this_cycle: 0,
            gas_committed_for_next_cycle: 0,
            locked_fees: 0,
            expected_tasks_to_be_processed: enumerable_map::get_map_list(&automation_registry.tasks),
            actual_processed_tasks: vector[]
        };
        cycle_info.transition_state = std::option::some(transition_state);
        update_cycle_state_to(cycle_info, CYCLE_FINISHED);
        // During cycle transition we update config only after transition state is created in order to have new cycle
        // duration as transition parameter.
        update_config_from_buffer(cycle_info);
    }

    fun update_cycle_state_to(cycle_info: &mut AutomationCycleDetails, state: u8) {
        let old_state = cycle_info.state;
        cycle_info.state = state;
        let event = AutomationCycleEvent {
            cycle_state_info: into_automation_cycle_info(cycle_info),
            old_state,
            event_time: timestamp::now_seconds(),
        };
        event::emit(event)
    }

    fun move_to_ready_state(cycle_info: &mut AutomationCycleDetails) {
        cycle_info.transition_state = std::option::none<TransitionState>();
        update_cycle_state_to(cycle_info, READY_TO_START_NEW_CYCLE)
    }

    fun move_to_started_state(cycle_info: &mut AutomationCycleDetails) {
        cycle_info.index = cycle_info.index + 1;
        cycle_info.start_time = timestamp::now_seconds();
        if (std::option::is_some(&cycle_info.transition_state)) {
            let transition_state = std::option::extract(&mut cycle_info.transition_state);
            cycle_info.duration_secs = transition_state.new_cycle_duration;
        };
        update_cycle_state_to(cycle_info, CYCLE_STARTED)
    }

    /// Transition to suspended state is expected
    ///   a) when cycle is active and in progress
    ///     - here we do simply move to suspended state so native layer can start requesting refunds and cleanup actions
    ///   b) when cycle has just finished and there was another transaction causing feature suspension
    ///     - as this both events happen in scope of the same block, then we will simply update the state to suspended
    ///       and the native layer should identify this and request refund and cleanup with 0 fee and 0 duration,
    ///       which will lead to simply deposit refund and cleanup.
    ///   c) when cycle transition was in progress and there was a feature suspension, but it could not be applied,
    ///      and postponed till the cycle transition concluded
    fun move_to_suspended_state(automation_registry: &AutomationRegistry, cycle_info: &mut AutomationCycleDetails) {
        if (std::option::is_none(&cycle_info.transition_state)) {
            let transition_state = TransitionState {
                new_cycle_duration: cycle_info.duration_secs,
                automation_fee_per_sec: 0,
                gas_committed_for_this_cycle: 0,
                gas_committed_for_next_cycle: 0,
                locked_fees: 0,
                expected_tasks_to_be_processed: enumerable_map::get_map_list(&automation_registry.tasks),
                actual_processed_tasks: vector[]
            };
            cycle_info.transition_state = std::option::some(transition_state);
        };
        update_cycle_state_to(cycle_info, CYCLE_SUSPENDED)
    }

    /// Checks all tasks for epoch fee refunds.
    fun update_state_for_migration(
        automation_registry: &mut AutomationRegistry,
        arc: &AutomationRegistryConfig,
        aei: &AutomationEpochInfo,
        current_time: u64
    ) {
        let previous_epoch_duration = current_time - aei.start_time;
        let refund_interval = 0;
        let refund_automation_fee_per_sec = 0;

        // If epoch actual duration is greater or equal to expected epoch-duration then there is nothing to refund.
        if (automation_registry.epoch_locked_fees != 0 && previous_epoch_duration < aei.expected_epoch_duration) {
            let previous_tcmg = automation_registry.gas_committed_for_this_epoch;
            refund_interval = aei.expected_epoch_duration - previous_epoch_duration;
            // Compute the automation fee multiplier for ended epoch
            refund_automation_fee_per_sec = calculate_automation_fee_multiplier_for_epoch(arc, previous_tcmg, arc.registry_max_gas_cap);
        };
        refund_fee(automation_registry, arc, refund_automation_fee_per_sec, refund_interval, current_time);

        automation_registry.gas_committed_for_next_epoch = 0;
        automation_registry.epoch_locked_fees = 0;
        automation_registry.gas_committed_for_this_epoch = 0;
    }

    fun refund_fee(
        automation_registry: &AutomationRegistry,
        arc: &AutomationRegistryConfig,
        refund_automation_fee_per_sec: u256,
        refund_interval: u64,
        current_time: u64)
    {
        if (refund_automation_fee_per_sec == 0) {
            return
        };
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);

        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        let epoch_locked_fees = automation_registry.epoch_locked_fees;

        vector::for_each(ids, |task_index| {
            let task = enumerable_map::get_value_ref(&automation_registry.tasks, task_index);
            if (task.state != PENDING) {
                let refund = calculate_task_fee(
                    arc,
                    task,
                    refund_interval,
                    current_time,
                    refund_automation_fee_per_sec);
                let (_, remaining_epoch_locked_fees) = safe_fee_refund(
                    epoch_locked_fees,
                    &resource_signer,
                    automation_registry.registry_fee_address,
                    task.task_index,
                    task.owner,
                    refund);
                epoch_locked_fees = remaining_epoch_locked_fees;
            };
        });
    }

    /// Traverses through all existing tasks and refunds deposited fee upon registration fully.
    fun safe_deposit_refund_all(
        automation_registry: &AutomationRegistry,
        refund_bookkeeping: &mut AutomationRefundBookkeeping) {
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);

        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        vector::for_each(ids, |task_index| {
            let task = enumerable_map::get_value_ref(&automation_registry.tasks, task_index);

            safe_deposit_refund(
                refund_bookkeeping,
                &resource_signer,
                automation_registry.registry_fee_address,
                task.task_index,
                task.owner,
                task.locked_fee_for_next_epoch,
                task.locked_fee_for_next_epoch);
        });
    }

    /// Refunds specified amount of deposit to the task owner and unlocks full deposit from registry resource account.
    /// Error events are emitted
    ///   - if the registry resource account does not have enough balance for refund.
    ///   - if the full deposit can not be unlocked.
    fun safe_deposit_refund(
        rb: &mut AutomationRefundBookkeeping,
        resource_signer: &signer,
        resource_address: address,
        task_index: u64,
        task_owner: address,
        refundable_deposit: u64,
        locked_deposit: u64
    ):  bool {
        // This check will make sure that no more than totally locked deposited will be refunded.
        // If there is an attempt then it means implementation bug.
        let result = safe_unlock_locked_deposit(rb, locked_deposit, task_index);
        if (!result) {
            return result
        };

        let result = safe_refund(
            resource_signer,
            resource_address,
            task_index,
            task_owner,
            refundable_deposit,
            DEPOSIT_EPOCH_FEE);

        if (result) {
            event::emit(
                TaskDepositFeeRefund { task_index, owner: task_owner, amount: refundable_deposit }
            );
        };
        result
    }

    /// Unlocks the deposit paid by the task from internal deposit refund bookkeeping state.
    /// Error event is emitted if the deposit refund bookkeeping state is inconsistent with the requested unlock amount.
    fun safe_unlock_locked_deposit(
        rb: &mut AutomationRefundBookkeeping,
        locked_deposit: u64,
        task_index: u64
    ): bool {
        let has_locked_deposit = rb.total_deposited_automation_fee >= locked_deposit;
        if (has_locked_deposit) {
            rb.total_deposited_automation_fee = rb.total_deposited_automation_fee - locked_deposit;
        } else {
            event::emit(
                ErrorUnlockTaskDepositFee { total_registered_deposit: rb.total_deposited_automation_fee, locked_deposit, task_index }
            );
        };
        has_locked_deposit
    }

    /// Unlocks the locked fee paid by the task for epoch.
    /// Error event is emitted if the epoch locked fee amount is inconsistent with the requested unlock amount.
    fun safe_unlock_locked_epoch_fee(
        epoch_locked_fees: u64,
        refundable_fee: u64,
        task_index: u64
    ): (bool, u64) {
        // This check makes sure that more than locked amount of the fees will be not be refunded.
        // Any attempt means internal bug.
        let has_locked_fee = epoch_locked_fees >= refundable_fee;
        if (has_locked_fee) {
            // unlock the refunded amount
            epoch_locked_fees = epoch_locked_fees - refundable_fee;
        } else {
            event::emit(
                ErrorUnlockTaskEpochFee { locked_epoch_fees: epoch_locked_fees, task_index, refund: refundable_fee}
            );
        };
        (has_locked_fee, epoch_locked_fees)
    }

    /// Refunds fee paid by the task for the epoch to the task owner.
    /// Note that here we do not unlock the fee, as on epoch change locked epoch-fees for the ended epoch are
    /// automatically unlocked.
    fun safe_fee_refund(
        epoch_locked_fees: u64,
        resource_signer: &signer,
        resource_address: address,
        task_index: u64,
        task_owner: address,
        refundable_fee: u64
    ):  (bool, u64) {
        let (result, remaining_locked_fees) = safe_unlock_locked_epoch_fee(epoch_locked_fees, refundable_fee, task_index);
        if (!result) {
            return (result, remaining_locked_fees)
        };
        let result = safe_refund(
            resource_signer,
            resource_address,
            task_index,
            task_owner,
            refundable_fee,
            EPOCH_FEE);
        if (result) {
            event::emit(
                TaskFeeRefund { task_index, owner: task_owner, amount: refundable_fee }
            );
        };
        (result, remaining_locked_fees)
    }

    /// Refunds specified amount to the task owner.
    /// Error event is emitted if the resource account does not have enough balance.
    fun safe_refund(
        resource_signer: &signer,
        resource_address: address,
        task_index: u64,
        task_owner: address,
        refundable_amount: u64,
        refund_type: u8
    ):  bool {
        let balance = coin::balance<SupraCoin>(resource_address);
        if (balance < refundable_amount) {
            event::emit(
                ErrorInsufficientBalanceToRefund { refund_type, task_index, owner: task_owner, amount: refundable_amount }
            );
            return false
        };

        coin::transfer<SupraCoin>(resource_signer, task_owner, refundable_amount);
        return true
    }


    /// Calculates automation task fees for a single task at the time of new epoch.
    /// This is supposed to be called only after removing expired task and must not be called for expired task.
    /// It returns calculated task fee for the interval the task will be active.
    fun calculate_task_fee(
        arc: &AutomationRegistryConfig,
        task: &AutomationTaskMetaData,
        potential_fee_timeframe: u64,
        current_time: u64,
        automation_fee_per_sec: u256
    ): u64 {
        if (automation_fee_per_sec == 0) { return 0 };
        if (task.expiry_time <= current_time) { return 0 };
        // Subtraction is safe here, as we already excluded expired tasks
        let task_active_timeframe = task.expiry_time - current_time;
        // If the task is a new task i.e. in Pending state, then it is charged always for
        // the input potential_fee_timeframe(which is epoch-interval),
        // For the new tasks which active-timeframe is less than epoch-interval
        // it would mean it is their first and only epoch and we charge the fee for entire epoch.
        // Note that although the new short tasks are charged for entire epoch, the refunding logic remains the same for
        // them as for the long tasks.
        // This way bad-actors will be discourged to submit small and short tasks with big occupancy by blocking other
        // good-actors register tasks.
        let actual_fee_timeframe = if (task.state == PENDING) {
            potential_fee_timeframe
        } else {
            math64::min(task_active_timeframe, potential_fee_timeframe)
        };
        calculate_automation_fee_for_interval(
            actual_fee_timeframe,
            task.max_gas_amount,
            automation_fee_per_sec,
            arc.registry_max_gas_cap)
    }

    /// Calculates automation task fees for a single task at the time of new epoch.
    /// This is supposed to be called only after removing expired task and must not be called for expired task.
    fun calculate_automation_fee_for_interval(
        interval: u64,
        task_occupancy: u64,
        automation_fee_per_sec: u256,
        registry_max_gas_cap: u64,
    ): u64 {
        let max_gas_cap = (registry_max_gas_cap as u256);
        let duration = (interval as u256);
        let task_occupancy_ratio_by_duration = (duration * upscale_from_u64(task_occupancy)) / max_gas_cap;

        let automation_fee_for_interval = automation_fee_per_sec * task_occupancy_ratio_by_duration;

        downscale_to_u64(automation_fee_for_interval)
    }

    /// Calculate automation fee multiplier for epoch. It is measured in quants/sec.
    fun calculate_automation_fee_multiplier_for_epoch(
        arc: &AutomationRegistryConfig,
        tcmg: u256,
        registry_max_gas_cap: u64
    ): u256 {
        let acf = calculate_automation_congestion_fee(arc, tcmg, registry_max_gas_cap);
        acf + (arc.automation_base_fee_in_quants_per_sec as u256)
    }

    /// Calculate automation congestion fee for the epoch
    fun calculate_automation_congestion_fee(
        arc: &AutomationRegistryConfig,
        tcmg: u256,
        registry_max_gas_cap: u64
    ): u256 {
        if (arc.congestion_threshold_percentage == MAX_PERCENTAGE || arc.congestion_base_fee_in_quants_per_sec == 0) {
            return 0
        };

        let max_gas_cap = (registry_max_gas_cap as u256);
        let threshold_percentage = upscale_from_u8(arc.congestion_threshold_percentage);

        // Calculate congestion threshold surplus for the current epoch
        let threshold_usage = upscale_from_u256(tcmg) * 100 / max_gas_cap;
        if (threshold_usage <= threshold_percentage) 0
        else {
            let threshold_surplus_normalized = (threshold_usage - threshold_percentage) / 100;

            // Ensure threshold + threshold_surplus does not exceeds 1 (1 in scaled terms)
            let threshold_percentage_scaled = threshold_percentage / 100;
            let threshold_surplus_clip = if ((threshold_surplus_normalized + threshold_percentage_scaled) > DECIMAL) {
                DECIMAL - threshold_percentage_scaled
            } else {
                threshold_surplus_normalized
            };
            // Compute the automation congestion fee (acf) for the epoch
            let threshold_surplus_exponential = calculate_exponentiation(
                threshold_surplus_clip,
                arc.congestion_exponent
            );

            // Calculate acf by multiplying base fee with exponential result
            let acf = (arc.congestion_base_fee_in_quants_per_sec as u256) * threshold_surplus_exponential;
            downscale_to_u256(acf)
        }
    }

    /// Calculates (1 + base)^exponent, where `base` is represented with `DECIMAL` decimal places.
    /// For example, if `base` is 0.5, it should be passed as 0.5 * DECIMAL (i.e., 50000000).
    /// The result is returned as an integer with `DECIMAL` decimal places.
    /// It will return the result of (((1 + base)^exponent) - 1), scaled by `DECIMAL` (e.g., 103906250 for 1.0390625).
    /// The reason for using `(1 + base)^exponent` is that `base` would be the fraction by which the congestion threshold is crossed,
    ///     thus highly likely to be less than one. To ensure that as `exponent` increases, the function increases, `1` is added.
    ///     In the final result, after `(1 + base)^exponent` is calculated, `1` is subtracted so as not to subsume the automation
    ///     base fee in this component. This would allow the freedom to set a multiplier for the automation base fee separately
    ///     from the congestion fee.
    /// `exponent` here acts as the degree of the polynomial, therefore an `exponent` of `2` or higher
    ///     would allow the congestion fee to increase in a non-linear fashion.
    fun calculate_exponentiation(base: u256, exponent: u8): u256 {
        // Add 1 (represented as DECIMAL) to the base
        let one_scaled = DECIMAL; // 1.0 in DECIMAL representation
        let adjusted_base = base + one_scaled; // (1 + base) in DECIMAL representation

        // Initialize result as 1 (represented in DECIMAL)
        let result = one_scaled;

        // Perform exponential calculation using integer arithmetic
        let i = 0;
        while (i < exponent) {
            result = result * adjusted_base / DECIMAL; // Adjust for decimal places
            i = i + 1;
        };

        // Subtract the initial added 1 (DECIMAL) to get the final result
        result - one_scaled
    }

    /// Processes automation task fees by checking user balances and task's commitment on automation-fee, i.e. automation-fee-cap
    /// - If the user has sufficient balance, deducts the fee and emits a success event.
    /// - If the balance is insufficient, removes the task and emits a cancellation event.
    /// - If calculated fee for the epoch surpasses task's automation-fee-cap task is removed and cancellation event is emitted.
    /// Return estimated committed gas for the next epoch, locked automation fee amount for this epoch, and list of active task indexes
    fun try_charge_tasks_automation_fees(
        automation_registry: &mut AutomationRegistry,
        refund_bookkeeping: &mut AutomationRefundBookkeeping,
        arc: &AutomationRegistryConfig,
        automation_fee_per_sec: u256,
        cycle_duration: u64,
        current_time: u64,
        task_ids: vector<u64>,
        intermediate_state: &mut IntermediateStateOfEpochChange,
    ): vector<u64> {
        let processed_tasks = vector[];

        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        let current_cycle_end_time = current_time + cycle_duration;

        // Sort task indexes to charge automation fees in the tasks chronological order
        sort_vector(&mut task_ids);

        // Process each active task and calculate fee for the epoch for the tasks
        vector::for_each(task_ids, |task_index| {
            if (enumerable_map::contains(&automation_registry.tasks, task_index)) {
                vector::push_back(&mut processed_tasks, task_index);
                let task = {
                    let task_meta = enumerable_map::get_value_mut(&mut automation_registry.tasks, task_index);
                    let fee= calculate_task_fee(arc, task_meta, cycle_duration, current_time, automation_fee_per_sec);
                    // If the task reached this phase that means it is valid active task for the new epoch.
                    // During cleanup all expired tasks has been removed from the registry but the state of the tasks is not updated.
                    // As here we need to distinguish new tasks from already existing active tasks,
                    // as the fee calculation for them will be different based on their active duration in the epoch.
                    // For more details see calculate_task_fee function.
                    task_meta.state = ACTIVE;
                    AutomationTaskFeeMeta {
                        task_index,
                        owner: task_meta.owner,
                        fee,
                        expiry_time: task_meta.expiry_time,
                        automation_fee_cap: task_meta.automation_fee_cap_for_epoch,
                        max_gas_amount: task_meta.max_gas_amount,
                        locked_deposit_fee: task_meta.locked_fee_for_next_epoch,
                    }
                };
                try_withdraw_task_automation_fee(
                    automation_registry,
                    refund_bookkeeping,
                    &resource_signer,
                    task,
                    current_cycle_end_time,
                    intermediate_state
                );
            };
        });
        processed_tasks
    }

    /// Processes automation task fees by checking user balances and task's commitment on automation-fee, i.e. automation-fee-cap
    /// - If the user has sufficient balance, deducts the fee and emits a success event.
    /// - If the balance is insufficient, removes the task and emits a cancellation event.
    /// - If calculated fee for the epoch surpasses task's automation-fee-cap task is removed and cancellation event is emitted.
    /// Return estimated committed gas for the next epoch, locked automation fee amount for this epoch, and list of active task indexes
    fun try_withdraw_task_automation_fees(
        automation_registry: &mut AutomationRegistry,
        refund_bookkeeping: &mut AutomationRefundBookkeeping,
        arc: &AutomationRegistryConfig,
        epoch_interval: u64,
        current_time: u64,
        intermediate_state: &mut IntermediateStateOfEpochChange,
    ) {
        // Compute the automation fee multiplier for epoch
        let automation_fee_per_sec = calculate_automation_fee_multiplier_for_epoch(
            arc,
            (intermediate_state.gas_committed_for_new_epoch as u256),
            arc.registry_max_gas_cap);

        let task_ids = enumerable_map::get_map_list(&automation_registry.tasks);
        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        let current_epoch_end_time = current_time + epoch_interval;

        // Sort task indexes to charge automation fees in the tasks chronological order
        sort_vector(&mut task_ids);

        // Process each active task and calculate fee for the epoch for the tasks
        vector::for_each(task_ids, |task_index| {
            let task = {
                let task_meta = enumerable_map::get_value_mut(&mut automation_registry.tasks, task_index);
                let fee= calculate_task_fee(arc, task_meta, epoch_interval, current_time, automation_fee_per_sec);
                // If the task reached this phase that means it is valid active task for the new epoch.
                // During cleanup all expired tasks has been removed from the registry but the state of the tasks is not updated.
                // As here we need to distinguish new tasks from already existing active tasks,
                // as the fee calculation for them will be different based on their active duration in the epoch.
                // For more details see calculate_task_fee function.
                task_meta.state = ACTIVE;
                AutomationTaskFeeMeta {
                    task_index,
                    owner: task_meta.owner,
                    fee,
                    expiry_time: task_meta.expiry_time,
                    automation_fee_cap: task_meta.automation_fee_cap_for_epoch,
                    max_gas_amount: task_meta.max_gas_amount,
                    locked_deposit_fee: task_meta.locked_fee_for_next_epoch,
                }
            };
            try_withdraw_task_automation_fee(
                automation_registry,
                refund_bookkeeping,
                &resource_signer,
                task,
                current_epoch_end_time,
                intermediate_state
            );
        });
    }

    fun try_withdraw_task_automation_fee(
        automation_registry: &mut AutomationRegistry,
        refund_bookkeeping: &mut AutomationRefundBookkeeping,
        resource_signer: &signer,
        task: AutomationTaskFeeMeta,
        current_epoch_end_time: u64,
        intermediate_state: &mut IntermediateStateOfEpochChange) {
        // Remove the automation task if the epoch fee cap is exceeded
        if (task.fee > task.automation_fee_cap) {
            safe_deposit_refund(
                refund_bookkeeping,
                resource_signer,
                automation_registry.registry_fee_address,
                task.task_index,
                task.owner,
                task.locked_deposit_fee,
                task.locked_deposit_fee
            );
            enumerable_map::remove_value(&mut automation_registry.tasks, task.task_index);
            vector::push_back(&mut intermediate_state.removed_tasks, task.task_index);
            event::emit(TaskCancelledCapacitySurpassed {
                task_index: task.task_index,
                owner: task.owner,
                fee: task.fee,
                automation_fee_cap: task.automation_fee_cap,
            });
            return
        };
        let user_balance = coin::balance<SupraCoin>(task.owner);
        if (user_balance < task.fee) {
            // If the user does not have enough balance, remove the task, DON'T refund the locked deposit, but simply unlock it
            // and emit an event
            safe_unlock_locked_deposit(refund_bookkeeping, task.locked_deposit_fee, task.task_index);
            enumerable_map::remove_value(&mut automation_registry.tasks, task.task_index);
            vector::push_back(&mut intermediate_state.removed_tasks, task.task_index);
            event::emit(TaskCancelledInsufficentBalance {
                task_index: task.task_index,
                owner: task.owner,
                fee: task.fee,
            });
            return
        };
        if (task.fee != 0) {
            // Charge the fee and emit a success event
            let withdrawn_coins = coin::withdraw<SupraCoin>(
                &create_signer(task.owner),
                task.fee
            );
            // Merge to total task fees deducted from the users account
            coin::merge(&mut intermediate_state.epoch_locked_fees, withdrawn_coins);
        };
        event::emit(TaskEpochFeeWithdraw {
            task_index: task.task_index,
            owner: task.owner,
            fee: task.fee,
        });

        // Calculate gas commitment for the next epoch only for valid active tasks
        if (task.expiry_time > current_epoch_end_time) {
            intermediate_state.gas_committed_for_next_epoch = intermediate_state.gas_committed_for_next_epoch + task.max_gas_amount;
        };
    }

    /// The function updates the ActiveAutomationRegistryConfig structure with values extracted from the buffer, if the buffer exists.
    fun update_config_from_buffer(cycle_info: &mut AutomationCycleDetails) acquires ActiveAutomationRegistryConfig {
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
            automation_registry_config.congestion_exponent = buffer.congestion_exponent;
            automation_registry_config.task_capacity = buffer.task_capacity;
        };
        if (config_buffer::does_exist<AutomationCycleDuration>()) {
            let buffer = config_buffer::extract<AutomationCycleDuration>();
            if (std::option::is_some(&cycle_info.transition_state)) {
                let transition_state = std::option::borrow_mut(&mut cycle_info.transition_state);
                transition_state.new_cycle_duration = buffer.duration_secs;
            } else {
                cycle_info.duration_secs = buffer.duration_secs;
            }
        };
    }

    /// Transfers the specified fee amount from the resource account to the target account.
    fun transfer_fee_to_account_internal(to: address, amount: u64) acquires AutomationRegistry, AutomationRefundBookkeeping {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        let refund_bookkeeping = borrow_global<AutomationRefundBookkeeping>(@supra_framework);
        let resource_balance = coin::balance<SupraCoin>(automation_registry.registry_fee_address);

        assert!(resource_balance >= amount, EINSUFFICIENT_BALANCE);

        assert!((resource_balance - amount)
            >= automation_registry.epoch_locked_fees + refund_bookkeeping.total_deposited_automation_fee,
            EREQUEST_EXCEEDS_LOCKED_BALANCE);

        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        coin::transfer<SupraCoin>(&resource_signer, to, amount);
    }

    /// Update Automation Registry Config releated to registration.
    fun update_registration_config_internal(
        supra_framework: &signer,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        automation_base_fee_in_quants_per_sec: u64,
        flat_registration_fee_in_quants: u64,
        congestion_threshold_percentage: u8,
        congestion_base_fee_in_quants_per_sec: u64,
        congestion_exponent: u8,
        task_capacity: u16,
        cycle_duration_secs: u64,
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);

        validate_configuration_parameters_common(
            cycle_duration_secs,
            task_duration_cap_in_secs,
            registry_max_gas_cap,
            congestion_threshold_percentage,
            congestion_exponent);

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
            congestion_exponent,
            task_capacity
        };
        config_buffer::upsert(copy new_automation_registry_config);

        // next_epoch_registry_max_gas_cap will be update instantly
        let automation_registry_config = borrow_global_mut<ActiveAutomationRegistryConfig>(@supra_framework);
        automation_registry_config.next_epoch_registry_max_gas_cap = registry_max_gas_cap;

        event::emit(new_automation_registry_config);
    }

    fun check_registration_task_duration(
        expiry_time: u64,
        registration_time: u64,
        automation_registry_config: &AutomationRegistryConfig,
        automation_cycle_info: &AutomationCycleDetails
    ) {
        assert!(expiry_time > registration_time, EINVALID_EXPIRY_TIME);
        let task_duration = expiry_time - registration_time;
        assert!(task_duration <= automation_registry_config.task_duration_cap_in_secs, EEXPIRY_TIME_UPPER);

        // Check that task is valid at least in the next epoch
        assert!(
            expiry_time > (automation_cycle_info.start_time + automation_cycle_info.duration_secs),
            EEXPIRY_BEFORE_NEXT_CYCLE
        );
    }

    /// Insertion sort implementation for vector
    fun sort_vector(input: &mut vector<u64>) {
        let len = vector::length(input);
        let i = 1;
        while (i < len) {
            let j = i;
            let to_be_sorted = *vector::borrow(input, j);
            while (j > 0 && to_be_sorted < *vector::borrow(input, j - 1)) {
                vector::swap(input, j, j - 1);
                j = j - 1;
            };
            i = i + 1;
        };
    }

    fun upscale_from_u8(value: u8): u256 { (value as u256) * DECIMAL }

    fun upscale_from_u64(value: u64): u256 { (value as u256) * DECIMAL }

    fun upscale_from_u256(value: u256): u256 { value * DECIMAL }

    fun downscale_to_u64(value: u256): u64 { ((value / DECIMAL) as u64) }

    fun downscale_to_u256(value: u256): u256 { value / DECIMAL }

    /// If SUPRA_AUTOMATION_CYCLE is enabled then call native function to assert full support of cycle based
    /// automation registry management.
    fun assert_automation_cycle_management_support() {
        if (features::supra_automation_cycle_enabled()) {
            native_automation_cycle_management_support();
        }
    }

    native fun native_automation_cycle_management_support(): bool;

    #[test_only]
    const AUTOMATION_MAX_GAS_TEST: u64 = 100_000_000;
    #[test_only]
    const TTL_UPPER_BOUND_TEST: u64 = 2_626_560;
    #[test_only]
    const AUTOMATION_BASE_FEE_TEST: u64 = 1000;
    #[test_only]
    const FLAT_REGISTRATION_FEE_TEST: u64 = 1_000_000;
    #[test_only]
    const CONGESTION_THRESHOLD_TEST: u8 = 80;
    #[test_only]
    const CONGESTION_BASE_FEE_TEST: u64 = 100;
    #[test_only]
    const CONGESTION_EXPONENT_TEST: u8 = 6;
    #[test_only]
    const TASK_CAPACITY_TEST: u16 = 500;
    #[test_only]
    /// Value defined in microsecond
    const EPOCH_INTERVAL_FOR_TEST_IN_SECS: u64 = 7200;
    #[test_only]
    const PARENT_HASH: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
    #[test_only]
    const PAYLOAD: vector<u8> = x"0102030405060708090a0b0c0d0e0f0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20101112131415161718191a1b1c1d1e1f20";
    #[test_only]
    const AUX_DATA: vector<vector<u8>> = vector[];
    #[test_only]
    const ACCOUNT_BALANCE: u64 = 10_000_000_000;
    #[test_only]
    const REGISTRY_DEFAULT_BALANCE: u64 = 100_000_000_000;


    #[test_only]
    /// Initializes registry without enabling SUPRA_NATIVE_AUTOMATION feature flag
    fun initialize_registry_test_partially(supra_framework: &signer, user: &signer) {
        use supra_framework::coin;
        use supra_framework::supra_coin::{Self, SupraCoin};

        let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
        account::create_account_for_test(@supra_framework);

        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(supra_framework);

        initialize_v2(
            supra_framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            TTL_UPPER_BOUND_TEST,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
        );

        coin::register<SupraCoin>(user);
        supra_coin::mint(supra_framework, user_addr, ACCOUNT_BALANCE);
        supra_coin::mint(supra_framework, get_registry_fee_address(), REGISTRY_DEFAULT_BALANCE);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        timestamp::set_time_has_started_for_testing(supra_framework);
    }

    #[test_only]
    fun toggle_feature_flag(supra_framework: &signer, enable: bool) {
        let flag = vector[features::get_supra_native_automation_feature()];
        if (enable) {
            features::change_feature_flags_for_testing(supra_framework,
                flag,
                vector::empty<u64>());
        } else {
            features::change_feature_flags_for_testing(supra_framework,
                vector::empty<u64>(),
                flag)
        }
    }

    #[test_only]
    public fun update_config_for_tests(
        supra_framework: &signer,
        task_duration_cap_in_secs: u64,
        registry_max_gas_cap: u64,
        automation_base_fee_in_quants_per_sec: u64,
        flat_registration_fee_in_quants: u64,
        congestion_threshold_percentage: u8,
        congestion_base_fee_in_quants_per_sec: u64,
        congestion_exponent: u8,
        task_capacity: u16,
    ) acquires ActiveAutomationRegistryConfig {
        system_addresses::assert_supra_framework(supra_framework);

        let new_automation_registry_config = AutomationRegistryConfig {
            task_duration_cap_in_secs,
            registry_max_gas_cap,
            automation_base_fee_in_quants_per_sec,
            flat_registration_fee_in_quants,
            congestion_threshold_percentage,
            congestion_base_fee_in_quants_per_sec,
            congestion_exponent,
            task_capacity
        };

        let automation_registry_config = borrow_global_mut<ActiveAutomationRegistryConfig>(@supra_framework);
        automation_registry_config.main_config = new_automation_registry_config;
        automation_registry_config.next_epoch_registry_max_gas_cap = registry_max_gas_cap;

        event::emit(new_automation_registry_config);
    }

    #[test_only]
    /// Initializes registry and enables SUPRA_NATIVE_AUTOMATION feature flag
    fun initialize_registry_test(supra_framework: &signer, user: &signer) {
        initialize_registry_test_partially(supra_framework, user);
        toggle_feature_flag(supra_framework, true);
    }


    #[test_only]
    fun has_task_with_id(task_index: u64): bool acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        enumerable_map::contains(&automation_registry.tasks, task_index)
    }

    #[test_only]
    /// Registers a task with specified state and returns the task index
    fun register_with_state(
        framework: &signer,
        user: &signer,
        max_gas_amount: u64,
        automation_fee_cap: u64,
        expiry_time: u64,
        state: u8,
    ): u64 acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationCycleDetails, AutomationRefundBookkeeping {
        register(user,
            PAYLOAD,
            expiry_time,
            max_gas_amount,
            20,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );
        let automation_registry = borrow_global_mut<AutomationRegistry>(address_of(framework));
        let task_index = automation_registry.current_index - 1;
        let task_details = enumerable_map::get_value_mut(&mut automation_registry.tasks, task_index);
        if (state != PENDING) {
            automation_registry.gas_committed_for_this_epoch = automation_registry.gas_committed_for_this_epoch + (max_gas_amount as u256);
        };
        task_details.state = state;
        task_index
    }

    #[test_only]
    /// Registers a task with specified state and returns the task index
    fun update_task_state(
        automation_registry: &mut AutomationRegistry,
        task_index: u64,
        state: u8,
    ) {
        let task_details = enumerable_map::get_value_mut(&mut automation_registry.tasks, task_index);
        task_details.state = state;
    }

    #[test_only]
    /// Registers a task with specified state and returns the task index
    fun check_task_state(
        automation_registry: &AutomationRegistry,
        task_index: u64,
        exists: bool,
        state: u8,
    ) {
        assert!(enumerable_map::contains(&automation_registry.tasks, task_index) == exists, 98);
        if (exists) {
            let task_details = enumerable_map::get_value_ref(&automation_registry.tasks, task_index);
            assert!(task_details.state == state, 99);
        }
    }

    #[test_only]
    fun set_locked_fee(
        framework: &signer,
        locked_fee: u64,
    ) acquires AutomationRegistry {
        let automation_registry = borrow_global_mut<AutomationRegistry>(address_of(framework));
        automation_registry.epoch_locked_fees = locked_fee;
    }

    #[test_only]
    fun check_account_balance(
        account: address,
        expected_balance: u64,
    ) {
        let current_balance = coin::balance<SupraCoin>(account);
        assert!(current_balance == expected_balance, current_balance);
    }

    #[test_only]
    fun consume_intermediate_state(
        intermediate_state: IntermediateStateOfEpochChange,
    ) {
        let IntermediateStateOfEpochChange {
            gas_committed_for_new_epoch: _,
            gas_committed_for_next_epoch: _,
            epoch_locked_fees,
            removed_tasks: _,
        } = intermediate_state;

        destroy_zero(epoch_locked_fees);
    }

    /// Represents the fee charged for an automation task execution and some additional information.
    /// Used only in tests, substituted with AutomationTaskFeeMeta in production code.
    /// Kept for backward compatible framework upgrade.
    struct AutomationTaskFee has drop {
        task_index: u64,
        owner: address,
        fee: u64,
    }

    #[test_only]
    /// Calculates automation task fees for the active tasks for the provided interval with provided tcmg occupancy.
    fun calculate_tasks_automation_fees(
        automation_registry: &AutomationRegistry,
        arc: &AutomationRegistryConfig,
        interval: u64,
        current_time: u64,
        tcmg: u256,
    ): vector<AutomationTaskFee> {
        let task_with_fees = vector[];

        // Compute the automation fee multiplier for epoch
        let automation_fee_per_sec = calculate_automation_fee_multiplier_for_epoch(arc, tcmg, arc.registry_max_gas_cap);

        enumerable_map::for_each_value_ref(&automation_registry.tasks, |task| {
            let task: &AutomationTaskMetaData = task;
                let task_fee = calculate_task_fee(arc, task, interval, current_time, automation_fee_per_sec);
                vector::push_back(&mut task_with_fees, AutomationTaskFee {
                    task_index: task.task_index,
                    owner: task.owner,
                    fee: task_fee,
                });
        });
        task_with_fees
    }


    #[test(supra_framework = @supra_framework)]
    #[expected_failure(abort_code = EUNACCEPTABLE_TASK_DURATION_CAP, location = Self)]
    fun test_initialization_with_invalid_task_duration(
        supra_framework: &signer,
    ) {
        initialize_v2(
            supra_framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
        );
    }

    #[test(supra_framework = @supra_framework)]
    #[expected_failure(abort_code = EREGISTRY_MAX_GAS_CAP_NON_ZERO, location = Self)]
    fun test_initialization_with_invalid_registry_max_gas_cap(
        supra_framework: &signer,
    ) {
        initialize_v2(
            supra_framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            0,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST
        );
    }

    #[test(supra_framework = @supra_framework)]
    #[expected_failure(abort_code = ECONGESTION_EXP_NON_ZERO, location = Self)]
    fun test_initialization_with_invalid_congestion_exponent(
        supra_framework: &signer,
    ) {
        initialize_v2(
            supra_framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            0,
            TASK_CAPACITY_TEST
        );
    }

    #[test(supra_framework = @supra_framework)]
    #[expected_failure(abort_code = EMAX_CONGESTION_THRESHOLD, location = Self)]
    fun test_initialization_with_invalid_threshold_percentage(
        supra_framework: &signer,
    ) {
        initialize_v2(
            supra_framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            200,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
        );
    }

    #[test(supra_framework = @supra_framework, user = @0x1cafe)]
    fun test_registry(
        supra_framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(supra_framework, user);

        let payload = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132";
        let parent_hash = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
        register(user, payload, 86400, 1000, 100000, 100_000_00, parent_hash, AUX_DATA);
    }

    #[test(supra_framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EDISABLED_AUTOMATION_FEATURE, location = Self)]
    fun test_registration_with_partial_initialization(
        supra_framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test_partially(supra_framework, user);

        let payload = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132";
        let parent_hash = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";
        register(user, payload, 86400, 1000, 100000, 100_000_00, parent_hash, AUX_DATA);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_update_config_success_update(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
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
        // Configuration parameter will update after on new epoch
        update_config_v2(framework,
            1_626_560,
            75,
            1005,
            700000000,
            70,
            2000,
            5,
            200,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS
        );

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
        assert!(state.congestion_exponent == 5, 8);
        assert!(state.task_capacity == 200, 9);
        // TODO check cycle duration update as well
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EUNACCEPTABLE_AUTOMATION_GAS_LIMIT, location = Self)]
    fun check_automation_gas_limit_failed_update(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
        update_config_v2(
            framework,
            TTL_UPPER_BOUND_TEST,
            45,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EUNACCEPTABLE_TASK_DURATION_CAP, location = Self)]
    fun check_config_udpate_with_invalid_task_duration_cap(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry,  ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        // Specified task duration cap is less than epoch length
        update_config_v2(
            framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EMAX_CONGESTION_THRESHOLD, location = Self)]
    fun check_config_udpate_with_max_congestion_threshold(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        // Specified task duration cap is less than epoch length
        update_config_v2(
            framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS + 1,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            150,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = ECONGESTION_EXP_NON_ZERO, location = Self)]
    fun check_config_udpate_with_invalid_congestion_exponent(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        // Specified task duration cap is less than epoch length
        update_config_v2(
            framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS + 1,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            0,
            TASK_CAPACITY_TEST,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EREGISTRY_MAX_GAS_CAP_NON_ZERO, location = Self)]
    fun check_config_udpate_with_invalid_registry_max_gas_cap(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        // Specified task duration cap is less than epoch length
        update_config_v2(
            framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS + 1,
            0,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_registration(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let max_gas_amount = 10;
        let estimated_fee = estimate_automation_fee(max_gas_amount);
        register(user,
            PAYLOAD,
            86400,
            max_gas_amount,
            20,
            estimated_fee,
            PARENT_HASH,
            AUX_DATA
        );
        assert!(1 == get_next_task_index(), 1);
        assert!(max_gas_amount == get_gas_committed_for_next_epoch(), 2);

        let registry_fee_address = get_registry_fee_address();
        let user_address = address_of(user);
        let registration_charges = FLAT_REGISTRATION_FEE_TEST + estimated_fee;
        let expected_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
        check_account_balance(user_address, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        let max_gas_amount_causing_of = (AUTOMATION_MAX_GAS_TEST * (CONGESTION_THRESHOLD_TEST as u64)) / 100;
        let estimated_fee = estimate_automation_fee(max_gas_amount_causing_of);
        register(user,
            PAYLOAD,
            86400,
            max_gas_amount_causing_of,
            20,
            estimated_fee,
            PARENT_HASH,
            AUX_DATA
        );
        assert!(2 == get_next_task_index(), 3);
        assert!(max_gas_amount_causing_of + max_gas_amount == get_gas_committed_for_next_epoch(), 4);

        let registration_charges = FLAT_REGISTRATION_FEE_TEST + estimated_fee;
        let expected_current_balance = expected_current_balance - registration_charges;
        let expected_registry_balance = expected_registry_balance + registration_charges;
        check_account_balance(user_address, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EREGISTRY_IS_FULL, location = Self)]
    fun check_registration_with_full_tasks(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        update_config_for_tests(
            framework,
            TTL_UPPER_BOUND_TEST,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            2,
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
        // Registry is already full
        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINVALID_EXPIRY_TIME, location = Self)]
    fun check_registration_invalid_expiry_time(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
    #[expected_failure(abort_code = EEXPIRY_BEFORE_NEXT_CYCLE, location = Self)]
    fun check_registration_invalid_expiry_time_before_next_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2,
            70,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EEXPIRY_TIME_UPPER, location = Self)]
    fun check_registration_invalid_expiry_time_surpassing_task_duration_cap(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            TTL_UPPER_BOUND_TEST + 1,
            70,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_registration_valid_expiry_time_matches_task_duration_cap(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);

        register(user,
            PAYLOAD,
            TTL_UPPER_BOUND_TEST,
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
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            60000000,
            20,
            100_000_000,
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
            100_000_000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EINSUFFICIENT_AUTOMATION_FEE_CAP_FOR_EPOCH, location = Self)]
    fun check_registration_with_insufficient_automation_fee_cap(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        register(user,
            PAYLOAD,
            86400,
            10_000,
            70,
            1,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_activation_on_new_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
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

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST_IN_SECS);
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
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
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

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST_IN_SECS);
        on_new_epoch();
        assert!(40 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
        });

        // Cancel task 2. The committed gas for the next epoch will be updated,
        // but when requested active task it will be still available in the list
        cancel_task(user, 2);
        // Task will be still available in the registry but with cancelled state
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
    fun check_pending_task_cancellation_refunds(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let automation_fee_cap = 1000;

        register(user,
            PAYLOAD,
            86400,
            10,
            20,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );
        // check user balance after registered new task
        let registry_fee_address = get_registry_fee_address();
        let user_address = address_of(user);
        let registration_charges = FLAT_REGISTRATION_FEE_TEST + automation_fee_cap;
        let expected_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
        check_account_balance(user_address, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        cancel_task(user, 0);
        // Pending task upon cancellation refunded only with half of the deposit;
        let expected_refund = automation_fee_cap / REFUND_FACTOR;
        check_account_balance(user_address, expected_current_balance + expected_refund);
        check_account_balance(registry_fee_address, expected_registry_balance - expected_refund);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = EAUTOMATION_TASK_NOT_FOUND, location = Self)]
    fun check_cancellation_of_non_existing_task(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);

        cancel_task(user, 1);
    }

    #[test(framework = @supra_framework, user = @0x1cafe, user2 = @0x1cafa)]
    #[expected_failure(abort_code = EUNAUTHORIZED_TASK_OWNER, location = Self)]
    fun check_unauthorized_cancellation_task(
        framework: &signer,
        user: &signer,
        user2: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
    fun check_cancellation_of_cancelled_task(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
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
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
        initialize_registry_test(framework, user);
        let automation_fee_cap = 100_000;

        register(user,
            PAYLOAD,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            1_000_000, // normal gas amount
            20,
            100_000,
            PARENT_HASH,
            AUX_DATA
        );

        // check user balance after registered new task
        let registry_fee_address = get_registry_fee_address();
        let user_address = address_of(user);
        let registration_charges = FLAT_REGISTRATION_FEE_TEST + automation_fee_cap;
        let expected_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
        check_account_balance(user_address, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch();

        // 10 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee = 10 * EPOCH_INTERVAL_FOR_TEST_IN_SECS;
        // check user balance after on new epoch fee applied
        check_account_balance(user_address, expected_current_balance - expected_automation_fee);
        check_account_balance(
            registry_fee_address,
            expected_registry_balance + expected_automation_fee);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_congestion_fee_charge_on_new_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
        initialize_registry_test(framework, user);
        let automation_fee_cap = 10_000_000;

        register(user,
            PAYLOAD,
            3 * EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            85_000_000, // congestion threshold reached
            20,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );

        // check user balance after registered new task
        let registry_fee_address = get_registry_fee_address();
        let user_address = address_of(user);
        let registration_charges = FLAT_REGISTRATION_FEE_TEST + automation_fee_cap;
        let expected_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
        check_account_balance(user_address, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        timestamp::update_global_time_for_test_secs(50);
        on_new_epoch();
        has_task_with_id(0);

        // 85/100 * 1000 = 850 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 850;
        // 5% surpasses the threshold, ((1+(5/100))^exponent-1) * 100 = 34 congestion base fee, occupancy 85/100, 7200 epoch duration
        let expected_congestion_fee = 34 * 85 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        let expected_epoch_fee = expected_automation_fee + expected_congestion_fee;
        // check user balance after on new epoch fee applied
        check_account_balance(user_address, expected_current_balance - expected_epoch_fee);
        check_account_balance(
            registry_fee_address,
            expected_registry_balance + expected_epoch_fee);
    }

    // #[test(framework = @supra_framework, user = @0x1cafa)]
    // fun check_update_state_for_new_epoch(
    //     framework: &signer,
    //     user: &signer
    // ) acquires AutomationRegistry, AutomationCycleInfo, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
    //     initialize_registry_test(framework, user);
    //     let task_exipry_time = 2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2;
    //     let automation_fee_cap = 100_000_000;
    //     let exists = true;
    //
    //     let task1 = register_with_state(
    //         framework,
    //         user,
    //         44_000_000,
    //         automation_fee_cap,
    //         task_exipry_time,
    //         ACTIVE);
    //     let task2 = register_with_state(
    //         framework,
    //         user,
    //         44_000_000,
    //         automation_fee_cap,
    //         task_exipry_time,
    //         ACTIVE);
    //     let task3 = register_with_state(
    //         framework,
    //         user,
    //         11_000_000,
    //         automation_fee_cap,
    //         task_exipry_time,
    //         PENDING);
    //     let expected_user_current_balance = ACCOUNT_BALANCE - 3 * (FLAT_REGISTRATION_FEE_TEST + automation_fee_cap);
    //     let expected_registry_current_balance = REGISTRY_DEFAULT_BALANCE + 3 * (FLAT_REGISTRATION_FEE_TEST + automation_fee_cap);
    //
    //
    //     // 44/100 * 1000 = 440 - automation_epoch_fee_per_second, 7200 epoch duration
    //     let expected_automation_fee_per_task = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 440;
    //     // 8% surpasses the threshold, ((1+(8/100))^exponent-1) * 100 = 58 congestion base fee, occupancy 44/100, 7200 epoch duration
    //     let expected_congestion_fee_per_task = 58 * 44 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
    //
    //     let fwk_address = address_of(framework);
    //     let user_address = address_of(user);
    //
    //     // No refund when there is no locked fee.
    //     set_locked_fee(framework, 0);
    //     {
    //         let ar = borrow_global_mut<AutomationRegistry>(fwk_address);
    //         let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(fwk_address);
    //         let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
    //         let aei = borrow_global<AutomationCycleInfo>(fwk_address);
    //         let result = update_state_for_new_epoch(ar, refund_bookkeeping, arc, aei, EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2);
    //         consume_intermediate_state(result);
    //         // If there is no locked fee, nothing to refund;
    //         // tasks only will be charged for the next epoch.
    //         check_account_balance(user_address, expected_user_current_balance);
    //         check_account_balance(ar.registry_fee_address, expected_registry_current_balance);
    //         // Task state is still pending, tasks will be activated after their epoch-fee is calculated
    //         check_task_state(ar, task3, exists, PENDING);
    //     };
    //
    //     // Set some locked fee which is enough to pay refund if necessary
    //     set_locked_fee(framework, 100_000_000);
    //
    //     {
    //         // if epoch length matches or greater the expected epoch interval then no refund is expected
    //         // even if there is a locked fee.
    //         let ar = borrow_global_mut<AutomationRegistry>(fwk_address);
    //         let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(fwk_address);
    //         let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
    //         let aei = borrow_global<AutomationEpochInfo>(fwk_address);
    //
    //         let result = update_state_for_new_epoch(ar, refund_bookkeeping, arc, aei, EPOCH_INTERVAL_FOR_TEST_IN_SECS);
    //         consume_intermediate_state(result);
    //
    //         check_account_balance(user_address, expected_user_current_balance);
    //         check_account_balance(ar.registry_fee_address, expected_registry_current_balance);
    //         check_task_state(ar, task1, exists, ACTIVE);
    //         check_task_state(ar, task2, exists, ACTIVE);
    //         // Task state is still pending, tasks will be activated after their epoch-fee is calculated
    //         check_task_state(ar, task3, exists, PENDING);
    //
    //         // Refund is expected only for ACTIVE AND CANCELLED TASK BUT NOT FOR PENDING
    //         update_task_state(ar, task2, CANCELLED);
    //         let result = update_state_for_new_epoch(ar, refund_bookkeeping, arc, aei, EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2);
    //         consume_intermediate_state(result);
    //         // Half of each task epoch-fee is refunded due to short epoch + locked deposit fee for the cancelled task
    //         let expected_refund = expected_congestion_fee_per_task + expected_automation_fee_per_task
    //             + automation_fee_cap; // refund of the depodit for cancelled task
    //         expected_user_current_balance = expected_user_current_balance + expected_refund;
    //         expected_registry_current_balance = expected_registry_current_balance - expected_refund;
    //
    //         check_account_balance(user_address, expected_user_current_balance);
    //         check_account_balance(ar.registry_fee_address, expected_registry_current_balance);
    //         check_task_state(ar, task1, exists, ACTIVE);
    //         check_task_state(ar, task2, !exists, CANCELLED);
    //         // Task state is still pending, tasks will be activated after their epoch-fee is calculated
    //         check_task_state(ar, task3, exists, PENDING);
    //
    //         // Now we have only task1 as Active and task 3 as pending.
    //         // If epoch duration surpasses tasks expiration time, then they are refunded on  locked deposit, and removed from registry.
    //         // even pending task.
    //         let result = update_state_for_new_epoch(
    //             ar,
    //             refund_bookkeeping,
    //             arc,
    //             aei,
    //             task_exipry_time + EPOCH_INTERVAL_FOR_TEST_IN_SECS
    //         );
    //         consume_intermediate_state(result);
    //         let expected_refund = 2 * automation_fee_cap; // refund of the depodit for both available tasks
    //
    //         expected_user_current_balance = expected_user_current_balance + expected_refund;
    //         expected_registry_current_balance = expected_registry_current_balance - expected_refund;
    //
    //         check_account_balance(user_address, expected_user_current_balance);
    //         check_account_balance(ar.registry_fee_address, expected_registry_current_balance);
    //     };
    // }

    // #[test(framework = @supra_framework, user = @0x1cafa)]
    // fun check_update_state_for_new_epoch_with_remaining_time_refund(
    //     framework: &signer,
    //     user: &signer
    // ) acquires AutomationRegistry, AutomationCycleInfo, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
    //     initialize_registry_test(framework, user);
    //     let task_exipry_time = 2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2;
    //     let automation_fee_cap = 100_000_000;
    //     let exists = true;
    //
    //     let task1 = register_with_state(
    //         framework,
    //         user,
    //         44_000_000,
    //         automation_fee_cap,
    //         task_exipry_time,
    //         ACTIVE);
    //     let task2 = register_with_state(
    //         framework,
    //         user,
    //         44_000_000,
    //         automation_fee_cap,
    //         task_exipry_time,
    //         CANCELLED);
    //     let task3 = register_with_state(
    //         framework,
    //         user,
    //         11_000_000,
    //         automation_fee_cap,
    //         task_exipry_time,
    //         PENDING);
    //     let registration_charges = 3 * (FLAT_REGISTRATION_FEE_TEST + automation_fee_cap);
    //     let expected_user_current_balance = ACCOUNT_BALANCE - registration_charges;
    //     let expected_registry_current_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
    //
    //
    //     // 44/100 * 1000 = 440 - automation_epoch_fee_per_second, 7200 epoch duration
    //     let expected_automation_fee_per_task = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 440;
    //     // 8% surpasses the threshold, ((1+(8/100))^exponent-1) * 100 = 58 congestion base fee, occupancy 44/100, 7200 epoch duration
    //     let expected_congestion_fee_per_task = 58 * 44 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
    //
    //     let fwk_address = address_of(framework);
    //     let user_address = address_of(user);
    //
    //
    //     // Set some locked fee which is enough to pay refund if necessary
    //     set_locked_fee(framework, 100_000_000);
    //
    //     // Refund is expected only for the remaing time till the task expiry time for both cancelled and active tasks
    //     // Task was expiring in the middle of the 3rd epoch, but epoch duration was cat short by 3/4
    //     let current_time = 2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 4;
    //     // update epoch-start-time to be 2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS
    //     {
    //         let aei = borrow_global_mut<AutomationEpochInfo>(fwk_address);
    //         aei.start_time = 2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS;
    //     };
    //
    //     let ar = borrow_global_mut<AutomationRegistry>(fwk_address);
    //     let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(fwk_address);
    //     let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
    //     let aei = borrow_global<AutomationEpochInfo>(fwk_address);
    //
    //     check_account_balance(user_address, expected_user_current_balance);
    //     check_account_balance(ar.registry_fee_address, expected_registry_current_balance);
    //
    //     let result = update_state_for_new_epoch(ar, refund_bookkeeping, arc, aei, current_time);
    //     consume_intermediate_state(result);
    //     // It is expected that the tasks will be chared only for 1/2 epoch fee, so if the epoch lenght is 1/4,
    //     // then refund should be 1/4.
    //     // as account has 2 tasks with same automation and congestion fees then refund is double
    //     // Half of each task epoch-fee is refunded due to short epoch + locked deposit fee for the cancelled task
    //     let expected_refund = (expected_congestion_fee_per_task + expected_automation_fee_per_task) / 2
    //             + automation_fee_cap; // refund of the depodit for cancelled task
    //
    //     expected_user_current_balance = expected_user_current_balance + expected_refund;
    //     expected_registry_current_balance = expected_registry_current_balance - expected_refund;
    //
    //     check_task_state(ar, task1, exists, ACTIVE);
    //     check_task_state(ar, task2, !exists, CANCELLED);
    //     // Task state is still pending, tasks will be activated after their epoch-fee is calculated
    //     check_task_state(ar, task3, exists, PENDING);
    //
    //     check_account_balance(user_address, expected_user_current_balance);
    //     // // Check registry balance
    //     check_account_balance(ar.registry_fee_address, expected_registry_current_balance);
    // }

    #[test(framework = @supra_framework, user = @0x1cafb)]
    fun check_automation_task_fee_refund_is_done_with_old_config(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
        initialize_registry_test(framework, user);
        config_buffer::initialize(framework);
        let t1_t2_max_gas = 44_000_000;
        let t3_max_gas = 11_000_000;
        let automation_fee_cap = 100_000_000;

        let t1 = register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            automation_fee_cap,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);
        let t2 = register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            automation_fee_cap,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, CANCELLED);
        let t3 = register_with_state(
            framework,
            user,
            t3_max_gas,
            automation_fee_cap,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, PENDING);
        // Set some locked fee which is enough to pay refund if necessary
        set_locked_fee(framework, 100_000_000);
        update_config_v2(framework,
            TTL_UPPER_BOUND_TEST,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST / 2,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST / 2,
            CONGESTION_BASE_FEE_TEST / 2,
            CONGESTION_EXPONENT_TEST - 1,
            TASK_CAPACITY_TEST,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS
        );
        // Disable feature in order to avoid charges and check only refunds.
        toggle_feature_flag(framework, false);

        // 3 task has been registered
        let registration_charges = 3 * (FLAT_REGISTRATION_FEE_TEST + automation_fee_cap);
        let expected_user_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_current_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;

        let user_address = signer::address_of(user);
        check_account_balance(user_address, expected_user_current_balance);

        // 44/100 * 1000 = 440 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee_per_task = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 440;
        // 8% surpasses the threshold, ((1+(8/100))^exponent-1) * 100 = 58 congestion base fee, occupancy 44/100, 7200 epoch duration
        let expected_congestion_fee_per_task = 58 * 44 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        // Epoch cut short 2 times

        // Refund is expected
        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2);
        on_new_epoch();
        // as account have 2 active tasks with same automation and congestion fees then refund is double + deposit refund for all 3 tasks.
        let expected_refund = expected_congestion_fee_per_task + expected_automation_fee_per_task + 3 * automation_fee_cap;

        check_account_balance(user_address, expected_user_current_balance + expected_refund);
        // Checke registry balance
        check_account_balance(get_registry_fee_address(), expected_registry_current_balance - expected_refund);

        // Check that config is updated even if feature is disabled.
        let fwk_address = address_of(framework);
        let arc = borrow_global<ActiveAutomationRegistryConfig>(fwk_address);
        assert!(arc.main_config.registry_max_gas_cap == AUTOMATION_MAX_GAS_TEST, 14);
        assert!(arc.main_config.automation_base_fee_in_quants_per_sec == AUTOMATION_BASE_FEE_TEST / 2, 14);
        assert!(arc.main_config.congestion_threshold_percentage == CONGESTION_THRESHOLD_TEST / 2, 14);
        assert!(arc.main_config.congestion_base_fee_in_quants_per_sec == CONGESTION_BASE_FEE_TEST / 2, 14);
        assert!(arc.main_config.congestion_exponent == CONGESTION_EXPONENT_TEST - 1, 14);
        // Check that if feature is disabled, cleanup happens and no task is available in the registry.
        assert!(!has_task_with_id(t1), 15);
        assert!(!has_task_with_id(t2), 15);
        assert!(!has_task_with_id(t3), 15);
        assert!(get_task_count() == 0, 15);
        let ar = borrow_global<AutomationRegistry>(fwk_address);
        // Check that committed gas for this epoch is sum of active tasks max-gass
        assert!(ar.gas_committed_for_this_epoch == 0, 16);
        // Check locked fee is 0 as feature is disabled and no charges have been done.
        assert!(ar.epoch_locked_fees == 0, 17);
        assert!(ar.gas_committed_for_next_epoch == 0, 17);
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    fun check_automation_task_fee_calculation(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let t1_t2_max_gas = 44_000_000;

        register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            100_000_000,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);
        register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            100_000_000,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);

        // 44/100 * 1000 = 440 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee_per_task = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 440;
        // 8% surpasses the threshold, ((1+(8/100))^exponent-1) * 100 = 58 congestion base fee, occupancy 44/100, 7200 epoch duration
        let expected_congestion_fee_per_task = 58 * 44 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        // Epoch cut short 2 times
        let fwk_address = address_of(framework);

        // if epoch length matches or greater the expected epoch interval then no refund is expected
        // event if there is a locked fee.
        let ar = borrow_global<AutomationRegistry>(fwk_address);
        let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
        let tcmg = ((2 * t1_t2_max_gas) as u256);
        // Take into account CANCELLED tasks as well
        // Tasks are still valid
        let results = calculate_tasks_automation_fees(
            ar,
            arc,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            0,
            tcmg);
        assert!(vector::length(&results) == 2, 2);

        let expected_fee = expected_automation_fee_per_task + expected_congestion_fee_per_task;
        let r1 = vector::borrow(&results, 0);
        let r2 = vector::borrow(&results, 1);
        assert!(r1.fee == expected_fee, 3);
        assert!(r2.fee == expected_fee, 4);

        // Take into account CANCELLED tasks as well
        // Tasks are still valid but for the half of the epoch, current_time - task.expiry time == epoch_duration / 2
        let current_time = EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2;
        let results = calculate_tasks_automation_fees(
            ar,
            arc,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            current_time,
            tcmg,
        );
        // Pending task is ignored
        assert!(vector::length(&results) == 2, 2);

        let expected_fee = (expected_automation_fee_per_task + expected_congestion_fee_per_task) / 2;
        let r1 = vector::borrow(&results, 0);
        let r2 = vector::borrow(&results, 1);
        assert!(r1.fee == expected_fee, 3);
        assert!(r2.fee == expected_fee, 4);

        // Tasks are considered as expired even if they are part of the registry due to some bug, they will not be charged.
        let current_time = 2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS;
        let results = calculate_tasks_automation_fees(
            ar,
            arc,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            current_time,
            tcmg,
        );
        // Pending task is ignored
        assert!(vector::length(&results) == 2, 2);

        let r1 = vector::borrow(&results, 0);
        let r2 = vector::borrow(&results, 1);
        assert!(r1.fee == 0, 5);
        assert!(r2.fee == 0, 6);
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    fun check_automation_task_fee_calculation_for_short_tasks(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let t1_t2_max_gas = 44_000_000;
        let expiry_time = EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2;

        // Old but short task, will be charged according to active time
        let task1 = register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            100_000_000,
            expiry_time,
            ACTIVE);

        // New short task will be charged full epoch fee
        let task2 = register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            100_000_000,
            expiry_time,
            PENDING);

        // 44/100 * 1000 = 440 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee_per_task = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 440;
        // 8% surpasses the threshold, ((1+(8/100))^exponent-1) * 100 = 58 congestion base fee, occupancy 44/100, 7200 epoch duration
        let expected_congestion_fee_per_task = 58 * 44 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        // Epoch cut short 2 times
        let fwk_address = address_of(framework);

        // if epoch length matches or greater the expected epoch interval then no refund is expected
        // event if there is a locked fee.
        let ar = borrow_global_mut<AutomationRegistry>(fwk_address);
        let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
        let tcmg = ((2 * t1_t2_max_gas) as u256);
        // Take into account CANCELLED tasks as well
        // Tasks are still valid
        let results = calculate_tasks_automation_fees(
            ar,
            arc,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            tcmg);
        assert!(vector::length(&results) == 2, 2);

        let expected_fee = expected_automation_fee_per_task + expected_congestion_fee_per_task;
        let r1 = vector::borrow(&results, task1);
        let r2 = vector::borrow(&results, task2);
        assert!(r1.fee == expected_fee / 2, 3);
        // As task to is short and new task it will be charged for full epoch
        assert!(r2.fee == expected_fee, 4);

        // Now lets assume task as activated and epoch has been kept short, refund for both tasks will be done in the
        // same manner according to their expiration time.
        update_task_state(ar, task2, ACTIVE);

        let current_time = EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 4;
        let refund_interval = 2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS - current_time;
        // Each task will be active still for EPOCH_INTERVAL_FOR_TEST_IN_SECS / 4 duration,
        // as expiry time was EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2;
        let results = calculate_tasks_automation_fees(
            ar,
            arc,
            refund_interval,
            current_time,
            tcmg);
        assert!(vector::length(&results) == 2, 5);

        let expected_fee = expected_automation_fee_per_task + expected_congestion_fee_per_task;
        let r1 = vector::borrow(&results, task1);
        let r2 = vector::borrow(&results, task2);
        assert!(r1.fee == expected_fee / 4, 6);
        // For this task full epoch fee was charged, but the refund is done according to expiry time
        assert!(r2.fee == expected_fee / 4, 7);
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    fun check_automation_task_fee_calculation_with_zero_multipliers(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let t1_t2_max_gas = 44_000_000;

        register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            100_000_000,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);
        register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            100_000_000,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);

        // 44/100 * 1000 = 440 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee_per_task = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 440;
        // 8% surpasses the threshold, ((1+(8/100))^exponent-1) * 100 = 58 congestion base fee, occupancy 44/100, 7200 epoch duration
        let expected_congestion_fee_per_task = 58 * 44 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        // Epoch cut short 2 times
        let fwk_address = address_of(framework);

        // Update config with 0 automation base fee
        update_config_for_tests(framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            AUTOMATION_MAX_GAS_TEST,
            0,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
        );

        let tcmg = ((2 * t1_t2_max_gas) as u256);

        {
            let ar = borrow_global<AutomationRegistry>(fwk_address);
            let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
            let results = calculate_tasks_automation_fees(ar, arc,
                EPOCH_INTERVAL_FOR_TEST_IN_SECS,
                0,
                tcmg);
            assert!(vector::length(&results) == 2, 10);

            let expected_fee = expected_congestion_fee_per_task;
            let r1 = vector::borrow(&results, 0);
            let r2 = vector::borrow(&results, 1);
            assert!(r1.fee == expected_fee, 1);
            assert!(r2.fee == expected_fee, 2);
        };

        // Update config with 100% congestion treshold, no congestion fee is expected
        update_config_for_tests(framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            100,
            CONGESTION_BASE_FEE_TEST,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
        );

        let tcmg = ((2 * t1_t2_max_gas) as u256);

        {
            let ar = borrow_global<AutomationRegistry>(fwk_address);
            let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
            let results = calculate_tasks_automation_fees(ar, arc,
                EPOCH_INTERVAL_FOR_TEST_IN_SECS,
                0,
                tcmg);
            assert!(vector::length(&results) == 2, 11);

            let expected_fee = expected_automation_fee_per_task;
            let r1 = vector::borrow(&results, 0);
            let r2 = vector::borrow(&results, 1);
            assert!(r1.fee == expected_fee, 3);
            assert!(r2.fee == expected_fee, 4);
        };

        // Update config with 0 congestion base fee, no congestion fee is expected
        update_config_for_tests(framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            0,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
        );

        let tcmg = ((2 * t1_t2_max_gas) as u256);

        {
            let ar = borrow_global<AutomationRegistry>(fwk_address);
            let arc = &borrow_global<ActiveAutomationRegistryConfig>(fwk_address).main_config;
            let results = calculate_tasks_automation_fees(ar, arc,
                EPOCH_INTERVAL_FOR_TEST_IN_SECS,
                0,
                tcmg);
            assert!(vector::length(&results) == 2, 12);

            let expected_fee = expected_automation_fee_per_task;
            let r1 = vector::borrow(&results, 0);
            let r2 = vector::borrow(&results, 1);
            assert!(r1.fee == expected_fee, 3);
            assert!(r2.fee == expected_fee, 4);
        };
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    fun check_automation_task_fee_withdrawal_on_new_epoch(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
        initialize_registry_test(framework, user);
        let t1_t2_max_gas = 44_000_000;
        let t3_max_gas = 10_000_000;
        let automation_fee_cap_t1 = 10_000_000;
        let automation_fee_cap_t2_t3 = 100_000_000;

        // Automation fee cap overflow
        let t1 = register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            10_000_000,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);
        let t2 = register_with_state(
            framework,
            user,
            t1_t2_max_gas,
            100_000_000,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);
        // Not enough balance to pay fee
        let t3 = register_with_state(
            framework,
            user,
            t3_max_gas,
            100_000_000,
            2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS, ACTIVE);

        // Update config to cause automation fee cap overflow for the 1st task
        update_config_for_tests(framework,
            EPOCH_INTERVAL_FOR_TEST_IN_SECS,
            AUTOMATION_MAX_GAS_TEST,
            AUTOMATION_BASE_FEE_TEST,
            FLAT_REGISTRATION_FEE_TEST,
            CONGESTION_THRESHOLD_TEST,
            CONGESTION_BASE_FEE_TEST * 100,
            CONGESTION_EXPONENT_TEST,
            TASK_CAPACITY_TEST,
        );

        // TASK 1 and 2 expected epoch fee calculation
        // 44/100 * 1000 = 440 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee_for_t1_2 = EPOCH_INTERVAL_FOR_TEST_IN_SECS * 440;
        // 18% surpasses the threshold, ((1+(18/100))^exponent-1) * 10000 = 1.6995541 * 10000 congestion base fee,
        // occupancy 44/100, 7200 epoch duration
        let expected_congestion_fee_for_t1_2 = 16995 * 44 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        let expected_epoch_fee_for_t1_2 = expected_automation_fee_for_t1_2 + expected_congestion_fee_for_t1_2;

        // 3 tasks have been registered
        let registration_charges = 3 * FLAT_REGISTRATION_FEE_TEST + automation_fee_cap_t1 + 2 * automation_fee_cap_t2_t3;
        let expected_user_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_current_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
        // Make sure that user account has only enough balance for task 2 automation fee
        let withdraw_amount = expected_user_current_balance - expected_epoch_fee_for_t1_2;
        coin::transfer<SupraCoin>(
            user,
            get_registry_fee_address(),
            withdraw_amount);
        let expected_registry_current_balance = expected_registry_current_balance + withdraw_amount;

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2);
        on_new_epoch();

        let tcmg = ((2 * t1_t2_max_gas + t3_max_gas) as u256);
        let user_address = address_of(user);
        let fwk_address = address_of(framework);

        // TASK 1 cancelled due-to automation fee cap surrpass and task 3 is cancelled due to insufficient balance.
        // So for task 1 full deposit refund is expected and for task 3 no refund is expected.
        assert!(!has_task_with_id(t1), 1);
        assert!(!has_task_with_id(t3), 2);
        assert!(has_sender_active_task_with_id(user_address, t2), 3);
        // only one task is charged as the other 2 are cancelled/removed.
        // and uppon cancellation no deposit is refunded.
        check_account_balance(user_address, automation_fee_cap_t1);
        check_account_balance(
            get_registry_fee_address(),
            expected_registry_current_balance + expected_epoch_fee_for_t1_2 - automation_fee_cap_t1
        );

        let ar = borrow_global<AutomationRegistry>(fwk_address);
        assert!(ar.gas_committed_for_this_epoch == tcmg, 4);
        assert!(ar.gas_committed_for_next_epoch == t1_t2_max_gas, 5);
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    fun check_estimate_api(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        let fwk_address = address_of(framework);
        let task_max_gas = 10_000_000;
        // 10/100  * 1000 = 100 - automation_epoch_fee_per_sec, 7200 epoch duration. no congestion fee as threshold is not crossed.
        let expected_automation_fee = 100 * EPOCH_INTERVAL_FOR_TEST_IN_SECS;
        let result = estimate_automation_fee(task_max_gas);
        assert!(result == expected_automation_fee, 1);

        // expected congestion fee with 85 % congestion
        // 5% surpass, ((1+(5/100))^exponent-1) * 100 = 34 (acf), task occupancy 10% epoch interval 7200
        let expected_congestion_fee = 34 * 10 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        let result = estimate_automation_fee_with_committed_occupancy(task_max_gas, 75_000_000);
        assert!(result == expected_automation_fee + expected_congestion_fee, 2);

        // update next epoch committed max gas to cause the same congestion
        {
            let registry = borrow_global_mut<AutomationRegistry>(fwk_address);
            registry.gas_committed_for_next_epoch = 75_000_000;
        };
        let result = estimate_automation_fee(task_max_gas);
        assert!(result == expected_automation_fee + expected_congestion_fee, 2);

        // update next epoch registry max gas cap to resolve the congestion
        {
            let active_config = borrow_global_mut<ActiveAutomationRegistryConfig>(address_of(framework));
            active_config.next_epoch_registry_max_gas_cap = 200_000_000;
        };

        // 10/200 * 1000 occupancy - 50 - automation_epoch_fee_per_sec, 7200 epoch duration. no congestion fee as threshold is not crossed.
        let expected_automation_fee = 50 * EPOCH_INTERVAL_FOR_TEST_IN_SECS;
        let result = estimate_automation_fee(task_max_gas);
        assert!(result == expected_automation_fee, 2);

        // expected congestion fee with 86 % congestion
        // 6% surpass, ((1+(6/100))^exponent-1) * 100 = 41 (acf), task occupancy 5% epoch interval 7200
        let expected_congestion_fee = 41 * 5 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100;
        let result = estimate_automation_fee_with_committed_occupancy(task_max_gas, 162_000_000);
        assert!(result == expected_automation_fee + expected_congestion_fee, 2);
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    fun check_registry_fee_success_withdrawal(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        set_locked_fee(framework, 100_000_000);
        let withdraw_amount = 99_999_999;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE - withdraw_amount;
        let expected_user_balance = ACCOUNT_BALANCE + withdraw_amount;
        withdraw_automation_task_fees(framework, address_of(user), withdraw_amount);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);
        check_account_balance(address_of(user), expected_user_balance);
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    #[expected_failure(abort_code = EREQUEST_EXCEEDS_LOCKED_BALANCE, location = Self)]
    fun check_registry_fee_failed_withdrawal_locked_balance(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        set_locked_fee(framework, 100_000_000);
        let withdraw_amount = REGISTRY_DEFAULT_BALANCE - 80_000_000;
        withdraw_automation_task_fees(framework, address_of(user), withdraw_amount);
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    #[expected_failure(abort_code = EINSUFFICIENT_BALANCE, location = Self)]
    fun check_registry_fee_failed_withdrawal_insufficient_balance(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let withdraw_amount = REGISTRY_DEFAULT_BALANCE + 1;
        withdraw_automation_task_fees(framework, address_of(user), withdraw_amount);
    }

    #[test]
    fun check_sort_vector() {
        let task_fee_vec = vector[5, 3, 1, 4, 2];
        sort_vector(&mut task_fee_vec);
        let i = 0;
        while (i < 5) {
            let item = vector::borrow(&task_fee_vec, i);
            assert!(i + 1 == *item, i);
            i = i + 1;
        };
    }

    #[test]
    fun check_calculate_exponentiation() {
        // 5% threshould which means (5/100) * DECIMAL
        let result = calculate_exponentiation(5 * DECIMAL / 100, CONGESTION_EXPONENT_TEST);
        assert!(result == 34009563, 11); // ~0.34

        // 28% threshould which means (28/100) * DECIMAL
        let result = calculate_exponentiation(28 * DECIMAL / 100, CONGESTION_EXPONENT_TEST);
        assert!(result == 339804650, 12); // ~3.39

        // 50% threshould which means (50/100) * DECIMAL
        let result = calculate_exponentiation(50 * DECIMAL / 100, CONGESTION_EXPONENT_TEST);
        assert!(result == 1039062500, 13); // ~10.39
    }

    #[test(framework = @supra_framework, user = @0x1cafa)]
    fun test_registration_enable_disable(framework: &signer, user: &signer) acquires ActiveAutomationRegistryConfig {
        initialize_registry_test(framework, user);
        assert!(is_registration_enabled(), 14);

        disable_registration(framework);
        assert!(!is_registration_enabled(), 15);

        enable_registration(framework);
        assert!(is_registration_enabled(), 16);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    #[expected_failure(abort_code = ETASK_REGISTRATION_DISABLED, location = Self)]
    fun test_register_fails_when_registration_disabled(
        framework: &signer, user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);

        disable_registration(framework);
        assert!(!is_registration_enabled(), 17);

        register(user,
            PAYLOAD,
            86400,
            50,
            20,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
    }

    #[test(framework = @supra_framework, user = @0x1caff)]
    fun check_task_successful_stopped(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
        initialize_registry_test(framework, user);
        let automation_fee_cap = 1000;

        register(user,
            PAYLOAD,
            86400,
            200,
            200,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            200,
            200,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            200,
            200,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );
        register(user,
            PAYLOAD,
            86400,
            200,
            200,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );

        // check user balance after registered new task
        let registry_fee_address = get_registry_fee_address();
        let user_account = address_of(user);
        let registration_charges = 4 * (FLAT_REGISTRATION_FEE_TEST + automation_fee_cap);
        let expected_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
        check_account_balance(user_account, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST_IN_SECS);
        on_new_epoch();
        assert!(800 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 2, 3];
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
        });

        // 0.002 (*4) - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee = 4 * (200 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100000);
        expected_current_balance = expected_current_balance - expected_automation_fee;
        expected_registry_balance = expected_registry_balance + expected_automation_fee;
        check_account_balance(user_account, expected_current_balance );
        check_account_balance( registry_fee_address, expected_registry_balance );

        timestamp::update_global_time_for_test_secs(
            EPOCH_INTERVAL_FOR_TEST_IN_SECS + (EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2)
        );

        // Stop task 2. and it's removed from active task list immediately
        stop_tasks(user, vector[2]);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 3];
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
        });
        // There is no task with index 2 now.
        assert!(!has_task_with_id(2), 1);
        assert!(600 == get_gas_committed_for_next_epoch(), 1);

        // Because the on of the task stopped halfway, the user gets a 50% refund for the unused time.
        // which is equivalent to a 25% refund of the full epoch for single task and deposited fee upon registration
        let expected_refund = (200 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100000) / 4 + automation_fee_cap;
        expected_current_balance = expected_current_balance + expected_refund;
        expected_registry_balance = expected_registry_balance - expected_refund;
        check_account_balance(user_account, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        // Add and stop the task in the same epoch. Task index will be 4
        assert!(get_next_task_index() == 4, 1);
        register(user,
            PAYLOAD,
            86400,
            200,
            200,
            1000,
            PARENT_HASH,
            AUX_DATA
        );

        registration_charges = FLAT_REGISTRATION_FEE_TEST + automation_fee_cap;
        expected_current_balance = expected_current_balance - registration_charges;
        expected_registry_balance = expected_registry_balance + registration_charges;
        check_account_balance(user_account, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        stop_tasks(user, vector[4]);
        let active_task_ids = get_active_task_ids();
        let expected_ids = vector<u64>[0, 1, 3];
        vector::for_each(active_task_ids, |task_index| {
            assert!(vector::contains(&expected_ids, &task_index), 1);
        });
        // There is no task with index 4 and the next task index will be 5.
        assert!(!has_task_with_id(4), 1);
        assert!(get_next_task_index() == 5, 1);
        assert!(600 == get_gas_committed_for_next_epoch(), 1);

        // Expected refund for the stopping pending task is only the half of the deposited fee
        expected_refund = automation_fee_cap / REFUND_FACTOR;
        check_account_balance(user_account, expected_current_balance + expected_refund);
        check_account_balance(registry_fee_address, expected_registry_balance - expected_refund);
    }

    #[test(framework = @supra_framework, user = @0x1cafe, user2 = @0x1cafa)]
    #[expected_failure(abort_code = EUNAUTHORIZED_TASK_OWNER, location = Self)]
    fun check_unauthorized_stopping_task(
        framework: &signer,
        user: &signer,
        user2: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
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
        stop_tasks(user2, vector[0]);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_stopping_of_stopped_task(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
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
        // Stop the same task 2 times, second time it will not abort it just skip the task_id if it's not found
        stop_tasks(user, vector[0]);
        assert!(!has_task_with_id(0), 1);
        stop_tasks(user, vector[0]);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_stopping_of_cancelled_task(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
        initialize_registry_test(framework, user);
        let automation_fee_cap = 1000;

        register(user,
            PAYLOAD,
            86400,
            2000,
            200,
            1000,
            PARENT_HASH,
            AUX_DATA
        );
        assert!(2000 == get_gas_committed_for_next_epoch(), 1);

        // check user balance after registered new task
        let registry_fee_address = get_registry_fee_address();
        let user_address = address_of(user);
        let registration_charges = FLAT_REGISTRATION_FEE_TEST + automation_fee_cap;
        let expected_current_balance = ACCOUNT_BALANCE - registration_charges;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE + registration_charges;
        check_account_balance(user_address, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        // Start new epoch
        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST_IN_SECS);
        on_new_epoch();

        // 0.002 - automation_epoch_fee_per_second, 7200 epoch duration
        let expected_automation_fee = 2000 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100000;
        expected_current_balance = expected_current_balance - expected_automation_fee;
        expected_registry_balance = expected_registry_balance + expected_automation_fee;
        check_account_balance(user_address, expected_current_balance);
        check_account_balance( registry_fee_address, expected_registry_balance );

        // Task is active state and after cancelling it, status will be update to cancelled
        cancel_task(user, 0);
        assert!(has_task_with_id(0), 1);
        assert!(0 == get_gas_committed_for_next_epoch(), 1);

        // balance is keep remain same
        check_account_balance(user_address, expected_current_balance);
        check_account_balance(registry_fee_address, expected_registry_balance);

        // After cancelling the task, the user stops it after 50% of the next epoch has passed.
        timestamp::update_global_time_for_test_secs(
            EPOCH_INTERVAL_FOR_TEST_IN_SECS + (EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2)
        );

        stop_tasks(user, vector[0]);
        assert!(!has_task_with_id(0), 1);
        assert!(0 == get_gas_committed_for_next_epoch(), 1);

        // Because the on of the task stopped after 50% epoch time passed, the user gets a 50% refund for the unused time.
        // which is equivalent to a 25% refund of the full epoch for single task + refund of deposited amount upon registration
        let refund_automation_fee = (2000 * EPOCH_INTERVAL_FOR_TEST_IN_SECS / 100000) / 4 + automation_fee_cap;
        check_account_balance( user_address, expected_current_balance + refund_automation_fee );
        check_account_balance( registry_fee_address, expected_registry_balance - refund_automation_fee );
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_bookkeeping_refunds_and_unlocks(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let automation_fee_cap = 1000;

        let user_address = address_of(user);
        let fwk_address = address_of(framework);


        register(user,
            PAYLOAD,
            86400,
            2000,
            200,
            automation_fee_cap,
            PARENT_HASH,
            AUX_DATA
        );
        let refund_bookkeeping = borrow_global_mut<AutomationRefundBookkeeping>(fwk_address);

        let expected_user_balance = ACCOUNT_BALANCE - automation_fee_cap - FLAT_REGISTRATION_FEE_TEST;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE + automation_fee_cap + FLAT_REGISTRATION_FEE_TEST;
        check_account_balance(user_address, expected_user_balance);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);

        let automation_registry = borrow_global<AutomationRegistry>(fwk_address);
        let resource_address = automation_registry.registry_fee_address;
        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        let expected_total_locked = automation_fee_cap;

        assert!(refund_bookkeeping.total_deposited_automation_fee == expected_total_locked, 2);
        // refund only 10 % and unlock half of the initial deposit;
        let refund = automation_fee_cap / 10;
        let unlock = automation_fee_cap / 2;
        let result = safe_deposit_refund(
            refund_bookkeeping,
            &resource_signer,
            resource_address,
            0,
            user_address,
            refund,
            unlock);
        assert!(result, 1);

        expected_user_balance = expected_user_balance + refund;
        expected_registry_balance = expected_registry_balance - refund;
        expected_total_locked = expected_total_locked - unlock;

        check_account_balance(user_address, expected_user_balance);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);
        assert!(refund_bookkeeping.total_deposited_automation_fee == expected_total_locked, 2);

        // try to refund availbale amount but unlock more than is locked balance
        // Niether unlock nor refund should succeed.
        let result = safe_deposit_refund(
            refund_bookkeeping,
            &resource_signer,
            resource_address,
            0,
            user_address,
            refund,
            automation_fee_cap);
        assert!(!result, 3);

        check_account_balance(user_address, expected_user_balance);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);
        assert!(refund_bookkeeping.total_deposited_automation_fee == expected_total_locked, 4);

        // try to refund more then registry account has but unlock acceptable amount of deposit.
        // Unlock will succeed but not refund.
        let result = safe_deposit_refund(
            refund_bookkeeping,
            &resource_signer,
            resource_address,
            0,
            user_address,
            expected_registry_balance + automation_fee_cap,
            unlock);
        assert!(!result, 4);

        check_account_balance(user_address, expected_user_balance);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);
        assert!(refund_bookkeeping.total_deposited_automation_fee == 0, 5);
    }

    #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_epoch_fee_refunds_and_unlocks(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry {
        initialize_registry_test(framework, user);
        let locked_epoch_fee = 1000;

        let user_address = address_of(user);
        let fwk_address = address_of(framework);

        let automation_registry = borrow_global_mut<AutomationRegistry>(fwk_address);
        automation_registry.epoch_locked_fees = locked_epoch_fee;

        let expected_user_balance = ACCOUNT_BALANCE;
        let expected_registry_balance = REGISTRY_DEFAULT_BALANCE;

        let resource_address = automation_registry.registry_fee_address;
        let resource_signer = account::create_signer_with_capability(
            &automation_registry.registry_fee_address_signer_cap
        );
        // refund only 10 % and unlock half of the initial deposit;
        let refund = locked_epoch_fee / 10;
        let (result, remaining_epoch_locked_fees) = safe_fee_refund(
            automation_registry.epoch_locked_fees,
            &resource_signer,
            resource_address,
            0,
            user_address,
            refund, );
        assert!(result, 1);

        expected_user_balance = expected_user_balance + refund;
        expected_registry_balance = expected_registry_balance - refund;
        let expected_total_locked = locked_epoch_fee - refund;

        check_account_balance(user_address, expected_user_balance);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);
        assert!(remaining_epoch_locked_fees == expected_total_locked, 2);

        // try to refund more than locked
        // Niether unlock nor refund should succeed.
        let (result, remaining_epoch_locked_fees) = safe_fee_refund(
            remaining_epoch_locked_fees,
            &resource_signer,
            resource_address,
            0,
            user_address,
            locked_epoch_fee,
            );
        assert!(!result, 3);

        check_account_balance(user_address, expected_user_balance);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);
        assert!(remaining_epoch_locked_fees == expected_total_locked, 4);

        // Assume there is no enough balance to refund the epoch fee in registry account.
        // No refund but fee is unlocked.
        let epoch_locked_fees = REGISTRY_DEFAULT_BALANCE;

        let (result, remaining_epoch_locked_fees) = safe_fee_refund(
            epoch_locked_fees,
            &resource_signer,
            resource_address,
            0,
            user_address,
            expected_registry_balance + 1,
        );
        assert!(!result, 3);

        check_account_balance(user_address, expected_user_balance);
        check_account_balance(get_registry_fee_address(), expected_registry_balance);
        assert!(remaining_epoch_locked_fees == epoch_locked_fees - expected_registry_balance - 1, 4);
    }


    // Register 500 tasks to measure registration time/used-gas
    #[test_only]
    fun task_registration_performance(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        initialize_registry_test(framework, user);
        let count = 0;
        let exp_time = EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 2;
        while (count < 500) {
            register(user,
                PAYLOAD,
                exp_time + EPOCH_INTERVAL_FOR_TEST_IN_SECS * (count / 2),
                10000,
                20,
                1000000,
                PARENT_HASH,
                AUX_DATA
            );
            count = count + 1;
        };

        // No active task and committed gas for the next epoch is total of the all registered tasks
        assert!(10000 * 500 == get_gas_committed_for_next_epoch(), 1);
        let active_task_ids = get_active_task_ids();
        assert!(active_task_ids == vector[], 1);
    }

    #[test_only]
    // Kept only for performance analysis intentions
    // Register 500 tasks to measure registration time/used-gas
    // #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_registration_performance(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping {
        task_registration_performance(framework, user);
    }

    #[test_only]
    // Kept only for performance analysis intentions
    // Register 500 tasks with 1.5 EPOCH_INTERVAL duration/expiration time
    // And run 3 epochs to check gas-used when
    //  - full epoch passed
    //  - 1/3 of epoch passed to simulate refund, but tasks are still active
    //  - last epoch identifies all tasks are expired
    // #[test(framework = @supra_framework, user = @0x1cafe)]
    fun check_task_activation_on_new_epoch_performance(
        framework: &signer,
        user: &signer
    ) acquires AutomationRegistry, ActiveAutomationRegistryConfig, AutomationRefundBookkeeping, AutomationCycleDetails {
        task_registration_performance(framework, user);

        timestamp::update_global_time_for_test_secs(EPOCH_INTERVAL_FOR_TEST_IN_SECS);
        on_new_epoch();
        timestamp::update_global_time_for_test_secs(
            EPOCH_INTERVAL_FOR_TEST_IN_SECS + EPOCH_INTERVAL_FOR_TEST_IN_SECS / 3
        );
        on_new_epoch();
        timestamp::update_global_time_for_test_secs(2 * EPOCH_INTERVAL_FOR_TEST_IN_SECS);
        on_new_epoch();
    }

    #[test]
    fun check_monitor_cycle_end() acquires AutomationCycleDetails, ActiveAutomationRegistryConfig, AutomationRegistry {
        monitor_cycle_end()
    }

}


