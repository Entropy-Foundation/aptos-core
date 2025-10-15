module std::dkg_committee {

    use std::option;
    use std::vector;
    use aptos_std::bls12381::public_key_to_bytes;
    use aptos_std::ed25519::validated_public_key_to_bytes;
    use supra_std::consensus_key::{consensus_public_key_from_bytes, get_bls_pub_key, get_ed_key};
    use supra_framework::validator_consensus_info;
    use supra_framework::validator_consensus_info::ValidatorConsensusInfo;

    const EINVALID_DKG_COMMITTEE_SIZE: u64 = 1;
    const EINVALID_DKG_NODE_PUBLIC_KEY: u64 = 2;
    
    const TYPE_CLAN: u8 = 0;
    const TYPE_TRIBE: u8 = 1;

    /// Internal tag wrapper
    struct DkgCommitteeType has copy, drop, store { tag: u8 }

    public fun clan_committee_type(): DkgCommitteeType { DkgCommitteeType { tag: TYPE_CLAN } }
    public fun tribe_committee_type(): DkgCommitteeType { DkgCommitteeType { tag: TYPE_TRIBE } }

    public fun is_clan_committee_type(t: &DkgCommitteeType): bool { t.tag == TYPE_CLAN }
    public fun is_tribe_committee_type(t: &DkgCommitteeType): bool { t.tag == TYPE_TRIBE }

    //todo: should we store network addr here?
    struct DkgNodeConfig has copy, drop, store {
        addr: address,
        identity: vector<u8>,
        // bls public key used for aggregate signatures
        bls_pubkey: vector<u8>,
    }
    
    public fun new_dkg_node_config(addr: address, identity: vector<u8>, bls_pubkey: vector<u8>,): DkgNodeConfig{
        DkgNodeConfig{
            addr,
            identity,
            bls_pubkey
        }
    }

    public fun get_addr(dkg_node: &DkgNodeConfig): address{
        dkg_node.addr
    }

    public fun get_bls_pubkey(dkg_node: &DkgNodeConfig): vector<u8>{
        dkg_node.bls_pubkey
    }
    
    struct DkgCommittee has copy, drop, store {
        type: DkgCommitteeType,
        committee: vector<DkgNodeConfig>,
    }
    
    public fun len(committee: &DkgCommittee): u64{
        vector::length(&committee.committee)
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

    public fun new_dkg_committee_from_validator_consensus_info(type: DkgCommitteeType, validator_committee: vector<ValidatorConsensusInfo>): DkgCommittee{

        if(is_clan_committee_type(&type)){
            assert!(vector::length(&validator_committee) > 2, EINVALID_DKG_COMMITTEE_SIZE);
        };
        if(is_tribe_committee_type(&type)){
            assert!(vector::length(&validator_committee) > 3, EINVALID_DKG_COMMITTEE_SIZE);
        };

        let dkg_committee = vector[];
        vector::for_each(validator_committee, |x|
            {
                let consensus_pk_option = consensus_public_key_from_bytes(validator_consensus_info::get_pk_bytes(&x));
                assert!(option::is_some(&consensus_pk_option), EINVALID_DKG_NODE_PUBLIC_KEY);
                let consensus_key = option::extract(&mut consensus_pk_option);
                let bls_key_option = get_bls_pub_key(&consensus_key);
                assert!(option::is_some(&bls_key_option), EINVALID_DKG_NODE_PUBLIC_KEY);
                let bls_key = option::extract(&mut bls_key_option);
                let bls_key_bytes = public_key_to_bytes(&bls_key);

                let ed_key = get_ed_key(&consensus_key);
                let ed_key_bytes = validated_public_key_to_bytes(&ed_key);
                
                vector::push_back(&mut dkg_committee, DkgNodeConfig{
                    addr: validator_consensus_info::get_addr(&x),
                    identity: ed_key_bytes,
                    bls_pubkey: bls_key_bytes,
                });
            }
        );

        DkgCommittee{
            type,
            committee: dkg_committee
        }
    }
}
