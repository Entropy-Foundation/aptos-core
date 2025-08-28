
<a id="0x1_dkg"></a>

# Module `0x1::dkg`

DKG on-chain states and helper functions.


-  [Struct `DKGSessionMetadata`](#0x1_dkg_DKGSessionMetadata)
-  [Struct `DKGMetaAllCommittees`](#0x1_dkg_DKGMetaAllCommittees)
-  [Struct `DKGStartEvent`](#0x1_dkg_DKGStartEvent)
-  [Struct `DKGSessionState`](#0x1_dkg_DKGSessionState)
-  [Resource `DKGState`](#0x1_dkg_DKGState)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_dkg_initialize)
-  [Function `start`](#0x1_dkg_start)
-  [Function `clan_threshold`](#0x1_dkg_clan_threshold)
-  [Function `is_node_family_committee_member`](#0x1_dkg_is_node_family_committee_member)
-  [Function `get_signer_bls_keys_from_indices`](#0x1_dkg_get_signer_bls_keys_from_indices)
-  [Function `finish`](#0x1_dkg_finish)
-  [Function `try_clear_incomplete_session`](#0x1_dkg_try_clear_incomplete_session)
-  [Function `incomplete_session`](#0x1_dkg_incomplete_session)
-  [Function `last_completed_session`](#0x1_dkg_last_completed_session)
-  [Function `session_dealer_epoch`](#0x1_dkg_session_dealer_epoch)
-  [Function `get_clan_committee_indices`](#0x1_dkg_get_clan_committee_indices)
-  [Function `get_family_committee_indices`](#0x1_dkg_get_family_committee_indices)
-  [Function `native_get_family_committee_indices`](#0x1_dkg_native_get_family_committee_indices)
-  [Function `native_get_clan_committee_indices`](#0x1_dkg_native_get_clan_committee_indices)
-  [Specification](#@Specification_1)
    -  [Function `initialize`](#@Specification_1_initialize)
    -  [Function `start`](#@Specification_1_start)
    -  [Function `finish`](#@Specification_1_finish)
    -  [Function `try_clear_incomplete_session`](#@Specification_1_try_clear_incomplete_session)
    -  [Function `incomplete_session`](#@Specification_1_incomplete_session)


<pre><code><b>use</b> <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381">0x1::bls12381</a>;
<b>use</b> <a href="../../supra-stdlib/doc/consensus_key.md#0x1_consensus_key">0x1::consensus_key</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="validator_consensus_info.md#0x1_validator_consensus_info">0x1::validator_consensus_info</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_dkg_DKGSessionMetadata"></a>

## Struct `DKGSessionMetadata`

This can be considered as the public input of DKG.


<pre><code><b>struct</b> <a href="dkg.md#0x1_dkg_DKGSessionMetadata">DKGSessionMetadata</a> <b>has</b> <b>copy</b>, drop, store
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
<code>current_validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="validator_consensus_info.md#0x1_validator_consensus_info_ValidatorConsensusInfo">validator_consensus_info::ValidatorConsensusInfo</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_DKGMetaAllCommittees"></a>

## Struct `DKGMetaAllCommittees`



<pre><code><b>struct</b> <a href="dkg.md#0x1_dkg_DKGMetaAllCommittees">DKGMetaAllCommittees</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_DKGStartEvent"></a>

## Struct `DKGStartEvent`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="dkg.md#0x1_dkg_DKGStartEvent">DKGStartEvent</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>session_metadata: <a href="dkg.md#0x1_dkg_DKGSessionMetadata">dkg::DKGSessionMetadata</a></code>
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

<a id="0x1_dkg_DKGSessionState"></a>

## Struct `DKGSessionState`

The input and output of a DKG session.
The validator set of epoch <code>x</code> works together for an DKG output for the target validator set of epoch <code>x+1</code>.


<pre><code><b>struct</b> <a href="dkg.md#0x1_dkg_DKGSessionState">DKGSessionState</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>metadata: <a href="dkg.md#0x1_dkg_DKGSessionMetadata">dkg::DKGSessionMetadata</a></code>
</dt>
<dd>

</dd>
<dt>
<code>start_time_us: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>dkg_meta_transcript: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="dkg.md#0x1_dkg_DKGMetaAllCommittees">dkg::DKGMetaAllCommittees</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_DKGState"></a>

## Resource `DKGState`

The completed and in-progress DKG sessions.


<pre><code><b>struct</b> <a href="dkg.md#0x1_dkg_DKGState">DKGState</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>last_completed: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="dkg.md#0x1_dkg_DKGSessionState">dkg::DKGSessionState</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>in_progress: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="dkg.md#0x1_dkg_DKGSessionState">dkg::DKGSessionState</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_dkg_EDKG_INVALID_SIGNER_VERIFICATION_KEY"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_INVALID_SIGNER_VERIFICATION_KEY">EDKG_INVALID_SIGNER_VERIFICATION_KEY</a>: u64 = 7;
</code></pre>



<a id="0x1_dkg_EDKG_INVALID_TRIBE_SIZE"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_INVALID_TRIBE_SIZE">EDKG_INVALID_TRIBE_SIZE</a>: u64 = 4;
</code></pre>



<a id="0x1_dkg_EDKG_IN_PROGRESS"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_IN_PROGRESS">EDKG_IN_PROGRESS</a>: u64 = 1;
</code></pre>



<a id="0x1_dkg_EDKG_META_ALREADY_SET"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_META_ALREADY_SET">EDKG_META_ALREADY_SET</a>: u64 = 3;
</code></pre>



<a id="0x1_dkg_EDKG_META_SIGNATURE_VERIFICATION_FAILED"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_META_SIGNATURE_VERIFICATION_FAILED">EDKG_META_SIGNATURE_VERIFICATION_FAILED</a>: u64 = 8;
</code></pre>



<a id="0x1_dkg_EDKG_NOT_FAMILY_NODE"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_NOT_FAMILY_NODE">EDKG_NOT_FAMILY_NODE</a>: u64 = 5;
</code></pre>



<a id="0x1_dkg_EDKG_NOT_IN_PROGRESS"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_NOT_IN_PROGRESS">EDKG_NOT_IN_PROGRESS</a>: u64 = 2;
</code></pre>



<a id="0x1_dkg_EDKG_NOT_THRESHOLD_SIGNERS"></a>



<pre><code><b>const</b> <a href="dkg.md#0x1_dkg_EDKG_NOT_THRESHOLD_SIGNERS">EDKG_NOT_THRESHOLD_SIGNERS</a>: u64 = 6;
</code></pre>



<a id="0x1_dkg_initialize"></a>

## Function `initialize`

Called in genesis to initialize on-chain states.


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>if</b> (!<b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>move_to</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(
            supra_framework,
            <a href="dkg.md#0x1_dkg_DKGState">DKGState</a> {
                last_completed: std::option::none(),
                in_progress: std::option::none(),
            }
        );
    }
}
</code></pre>



</details>

<a id="0x1_dkg_start"></a>

## Function `start`

Mark on-chain DKG state as in-progress. Notify validators to start DKG.
Abort if a DKG is already in progress.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg.md#0x1_dkg_start">start</a>(dealer_epoch: u64, randomness_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, current_validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="validator_consensus_info.md#0x1_validator_consensus_info_ValidatorConsensusInfo">validator_consensus_info::ValidatorConsensusInfo</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg.md#0x1_dkg_start">start</a>(
    dealer_epoch: u64,
    randomness_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    current_validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;ValidatorConsensusInfo&gt;,
) <b>acquires</b> <a href="dkg.md#0x1_dkg_DKGState">DKGState</a> {
    <b>let</b> dkg_state = <b>borrow_global_mut</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
    <b>let</b> new_session_metadata = <a href="dkg.md#0x1_dkg_DKGSessionMetadata">DKGSessionMetadata</a> {
        dealer_epoch,
        randomness_seed,
        current_validator_set,
    };
    <b>let</b> start_time_us = <a href="timestamp.md#0x1_timestamp_now_microseconds">timestamp::now_microseconds</a>();
    dkg_state.in_progress = std::option::some(<a href="dkg.md#0x1_dkg_DKGSessionState">DKGSessionState</a> {
        metadata: new_session_metadata,
        start_time_us,
        dkg_meta_transcript: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
    });

    emit(<a href="dkg.md#0x1_dkg_DKGStartEvent">DKGStartEvent</a> {
        start_time_us,
        session_metadata: new_session_metadata,
    });
}
</code></pre>



</details>

<a id="0x1_dkg_clan_threshold"></a>

## Function `clan_threshold`

The threshold required to ensure the presence of honest majority in clan where
N = 2f+1 with f byzantine nodes


<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_clan_threshold">clan_threshold</a>(total: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_clan_threshold">clan_threshold</a>(total: u64): u64 {
    total / 2 + 1
}
</code></pre>



</details>

<a id="0x1_dkg_is_node_family_committee_member"></a>

## Function `is_node_family_committee_member`



<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_is_node_family_committee_member">is_node_family_committee_member</a>(addr: <b>address</b>, validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="validator_consensus_info.md#0x1_validator_consensus_info_ValidatorConsensusInfo">validator_consensus_info::ValidatorConsensusInfo</a>&gt;, random_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_is_node_family_committee_member">is_node_family_committee_member</a>(addr: <b>address</b>, validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;ValidatorConsensusInfo&gt;, random_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool {

    <b>let</b> family_committee_indices
        = <a href="dkg.md#0x1_dkg_get_family_committee_indices">get_family_committee_indices</a>((<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&validator_set) <b>as</b> u32), random_seed);

    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_any">vector::any</a>(&family_committee_indices, |family_node_index|{
        <b>let</b> family_node = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&validator_set, (*family_node_index <b>as</b> u64));
        get_addr(family_node) == addr
    })
}
</code></pre>



</details>

<a id="0x1_dkg_get_signer_bls_keys_from_indices"></a>

## Function `get_signer_bls_keys_from_indices`



<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_get_signer_bls_keys_from_indices">get_signer_bls_keys_from_indices</a>(validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="validator_consensus_info.md#0x1_validator_consensus_info_ValidatorConsensusInfo">validator_consensus_info::ValidatorConsensusInfo</a>&gt;, signers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;, random_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKeyWithPoP">bls12381::PublicKeyWithPoP</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_get_signer_bls_keys_from_indices">get_signer_bls_keys_from_indices</a>(validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;ValidatorConsensusInfo&gt;, signers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;, random_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;PublicKeyWithPoP&gt;{

    <b>let</b> dealer_clan_committee_indices = <a href="dkg.md#0x1_dkg_get_clan_committee_indices">get_clan_committee_indices</a>(
        (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&validator_set) <b>as</b> u32),
        random_seed);
    <b>let</b> clan_threshold = <a href="dkg.md#0x1_dkg_clan_threshold">clan_threshold</a>( <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&dealer_clan_committee_indices));

    <b>assert</b>!( <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&signers) == clan_threshold,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg.md#0x1_dkg_EDKG_NOT_THRESHOLD_SIGNERS">EDKG_NOT_THRESHOLD_SIGNERS</a>));

    <b>let</b> signer_keys = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(signers, |<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>| {
        <b>let</b> clan_node_index = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&dealer_clan_committee_indices, (<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> <b>as</b> u64));
        <b>let</b> clan_node = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&validator_set, (*clan_node_index <b>as</b> u64));
        <b>let</b> node_pk_bytes = get_pk_bytes(clan_node);

        <b>let</b> consensus_pk_option = <a href="../../supra-stdlib/doc/consensus_key.md#0x1_consensus_key_consensus_public_key_from_bytes">consensus_key::consensus_public_key_from_bytes</a>(node_pk_bytes);
        <b>assert</b>!(is_some(&consensus_pk_option),<a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg.md#0x1_dkg_EDKG_INVALID_SIGNER_VERIFICATION_KEY">EDKG_INVALID_SIGNER_VERIFICATION_KEY</a>));
        <b>let</b> consensus_pk = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> consensus_pk_option);
        <b>let</b> bls_key = <a href="../../supra-stdlib/doc/consensus_key.md#0x1_consensus_key_get_bls_pub_key">consensus_key::get_bls_pub_key</a>(&consensus_pk);

        // create <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a> vks assuming the corresponding pops have already been verified upon registration
        <b>let</b> signer_key_option = public_key_from_bytes_with_pop_externally_verified(<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_public_key_to_bytes">bls12381::public_key_to_bytes</a>(&bls_key));
        <b>assert</b>!(is_some(&signer_key_option),<a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg.md#0x1_dkg_EDKG_INVALID_SIGNER_VERIFICATION_KEY">EDKG_INVALID_SIGNER_VERIFICATION_KEY</a>));
        <b>let</b> signer_key = std::option::extract(&<b>mut</b> signer_key_option);
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> signer_keys, signer_key);
    });

    signer_keys
}
</code></pre>



</details>

<a id="0x1_dkg_finish"></a>

## Function `finish`

Family Node sets the DKGMeta for the in-progress DKG session and
marks the incomplete DKG session completed.

Abort if DKG is not in progress.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg.md#0x1_dkg_finish">finish</a>(<a href="account.md#0x1_account">account</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, dkg_meta_all_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, agg_signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg.md#0x1_dkg_finish">finish</a>(<a href="account.md#0x1_account">account</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
                          dkg_meta_all_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
                          agg_signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
                          signers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;)
<b>acquires</b> <a href="dkg.md#0x1_dkg_DKGState">DKGState</a> {
    // ensure <a href="dkg.md#0x1_dkg">dkg</a> is in progress
    <b>let</b> dkg_state = <b>borrow_global_mut</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&dkg_state.in_progress), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="dkg.md#0x1_dkg_EDKG_NOT_IN_PROGRESS">EDKG_NOT_IN_PROGRESS</a>));

    // we only add the first DKG Meta proposed and ignore the rest
    <b>let</b> session = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> dkg_state.in_progress);
    <b>assert</b>!(std::option::is_none(&session.dkg_meta_transcript), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="dkg.md#0x1_dkg_EDKG_META_ALREADY_SET">EDKG_META_ALREADY_SET</a>));

    // the <a href="dkg.md#0x1_dkg">dkg</a> meta should only be added by a family node
    <b>assert</b>!(<a href="dkg.md#0x1_dkg_is_node_family_committee_member">is_node_family_committee_member</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(&<a href="account.md#0x1_account">account</a>),
        session.metadata.current_validator_set,
        session.metadata.randomness_seed),
        <a href="dkg.md#0x1_dkg_EDKG_NOT_FAMILY_NODE">EDKG_NOT_FAMILY_NODE</a>
    );

    <b>let</b> signer_bls_pubkeys = <a href="dkg.md#0x1_dkg_get_signer_bls_keys_from_indices">get_signer_bls_keys_from_indices</a>(session.metadata.current_validator_set,
        signers,
        session.metadata.randomness_seed);

    // verify the multi signature on the <a href="dkg.md#0x1_dkg">dkg</a> meta is correct
    <b>let</b> agg_sig = aggr_or_multi_signature_from_bytes(agg_signature);
    <b>let</b> agg_pk = aggregate_pubkeys(signer_bls_pubkeys);
    <b>assert</b>!(verify_multisignature(&agg_sig, &agg_pk, dkg_meta_all_committees),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg.md#0x1_dkg_EDKG_META_SIGNATURE_VERIFICATION_FAILED">EDKG_META_SIGNATURE_VERIFICATION_FAILED</a>));

    session.dkg_meta_transcript = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(
        <a href="dkg.md#0x1_dkg_DKGMetaAllCommittees">DKGMetaAllCommittees</a>{
            bytes: dkg_meta_all_committees
        });

    dkg_state.last_completed = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(session);
    dkg_state.in_progress = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>();
}
</code></pre>



</details>

<a id="0x1_dkg_try_clear_incomplete_session"></a>

## Function `try_clear_incomplete_session`

Delete the currently incomplete session, if it exists.


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_try_clear_incomplete_session">try_clear_incomplete_session</a>(fx: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_try_clear_incomplete_session">try_clear_incomplete_session</a>(fx: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="dkg.md#0x1_dkg_DKGState">DKGState</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(fx);
    <b>if</b> (<b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>let</b> dkg_state = <b>borrow_global_mut</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
        dkg_state.in_progress = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>();
    }
}
</code></pre>



</details>

<a id="0x1_dkg_incomplete_session"></a>

## Function `incomplete_session`

Return the incomplete DKG session state, if it exists.


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_incomplete_session">incomplete_session</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="dkg.md#0x1_dkg_DKGSessionState">dkg::DKGSessionState</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_incomplete_session">incomplete_session</a>(): Option&lt;<a href="dkg.md#0x1_dkg_DKGSessionState">DKGSessionState</a>&gt; <b>acquires</b> <a href="dkg.md#0x1_dkg_DKGState">DKGState</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>borrow_global</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework).in_progress
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
    }
}
</code></pre>



</details>

<a id="0x1_dkg_last_completed_session"></a>

## Function `last_completed_session`

Return the last completed DKG session state, if it exists.


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_last_completed_session">last_completed_session</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="dkg.md#0x1_dkg_DKGSessionState">dkg::DKGSessionState</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_last_completed_session">last_completed_session</a>(): Option&lt;<a href="dkg.md#0x1_dkg_DKGSessionState">DKGSessionState</a>&gt; <b>acquires</b> <a href="dkg.md#0x1_dkg_DKGState">DKGState</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
        <b>borrow_global</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework).last_completed
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>()
    }
}
</code></pre>



</details>

<a id="0x1_dkg_session_dealer_epoch"></a>

## Function `session_dealer_epoch`

Return the dealer epoch of a <code><a href="dkg.md#0x1_dkg_DKGSessionState">DKGSessionState</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_session_dealer_epoch">session_dealer_epoch</a>(session: &<a href="dkg.md#0x1_dkg_DKGSessionState">dkg::DKGSessionState</a>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_session_dealer_epoch">session_dealer_epoch</a>(session: &<a href="dkg.md#0x1_dkg_DKGSessionState">DKGSessionState</a>): u64 {
    session.metadata.dealer_epoch
}
</code></pre>



</details>

<a id="0x1_dkg_get_clan_committee_indices"></a>

## Function `get_clan_committee_indices`



<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_get_clan_committee_indices">get_clan_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_get_clan_committee_indices">get_clan_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;{
    <b>let</b> clan_indices = <a href="dkg.md#0x1_dkg_native_get_clan_committee_indices">native_get_clan_committee_indices</a>(tribe_size, seed);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&clan_indices) &gt; 0, <a href="dkg.md#0x1_dkg_EDKG_INVALID_TRIBE_SIZE">EDKG_INVALID_TRIBE_SIZE</a>);
    clan_indices
}
</code></pre>



</details>

<a id="0x1_dkg_get_family_committee_indices"></a>

## Function `get_family_committee_indices`



<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_get_family_committee_indices">get_family_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_get_family_committee_indices">get_family_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;{
    <b>let</b> family_indices = <a href="dkg.md#0x1_dkg_native_get_family_committee_indices">native_get_family_committee_indices</a>(tribe_size, seed);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&family_indices) &gt; 0, <a href="dkg.md#0x1_dkg_EDKG_INVALID_TRIBE_SIZE">EDKG_INVALID_TRIBE_SIZE</a>);
    family_indices
}
</code></pre>



</details>

<a id="0x1_dkg_native_get_family_committee_indices"></a>

## Function `native_get_family_committee_indices`



<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_native_get_family_committee_indices">native_get_family_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="dkg.md#0x1_dkg_native_get_family_committee_indices">native_get_family_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;;
</code></pre>



</details>

<a id="0x1_dkg_native_get_clan_committee_indices"></a>

## Function `native_get_clan_committee_indices`



<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_native_get_clan_committee_indices">native_get_clan_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="dkg.md#0x1_dkg_native_get_clan_committee_indices">native_get_clan_committee_indices</a>(tribe_size: u32, seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;;
</code></pre>



</details>

<a id="@Specification_1"></a>

## Specification



<pre><code><b>invariant</b> [suspendable] <a href="chain_status.md#0x1_chain_status_is_operating">chain_status::is_operating</a>() ==&gt; <b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
</code></pre>



<a id="@Specification_1_initialize"></a>

### Function `initialize`


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>let</b> supra_framework_addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(supra_framework);
<b>aborts_if</b> supra_framework_addr != @supra_framework;
</code></pre>



<a id="@Specification_1_start"></a>

### Function `start`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg.md#0x1_dkg_start">start</a>(dealer_epoch: u64, randomness_seed: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, current_validator_set: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="validator_consensus_info.md#0x1_validator_consensus_info_ValidatorConsensusInfo">validator_consensus_info::ValidatorConsensusInfo</a>&gt;)
</code></pre>




<pre><code><b>aborts_if</b> !<b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
<b>aborts_if</b> !<b>exists</b>&lt;<a href="timestamp.md#0x1_timestamp_CurrentTimeMicroseconds">timestamp::CurrentTimeMicroseconds</a>&gt;(@supra_framework);
</code></pre>



<a id="@Specification_1_finish"></a>

### Function `finish`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg.md#0x1_dkg_finish">finish</a>(<a href="account.md#0x1_account">account</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, dkg_meta_all_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, agg_signature: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, signers: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u32&gt;)
</code></pre>




<pre><code><b>requires</b> <b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework);
<b>requires</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(<b>global</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework).in_progress);
<b>aborts_if</b> <b>false</b>;
</code></pre>




<a id="0x1_dkg_has_incomplete_session"></a>


<pre><code><b>fun</b> <a href="dkg.md#0x1_dkg_has_incomplete_session">has_incomplete_session</a>(): bool {
   <b>if</b> (<b>exists</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework)) {
       <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_spec_is_some">option::spec_is_some</a>(<b>global</b>&lt;<a href="dkg.md#0x1_dkg_DKGState">DKGState</a>&gt;(@supra_framework).in_progress)
   } <b>else</b> {
       <b>false</b>
   }
}
</code></pre>



<a id="@Specification_1_try_clear_incomplete_session"></a>

### Function `try_clear_incomplete_session`


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_try_clear_incomplete_session">try_clear_incomplete_session</a>(fx: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>let</b> addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(fx);
<b>aborts_if</b> addr != @supra_framework;
</code></pre>



<a id="@Specification_1_incomplete_session"></a>

### Function `incomplete_session`


<pre><code><b>public</b> <b>fun</b> <a href="dkg.md#0x1_dkg_incomplete_session">incomplete_session</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="dkg.md#0x1_dkg_DKGSessionState">dkg::DKGSessionState</a>&gt;
</code></pre>




<pre><code><b>aborts_if</b> <b>false</b>;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
