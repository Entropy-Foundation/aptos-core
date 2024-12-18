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

module supra_framework::i_asset {

    use supra_framework::table;
    use supra_framework::string::String;
/// Errors:

    /// Thrown when the calling address is not the poel module address
    const ERR_NOT_POEL_ADDRESS: u64 = 0;
/// 
/// Structs:
    ///This struct holds individual iAsset parameters for each user's holdings  
    struct AssetEntry has store, copy {
        ///iAssetBalance: Amount of iAsset held by the user.
        iAsset_balance: u64,
        ///UserRewardIndex: Track RewardIndex specific to the user for each asset.
        user_reward_index: u64,
        ///Preminted_iAssets: Tracks  number  of iAssets that are preminted.
        preminted_iAssets: u64,
        ///Redeem_Requested_iAssets: Number of iAssets for which redemption has been requested.
        redeem_requested_iAssets: u64,
        ///Preminiting_OLC_Index: Records the index of the last cycle during which a preminting request was submitted for an asset.
        preminiting_OLC_index: u64
    }

    ///This structs holds a user's Liquidity information with a table mapping to all assets
    struct LiquidityProvider has key {
        ///iAsset_table: Utilizes aptos_std::table to map asset IDs to multiple attributes in AssetEntry
        iAsset_table: table::Table<u64, AssetEntry>,
        ///allocated_Rewards: Tracks the total rewards that are allocable to the user.
        allocated_rewards: u64,
        ///unlock_OLC_Index: Registers the index of the lockup cycle when the user last submitted an unlock request.
        unlock_olc_index: u64
    }

    //Functions:

    //helper function to update the liquidity provider table
    public fun update_iAsset_entry(
        _provider: &mut LiquidityProvider,
        _asset_id: u64,
        _iAssetBalance: u64,
        _user_reward_index: u64,
        _preminted_iAssets: u64,
        _redeem_requested_iAssets: u64,
        _preminiting_OLC_index: u64
    ) {}

    ///Function to set up initial LiquidityProvider structures for asset management.
    public fun initialize_LiquidityProvider(_account: &signer) {}

    ///Verifies if an assetID exists in the user's LiquidityProvider struct and updates it if absent.
    /// @param: user_address - The user address receiving the assets
    /// @param: asset_id - asset id in the iAsset_table of LiquidityProvider struct
    fun add_asset_LiquidityProvider(
        _user_address: address,
        _asset_id: u64
    ) {}

    /// is applied to mint iAssets as soon as some amount of the original asset has been submitted to the interalayer vaults.
    /// premint function can be called only by PoEL contract
    /// @param: account - Poel signer account
    /// @param: asset_amount: amount of assets supplied
    /// @param: asset_id: asset id in the iAsset_table of LiquidityProvider struct
    /// @param: receiver - The address receiving the assets
    public fun premint_iAsset(
        _account: &signer,
        _asset_amount: u64,
        _asset_id: u64,
        _receiver: address,
    ) {}

    /// Function: mint_iAsset(user_address, assetID)
    /// Purpose: Intended to mint the pre-minted tokens of iAssets.
    /// The function can be called by anyone, not necessarily by the user themselves.
    /// @param: user_address - The user address receiving the assets
    /// @param: asset_id - asset id in the iAsset_table of LiquidityProvider struct
    public fun mint_iAsset(_user_address: address, _asset_id: u64) {}


    /// previewMint(asset_amount, assetID):
    /// Purpose: Calculates the total amount of iAsset that needs to be minted based on the submitted original assets.
    /// @param: provider_ref - Liquidity provider object geting previewd
    /// @param: asset_amount: amount of assets supplied
    /// @param: asset_id - asset id in the iAsset_table of LiquidityProvider struct
    /// @notice: return the amount of iAssets to get minted
    public fun previewMint(_provider_ref: &mut LiquidityProvider, _asset_amount: u64, _asset_id: u64): u64 {
        0
    }

    /// previewRedeem(iAsset_amount, assetID)
    /// previews the amount of assets to receive by specifying the amount of iAssets to redeem
    /// @param: iAsset_amount: amount of iAssets to be redeemed
    /// @param: asset_id - asset id in the iAsset_table of LiquidityProvider struct
    /// @notice: returns returns the amount converted assets 
    public fun previewRedeem(_iAsset_amount: u64, _asset_id: u64): u64 {
        0
    }

    /// previewWithdraw(asset_amount, assetID): preview the amount of iAsset to burn by specifying
    /// the amount of assets that would be withdrawn
    /// @param: asset_amount: amount of assets to be redeemed
    /// @param: asset_id - asset id in the iAsset_table of LiquidityProvider struct
    /// @notice: returns returns the amount of assets to get withdrawn 
    public fun previewWithdraw(_asset_amount: u64, _asset_id: u64): u64 {
        0
    }

    public fun redeem_request(
        _account: &signer,
        _iAsset_amount: u64,
        _asset_id: u64,
        _receiver_address: address
    ) {}

    public fun redeem_iAsset(
        _account: &signer,
        _asset_id: u64,
        _receiver_address: address
    ) {}

    /// This function is applied to transfer iAssets from a user to another
    public fun transfer_iAsset(
        _iAsset_amount: u64,
        _asset_id: u64,
        _receiver_address: address,
        _owner_address: address
    ) {}

    public fun transfer_asset(
        _asset_amount: u64,
        _asset_id: u64,
        _receiver_address: address,
        _owner_address: address
    ) {}

    public fun convertToAssets(_shares: u64, _asset_id: u64): u64 {
        0
    }

    /// Adds a new asset to the TotalLiquidityTable within the TotalLiquidity struct, initializing its financial metrics to default values.
    public fun add_new_iAsset(
        _account: &signer,
        _asset_name: String,
        _desirability_score: u64
    ) {}
}