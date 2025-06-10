module 0x2::fungible_asset_tests {
    use std::string::String;
    use supra_framework::object;
    use supra_framework::object::Object;
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use supra_framework::account;
    #[test_only]
    use supra_framework::fungible_asset;
    #[test_only]
    use supra_framework::object::{ConstructorRef};
    struct FakeMoney has key {}

    struct Metadata has key, copy, drop {
        /// Name of the fungible metadata, i.e., "USDT".
        name: String,
        /// Symbol of the fungible metadata, usually a shorter version of the name.
        /// For example, Singapore Dollar is SGD.
        symbol: String,
        /// Number of decimals used for display purposes.
        /// For example, if `decimals` equals `2`, a balance of `505` coins should
        /// be displayed to a user as `5.05` (`505 / 10 ** 2`).
        decimals: u8,
        /// The Uniform Resource Identifier (uri) pointing to an image that can be used as the icon for this fungible
        /// asset.
        icon_uri: String,
        /// The Uniform Resource Identifier (uri) pointing to the website for the fungible asset.
        project_uri: String,
    }

    /// Capability required to mint coins.
    struct MintCapability<phantom CoinType> has copy, store {}

    /// Capability required to freeze a coin store.
    struct FreezeCapability<phantom CoinType> has copy, store {}

    /// Capability required to burn coins.
    struct BurnCapability<phantom CoinType> has copy, store {}

    inline fun borrow_fungible_metadata<T: key>(
        metadata: &Object<T>
    ): &Metadata acquires Metadata {
        let addr = object::object_address(metadata);
        borrow_global<Metadata>(addr)
    }

    public fun metadata<T: key>(metadata: Object<T>): Metadata acquires Metadata {
        *borrow_fungible_metadata(&metadata)
    }

    struct TestToken has key {}

    #[test_only]
    public fun create_test_token(creator: &signer): (ConstructorRef, Object<TestToken>) {
        account::create_account_for_test(signer::address_of(creator));
        let creator_ref = object::create_named_object(creator, b"TEST");
        let object_signer = object::generate_signer(&creator_ref);
        move_to(&object_signer, TestToken {});

        let token = object::object_from_constructor_ref<TestToken>(&creator_ref);
        (creator_ref, token)
    }

    #[test(creator1 = @0xcafe, creator2 = @0xface)]
    fun test_metadata_from_different_modules(creator1: &signer, creator2: &signer) {
        let (creator_ref, metadata) = fungible_asset::create_test_token(creator1);
        let (creator_ref_test, metadata_test) = create_test_token(creator2);
        fungible_asset::init_test_metadata(&creator_ref);
        fungible_asset::init_test_metadata(&creator_ref_test);
        debug::print(&metadata);
        // [debug] 0x1::object::Object<0x1::fungible_asset::TestToken> {
        // inner: @0x37f294d40b6ca58d99537d7c6f4fdfb3f1ff442ac74694a71c15a8fba537cdb2
        // }
        debug::print(&metadata_test);
        // [debug] 0x1::object::Object<0x2::fungible_asset_tests::TestToken> {
        // inner: @0x2f81cd9f9c6933b4683404a2a2d2dc60ec682ed4f0f05112c88875fd72b7decb
        // }
    }
}
