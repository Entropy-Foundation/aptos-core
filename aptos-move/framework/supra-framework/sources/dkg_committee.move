// Copyright (c) 2024 Supra.
module std::dkg_committee {

    use std::bcs;
    use std::vector;
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

    struct DkgNodeConfig has copy, drop, store {
        addr: address,
        identity: vector<u8>,
        dkg_pubkey: vector<u8>,
    }

    struct DkgCommittee has copy, drop, store {
        type: DkgCommitteeType,
        committee: vector<DkgNodeConfig>,
    }

    struct ReceiverCommittee has copy, drop, store {
        is_resharing: bool,
        committee: DkgCommittee,
    }

    public fun new_dkg_node_config(addr: address, identity: vector<u8>, dkg_pubkey: vector<u8>,): DkgNodeConfig{
        DkgNodeConfig{
            addr,
            identity,
            dkg_pubkey
        }
    }

    public fun get_addr(dkg_node: &DkgNodeConfig): address{
        dkg_node.addr
    }

    public fun get_dkg_pubkey(dkg_node: &DkgNodeConfig): vector<u8>{
        dkg_node.dkg_pubkey
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

        // The order of the committee members is important for DKG.
        // The order should correspond to the order of the validator committee.
        // The output of the DKG has keys in the same order as the committee.
        let dkg_committee = vector[];
        vector::for_each(validator_committee, |x|
            {
                let validator_keys_bytes = validator_consensus_info::get_pk_bytes(&x);
                let addr = validator_consensus_info::get_addr(&x);
                vector::push_back(&mut dkg_committee, DkgNodeConfig{
                    addr,
                    identity: bcs::to_bytes(&addr),
                    dkg_pubkey: validator_keys_bytes,
                });
            }
        );

        DkgCommittee{
            type,
            committee: dkg_committee,
        }
    }

    public fun new_receiver_committee(is_resharing: bool, committee: DkgCommittee): ReceiverCommittee{
        ReceiverCommittee{
            is_resharing,
            committee
        }
    }
}
