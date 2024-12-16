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
/// 
/// Errors:
///    //thrown when the allowed signer is not the caller (owner)
///    const ERR_NOT_OWNER: u64 = 0;
///
///    //thrown when the wrong asset weight gets calculated
///    const ERR_WRONG_WEIGHT: u64 = 1;
///
///    //thrown when the length of the supplied collaterixation weight argument vector does not match table entries
///    const ERR_WRONG_CWV_LENGTH: u64 = 2;
///
///    //thrown when the length of the desirability score argument vector does not match table entries
///    const ERR_WRONG_DESIRABILITY_SCORE_LEN: u64 = 3;
///
///    //thrown when the asset id supiled is not present in the TotalLiquidityTable
///    const ERR_ASSET_NOT_PRESENT: u64 = 4;
///
///    //thrown If coefficient_X < coefficient_b
///    const ERR_COEFA_LT_COEFB: u64 = 5;
/// 
/// Structs:
/// 
///     This struct contains contains the field attributes for each asset in the liquidity table
///     struct LiquidityTableItems {
///        ///Asset_name
///        asset_name: vector<u8>,
///        ///asset_supply: Total amount of the asset that has been bridged to create the iAsset.
///        asset_supply: u64,
///        ///iAsset_supply: Total supply of iAssets generated through the scheme.
///        iAsset_supply: u64,
///        ///collaterisation_rate: Specific rate indicating the collateral security of the iAsset.
///        collateralisation_rate: u64,
///        ///desired_weights: Weights reflecting the asset's strategic importance.
///        desired_weight: u64,
///        ///desirability_score: Attractiveness score of the asset.
///        desirability_score: u64,
///        ///asset_price: Current market price of the asset.
///        asset_price: u64,
///    }
/// 
///     //This struct aggregates comprehensive liquidity metrics and operational indices for assets managed within the system.
///    struct TotalLiquidity {
///        //TotalLiquidityTable: Maps each AssetID to a LiquidityTableItems struct
///        TotalLiquidityTable: SmartTable<u64, LiquidityTableItems>,
///        //Index of the last observable lockup cycle (OLC), crucial for the minting of preminted tokens and the withdrawal of unlocked tokens.
///        current_olc_index: u64,
///        //Represents the nominal value of all assets submitted to the system, indicating the total economic stake.
///        total_nominal_value: u64
///    }
/// 
///    /// This struct is applied for the dynamic adjustment of the system's operational parameters. 
///    /// It allows for flexible management of financial metrics, adapting to market conditions or strategic shifts in policy.
///    struct MutableParameters { 
///        coefficient_b: u64,
///        coefficient_X: u64,
///        coefficient_rho: u64, 
///        min_collateralisation: u64 
///    }
///
///
///    struct StakingPoolMap {
///        //Address of the staking pool.
///        pool_address: address,
///        //The amount of Supra delegated to the validator at this pool.
///        delagated_amount: u64,
///        //Amount of tokens that are pending deactivation but are currently inactive.
///        pending_inactive_balance: u64
///    }
///
///    /// Description: This struct serves as a central repository for tracking delegated assets in various staking pools, 
///    /// providing essential data for managing staking operations and calculating borrowing limits based on active and 
///    /// inactive balances within the system.
///    struct DelegatedAmount {
///        // Maps StakingPoolID to tuple StakingPoolMap
///        staking_pool_mapping: table::Table<u64, StakingPoolMap>,
///        // Cumulative amount of Supra delegated across all staking pools
///        total_delegated_amount: u64,
///        // Total amount of Supra pending deactivation    
///        pending_inactive_balance: u64,
///        // Total amount of Supra that could be borrowed from the PoEL contract 
///        total_borrowable_amount: u64,
///        // Index of the lockup cycle when the PoEL last withdrew Supra tokens
///        withdrawal_OLC_index: u64
///    }
///
///
///    struct AdminManagement {
///        // Total amount of Supra tokens requested for withdrawal
///        withdraw_requested_assets: u64,
///        // Index of the last withdrawal request submitted by the admin
///        withdraw_OLC_index: u64
///    }
/// 
///    ///This struct holds the field items (total_borrow_requests & total_withdraw_requests) mapped to requests
///    /// table (AssetId => BorrowWithdrawRequestTableItems) in the BorrowWithdrawRequest
///    struct BorrowWithdrawRequestTableItems {
///        total_borrow_requests: u64,
///        total_withdraw_requests: u64,
///    }
///    ///Maps each AssetID to a tuple containing the total amounts of withdraw requests submitted to the PoEL contract.
///    ///Borrow requests are initiated by users to borrow Supra and mint iAssets after depositing their assets in intralayer vaults.
///    ///Withdraw requests are made by users aiming to retrieve their assets from intralayer vaults in the subsequent cycle.
///    ///Both types of requests are processed in the next cycle.
///    struct BorrowWithdrawRequest {
///        // Maps each AssetID to a BorrowWithdrawRequestTableItems
///        requests: table::Table<u64, BorrowWithdrawRequestTableItems>,
///    }