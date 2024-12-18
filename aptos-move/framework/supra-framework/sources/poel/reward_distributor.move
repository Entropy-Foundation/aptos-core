/// This is the reward distribution module
/// it manages the reward metrics of the Proof of Efficiency Liquidity module and iAssets module
/// Its main purposes include: updating reward indexes, calculating user rewards, and updating user rewards


module supra_framework::reward_distributor {
    use supra_framework::table;

    //Errors:

    const NO_AVAILABLE_DESIRABLE_LIQUIDITY: u64 = 1;
    
    // Structs: 

    ///houses the reward_index_asset and the available_rewards_for_asset
    struct TotalLiquidityProvidedItems has store, copy {
        ///reward_index_asset: Index tracking the reward distribution of the asset (u64).
        reward_index_asset: u64,
        ///available_rewards_for_asset: tracks the available rewards that are distributable for each asset  
        available_rewards_for_asset: u64
    }

    ///Manages reward distribution metrics for assets based on provided liquidity.
    struct DistributableRewards {
        // Maps AssetID to TotalLiquidityProvidedItems
        total_liquidity_provided: table::Table<u64, TotalLiquidityProvidedItems>,
    }

    /// Updates the reward index for an asset based on newly distributed rewards.
    public fun update_reward_index(
        _asset_id: u64,
        _rewards: u64,
        _asset_supply: u64,
        _desirability_score: u64
    ) {

    }


    ///Computes the rewards for a user based on their held assets and accrued reward indices.
    public fun calculate_rewards(
        _iAsset_balance: u64,
        _user_reward_index: u64,
        _reward_index_asset: u64
    ): u64 {
        0
    }

    ///Updates and distributes rewards for a specific asset to an account.
    public fun update_rewards(
        _asset_id: u64,
        _iAsset_balance: u64,
        _user_reward_index: u64,
    ): u64 {
        0
    }
}
