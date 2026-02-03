// Copyright (c) 2024 Supra.
module std::dkg_committee {

    use std::bcs;
    use std::vector;
    use supra_framework::validator_consensus_info;
    use supra_framework::validator_consensus_info::ValidatorConsensusInfo;
    use supra_framework::validator_public_keys::CertificateThresholdType;

    const EINVALID_DKG_COMMITTEE_SIZE: u64 = 1;

    struct DkgNodeConfig has copy, drop, store {
        addr: address,
        identity: vector<u8>,
        dkg_pubkey: vector<u8>,
    }

    struct DkgCommittee has copy, drop, store {
        committee: vector<DkgNodeConfig>,
        threshold_type: CertificateThresholdType,
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

    public fun new_dkg_committee(committee: vector<DkgNodeConfig>, threshold_type: CertificateThresholdType): DkgCommittee{

        assert!(vector::length(&committee) > 0, EINVALID_DKG_COMMITTEE_SIZE);
        DkgCommittee{
            committee,
            threshold_type
        }
    }

    public fun new_dkg_committee_from_validator_consensus_info(validator_committee: vector<ValidatorConsensusInfo>, threshold_type: CertificateThresholdType): DkgCommittee{

        assert!(vector::length(&validator_committee) > 0, EINVALID_DKG_COMMITTEE_SIZE);

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
            committee: dkg_committee,
            threshold_type
        }
    }

    public fun new_receiver_committee(is_resharing: bool, committee: DkgCommittee): ReceiverCommittee{
        ReceiverCommittee{
            is_resharing,
            committee
        }
    }

    /// Input for DKG key output - contains threshold type and keys for one committee
    struct DkgCommitteeOutput has copy, drop {
        /// The threshold type (0=validity, 1=quorum, 2=unanimous, etc.)
        threshold_type: u8,
        /// Public key shares for each validator (indexed by validator position)
        keys: vector<vector<u8>>,
    }

    /// Create a new DkgCommitteeOutput
    public fun new_dkg_committee_output(threshold_type: u8, keys: vector<vector<u8>>): DkgCommitteeOutput {
        DkgCommitteeOutput { threshold_type, keys }
    }

    /// Get threshold type from DkgCommitteeOutput
    public fun get_dkg_committee_output_threshold_type(output: &DkgCommitteeOutput): u8 {
        output.threshold_type
    }

    /// Get keys from DkgCommitteeOutput
    public fun get_dkg_committee_output_keys(output: &DkgCommitteeOutput): vector<vector<u8>> {
        output.keys
    }
}
