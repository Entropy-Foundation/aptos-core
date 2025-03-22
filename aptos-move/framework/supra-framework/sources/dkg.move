/// DKG on-chain states and helper functions.
module supra_framework::dkg {
    use std::error;
    use std::option;
    use std::option::{Option, is_some};
    use std::signer;
    use std::vector;
    use aptos_std::bls12381::{PublicKeyWithPoP, public_key_from_bytes_with_pop_externally_verified,
        aggr_or_multi_signature_from_bytes, aggregate_pubkeys, verify_multisignature
    };
    use supra_framework::dkg_config::{DkgNodeConfig, DkgConfig, get_dealer_clan_committee, get_dkg_node_bls_pubkey,
        is_node_family_committee_member
    };
    use supra_framework::event::emit;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;
    #[test_only]
    use std::option::extract;
    #[test_only]
    use supra_framework::account::create_signer_for_test;
    #[test_only]
    use supra_framework::dkg_config::{create_dkg_config, create_dkg_node_config_for_test};
    friend supra_framework::block;
    friend supra_framework::reconfiguration_with_dkg;

    const EDKG_IN_PROGRESS: u64 = 1;
    const EDKG_NOT_IN_PROGRESS: u64 = 2;
    const EDKG_META_ALREADY_SET: u64 = 3;
    const EDKG_NOT_THRESHOLD_SIGNERS: u64 = 4;
    const EDKG_INVALID_SIGNER_VERIFICATION_KEY: u64 = 5;
    const EDKG_META_SIGNATURE_VERIFICATION_FAILED: u64 = 6;
    const EDKG_NOT_FAMILY_NODE: u64 = 7;

    /// This can be considered as the public input of DKG.
    struct DKGSessionMetadata has copy, drop, store {
        dealer_epoch: u32,
        dkg_config: DkgConfig,
    }

    /// DKG Meta information posted by a family node during the dkg process
    struct DKGMeta has store, copy, drop{
        committee_pk: vector<u8>,
        accumulation_value: vector<u8>
    }

    /// Contains DKG Meta and bls multi-signature of the clan nodes that voted for this DKG Meta
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

    /// The threshold required to ensure the presence of honest majority in clan where
    /// N = 2f+1 with f byzantine nodes
    fun clan_threshold(total: u64): u64 {
        total / 2 + 1
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

    fun get_signer_bls_keys_from_index(committee: &vector<DkgNodeConfig>, signers: vector<u32>): vector<PublicKeyWithPoP>{

        let signer_keys = vector[];
        vector::for_each(signers, |signer| {
            let node = vector::borrow(committee, (signer as u64));
            let node_bls_key_bytes = get_dkg_node_bls_pubkey(node);
            // create signer vks assuming the corresponding pops have already been verified upon registration
            let signer_key_option = public_key_from_bytes_with_pop_externally_verified(node_bls_key_bytes);
            assert!(is_some(&signer_key_option),error::invalid_argument(EDKG_INVALID_SIGNER_VERIFICATION_KEY));
            let signer_key = std::option::extract(&mut signer_key_option);
            vector::push_back(&mut signer_keys, signer_key);
        });

        signer_keys
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
        dealer_epoch: u64,
        dkg_config: DkgConfig,
    ) acquires DKGState {
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        let new_session_metadata = DKGSessionMetadata {
            dealer_epoch: (dealer_epoch as u32),
            dkg_config
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

    /// Family Node sets the DKGMeta for the in-progress DKG session and
    /// marks the incomplete DKG session completed.
    public entry fun finish(account: signer,
                            committee_pk_bytes: vector<u8>,
                            accumulation_value: vector<u8>,
                            agg_signature: vector<u8>,
                            signers: vector<u32>,
    ) acquires DKGState{

        // ensure dkg is in progress
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        assert!(option::is_some(&dkg_state.in_progress), error::invalid_state(EDKG_NOT_IN_PROGRESS));

        // we only add the first DKG Meta proposed and ignore the rest
        let session = option::extract(&mut dkg_state.in_progress);
        assert!(std::option::is_none(&session.dkg_meta_transcript), error::already_exists(EDKG_META_ALREADY_SET));

        // the dkg meta should only be added by a family node
        let account_address = signer::address_of(&account);
        assert!(is_node_family_committee_member(account_address, &session.metadata.dkg_config),
            EDKG_NOT_FAMILY_NODE
        );

        let dealer_clan_committee = get_dealer_clan_committee(&session.metadata.dkg_config);
        let clan_threshold = clan_threshold( vector::length(&dealer_clan_committee));

        assert!( vector::length(&signers) == clan_threshold,
            error::invalid_argument(EDKG_NOT_THRESHOLD_SIGNERS));

        // serialize the dkg meta similar to the rust implementation, to verify the multi signature
        let data_input =
            serialize_dkg_meta(session.metadata.dealer_epoch,
                committee_pk_bytes,
                accumulation_value);

        let signer_bls_pubkeys = get_signer_bls_keys_from_index(&dealer_clan_committee, signers);

        // verify the multi signature on the dkg meta is correct
        let agg_sig = aggr_or_multi_signature_from_bytes(agg_signature);
        let agg_pk = aggregate_pubkeys(signer_bls_pubkeys);
        assert!(verify_multisignature(&agg_sig, &agg_pk, data_input),
            error::invalid_argument(EDKG_META_SIGNATURE_VERIFICATION_FAILED));

        session.dkg_meta_transcript = option::some(
            DKGMeta{
                committee_pk: committee_pk_bytes,
                accumulation_value: accumulation_value
            });

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

    /// Return the last completed DKG session state, if it exists.
    public fun last_completed_session(): Option<DKGSessionState> acquires DKGState {
        if (exists<DKGState>(@supra_framework)) {
            borrow_global<DKGState>(@supra_framework).last_completed
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
    fun dummy_dkg_node(bls_pubkey: vector<u8>): DkgNodeConfig {
        create_dkg_node_config_for_test(@0x1, vector[1], vector[2], bls_pubkey, vector[3])
    }

    #[test_only]
    fun test_setup(): (u64, DkgConfig, vector<u8>, vector<u8>, vector<u8>, vector<u32>){

        let epoch: u64 = 10;
        let dealer_clan_committee = vector[];
        let family_committee = vector[];
        let target_committee = vector[];

        vector::push_back(&mut dealer_clan_committee, dummy_dkg_node(vector[147, 241, 20, 165, 199, 147, 154, 35, 21, 86, 138, 254, 208, 81, 28, 40, 164, 200, 57, 247, 61, 46, 40, 186, 98, 69, 139, 204, 0, 59, 27, 93, 146, 25, 226, 194, 50, 123, 219, 188, 67, 140, 160, 36, 231, 138, 250, 250]));
        vector::push_back(&mut dealer_clan_committee, dummy_dkg_node(vector[178, 205, 57, 192, 200, 251, 129, 159, 191, 92, 52, 131, 206, 229, 115, 188, 169, 164, 37, 221, 14, 196, 152, 27, 23, 46, 129, 27, 172, 105, 177, 242, 211, 220, 82, 104, 112, 124, 136, 166, 61, 16, 0, 35, 218, 29, 192, 153]));
        vector::push_back(&mut dealer_clan_committee, dummy_dkg_node(vector[161, 241, 195, 163, 120, 146, 20, 253, 54, 116, 156, 150, 25, 17, 95, 44, 38, 23, 53, 227, 113, 92, 19, 200, 201, 191, 124, 89, 247, 219, 33, 215, 146, 18, 26, 230, 112, 228, 236, 42, 238, 80, 149, 35, 13, 142, 136, 92]));
        vector::push_back(&mut dealer_clan_committee, dummy_dkg_node(vector[140, 4, 151, 88, 74, 215, 20, 193, 21, 212, 234, 80, 106, 30, 152, 62, 170, 176, 125, 81, 101, 139, 28, 189, 78, 216, 78, 161, 245, 95, 105, 117, 191, 136, 140, 117, 51, 167, 237, 200, 126, 179, 94, 206, 218, 205, 128, 71]));
        vector::push_back(&mut dealer_clan_committee, dummy_dkg_node(vector[0]));
        vector::push_back(&mut dealer_clan_committee, dummy_dkg_node(vector[0]));
        vector::push_back(&mut dealer_clan_committee, dummy_dkg_node(vector[0]));

        vector::push_back(&mut family_committee, dummy_dkg_node(vector[0]));

        vector::push_back(&mut target_committee, dummy_dkg_node(vector[0]));
        vector::push_back(&mut target_committee, dummy_dkg_node(vector[0]));
        vector::push_back(&mut target_committee, dummy_dkg_node(vector[0]));
        vector::push_back(&mut target_committee, dummy_dkg_node(vector[0]));

        let dkg_config = create_dkg_config(dealer_clan_committee, family_committee, target_committee);

        let committee_pk: vector<u8> = vector[182, 73, 201, 14, 230, 212, 121, 234, 4, 2, 125, 30, 61, 139, 81, 76, 241, 191, 75, 135, 143, 132, 162, 52, 121, 234, 164, 60, 119, 40, 189, 164, 194, 214, 90, 25, 73, 85, 94, 130, 208, 18, 199, 241, 167, 98, 239, 68];
        let accumulation: vector<u8> = vector[232, 119, 152, 228, 1, 19, 215, 62, 95, 203, 75, 118, 224, 181, 223, 233, 41, 47, 51, 61, 85, 215, 75, 107, 104, 79, 222, 151, 170, 97, 92, 207];
        let agg_signature: vector<u8> = vector[181, 161, 53, 232, 184, 30, 201, 51, 146, 146, 54, 240, 64, 227, 1, 247, 176, 252, 106, 194, 225, 145, 142, 52, 220, 79, 27, 148, 84, 137, 166, 112, 7, 118, 119, 67, 199, 31, 198, 251, 216, 37, 64, 72, 51, 235, 62, 178, 2, 6, 214, 51, 156, 158, 215, 63, 178, 97, 176, 148, 12, 47, 95, 201, 130, 98, 93, 112, 182, 62, 36, 4, 42, 85, 90, 82, 198, 222, 84, 90, 19, 223, 179, 47, 108, 229, 238, 59, 42, 240, 175, 153, 155, 185, 173, 69];
        let signers: vector<u32> = vector[0,1,2,3];

        (epoch, dkg_config, committee_pk, accumulation, agg_signature, signers)
    }

    //----------------------------------------------------------------------------
    // Test 1: Successful add_dkg_meta.
    //----------------------------------------------------------------------------
    #[test]
    fun test_add_dkg_meta_success() acquires DKGState {
        let sf = @supra_framework;
        let sf_signer = create_signer_for_test(sf);
        // Initialize the global timestamp resource.
        timestamp::set_time_has_started_for_testing(&sf_signer);
        initialize(&sf_signer);

        let (epoch, dkg_config, committee_pk, accumulation, agg_signature, signers) = test_setup();
        start(epoch, dkg_config);

        let session_opt = incomplete_session();
        assert!(is_some(&session_opt), 100);

        // Call finish with valid inputs.
        finish(
            sf_signer,
            committee_pk,
            accumulation,
            agg_signature,
            signers
        );

        // Verify that the DKG meta transcript was set.
        let session_opt = last_completed_session();
        assert!(is_some(&session_opt), 100);

        let session = extract(&mut session_opt);
        assert!(session_dealer_epoch(&session) == 10, 101);

        assert!(is_some(&session.dkg_meta_transcript), 102);

        let dkg_meta = extract(&mut session.dkg_meta_transcript);

        assert!(dkg_meta.committee_pk == committee_pk, 103);
        assert!(dkg_meta.accumulation_value == accumulation, 104);

    }
}
