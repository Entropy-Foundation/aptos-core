
<a id="0x1_dkg_committee"></a>

# Module `0x1::dkg_committee`



-  [Struct `DkgCommitteeType`](#0x1_dkg_committee_DkgCommitteeType)
-  [Struct `DkgNodeConfig`](#0x1_dkg_committee_DkgNodeConfig)
-  [Struct `DkgCommittee`](#0x1_dkg_committee_DkgCommittee)
-  [Constants](#@Constants_0)
-  [Function `clan_committee_type`](#0x1_dkg_committee_clan_committee_type)
-  [Function `tribe_committee_type`](#0x1_dkg_committee_tribe_committee_type)
-  [Function `is_clan_committee_type`](#0x1_dkg_committee_is_clan_committee_type)
-  [Function `is_tribe_committee_type`](#0x1_dkg_committee_is_tribe_committee_type)
-  [Function `new_dkg_node_config`](#0x1_dkg_committee_new_dkg_node_config)
-  [Function `get_addr`](#0x1_dkg_committee_get_addr)
-  [Function `get_bls_pubkey`](#0x1_dkg_committee_get_bls_pubkey)
-  [Function `get_committee`](#0x1_dkg_committee_get_committee)
-  [Function `new_dkg_committee`](#0x1_dkg_committee_new_dkg_committee)
-  [Function `new_dkg_committee_from_validator_consensus_info`](#0x1_dkg_committee_new_dkg_committee_from_validator_consensus_info)


<pre><code><b>use</b> <a href="validator_consensus_info.md#0x1_validator_consensus_info">0x1::validator_consensus_info</a>;
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
<code>bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
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

<a id="@Constants_0"></a>

## Constants


<a id="0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE"></a>



<pre><code><b>const</b> <a href="dkg_committee.md#0x1_dkg_committee_EINVALID_DKG_COMMITTEE_SIZE">EINVALID_DKG_COMMITTEE_SIZE</a>: u64 = 1;
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



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_node_config">new_dkg_node_config</a>(addr: <b>address</b>, bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_new_dkg_node_config">new_dkg_node_config</a>(addr: <b>address</b>, bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,): <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>{
    <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>{
        addr,
        bls_pubkey
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

<a id="0x1_dkg_committee_get_bls_pubkey"></a>

## Function `get_bls_pubkey`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_bls_pubkey">get_bls_pubkey</a>(dkg_node: &<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">dkg_committee::DkgNodeConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_committee.md#0x1_dkg_committee_get_bls_pubkey">get_bls_pubkey</a>(dkg_node: &<a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;{
    dkg_node.bls_pubkey
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
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> <a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a>, <a href="dkg_committee.md#0x1_dkg_committee_DkgNodeConfig">DkgNodeConfig</a>{
                addr: <a href="validator_consensus_info.md#0x1_validator_consensus_info_get_addr">validator_consensus_info::get_addr</a>(&x),
                bls_pubkey: <a href="validator_consensus_info.md#0x1_validator_consensus_info_get_pk_bytes">validator_consensus_info::get_pk_bytes</a>(&x)
            });
        }
    );

    <a href="dkg_committee.md#0x1_dkg_committee_DkgCommittee">DkgCommittee</a>{
        type,
        committee: <a href="dkg_committee.md#0x1_dkg_committee">dkg_committee</a>
    }
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
