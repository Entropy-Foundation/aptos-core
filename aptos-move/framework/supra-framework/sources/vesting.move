///
/// Simple vesting contract that allows specifying how much SUPRA coins should be vesting in each fixed-size period. The
/// vesting contract also comes with staking and allows shareholders to withdraw rewards anytime.
///
/// Vesting schedule is represented as a vector of distributions. For example, a vesting schedule of
/// [3/48, 3/48, 1/48] means that after the vesting starts:
/// 1. The first and second periods will vest 3/48 of the total original grant.
/// 2. The third period will vest 1/48.
/// 3. All subsequent periods will also vest 1/48 (last distribution in the schedule) until the original grant runs out.
///
/// Shareholder flow:
/// 1. Admin calls create_vesting_contract with a schedule of [3/48, 3/48, 1/48] with a vesting cliff of 1 year and
/// vesting period of 1 month.
/// 2. After a month, a shareholder calls unlock_rewards to request rewards. They can also call vest() which would also
/// unlocks rewards but since the 1 year cliff has not passed (vesting has not started), vest() would not release any of
/// the original grant.
/// 3. After the unlocked rewards become fully withdrawable (as it's subject to staking lockup), shareholders can call
/// distribute() to send all withdrawable funds to all shareholders based on the original grant's shares structure.
/// 4. After 1 year and 1 month, the vesting schedule now starts. Shareholders call vest() to unlock vested coins. vest()
/// checks the schedule and unlocks 3/48 of the original grant in addition to any accumulated rewards since last
/// unlock_rewards(). Once the unlocked coins become withdrawable, shareholders can call distribute().
/// 5. Assuming the shareholders forgot to call vest() for 2 months, when they call vest() again, they will unlock vested
/// tokens for the next period since last vest. This would be for the first month they missed. They can call vest() a
/// second time to unlock for the second month they missed.
///
/// Admin flow:
/// 1. After creating the vesting contract, admin cannot change the vesting schedule.
/// 2. Admin can call update_voter, update_operator, or reset_lockup at any time to update the underlying staking
/// contract.
/// 3. Admin can also call update_beneficiary for any shareholder. This would send all distributions (rewards, vested
/// coins) of that shareholder to the beneficiary account. By defalt, if a beneficiary is not set, the distributions are
/// send directly to the shareholder account.
/// 4. Admin can call terminate_vesting_contract to terminate the vesting. This would first finish any distribution but
/// will prevent any further rewards or vesting distributions from being created. Once the locked up stake becomes
/// withdrawable, admin can call admin_withdraw to withdraw all funds to the vesting contract's withdrawal address.
module supra_framework::vesting {
    use std::bcs;
    use std::error;
    use std::fixed_point32::{Self, FixedPoint32};
    use std::signer;
    use std::string::{utf8, String};
    use std::vector;

    use aptos_std::pool_u64::{Self, Pool};
    use aptos_std::simple_map::{Self, SimpleMap};

    use supra_framework::account::{Self, SignerCapability, new_event_handle};
    use supra_framework::supra_account::{Self, assert_account_is_registered_for_supra};
    use supra_framework::supra_coin::SupraCoin;
    use supra_framework::coin::{Self, Coin};
    use supra_framework::event::{EventHandle, emit, emit_event};
    use supra_framework::stake;
    use supra_framework::staking_contract;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;

    friend supra_framework::genesis;

    const VESTING_POOL_SALT: vector<u8> = b"supra_framework::vesting";

    /// Withdrawal address is invalid.
    const EINVALID_WITHDRAWAL_ADDRESS: u64 = 1;
    /// Vesting schedule cannot be empty.
    const EEMPTY_VESTING_SCHEDULE: u64 = 2;
    /// Vesting period cannot be 0.
    const EZERO_VESTING_SCHEDULE_PERIOD: u64 = 3;
    /// Shareholders list cannot be empty.
    const ENO_SHAREHOLDERS: u64 = 4;
    /// The length of shareholders and shares lists don't match.
    const ESHARES_LENGTH_MISMATCH: u64 = 5;
    /// Vesting cannot start before or at the current block timestamp. Has to be in the future.
    const EVESTING_START_TOO_SOON: u64 = 6;
    /// The signer is not the admin of the vesting contract.
    const ENOT_ADMIN: u64 = 7;
    /// Vesting contract needs to be in active state.
    const EVESTING_CONTRACT_NOT_ACTIVE: u64 = 8;
    /// Admin can only withdraw from an inactive (paused or terminated) vesting contract.
    const EVESTING_CONTRACT_STILL_ACTIVE: u64 = 9;
    /// No vesting contract found at provided address.
    const EVESTING_CONTRACT_NOT_FOUND: u64 = 10;
    /// Cannot terminate the vesting contract with pending active stake. Need to wait until next epoch.
    const EPENDING_STAKE_FOUND: u64 = 11;
    /// Grant amount cannot be 0.
    const EZERO_GRANT: u64 = 12;
    /// Vesting account has no other management roles beside admin.
    const EVESTING_ACCOUNT_HAS_NO_ROLES: u64 = 13;
    /// The vesting account has no such management role.
    const EROLE_NOT_FOUND: u64 = 14;
    /// Account is not admin or does not have the required role to take this action.
    const EPERMISSION_DENIED: u64 = 15;
    /// Zero items were provided to a *_many function.
    const EVEC_EMPTY_FOR_MANY_FUNCTION: u64 = 16;
    /// Deprecated
    const EDEPRECATED: u64 = 17;

    /// Maximum number of shareholders a vesting pool can support.
    const MAXIMUM_SHAREHOLDERS: u64 = 30;

    /// Vesting contract states.
    /// Vesting contract is active and distributions can be made.
    const VESTING_POOL_ACTIVE: u64 = 1;
    /// Vesting contract has been terminated and all funds have been released back to the withdrawal address.
    const VESTING_POOL_TERMINATED: u64 = 2;

    /// Roles that can manage certain aspects of the vesting account beyond the main admin.
    const ROLE_BENEFICIARY_RESETTER: vector<u8> = b"ROLE_BENEFICIARY_RESETTER";

    struct VestingSchedule has copy, drop, store {
        // The vesting schedule as a list of fractions that vest for each period. The last number is repeated until the
        // vesting amount runs out.
        // For example [1/24, 1/24, 1/48] with a period of 1 month means that after vesting starts, the first two months
        // will vest 1/24 of the original total amount. From the third month only, 1/48 will vest until the vesting fund
        // runs out.
        // u32/u32 should be sufficient to support vesting schedule fractions.
        schedule: vector<FixedPoint32>,
        // When the vesting should start.
        start_timestamp_secs: u64,
        // In seconds. How long each vesting period is. For example 1 month.
        period_duration: u64,
        // Last vesting period, 1-indexed. For example if 2 months have passed, the last vesting period, if distribution
        // was requested, would be 2. Default value is 0 which means there have been no vesting periods yet.
        last_vested_period: u64,
    }

    struct StakingInfo has store {
        // Where the vesting's stake pool is located at. Included for convenience.
        pool_address: address,
        // The currently assigned operator.
        operator: address,
        // The currently assigned voter.
        voter: address,
        // Commission paid to the operator of the stake pool.
        commission_percentage: u64,
    }

    struct VestingContract has key {
        state: u64,
        admin: address,
        grant_pool: Pool,
        beneficiaries: SimpleMap<address, address>,
        vesting_schedule: VestingSchedule,
        // Withdrawal address where all funds would be released back to if the admin ends the vesting for a specific
        // account or terminates the entire vesting contract.
        withdrawal_address: address,
        staking: StakingInfo,
        // Remaining amount in the grant. For calculating accumulated rewards.
        remaining_grant: u64,
        // Used to control staking.
        signer_cap: SignerCapability,

        // Events.
        update_operator_events: EventHandle<UpdateOperatorEvent>,
        update_voter_events: EventHandle<UpdateVoterEvent>,
        reset_lockup_events: EventHandle<ResetLockupEvent>,
        set_beneficiary_events: EventHandle<SetBeneficiaryEvent>,
        unlock_rewards_events: EventHandle<UnlockRewardsEvent>,
        vest_events: EventHandle<VestEvent>,
        distribute_events: EventHandle<DistributeEvent>,
        terminate_events: EventHandle<TerminateEvent>,
        admin_withdraw_events: EventHandle<AdminWithdrawEvent>,
    }

    struct VestingAccountManagement has key {
        roles: SimpleMap<String, address>,
    }

    struct AdminStore has key {
        vesting_contracts: vector<address>,
        // Used to create resource accounts for new vesting contracts so there's no address collision.
        nonce: u64,

        create_events: EventHandle<CreateVestingContractEvent>,
    }

    #[event]
    struct CreateVestingContract has drop, store {
        operator: address,
        voter: address,
        grant_amount: u64,
        withdrawal_address: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        commission_percentage: u64,
    }

    #[event]
    struct UpdateOperator has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        old_operator: address,
        new_operator: address,
        commission_percentage: u64,
    }

    #[event]
    struct UpdateVoter has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        old_voter: address,
        new_voter: address,
    }

    #[event]
    struct ResetLockup has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        new_lockup_expiration_secs: u64,
    }

    #[event]
    struct SetBeneficiary has drop, store {
        admin: address,
        vesting_contract_address: address,
        shareholder: address,
        old_beneficiary: address,
        new_beneficiary: address,
    }

    #[event]
    struct UnlockRewards has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        amount: u64,
    }

    #[event]
    struct Vest has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        period_vested: u64,
        amount: u64,
    }

    #[event]
    struct Distribute has drop, store {
        admin: address,
        vesting_contract_address: address,
        amount: u64,
    }

    #[event]
    struct Terminate has drop, store {
        admin: address,
        vesting_contract_address: address,
    }

    #[event]
    struct AdminWithdraw has drop, store {
        admin: address,
        vesting_contract_address: address,
        amount: u64,
    }

    struct CreateVestingContractEvent has drop, store {
        operator: address,
        voter: address,
        grant_amount: u64,
        withdrawal_address: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        commission_percentage: u64,
    }

    struct UpdateOperatorEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        old_operator: address,
        new_operator: address,
        commission_percentage: u64,
    }

    struct UpdateVoterEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        old_voter: address,
        new_voter: address,
    }

    struct ResetLockupEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        new_lockup_expiration_secs: u64,
    }

    struct SetBeneficiaryEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        shareholder: address,
        old_beneficiary: address,
        new_beneficiary: address,
    }

    struct UnlockRewardsEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        amount: u64,
    }

    struct VestEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        staking_pool_address: address,
        period_vested: u64,
        amount: u64,
    }

    struct DistributeEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        amount: u64,
    }

    struct TerminateEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
    }

    struct AdminWithdrawEvent has drop, store {
        admin: address,
        vesting_contract_address: address,
        amount: u64,
    }

    #[deprecated]
    #[view]
    /// Return the address of the underlying stake pool (separate resource account) of the vesting contract.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun stake_pool_address(vesting_contract_address: address): address {
        abort error::unavailable(EDEPRECATED);
        vesting_contract_address // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the vesting start timestamp (in seconds) of the vesting contract.
    /// Vesting will start at this time, and once a full period has passed, the first vest will become unlocked.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun vesting_start_secs(vesting_contract_address: address): u64 {
        abort error::unavailable(EDEPRECATED);
        0 // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the duration of one vesting period (in seconds).
    /// Each vest is released after one full period has started, starting from the specified start_timestamp_secs.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun period_duration_secs(vesting_contract_address: address): u64 {
        abort error::unavailable(EDEPRECATED);
        0 // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the remaining grant, consisting of unvested coins that have not been distributed to shareholders.
    /// Prior to start_timestamp_secs, the remaining grant will always be equal to the original grant.
    /// Once vesting has started, and vested tokens are distributed, the remaining grant will decrease over time,
    /// according to the vesting schedule.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun remaining_grant(vesting_contract_address: address): u64 {
        abort error::unavailable(EDEPRECATED);
        0
    }

    #[deprecated]
    #[view]
    /// Return the beneficiary account of the specified shareholder in a vesting contract.
    /// This is the same as the shareholder address by default and only different if it's been explicitly set.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun beneficiary(vesting_contract_address: address, shareholder: address): address {
        abort error::unavailable(EDEPRECATED);
        shareholder // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the percentage of accumulated rewards that is paid to the operator as commission.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun operator_commission_percentage(vesting_contract_address: address): u64 {
        abort error::unavailable(EDEPRECATED);
        0 // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return all the vesting contracts a given address is an admin of.
    public fun vesting_contracts(admin: address): vector<address> {
        abort error::unavailable(EDEPRECATED);
        vector::empty<address>() // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the operator who runs the validator for the vesting contract.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun operator(vesting_contract_address: address): address {
        abort error::unavailable(EDEPRECATED);
        vesting_contract_address // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the voter who will be voting on on-chain governance proposals on behalf of the vesting contract's stake
    /// pool.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun voter(vesting_contract_address: address): address {
        abort error::unavailable(EDEPRECATED);
        vesting_contract_address // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the vesting contract's vesting schedule. The core schedule is represented as a list of u64-based
    /// fractions, where the rightmmost 32 bits can be divided by 2^32 to get the fraction, and anything else is the
    /// whole number.
    ///
    /// For example 3/48, or 0.0625, will be represented as 268435456. The fractional portion would be
    /// 268435456 / 2^32 = 0.0625. Since there are fewer than 32 bits, the whole number portion is effectively 0.
    /// So 268435456 = 0.0625.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun vesting_schedule(vesting_contract_address: address): VestingSchedule {
        abort error::unavailable(EDEPRECATED);
        VestingSchedule {
            schedule: vector::empty<FixedPoint32>(),
            start_timestamp_secs: 0,
            period_duration: 0,
            last_vested_period: 0,
        } // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the total accumulated rewards that have not been distributed to shareholders of the vesting contract.
    /// This excludes any unpaid commission that the operator has not collected.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun total_accumulated_rewards(vesting_contract_address: address): u64 {
        abort error::unavailable(EDEPRECATED);
        0 // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the accumulated rewards that have not been distributed to the provided shareholder. Caller can also pass
    /// the beneficiary address instead of shareholder address.
    ///
    /// This errors out if the vesting contract with the provided address doesn't exist.
    public fun accumulated_rewards(
        vesting_contract_address: address, shareholder_or_beneficiary: address): u64 {
        abort error::unavailable(EDEPRECATED);
        0 // Placeholder return to make the function signature work. This should be removed when the function is implemented.
        }

    #[deprecated]
    #[view]
    /// Return the list of all shareholders in the vesting contract.
    public fun shareholders(vesting_contract_address: address): vector<address> {
        abort error::unavailable(EDEPRECATED);
        vector::empty<address>() // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    #[view]
    /// Return the shareholder address given the beneficiary address in a given vesting contract. If there are multiple
    /// shareholders with the same beneficiary address, only the first shareholder is returned. If the given beneficiary
    /// address is actually a shareholder address, just return the address back.
    ///
    /// This returns 0x0 if no shareholder is found for the given beneficiary / the address is not a shareholder itself.
    public fun shareholder(
        vesting_contract_address: address,
        shareholder_or_beneficiary: address
    ): address {
        abort error::unavailable(EDEPRECATED);
        vesting_contract_address // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    /// Create a vesting schedule with the given schedule of distributions, a vesting start time and period duration.
    public fun create_vesting_schedule(
        schedule: vector<FixedPoint32>,
        start_timestamp_secs: u64,
        period_duration: u64,
    ): VestingSchedule {
        abort error::unavailable(EDEPRECATED);
        VestingSchedule {
            schedule: vector::empty<FixedPoint32>(),
            start_timestamp_secs: 0,
            period_duration: 0,
            last_vested_period: 0,
        } // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    /// Create a vesting contract with a given configurations.
    public fun create_vesting_contract(
        admin: &signer,
        shareholders: &vector<address>,
        buy_ins: SimpleMap<address, Coin<SupraCoin>>,
        vesting_schedule: VestingSchedule,
        withdrawal_address: address,
        operator: address,
        voter: address,
        commission_percentage: u64,
        // Optional seed used when creating the staking contract account.
        contract_creation_seed: vector<u8>,
    ): address {
        abort error::unavailable(EDEPRECATED);
        // Placeholder implementation to make the function signature work. This should be removed when the function is implemented.
        
        let admin_address = signer::address_of(admin);
        let keys = simple_map::keys(&buy_ins);
        vector::for_each_ref(&keys, |shareholder| {
            let (s,c) = simple_map::remove<address, Coin<SupraCoin>>(&mut buy_ins, shareholder);
            let c : Coin<SupraCoin> = c;
            coin::deposit<SupraCoin>(*shareholder, c);
            
        });
        simple_map::destroy_empty<address, Coin<SupraCoin>>(buy_ins);
        voter // Placeholder return to make the function signature work. This should be removed when the function is implemented.
    }

    #[deprecated]
    /// Unlock any accumulated rewards.
    public entry fun unlock_rewards(contract_address: address) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Call `unlock_rewards` for many vesting contracts.
    public entry fun unlock_rewards_many(contract_addresses: vector<address>) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Unlock any vested portion of the grant.
    public entry fun vest(contract_address: address) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Call `vest` for many vesting contracts.
    public entry fun vest_many(contract_addresses: vector<address>) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Distribute any withdrawable stake from the stake pool.
    public entry fun distribute(contract_address: address) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Call `distribute` for many vesting contracts.
    public entry fun distribute_many(contract_addresses: vector<address>) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Terminate the vesting contract and send all funds back to the withdrawal address.
    public entry fun terminate_vesting_contract(admin: &signer, contract_address: address)  {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Withdraw all funds to the preset vesting contract's withdrawal address. This can only be called if the contract
    /// has already been terminated.
    public entry fun admin_withdraw(admin: &signer, contract_address: address)  {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun update_operator(
        admin: &signer,
        contract_address: address,
        new_operator: address,
        commission_percentage: u64,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun update_operator_with_same_commission(
        admin: &signer,
        contract_address: address,
        new_operator: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun update_commission_percentage(
        admin: &signer,
        contract_address: address,
        new_commission_percentage: u64,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun update_voter(
        admin: &signer,
        contract_address: address,
        new_voter: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun reset_lockup(
        admin: &signer,
        contract_address: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun set_beneficiary(
        admin: &signer,
        contract_address: address,
        shareholder: address,
        new_beneficiary: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Remove the beneficiary for the given shareholder. All distributions will sent directly to the shareholder
    /// account.
    public entry fun reset_beneficiary(
        account: &signer,
        contract_address: address,
        shareholder: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun set_management_role(
        admin: &signer,
        contract_address: address,
        role: String,
        role_holder: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public entry fun set_beneficiary_resetter(
        admin: &signer,
        contract_address: address,
        beneficiary_resetter: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    /// Set the beneficiary for the operator.
    public entry fun set_beneficiary_for_operator(
        operator: &signer,
        new_beneficiary: address,
    ) {
        abort error::unavailable(EDEPRECATED);
    }

    #[deprecated]
    public fun get_role_holder(contract_address: address, role: String): address {
        abort error::unavailable(EDEPRECATED);
        contract_address // Placeholder return to make the function signature work. This should be removed when the function is implemented.    
    }

    /// For emergency use in case the admin needs emergency control of vesting contract account.
    /// This doesn't give the admin total power as the admin would still need to follow the rules set by
    /// staking_contract and stake modules.
    #[deprecated]
    public fun get_vesting_account_signer(admin: &signer, contract_address: address): signer acquires VestingContract {
        abort error::unavailable(EDEPRECATED);
        // Placeholder implementation to make the function signature work. This should be removed when the function is implemented.
        let _ = borrow_global<VestingContract>(contract_address);
        let seed = bcs::to_bytes(&signer::address_of(admin));

        let (s,s_cap) = account::create_resource_account(admin, seed);
        s
    }

    }
