
<a id="0x1_dkg_committee"></a>

# Module `0x1::dkg_committee`



-  [Struct `DkgCommitteeType`](#0x1_dkg_committee_DkgCommitteeType)
-  [Struct `DkgNodeConfig`](#0x1_dkg_committee_DkgNodeConfig)
-  [Struct `DkgCommittee`](#0x1_dkg_committee_DkgCommittee)
-  [Struct `ReceiverCommittee`](#0x1_dkg_committee_ReceiverCommittee)
-  [Constants](#@Constants_0)
-  [Function `clan_committee_type`](#0x1_dkg_committee_clan_committee_type)
-  [Function `tribe_committee_type`](#0x1_dkg_committee_tribe_committee_type)
-  [Function `is_clan_committee_type`](#0x1_dkg_committee_is_clan_committee_type)
-  [Function `is_tribe_committee_type`](#0x1_dkg_committee_is_tribe_committee_type)
-  [Function `new_dkg_node_config`](#0x1_dkg_committee_new_dkg_node_config)
-  [Function `get_addr`](#0x1_dkg_committee_get_addr)
-  [Function `get_dkg_pubkey`](#0x1_dkg_committee_get_dkg_pubkey)
-  [Function `len`](#0x1_dkg_committee_len)
-  [Function `get_committee`](#0x1_dkg_committee_get_committee)
-  [Function `new_dkg_committee`](#0x1_dkg_committee_new_dkg_committee)
-  [Function `new_dkg_committee_from_validator_consensus_info`](#0x1_dkg_committee_new_dkg_committee_from_validator_consensus_info)
-  [Function `new_receiver_committee`](#0x1_dkg_committee_new_receiver_committee)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="validator_consensus_info.md#0x1_validator_consensus_info">0x1::validator_consensus_info</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_dkg_committee_DkgCommitteeType"></a>

## Struct `DkgCommitteeType`

Internal tag wrapper


<pre><code><b>struct</b> <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>tag: u8</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_committee_DkgNodeConfig"></a>

## Struct `DkgNodeConfig`



<pre><code><b>struct</b> <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>identity: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>dkg_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_committee_DkgCommittee"></a>

## Struct `DkgCommittee`



<pre><code><b>struct</b> <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>type: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">dkg_committee::DkgCommitteeType</a></code>
</dt>
<dd>

</dd>
<dt>
<code>committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_committee_ReceiverCommittee"></a>

## Struct `ReceiverCommittee`



<pre><code><b>struct</b> <a href="dkg_committee.md#0x1_dkg_committee_ReceiverCommittee">ReceiverCommittee</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>is_resharing: bool</code>
</dt>
<dd>

</dd>
<dt>
<code>committee: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE"></a>



<pre><code><b>const</b> <a href="dkg_committee.md#0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE">EINVALID_DKG_COMMITTEE_SIZE</a>: u64 = 1;
</code></pre>



<a id="0x1_dkg_committee_EINVALID_DKG_NODE_PUBLIC_KEY"></a>



<pre><code><b>const</b> <a href="dkg_committee.md#0x1_dkg_committee_EINVALID_DKG_NODE_PUBLIC_KEY">EINVALID_DKG_NODE_PUBLIC_KEY</a>: u64 = 2;
</code></pre>



<a id="0x1_dkg_committee_TYPE_CLAN"></a>



<pre><code><b>const</b> <a href="dkg_committee.md#0x1_dkg_committee_TYPE_CLAN">TYPE_CLAN</a>: u8 = 0;
</code></pre>



<a id="0x1_dkg_committee_TYPE_TRIBE"></a>



<pre><code><b>const</b> <a href="dkg_committee.md#0x1_dkg_committee_TYPE_TRIBE">TYPE_TRIBE</a>: u8 = 1;
</code></pre>



<a id="0x1_dkg_committee_clan_committee_type"></a>

## Function `clan_committee_type`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_clan_committee_type">clan_committee_type</a>(): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">dkg_committee::DkgCommitteeType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_clan_committee_type">clan_committee_type</a>(): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a> { <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a> { tag: <a href="dkg_committee.md#0x1_dkg_committee_TYPE_CLAN">TYPE_CLAN</a> } }
</code></pre>



</details>

<a id="0x1_dkg_committee_tribe_committee_type"></a>

## Function `tribe_committee_type`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_tribe_committee_type">tribe_committee_type</a>(): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">dkg_committee::DkgCommitteeType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_tribe_committee_type">tribe_committee_type</a>(): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a> { <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a> { tag: <a href="dkg_committee.md#0x1_dkg_committee_TYPE_TRIBE">TYPE_TRIBE</a> } }
</code></pre>



</details>

<a id="0x1_dkg_committee_is_clan_committee_type"></a>

## Function `is_clan_committee_type`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_is_clan_committee_type">is_clan_committee_type</a>(t: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">dkg_committee::DkgCommitteeType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_is_clan_committee_type">is_clan_committee_type</a>(t: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a>): bool { t.tag == <a href="dkg_committee.md#0x1_dkg_committee_TYPE_CLAN">TYPE_CLAN</a> }
</code></pre>



</details>

<a id="0x1_dkg_committee_is_tribe_committee_type"></a>

## Function `is_tribe_committee_type`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_is_tribe_committee_type">is_tribe_committee_type</a>(t: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">dkg_committee::DkgCommitteeType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_is_tribe_committee_type">is_tribe_committee_type</a>(t: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a>): bool { t.tag == <a href="dkg_committee.md#0x1_dkg_committee_TYPE_TRIBE">TYPE_TRIBE</a> }
</code></pre>



</details>

<a id="0x1_dkg_committee_new_dkg_node_config"></a>

## Function `new_dkg_node_config`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_node_config">new_dkg_node_config</a>(addr: <b>address</b>, identity: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, dkg_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_node_config">new_dkg_node_config</a>(addr: <b>address</b>, identity: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, dkg_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,): <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>{
    <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>{
        addr,
        identity,
        dkg_pubkey
    }
}
</code></pre>



</details>

<a id="0x1_dkg_committee_get_addr"></a>

## Function `get_addr`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_addr">get_addr</a>(dkg_node: &<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_addr">get_addr</a>(dkg_node: &<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>): <b>address</b>{
    dkg_node.addr
}
</code></pre>



</details>

<a id="0x1_dkg_committee_get_dkg_pubkey"></a>

## Function `get_dkg_pubkey`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_dkg_pubkey">get_dkg_pubkey</a>(dkg_node: &<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_dkg_pubkey">get_dkg_pubkey</a>(dkg_node: &<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;{
    dkg_node.dkg_pubkey
}
</code></pre>



</details>

<a id="0x1_dkg_committee_len"></a>

## Function `len`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_len">len</a>(committee: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_len">len</a>(committee: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>): u64{
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&committee.committee)
}
</code></pre>



</details>

<a id="0x1_dkg_committee_get_committee"></a>

## Function `get_committee`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_committee">get_committee</a>(<a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a>: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_committee">get_committee</a>(<a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a>: &<a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>&gt;{
    <a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a>.committee
}
</code></pre>



</details>

<a id="0x1_dkg_committee_new_dkg_committee"></a>

## Function `new_dkg_committee`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_committee">new_dkg_committee</a>(type: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">dkg_committee::DkgCommitteeType</a>, committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>&gt;): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_committee">new_dkg_committee</a>(type: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a>, committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>&gt;): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>{

    <b>if</b>(<a href="dkg_committee.md#0x1_dkg_committee_is_clan_committee_type">is_clan_committee_type</a>(&type)){
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&committee) &gt; 2, <a href="dkg_committee.md#0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE">EINVALID_DKG_COMMITTEE_SIZE</a>);
    };
    <b>if</b>(<a href="dkg_committee.md#0x1_dkg_committee_is_tribe_committee_type">is_tribe_committee_type</a>(&type)){
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&committee) &gt; 3, <a href="dkg_committee.md#0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE">EINVALID_DKG_COMMITTEE_SIZE</a>);
    };

    <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>{
        type,
        committee
    }
}
</code></pre>



</details>

<a id="0x1_dkg_committee_new_dkg_committee_from_validator_consensus_info"></a>

## Function `new_dkg_committee_from_validator_consensus_info`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_committee_from_validator_consensus_info">new_dkg_committee_from_validator_consensus_info</a>(type: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">dkg_committee::DkgCommitteeType</a>, validator_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="validator_consensus_info.md#0x1_validator_consensus_info_ValidatorConsensusInfo">validator_consensus_info::ValidatorConsensusInfo</a>&gt;): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_committee_from_validator_consensus_info">new_dkg_committee_from_validator_consensus_info</a>(type: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommitteeType">DkgCommitteeType</a>, validator_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;ValidatorConsensusInfo&gt;): <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>{

    <b>if</b>(<a href="dkg_committee.md#0x1_dkg_committee_is_clan_committee_type">is_clan_committee_type</a>(&type)){
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&validator_committee) &gt; 2, <a href="dkg_committee.md#0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE">EINVALID_DKG_COMMITTEE_SIZE</a>);
    };
    <b>if</b>(<a href="dkg_committee.md#0x1_dkg_committee_is_tribe_committee_type">is_tribe_committee_type</a>(&type)){
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&validator_committee) &gt; 3, <a href="dkg_committee.md#0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE">EINVALID_DKG_COMMITTEE_SIZE</a>);
    };

    <b>let</b> <a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a> = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(validator_committee, |x|
        {
            <b>let</b> validator_keys_bytes = <a href="validator_consensus_info.md#0x1_validator_consensus_info_get_pk_bytes">validator_consensus_info::get_pk_bytes</a>(&x);
            <b>let</b> addr = <a href="validator_consensus_info.md#0x1_validator_consensus_info_get_addr">validator_consensus_info::get_addr</a>(&x);
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> <a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a>, <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>{
                addr,
                identity: <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&addr),
                dkg_pubkey: validator_keys_bytes,
            });
        }
    );

    <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>{
        type,
        committee: <a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a>,
    }
}
</code></pre>



</details>

<a id="0x1_dkg_committee_new_receiver_committee"></a>

## Function `new_receiver_committee`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_receiver_committee">new_receiver_committee</a>(is_resharing: bool, committee: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">dkg_committee::DkgCommittee</a>): <a href="dkg_committee.md#0x1_dkg_committee_ReceiverCommittee">dkg_committee::ReceiverCommittee</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_receiver_committee">new_receiver_committee</a>(is_resharing: bool, committee: <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>): <a href="dkg_committee.md#0x1_dkg_committee_ReceiverCommittee">ReceiverCommittee</a>{
    <a href="dkg_committee.md#0x1_dkg_committee_ReceiverCommittee">ReceiverCommittee</a>{
        is_resharing,
        committee
    }
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
