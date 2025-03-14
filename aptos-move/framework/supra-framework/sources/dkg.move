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
    #[test_only]
    use std::option::extract;
    #[test_only]
    use supra_framework::account::create_signer_for_test;
    #[test_only]
    use supra_framework::validator_consensus_info::new;
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
        dkg_state.in_progress = option::some(session);
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

    //----------------------------------------------------------------------------
    // Helper function to create a dummy ValidatorConsensusInfo.
    //----------------------------------------------------------------------------
    #[test_only]
    fun dummy_validator(addr: address, pk: vector<u8>, voting: u64): ValidatorConsensusInfo {
        new(addr, pk, voting)
    }

    #[test_only]
    fun test_setup(): (vector<u8>, vector<u8>, vector<u8>, vector<vector<u8>>){
        let committee_pk: vector<u8> = vector[182, 73, 201, 14, 230, 212, 121, 234, 4, 2, 125, 30, 61, 139, 81, 76, 241, 191, 75, 135, 143, 132, 162, 52, 121, 234, 164, 60, 119, 40, 189, 164, 194, 214, 90, 25, 73, 85, 94, 130, 208, 18, 199, 241, 167, 98, 239, 68];
        let accumulation: vector<u8> = vector[232, 119, 152, 228, 1, 19, 215, 62, 95, 203, 75, 118, 224, 181, 223, 233, 41, 47, 51, 61, 85, 215, 75, 107, 104, 79, 222, 151, 170, 97, 92, 207];
        let agg_signature: vector<u8> = vector[181, 161, 53, 232, 184, 30, 201, 51, 146, 146, 54, 240, 64, 227, 1, 247, 176, 252, 106, 194, 225, 145, 142, 52, 220, 79, 27, 148, 84, 137, 166, 112, 7, 118, 119, 67, 199, 31, 198, 251, 216, 37, 64, 72, 51, 235, 62, 178, 2, 6, 214, 51, 156, 158, 215, 63, 178, 97, 176, 148, 12, 47, 95, 201, 130, 98, 93, 112, 182, 62, 36, 4, 42, 85, 90, 82, 198, 222, 84, 90, 19, 223, 179, 47, 108, 229, 238, 59, 42, 240, 175, 153, 155, 185, 173, 69];

        let signer_vks = vector[];
        vector::push_back(&mut signer_vks, vector[147, 241, 20, 165, 199, 147, 154, 35, 21, 86, 138, 254, 208, 81, 28, 40, 164, 200, 57, 247, 61, 46, 40, 186, 98, 69, 139, 204, 0, 59, 27, 93, 146, 25, 226, 194, 50, 123, 219, 188, 67, 140, 160, 36, 231, 138, 250, 250]);
        vector::push_back(&mut signer_vks, vector[178, 205, 57, 192, 200, 251, 129, 159, 191, 92, 52, 131, 206, 229, 115, 188, 169, 164, 37, 221, 14, 196, 152, 27, 23, 46, 129, 27, 172, 105, 177, 242, 211, 220, 82, 104, 112, 124, 136, 166, 61, 16, 0, 35, 218, 29, 192, 153]);
        vector::push_back(&mut signer_vks, vector[161, 241, 195, 163, 120, 146, 20, 253, 54, 116, 156, 150, 25, 17, 95, 44, 38, 23, 53, 227, 113, 92, 19, 200, 201, 191, 124, 89, 247, 219, 33, 215, 146, 18, 26, 230, 112, 228, 236, 42, 238, 80, 149, 35, 13, 142, 136, 92]);
        vector::push_back(&mut signer_vks, vector[140, 4, 151, 88, 74, 215, 20, 193, 21, 212, 234, 80, 106, 30, 152, 62, 170, 176, 125, 81, 101, 139, 28, 189, 78, 216, 78, 161, 245, 95, 105, 117, 191, 136, 140, 117, 51, 167, 237, 200, 126, 179, 94, 206, 218, 205, 128, 71]);

        (committee_pk, accumulation, agg_signature, signer_vks)
    }

    //----------------------------------------------------------------------------
    // Test 1: start() correctly initializes a DKG session.
    //----------------------------------------------------------------------------
    #[test]
    fun test_start_session() acquires DKGState {
        let sf = @supra_framework; // framework signer address
        let sf_signer = create_signer_for_test(sf);
        // Initialize the global timestamp resource.
        timestamp::set_time_has_started_for_testing(&sf_signer);

        initialize(&sf_signer);
        // Create a dealer and a target validator.
        let dealer = dummy_validator(@0x1, vector[9, 9, 9], 100);
        let target = dummy_validator(@0x2, vector[10, 10, 10], 100);

        let dealer_set = vector::empty<ValidatorConsensusInfo>();
        vector::push_back(&mut dealer_set, dealer);
        let target_set = vector::empty<ValidatorConsensusInfo>();
        vector::push_back(&mut target_set, target);

        // Start a session with dealer_epoch = 10 and threshold = 1.
        start(10, 1, dealer_set, target_set);

        // Verify that an in-progress session exists and metadata is set.
        let session_opt = incomplete_session();
        assert!(is_some(&session_opt), 100);
        let session = extract(&mut session_opt);
        assert!(session_dealer_epoch(&session) == 10, 101);
    }

    //----------------------------------------------------------------------------
    // Test 2: Successful add_dkg_meta.
    //----------------------------------------------------------------------------
    #[test]
    fun test_add_dkg_meta_success() acquires DKGState {
        let sf = @supra_framework;
        let sf_signer = create_signer_for_test(sf);
        // Initialize the global timestamp resource.
        timestamp::set_time_has_started_for_testing(&sf_signer);
        initialize(&sf_signer);

        // Create dummy validator sets.
        let dealer = dummy_validator(@0x1, vector[9, 9, 9], 100);
        let target = dummy_validator(@0x2, vector[10, 10, 10], 100);
        let dealer_set = vector::empty<ValidatorConsensusInfo>();
        vector::push_back(&mut dealer_set, dealer);
        let target_set = vector::empty<ValidatorConsensusInfo>();
        vector::push_back(&mut target_set, target);

        let epoch = 10;
        let threshold = 4;
        start(epoch, threshold, dealer_set, target_set);

        let (committee_pk, accumulation, agg_signature, signer_vks) = test_setup();

        let session_opt = incomplete_session();
        assert!(is_some(&session_opt), 100);

        // Call add_dkg_meta with valid inputs.
        add_dkg_meta(
            committee_pk,
            accumulation,
            agg_signature,
            signer_vks
        );

        // Verify that the DKG meta transcript was set.
        let session_opt = incomplete_session();
        assert!(is_some(&session_opt), 100);

        let session = extract(&mut session_opt);
        assert!(session_dealer_epoch(&session) == 10, 101);

        assert!(is_some(&session.dkg_meta_transcript), 102);

        let dkg_meta = extract(&mut session.dkg_meta_transcript);

        assert!(dkg_meta.committee_pk == committee_pk, 103);
        assert!(dkg_meta.accumulation_value == accumulation, 104);

    }
}
