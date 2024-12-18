/// Supra Automation Registry
///
/// This contract is part of the Supra Framework and is designed to manage automated task entries
module supra_framework::automation_registry {

    use std::signer;
    use supra_framework::event;
    use supra_framework::automation_registry_state::{Self, AutomationTaskMetaData};

    use supra_framework::account::{Self, SignerCapability};
    use supra_framework::block;
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

    /// Invalid expiry time: it cannot be earlier than the current time
    const EINVALID_EXPIRY_TIME: u64 = 1;
    /// Expiry time does not go beyond upper cap duration
    const EEXPIRY_TIME_UPPER: u64 = 2;
    /// Expiry time must be after the start of the next epoch
    const EEXPIRY_BEFORE_NEXT_EPOCH: u64 = 3;
    /// Invalid gas price: it cannot be zero
    const EINVALID_GAS_PRICE: u64 = 4;

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


    // todo : this function should call during initialzation, but since we already done genesis in that case who can access the function
    public fun initialize(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        automation_registry_state::initialize(supra_framework, DEFAULT_AUTOMATION_GAS_LIMIT);

        let (registry_fee_resource_signer, registry_fee_address_signer_cap) = account::create_resource_account(
            supra_framework,
            REGISTRY_RESOURCE_SEED
        );

        move_to(supra_framework, AutomationRegistry {
            duration_upper_limit: DEFAULT_DURATION_UPPER_LIMIT,
            gas_committed_for_next_epoch: 0,
            automation_unit_price: DEFAULT_AUTOMATION_UNIT_PRICE,
            registry_fee_address: signer::address_of(&registry_fee_resource_signer),
            registry_fee_address_signer_cap,
        })
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
    ) {
        system_addresses::assert_supra_framework(supra_framework);
        automation_registry_state::update_automation_gas_limit(supra_framework, automation_gas_limit)
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

        //Well formedness check of payload_tx is done in native layer beforehand.

        let current_time = timestamp::now_seconds();
        assert!(expiry_time > current_time, EINVALID_EXPIRY_TIME);

        let expiry_time_duration = expiry_time - current_time;
        assert!(expiry_time_duration < registry_data.duration_upper_limit, EEXPIRY_TIME_UPPER);

        let epoch_interval = block::get_epoch_interval_secs();
        let last_epoch_time = get_last_epoch_time_second();
        assert!(expiry_time > (last_epoch_time + epoch_interval), EEXPIRY_BEFORE_NEXT_EPOCH);


        assert!(gas_price_cap > 0, EINVALID_GAS_PRICE);

        let fee = expiry_time_duration * registry_data.automation_unit_price;
        charge_automation_fee_from_user(owner, fee);

        let epoch = reconfiguration::current_epoch();
        let parent_hash = transaction_context::txn_app_hash();
        automation_registry_state::register(
            owner,
            payload_tx,
            expiry_time,
            max_gas_amount,
            gas_price_cap,
            epoch,
            parent_hash);
    }

    /// Remove Automatioon task entry.
    public entry fun remove_task(owner: &signer, id: u64) acquires AutomationRegistry {
        let automation_registry = borrow_global_mut<AutomationRegistry>(@supra_framework);
        let automation_task_metadata = automation_registry_state::remove_task(owner, id);
        refund_automation_task_fee(signer::address_of(owner), automation_task_metadata, automation_registry.automation_unit_price);
    }

    /// Refunds the automation task fee to the user who has removed their task registration from the list.
    fun refund_automation_task_fee(
        user: address,
        automation_task_metadata: AutomationTaskMetaData,
        automation_unit_price: u64,
    ) acquires AutomationRegistry {
        let current_time = timestamp::now_seconds();
        let expiry_time_duration = automation_registry_state::task_expiry_time(&automation_task_metadata) - current_time;

        let refund_amount = expiry_time_duration * automation_unit_price;
        transfer_fee_to_account_internal(user, refund_amount);
        event::emit(RefundFeeUser { user, amount: refund_amount });
    }

    #[view]
    /// Returns next task index in registry
    public fun get_next_task_index(): u64 {
        automation_registry_state::get_next_task_index()
    }

    #[view]
    /// List all the automation task ids
    public fun get_active_task_ids(): vector<u64> {
        automation_registry_state::get_active_task_ids()
    }

    #[view]
    /// Retrieves the details of a automation task entry by its ID.
    /// Error will be returned if entry with specified ID does not exist.
    public fun get_task_details(id: u64): AutomationTaskMetaData {
        automation_registry_state::get_task_details(id)
    }

    #[view]
    /// Checks whether there is an active task in registry with specified input task id.
    public fun has_active_task_with_id(id: u64): bool {
        automation_registry_state::has_active_task_with_id(id)
    }

    #[view]
    /// Get registry fee resource account address
    public fun get_registry_fee_address(): address {
        account::create_resource_address(&@supra_framework, REGISTRY_RESOURCE_SEED)
    }

    #[view]
    /// Ge gas committed for next epoch
    public fun get_gas_committed_for_next_epoch(): u64 {
        automation_registry_state::get_gas_committed_for_next_epoch()
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
    #[expected_failure(abort_code=196609, location=transaction_context)]
    fun test_registry(supra_framework: &signer, user: &signer) acquires AutomationRegistry {
        initialize_registry_test(supra_framework, user);

        let payload = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f4041424344";
        register(user, payload, 86400, 1000, 100000);
    }
}
