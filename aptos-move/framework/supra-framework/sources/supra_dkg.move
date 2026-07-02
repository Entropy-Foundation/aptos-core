// Copyright (c) 2024 Supra.
/// DKG on-chain states and helper functions.
module supra_framework::supra_dkg {
    use std::dkg_committee::{
        DkgCommittee,
        ReceiverCommittee,
        new_dkg_committee_output,
        get_committee,
        get_addr,
        get_receiver_dkg_committee,
    };
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

    /// Called in genesis to initialize on-chain states when DKG is active from genesis,
    /// otherwise, must be called from a governance script before the DKG feature flag
    /// is activated.
    public fun initialize(supra_framework: &signer) {
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

        emit(DKGStartEvent { start_time_us, session_metadata: new_session_metadata });
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

    /// Return the set of validator addresses that received shares in the last
    /// completed DKG, computed as the *intersection* of member addresses across
    /// every receiver committee in that session.
    ///
    /// Intent: identify the validators that locally hold prior reshare data on
    /// disk. Used by `reconfiguration_with_dkg::try_start` to constrain the
    /// dealer set for resharing DKGs to only those validators.
    ///
    /// Why intersection: a resharing dealer must hold prior shares for every
    /// receiver committee that is being reshared in the new DKG. Today the
    /// framework constructs a *single* dealer committee per DKG that deals for
    /// all receiver committees, so the dealer set must satisfy every reshared
    /// committee's prior-data requirement simultaneously.
    ///
    /// Assumption: in current default configs, all receiver committees share
    /// the same membership, so the intersection equals any one of them. The
    /// explicit intersection guarantees correctness if configs ever diverge.
    /// If the framework is later extended to support multiple dealer committees
    /// per DKG (one per receiver), this helper must be revisited.
    ///
    /// Returns `None` when no DKG has completed yet. Callers should treat that
    /// case as an invariant violation when resharing is enabled, because
    /// `dkg_config::set_for_next_epoch` rejects `is_resharing=true` at proposal
    /// time when no completed session exists (`ERESHARING_WITHOUT_PRIOR_SESSION`).
    public fun last_completed_receivers_addresses(): option::Option<vector<address>>
        acquires DKGState
    {
        if (!exists<DKGState>(@supra_framework)) {
            return option::none()
        };
        let state = borrow_global<DKGState>(@supra_framework);
        if (option::is_none(&state.last_completed)) {
            return option::none()
        };
        let session = option::borrow(&state.last_completed);
        let target_committees = &session.metadata.target_committees;
        let n = vector::length(target_committees);
        if (n == 0) {
            return option::none()
        };

        // Seed the intersection with the first receiver committee's addresses,
        // then narrow it against each subsequent receiver committee.
        let result = receiver_committee_addresses(vector::borrow(target_committees, 0));
        let i = 1;
        while (i < n) {
            let next_addrs =
                receiver_committee_addresses(vector::borrow(target_committees, i));
            result = intersect_addresses(&result, &next_addrs);
            i = i + 1;
        };
        option::some(result)
    }

    /// Extract the ordered list of member addresses from a `ReceiverCommittee`.
    /// Order does not matter for the intersection caller; we just need the set.
    fun receiver_committee_addresses(rc: &ReceiverCommittee): vector<address> {
        let nodes = get_committee(get_receiver_dkg_committee(rc));
        let addrs = vector[];
        let i = 0;
        let n = vector::length(&nodes);
        while (i < n) {
            vector::push_back(&mut addrs, get_addr(vector::borrow(&nodes, i)));
            i = i + 1;
        };
        addrs
    }

    /// Compute the intersection of two address vectors. O(|a| * |b|); acceptable
    /// for validator-set-sized inputs (tens to low hundreds).
    fun intersect_addresses(a: &vector<address>, b: &vector<address>): vector<address> {
        let result = vector[];
        let i = 0;
        let n = vector::length(a);
        while (i < n) {
            let addr = *vector::borrow(a, i);
            if (vector::contains(b, &addr)) {
                vector::push_back(&mut result, addr);
            };
            i = i + 1;
        };
        result
    }

    #[view]
    /// Return the threshold public key (the polynomial constant term, evals[0])
    /// for each receiver committee from the last completed DKG session, paired
    /// with its threshold_type tag. Empty vector if no DKG has completed yet.
    /// Used by integration tests to verify that resharing preserves the
    /// threshold key across epochs.
    public fun last_completed_threshold_pubkeys(): vector<vector<u8>> acquires DKGState {
        if (!exists<DKGState>(@supra_framework)) {
            return vector[]
        };
        let state = borrow_global<DKGState>(@supra_framework);
        if (option::is_none(&state.last_completed)) {
            return vector[]
        };
        let session = option::borrow(&state.last_completed);
        if (vector::length(&session.target_committees_public_key_shares) == 0) {
            return vector[]
        };

        let serialized = any::new(
            type_info::type_name<OnChainAggregateCommitmentAllCommittees>(),
            session.target_committees_public_key_shares
        );
        let unpacked = any::unpack<OnChainAggregateCommitmentAllCommittees>(serialized);

        let pubkeys = vector[];
        let i = 0;
        let n = vector::length(&unpacked.commitments);
        while (i < n) {
            let c = vector::borrow(&unpacked.commitments, i);
            // Prefix the threshold_type tag so callers can correlate entries
            // across epochs even if committee order ever changes.
            let entry = vector[c.threshold_type];
            if (vector::length(&c.bls12381_commitment_evals) > 0) {
                vector::append(
                    &mut entry,
                    *vector::borrow(&c.bls12381_commitment_evals, 0)
                );
            };
            vector::push_back(&mut pubkeys, entry);
            i = i + 1;
        };
        pubkeys
    }

    // ========================
    // Test-only helpers
    // ========================

    #[test_only]
    use std::dkg_committee::{new_dkg_committee, new_dkg_node_config, new_receiver_committee};
    #[test_only]
    use supra_framework::validator_public_keys::CertificateThresholdType;

    /// Test-only: populate `DKGState.last_completed` with a minimal valid
    /// session so that callers depending on `last_completed_session().is_some()`
    /// (e.g., `dkg_config::set_for_next_epoch`'s `ERESHARING_WITHOUT_PRIOR_SESSION`
    /// guard) succeed in tests that don't run a real DKG.
    ///
    /// The session carries the supplied receiver-committee dkg_threshold_types
    /// so tests can construct a `last_completed` matching whatever resharing
    /// they want to enable next. Single-validator committees with placeholder
    /// keys are used; only structure (not key validity) matters here.
    #[test_only]
    public fun setup_fake_last_completed_session_for_test(
        framework: &signer,
        committee_threshold_type: CertificateThresholdType,
        dkg_threshold_types: vector<CertificateThresholdType>,
    ) acquires DKGState {
        system_addresses::assert_supra_framework(framework);
        initialize(framework);

        // Build a single-validator placeholder committee. The DKG state
        // machine cares about structure here, not key validity.
        let placeholder_addr = @0xA;
        let placeholder_pubkey = vector[0u8, 0u8, 0u8, 0u8];
        let nodes = vector[
            new_dkg_node_config(placeholder_addr, vector[0u8], placeholder_pubkey)
        ];

        // One receiver committee per requested dkg_threshold_type, all sharing
        // the same placeholder member set.
        let target_committees = vector[];
        let i = 0;
        let n = vector::length(&dkg_threshold_types);
        while (i < n) {
            let dkg_tt = *vector::borrow(&dkg_threshold_types, i);
            vector::push_back(
                &mut target_committees,
                new_receiver_committee(
                    false,
                    dkg_tt,
                    new_dkg_committee(nodes, committee_threshold_type)
                )
            );
            i = i + 1;
        };

        let metadata = DKGSessionMetadata {
            dealer_epoch: 0,
            randomness_seed: vector[],
            dealer_committee: new_dkg_committee(nodes, committee_threshold_type),
            target_committees,
        };
        let session = DKGSessionState {
            metadata,
            start_time_us: 0,
            dkg_meta_transcript: vector[0u8],
            target_committees_public_key_shares: vector[],
        };

        let state = borrow_global_mut<DKGState>(@supra_framework);
        state.last_completed = option::some(session);
    }
}
