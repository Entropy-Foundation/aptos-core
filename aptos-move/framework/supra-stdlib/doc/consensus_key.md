
<a id="0x1_consensus_key"></a>

# Module `0x1::consensus_key`



-  [Struct `ConsensusPublicKey`](#0x1_consensus_key_ConsensusPublicKey)
-  [Constants](#@Constants_0)
-  [Function `consensus_public_key_from_bytes`](#0x1_consensus_key_consensus_public_key_from_bytes)
-  [Function `public_key_to_bytes`](#0x1_consensus_key_public_key_to_bytes)
-  [Function `get_bls_pub_key`](#0x1_consensus_key_get_bls_pub_key)
-  [Function `get_ed_key`](#0x1_consensus_key_get_ed_key)
-  [Function `get_cg_key`](#0x1_consensus_key_get_cg_key)


<pre><code><b>use</b> <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381">0x1::bls12381</a>;
<b>use</b> <a href="class_groups.md#0x1_class_groups">0x1::class_groups</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519">0x1::ed25519</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_consensus_key_ConsensusPublicKey"></a>

## Struct `ConsensusPublicKey`

Consensus public key consists of:
1. Ed25519 key
2. Bls12381 G1 key
3. Class group encryption key


<pre><code><b>struct</b> <a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>ed_key: <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a></code>
</dt>
<dd>

</dd>
<dt>
<code>bls_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>cg_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_consensus_key_E_WRONG_PUBKEY_SIZE"></a>

Wrong number of bytes were given as input when deserializing an consensus public key.


<pre><code><b>const</b> <a href="consensus_key.md#0x1_consensus_key_E_WRONG_PUBKEY_SIZE">E_WRONG_PUBKEY_SIZE</a>: u64 = 1;
</code></pre>



<a id="0x1_consensus_key_BLS12381_G1_PUBLIC_KEY_NUM_BYTES"></a>

The size of a serialized bls12381 G1 public key, in bytes.


<pre><code><b>const</b> <a href="consensus_key.md#0x1_consensus_key_BLS12381_G1_PUBLIC_KEY_NUM_BYTES">BLS12381_G1_PUBLIC_KEY_NUM_BYTES</a>: u64 = 48;
</code></pre>



<a id="0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES"></a>

The size of a serialized ed25519 public key, in bytes.


<pre><code><b>const</b> <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a>: u64 = 32;
</code></pre>



<a id="0x1_consensus_key_EINVALID_PUBLIC_KEY"></a>

Invalid consensus public key


<pre><code><b>const</b> <a href="consensus_key.md#0x1_consensus_key_EINVALID_PUBLIC_KEY">EINVALID_PUBLIC_KEY</a>: u64 = 2;
</code></pre>



<a id="0x1_consensus_key_consensus_public_key_from_bytes"></a>

## Function `consensus_public_key_from_bytes`



<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_consensus_public_key_from_bytes">consensus_public_key_from_bytes</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">consensus_key::ConsensusPublicKey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_consensus_public_key_from_bytes">consensus_public_key_from_bytes</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a>&gt;{
    //todo: pop for ed and bls
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&bytes) == <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a>){
        <b>let</b> ed_key_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_slice">vector::slice</a>(&bytes, 0, <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a>);
        <b>let</b> valid_ed_public_key = <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_validated_public_key_from_bytes">ed25519::new_validated_public_key_from_bytes</a>(ed_key_bytes);
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&valid_ed_public_key), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="consensus_key.md#0x1_consensus_key_EINVALID_PUBLIC_KEY">EINVALID_PUBLIC_KEY</a>));
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a> {
            ed_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> valid_ed_public_key),
            bls_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;(),
            cg_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>&lt;<a href="class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>&gt;()
        })
    }
    <b>else</b> <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&bytes) &gt; <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a> + <a href="consensus_key.md#0x1_consensus_key_BLS12381_G1_PUBLIC_KEY_NUM_BYTES">BLS12381_G1_PUBLIC_KEY_NUM_BYTES</a>){

        <b>let</b> ed_key_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_slice">vector::slice</a>(&bytes, 0, <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a>);
        <b>let</b> bls_key_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_slice">vector::slice</a>(&bytes, <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a>, <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a> + <a href="consensus_key.md#0x1_consensus_key_BLS12381_G1_PUBLIC_KEY_NUM_BYTES">BLS12381_G1_PUBLIC_KEY_NUM_BYTES</a>);
        <b>let</b> cg_key_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_slice">vector::slice</a>(&bytes, <a href="consensus_key.md#0x1_consensus_key_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a> + <a href="consensus_key.md#0x1_consensus_key_BLS12381_G1_PUBLIC_KEY_NUM_BYTES">BLS12381_G1_PUBLIC_KEY_NUM_BYTES</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&bytes));

        <b>let</b> valid_ed_public_key = <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_validated_public_key_from_bytes">ed25519::new_validated_public_key_from_bytes</a>(ed_key_bytes);
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&valid_ed_public_key), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="consensus_key.md#0x1_consensus_key_EINVALID_PUBLIC_KEY">EINVALID_PUBLIC_KEY</a>));

        <b>let</b> valid_bls_public_key = <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_public_key_from_bytes">bls12381::public_key_from_bytes</a>(bls_key_bytes);
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&valid_bls_public_key), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="consensus_key.md#0x1_consensus_key_EINVALID_PUBLIC_KEY">EINVALID_PUBLIC_KEY</a>));

        <b>let</b> valid_cg_public_key = <a href="class_groups.md#0x1_class_groups_public_key_from_bytes">class_groups::public_key_from_bytes</a>(cg_key_bytes);
        <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&valid_cg_public_key), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="consensus_key.md#0x1_consensus_key_EINVALID_PUBLIC_KEY">EINVALID_PUBLIC_KEY</a>));

        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a> {
            ed_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> valid_ed_public_key),
            bls_key: valid_bls_public_key,
            cg_key: valid_cg_public_key
        })

    }
    <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>&lt;<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a>&gt;()
    }
}
</code></pre>



</details>

<a id="0x1_consensus_key_public_key_to_bytes"></a>

## Function `public_key_to_bytes`



<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_public_key_to_bytes">public_key_to_bytes</a>(pk: <a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">consensus_key::ConsensusPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_public_key_to_bytes">public_key_to_bytes</a>(pk: <a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;{

    <b>let</b> out = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;u8&gt;();
    <b>let</b> ed_bytes  = <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_validated_public_key_to_bytes">ed25519::validated_public_key_to_bytes</a>(&pk.ed_key);
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> out, ed_bytes);

    <b>if</b>(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&pk.bls_key) && <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&pk.cg_key)){
        <b>let</b> bls_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> pk.bls_key);
        <b>let</b> bls_bytes = <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_public_key_to_bytes">bls12381::public_key_to_bytes</a>(&bls_key);
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> out, bls_bytes);

        <b>let</b> cg_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> pk.cg_key);
        <b>let</b> cg_bytes  = <a href="class_groups.md#0x1_class_groups_public_key_to_bytes">class_groups::public_key_to_bytes</a>(&cg_key);
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_append">vector::append</a>(&<b>mut</b> out, cg_bytes);
    };
    out
}
</code></pre>



</details>

<a id="0x1_consensus_key_get_bls_pub_key"></a>

## Function `get_bls_pub_key`



<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_get_bls_pub_key">get_bls_pub_key</a>(pk: &<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">consensus_key::ConsensusPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_get_bls_pub_key">get_bls_pub_key</a>(pk: &<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;{
    pk.bls_key
}
</code></pre>



</details>

<a id="0x1_consensus_key_get_ed_key"></a>

## Function `get_ed_key`



<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_get_ed_key">get_ed_key</a>(pk: &<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">consensus_key::ConsensusPublicKey</a>): <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_get_ed_key">get_ed_key</a>(pk: &<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a>): <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a>{
    pk.ed_key
}
</code></pre>



</details>

<a id="0x1_consensus_key_get_cg_key"></a>

## Function `get_cg_key`



<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_get_cg_key">get_cg_key</a>(pk: &<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">consensus_key::ConsensusPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="consensus_key.md#0x1_consensus_key_get_cg_key">get_cg_key</a>(pk: &<a href="consensus_key.md#0x1_consensus_key_ConsensusPublicKey">ConsensusPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>&gt;{
    pk.cg_key
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
