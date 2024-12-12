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

    #[test_only]
    use supra_framework::coin;
    #[test_only]
    use supra_framework::supra_coin::{Self, SupraCoin};

    friend supra_framework::genesis;

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
    /// Automation task not found
    const EAUTOMATION_TASK_NOT_EXIST: u64 = 7;
    /// Unauthorized access: the caller is not the owner of the task
    const EUNAUTHORIZED_TASK_OWNER: u64 = 8;

    /// The default automation task gas limit
    const DEFAULT_AUTOMATION_GAS_LIMIT: u64 = 100000000;
    /// The default upper limit duration for automation task, specified in seconds (30 days).
    const DEFAULT_DURATION_UPPER_LIMIT: u64 = 2592000;
    /// The default Automation unit price for per second, in Quants
    const DEFAULT_AUTOMATION_UNIT_PRICE: u64 = 1000;
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
        /// Automation task unit price per second
        automation_unit_price: u64,
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
    /// Update automation gas limit event
    struct UpdateAutomationGasLimit has drop, store {
        automation_gas_limit: u64
    }

    #[event]
    /// Update duration upper limit event
    struct UpdateDurationUpperLimit has drop, store {
        duration_upper_limit: u64
    }

    #[event]
    /// Remove automation task registry event
    struct RemoveAutomationTask has drop, store {
        id: u64
    }

    // todo : this function should call during initialzation, but since we already done genesis in that case who can access the function
    public fun initialize(supra_framework: &signer) {
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
            automation_unit_price: DEFAULT_AUTOMATION_UNIT_PRICE,
            registry_fee_address: signer::address_of(&registry_fee_resource_signer),
            registry_fee_address_signer_cap,
            tasks: enumerable_map::new_map(),
        })
    }

    public(friend) fun on_new_epoch(supra_framework: &signer) acquires AutomationRegistry {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let ids = enumerable_map::get_map_list(&automation_registry.tasks);

        let current_time = timestamp::now_seconds();
        let epoch_interval = block::get_epoch_interval_secs();
        let expired_task_gas = 0;

        // Perform clean up and updation of state
        vector::for_each(ids, |id| {
            let task = enumerable_map::get_value_mut(&mut automation_registry.tasks, id);

            // Tasks that are active during this new epoch but will be already expired for the next epoch
            if (task.expiry_time < (current_time + epoch_interval)) {
                expired_task_gas = expired_task_gas + task.max_gas_amount;
            };

            if (task.expiry_time <= current_time) {
                enumerable_map::remove_value(&mut automation_registry.tasks, id);
            } else if (!task.is_active && task.expiry_time > current_time) {
                task.is_active = true;
            }
        });

        // Adjust the gas committed for the next epoch by subtracting the gas amount of the expired task
        automation_registry.gas_committed_for_next_epoch = automation_registry.gas_committed_for_next_epoch - expired_task_gas;
    }

    /// Withdraw accumulated automation task fees from the resource account - access by admin
    entry fun withdraw_automation_task_fees(
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

    /// Update Automation gas limit
    public entry fun update_automation_gas_limit(
        supra_framework: &signer,
        automation_gas_limit: u64
    ) acquires AutomationRegistry {
        system_addresses::assert_supra_framework(supra_framework);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
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
    fun charge_automation_fee_from_user(owner: &signer, fee: u64) {
        // todo : dynamic price calculation is pending
        let registry_fee_address = get_registry_fee_address();
        supra_account::transfer(owner, registry_fee_address, fee);
    }

    /// Get last epoch time in second
    fun get_last_epoch_time_second(): u64 {
        let last_epoch_time_ms = reconfiguration::last_reconfiguration_time() / MILLISECOND_CONVERSION_FACTOR;
        last_epoch_time_ms / MILLISECOND_CONVERSION_FACTOR
    }

    /// Registers a new automation task entry.
    public fun register(
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

        let expiry_time_duration = expiry_time - current_time;
        assert!(expiry_time_duration < registry_data.duration_upper_limit, EEXPIRY_TIME_UPPER);

        let epoch_interval = block::get_epoch_interval_secs();
        let last_epoch_time = get_last_epoch_time_second();
        assert!(expiry_time > (last_epoch_time + epoch_interval), EEXPIRY_BEFORE_NEXT_EPOCH);

        registry_data.gas_committed_for_next_epoch = registry_data.gas_committed_for_next_epoch + max_gas_amount;
        assert!(registry_data.gas_committed_for_next_epoch < registry_data.automation_gas_limit, EGAS_AMOUNT_UPPER);

        assert!(gas_price_cap > 0, EINVALID_GAS_PRICE);

        let fee = expiry_time_duration * registry_data.automation_unit_price;
        charge_automation_fee_from_user(owner, fee);

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

    /// Remove Automatioon task entry.
    public entry fun remove_task(owner: &signer, registry_id: u64) acquires AutomationRegistry {
        let user_addr = signer::address_of(owner);

        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        assert!(enumerable_map::contains(&automation_registry.tasks, registry_id), EAUTOMATION_TASK_NOT_EXIST);

        let automation_task_metadata = enumerable_map::get_value(&automation_registry.tasks, registry_id);
        assert!(automation_task_metadata.owner == user_addr, EUNAUTHORIZED_TASK_OWNER);

        enumerable_map::remove_value(&mut automation_registry.tasks, registry_id);

        // Adjust the gas committed for the next epoch by subtracting the gas amount of the expired task
        automation_registry.gas_committed_for_next_epoch = automation_registry.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

        // Calculate refund fee and transfer it to user
        refund_automation_task_fee(user_addr, automation_task_metadata, automation_registry.automation_unit_price);

        event::emit(RemoveAutomationTask { id: automation_task_metadata.id });
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

    #[view]
    /// List all the automation task ids
    public fun get_next_task_index(): u64 acquires AutomationRegistry {
        let automation_registry = borrow_global<AutomationRegistry>(@supra_framework);
        automation_registry.current_index + 1
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
    /// Get registry fee resource account address
    public fun get_registry_fee_address(): address {
        account::create_resource_address(&@supra_framework, REGISTRY_RESOURCE_SEED)
    }

    #[view]
    /// Ge gas committed for next epoch
    public fun get_gas_committed_for_next_epoch(): u64 acquires AutomationRegistry {
        let automation_task_metadata = borrow_global<AutomationRegistry>(@supra_framework);
        automation_task_metadata.gas_committed_for_next_epoch
    }

    #[test_only]
    fun initialize_registry_test(supra_framework: &signer, user: &signer) {
        let user_addr = signer::address_of(user);
        account::create_account_for_test(user_addr);
        account::create_account_for_test(@supra_framework);

        let (burn_cap, mint_cap) = supra_coin::initialize_for_test(supra_framework);
        coin::register<SupraCoin>(user);
        supra_coin::mint(supra_framework, user_addr, 100000000);
        coin::destroy_burn_cap(burn_cap);
        coin::destroy_mint_cap(mint_cap);

        block::initialize_for_test(supra_framework, 7200000000);
        timestamp::set_time_has_started_for_testing(supra_framework);
        reconfiguration::initialize_for_test(supra_framework);

        initialize(supra_framework);
    }

    #[test(supra_framework = @supra_framework, user = @0x1cafe)]
    fun test_registry(supra_framework: &signer, user: &signer) acquires AutomationRegistry {
        initialize_registry_test(supra_framework, user);

        let payload = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f4041424344";
        register(user, payload, 86400, 1000, 100000);
    }
}
