/// DKG on-chain states and helper functions.
module supra_framework::dkg {
    use std::bcs;
    use std::dkg_committee::{DkgCommittee};
    use std::error;
    use std::option;
    use std::option::{Option};
    use std::vector;
    use aptos_std::any;
    use aptos_std::type_info;
    use supra_framework::event::emit;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;
    #[test_only]
    use std::dkg_committee;
    #[test_only]
    use std::dkg_committee::{new_dkg_committee, tribe_committee_type};
    #[test_only]
    use std::option::{extract, is_some};
    #[test_only]
    use supra_framework::account::create_signer_for_test;
    friend supra_framework::block;
    friend supra_framework::reconfiguration_with_dkg;

    const EDKG_NOT_IN_PROGRESS: u64 = 1;
    const EDKG_META_ALREADY_SET: u64 = 2;
    const EDKG_META_NOT_SET: u64 = 3;
    const EDKG_INVALID_PK_SHARES: u64 = 4;

    #[event]
    struct DKGStartEvent has drop, store {
        session_metadata: DKGSessionMetadata,
        start_time_us: u64,
    }

    #[event]
    struct DKGMetaSetEvent has drop, store {
        dkg_meta_transcript: vector<u8>,
    }

    #[event]
    struct DKGFinishEvent has drop, store {
        target_committees_public_key_shares: vector<u8>
    }

    /// This can be considered as the public input of DKG.
    struct DKGSessionMetadata has copy, drop, store {
        dealer_epoch: u64,
        randomness_seed: vector<u8>,
        dealer_committee: DkgCommittee,
        target_committees: vector<DkgCommittee>,
    }
    
    /// The input and output of a DKG session.
    /// The validator set of epoch `x` works together for an DKG output for the target validator set of epoch `x+1`.
    struct DKGSessionState has copy, store, drop {
        metadata: DKGSessionMetadata,
        start_time_us: u64,
        dkg_meta_transcript: vector<u8>,
        target_committees_public_key_shares: vector<u8>
    }

    /// The completed and in-progress DKG sessions.
    struct DKGState has key {
        last_completed: Option<DKGSessionState>,
        in_progress: Option<DKGSessionState>,
    }

    /// Flag indicating if the next DKG run should be a fresh instance or a resharing instance
    struct DKGResharing has key {
        is_resharing: bool,
    }

    struct OnChainAggregateCommitment has copy, drop{
        bls12381_commitment_g: vector<u8>,
        bls12381_commitment_evals: vector<vector<u8>>,
        dealer_ids: vector<u32>,
        committee_index: u32,
    }

    struct OnChainAggregateCommitmentAllCommittees has copy, drop{
        commitments: vector<OnChainAggregateCommitment>,
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
        };

        //todo: add a function to set this flag
        if (!exists<DKGResharing>(@supra_framework)) {
            move_to<DKGResharing>(
                supra_framework,
                DKGResharing {
                    is_resharing: false,
                }
            );
        }
    }

    /// Mark on-chain DKG state as in-progress. Notify validators to start DKG.
    /// Abort if a DKG is already in progress.
    public(friend) fun start(
        dealer_epoch: u64,
        randomness_seed: vector<u8>,
        dealer_committee: DkgCommittee,
        target_committees: vector<DkgCommittee>
    ) acquires DKGState {
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        let new_session_metadata = DKGSessionMetadata {
            dealer_epoch,
            randomness_seed,
            dealer_committee,
            target_committees,
        };
        let start_time_us = timestamp::now_microseconds();
        dkg_state.in_progress = std::option::some(DKGSessionState {
            metadata: new_session_metadata,
            start_time_us,
            dkg_meta_transcript: vector[],
            target_committees_public_key_shares: vector[],
        });

        emit(DKGStartEvent {
            start_time_us,
            session_metadata: new_session_metadata,
        });
    }

    /// Family Node sets the DKGMeta for the in-progress DKG session
    /// The dkg transcript is assumed to have been already verified by the aptos VM in `process_dkg_result` method
    public(friend) fun set_dkg_meta(dkg_meta_all_committees: vector<u8>)
    acquires DKGState {
        // ensure dkg is in progress
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        assert!(option::is_some(&dkg_state.in_progress), error::invalid_state(EDKG_NOT_IN_PROGRESS));

        // we only add the first DKG Meta proposed and ignore the rest
        let session = option::extract(&mut dkg_state.in_progress);
        assert!(vector::length(&session.dkg_meta_transcript) == 0, error::already_exists(EDKG_META_ALREADY_SET));
        session.dkg_meta_transcript = dkg_meta_all_committees;
        dkg_state.in_progress = option::some(session);

        emit(DKGMetaSetEvent {
            dkg_meta_transcript: dkg_meta_all_committees,
        });
    }

    /// Family Node sets the `target_committees_public_key_shares` for the in-progress DKG session and
    /// marks the incomplete DKG session completed.
    ///The `target_committees_public_key_shares` is assumed to be verified by the aptos VM before calling this function
    public fun finish(target_committees_public_key_shares: vector<u8>)
    acquires DKGState {
        // ensure dkg is in progress
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        assert!(option::is_some(&dkg_state.in_progress), error::invalid_state(EDKG_NOT_IN_PROGRESS));

        // DKG meta should be already set before `finish` is called
        let session = option::extract(&mut dkg_state.in_progress);
        assert!(vector::length(&session.dkg_meta_transcript) > 0, error::already_exists(EDKG_META_NOT_SET));

        session.target_committees_public_key_shares = target_committees_public_key_shares;
        dkg_state.last_completed = option::some(session);
        dkg_state.in_progress = option::none();

        //todo: propagate updated keys to stake.move
        let public_key_shares_all_comms_serialized 
            = any::new(type_info::type_name<OnChainAggregateCommitmentAllCommittees>(), target_committees_public_key_shares);
        let public_key_shares_all_comms = any::unpack<OnChainAggregateCommitmentAllCommittees>(public_key_shares_all_comms_serialized);
        assert!(vector::length(&public_key_shares_all_comms.commitments) > 0, error::invalid_state(EDKG_INVALID_PK_SHARES));
        
        emit(DKGFinishEvent {
            target_committees_public_key_shares,
        });
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
    public fun session_dealer_epoch(session: &DKGSessionState): u64 {
        session.metadata.dealer_epoch
    }

    #[test_only]
    fun test_setup(): (u64, vector<u8>, DkgCommittee, vector<DkgCommittee>, vector<u8>){

        let epoch: u64 = 10;
        let randomness_seed = vector[1,2,3];
        // clan indices: [0, 2, 4, 5, 6]
        // family_indices: [2, 4, 6]
        let committee = vector[];
        
        let pk_bytes_0 = vector[1,2,3];
        let identity_0 = vector[0];
        let pk_bytes_1 = vector[1,2,3];
        let identity_1 = vector[1];
        let pk_bytes_2 = vector[1,2,3];
        let identity_2 = vector[2];
        let pk_bytes_3 = vector[1,2,3];
        let identity_3 = vector[3];
        let pk_bytes_4 = vector[1,2,3];
        let identity_4 = vector[4];
        let pk_bytes_5 = vector[1,2,3];
        let identity_5 = vector[5];
        let pk_bytes_6 = vector[1,2,3];
        let identity_6 = vector[6];
        let identities_committee = vector[identity_0, identity_1, identity_2, identity_3, identity_4, identity_5, identity_6];
        let pk_committee = vector[pk_bytes_0, pk_bytes_1, pk_bytes_2, pk_bytes_3, pk_bytes_4, pk_bytes_5, pk_bytes_6];

        for (i in 0..vector::length(&pk_committee)){
            let identity_bytes = *vector::borrow(&identities_committee, i);
            let pk_bytes = *vector::borrow(&pk_committee, i);
            vector::push_back(&mut committee,dkg_committee::new_dkg_node_config(@0x1, identity_bytes, pk_bytes));
        };

        let dkg_meta_all_committees = vector[1,2,3,4,5];
        let tribe_committee = new_dkg_committee(tribe_committee_type(), committee);
        (epoch, randomness_seed, tribe_committee, vector[tribe_committee], dkg_meta_all_committees)
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

        let (epoch, randomness_seed, dealer_committee, target_committees, dkg_meta) = test_setup();
        start(epoch, randomness_seed, dealer_committee, target_committees);

        let session_opt = incomplete_session();
        assert!(is_some(&session_opt), 100);
        set_dkg_meta(dkg_meta);
        let dummy_pk_shares = vector[1,2,3];
        finish(dummy_pk_shares);

        // Verify that the DKG meta transcript was set correctly.
        let session_opt = last_completed_session();
        
        assert!(is_some(&session_opt), 100);
        let session = extract(&mut session_opt);
        assert!(session_dealer_epoch(&session) == 10, 101);
        let dkg_meta_stored = session.dkg_meta_transcript;
        assert!(dkg_meta_stored == dkg_meta, 102);
        let pk_shares_stored = session.target_committees_public_key_shares;
        assert!(pk_shares_stored == dummy_pk_shares, 103);
    }
}
