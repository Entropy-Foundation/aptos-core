/// Added via upgrade
module supra_framework::coin_factory {
    use std::signer;
    use std::string::String;
    use supra_framework::coin;

    const ONLY_COIN_MANAGER: u64 = 1;

    struct USDC {}

    struct USDT {}

    struct WBTC {}

    struct WETH {}

    struct WSOL {}

    struct CoinManager<phantom CoinType> has key {
        mint_capability: coin::MintCapability<CoinType>,
        freez_capability: coin::FreezeCapability<CoinType>,
        burn_capability: coin::BurnCapability<CoinType>
    }

    public entry fun create_coin<CoinType>(
        tx_sender: &signer,
        name: String,
        symbol: String,
        deciamals: u8,
        monitory_supply: bool
    ) {
        let (burn_capability, freez_capability, mint_capability) = coin::initialize<CoinType>(
            tx_sender,
            name,
            symbol,
            deciamals,
            monitory_supply,
        );
        move_to(tx_sender, CoinManager {
            mint_capability,
            freez_capability,
            burn_capability,
        })
    }

    public entry fun register_user<CoinType>(tx_sender: &signer) {
        coin::register<CoinType>(tx_sender)
    }

    public entry fun mint<CoinType>(sender: &signer, to: address, amount: u64) acquires CoinManager {
        let sender_addr = signer::address_of(sender);
        assert!(exists<CoinManager<CoinType>>(sender_addr) == true,
            ONLY_COIN_MANAGER);
        coin::deposit(
            to,
            coin::mint<CoinType>(amount, &borrow_global<CoinManager<CoinType>>(sender_addr).mint_capability)
        )
    }

    public entry fun burn<CoinType>(sender: &signer, from: address, amount: u64) acquires CoinManager {
        let sender_addr = signer::address_of(sender);
        assert!(exists<CoinManager<CoinType>>(sender_addr) == true,
            ONLY_COIN_MANAGER);
        coin::burn_from<CoinType>(
            from,
            amount,
            &borrow_global<CoinManager<CoinType>>(sender_addr).burn_capability
        )
    }

    public entry fun freeze_user_coin_store<CoinType>(sender: &signer, user: address) acquires CoinManager {
        let sender_addr = signer::address_of(sender);
        assert!(exists<CoinManager<CoinType>>(sender_addr) == true,
            ONLY_COIN_MANAGER);
        coin::freeze_coin_store<CoinType>(
            user,
            &borrow_global<CoinManager<CoinType>>(sender_addr).freez_capability
        )
    }
}
