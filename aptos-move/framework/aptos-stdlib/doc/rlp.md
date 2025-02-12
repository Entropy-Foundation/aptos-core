
<a id="0x1_rlp"></a>

# Module `0x1::rlp`



-  [Function `encode_bool`](#0x1_rlp_encode_bool)
-  [Function `decode_bool`](#0x1_rlp_decode_bool)
-  [Function `encode_u8`](#0x1_rlp_encode_u8)
-  [Function `decode_u8`](#0x1_rlp_decode_u8)
-  [Function `encode_u16`](#0x1_rlp_encode_u16)
-  [Function `decode_u16`](#0x1_rlp_decode_u16)
-  [Function `encode_u32`](#0x1_rlp_encode_u32)
-  [Function `decode_u32`](#0x1_rlp_decode_u32)
-  [Function `encode_u64`](#0x1_rlp_encode_u64)
-  [Function `decode_u64`](#0x1_rlp_decode_u64)
-  [Function `encode_u128`](#0x1_rlp_encode_u128)
-  [Function `decode_u128`](#0x1_rlp_decode_u128)
-  [Function `encode_u256`](#0x1_rlp_encode_u256)
-  [Function `decode_u256`](#0x1_rlp_decode_u256)
-  [Function `encode_address`](#0x1_rlp_encode_address)
-  [Function `decode_address`](#0x1_rlp_decode_address)
-  [Function `encode_bytes`](#0x1_rlp_encode_bytes)
-  [Function `decode_bytes`](#0x1_rlp_decode_bytes)
-  [Function `encode_string`](#0x1_rlp_encode_string)
-  [Function `decode_string`](#0x1_rlp_decode_string)
-  [Function `native_rlp_encode`](#0x1_rlp_native_rlp_encode)
-  [Function `native_rlp_decode`](#0x1_rlp_native_rlp_decode)


<pre><code><b>use</b> <a href="../../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="from_bcs.md#0x1_from_bcs">0x1::from_bcs</a>;
<b>use</b> <a href="../../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
</code></pre>



<a id="0x1_rlp_encode_bool"></a>

## Function `encode_bool`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_bool">encode_bool</a>(x: bool): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_bool">encode_bool</a>(x: bool): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&x))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_bool"></a>

## Function `decode_bool`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_bool">decode_bool</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_bool">decode_bool</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): bool {
    <a href="from_bcs.md#0x1_from_bcs_to_bool">from_bcs::to_bool</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_u8"></a>

## Function `encode_u8`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u8">encode_u8</a>(x: u8): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u8">encode_u8</a>(x: u8): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&x))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_u8"></a>

## Function `decode_u8`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u8">decode_u8</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u8">decode_u8</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u8 {
    <a href="from_bcs.md#0x1_from_bcs_to_u8">from_bcs::to_u8</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_u16"></a>

## Function `encode_u16`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u16">encode_u16</a>(x: u16): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u16">encode_u16</a>(x: u16): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&x))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_u16"></a>

## Function `decode_u16`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u16">decode_u16</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u16
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u16">decode_u16</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u16 {
    <a href="from_bcs.md#0x1_from_bcs_to_u16">from_bcs::to_u16</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_u32"></a>

## Function `encode_u32`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u32">encode_u32</a>(x: u32): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u32">encode_u32</a>(x: u32): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&x))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_u32"></a>

## Function `decode_u32`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u32">decode_u32</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u32
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u32">decode_u32</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u32 {
    <a href="from_bcs.md#0x1_from_bcs_to_u32">from_bcs::to_u32</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_u64"></a>

## Function `encode_u64`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u64">encode_u64</a>(x: u64): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u64">encode_u64</a>(x: u64): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&x))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_u64"></a>

## Function `decode_u64`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u64">decode_u64</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u64">decode_u64</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u64 {
    <a href="from_bcs.md#0x1_from_bcs_to_u64">from_bcs::to_u64</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_u128"></a>

## Function `encode_u128`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u128">encode_u128</a>(x: u128): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u128">encode_u128</a>(x: u128): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&x))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_u128"></a>

## Function `decode_u128`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u128">decode_u128</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u128
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u128">decode_u128</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u128 {
    <a href="from_bcs.md#0x1_from_bcs_to_u128">from_bcs::to_u128</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_u256"></a>

## Function `encode_u256`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u256">encode_u256</a>(x: u256): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_u256">encode_u256</a>(x: u256): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&x))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_u256"></a>

## Function `decode_u256`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u256">decode_u256</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u256
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_u256">decode_u256</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): u256 {
    <a href="from_bcs.md#0x1_from_bcs_to_u256">from_bcs::to_u256</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_address"></a>

## Function `encode_address`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_address">encode_address</a>(addr: <b>address</b>): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_address">encode_address</a>(addr: <b>address</b>): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&addr))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_address"></a>

## Function `decode_address`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_address">decode_address</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_address">decode_address</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <b>address</b> {
    <a href="from_bcs.md#0x1_from_bcs_to_address">from_bcs::to_address</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_encode_bytes"></a>

## Function `encode_bytes`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_bytes">encode_bytes</a>(data: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_bytes">encode_bytes</a>(data: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(data)
}
</code></pre>



</details>

<a id="0x1_rlp_decode_bytes"></a>

## Function `decode_bytes`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_bytes">decode_bytes</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_bytes">decode_bytes</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp)
}
</code></pre>



</details>

<a id="0x1_rlp_encode_string"></a>

## Function `encode_string`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_string">encode_string</a>(s: &<a href="../../move-stdlib/doc/string.md#0x1_string_String">string::String</a>): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_string">encode_string</a>(s: &std::string::String): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(<a href="../../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(s))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_string"></a>

## Function `decode_string`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_string">decode_string</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../move-stdlib/doc/string.md#0x1_string_String">string::String</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_string">decode_string</a>(encoded_rlp: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): std::string::String {
    <a href="from_bcs.md#0x1_from_bcs_to_string">from_bcs::to_string</a>(<a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp))
}
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_encode"></a>

## Function `native_rlp_encode`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(data: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(
    data: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_decode"></a>

## Function `native_rlp_decode`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_data: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(
    encoded_data: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
): <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
