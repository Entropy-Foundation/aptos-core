
<a id="0x1_rlp"></a>

# Module `0x1::rlp`



-  [Constants](#@Constants_0)
-  [Function `encode`](#0x1_rlp_encode)
-  [Function `decode`](#0x1_rlp_decode)
-  [Function `encode_list_scalar`](#0x1_rlp_encode_list_scalar)
-  [Function `decode_list_scalar`](#0x1_rlp_decode_list_scalar)
-  [Function `encode_list_byte_array`](#0x1_rlp_encode_list_byte_array)
-  [Function `deserialize_vec_vec_u8`](#0x1_rlp_deserialize_vec_vec_u8)
-  [Function `read_u32`](#0x1_rlp_read_u32)
-  [Function `decode_list_byte_array`](#0x1_rlp_decode_list_byte_array)
-  [Function `native_rlp_encode`](#0x1_rlp_native_rlp_encode)
-  [Function `native_rlp_decode`](#0x1_rlp_native_rlp_decode)
-  [Function `native_rlp_encode_list_scalar`](#0x1_rlp_native_rlp_encode_list_scalar)
-  [Function `native_rlp_decode_list_scalar`](#0x1_rlp_native_rlp_decode_list_scalar)
-  [Function `native_rlp_encode_list_byte_array`](#0x1_rlp_native_rlp_encode_list_byte_array)
-  [Function `native_rlp_decode_list_byte_array`](#0x1_rlp_native_rlp_decode_list_byte_array)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features">0x1::features</a>;
</code></pre>



<a id="@Constants_0"></a>

## Constants


<a id="0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED"></a>

SUPRA_RLP_ENCODE feature APIs are disabled.


<pre><code><b>const</b> <a href="rlp.md#0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED">ERLP_ENCODE_FEATURE_DISABLED</a>: u64 = 1;
</code></pre>



<a id="0x1_rlp_encode"></a>

## Function `encode`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode">encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode">encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_supra_rlp_enabled">features::supra_rlp_enabled</a>(), <a href="rlp.md#0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED">ERLP_ENCODE_FEATURE_DISABLED</a>);
    <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>(x)
}
</code></pre>



</details>

<a id="0x1_rlp_decode"></a>

## Function `decode`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode">decode</a>&lt;T&gt;(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): T
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode">decode</a>&lt;T&gt;(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): T {
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_supra_rlp_enabled">features::supra_rlp_enabled</a>(), <a href="rlp.md#0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED">ERLP_ENCODE_FEATURE_DISABLED</a>);
    <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp)
}
</code></pre>



</details>

<a id="0x1_rlp_encode_list_scalar"></a>

## Function `encode_list_scalar`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_list_scalar">encode_list_scalar</a>&lt;T: drop&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_list_scalar">encode_list_scalar</a>&lt;T: drop&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_supra_rlp_enabled">features::supra_rlp_enabled</a>(), <a href="rlp.md#0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED">ERLP_ENCODE_FEATURE_DISABLED</a>);
    <a href="rlp.md#0x1_rlp_native_rlp_encode_list_scalar">native_rlp_encode_list_scalar</a>&lt;T&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&data))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_list_scalar"></a>

## Function `decode_list_scalar`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_list_scalar">decode_list_scalar</a>&lt;T&gt;(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_list_scalar">decode_list_scalar</a>&lt;T&gt;(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt; {
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_supra_rlp_enabled">features::supra_rlp_enabled</a>(), <a href="rlp.md#0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED">ERLP_ENCODE_FEATURE_DISABLED</a>);
    <a href="rlp.md#0x1_rlp_native_rlp_decode_list_scalar">native_rlp_decode_list_scalar</a>&lt;T&gt;(encoded_rlp)
}
</code></pre>



</details>

<a id="0x1_rlp_encode_list_byte_array"></a>

## Function `encode_list_byte_array`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_list_byte_array">encode_list_byte_array</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_list_byte_array">encode_list_byte_array</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_supra_rlp_enabled">features::supra_rlp_enabled</a>(), <a href="rlp.md#0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED">ERLP_ENCODE_FEATURE_DISABLED</a>);
    <a href="rlp.md#0x1_rlp_native_rlp_encode_list_byte_array">native_rlp_encode_list_byte_array</a>(<a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&data))
}
</code></pre>



</details>

<a id="0x1_rlp_deserialize_vec_vec_u8"></a>

## Function `deserialize_vec_vec_u8`

Helper function for deserializing output of native_rlp_decode_list_byte_array
Deserializes a vector<u8> into a vector<vector<u8>>.
Format: [len1 (u32), data1, len2 (u32), data2, ...]


<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_deserialize_vec_vec_u8">deserialize_vec_vec_u8</a>(serialized: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_deserialize_vec_vec_u8">deserialize_vec_vec_u8</a>(serialized: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt; {
    <b>let</b> result = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;();
    <b>let</b> i:u64 = 0;
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&serialized);

    <b>while</b> (i &lt; len) {
        // Read the next 4 bytes <b>as</b> the length of the inner <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>
        <b>let</b> len_inner = <a href="rlp.md#0x1_rlp_read_u32">read_u32</a>(&serialized, i);
        i = i + 4;

        // Extract the next len_inner bytes <b>as</b> the inner <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>
        <b>let</b> inner_vec = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;u8&gt;();
        <b>let</b> j = 0;
        <b>while</b> (j &lt; len_inner) {
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> inner_vec, *<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&serialized, i + (j <b>as</b> u64)));
            j = j + 1;
        };
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> result, inner_vec);
        i = i + (len_inner <b>as</b> u64);
    };
    result
}
</code></pre>



</details>

<a id="0x1_rlp_read_u32"></a>

## Function `read_u32`

Reads a u32 from a vector<u8> at position i in little-endian order.


<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_read_u32">read_u32</a>(data: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, i: u64): u32
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_read_u32">read_u32</a>(data: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, i: u64): u32 {
    <b>let</b> b0 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i) <b>as</b> u32);
    <b>let</b> b1 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i + 1) <b>as</b> u32);
    <b>let</b> b2 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i + 2) <b>as</b> u32);
    <b>let</b> b3 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i + 3) <b>as</b> u32);
    b0 | (b1 &lt;&lt; 8) | (b2 &lt;&lt; 16) | (b3 &lt;&lt; 24)
}
</code></pre>



</details>

<a id="0x1_rlp_decode_list_byte_array"></a>

## Function `decode_list_byte_array`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_list_byte_array">decode_list_byte_array</a>(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_list_byte_array">decode_list_byte_array</a>(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt; {
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_supra_rlp_enabled">features::supra_rlp_enabled</a>(), <a href="rlp.md#0x1_rlp_ERLP_ENCODE_FEATURE_DISABLED">ERLP_ENCODE_FEATURE_DISABLED</a>);
    <b>let</b> ser_result = <a href="rlp.md#0x1_rlp_native_rlp_decode_list_byte_array">native_rlp_decode_list_byte_array</a>(encoded_rlp);
    <a href="rlp.md#0x1_rlp_deserialize_vec_vec_u8">deserialize_vec_vec_u8</a>(ser_result)
}
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_encode"></a>

## Function `native_rlp_encode`



<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_decode"></a>

## Function `native_rlp_decode`



<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): T
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): T;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_encode_list_scalar"></a>

## Function `native_rlp_encode_list_scalar`



<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode_list_scalar">native_rlp_encode_list_scalar</a>&lt;T&gt;(x: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode_list_scalar">native_rlp_encode_list_scalar</a>&lt;T&gt;(x: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_decode_list_scalar"></a>

## Function `native_rlp_decode_list_scalar`



<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode_list_scalar">native_rlp_decode_list_scalar</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode_list_scalar">native_rlp_decode_list_scalar</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_encode_list_byte_array"></a>

## Function `native_rlp_encode_list_byte_array`



<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode_list_byte_array">native_rlp_encode_list_byte_array</a>(x: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode_list_byte_array">native_rlp_encode_list_byte_array</a>(x: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_decode_list_byte_array"></a>

## Function `native_rlp_decode_list_byte_array`



<pre><code><b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode_list_byte_array">native_rlp_decode_list_byte_array</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode_list_byte_array">native_rlp_decode_list_byte_array</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
