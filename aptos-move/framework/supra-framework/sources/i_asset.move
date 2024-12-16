///
/// This is the iAsset module used as the iAsset standard given to users who deposited assets 
/// via the intralayer vault. Holders of iAsset get an amount of $supra delegated to staking pools depending on the
/// amount of assets deposited and the price of the asset. ie If the price of the asset if 
/// up compared with $Supra the system lends more to the user delegating more $supra 
/// to the delegation pools and correspondingly if the price drops the system lends less, withdrawing some assets
/// from the delegation pools. Holders of iAsset get $supra rewards from the staking pools while enabling them to utilize 
/// the iAsset as an underlying asset of their deposited asset for other defi utilities. Transfer of iAsset to a different address
/// transfers the acrual of rewards to the receiving address for the period beging after the transfer. 
///
/// Errors:
/// 
/// 
/// Structs:
///    This struct holds individual iAsset parameters for each user's holdings  
///    struct AssetEntry has store, copy {
///        ///iAssetBalance: Amount of iAsset held by the user.
///        iAsset_balance: u64,
///        ///UserRewardIndex: Track RewardIndex specific to the user for each asset.
///        user_reward_index: u64,
///        ///Preminted_iAssets: Tracks  number  of iAssets that are preminted.
///        preminted_iAssets: u64,
///        ///Redeem_Requested_iAssets: Number of iAssets for which redemption has been requested.
///        redeem_requested_iAssets: u64,
///        ///Preminiting_OLC_Index: Records the index of the last cycle during which a preminting request was submitted for an asset.
///        preminiting_OLC_index: u64
///    }
///
///    This structs holds a user's Liquidity information with a table mapping to all assets
///    struct LiquidityProvider has key {
///        ///iAsset_table: Utilizes aptos_std::table to map asset IDs to multiple attributes in AssetEntry
///        iAsset_table: table::Table<u64, AssetEntry>,
///        ///allocated_Rewards: Tracks the total rewards that are allocable to the user.
///        allocated_rewards: u64,
///        ///unlock_OLC_Index: Registers the index of the lockup cycle when the user last submitted an unlock request.
///        unlock_olc_index: u64
///    }