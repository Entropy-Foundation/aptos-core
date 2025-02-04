/**
 This is the Proof of Efficiency Liquidity module used to delagate $supra to staking pools for users
 who hold iEth by making deposits of ETH to the intralayer vault. It handles the creation of the iETH and distribution to the
 corresponding addresses on supra

 General Flow:
Although these steps refer to ETH, the Proof of Efficient Liquidity (PoEL) approach can be applied similarly to other assets:
1. Users deposit WETH into the Intralayer Vault on the Ethereum blockchain.
2. The Supra cross-chain communication protocol forwards the deposit information to the PoEL (Proof of Efficient Liquidity) contract on the Supra chain.
3. This step moves the borrowing request to the pre-processing stage, where the request to rent Supra using ETH is registered. Additionally, the mechanism
pre-mints a special token called iETH to the user’s address. This iETH serves as a “coupon” representing the user’s share of the original ETH deposited in the Intralayer Vault.
4. Periodically, the protocol processes borrow requests, taking into account:
    a. All available borrow requests
    b. Price fluctuations of the underlying asset (based on an oracle price submitted to the PoEL contract)
    c. Asset characteristics such as collateralization rates and desirability scores
The total amount lent through the PoEL contract depends on these factors. If the price of the asset (relative to $Supra) increases, the system rents and delegates more 
tokens to the delegation pools. Conversely, if the price falls, the system reduces the lent amount and withdraws tokens from the pools. During delegation, 
the rented tokens are evenly distributed across various delegation pools participating in the system.
5. After lending and delegation are finalized, users can convert their pre-minted iETH into actual assets that they can manage directly.
6. The delegated tokens earn staking rewards, which are distributed to iETH holders(for minted tokens) via the reward_distribution module.
7. Users can redeem iETH to reclaim ETH from the Intralayer Vault on the Ethereum blockchain. To do so, they submit a withdrawal request to the PoEL contract,
which burns their iETH and moves the request into the pre-processing stage.
8. Redemption requests are processed alongside new borrow requests. If the remeption requested amount > borrow requested amount, this process decreases the overall rented 
amount and unstakes the corresponding tokens from the delegation pools.
After redemption requests have been processed, users can withdraw their ETH from the system, receiving the assets on the Ethereum blockchain.
 */

module supra_framework::poel {
    use aptos_std::object::{Self, ExtendRef};
    use aptos_std::vector;
    use aptos_std::signer;
    use aptos_std::smart_table::{Self, SmartTable};
    use aptos_std::error;
    use supra_framework::iAsset::{
        mint_iAsset, premint_iAsset, update_asset_price_supply,
        update_single_asset_supply, get_liquidity_table_items, asset_metadata,
        calculate_collaterisation_rate, calculate_total_rentable, get_assets, get_total_liquidity,
        get_asset_price, poel_update_olc_index, update_borrow_request
    };
    use supra_framework::reward_distribution::update_reward_index;
    use supra_framework::pbo_delegation_pool::{unlock, add_stake, withdraw, get_pending_withdrawal, get_stake};
    use supra_framework::coin;
    use supra_framework::supra_coin::SupraCoin;

    use supra_framework::timestamp;

    /// thrown when the allowed signer is not the caller (owner)
    const ENOT_OWNER: u64 = 1;

    /// thrown when the wrong asset weight gets calculated
    const EWRONG_WEIGHT: u64 = 2;

    /// thrown when the length of the collaterixation weight vector does not match table entries
    const EWRONG_CWV_LENGTH: u64 = 3;

    /// thrown when the length of the desirability_score_vector does not match table entries
    const EWRONG_DESIRABILITY_SCORE_LEN: u64 = 4;

    /// thrown If coefficient_m < coefficient_k
    const ECOEFM_LT_COEFK: u64 = 5;

    /// thrown when insificient balance
    const EINSUFICIENT_CALLER_BALANCE: u64 = 6;

    /// thrown when the reward balance is wrong
    const EWRONG_REWARD_BALANCE: u64 = 7;

    /// thrown when the caller s not the bridge address
    const EBRIDGE_NOT_PRESENT: u64 = 8;

    /// thrown when calling a second initialization of the bridges
    const EBRIDGE_INITIALIZED: u64 = 9;

    /// seed  for the total liquidity object for easy access
    const POEL_STORAGE_ADDRESS: vector<u8> = b"PoELStorageGlobal";


    //Is applied for the dynamic adjustment of the system's operational parameters. It allows for flexible management of financial metrics, adapting to market conditions or strategic shifts in policy.
    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct MutableParameters has key { 
        coefficient_k: u64,
        coefficient_m: u64,
        coefficient_rho: u64, 
        min_collateralisation: u64,
        number_of_Epochs_for_extra_Reward_Allocation: u64,
        length_of_lockup_cycle: u64,
        max_collateralisation_first: u64,
        max_collateralisation_second: u64,
        reward_reduction_rate: u64,
        reward_distribution_address: address,
    }


    struct StakingPoolMap has store{
        //The amount of Supra delegated to the validator at this pool.
        delegated_amount: u64,
        //Amount of tokens that are pending deactivation but are currently inactive.
        //pending_inactive_balance: u64
    }

    //Description: This struct serves as a central repository for tracking delegated assets in various staking pools, providing essential data for managing staking operations and calculating borrowing limits based on active and inactive balances within the system.
    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct DelegatedAmount has key {
        /// Maps StakingPoolID to tuple StakingPoolMap
        staking_pool_mapping: SmartTable<address, StakingPoolMap>,
        /// Cumulative amount of Supra delegated across all staking pools
        total_delegated_amount: u64,
        /// Total amount of Supra pending deactivation    
        pending_inactive_balance: u64,
        /// Total amount of Supra that could be borrowed from the PoEL contract 
        total_borrowable_amount: coin::Coin<SupraCoin>,
        /// Index of the lockup cycle when the PoEL last withdrew Supra tokens
        withdrawal_OLC_index: u64,

        withdrawable_rewards: u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct AdminManagement has key {
        /// Total amount of Supra tokens requested for withdrawal
        withdraw_requested_assets: u64,
        /// Index of the last withdrawal request submitted by the admin
        withdraw_OLC_index: u64,
        /// Records the address of the delegation pool that is being replaced.
        replaced_delegation_pool: address,
        /// Records the index of the last pool replacement request submitted by admin
        change_Delegation_pool_OLC_index: u64,
       /// Records the address of the admin that can amend some of the mutable parameters to optimise the system such as total
       /// rentable amount
        admin_address: address,
       /// Stores the address where the extra Supra would be depositted after admin decreases the total rentable amount
        withdrawal_address: address,
        reward_allocation_OLC_index: u64,
    }


    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct BridgeAddresses has key {
        bridge_addresses: vector<address>,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct PoelControler has key {
      extend_ref: ExtendRef,
    }


    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct ExtraReward has key {
        multiperiod_extra_rewards: u64,
        multiperiod_reward_balance: u64,
        singleperiod_reward_balance: u64,
    }


    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, POEL_STORAGE_ADDRESS);

        let obj_signer = &object::generate_signer(constructor_ref);

        let extend_ref = object::generate_extend_ref(constructor_ref);

        move_to(obj_signer, PoelControler {
            extend_ref: extend_ref,
        });

        move_to(obj_signer, DelegatedAmount {
            staking_pool_mapping: smart_table::new(),
            total_delegated_amount: 0,
            pending_inactive_balance: 0,
            total_borrowable_amount: coin::zero<SupraCoin>(),
            withdrawal_OLC_index: 0,
            withdrawable_rewards: 0
        });

        move_to(obj_signer, MutableParameters {
            coefficient_k: 0,
            coefficient_m: 0,
            coefficient_rho: 0,
            min_collateralisation: 0,
            number_of_Epochs_for_extra_Reward_Allocation: 0,
            length_of_lockup_cycle: 0,
            max_collateralisation_first: 0,
            max_collateralisation_second: 0,
            reward_reduction_rate: 0,
            reward_distribution_address: @0x0,
        });

        move_to(obj_signer, AdminManagement {
            withdraw_requested_assets: 0,
            withdraw_OLC_index: 0,
            replaced_delegation_pool: @0x0,
            change_Delegation_pool_OLC_index: 0,
            admin_address: signer::address_of(account),
            withdrawal_address: @0x0,
            reward_allocation_OLC_index: 0,

        });

        move_to(obj_signer, BridgeAddresses {
            bridge_addresses: vector::empty(),
            //delegation_pools: vector::empty(),
        });

        move_to(obj_signer, ExtraReward {
            multiperiod_extra_rewards:0,
            multiperiod_reward_balance:0,
            singleperiod_reward_balance:0,
        });
    
    }

    public fun initialize_Bridge_Pools(bridge_addresses: vector<address>, delegation_pools: vector<address>) acquires BridgeAddresses, DelegatedAmount {
        let obj_address = get_poel_storage_address();

        let bridge_obj = borrow_global_mut<BridgeAddresses>(obj_address);

        bridge_obj.bridge_addresses = bridge_addresses;

        assert!(vector::is_empty(&bridge_obj.bridge_addresses), error::invalid_state(EBRIDGE_INITIALIZED));
        vector::for_each_ref<address>(&delegation_pools, |value| {
            let pool: address = *value;
            let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());
            add_staking_pool(delegated_amount_ref, pool, 0);
        });
    }

    #[view]
    public fun get_poel_storage_address(): address {
        object::create_object_address(&@supra_framework, POEL_STORAGE_ADDRESS)
    }


    fun get_obj_signer(): signer acquires PoelControler {
        let obj_address = get_poel_storage_address();

        let extend_ref = borrow_global<PoelControler>(obj_address);

        object::generate_signer_for_extending(&extend_ref.extend_ref)

    }


    fun add_staking_pool(
        delegated_amount: &mut DelegatedAmount,
        pool_address: address,
        delegated_amount_value: u64,
        //pending_inactive_balance: u64
    ) {
        smart_table::add(
            &mut delegated_amount.staking_pool_mapping,
            pool_address,
            StakingPoolMap {
                delegated_amount: delegated_amount_value,
                //pending_inactive_balance: pending_inactive_balance
            }
        );
        //delegated_amount.total_delegated_amount = (delegated_amount.total_delegated_amount + delegated_amount_value);
        //delegated_amount.pending_inactive_balance = (delegated_amount.pending_inactive_balance + pending_inactive_balance);
    }


    //public fun submit_withdraw_request(
    //    request_table: &mut BorrowWithdrawRequest,
    //    asset: Object<Metadata>,
    //    withdraw_amount: u64
    //) {
    //    let withdraw_items = table::borrow_mut(&mut request_table.requests, asset);
    //    withdraw_items.total_withdraw_requests = (withdraw_items.total_withdraw_requests + withdraw_amount);
    //}

    //public fun get_requests(
    //    request_table: &BorrowWithdrawRequest,
    //    asset: Object<Metadata>
    //): &BorrowRequestTableItems {
    //    table::borrow(&request_table.requests, asset)
    //}


    entry fun set_parameters(
        account: &signer,
        coefficient_k: u64,
        coefficient_m: u64,
        coefficient_rho: u64,
        min_collateralisation: u64,
        number_of_Epochs_for_extra_Reward_Allocation: u64,
        length_of_lockup_cycle: u64,
        max_collateralisation_first: u64,
        max_collateralisation_second: u64,
        reward_reduction_rate: u64,
        reward_distribution_address: address,
    ) acquires MutableParameters, AdminManagement {
        assert!(signer::address_of(account) == get_admin_address(), error::permission_denied(ENOT_OWNER));

        let mutable_params_ref = borrow_global_mut<MutableParameters>(get_poel_storage_address());

        mutable_params_ref.coefficient_k = coefficient_k;
        mutable_params_ref.coefficient_m = coefficient_m;
        mutable_params_ref.coefficient_rho = coefficient_rho;
        mutable_params_ref.min_collateralisation = min_collateralisation;
        mutable_params_ref.number_of_Epochs_for_extra_Reward_Allocation = number_of_Epochs_for_extra_Reward_Allocation;
        mutable_params_ref.length_of_lockup_cycle = length_of_lockup_cycle;
        mutable_params_ref.max_collateralisation_first = max_collateralisation_first;
        mutable_params_ref.max_collateralisation_second = max_collateralisation_second;
        mutable_params_ref.reward_reduction_rate = reward_reduction_rate;
        mutable_params_ref.reward_distribution_address = reward_distribution_address;
    }

    /// Finction: unlock_tokens(supra_amount)
    /// Desctriptio: Unlocks token from the all delegation pools involved in the system 
    /// @param: supra_amount - u64
    fun unlock_tokens(supra_amount: u64) acquires DelegatedAmount, PoelControler {
        let delegated_amount = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());

        let pool_num = smart_table::length(&delegated_amount.staking_pool_mapping);
        let remainder = supra_amount % pool_num;
        let adjusted_supra_amount = supra_amount - remainder;

        let per_pool_unlock_amount = adjusted_supra_amount / pool_num;
      
        let total_unlocked_amount = 0;


        smart_table::for_each_mut<address, StakingPoolMap>(
            &mut delegated_amount.staking_pool_mapping,
            | key, _value|
            {
                let pool_address = *key;
                let (active_stake, inactive_stake, _) = get_stake(pool_address, get_poel_storage_address());

                if (active_stake >= per_pool_unlock_amount) {

                    total_unlocked_amount = total_unlocked_amount + per_pool_unlock_amount;

                    unlock(&get_obj_signer(), pool_address, per_pool_unlock_amount);
                } else if ( active_stake < per_pool_unlock_amount) {
                    total_unlocked_amount = total_unlocked_amount + active_stake; 

                    unlock(&get_obj_signer(), pool_address, per_pool_unlock_amount);
                };
                if (inactive_stake > 0) {
                    withdraw(&get_obj_signer(), pool_address, inactive_stake); // Assuming withdraw is defined in delegation_pool.move
                };

            }
        );

        //let delegated_amount = borrow_global_mut<DelegatedAmount>(DELEGATED_AMOUNT_ADDRESS);
        delegated_amount.total_delegated_amount = delegated_amount.total_delegated_amount - total_unlocked_amount;
    }

    /// Delegates  token to the all delegation pools involved in the system 
    fun delegate_tokens(supra_amount: u64) acquires DelegatedAmount, PoelControler {
        let pool_table = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());

        let pool_num = smart_table::length(&pool_table.staking_pool_mapping);

        let remainder = supra_amount % pool_num;
        let adjusted_supra_amount = supra_amount - remainder;

        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());

        smart_table::for_each_mut<address, StakingPoolMap>(
            &mut delegated_amount_ref.staking_pool_mapping,
            | key, value|
        {
            let pool_address = *key;
            let staking_map: &mut StakingPoolMap = value;

            add_stake(&get_obj_signer(), pool_address, adjusted_supra_amount);

            staking_map.delegated_amount = staking_map.delegated_amount + adjusted_supra_amount;

        });

        delegated_amount_ref.total_delegated_amount = delegated_amount_ref.total_delegated_amount + adjusted_supra_amount;
    }

    /// Facilitates the withdrawal of unlocked tokens from the inactive delegation pools.
    public fun withdraw_tokens() acquires DelegatedAmount, PoelControler {
        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());

        // Preconditions
        //assert!(delegated_amount_ref.withdrawal_OLC_index < current_olc_index, 0);

        //assert!(delegated_amount_ref.pending_inactive_balance > 0, 1);

        // Token Withdrawal Process
        smart_table::for_each_ref<address, StakingPoolMap>(
            &delegated_amount_ref.staking_pool_mapping,
            | key, _value|
        {
            let pool_address = *key;
            let (_, pending_withdrawal) = get_pending_withdrawal(pool_address, signer::address_of(&get_obj_signer())); // Assuming signer is the delegator addr
            // Execute the withdrawal using the withdraw function from delegation_pool.move
            if (pending_withdrawal > 0) {
                withdraw(&get_obj_signer(), pool_address, pending_withdrawal);
            };

        });
        let (current_olc_index, _) = get_total_liquidity();

        delegated_amount_ref.withdrawal_OLC_index = current_olc_index;
    }


/// Allocate Rewards Function
///Description: The function does the following:
/// a. computes the total amount of rewards earned
/// b. computes out of the total earned rewards which part is allocable for different assets,
///    b.1 Calculate the loan granted for an asset: 
///  L^a_e = \frac{S^a_e \cdot P^a_e}{\rho}
///  where $S^a_e$ is the amount of asset $a$ submitted to the vault at the epoch $e$ and $P^a_e$ is 
///the price of asset $a$ (in terms of \$Supra) at the epoch $e$ submitted by an Oracle, $\rho$ is collaterisation rate.  
///    b.2 Calculate the reward distributed for an asset($DR^a_e$).
///DR^a_e = \frac{L^a_e \cdot \mathcal{W}^a_e}{\sum^N_{j=0} L^j_e \cdot \mathcal{W}^j_e} \cdot R_e
///where $R_e$ is total rewards earned from the staking rewards, $N$ is the length of the set of asset $\mathbf{A}$ 
///supported by the system, $\mathcal{W}^a_e$ is the desirability parameter for asset $a$. 
///c. updates reward index for the asset

    public fun allocate_rewards() acquires DelegatedAmount, MutableParameters, PoelControler {
        let total_reward_earned: u64 = 0;

      
        //let delegate_num_ref = borrow_global<DelegatedAmount>(get_poel_storage_address()); 
        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());

        smart_table::for_each_ref<address, StakingPoolMap>(
            &delegated_amount_ref.staking_pool_mapping,
            | key, _value|
        {
            let pool_address = *key;
            // Calculate the total stake by summing values from the pool
            let (active_stake, inactive_stake, _) = get_stake(pool_address, get_poel_storage_address());

            let total_stake = active_stake + inactive_stake;

            // Compute the rewards for the pool and update the total_reward_earned
            let pool_reward = total_stake - delegated_amount_ref.total_delegated_amount;
            total_reward_earned = total_reward_earned + pool_reward;

            // Unlock the calculated total_reward_earned for each pool
            unlock(&get_obj_signer(), pool_address, pool_reward);

        });


        let (_, total_nominal_value) = get_total_liquidity();

        let tracked_assets = get_assets();

        let mutable_params_ref = borrow_global<MutableParameters>(get_poel_storage_address());
        let coefficient_k = mutable_params_ref.coefficient_k;
        let coefficient_m = mutable_params_ref.coefficient_m;
        let min_collateralisation = mutable_params_ref.min_collateralisation;
        let max_collateralisation_first = mutable_params_ref.max_collateralisation_first;
        let max_collateralisation_second = mutable_params_ref.max_collateralisation_second;

        vector::for_each_ref<vector<u8>>(
            &tracked_assets,
            | key|
        {
            //let is_there: &bool = value;
            let symbol = *key;

            let collateralisation_rate = calculate_collaterisation_rate(
                symbol,
                coefficient_k,
                coefficient_m,
                //coefficient_rho,
                min_collateralisation,
                max_collateralisation_first,
                max_collateralisation_second
            );
            let (_, asset_supply, _, desirability_score) =  get_liquidity_table_items(symbol);
            let (asset_price, _decimal, _timestamp, _round) = get_asset_price(symbol);

            let available_reward_for_asset = (
                (desirability_score * asset_price * asset_supply / collateralisation_rate) / total_nominal_value
            ) * total_reward_earned;

            update_reward_index(asset_metadata(symbol), available_reward_for_asset, asset_supply, desirability_score);

        });
    }


    ///  This function recalculates and updates(delegates or unlocks) the total amount of
    /// Supra that is borrowed based on the current asset prices, supplies, and collateralization rates.
    public fun update_rented_amount() acquires DelegatedAmount, MutableParameters, PoelControler {
        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());
        let current_delegated_amount = delegated_amount_ref.total_delegated_amount;

        calculate_nominal_liquidity();

        let mutable_params_ref = borrow_global<MutableParameters>(get_poel_storage_address());
        let coefficient_k = mutable_params_ref.coefficient_k;
        let coefficient_m = mutable_params_ref.coefficient_m;
        let min_collateralisation = mutable_params_ref.min_collateralisation;
        let max_collateralisation_first = mutable_params_ref.max_collateralisation_first;
        let max_collateralisation_second = mutable_params_ref.max_collateralisation_second;


        let change_of_rented_amount: u64 = calculate_total_rentable(
                coefficient_k,
                coefficient_m,
                min_collateralisation,
                max_collateralisation_first,
                max_collateralisation_second
            );

        let change_of_borrowed_amount: u64 = 0;
        let total_borrowable_amount = coin::value<SupraCoin>(&delegated_amount_ref.total_borrowable_amount);

        if (change_of_rented_amount > current_delegated_amount) {
            let difference = change_of_rented_amount - current_delegated_amount;
            if (difference <= total_borrowable_amount) {
                change_of_borrowed_amount = difference;
            } else {
                change_of_borrowed_amount = total_borrowable_amount;
            }
        } else {
            change_of_borrowed_amount = 0;
        };

        if (change_of_borrowed_amount == 0) {
            return
        } else if (change_of_borrowed_amount > 0) {
            delegate_tokens(change_of_borrowed_amount);
        } else if (change_of_borrowed_amount < 0) {
            unlock_tokens(change_of_borrowed_amount); //should be negative?
        }
    }

    /// Enables increasing the rentable Supra amount by transferring funds to the PoEL contract.
    public fun increase_rentable_amount<CoinType>(account: &signer, amount: u64) acquires DelegatedAmount, AdminManagement {
        assert!(signer::address_of(account) == get_admin_address(), error::permission_denied(ENOT_OWNER));

        let coins = coin::withdraw<SupraCoin>(account, amount);

        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());

        //increase the rentable abount
        coin::merge<SupraCoin>(&mut delegated_amount_ref.total_borrowable_amount, coins);
    }

    /// Decreases the amount of rentable tokens available in the PoEL contract.
    public fun decrease_rentable_amount(account: &signer, amount: u64) acquires DelegatedAmount, AdminManagement, PoelControler {
        let admin = get_admin_address();
        assert!(signer::address_of(account) == admin, error::permission_denied(ENOT_OWNER));

        let admin_management_ref = borrow_global_mut<AdminManagement>(get_poel_storage_address());

        let (current_olc_index, _) = get_total_liquidity(); // Assuming a function to get the current OLC index

        // Withdrawal Index Check
        if (admin_management_ref.withdraw_OLC_index < current_olc_index && admin_management_ref.withdraw_OLC_index != 0) {
            let withdraw_requested_assets = admin_management_ref.withdraw_requested_assets;

            // Send withdraw_requested_assets amount of Supra from the PoEL contract to the admin
            coin::transfer<SupraCoin>(&get_obj_signer(), admin_management_ref.admin_address, withdraw_requested_assets);

            admin_management_ref.withdraw_requested_assets = 0;
        };

        let unmut_delegated_amount_ref = borrow_global<DelegatedAmount>(get_poel_storage_address());
        let supra_balance = coin::value<SupraCoin>(&unmut_delegated_amount_ref.total_borrowable_amount);


        // Token Movement
        if (supra_balance >= amount) {
            let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());
            //extract the amount of supra
            let extracted_supra = coin::extract<SupraCoin>(&mut delegated_amount_ref.total_borrowable_amount, amount);

            // deposit the specified amount of Supra from the PoEL contract to the admin's account
            coin::deposit<SupraCoin>(admin, extracted_supra);

        } else {
            //let coin_value = coin::value<SupraCoin>(&unmut_delegated_amount_ref.total_borrowable_amount);
            if (amount > supra_balance) {
                abort(1) // Throw an error if requested amount exceeds total borrowable amount
            } else {
                let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());

                //extract the amount of supra
                //double check this logic. the extracted supra could be unsed
                let extracted_supra = coin::extract<SupraCoin>(&mut delegated_amount_ref.total_borrowable_amount, amount);
                // Move the entire Supra balance from the PoEL contract to the admin's account
                coin::deposit<SupraCoin>(admin, extracted_supra);

                let shortfall = amount - supra_balance;

                unlock_tokens(shortfall);


            }
        };

        admin_management_ref.withdraw_OLC_index = current_olc_index;
    }

    /// Facilitates the creation of borrow requests following the deposition of the original asset into
    /// an intermediary vault. One of the main reasons why the borrow_request function has been suggested 
    /// in the flow to borrow is because the pending_active coins do not earn rewards. 
    public fun borrow_request(
        account: &signer,
        asset_symbol: vector<u8>,
        asset_amount: u64,
        receiver_address: address
    ) acquires BridgeAddresses {

        let bridge_addresses = borrow_global<BridgeAddresses>(get_poel_storage_address());

        let bridge_exists = vector::contains<address>(&bridge_addresses.bridge_addresses,&signer::address_of(account));
        assert!(bridge_exists, error::permission_denied(EBRIDGE_NOT_PRESENT));

        update_borrow_request(asset_symbol, asset_amount);

        let (_, asset_supply, _, _) = get_liquidity_table_items(asset_symbol);
        premint_iAsset(asset_amount, asset_symbol, receiver_address, asset_supply);
    }


    /// Facilitates borrowing of assets, calculates new collateralization rates and manages distribution across staking pools.
    public fun borrow(
        asset_symbol: vector<u8>,
        asset_amount: u64,
        receiver_address: address
    ) acquires DelegatedAmount , MutableParameters, PoelControler{
        let (asset_price, _decimal, _timestamp, _round) = get_asset_price(asset_symbol);

        let new_balance_asset = update_single_asset_supply(asset_symbol, asset_amount);

        let mutable_params_ref = borrow_global<MutableParameters>(get_poel_storage_address());
        let coefficient_k = mutable_params_ref.coefficient_k;
        let coefficient_m = mutable_params_ref.coefficient_m;
        //let coefficient_rho = mutable_params_ref.coefficient_rho;
        let min_collateralisation = mutable_params_ref.min_collateralisation;
        let max_collateralisation_first = mutable_params_ref.max_collateralisation_first;
        let max_collateralisation_second = mutable_params_ref.max_collateralisation_second;
        let nominal_value = new_balance_asset * asset_price;
        let collateralisation_rate = calculate_collaterisation_rate(
            asset_symbol,
            coefficient_k,
            coefficient_m,
            min_collateralisation,
            max_collateralisation_first,
            max_collateralisation_second
        );
        let borrowed_amount = (asset_amount / collateralisation_rate) * asset_price;

        delegate_tokens(borrowed_amount);

        mint_iAsset(receiver_address, asset_symbol);

        let delegated_amount_ref = borrow_global_mut<DelegatedAmount>(get_poel_storage_address());
        delegated_amount_ref.total_delegated_amount = delegated_amount_ref.total_delegated_amount + borrowed_amount;
    }

    fun update_olc_index(olc_index_update_timestep: u64) acquires MutableParameters {
        let mutable_params_ref = borrow_global<MutableParameters>(get_poel_storage_address());

        let time_now = timestamp::now_seconds();

        if ((time_now - olc_index_update_timestep) >= mutable_params_ref.length_of_lockup_cycle ) {
            poel_update_olc_index()        };

    }
    
    entry fun add_multiperiod_extra_rewards(amount: u64, account: &signer) acquires ExtraReward {
        let extra_reward_ref = borrow_global_mut<ExtraReward>(get_poel_storage_address());

        assert!(extra_reward_ref.multiperiod_reward_balance == 0, error::invalid_state(EWRONG_REWARD_BALANCE));
        let user_balance = coin::balance<SupraCoin>(signer::address_of(account));

        assert!(user_balance >= amount, error::invalid_argument(EINSUFICIENT_CALLER_BALANCE));

        extra_reward_ref.multiperiod_extra_rewards = amount;
        extra_reward_ref.multiperiod_reward_balance = amount;
    }


    entry fun add_singleperiod_extra_rewards(amount: u64, account: &signer) acquires ExtraReward {
        let user_balance = coin::balance<SupraCoin>(signer::address_of(account));
        assert!(user_balance >= amount, error::invalid_argument(EINSUFICIENT_CALLER_BALANCE));
        let extra_reward_ref = borrow_global_mut<ExtraReward>(get_poel_storage_address());

        extra_reward_ref.singleperiod_reward_balance = amount;
    }


    entry fun change_admin(account: &signer, new_address: address) acquires AdminManagement {
        let admin_management_ref = borrow_global_mut<AdminManagement>(get_poel_storage_address());

        assert!(admin_management_ref.admin_address == signer::address_of(account), error::permission_denied(ENOT_OWNER));

        admin_management_ref.admin_address = new_address;
    }


    entry fun change_withdrawal_address(account: &signer, new_address: address) acquires AdminManagement {
        let admin_management_ref = borrow_global_mut<AdminManagement>(get_poel_storage_address());

        assert!(admin_management_ref.admin_address == signer::address_of(account), error::permission_denied(ENOT_OWNER));

        admin_management_ref.withdrawal_address = new_address;
    }

    fun get_admin_address(): address acquires AdminManagement {
        let admin_management_ref = borrow_global<AdminManagement>(get_poel_storage_address());
        admin_management_ref.admin_address

    }


  

    #[test(creator = @store)]
    fun test_init(creator: &signer) {
        init_module(creator);
    }
}
