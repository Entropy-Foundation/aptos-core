
<a id="0x1_validator_public_keys"></a>

# Module `0x1::validator_public_keys`



-  [Struct `CertificateThresholdType`](#0x1_validator_public_keys_CertificateThresholdType)
-  [Struct `InternalPublicKeys`](#0x1_validator_public_keys_InternalPublicKeys)
-  [Struct `ValidatorPublicKeys`](#0x1_validator_public_keys_ValidatorPublicKeys)
-  [Constants](#@Constants_0)
-  [Function `validity_certificate_type`](#0x1_validator_public_keys_validity_certificate_type)
-  [Function `quorum_certificate_type`](#0x1_validator_public_keys_quorum_certificate_type)
-  [Function `unanimous_certificate_type`](#0x1_validator_public_keys_unanimous_certificate_type)
-  [Function `bcft_validity_certificate_type`](#0x1_validator_public_keys_bcft_validity_certificate_type)
-  [Function `bcft_quorum_certificate_type`](#0x1_validator_public_keys_bcft_quorum_certificate_type)
-  [Function `bcft_fallback_view_change_certificate_type`](#0x1_validator_public_keys_bcft_fallback_view_change_certificate_type)
-  [Function `clan_majority_certificate_type`](#0x1_validator_public_keys_clan_majority_certificate_type)
-  [Function `is_validity_certificate_type`](#0x1_validator_public_keys_is_validity_certificate_type)
-  [Function `is_quorum_certificate_type`](#0x1_validator_public_keys_is_quorum_certificate_type)
-  [Function `is_unanimous_certificate_type`](#0x1_validator_public_keys_is_unanimous_certificate_type)
-  [Function `is_bcft_validity_certificate_type`](#0x1_validator_public_keys_is_bcft_validity_certificate_type)
-  [Function `is_bcft_quorum_certificate_type`](#0x1_validator_public_keys_is_bcft_quorum_certificate_type)
-  [Function `is_bcft_fallback_view_change_certificate_type`](#0x1_validator_public_keys_is_bcft_fallback_view_change_certificate_type)
-  [Function `is_clan_majority_certificate_type`](#0x1_validator_public_keys_is_clan_majority_certificate_type)
-  [Function `validator_public_keys_from_bytes`](#0x1_validator_public_keys_validator_public_keys_from_bytes)
-  [Function `public_key_to_bytes`](#0x1_validator_public_keys_public_key_to_bytes)
-  [Function `get_network_key`](#0x1_validator_public_keys_get_network_key)
-  [Function `get_supra_bls_multi_sig_pub_key`](#0x1_validator_public_keys_get_supra_bls_multi_sig_pub_key)
-  [Function `get_supra_cg_key`](#0x1_validator_public_keys_get_supra_cg_key)
-  [Function `get_supra_ed_key`](#0x1_validator_public_keys_get_supra_ed_key)
-  [Function `replace_static_keys`](#0x1_validator_public_keys_replace_static_keys)
-  [Function `validate_static_keys`](#0x1_validator_public_keys_validate_static_keys)
-  [Function `is_valid_ed25519_key`](#0x1_validator_public_keys_is_valid_ed25519_key)
-  [Function `is_valid_bls12381_key`](#0x1_validator_public_keys_is_valid_bls12381_key)
-  [Function `is_valid_cg_key`](#0x1_validator_public_keys_is_valid_cg_key)
-  [Function `rotate_supra_bls_threshold_validity_key`](#0x1_validator_public_keys_rotate_supra_bls_threshold_validity_key)
-  [Function `rotate_supra_bls_threshold_quorum_key`](#0x1_validator_public_keys_rotate_supra_bls_threshold_quorum_key)
-  [Function `rotate_supra_bls_threshold_unanimous_key`](#0x1_validator_public_keys_rotate_supra_bls_threshold_unanimous_key)
-  [Function `rotate_supra_bls_threshold_bcft_validity_key`](#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_validity_key)
-  [Function `rotate_supra_bls_threshold_bcft_quorum_key`](#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_quorum_key)
-  [Function `rotate_supra_bls_threshold_bcft_fallback_view_change_key`](#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_fallback_view_change_key)
-  [Function `rotate_supra_bls_threshold_clan_majority_key`](#0x1_validator_public_keys_rotate_supra_bls_threshold_clan_majority_key)
-  [Function `rotate_supra_bls_threshold_key_by_type`](#0x1_validator_public_keys_rotate_supra_bls_threshold_key_by_type)


<pre><code><b>use</b> <a href="../../aptos-stdlib/doc/any.md#0x1_any">0x1::any</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381">0x1::bls12381</a>;
<b>use</b> <a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups">0x1::class_groups</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519">0x1::ed25519</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/type_info.md#0x1_type_info">0x1::type_info</a>;
</code></pre>



<a id="0x1_validator_public_keys_CertificateThresholdType"></a>

## Struct `CertificateThresholdType`

Internal tag wrapper


<pre><code><b>struct</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> <b>has</b> <b>copy</b>, drop, store
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

<a id="0x1_validator_public_keys_InternalPublicKeys"></a>

## Struct `InternalPublicKeys`

InternalPublicKeys consists of:
1. bls multisig key
2. bls threshold key shares for various certificate types
3. classgroup key
4. ed25519 key


<pre><code><b>struct</b> <a href="validator_public_keys.md#0x1_validator_public_keys_InternalPublicKeys">InternalPublicKeys</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>bls_multisig_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a></code>
</dt>
<dd>

</dd>
<dt>
<code>bls_threshold_validity_certificate_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls_threshold_quorum_certificate_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls_threshold_unanimous_certificate_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls_threshold_bcft_validity_certificate_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls_threshold_bcft_quorum_certificate_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls_threshold_bcft_fallback_view_change_certificate_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls_threshold_clan_majority_certificate_key: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>class_group_key: <a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a></code>
</dt>
<dd>

</dd>
<dt>
<code>ed25519_key: <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_validator_public_keys_ValidatorPublicKeys"></a>

## Struct `ValidatorPublicKeys`

ValidatorPublicKeys consists of:
1. network key
2. supra's internal keys


<pre><code><b>struct</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>network_key: <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a></code>
</dt>
<dd>

</dd>
<dt>
<code>supra_keys: <a href="validator_public_keys.md#0x1_validator_public_keys_InternalPublicKeys">validator_public_keys::InternalPublicKeys</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_validator_public_keys_BLS12381_G1_PUBLIC_KEY_NUM_BYTES"></a>

The size of a serialized bls12381 G1 public key, in bytes.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_BLS12381_G1_PUBLIC_KEY_NUM_BYTES">BLS12381_G1_PUBLIC_KEY_NUM_BYTES</a>: u64 = 48;
</code></pre>



<a id="0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE"></a>

The integer should match the Rust enum value representation in <code><a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a></code>.
n - f - c, given there are f Byzantine nodes and c crash-only nodes in the [Committee] with n >= 3f + 2c + 1 nodes.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE">CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE</a>: u8 = 5;
</code></pre>



<a id="0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM"></a>

The integer should match the Rust enum value representation in <code><a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a></code>
2f + c + 1, given there are f Byzantine nodes and c crash-only nodes in the [Committee] with n >= 3f + 2c + 1 nodes.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM">CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM</a>: u8 = 4;
</code></pre>



<a id="0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY"></a>

The integer should match the Rust enum value representation in <code><a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a></code>.
f+1, given there are f Byzantine nodes and c crash-only nodes in the [Committee] with n >= 3f + 2c + 1 nodes.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY</a>: u8 = 3;
</code></pre>



<a id="0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY"></a>

The integer should match the Rust enum value representation in <code><a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a></code>.
f+1, given there are f Byzantine nodes in the [Committee] with n >= 2f + 1 nodes.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY">CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY</a>: u8 = 6;
</code></pre>



<a id="0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_QUORUM"></a>

The integer should match the Rust enum value representation in <code><a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a></code>.
2f+1, given there are f Byzantine nodes in the [Committee] and n >= 3f + 1 nodes in total.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_QUORUM">CERTIFICATE_THRESHOLD_TYPE_QUORUM</a>: u8 = 1;
</code></pre>



<a id="0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS"></a>

The integer should match the Rust enum value representation in <code><a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a></code>.
n, where n is the total number of nodes in the [Committee].


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS">CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS</a>: u8 = 2;
</code></pre>



<a id="0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_VALIDITY"></a>

The integer should match the Rust enum value representation in <code><a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a></code>.
f+1, given there are f Byzantine nodes in the [Committee].


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_VALIDITY</a>: u8 = 0;
</code></pre>



<a id="0x1_validator_public_keys_ED25519_PUBLIC_KEY_NUM_BYTES"></a>

The size of a serialized ed25519 public key, in bytes.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ED25519_PUBLIC_KEY_NUM_BYTES">ED25519_PUBLIC_KEY_NUM_BYTES</a>: u64 = 32;
</code></pre>



<a id="0x1_validator_public_keys_EUNKNOWN_THRESHOLD_TYPE"></a>

Error: Unknown certificate threshold type.


<pre><code><b>const</b> <a href="validator_public_keys.md#0x1_validator_public_keys_EUNKNOWN_THRESHOLD_TYPE">EUNKNOWN_THRESHOLD_TYPE</a>: u64 = 1;
</code></pre>



<a id="0x1_validator_public_keys_validity_certificate_type"></a>

## Function `validity_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_validity_certificate_type">validity_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_validity_certificate_type">validity_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
    <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> { tag: <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_VALIDITY</a> }
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_quorum_certificate_type"></a>

## Function `quorum_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_quorum_certificate_type">quorum_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_quorum_certificate_type">quorum_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
    <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> { tag: <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_QUORUM">CERTIFICATE_THRESHOLD_TYPE_QUORUM</a> }
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_unanimous_certificate_type"></a>

## Function `unanimous_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_unanimous_certificate_type">unanimous_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_unanimous_certificate_type">unanimous_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
    <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> { tag: <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS">CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS</a> }
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_bcft_validity_certificate_type"></a>

## Function `bcft_validity_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_bcft_validity_certificate_type">bcft_validity_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_bcft_validity_certificate_type">bcft_validity_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
    <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> { tag: <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY</a> }
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_bcft_quorum_certificate_type"></a>

## Function `bcft_quorum_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_bcft_quorum_certificate_type">bcft_quorum_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_bcft_quorum_certificate_type">bcft_quorum_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
    <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> { tag: <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM">CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM</a> }
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_bcft_fallback_view_change_certificate_type"></a>

## Function `bcft_fallback_view_change_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_bcft_fallback_view_change_certificate_type">bcft_fallback_view_change_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_bcft_fallback_view_change_certificate_type">bcft_fallback_view_change_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
    <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
        tag: <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE">CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE</a>
    }
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_clan_majority_certificate_type"></a>

## Function `clan_majority_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_clan_majority_certificate_type">clan_majority_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_clan_majority_certificate_type">clan_majority_certificate_type</a>(): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> {
    <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a> { tag: <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY">CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY</a> }
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_validity_certificate_type"></a>

## Function `is_validity_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_validity_certificate_type">is_validity_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_validity_certificate_type">is_validity_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a>): bool {
    t.tag == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_VALIDITY</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_quorum_certificate_type"></a>

## Function `is_quorum_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_quorum_certificate_type">is_quorum_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_quorum_certificate_type">is_quorum_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a>): bool {
    t.tag == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_QUORUM">CERTIFICATE_THRESHOLD_TYPE_QUORUM</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_unanimous_certificate_type"></a>

## Function `is_unanimous_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_unanimous_certificate_type">is_unanimous_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_unanimous_certificate_type">is_unanimous_certificate_type</a>(
    t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a>
): bool {
    t.tag == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS">CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_bcft_validity_certificate_type"></a>

## Function `is_bcft_validity_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_bcft_validity_certificate_type">is_bcft_validity_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_bcft_validity_certificate_type">is_bcft_validity_certificate_type</a>(
    t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a>
): bool {
    t.tag == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_bcft_quorum_certificate_type"></a>

## Function `is_bcft_quorum_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_bcft_quorum_certificate_type">is_bcft_quorum_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_bcft_quorum_certificate_type">is_bcft_quorum_certificate_type</a>(
    t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a>
): bool {
    t.tag == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM">CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_bcft_fallback_view_change_certificate_type"></a>

## Function `is_bcft_fallback_view_change_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_bcft_fallback_view_change_certificate_type">is_bcft_fallback_view_change_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_bcft_fallback_view_change_certificate_type">is_bcft_fallback_view_change_certificate_type</a>(
    t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a>
): bool {
    t.tag == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE">CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_clan_majority_certificate_type"></a>

## Function `is_clan_majority_certificate_type`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_clan_majority_certificate_type">is_clan_majority_certificate_type</a>(t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_clan_majority_certificate_type">is_clan_majority_certificate_type</a>(
    t: &<a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">CertificateThresholdType</a>
): bool {
    t.tag == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY">CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_validator_public_keys_from_bytes"></a>

## Function `validator_public_keys_from_bytes`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_validator_public_keys_from_bytes">validator_public_keys_from_bytes</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_validator_public_keys_from_bytes">validator_public_keys_from_bytes</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a> {
    // <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">bcs</a> deserialization
    <b>let</b> bytes_serialized =
        <a href="../../aptos-stdlib/doc/any.md#0x1_any_new">any::new</a>(<a href="../../aptos-stdlib/doc/type_info.md#0x1_type_info_type_name">type_info::type_name</a>&lt;<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>&gt;(), bytes);
    <b>let</b> <a href="validator_public_keys.md#0x1_validator_public_keys">validator_public_keys</a> = <a href="../../aptos-stdlib/doc/any.md#0x1_any_unpack">any::unpack</a>&lt;<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>&gt;(bytes_serialized);
    <a href="validator_public_keys.md#0x1_validator_public_keys">validator_public_keys</a>
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_public_key_to_bytes"></a>

## Function `public_key_to_bytes`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_public_key_to_bytes">public_key_to_bytes</a>(pk: <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_public_key_to_bytes">public_key_to_bytes</a>(pk: <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    // <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">bcs</a> deserialization
    <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>&lt;<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>&gt;(&pk)
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_get_network_key"></a>

## Function `get_network_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_network_key">get_network_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_network_key">get_network_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a> {
    pk.network_key
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_get_supra_bls_multi_sig_pub_key"></a>

## Function `get_supra_bls_multi_sig_pub_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_supra_bls_multi_sig_pub_key">get_supra_bls_multi_sig_pub_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_supra_bls_multi_sig_pub_key">get_supra_bls_multi_sig_pub_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a> {
    pk.supra_keys.bls_multisig_key
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_get_supra_cg_key"></a>

## Function `get_supra_cg_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_supra_cg_key">get_supra_cg_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>): <a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_supra_cg_key">get_supra_cg_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>): <a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a> {
    pk.supra_keys.class_group_key
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_get_supra_ed_key"></a>

## Function `get_supra_ed_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_supra_ed_key">get_supra_ed_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_get_supra_ed_key">get_supra_ed_key</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>): <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a> {
    pk.supra_keys.ed25519_key
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_replace_static_keys"></a>

## Function `replace_static_keys`

Overwrites the four static keys of <code>target</code> (network_key, bls_multisig_key, class_group_key,
ed25519_key) with those from <code>source</code>, leaving the DKG-managed BLS threshold key fields of
<code>target</code> untouched. Used by <code><a href="stake.md#0x1_stake_rotate_consensus_key">stake::rotate_consensus_key</a></code> so that an operator key rotation
only changes the static keys and cannot clobber the threshold keys written by the DKG via
<code><a href="stake.md#0x1_stake_set_dkg_output_keys">stake::set_dkg_output_keys</a></code>.


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_replace_static_keys">replace_static_keys</a>(target: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, source: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_replace_static_keys">replace_static_keys</a>(
    target: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, source: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>
) {
    target.network_key = source.network_key;
    target.supra_keys.bls_multisig_key = source.supra_keys.bls_multisig_key;
    target.supra_keys.class_group_key = source.supra_keys.class_group_key;
    target.supra_keys.ed25519_key = source.supra_keys.ed25519_key;
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_validate_static_keys"></a>

## Function `validate_static_keys`

Returns true iff the four static (non-DKG) public keys decode to cryptographically valid
keys: the network key, the BLS multisig key, the class-group key and the ed25519 key.

<code>validator_public_keys_from_bytes</code> reconstructs each key's raw bytes via BCS without
running the per-key validation natives, so a registration blob can carry malformed keys
(the <code>Validated*</code>/<code>PublicKey</code> types are a misnomer after deserialization). This re-runs
each key's validating constructor on the recovered bytes to reject them.

The DKG-managed BLS threshold key shares are intentionally not checked: they are absent at
registration and are produced/overwritten by the protocol via <code><a href="stake.md#0x1_stake_set_dkg_output_keys">stake::set_dkg_output_keys</a></code>
(which validates them). Proof-of-possession is not verified here either (no PoP is supplied
at registration); only key well-formedness / subgroup membership is checked.


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_validate_static_keys">validate_static_keys</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_validate_static_keys">validate_static_keys</a>(pk: &<a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>): bool {
    <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_ed25519_key">is_valid_ed25519_key</a>(&pk.network_key)
        && <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_bls12381_key">is_valid_bls12381_key</a>(&pk.supra_keys.bls_multisig_key)
        && <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_cg_key">is_valid_cg_key</a>(&pk.supra_keys.class_group_key)
        && <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_ed25519_key">is_valid_ed25519_key</a>(&pk.supra_keys.ed25519_key)
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_valid_ed25519_key"></a>

## Function `is_valid_ed25519_key`



<pre><code><b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_ed25519_key">is_valid_ed25519_key</a>(pk: &<a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_ed25519_key">is_valid_ed25519_key</a>(pk: &<a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_ValidatedPublicKey">ed25519::ValidatedPublicKey</a>): bool {
    <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(
        &<a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_validated_public_key_from_bytes">ed25519::new_validated_public_key_from_bytes</a>(
            <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_validated_public_key_to_bytes">ed25519::validated_public_key_to_bytes</a>(pk)
        )
    )
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_valid_bls12381_key"></a>

## Function `is_valid_bls12381_key`



<pre><code><b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_bls12381_key">is_valid_bls12381_key</a>(pk: &<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_bls12381_key">is_valid_bls12381_key</a>(pk: &<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>): bool {
    <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(
        &<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_public_key_from_bytes">bls12381::public_key_from_bytes</a>(<a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_public_key_to_bytes">bls12381::public_key_to_bytes</a>(pk))
    )
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_is_valid_cg_key"></a>

## Function `is_valid_cg_key`



<pre><code><b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_cg_key">is_valid_cg_key</a>(pk: &<a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_is_valid_cg_key">is_valid_cg_key</a>(pk: &<a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups_CGPublicKey">class_groups::CGPublicKey</a>): bool {
    <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(
        &<a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups_public_key_from_bytes">class_groups::public_key_from_bytes</a>(<a href="../../supra-stdlib/doc/class_groups.md#0x1_class_groups_public_key_to_bytes">class_groups::public_key_to_bytes</a>(pk))
    )
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_validity_key"></a>

## Function `rotate_supra_bls_threshold_validity_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_validity_key">rotate_supra_bls_threshold_validity_key</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, new_bls_threshold_validity_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_validity_key">rotate_supra_bls_threshold_validity_key</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, new_bls_threshold_validity_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    pk.supra_keys.bls_threshold_validity_certificate_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(
        new_bls_threshold_validity_key
    );
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_quorum_key"></a>

## Function `rotate_supra_bls_threshold_quorum_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_quorum_key">rotate_supra_bls_threshold_quorum_key</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, new_bls_threshold_quorum_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_quorum_key">rotate_supra_bls_threshold_quorum_key</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, new_bls_threshold_quorum_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    pk.supra_keys.bls_threshold_quorum_certificate_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(
        new_bls_threshold_quorum_key
    );
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_unanimous_key"></a>

## Function `rotate_supra_bls_threshold_unanimous_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_unanimous_key">rotate_supra_bls_threshold_unanimous_key</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_unanimous_key">rotate_supra_bls_threshold_unanimous_key</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    pk.supra_keys.bls_threshold_unanimous_certificate_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(new_key);
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_validity_key"></a>

## Function `rotate_supra_bls_threshold_bcft_validity_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_validity_key">rotate_supra_bls_threshold_bcft_validity_key</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_validity_key">rotate_supra_bls_threshold_bcft_validity_key</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    pk.supra_keys.bls_threshold_bcft_validity_certificate_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(new_key);
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_quorum_key"></a>

## Function `rotate_supra_bls_threshold_bcft_quorum_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_quorum_key">rotate_supra_bls_threshold_bcft_quorum_key</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_quorum_key">rotate_supra_bls_threshold_bcft_quorum_key</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    pk.supra_keys.bls_threshold_bcft_quorum_certificate_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(new_key);
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_fallback_view_change_key"></a>

## Function `rotate_supra_bls_threshold_bcft_fallback_view_change_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_fallback_view_change_key">rotate_supra_bls_threshold_bcft_fallback_view_change_key</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_fallback_view_change_key">rotate_supra_bls_threshold_bcft_fallback_view_change_key</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    pk.supra_keys.bls_threshold_bcft_fallback_view_change_certificate_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(
        new_key
    );
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_clan_majority_key"></a>

## Function `rotate_supra_bls_threshold_clan_majority_key`



<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_clan_majority_key">rotate_supra_bls_threshold_clan_majority_key</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_clan_majority_key">rotate_supra_bls_threshold_clan_majority_key</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    pk.supra_keys.bls_threshold_clan_majority_certificate_key = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(new_key);
}
</code></pre>



</details>

<a id="0x1_validator_public_keys_rotate_supra_bls_threshold_key_by_type"></a>

## Function `rotate_supra_bls_threshold_key_by_type`

Rotate a threshold key based on the threshold type tag.
threshold_type: 0=validity, 1=quorum, 2=unanimous, 3=bcft_validity, 4=bcft_quorum, 5=bcft_fallback_view_change, 6=clan_majority


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_key_by_type">rotate_supra_bls_threshold_key_by_type</a>(pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">validator_public_keys::ValidatorPublicKeys</a>, threshold_type: u8, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_key_by_type">rotate_supra_bls_threshold_key_by_type</a>(
    pk: &<b>mut</b> <a href="validator_public_keys.md#0x1_validator_public_keys_ValidatorPublicKeys">ValidatorPublicKeys</a>, threshold_type: u8, new_key: <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_PublicKey">bls12381::PublicKey</a>
) {
    <b>if</b> (threshold_type == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_VALIDITY</a>) {
        <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_validity_key">rotate_supra_bls_threshold_validity_key</a>(pk, new_key);
    } <b>else</b> <b>if</b> (threshold_type == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_QUORUM">CERTIFICATE_THRESHOLD_TYPE_QUORUM</a>) {
        <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_quorum_key">rotate_supra_bls_threshold_quorum_key</a>(pk, new_key);
    } <b>else</b> <b>if</b> (threshold_type == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS">CERTIFICATE_THRESHOLD_TYPE_UNANIMOUS</a>) {
        <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_unanimous_key">rotate_supra_bls_threshold_unanimous_key</a>(pk, new_key);
    } <b>else</b> <b>if</b> (threshold_type == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY">CERTIFICATE_THRESHOLD_TYPE_BCFT_VALIDITY</a>) {
        <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_validity_key">rotate_supra_bls_threshold_bcft_validity_key</a>(pk, new_key);
    } <b>else</b> <b>if</b> (threshold_type == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM">CERTIFICATE_THRESHOLD_TYPE_BCFT_QUORUM</a>) {
        <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_quorum_key">rotate_supra_bls_threshold_bcft_quorum_key</a>(pk, new_key);
    } <b>else</b> <b>if</b> (threshold_type
        == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE">CERTIFICATE_THRESHOLD_TYPE_BCFT_FALLBACK_VIEW_CHANGE</a>) {
        <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_bcft_fallback_view_change_key">rotate_supra_bls_threshold_bcft_fallback_view_change_key</a>(pk, new_key);
    } <b>else</b> <b>if</b> (threshold_type == <a href="validator_public_keys.md#0x1_validator_public_keys_CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY">CERTIFICATE_THRESHOLD_TYPE_CLAN_MAJORITY</a>) {
        <a href="validator_public_keys.md#0x1_validator_public_keys_rotate_supra_bls_threshold_clan_majority_key">rotate_supra_bls_threshold_clan_majority_key</a>(pk, new_key);
    } <b>else</b> {
        <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="validator_public_keys.md#0x1_validator_public_keys_EUNKNOWN_THRESHOLD_TYPE">EUNKNOWN_THRESHOLD_TYPE</a>)
    };
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
