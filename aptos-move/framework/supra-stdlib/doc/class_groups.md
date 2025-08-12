
<a id="0x1_class_groups"></a>

# Module `0x1::class_groups`



-  [Struct `CGPublicKey`](#0x1_class_groups_CGPublicKey)
-  [Function `public_key_from_bytes`](#0x1_class_groups_public_key_from_bytes)
-  [Function `public_key_to_bytes`](#0x1_class_groups_public_key_to_bytes)
-  [Function `validate_pubkey_internal`](#0x1_class_groups_validate_pubkey_internal)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
</code></pre>



<a id="0x1_class_groups_CGPublicKey"></a>

## Struct `CGPublicKey`



<pre><code><b>struct</b> <a href="class_groups.md#0x1_class_groups_CGPublicKey">CGPublicKey</a> <b>has</b> <b>copy</b>, drop, store
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

<a id="0x1_class_groups_public_key_from_bytes"></a>

## Function `public_key_from_bytes`

Creates a new public key from a sequence of bytes.


<pre><code><b>public</b> <b>fun</b> <a href="class_groups.md#0x1_class_groups_public_key_from_bytes">public_key_from_bytes</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="class_groups.md#0x1_class_groups_public_key_from_bytes">public_key_from_bytes</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="class_groups.md#0x1_class_groups_CGPublicKey">CGPublicKey</a>&gt; {
    <b>if</b> (<a href="class_groups.md#0x1_class_groups_validate_pubkey_internal">validate_pubkey_internal</a>(bytes)) {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(<a href="class_groups.md#0x1_class_groups_CGPublicKey">CGPublicKey</a> {
            bytes
        })
    } <b>else</b> {
        <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>&lt;<a href="class_groups.md#0x1_class_groups_CGPublicKey">CGPublicKey</a>&gt;()
    }
}
</code></pre>



</details>

<a id="0x1_class_groups_public_key_to_bytes"></a>

## Function `public_key_to_bytes`

Serializes a public key to a sequence of bytes.


<pre><code><b>public</b> <b>fun</b> <a href="class_groups.md#0x1_class_groups_public_key_to_bytes">public_key_to_bytes</a>(pk: &<a href="class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="class_groups.md#0x1_class_groups_public_key_to_bytes">public_key_to_bytes</a>(pk: &<a href="class_groups.md#0x1_class_groups_CGPublicKey">CGPublicKey</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    pk.bytes
}
</code></pre>



</details>

<a id="0x1_class_groups_validate_pubkey_internal"></a>

## Function `validate_pubkey_internal`



<pre><code><b>fun</b> <a href="class_groups.md#0x1_class_groups_validate_pubkey_internal">validate_pubkey_internal</a>(public_key: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="class_groups.md#0x1_class_groups_validate_pubkey_internal">validate_pubkey_internal</a>(public_key: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool;
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
