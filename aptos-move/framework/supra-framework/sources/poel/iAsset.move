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
module supra_framework::iAsset {
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::vector;
    use aptos_std::smart_table::{Self, SmartTable};
    use std::signer;
    use std::string;
    use aptos_std::error;
    use aptos_std::object::{Self, Object, ExtendRef, ObjectCore};
    use aptos_std::math64;
    use std::option;
    use aptos_std::primary_fungible_store::Self;
    use aptos_std::fungible_asset::{Self, MintRef, TransferRef, BurnRef, Metadata};
    use supra_framework::reward_distribution;//::update_rewards;

    friend supra_framework::poel;

    /// The storage object name from object::create_named_object(address, OBJECT_NAME)
    const IASSET_GLOBAL: vector<u8> = b"IASSET_GLOBAL";

    /// thrown when the calling address is not poel as expected
    const ENOT_POEL_ADDRESS: u64 = 1;

    /// thrown when the the asset getting deployed is already deployed
    const EIASSET_ALREADY_DELOYED: u64 = 2;

    /// thrown when the preminiting_OLC_index > current total liquidity cycle index
    const EPREMINTING_OLC_EXCESS: u64 = 3;

    /// thrown when the asset balance is not enogh to perform an operation
    const EBALANCE_NOT_ENOUGH: u64 = 4;

    /// thrown when the unlock_olc index is > current_cycle_index
    const EUNLOCK_OLC_INDEX: u64 = 5;

    /// thrown when the redeem amount is lessthatn 0
    const EREDEEM_AMOUNT: u64 = 6;

    ///thrown when the wrong asset weight gets calculated
    const EWRONG_WEIGHT: u64 = 7;

    ///thrown when the length of the collaterixation weight vector does not match table entries
    const EWRONG_CWV_LENGTH: u64 = 8;

    ///thrown when the allowed signer is not the caller (owner)
    const ENOT_OWNER: u64 = 9;

    ///thrown when the length of the desirability_score_vector does not match table entries
    const EWRONG_DESIRABILITY_SCORE_LEN: u64 = 10;

    ///thrown when the asset id is not present in the TotalLiquidityTable
    const EASSET_NOT_PRESENT: u64 = 11;

    /// thrown when the assets' iterations don't match their number
    const EWRONG_ASSET_COUNT: u64 = 12; 


    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// AssetEntry struct that holds the iAsset's user's metrics
    struct AssetEntry has key, store, copy {
        ///UserRewardIndex: Track RewardIndex specific to the user for each asset.
        user_reward_index: u64,
        ///Preminted_iAssets: Tracks  number  of iAssets that are preminted.
        preminted_iAssets: u64,
        ///Redeem_Requested_iAssets: Number of iAssets for which redemption has been requested.
        redeem_requested_iAssets: u64,
        ///Preminiting_OLC_Index: Records the index of the last cycle during which a preminting request was submitted for an asset.
        preminiting_OLC_index: u64
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// tracks the liquidity of every asset.
    struct LiquidityTableItems has key, store {
        ///asset_supply: Total amount of the asset that has been bridged to create the iAsset.
        asset_supply: u64,
        ///desired_weights: Weights reflecting the asset's strategic importance.
        desired_weight: u64,
        ///desirability_score: Attractiveness score of the asset.
        desirability_score: u64,
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    /// Liquidity provider struct that holds the overal info on the user's iAssets
    struct LiquidityProvider has key {
        ///allocated_Rewards: Tracks the total rewards that are allocable to the user.
        allocated_rewards: u64,//not updated at any point??
        ///unlock_OLC_Index: Registers the index of the lockup cycle when the user last submitted an unlock request.
        unlock_olc_index: u64//not updated at any point??
    }

    #[resource_group_member(group = supra_framework::object::ObjectGroup)]
    ///This struct aggregates comprehensive liquidity metrics and operational indices for assets managed within the system.
    struct TotalLiquidity has key {
        ///Index of the last observable lockup cycle (OLC), crucial for the minting of preminted tokens and the withdrawal of unlocked tokens.
        current_olc_index: u64, //not update at any point??
        ///Represents the nominal value of all assets submitted to the system, indicating the total economic stake.
        total_nominal_value: u64
    }

    #[resource_group_member(group = aptos_std::object::ObjectGroup)]
    /// This struct holds the refences for managing the iAsset fungible assets
    struct ManagingRefs has key {
        /// enables minting
        mint_ref: MintRef,
        /// enables transfers
        transfer_ref: TransferRef,
        /// enables burning
        burn_ref: BurnRef,
    }

    #[resource_group_member(group = aptos_std::object::ObjectGroup)]
    /// this object tracks all iAssets created in this module
    /// it stores assets in a table mapping their symbols to a bool
    /// it can change to an asset id or an address depending on which is convenient
    struct AssetTracker has key {
        liquidity_provider_objects: SimpleMap<address, address>,
        assets: SmartTable<vector<u8>, bool>,//maps asset symbol to a bool
    }

    fun init_module(account: &signer) {
        let constructor_ref = object::create_named_object(account, IASSET_GLOBAL);

        let global_signer = &object::generate_signer(&constructor_ref);

        move_to(
            global_signer,
            AssetTracker {
                liquidity_provider_objects: simple_map::create<address, address>(),
                assets: smart_table::new()
            }
        );

        move_to(global_signer, TotalLiquidity {
            current_olc_index: 0,
            total_nominal_value: 0,
        });
    }

    /// Function create_new_iAsset
    /// Description creates a new iAsset as a fungible asset and tracks it in the AssetTracker
    /// @param iAsset_name: the name of the iAsset
    /// @param iAsset_symbol: its corresponding symbol
    public fun create_new_iAsset(account: &signer, iAsset_name: vector<u8>, iAsset_symbol: vector<u8>) acquires AssetTracker {
        assert!(signer::address_of(account) == @supra_framework, error::permission_denied(ENOT_POEL_ADDRESS));
        let tracker_address = object::create_object_address(&@supra_framework, IASSET_GLOBAL);

        //assert that the iAsset has not been deployed yet
        assert!(!
            *smart_table::borrow(&borrow_global<AssetTracker>(tracker_address).assets, iAsset_symbol),
            error::already_exists(EIASSET_ALREADY_DELOYED)
        );

        //Create the asste Metadata constructor_reference
        let metadata_constructor_ref = &object::create_named_object(
            account, iAsset_symbol
        );

        // Create a store enabled fungible asset
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            metadata_constructor_ref,
            option::none(),
            string::utf8(iAsset_name),
            string::utf8(iAsset_symbol),
            6,
            string::utf8(b""),
            string::utf8(b""),
        );


        // generate the mint, burn and transfer refs then store
        let mint_ref = fungible_asset::generate_mint_ref(metadata_constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(metadata_constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(metadata_constructor_ref);
        let metadata_object_signer = &object::generate_signer(metadata_constructor_ref);
        move_to(
            metadata_object_signer,
            ManagingRefs { mint_ref, transfer_ref, burn_ref }
        );

        move_to(metadata_object_signer, LiquidityTableItems {
                asset_supply: 0,
                desired_weight: 0,
                desirability_score: 0,
            });

        // track the deployed asset in the AssetTracker assets table
        smart_table::add(
            &mut borrow_global_mut<AssetTracker>(tracker_address).assets,
            iAsset_symbol,
            true
        );
    }

    #[view]
    /// Function asset_addess
    /// Description returns the address of the assets's metadata derived from the creator and its symbol
    /// @param: symbol: the symbol used during the creation of the asset's object
    public fun asset_address(symbol: vector<u8>): address {
        object::create_object_address(&@supra_framework, symbol)
    }


    #[view]
    /// Function asset_metadata
    /// Description returns the assets's metadata derived from its address
    /// @param symbol: the symbol used during the creation of the asset's object
    public fun asset_metadata(symbol: vector<u8>): Object<Metadata> {
        object::address_to_object<Metadata>(asset_address(symbol))
    }

    #[view]
    /// Get the address of the global storage object
    public fun get_storage_address(): address {
        object::create_object_address(&@supra_framework, IASSET_GLOBAL)
    }

    #[view]
    /// Function get_liquidity_table_items(symbol)
    /// Desctiption: Retrives the data in the liquidity table struct
    /// @param: symbol - vector<u8>
    /// returns: (asset_supply, iAsset_supply, desired_weight, desirability_score)
    public fun get_liquidity_table_items(symbol: vector<u8>): (u64, u64, u64,) acquires LiquidityTableItems {        
        let items = borrow_global<LiquidityTableItems>(asset_address(symbol));

        (items.asset_supply, items.desired_weight, items.desirability_score)
    }

    #[view]
    /// Function get_total_liquidity
    /// Desctiption: Retrives the data in the total_liquidity
    /// returns: (current_olc_index, total_nominal_value)
    public fun get_total_liquidity(): (u64, u64) acquires TotalLiquidity {
        let obj_address = object::create_object_address(&@supra_framework, IASSET_GLOBAL);

        let total_obj = borrow_global<TotalLiquidity>(obj_address);

        (total_obj.current_olc_index, total_obj.total_nominal_value)
    }

    #[view]
    /// Function: get_asset_price(asset_symbol)
    /// Description: Gets an asset's prce from the price oracle
    /// @param: asset_symbol - vector<u8>
    public fun get_asset_price(asset_symbol: vector<u8>): u64 {
        0
    }

    #[view]
    /// Function: get_iAsset_supply(asset: Object<Metadata>)
    /// Description: Gets an asset's prce from the price oracle
    /// @param: asset - Object<Metadata>
    /// returns: u64
    public fun get_iAsset_supply(asset: Object<Metadata>): u64 {
        (option::extract(&mut fungible_asset::supply(asset)) as u64)

    }

    #[view]
    /// Function: get_assets
    /// Description: Gets all asset names from AssetTracker
    /// returns: vector<vector<u8>
    public fun get_assets(): vector<vector<u8>> acquires AssetTracker {
        let tracked_assets = borrow_global<AssetTracker>(get_storage_address());

        let return_value: vector<vector<u8>> = vector::empty();

        smart_table::for_each_ref<vector<u8>, bool>(
            &tracked_assets.assets,
            | key, _value|
        {
            //let is_there: &bool = value;
            let symbol = *key;
            vector::push_back<vector<u8>>(&mut return_value, symbol);

        });
        return_value
    }

    #[view]
    /// Function: get_provider_address(account)
    /// Description: Gets Liquidity provider object address for the account
    /// @param: account - address of the user
    /// returns: address
    fun get_provider_address(account: address): address acquires AssetTracker {
        let tracked_assets = borrow_global<AssetTracker>(get_storage_address());

        *simple_map::borrow(&tracked_assets.liquidity_provider_objects, &account)
    }


    /// Function: create_iAsset_entry(account, asset)
    /// Description: This function created an AssetEntry record on an address's FungibleStore's address
    /// @param: account - address of the user
    /// @param: asset - the target asset
    public fun create_iAsset_entry(account: address, asset: Object<Metadata>) acquires AssetTracker {
        initialize_LiquidityProvider(account);
        let primary_store = primary_fungible_store::ensure_primary_store_exists(account, asset);
        let store_address = object::object_address(&primary_store); 
        if (!object::object_exists<ObjectCore>(store_address)) {
        // create and object 
            let constructor_ref = &object::create_object(store_address);

            let object_signer = &object::generate_signer(constructor_ref);

            move_to(
                object_signer,
                  AssetEntry {
                      user_reward_index: 0,
                      preminted_iAssets: 0,
                      redeem_requested_iAssets: 0,
                      preminiting_OLC_index: 0
                  }
            )
        }
    }

    ///Function to set up initial LiquidityProvider structures for asset management.
    /// Desctription: Create an liquidityProvider for an addres if its not created
    /// @param: user_address - address of the user
    public fun initialize_LiquidityProvider(user_address: address) acquires AssetTracker {

        // check if the object was created and tracked
        let liquidity_provider_address = get_provider_address(user_address);
        if (!object::object_exists<ObjectCore>(liquidity_provider_address)) {
            let constructor_ref = object::create_object(user_address);
            let account = &object::generate_signer(&constructor_ref);
            let liquidity_provider = LiquidityProvider {
                allocated_rewards: 0u64,
                unlock_olc_index: 0u64
            };
            move_to(account, liquidity_provider);
        }
    }


    #[view]
    /// Function: get_asset_entry
    /// returns the iAsset entry values as a tuple
    /// @param: user_address - the user address geting checked
    /// @param: asset - the asset metadata
    /// @return (u64, u64, u64, u64) - (user_reward_index, preminted_iAssets, redeem_requested_iAssets, preminiting_OLC_index)
    public fun get_asset_entry(user_address: address, asset: Object<Metadata>): (u64, u64, u64, u64) acquires AssetEntry {
        let store_address = primary_fungible_store::primary_store_address<Metadata>(user_address, asset);

        if (fungible_asset::store_exists(store_address)) {
            let item = borrow_global_mut<AssetEntry>(store_address);
            (item.user_reward_index, item.preminted_iAssets, item.redeem_requested_iAssets, item.preminiting_OLC_index)

        } else {
            (0, 0, 0, 0)
        }
    }


    /// Function: premint_iAsset 
    /// Description: is applied to mint iAssets as soon as some amount of the original asset has been submitted to the interalayer vaults.
    /// @notice: premint function can be called only by PoEL contract 
    /// @param: account has to be the poel contract
    /// @param: asset_amount asssets to be minted
    /// @param: asset: the asset getting minted
    /// @param: receiver the receiving address
    public(friend) fun premint_iAsset(
        account: &signer,
        asset_amount: u64,
        asset_symbol: vector<u8>,
        receiver: address,
        asset_supply: u64,
    ) acquires AssetEntry, ManagingRefs, TotalLiquidity, AssetTracker {
        // confirm the caller is the right address
        assert!(signer::address_of(account) == @supra_framework, error::permission_denied(ENOT_POEL_ADDRESS));

        //let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address(asset_symbol));

        //ensure the reciver has a fungible store of the iAsset
        let primary_store = primary_fungible_store::ensure_primary_store_exists(receiver, asset_metadata(asset_symbol));
        // check whether the AssetEntry struct is in the store address
        create_iAsset_entry(receiver, asset_metadata(asset_symbol));

        mint_iAsset(receiver, asset_symbol);

        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());

        let asset_entry = borrow_global_mut<AssetEntry>(object::object_address(&primary_store));
        let iAsset_amount = previewMint(asset_supply, asset_amount, asset_metadata(asset_symbol));

        asset_entry.preminted_iAssets = (asset_entry.preminted_iAssets + iAsset_amount);
        asset_entry.preminiting_OLC_index = total_liquidity_ref.current_olc_index;
    }


    /// Function: mint_iAsset
    /// Purpose: Intended to mint the pre-minted tokens of iAssets.
    /// The function can be called by anyone, not necessarily by the user themselves.
    /// @param: user_address - the user address geting checked
    /// @param: asset - the asset metadata
    public fun mint_iAsset(
        user_address: address,
        asset_symbol: vector<u8>,
    ) acquires ManagingRefs, AssetEntry, TotalLiquidity, AssetTracker {

        let mint_ref = &borrow_global<ManagingRefs>(
            asset_address(asset_symbol)
        ).mint_ref;

        let total_liquidity_ref = borrow_global<TotalLiquidity>(get_storage_address());

        let primary_store = primary_fungible_store::ensure_primary_store_exists(user_address, asset_metadata(asset_symbol));

        //assert!(exists<AssetEntry>(object::object_address(&primary_store)));
        create_iAsset_entry(user_address, asset_metadata(asset_symbol));

        let asset_entry = borrow_global_mut<AssetEntry>(object::object_address(&primary_store));

        //Assert that Preminiting_OLC_Index < current_cycle_index.
        assert!(
            asset_entry.preminiting_OLC_index < total_liquidity_ref.current_olc_index,
            error::invalid_state(EPREMINTING_OLC_EXCESS)
        );
        //Check PremintedAssetBalance (fetched from iAsset_table using assetID) . If PremintedAssetBalance > 0:
        if (asset_entry.preminted_iAssets > 0) {

            //mint into primary store
            primary_fungible_store::mint(mint_ref, user_address, asset_entry.preminted_iAssets);
            //Set PremintedAssetBalance = 0.
            asset_entry.preminted_iAssets = 0;
            //Call update_rewards(owner address, asset).
            reward_distribution::update_rewards(user_address, asset_entry.user_reward_index, asset_metadata(asset_symbol));
        }
    }


    /// previewMint(asset_amount, assetID):
    /// Purpose: Calculates the total amount of iAsset that needs to be minted based on the submitted original assets.
    /// @param: amount - the amount to mint
    /// @param: asset - the asset metadata
    public fun previewMint(asset_supply: u64, asset_amount: u64, asset: Object<Metadata>): u64 {

        // get the iAsset total supply
        //let i_asset = fungible_asset::supply(asset);
        ////@phydy: confirm the best to use
        //let _x = (option::extract(&mut i_asset) as u64);
        //Retrieve Asset_supply from the iAsset_table using assetID.
        let iAsset_supply = get_iAsset_supply(asset);

        //let (_, asset_supply, iAsset_supply, _, _) = get_liquidity_table_items(asset);

        //Calculate asset_needed based on the current iAsset_supply:
        let asset_needed: u64;

        //If iAsset_supply equals 0, set asset_needed to asset_amount.
        if (iAsset_supply == 0) {
            asset_needed = asset_amount;
        } 
        // If iAsset_supply is greater than 0, calculate asset_needed as the rounded up result of
        // (asset_amount * asset_supply / iAsset_supply) to account for division truncation.
        else {

            // rounding up when division truncation occurs 
            asset_needed = (asset_amount * iAsset_supply + asset_supply - 1) / asset_supply + 1;
        };
        //Return asset_needed
        asset_needed
    }

    /// Function: previewRedeem(iAsset_amount, asset): preview the amount of assets to receive by specifying the amount of iAssets to redeem
    /// @param: iAsset_amount - the iAsset amount getting previewed
    /// @param: asset - the asset metadata
    /// return u64 - from convertToAssets(iAsset_amount, asset)
    public fun previewRedeem(asset_supply: u64, iAsset_amount: u64, asset: Object<Metadata>): u64 {
        let asset_amount = convertToAssets(asset_supply, iAsset_amount, asset);
        asset_amount
    }

    /// previewWithdraw(asset_amount, asset): preview the amount of iAsset to burn by specifying the amount of assets that would be withdrawn
    /// @param: iAsset_amount - the iAsset amount getting previewed
    /// @param: asset - the asset metadata
    /// return: u64 - calculated iAsset_to_burn
    public fun previewWithdraw(asset_supply: u64, asset_amount: u64, asset: Object<Metadata>): u64 {
        //let (_, asset_supply, iAsset_supply, _, _) = get_liquidity_table_items(asset);

        let iAsset_supply = get_iAsset_supply(asset);

        let iAsset_to_burn: u64;

        if (iAsset_supply == 0) {
            iAsset_to_burn = asset_amount;
        } else {
            //@phydy: to change
            let totalAssets = asset_supply;//getTotalAssets(asset_id); // Assume this function fetches total assets
            iAsset_to_burn = (asset_amount * iAsset_supply + totalAssets - 1) / totalAssets + 1;
        };

        // Return the calculated iAsset_to_burn
        iAsset_to_burn
    }

    /// Function: redeem_request(account, iAsset_amount, asset, receiver_address)
    /// Description: A request to redeem iAssets
    /// @param: account - the account submiting the redeem request
    /// @param: iAsset_amount - amount of iAssets getting redeemed
    /// @param: asset - iAsset getting redeemed
    /// @param: receiver_address - address receiving the assets on the intra laver vault
    public fun redeem_request(
        account: &signer,
        iAsset_amount: u64,
        asset_symbol: vector<u8>,
        receiver_address: address,
        current_cycle_index: u64
    ) acquires AssetEntry, ManagingRefs, LiquidityTableItems, AssetTracker, LiquidityProvider {
        let asset = asset_metadata(asset_symbol);
        let account_address = signer::address_of(account);
        let iAssetBalance = primary_fungible_store::balance(account_address, asset);

        assert!(iAssetBalance >= iAsset_amount, error::invalid_state(EBALANCE_NOT_ENOUGH));

        let primary_store = primary_fungible_store::ensure_primary_store_exists(account_address, asset);

        create_iAsset_entry(account_address, asset);

        redeem_iAsset(account, asset, receiver_address, current_cycle_index, iAsset_amount);

        let asset_entry = borrow_global_mut<AssetEntry>(object::object_address(&primary_store));

        //burn the assets
        let burn_ref = &borrow_global<ManagingRefs>(object::object_address(&asset)).burn_ref;

        primary_fungible_store::burn(burn_ref, account_address, iAsset_amount);

        reduce_asset_supply(asset_symbol, iAsset_amount);

        asset_entry.redeem_requested_iAssets + iAsset_amount;

        reward_distribution::update_rewards(account_address, asset_entry.user_reward_index, asset);

        let current_cycle_index = current_cycle_index;

        let provider_ref = borrow_global_mut<LiquidityProvider>(get_provider_address(account_address));

        provider_ref.unlock_olc_index = current_cycle_index;
        //preminting_olc_index = current_cycle_index;
        asset_entry.preminiting_OLC_index = current_cycle_index;
    }

    /// Function: redeem_iAsset(account, asset, receiver_address)
    /// Description: called to to redeem iAssets ie withdraw
    /// @param: account - the account submiting the redeem request
    /// @param: asset - iAsset getting redeemed
    /// @param: receiver_address - address receiving the assets on the intra laver vault
    fun redeem_iAsset(
        account: &signer,
        asset: Object<Metadata>,
        _receiver_address: address,
        current_cycle_index: u64,
        asset_supply: u64
    ) acquires LiquidityProvider, AssetEntry, AssetTracker {
        let account_address = signer::address_of(account);

        let primary_store = primary_fungible_store::ensure_primary_store_exists(account_address, asset);

        //assert!(exists<AssetEntry>(object::object_address(&primary_store)));
        create_iAsset_entry(account_address, asset);
        let provider_ref = borrow_global_mut<LiquidityProvider>(get_provider_address(account_address));


        let asset_entry = borrow_global_mut<AssetEntry>(object::object_address(&primary_store));

        // Ensure that the unlock_olc_index is less than the current cycle index
        assert!(provider_ref.unlock_olc_index < current_cycle_index, error::invalid_state(EUNLOCK_OLC_INDEX));

        // Ensure that redeem_requested_iAssets is greater than or equal to 0
        assert!(asset_entry.redeem_requested_iAssets >= 0, error::invalid_state(EREDEEM_AMOUNT));

        let _asset_to_withdraw = previewWithdraw(asset_supply, asset_entry.redeem_requested_iAssets, asset);

        // Verify that the receiver address is valid (assuming a helper function verify_receiver_address exists)
        //assert!(verify_receiver_address(receiver_address), 2);

        asset_entry.redeem_requested_iAssets = 0;



        //Bridge::trigger_sendToUser(asset_id, asset_to_withdraw, receiver_address);
//
        //IntraLayerVault::sendToUser(asset_id, asset_to_withdraw, receiver_address);
    }

    /// Function: transfer_iAsset(account, asset, receiver_address)
    /// Description: called to transfer iAssets to another address
    /// @param: account - the account submiting the redeem request
    /// @param: asset - iAsset getting redeemed
    /// @param: receiver_address - address receiving the assets
    public fun transfer_iAsset(
        account: &signer,
        iAsset_amount: u64,
        asset: Object<Metadata>,
        receiver_address: address,
    ) acquires AssetEntry, AssetTracker {
        let owner_address = signer::address_of(account);
        let owner_primary_store = primary_fungible_store::ensure_primary_store_exists(owner_address, asset);
        //let receiver_primary_store = primary_fungible_store::ensure_primary_store_exists(receiver_address, asset);

        let owner_asset_entry = borrow_global_mut<AssetEntry>(object::object_address(&owner_primary_store));

        // Ensure the asset is initialized in the owner's LiquidityProvider struct
        create_iAsset_entry(owner_address, asset);

        // Ensure the asset is initialized in the receiver's LiquidityProvider struct
        create_iAsset_entry(receiver_address, asset);

        let owner_iAsset_balance = fungible_asset::balance(owner_primary_store);

        assert!(
            owner_iAsset_balance - owner_asset_entry.redeem_requested_iAssets >= iAsset_amount,
            error::invalid_argument(EBALANCE_NOT_ENOUGH)
        ); // to confirm on pending_withdraw_balance_iAsset

        //invoke transfer
        //*owner_iAsset_balance -= iAsset_amount;
        primary_fungible_store::transfer(account, asset, receiver_address, iAsset_amount);

        //let (receiver_iAsset_balance, _, _, _, _) = table::borrow_mut(&mut receiver_provider_ref.iAsset_table, asset_id);
        //*receiver_iAsset_balance += iAsset_amount;

            reward_distribution::update_rewards(owner_address, owner_asset_entry.user_reward_index, asset);
    }
//
//    public fun transfer_asset(
//        asset_amount: u64,
//        asset_id: u64,
//        receiver_address: address,
//        owner_address: address
//    ) {
//        let iAsset_amount = convertToiAssets(asset_amount, asset_id);
//
//        let owner_provider_ref = borrow_global_mut<LiquidityProvider>(owner_address);
//        let (owner_iAsset_balance, _, _, _, _) = table::borrow_mut(&mut owner_provider_ref.iAsset_table, asset_id);
//        assert!(*owner_iAsset_balance >= iAsset_amount, 0);
//
//        *owner_iAsset_balance -= iAsset_amount;
//
//        if (!exists<LiquidityProvider>(receiver_address)) {
//            initialize_LiquidityProvider(receiver_address);
//        }
//        add_asset_LiquidityProvider(asset_id, receiver_address);
//
//        let receiver_provider_ref = borrow_global_mut<LiquidityProvider>(receiver_address);
//        let (receiver_iAsset_balance, _, _, _, _) = table::borrow_mut(&mut receiver_provider_ref.iAsset_table, asset_id);
//        *receiver_iAsset_balance += iAsset_amount;
//
//        update_rewards(owner_address, asset_id);
//    }
//
    ///Function convertToAssets(shares, asset)
    /// Description: Converts the asiAssets to assets before redemption
    /// @param: shares - the iAsset amount getting previewed
    /// @param: asset - the asset metadata
    /// return u64 
    public fun convertToAssets(asset_supply: u64, shares: u64, asset: Object<Metadata>): u64 {
        //let (_, asset_supply, iAsset_supply, _, _) = get_liquidity_table_items(asset);

        let iAsset_supply = get_iAsset_supply(asset);

        let asset_amount: u64;

        if (iAsset_supply == 0) {
            asset_amount = shares;
        } else {
            asset_amount = (shares * asset_supply) / iAsset_supply;
        };

        asset_amount
    }

//    /// Adds a new asset to the TotalLiquidityTable within the TotalLiquidity struct, initializing its financial metrics to default values.
//    public fun add_new_iAsset(
//        signer: &signer,
//        asset_name: String,
//        desirability_score: u64
//    ) {
//        // Ensure the function is called by an authorized signer (admin)
//        assert!(signer::address_of(signer) == ADMIN_ADDRESS, 0);
//
//        // Borrow a mutable reference to the TotalLiquidity struct
//        let total_liquidity_ref = borrow_global_mut<TotalLiquidity>(TOTAL_LIQUIDITY_ADDRESS);
//
//        let new_asset_id = total_liquidity_ref.last_asset_id + 1;
//        total_liquidity_ref.last_asset_id = new_asset_id;
//
//        let initial_metrics = (0, 0, 0, 0); // (collaterisation_rate, asset_price, iAsset_supply, asset_supply)
//
//        table::add(
//            &mut total_liquidity_ref.TotalLiquidityTable,
//            new_asset_id,
//            initial_metrics
//        );
//
//        total_liquidity_ref.asset_metadata.insert(new_asset_id, (asset_name, desirability_score));
//
//        total_liquidity_ref.desirable_weights.insert(new_asset_id, 0);
//
//        // Inform the admin that they must call updateDesiredWeights to allocate the desired weight
//        // This could be done through an event or a log, depending on your system design
//    }

    fun reduce_asset_supply(asset: vector<u8>, amount: u64) acquires LiquidityTableItems {
        let obj_address = asset_address(asset);

        let liquidity_ref = borrow_global_mut<LiquidityTableItems>(obj_address);

        liquidity_ref.asset_supply = liquidity_ref.asset_supply - amount;
    }

    /// Function: update_desired_weight(desired_weight_vector, signer)
    /// Purpose: Updates asset weights in the TotalLiquidity struct to align with current strategic objectives.
    /// Description:
    /// Ensure the sum of desired weights in the vector equals 1; if not, throw an error.
    /// Update desired_weights for all assets in TotalLiquidity based on the vector.

    public fun update_desired_weight(
        desired_weight_vector: vector<u64>,
        account: &signer
    ) acquires AssetTracker, LiquidityTableItems {
        //Verify admin authority and existence of TotalLiquidity in Supra_framework.
        assert!(signer::address_of(account) == @supra_framework, error::permission_denied(ENOT_OWNER));

        let obj_address = get_storage_address();

        let tracked_assets = borrow_global<AssetTracker>(obj_address);

        let num_assets = smart_table::length(&tracked_assets.assets);
        //Check that desired_weight_vector length matches the number of assets in TotalLiquidity.

        assert!(
            vector::length(&desired_weight_vector) == num_assets, error::invalid_argument(EWRONG_CWV_LENGTH)
        );

        let total_weight: u64 = 0;


        vector::for_each(desired_weight_vector,  | weight| {total_weight = total_weight + weight});

        //Ensure the sum of desired weights in the vector equals 1; if not, throw an error.
        assert!(total_weight == 1, error::invalid_argument(EWRONG_WEIGHT));

        //Update desired_weights for all assets in TotalLiquidity based on the vector.
        let index = 0;
        smart_table::for_each_ref<vector<u8>, bool>(
            &tracked_assets.assets,
            | key, _value|
        {
            let symbol = *key;
            let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address(symbol));
            let new_desired_weight = vector::borrow(&desired_weight_vector, index);
            table_obj.desired_weight = *new_desired_weight;
            index = index + 1;
        });

        assert!(index == num_assets, error::invalid_state(EWRONG_ASSET_COUNT));
    }

    /// batch_update_desirability_score(desirability_score_vector, signer)
    /// Purpose: Updates desirability scores for all assets in the TotalLiquidity struct.
    public fun batch_update_desirability_score(
        desirability_score_vector: vector<u64>,
        signer: &signer
    ) acquires AssetTracker, LiquidityTableItems {
        //Verifies that the function caller is an authorized admin.
        assert!(signer::address_of(signer) == @supra_framework, error::permission_denied(ENOT_OWNER));

        let obj_address = get_storage_address();

        let tracked_assets = borrow_global<AssetTracker>(obj_address);

        //Asserts that the length of desirability_score_vector matches the number of assets in TotalLiquidity.
        let num_assets = smart_table::length(&tracked_assets.assets);

        assert!(
            vector::length(&desirability_score_vector) == num_assets, error::invalid_argument(EWRONG_DESIRABILITY_SCORE_LEN)
        );

        //Adjusts the desirability_score for each asset in TotalLiquidity based on the new scores provided.
        let index = 0;
        smart_table::for_each_ref<vector<u8>, bool>(
            &tracked_assets.assets,
            | key, _value|
        {
            let symbol = *key;
            let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address(symbol));
            let new_desirability_score = vector::borrow(&desirability_score_vector, index);
            table_obj.desirability_score = *new_desirability_score;
            index = index + 1;
        });
    }

    /// update_desirability_score(signer,desirability_score, assetID) 
    /// Purpose: Updates the desirability score of a specified asset within the TotalLiquidity struct of the Supra_framework.
    public fun update_desirability_score(
        signer: &signer,
        desirability_score: u64,
        asset_symbol: vector<u8>,
    ) acquires AssetTracker, LiquidityTableItems  {
        //Verifies that the function caller is an authorized admin.
        assert!(signer::address_of(signer) == @supra_framework, error::permission_denied(ENOT_OWNER));

        let obj_address = get_storage_address();

        let tracked_assets = borrow_global<AssetTracker>(obj_address);
        //Confirms that the assetID corresponds to an asset within TotalLiquidity.
        assert!(
            smart_table::contains(&tracked_assets.assets, asset_symbol),
            error::not_found(EASSET_NOT_PRESENT)
        );

        //Adjusts the desirability score for the asset based on the provided score and assetID.
        let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address(asset_symbol));

        table_obj.desirability_score = desirability_score;
    }

    /// updates asset prices and calculates new supply metrics for collateral management in the system.
    public(friend) fun update_asset_price_supply() acquires TotalLiquidity, AssetTracker, LiquidityTableItems {
        let total_nominal_liquidity: u64 = 0;
        let total_liquidity_ref = borrow_global_mut<TotalLiquidity>(get_storage_address());
        let tracked_assets = borrow_global<AssetTracker>(get_storage_address());


        smart_table::for_each_ref<vector<u8>, bool>(
            &tracked_assets.assets,
            | key, _value|
        {
            //let is_there: &bool = value;
            let symbol = *key;
            let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address(symbol));
            let new_asset_price = 0; //get_asset_price_from_oracle(asset_id); // Assuming a function to get the asset price
            
            // Fetch asset details and calculate new supply
            let borrow_request = 0;// get_borrow_request(asset_id); // Assuming a function to get borrow requests
            let withdraw_request = 0;// get_withdraw_request(asset_id); // Assuming a function to get withdraw requests
            let new_supply = table_obj.asset_supply + borrow_request - withdraw_request;

            let nominal_liquidity_of_asset = new_supply * new_asset_price;

            table_obj.asset_supply = new_supply;
            //table_obj.collateralisation_rate = nominal_liquidity_of_asset;

            total_nominal_liquidity = total_nominal_liquidity + nominal_liquidity_of_asset;

            total_liquidity_ref.total_nominal_value = total_nominal_liquidity;

        });
    }


    public(friend) fun update_single_asset_supply(symbol: vector<u8>, new_supply: u64): u64 acquires LiquidityTableItems {
        let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address(symbol));
        table_obj.asset_supply = table_obj.asset_supply + new_supply;
        table_obj.asset_supply

    }

    public fun calculate_total_rentable(
        coefficient_k: u64,
        coefficient_m: u64,
        //coefficient_rho: u64,
        min_collateralisation: u64,
        max_collateralisation_first: u64

    ): u64 acquires AssetTracker, LiquidityTableItems, TotalLiquidity {
        let tracked_assets = borrow_global<AssetTracker>(get_storage_address());

        let asset_price = 1;//get_asset_price();
        let total_rentable_amount: u64 = 0;

                smart_table::for_each_ref<vector<u8>, bool>(
            &tracked_assets.assets,
            | key, _value|
        {
            //let is_there: &bool = value;
            let symbol = *key;
            let collateralisation_rate = calculate_collaterisation_rate(
                symbol,
                coefficient_k,
                coefficient_m,
                //coefficient_rho,
                min_collateralisation,
                max_collateralisation_first

            );
            let table_obj = borrow_global_mut<LiquidityTableItems>(asset_address(symbol));

            total_rentable_amount = total_rentable_amount + (table_obj.asset_supply / collateralisation_rate) * asset_price;
        });
        total_rentable_amount

    }


    //5. calculate_collaterisation_rate(asset_nominal_value, total_nominal_value, assetID)
    //Purpose: Calculates and updates the collateralization rate for a specified asset based on dynamic market weights and predefined coefficients.
    public fun calculate_collaterisation_rate(
        symbol: vector<u8>,
        coefficient_k: u64,
        coefficient_m: u64,
        //coefficient_rho: u64,
        min_collaterisation: u64,
        max_collateralisation_first: u64
    ): u64 acquires TotalLiquidity, LiquidityTableItems {

        let total_liquidity_ref = borrow_global_mut<TotalLiquidity>(get_storage_address());

        let (asset_supply, desired_weight, _) = get_liquidity_table_items(symbol);

        let collaterisation_rate_for_asset = 0;

        let asset_weight = asset_supply / total_liquidity_ref.total_nominal_value; //to convert to f64

        if (asset_weight <= desired_weight) {
            let numerator = desired_weight - asset_weight;
            let denominator = desired_weight;
            let ratio = numerator / denominator;
            let ratio_exp = math64::pow(ratio, coefficient_k);

            collaterisation_rate_for_asset = min_collaterisation + ( 
                max_collateralisation_first - min_collaterisation) * ratio_exp;
        } else {
            let numerator = asset_weight - desired_weight;
            let denominator = 100 - desired_weight;
            let ratio = numerator / denominator;
            let ratio_exp = math64::pow(ratio, coefficient_m);

            collaterisation_rate_for_asset = 
                min_collaterisation +
                (max_collateralisation_first - min_collaterisation) * ratio_exp;
        };
        collaterisation_rate_for_asset
    }

    public(friend) fun poel_update_olc_index() acquires TotalLiquidity {
        let total_liquidity_ref = borrow_global_mut<TotalLiquidity>(get_storage_address());

        total_liquidity_ref.current_olc_index = total_liquidity_ref.current_olc_index + 1;

    }

}