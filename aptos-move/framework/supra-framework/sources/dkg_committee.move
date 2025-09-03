module std::dkg_committee {

    use std::vector;

    const EINVALID_DKG_COMMITTEE_SIZE: u64 = 1;
    
    const TYPE_CLAN: u8 = 0;
    const TYPE_TRIBE: u8 = 1;

    /// Internal tag wrapper
    struct DkgCommitteeType has copy, drop { tag: u8 }

    public fun clan_committee_type(): DkgCommitteeType { DkgCommitteeType { tag: TYPE_CLAN } }
    public fun tribe_committee_type(): DkgCommitteeType { DkgCommitteeType { tag: TYPE_TRIBE } }

    public fun is_clan_committee_type(t: &DkgCommitteeType): bool { t.tag == TYPE_CLAN }
    public fun is_tribe_committee_type(t: &DkgCommitteeType): bool { t.tag == TYPE_TRIBE }

    //todo: should we store network addr here?
    struct DkgNodeConfig has copy, drop {
        addr: address,
        // bls public key used for aggregate signatures
        bls_pubkey: vector<u8>,
    }
    
    public fun new_dkg_node_config(addr: address, bls_pubkey: vector<u8>,): DkgNodeConfig{
        DkgNodeConfig{
            addr,
            bls_pubkey
        }
    }

    public fun get_addr(dkg_node: &DkgNodeConfig): address{
        dkg_node.addr
    }

    public fun get_bls_pubkey(dkg_node: &DkgNodeConfig): vector<u8>{
        dkg_node.bls_pubkey
    }
    
    struct DkgCommittee has copy, drop {
        type: DkgCommitteeType,
        committee: vector<DkgNodeConfig>,
    }
    
    public fun get_committee(dkg_committee: &DkgCommittee): vector<DkgNodeConfig>{
        dkg_committee.committee
    }
    
    public fun new_dkg_committee(type: DkgCommitteeType, committee: vector<DkgNodeConfig>): DkgCommittee{
        
        if(is_clan_committee_type(&type)){
            assert!(vector::length(&committee) > 2, EINVALID_DKG_COMMITTEE_SIZE);
        };
        if(is_tribe_committee_type(&type)){
            assert!(vector::length(&committee) > 3, EINVALID_DKG_COMMITTEE_SIZE);
        };
        
        DkgCommittee{
            type,
            committee
        }
    }
}
