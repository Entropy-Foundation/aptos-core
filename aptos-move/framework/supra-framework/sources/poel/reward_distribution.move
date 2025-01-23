/// This is the reward distribution module
/// it manages the reward metrics of the Proof of Efficiency Liquidity module and iAssets module
/// Its main purposes include: updating reward indexes, calculating user rewards, and updating user rewards


module supra_framework::reward_distribution {
    use supra_framework::table;
    use supra_framework::object::{Self, Object};
    use supra_framework::error;

    use aptos_std::fungible_asset::Metadata;
    use aptos_std::primary_fungible_store;
    friend supra_framework::poel;

    const ENO_AVAILABLE_DESIRABLE_LIQUIDITY: u64 = 1;

    const DISTRIBUTABLE_REWARDS: vector<u8> = b"DistributableRewards";

    struct TotalLiquidityProvidedItems has store, copy {
        ///reward_index_asset: Index tracking the reward distribution of the asset (u64).
        reward_index_asset: u64,
        ///available_rewards_for_asset: tracks the available rewards that are distributable for each asset  
        available_rewards_for_asset: u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    struct DistributableRewards has key {
        // Maps AssetID to TotalLiquidityProvidedItems
        total_liquidity_provided: table::Table<Object<Metadata>, TotalLiquidityProvidedItems>,
    }


    fun init_module(account: &signer) {
        let constructor_ref = &object::create_named_object(account, DISTRIBUTABLE_REWARDS);

        let obj_signer = &object::generate_signer(constructor_ref);
        move_to(obj_signer, DistributableRewards {
            total_liquidity_provided: table::new(),
        });
    }

    ///Update_reward_index(asseID, rewards): 
    ///Purpose: Updates the reward index for an asset based on newly distributed rewards. The function will be applied for each asset after rewards are withdrawn from the delegation pools at the end of each OLC, updating the asset's global reward index
    public(friend) fun update_reward_index(
        asset: Object<Metadata>,
        rewards: u64,
        asset_supply: u64,
        desirability_score: u64,
    ) acquires DistributableRewards {
        if (asset_supply == 0 || desirability_score == 0) {
            abort(error::aborted(ENO_AVAILABLE_DESIRABLE_LIQUIDITY))
        };
        let reward_index_increase = rewards / asset_supply;

        let distributable_rewards_ref = borrow_global_mut<DistributableRewards>(
            object::create_object_address(&@supra_framework, DISTRIBUTABLE_REWARDS)
        );
        let distributable_table_item = table::borrow_mut(
            &mut distributable_rewards_ref.total_liquidity_provided,
            asset
        );

        distributable_table_item.reward_index_asset = distributable_table_item.reward_index_asset + reward_index_increase;

        table::add(
            &mut distributable_rewards_ref.total_liquidity_provided,
            asset,
            *distributable_table_item
        );
    }


    ///Purpose: Computes the rewards for a user based on assets held on their account for some period of time and asset specific global reward index(at the point of the function call) and user specific reward(updated for the user at the point of the last asset balance change).
    public fun calculate_rewards(
        user_address: address,
        user_reward_index: u64,
        asset: Object<Metadata>
    ): u64 acquires DistributableRewards {
        let iAsset_balance = primary_fungible_store::balance(user_address, asset);

        let distributable_rewards_ref = borrow_global<DistributableRewards>(
            object::create_object_address(&@supra_framework, DISTRIBUTABLE_REWARDS)
        );
        let reward_index_asset = table::borrow(
            &distributable_rewards_ref.total_liquidity_provided,
            asset
        ).reward_index_asset;

        //Compute Rewards using the formula:  Rewards= iAssetBalance * (reward_index_asset - rewardIndexOf[_account])

        let rewards = iAsset_balance * (reward_index_asset - user_reward_index);

        rewards
    }


    ///Purpose: Updates and distributes rewards for a specific asset to an account.
    public fun update_rewards(
        user_address: address,
        user_reward_index: u64,
        asset: Object<Metadata>
    ): u64 acquires DistributableRewards {
        let new_user_reward_index: u64 = 0;


        let distributable_rewards_ref = borrow_global<DistributableRewards>(
            object::create_object_address(&@supra_framework, DISTRIBUTABLE_REWARDS)
        );

        let distributable_rewards_table_item = table::borrow(&distributable_rewards_ref.total_liquidity_provided, asset);
        let reward_index_asset = distributable_rewards_table_item.reward_index_asset;

        if (user_reward_index == new_user_reward_index) {
            new_user_reward_index = reward_index_asset;
        } else {
            let _distributable_rewards = calculate_rewards(user_address, user_reward_index, asset);

            //assert!(PoEL::has_sufficient_tokens(distributable_rewards), INSUFFICIENT_TOKENS_ERROR);

            //PoEL::transfer_tokens(distributable_rewards, user_address);

            new_user_reward_index = reward_index_asset;
        };
        new_user_reward_index
    }


    #[test(creator = @supra_framework)]
    fun test_init(creator: &signer) {
        init_module(creator);
    }

}
