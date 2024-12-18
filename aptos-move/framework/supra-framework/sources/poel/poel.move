///
/// This is the Proof of Efficiency Liquidity module used to delagate $supra to staking pools for users
/// who hold iEth by making deposits of ETH to the intralayer vault. It handles the creation of the iETH and distribution to the
/// corresponding addresses on supra
///
/// Flow:
/// 1. Users submit WETH to the Intralayer Vault on the Ethereum blockchain.
/// 2. The Supra cross-chain communication protocol transfers the deposit information to the PoEL (Proof of Efficient Liquidity) contract on the Supra chain.
/// 3. This process creates a new token, iETH (InterLayer ETH), which is distributed to the user's address on Supra. 
/// 4. In the background, utilizing the PoEL protocol, assets deposited into the Intralayer Vault serve as collateral to 
/// borrow $Supra and stake it in the Supra PoS system. The PoEL contract periodically lends $Supra tokens to users who have submitted WETH to the Intralayer 
/// Vault and evenly distributes these tokens among various delegation pools participating in the system. 
/// In this setup, the PoEL contract itself acts as the delegator of the $Supra tokens in the delegation pool on behalf of the users.
/// Note:
/// The total lended amount through the PoEL contract depends on the Oracle price submitted to the PoEL contract.
/// If the price of the asset goes up compared with $Supra the system lends more delegating more assets 
/// to the delegation pools and correspondingly if the price drops the system lends less, withdrawing some assets
/// from the delegation pools. Therefore, the PoEL contract acting as the delegation agent for the users ensures the
/// total delegated amount from the PoEL contract is equable with the total nominal value submitted to the IntraLayer vaults.
/// When a user wants to retrieve the original ETH that was used as collateral, they can burn the iETH, which then enables
/// them to receive the original ETH on the Ethereum blockchain.

module supra_framework::poel {
    use supra_framework::table;
    use supra_framework::smart_table::SmartTable;
    //Errors:

    /// thrown when the allowed signer is not the caller (owner)
    const ERR_NOT_OWNER: u64 = 0;

    /// thrown when the wrong asset weight gets calculated
    const ERR_WRONG_WEIGHT: u64 = 1;

    /// thrown when the length of the supplied collaterixation weight argument vector does not match table entries
    const ERR_WRONG_CWV_LENGTH: u64 = 2;

    /// thrown when the length of the desirability score argument vector does not match table entries
    const ERR_WRONG_DESIRABILITY_SCORE_LEN: u64 = 3;

    /// thrown when the asset id supiled is not present in the TotalLiquidityTable
    const ERR_ASSET_NOT_PRESENT: u64 = 4;

    /// thrown If coefficient_X < coefficient_b
    const ERR_COEFA_LT_COEFB: u64 = 5;
 
    // Structs:
 
     /// This struct contains contains the field attributes for each asset in the liquidity table
     struct LiquidityTableItems {
        ///Asset_name
        asset_name: vector<u8>,
        ///asset_supply: Total amount of the asset that has been bridged to create the iAsset.
        asset_supply: u64,
        ///iAsset_supply: Total supply of iAssets generated through the scheme.
        iAsset_supply: u64,
        ///collaterisation_rate: Specific rate indicating the collateral security of the iAsset.
        collateralisation_rate: u64,
        ///desired_weights: Weights reflecting the asset's strategic importance.
        desired_weight: u64,
        ///desirability_score: Attractiveness score of the asset.
        desirability_score: u64,
        ///asset_price: Current market price of the asset.
        asset_price: u64,
    }
 
    /// This struct aggregates comprehensive liquidity metrics and operational indices for assets managed within the system.
    struct TotalLiquidity {
        //TotalLiquidityTable: Maps each AssetID to a LiquidityTableItems struct
        TotalLiquidityTable: SmartTable<u64, LiquidityTableItems>,
        //Index of the last observable lockup cycle (OLC), crucial for the minting of preminted tokens and the withdrawal of unlocked tokens.
        current_olc_index: u64,
        //Represents the nominal value of all assets submitted to the system, indicating the total economic stake.
        total_nominal_value: u64
    }
 
    /// This struct is applied for the dynamic adjustment of the system's operational parameters. 
    /// It allows for flexible management of financial metrics, adapting to market conditions or strategic shifts in policy.
    struct MutableParameters { 
        coefficient_b: u64,
        coefficient_X: u64,
        coefficient_rho: u64, 
        min_collateralisation: u64 
    }


    struct StakingPoolMap {
        //Address of the staking pool.
        pool_address: address,
        //The amount of Supra delegated to the validator at this pool.
        delagated_amount: u64,
        //Amount of tokens that are pending deactivation but are currently inactive.
        pending_inactive_balance: u64
    }

    /// Description: This struct serves as a central repository for tracking delegated assets in various staking pools, 
    /// providing essential data for managing staking operations and calculating borrowing limits based on active and 
    /// inactive balances within the system.
    struct DelegatedAmount {
        // Maps StakingPoolID to tuple StakingPoolMap
        staking_pool_mapping: table::Table<u64, StakingPoolMap>,
        // Cumulative amount of Supra delegated across all staking pools
        total_delegated_amount: u64,
        // Total amount of Supra pending deactivation    
        pending_inactive_balance: u64,
        // Total amount of Supra that could be borrowed from the PoEL contract 
        total_borrowable_amount: u64,
        // Index of the lockup cycle when the PoEL last withdrew Supra tokens
        withdrawal_OLC_index: u64
    }


    struct AdminManagement {
        // Total amount of Supra tokens requested for withdrawal
        withdraw_requested_assets: u64,
        // Index of the last withdrawal request submitted by the admin
        withdraw_OLC_index: u64
    }
 
    /// This struct holds the field items (total_borrow_requests & total_withdraw_requests) mapped to requests
    /// table (AssetId => BorrowWithdrawRequestTableItems) in the BorrowWithdrawRequest
    struct BorrowWithdrawRequestTableItems {
        total_borrow_requests: u64,
        total_withdraw_requests: u64,
    }


    /// Maps each AssetID to a tuple containing the total amounts of withdraw requests submitted to the PoEL contract.
    /// Borrow requests are initiated by users to borrow Supra and mint iAssets after depositing their assets in intralayer vaults.
    /// Withdraw requests are made by users aiming to retrieve their assets from intralayer vaults in the subsequent cycle.
    /// Both types of requests are processed in the next cycle.
    struct BorrowWithdrawRequest {
        // Maps each AssetID to a BorrowWithdrawRequestTableItems
        requests: table::Table<u64, BorrowWithdrawRequestTableItems>,
    }

    //Functions:

    #[view]
    public fun get_total_liquidity_current_cycle_index(): u64 {
        0
    }

    #[view]
    public fun get_total_liquidity(): address {
        @supra_framework
    }


    /// adds an asset with its coresponding information to the System
    public fun add_asset(
        _total_liquidity: &mut TotalLiquidity,
        _asset_id: u64,
        _asset_name: vector<u8>,
        _asset_supply: u64,
        _iAsset_supply: u64,
        _collateralisation_rate: u64,
        _desired_weights: u64,
        _desirability_score: u64,
        _asset_price: u64
    ) {
    }

    /// Adds a staking pool to the existing pools for delegation os $supra
    public fun add_staking_pool(
        _delegated_amount: &mut DelegatedAmount,
        _pool_id: u64,
        _pool_address: address,
        _delegated_amount_value: u64,
        _pending_inactive_balance: u64
    ) {
    }


    public fun submit_borrow_request(
        _request_table: &mut BorrowWithdrawRequest,
        _asset_id: u64,
        _borrow_amount: u64
    ) {

    }


    public fun submit_withdraw_request(
        _request_table: &mut BorrowWithdrawRequest,
        _asset_id: u64,
        _withdraw_amount: u64
    ) {

    }

    /// should return a &BorrowRequestTableItems
    public fun get_requests(
        _request_table: &BorrowWithdrawRequest,
        _asset_id: u64
    ) {
    }


    // Updates asset weights in the TotalLiquidity struct to align with current strategic objectives.
    public fun update_desired_weight(
        _collaterisation_rate_vector: vector<u64>,
        _account: &signer
    ) {

    }

    /// Updates desirability scores for all assets in the TotalLiquidity struct.
    public fun batch_update_desirability_score(
        _desirability_score_vector: vector<u64>,
        _account: &signer
    ) {

    }

    /// Updates the desirability score of a specified asset within the TotalLiquidity struct of the Supra_framework.
    public fun update_desirability_score(
        _account: &signer,
        _desirability_score: u64,
        _asset_id: u64
    ){
    }


    /// Calculates and updates the collateralization rate for a specified asset based on dynamic market weights 
    /// and predefined coefficients.
    public fun calculate_collaterisation_rate(
        _asset_nominal_value: u64,
        _total_nominal_value: u64,
        _asset_id: u64
    ) {

    }


    fun sign(_value: u64): u64 {
        0
    }


    public fun set_parameters(
        _account: &signer,
        _coefficient_b: u64,
        _coefficient_X: u64,
        _coefficient_rho: u64,
        _min_collateralisation: u64
    ) {

    }

    /// Unlocks token from the all delegation pools involved in the system 
    public fun unlock_tokens(_supra_amount: u64) {}

    /// Delegates  token to the all delegation pools involved in the system 
    public fun delegate_tokens(_supra_amount: u64) {}

    /// Facilitates the withdrawal of unlocked tokens from the inactive delegation pools.
    public fun withdraw_tokens() {}

    /// This function facilitates the replacement of an existing staking pool with a new pool address.
    /// It performs several checks and updates to ensure the integrity and security of the staking \
    /// process within the blockchain network.
    public fun allocate_rewards() {}


    /// This function is designed to manage the transition of assets between staking pools. 
    /// It ensures that the transition adheres to the required permissions
    /// and conditions set within the system before proceeding with asset reallocation.
    public fun replace_staking_pool (
        _account: signer,
        _replaced_pool_address: address,
        _replacing_pool_address: address
    ) {}

    /// pdates asset prices and calculates new supply metrics for collateral management in the system.
    public fun update_asset_price_supply() {}

    ///  This function recalculates and updates(delegates or unlocks) the total amount of
    /// Supra that is borrowed based on the current asset prices, supplies, and collateralization rates.
    public fun update_rented_amount() {}

    /// Enables increasing the rentable Supra amount by transferring funds to the PoEL contract.
    public fun increase_rentable_amount(_account: &signer, _amount: u64) {}

    /// Decreases the amount of rentable tokens available in the PoEL contract.
    public fun decrease_rentable_amount(_acccount: &signer, _amount: u64) {}

    /// Facilitates the creation of borrow requests following the deposition of the original asset into
    /// an intermediary vault. One of the main reasons why the borrow_request function has been suggested 
    /// in the flow to borrow is because the pending_active coins do not earn rewards. 
    public fun borrow_request(
        _account: &signer,
        _asset_id: u64,
        _asset_amount: u64,
        _receiver_address: address
    ) {}

    /// Facilitates borrowing of assets, calculates new collateralization rates and manages distribution across staking pools.
    public fun borrow(
        _asset_id: u64,
        _asset_amount: u64,
        _receiver_address: address
    ) {}

    //add_stake() 
    //unlock_stake()
    //unlock_rewards(),  

}