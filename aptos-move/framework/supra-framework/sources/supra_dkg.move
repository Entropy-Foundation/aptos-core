// Copyright (c) 2024 Supra.
/// DKG on-chain states and helper functions.
module supra_framework::supra_dkg {
    use std::dkg_committee::{DkgCommittee, ReceiverCommittee, new_dkg_committee_output};
    use std::error;
    use std::option;
    use std::option::{Option};
    use std::vector;
    use aptos_std::any;
    use aptos_std::type_info;
    use supra_framework::event::emit;
    use supra_framework::system_addresses;
    use supra_framework::timestamp;
    use supra_framework::stake;

    friend supra_framework::block;
    friend supra_framework::reconfiguration_with_dkg;

    const EDKG_NOT_IN_PROGRESS: u64 = 1;
    const EDKG_META_ALREADY_SET: u64 = 2;
    const EDKG_META_NOT_SET: u64 = 3;
    const EDKG_INVALID_PK_SHARES: u64 = 4;

    #[event]
    struct DKGStartEvent has drop, store {
        session_metadata: DKGSessionMetadata,
        start_time_us: u64
    }

    #[event]
    struct DKGMetaSetEvent has drop, store {
        dkg_meta_transcript: vector<u8>
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
        target_committees: vector<ReceiverCommittee>
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
        in_progress: Option<DKGSessionState>
    }

    struct OnChainAggregateCommitment has copy, drop {
        bls12381_commitment_g: vector<u8>,
        bls12381_commitment_evals: vector<vector<u8>>,
        dealer_ids: vector<u32>,
        committee_index: u32,
        epoch: u64,
        chain_id: u8,
        threshold_type: u8
    }

    struct OnChainAggregateCommitmentAllCommittees has copy, drop {
        commitments: vector<OnChainAggregateCommitment>
    }

    /// Called in genesis to initialize on-chain states.
    public(friend) fun initialize(supra_framework: &signer) {
        system_addresses::assert_supra_framework(supra_framework);
        if (!exists<DKGState>(@supra_framework)) {
            move_to<DKGState>(
                supra_framework,
                DKGState {
                    last_completed: std::option::none(),
                    in_progress: std::option::none()
                }
            );
        };
    }

    /// Mark on-chain DKG state as in-progress. Notify validators to start DKG.
    /// Abort if a DKG is already in progress.
    public(friend) fun start(
        dealer_epoch: u64,
        randomness_seed: vector<u8>,
        dealer_committee: DkgCommittee,
        target_committees: vector<ReceiverCommittee>
    ) acquires DKGState {
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        let new_session_metadata = DKGSessionMetadata {
            dealer_epoch,
            randomness_seed,
            dealer_committee,
            target_committees
        };
        let start_time_us = timestamp::now_microseconds();
        dkg_state.in_progress = std::option::some(
            DKGSessionState {
                metadata: new_session_metadata,
                start_time_us,
                dkg_meta_transcript: vector[],
                target_committees_public_key_shares: vector[]
            }
        );

        emit(
            DKGStartEvent { start_time_us, session_metadata: new_session_metadata }
        );
    }

    /// Family Node sets the DKGMeta for the in-progress DKG session
    /// The dkg transcript is assumed to have been already verified by the aptos VM in `process_dkg_result` method
    public(friend) fun set_dkg_meta(dkg_meta_all_committees: vector<u8>) acquires DKGState {
        // ensure dkg is in progress
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        assert!(
            option::is_some(&dkg_state.in_progress),
            error::invalid_state(EDKG_NOT_IN_PROGRESS)
        );

        // we only add the first DKG Meta proposed and ignore the rest
        let session = option::extract(&mut dkg_state.in_progress);
        assert!(
            vector::length(&session.dkg_meta_transcript) == 0,
            error::already_exists(EDKG_META_ALREADY_SET)
        );
        session.dkg_meta_transcript = dkg_meta_all_committees;
        dkg_state.in_progress = option::some(session);

        emit(DKGMetaSetEvent { dkg_meta_transcript: dkg_meta_all_committees });
    }

    /// Family Node sets the `target_committees_public_key_shares` for the in-progress DKG session and
    /// marks the incomplete DKG session completed.
    ///The `target_committees_public_key_shares` is assumed to be verified by the aptos VM before calling this function
    public(friend) fun finish(
        target_committees_public_key_shares: vector<u8>
    ) acquires DKGState {
        // ensure dkg is in progress
        let dkg_state = borrow_global_mut<DKGState>(@supra_framework);
        assert!(
            option::is_some(&dkg_state.in_progress),
            error::invalid_state(EDKG_NOT_IN_PROGRESS)
        );

        // DKG meta should be already set before `finish` is called
        let session = option::extract(&mut dkg_state.in_progress);
        assert!(
            vector::length(&session.dkg_meta_transcript) > 0,
            error::already_exists(EDKG_META_NOT_SET)
        );

        session.target_committees_public_key_shares = target_committees_public_key_shares;
        dkg_state.last_completed = option::some(session);
        dkg_state.in_progress = option::none();

        // propagate updated keys to stake.move for all threshold types
        let public_key_shares_all_comms_serialized =
            any::new(
                type_info::type_name<OnChainAggregateCommitmentAllCommittees>(),
                target_committees_public_key_shares
            );
        let public_key_shares_all_comms =
            any::unpack<OnChainAggregateCommitmentAllCommittees>(
                public_key_shares_all_comms_serialized
            );

        // Build a vector of DkgCommitteeOutput for all committees
        let committee_outputs = vector[];
        let i = 0;
        let len = vector::length(&public_key_shares_all_comms.commitments);
        while (i < len) {
            let commitment = vector::borrow(&public_key_shares_all_comms.commitments, i);
            // As the first index contains the committee's threshold public key, we can skip that
            let evals = vector::slice(
                &commitment.bls12381_commitment_evals,
                1,
                vector::length(&commitment.bls12381_commitment_evals)
            );

            vector::push_back(
                &mut committee_outputs,
                new_dkg_committee_output(commitment.threshold_type, evals)
            );
            i = i + 1;
        };

        // Set all keys for all threshold types
        stake::set_dkg_output_keys(committee_outputs);
        emit(DKGFinishEvent { target_committees_public_key_shares });
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
}
