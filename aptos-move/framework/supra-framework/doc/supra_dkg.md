
<a id="0x1_supra_dkg"></a>

# Module `0x1::supra_dkg`

DKG on-chain states and helper functions.


-  [Struct `DKGStartEvent`](#0x1_supra_dkg_DKGStartEvent)
-  [Struct `DKGMetaSetEvent`](#0x1_supra_dkg_DKGMetaSetEvent)
-  [Struct `DKGFinishEvent`](#0x1_supra_dkg_DKGFinishEvent)
-  [Struct `DKGSessionMetadata`](#0x1_supra_dkg_DKGSessionMetadata)
-  [Struct `DKGSessionState`](#0x1_supra_dkg_DKGSessionState)
-  [Resource `DKGState`](#0x1_supra_dkg_DKGState)
-  [Struct `OnChainAggregateCommitment`](#0x1_supra_dkg_OnChainAggregateCommitment)
-  [Struct `OnChainAggregateCommitmentAllCommittees`](#0x1_supra_dkg_OnChainAggregateCommitmentAllCommittees)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_supra_dkg_initialize)
-  [Function `start`](#0x1_supra_dkg_start)
-  [Function `set_dkg_meta`](#0x1_supra_dkg_set_dkg_meta)
-  [Function `finish`](#0x1_supra_dkg_finish)
-  [Function `try_clear_incomplete_session`](#0x1_supra_dkg_try_clear_incomplete_session)
-  [Function `incomplete_session`](#0x1_supra_dkg_incomplete_session)
-  [Function `last_completed_session`](#0x1_supra_dkg_last_completed_session)
-  [Function `session_dealer_epoch`](#0x1_supra_dkg_session_dealer_epoch)
-  [Specification](#@Specification_1)
    -  [Function `initialize`](#@Specification_1_initialize)
    -  [Function `start`](#@Specification_1_start)
    -  [Function `set_dkg_meta`](#@Specification_1_set_dkg_meta)
    -  [Function `finish`](#@Specification_1_finish)
    -  [Function `try_clear_incomplete_session`](#@Specification_1_try_clear_incomplete_session)
    -  [Function `incomplete_session`](#@Specification_1_incomplete_session)


<pre><code><b>use</b> <a href="../../aptos-stdlib/doc/any.md#0x1_any">0x1::any</a>;
<b>use</b> <a href="dkg_committee.md#0x1_dkg_committee">0x1::dkg_committee</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="stake.md#0x1_stake">0x1::stake</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/type_info.md#0x1_type_info">0x1::type_info</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_supra_dkg_DKGStartEvent"></a>

## Struct `DKGStartEvent`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGStartEvent">DKGStartEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>session_metadata: <a href="supra_dkg.md#0x1_supra_dkg_DKGSessionMetadata">supra_dkg::DKGSessionMetadata</a></code>
</dt>
<dd>

</dd>
<dt>
<code>start_time_us: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_supra_dkg_DKGMetaSetEvent"></a>

## Struct `DKGMetaSetEvent`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGMetaSetEvent">DKGMetaSetEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dkg_meta_transcript: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_supra_dkg_DKGFinishEvent"></a>

## Struct `DKGFinishEvent`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGFinishEvent">DKGFinishEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>target_committees_public_key_shares: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_supra_dkg_DKGSessionMetadata"></a>

## Struct `DKGSessionMetadata`

This can be considered as the public input of DKG.


<pre><code><b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGSessionMetadata">DKGSessionMetadata</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dealer_epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>randomness_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>dealer_committee: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a></code>
</dt>
<dd>

</dd>
<dt>
<code>target_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_ReceiverCommittee">dkg_committee::ReceiverCommittee</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_supra_dkg_DKGSessionState"></a>

## Struct `DKGSessionState`

The input and output of a DKG session.
The validator set of epoch <code>x</code> works together for an DKG output for the target validator set of epoch <code>x+1</code>.


<pre><code><b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">DKGSessionState</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>metadata: <a href="supra_dkg.md#0x1_supra_dkg_DKGSessionMetadata">supra_dkg::DKGSessionMetadata</a></code>
</dt>
<dd>

</dd>
<dt>
<code>start_time_us: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>dkg_meta_transcript: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>target_committees_public_key_shares: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_supra_dkg_DKGState"></a>

## Resource `DKGState`

The completed and in-progress DKG sessions.


<pre><code><b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>last_completed: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">supra_dkg::DKGSessionState</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>in_progress: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">supra_dkg::DKGSessionState</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_supra_dkg_OnChainAggregateCommitment"></a>

## Struct `OnChainAggregateCommitment`



<pre><code><b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_OnChainAggregateCommitment">OnChainAggregateCommitment</a> <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>bls12381_commitment_g: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls12381_commitment_evals: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>dealer_ids: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>committee_index: u32</code>
</dt>
<dd>

</dd>
<dt>
<code>epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code><a href="chain_id.md#0x1_chain_id">chain_id</a>: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>threshold_type: u8</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_supra_dkg_OnChainAggregateCommitmentAllCommittees"></a>

## Struct `OnChainAggregateCommitmentAllCommittees`



<pre><code><b>struct</b> <a href="supra_dkg.md#0x1_supra_dkg_OnChainAggregateCommitmentAllCommittees">OnChainAggregateCommitmentAllCommittees</a> <b>has</b> <b>copy</b>, drop
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>commitments: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_OnChainAggregateCommitment">supra_dkg::OnChainAggregateCommitment</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_supra_dkg_EDKG_INVALID_PK_SHARES"></a>



<pre><code><b>const</b> <a href="supra_dkg.md#0x1_supra_dkg_EDKG_INVALID_PK_SHARES">EDKG_INVALID_PK_SHARES</a>: u64 = 4;
</code></pre>



<a id="0x1_supra_dkg_EDKG_META_ALREADY_SET"></a>



<pre><code><b>const</b> <a href="supra_dkg.md#0x1_supra_dkg_EDKG_META_ALREADY_SET">EDKG_META_ALREADY_SET</a>: u64 = 2;
</code></pre>



<a id="0x1_supra_dkg_EDKG_META_NOT_SET"></a>



<pre><code><b>const</b> <a href="supra_dkg.md#0x1_supra_dkg_EDKG_META_NOT_SET">EDKG_META_NOT_SET</a>: u64 = 3;
</code></pre>



<a id="0x1_supra_dkg_EDKG_NOT_IN_PROGRESS"></a>



<pre><code><b>const</b> <a href="supra_dkg.md#0x1_supra_dkg_EDKG_NOT_IN_PROGRESS">EDKG_NOT_IN_PROGRESS</a>: u64 = 1;
</code></pre>



<a id="0x1_supra_dkg_initialize"></a>

## Function `initialize`

Called in genesis to initialize on-chain states.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>if</b> (!<b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>move_to</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(
            supra_framework,
            <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> {
                last_completed: std::option::none(),
                in_progress: std::option::none()
            }
        );
    };
}
</code></pre>



</details>

<a id="0x1_supra_dkg_start"></a>

## Function `start`

Mark on-chain DKG state as in-progress. Notify validators to start DKG.
Abort if a DKG is already in progress.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_start">start</a>(dealer_epoch: u64, randomness_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, dealer_committee: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a>, target_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_ReceiverCommittee">dkg_committee::ReceiverCommittee</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_start">start</a>(
    dealer_epoch: u64,
    randomness_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    dealer_committee: DkgCommittee,
    target_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;ReceiverCommittee&gt;
) <b>acquires</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> {
    <b>let</b> dkg_state = <b>borrow_global_mut</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
    <b>let</b> new_session_metadata = <a href="supra_dkg.md#0x1_supra_dkg_DKGSessionMetadata">DKGSessionMetadata</a> {
        dealer_epoch,
        randomness_seed,
        dealer_committee,
        target_committees
    };
    <b>let</b> start_time_us = <a href="timestamp.md#0x1_timestamp_now_microseconds">timestamp::now_microseconds</a>();
    dkg_state.in_progress = std::option::some(
        <a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">DKGSessionState</a> {
            metadata: new_session_metadata,
            start_time_us,
            dkg_meta_transcript: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[],
            target_committees_public_key_shares: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[]
        }
    );

    emit(
        <a href="supra_dkg.md#0x1_supra_dkg_DKGStartEvent">DKGStartEvent</a> { start_time_us, session_metadata: new_session_metadata }
    );
}
</code></pre>



</details>

<a id="0x1_supra_dkg_set_dkg_meta"></a>

## Function `set_dkg_meta`

Family Node sets the DKGMeta for the in-progress DKG session
The dkg transcript is assumed to have been already verified by the aptos VM in <code>process_dkg_result</code> method


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_set_dkg_meta">set_dkg_meta</a>(dkg_meta_all_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_set_dkg_meta">set_dkg_meta</a>(dkg_meta_all_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) <b>acquires</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> {
    // ensure <a href="dkg.md#0x1_dkg">dkg</a> is in progress
    <b>let</b> dkg_state = <b>borrow_global_mut</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&dkg_state.in_progress),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="supra_dkg.md#0x1_supra_dkg_EDKG_NOT_IN_PROGRESS">EDKG_NOT_IN_PROGRESS</a>)
    );

    // we only add the first DKG Meta proposed and ignore the rest
    <b>let</b> session = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> dkg_state.in_progress);
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&session.dkg_meta_transcript) == 0,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="supra_dkg.md#0x1_supra_dkg_EDKG_META_ALREADY_SET">EDKG_META_ALREADY_SET</a>)
    );
    session.dkg_meta_transcript = dkg_meta_all_committees;
    dkg_state.in_progress = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(session);

    emit(<a href="supra_dkg.md#0x1_supra_dkg_DKGMetaSetEvent">DKGMetaSetEvent</a> { dkg_meta_transcript: dkg_meta_all_committees });
}
</code></pre>



</details>

<a id="0x1_supra_dkg_finish"></a>

## Function `finish`

Family Node sets the <code>target_committees_public_key_shares</code> for the in-progress DKG session and
marks the incomplete DKG session completed.
The <code>target_committees_public_key_shares</code> is assumed to be verified by the aptos VM before calling this function


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_finish">finish</a>(target_committees_public_key_shares: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_finish">finish</a>(
    target_committees_public_key_shares: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) <b>acquires</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> {
    // ensure <a href="dkg.md#0x1_dkg">dkg</a> is in progress
    <b>let</b> dkg_state = <b>borrow_global_mut</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&dkg_state.in_progress),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="supra_dkg.md#0x1_supra_dkg_EDKG_NOT_IN_PROGRESS">EDKG_NOT_IN_PROGRESS</a>)
    );

    // DKG meta should be already set before `finish` is called
    <b>let</b> session = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> dkg_state.in_progress);
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&session.dkg_meta_transcript) &gt; 0,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="supra_dkg.md#0x1_supra_dkg_EDKG_META_NOT_SET">EDKG_META_NOT_SET</a>)
    );

    session.target_committees_public_key_shares = target_committees_public_key_shares;
    dkg_state.last_completed = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(session);
    dkg_state.in_progress = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>();

    // propagate updated keys <b>to</b> <a href="stake.md#0x1_stake">stake</a>.<b>move</b> for all threshold types
    <b>let</b> public_key_shares_all_comms_serialized =
        <a href="../../aptos-stdlib/doc/any.md#0x1_any_new">any::new</a>(
            <a href="../../aptos-stdlib/doc/type_info.md#0x1_type_info_type_name">type_info::type_name</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_OnChainAggregateCommitmentAllCommittees">OnChainAggregateCommitmentAllCommittees</a>&gt;(),
            target_committees_public_key_shares
        );
    <b>let</b> public_key_shares_all_comms =
        <a href="../../aptos-stdlib/doc/any.md#0x1_any_unpack">any::unpack</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_OnChainAggregateCommitmentAllCommittees">OnChainAggregateCommitmentAllCommittees</a>&gt;(
            public_key_shares_all_comms_serialized
        );

    // Build a <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a> of DkgCommitteeOutput for all committees
    <b>let</b> committee_outputs = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> i = 0;
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&public_key_shares_all_comms.commitments);
    <b>while</b> (i &lt; len) {
        <b>let</b> commitment = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&public_key_shares_all_comms.commitments, i);
        // As the first index contains the committee's threshold <b>public</b> key, we can skip that
        <b>let</b> evals = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_slice">vector::slice</a>(
            &commitment.bls12381_commitment_evals,
            1,
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&commitment.bls12381_commitment_evals)
        );

        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(
            &<b>mut</b> committee_outputs,
            new_dkg_committee_output(commitment.threshold_type, evals)
        );
        i = i + 1;
    };

    // Set all keys for all threshold types
    <a href="stake.md#0x1_stake_set_dkg_output_keys">stake::set_dkg_output_keys</a>(committee_outputs);
    emit(<a href="supra_dkg.md#0x1_supra_dkg_DKGFinishEvent">DKGFinishEvent</a> { target_committees_public_key_shares });
}
</code></pre>



</details>

<a id="0x1_supra_dkg_try_clear_incomplete_session"></a>

## Function `try_clear_incomplete_session`

Delete the currently incomplete session, if it exists.


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_try_clear_incomplete_session">try_clear_incomplete_session</a>(fx: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_try_clear_incomplete_session">try_clear_incomplete_session</a>(fx: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(fx);
    <b>if</b> (<b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>let</b> dkg_state = <b>borrow_global_mut</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
        dkg_state.in_progress = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>();
    }
}
</code></pre>



</details>

<a id="0x1_supra_dkg_incomplete_session"></a>

## Function `incomplete_session`

Return the incomplete DKG session state, if it exists.


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_incomplete_session">incomplete_session</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">supra_dkg::DKGSessionState</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_incomplete_session">incomplete_session</a>(): Option&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">DKGSessionState</a>&gt; <b>acquires</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>borrow_global</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework).in_progress
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
    }
}
</code></pre>



</details>

<a id="0x1_supra_dkg_last_completed_session"></a>

## Function `last_completed_session`

Return the last completed DKG session state, if it exists.


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_last_completed_session">last_completed_session</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">supra_dkg::DKGSessionState</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_last_completed_session">last_completed_session</a>(): Option&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">DKGSessionState</a>&gt; <b>acquires</b> <a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>borrow_global</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework).last_completed
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
    }
}
</code></pre>



</details>

<a id="0x1_supra_dkg_session_dealer_epoch"></a>

## Function `session_dealer_epoch`

Return the dealer epoch of a <code><a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">DKGSessionState</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_session_dealer_epoch">session_dealer_epoch</a>(session: &<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">supra_dkg::DKGSessionState</a>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_session_dealer_epoch">session_dealer_epoch</a>(session: &<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">DKGSessionState</a>): u64 {
    session.metadata.dealer_epoch
}
</code></pre>



</details>

<a id="@Specification_1"></a>

## Specification



<pre><code><b>invariant</b> [suspendable] <a href="chain_status.md#0x1_chain_status_is_operating">chain_status::is_operating</a>() ==&gt;
    <b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
</code></pre>



<a id="@Specification_1_initialize"></a>

### Function `initialize`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>let</b> supra_framework_addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(supra_framework);
<b>aborts_if</b> supra_framework_addr != @supra_framework;
</code></pre>



<a id="@Specification_1_start"></a>

### Function `start`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_start">start</a>(dealer_epoch: u64, randomness_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, dealer_committee: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a>, target_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_ReceiverCommittee">dkg_committee::ReceiverCommittee</a>&gt;)
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timestamp.md#0x1_timestamp_CurrentTimeMicroseconds">timestamp::CurrentTimeMicroseconds</a>&gt;(@supra_framework);
</code></pre>



<a id="@Specification_1_set_dkg_meta"></a>

### Function `set_dkg_meta`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_set_dkg_meta">set_dkg_meta</a>(dkg_meta_all_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>requires</b> <b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
<b>requires</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(<b>global</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework).in_progress);
<b>aborts_if</b> <b>false</b>;
</code></pre>



<a id="@Specification_1_finish"></a>

### Function `finish`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_finish">finish</a>(target_committees_public_key_shares: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>requires</b> <b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
<b>requires</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(<b>global</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework).in_progress);
<b>aborts_if</b> <b>false</b>;
</code></pre>




<a id="0x1_supra_dkg_has_incomplete_session"></a>


<pre><code><b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_has_incomplete_session">has_incomplete_session</a>(): bool {
   <b>if</b> (<b>exists</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
       <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_spec_is_some">option::spec_is_some</a>(<b>global</b>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGState">DKGState</a>&gt;(@supra_framework).in_progress)
   } <b>else</b> { <b>false</b> }
}
</code></pre>



<a id="@Specification_1_try_clear_incomplete_session"></a>

### Function `try_clear_incomplete_session`


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_try_clear_incomplete_session">try_clear_incomplete_session</a>(fx: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>let</b> addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(fx);
<b>aborts_if</b> addr != @supra_framework;
</code></pre>



<a id="@Specification_1_incomplete_session"></a>

### Function `incomplete_session`


<pre><code><b>public</b> <b>fun</b> <a href="supra_dkg.md#0x1_supra_dkg_incomplete_session">incomplete_session</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="supra_dkg.md#0x1_supra_dkg_DKGSessionState">supra_dkg::DKGSessionState</a>&gt;
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
