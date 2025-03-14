/// DKG on-chain states and helper functions.
module supra_framework::dkg {
    use std::error;
    use std::option;
    use std::option::{Option, is_some};
    use std::vector;
    use aptos_std::bls12381::{PublicKeyWithPoP, public_key_from_bytes_with_pop_externally_verified,
        aggr_or_multi_signature_from_bytes, aggregate_pubkeys, verify_multisignature
    };
    use supra_framework::event::emit;
    use supra_framework::randomness_config::RandomnessConfig;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;
    use supra_framework::validator_consensus_info::ValidatorConsensusInfo;
    friend supra_framework::block;
    friend supra_framework::reconfiguration_with_dkg;

    const EDKG_IN_PROGRESS: u64 = 1;
    const EDKG_NOT_IN_PROGRESS: u64 = 2;
    const EDKG_DKG_META_ALREADY_SET: u64 = 3;
    const EDKG_NOT_THRESHOLD_SIGNERS: u64 = 4;
    const EDKG_INVALID_SIGNER_VERIFICATION_KEY: u64 = 5;
    const EDKG_DKG_META_SIGNATURE_VERIFICATION_FAILED: u64 = 6;

    /// This can be considered as the public input of DKG.
    //todo: add dkgcommittee (clan, family, tribe) info
    struct DKGSessionMetadata has copy, drop, store {
        dealer_epoch: u32,
        threshold: u32,
        dealer_validator_set: vector<ValidatorConsensusInfo>,
        target_validator_set: vector<ValidatorConsensusInfo>,
    }

    struct DKGMeta has store, copy, drop{
        committee_pk: vector<u8>,
        accumulation_value: vector<u8>
    }

    struct DKGMetaWithAggregateSignature has copy{
        dkg_meta: DKGMeta,
        signers: vector<u32>,
        signature: vector<u32>,
    }

    #[event]
    struct DKGStartEvent has drop, store {
        session_metadata: DKGSessionMetadata,
        start_time_us: u64,
    }

    /// The input and output of a DKG session.
    /// The validator set of epoch `x` works together for an DKG output for the target validator set of epoch `x+1`.
    struct DKGSessionState has copy, store, drop {
        metadata: DKGSessionMetadata,
        start_time_us: u64,
        dkg_meta_transcript: Option<DKGMeta>,
    }

    /// The completed and in-progress DKG sessions.
    struct DKGState has key {
        last_completed: Option<DKGSessionState>,
        in_progress: Option<DKGSessionState>,
    }

    fun u32_to_bytes_le(n: u32): vector<u8> {
        let bytes = vector::empty<u8>();
        let x = n;
        let i = 0;
        while (i < 4) {
            vector::push_back(&mut bytes, ((x & 0xFF) as u8));
            x = x >> 8;
            i = i + 1;
        };
        bytes
    }

    /// Serialize DKG Meta to be used as input for multi signature verification
    fun serialize_dkg_meta(dealer_epoch: u32,
                           committee_pk_bytes: vector<u8>,
                           accumulation_value: vector<u8>): vector<u8>{

        let data_input = vector[];
        let dealer_epoch_bytes = u32_to_bytes_le(dealer_epoch);
        vector::append(&mut data_input, dealer_epoch_bytes);
        vector::append(&mut data_input, u32_to_bytes_le((vector::length(&committee_pk_bytes) as u32)));
        vector::append(&mut data_input, committee_pk_bytes);
        vector::append(&mut data_input, u32_to_bytes_le((vector::length(&accumulation_value) as u32)));
        vector::append(&mut data_input, accumulation_value);
        data_input
    }

    /// Called in genesis to initialize on-chain states.
    public fun initialize(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        if (!exists<DKGState>(@supra_framework)) {
            move_to<DKGState>(
                supra_framework,
                DKGState {
                    last_completed: std::option::none(),
                    in_progress: std::option::none(),
                }
            );
        }
    }

    /// Mark on-chain DKG state as in-progress. Notify validators to start DKG.
    /// Abort if a DKG is already in progress.
    public(friend) fun start(
        dealer_epoch: u32,
        threshold: u32,
        dealer_validator_set: vector<ValidatorConsensusInfo>,
        target_validator_set: vector<ValidatorConsensusInfo>,
    ) acquires DKGState {
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        let new_session_metadata = DKGSessionMetadata {
            dealer_epoch,
            threshold,
            dealer_validator_set,
            target_validator_set,
        };
        let start_time_us = timestamp::now_microseconds();
        dkg_state.in_progress = std::option::some(DKGSessionState {
            metadata: new_session_metadata,
            start_time_us,
            dkg_meta_transcript: option::none()
        });

        emit(DKGStartEvent {
            start_time_us,
            session_metadata: new_session_metadata,
        });
    }

    public(friend) fun add_dkg_meta(committee_pk_bytes: vector<u8>,
                                    accumulation_value: vector<u8>,
                                    agg_signature: vector<u8>,
                                    signer_vk_bytes: vector<vector<u8>>,
    ) acquires DKGState{

        // ensure dkg is in progress
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        assert!(option::is_some(&dkg_state.in_progress), error::invalid_state(EDKG_NOT_IN_PROGRESS));

        // we only add the first DKG Meta proposed and ignore the rest
        let session = option::extract(&mut dkg_state.in_progress);
        assert!(std::option::is_none(&session.dkg_meta_transcript), error::already_exists(EDKG_DKG_META_ALREADY_SET));

        assert!( (vector::length(&signer_vk_bytes) as u32) == session.metadata.threshold,
            error::invalid_argument(EDKG_NOT_THRESHOLD_SIGNERS));

        // serialize the dkg meta similar to the rust implementation, to verify the multi signature
        let data_input =
            serialize_dkg_meta(session.metadata.dealer_epoch,
                committee_pk_bytes,
                accumulation_value);

        let signer_vks_with_pop: vector<PublicKeyWithPoP> = vector[];
        // create signer vks assuming the corresponding pops have already been verified upon registration
        for(i in 0..vector::length(&signer_vk_bytes)){
            let signer_vk_option = public_key_from_bytes_with_pop_externally_verified(*vector::borrow(&signer_vk_bytes, i));
            assert!(is_some(&signer_vk_option),error::invalid_argument(EDKG_INVALID_SIGNER_VERIFICATION_KEY));
            let signer_vk = std::option::extract(&mut signer_vk_option);
            vector::push_back(&mut signer_vks_with_pop, signer_vk);
        };

        // verify the multi signature on the dkg meta is correct
        let agg_sig = aggr_or_multi_signature_from_bytes(agg_signature);
        let agg_pk = aggregate_pubkeys(signer_vks_with_pop);
        assert!(verify_multisignature(&agg_sig, &agg_pk, data_input),
            error::invalid_argument(EDKG_DKG_META_SIGNATURE_VERIFICATION_FAILED));

        session.dkg_meta_transcript = option::some(
            DKGMeta{
                committee_pk: committee_pk_bytes,
                accumulation_value: accumulation_value
            });
    }

    /// Mark the incomplete DKG session completed.
    ///
    /// Abort if DKG is not in progress.
    public(friend) fun finish() acquires DKGState {
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        assert!(option::is_some(&dkg_state.in_progress), error::invalid_state(EDKG_NOT_IN_PROGRESS));
        let session = option::extract(&mut dkg_state.in_progress);
        dkg_state.last_completed = option::some(session);
        dkg_state.in_progress = option::none();
    }

    /// Delete the currently incomplete session, if it exists.
    public fun try_clear_incomplete_session(fx: &signer) acquires DKGState {
        system_addresses::assert_supra_framework(fx);
        if (exists<DKGState>(@supra_framework)) {
            let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
            dkg_state.in_progress = option::none();
        }
    }

    /// Return the incomplete DKG session state, if it exists.
    public fun incomplete_session(): Option<DKGSessionState> acquires DKGState {
        if (exists<DKGState>(@supra_framework)) {
            borrow_global<DKGState>(@supra_framework).in_progress
        } else {
            option::none()
        }
    }

    /// Return the dealer epoch of a `DKGSessionState`.
    public fun session_dealer_epoch(session: &DKGSessionState): u32 {
        session.metadata.dealer_epoch
    }
}
