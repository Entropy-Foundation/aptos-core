module supra_framework::dkg_config {

    use std::error;
    use std::option;
    use std::vector;
    use aptos_std::bls12381;
    use aptos_std::ed25519;
    use supra_framework::system_addresses;
    friend supra_framework::stake;
    friend supra_framework::reconfiguration_with_dkg;
    friend supra_framework::dkg;

    /// Invalid ed25519 public key
    const EINVALID_EDPUBLIC_KEY: u64 = 1;
    /// Invalid bls public key
    const EINVALID_BLS_PUBLIC_KEY: u64 = 2;
    /// Invalid cg public key
    const EINVALID_CG_PUBLIC_KEY: u64 = 3;
    /// Invalid dkg config
    const EINVALID_DKG_CONFIG: u64 = 4;
    /// Missing node dkg config
    const EDKG_NODE_CONFIG_NOT_EXIST: u64 = 5;

    /// Configuration that controls if the dkg is enabled for validators
    struct DkgFeatureFlag has key {
        enable_dkg: bool,
    }

    /// This should be called by on-chain governance to enable/disable dkg for the validator nodes
    public(friend) fun update_dkg_feature_flag(supra_framework: &signer, enable: bool) acquires DkgFeatureFlag {
        system_addresses::assert_supra_framework(supra_framework);
        let enable_dkg_flag = &mut borrow_global_mut<DkgFeatureFlag>(@supra_framework).enable_dkg;
        *enable_dkg_flag = enable;
    }

    public(friend) fun dkg_feature_enabled(): bool acquires DkgFeatureFlag {
        let dkg_flag_exists = exists<DkgFeatureFlag>(@supra_framework);
        if (!dkg_flag_exists){
            return false
        };

        let enable_dkg_flag = borrow_global<DkgFeatureFlag>(@supra_framework).enable_dkg;
        enable_dkg_flag
    }

    struct DkgNodeConfig has key, copy, store, drop {
        addr: address,
        network_address: vector<u8>,
        // ed25519 public key for signing dealings
        ed_pubkey: vector<u8>,
        // bls public key used for aggregate signatures
        bls_pubkey: vector<u8>,
        // class group encryption key used to encrypt dealings
        cg_pubkey: vector<u8>,
    }

    struct DkgConfig has copy, key, drop, store {
        // The clan committee of nodes acting as dealers during dkg
        dealer_clan_committee: vector<DkgNodeConfig>,
        // The family committee of nodes assisting the clan committee during dkg
        family_committee: vector<DkgNodeConfig>,
        // The committee of nodes acting as receivers of the dealings during dkg
        target_committee: vector<DkgNodeConfig>,
    }

    #[test_only]
    public fun create_dkg_node_config_for_test(addr: address, network_address: vector<u8>, ed_pubkey: vector<u8>, bls_pubkey: vector<u8>, cg_pubkey: vector<u8>): DkgNodeConfig {
        DkgNodeConfig {
            addr,
            network_address,
            ed_pubkey,
            bls_pubkey,
            cg_pubkey,
        }
    }

    // function to store the dkg config
    public(friend) fun store_dkg_node_config(account: &signer,
                                             address: address,
                                             network_addresses: vector<u8>,
                                             ed_pubkey: vector<u8>,
                                             bls_pubkey: vector<u8>,
                                             pop_bls_pubkey: vector<u8>,
                                             cg_pubkey: vector<u8>) {
        // Checks the ed key is valid to prevent rogue-key attacks.
        let valid_ed_public_key = ed25519::new_validated_public_key_from_bytes(ed_pubkey);
        assert!(option::is_some(&valid_ed_public_key), error::invalid_argument(EINVALID_EDPUBLIC_KEY));

        // Checks the bls key is valid to prevent rogue-key attacks.
        let pop = bls12381::proof_of_possession_from_bytes(pop_bls_pubkey);
        let valid_bls_public_key = bls12381::public_key_from_bytes_with_pop(bls_pubkey, &pop);
        assert!(option::is_some(&valid_bls_public_key), error::invalid_argument(EINVALID_BLS_PUBLIC_KEY));

        // Validating CG public key requires class group arithmatics not supported in MOVE
        // we can add a native function for cg key verification
        // for now atleast check the key is not empty
        //todo: add cg_key verification
        assert!(!vector::is_empty(&cg_pubkey), error::invalid_argument(EINVALID_CG_PUBLIC_KEY));

        let dkg_config = DkgNodeConfig {
            addr: address,
            network_address: network_addresses,
            ed_pubkey,
            bls_pubkey,
            cg_pubkey,
        };

        move_to(account, dkg_config);
    }

    // Check if DkgNodeConfig exists for a node
    public(friend) fun dkg_node_config_exists(account_address: address): bool{
        exists<DkgNodeConfig>(account_address)
    }

    public(friend) fun get_dkg_node_config(account_address: address): DkgNodeConfig acquires DkgNodeConfig {
        assert!(dkg_node_config_exists(account_address), EDKG_NODE_CONFIG_NOT_EXIST);
        let dkg_node_config = borrow_global<DkgNodeConfig>(account_address);
        *dkg_node_config
    }

    public fun create_dkg_config(dealer_clan_committee: vector<DkgNodeConfig>,
                                 family_committee: vector<DkgNodeConfig>,
                                 target_committee: vector<DkgNodeConfig>,): DkgConfig {

        assert!(vector::length(&dealer_clan_committee) >= 3 &&
                vector::length(&family_committee) >= 1 &&
                vector::length(&target_committee) >= 4, EINVALID_DKG_CONFIG);

        DkgConfig {
            dealer_clan_committee,
            family_committee,
            target_committee
        }
    }

    public fun get_dealer_clan_committee(dkg_config: &DkgConfig): vector<DkgNodeConfig>{
        dkg_config.dealer_clan_committee
    }

    public(friend) fun is_node_family_committee_member(addr: address, dkg_config: &DkgConfig): bool {
        let family_committee = &dkg_config.family_committee;
        let len = vector::length(family_committee);
        let i = 0;
        while (i < len) {
            let family_node = vector::borrow(family_committee, i);
            if (family_node.addr == addr) {
                return true
            };
            i = i + 1;
        };
        false
    }

    public fun get_dkg_node_bls_pubkey(dkg_node_config: &DkgNodeConfig): vector<u8>{
        dkg_node_config.bls_pubkey
    }

}
