
<a id="0x1_vec_utils"></a>

# Module `0x1::vec_utils`



-  [Constants](#@Constants_0)
-  [Function `flatten_nested_vec_to_vec`](#0x1_vec_utils_flatten_nested_vec_to_vec)
-  [Function `read_u32`](#0x1_vec_utils_read_u32)
-  [Function `unflatten_vec_to_nested_vec`](#0x1_vec_utils_unflatten_vec_to_nested_vec)
-  [Function `native_flatten_nested_vec_to_vec`](#0x1_vec_utils_native_flatten_nested_vec_to_vec)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features">0x1::features</a>;
</code></pre>



<a id="@Constants_0"></a>

## Constants


<a id="0x1_vec_utils_EVEC_UTILS_FEATURE_DISABLED"></a>

VEC_UTILS feature APIs are disabled.


<pre><code><b>const</b> <a href="vec_utils.md#0x1_vec_utils_EVEC_UTILS_FEATURE_DISABLED">EVEC_UTILS_FEATURE_DISABLED</a>: u64 = 1;
</code></pre>



<a id="0x1_vec_utils_flatten_nested_vec_to_vec"></a>

## Function `flatten_nested_vec_to_vec`

Function for serializing a vector<vector<u8>> into a vector<u8>.
Serializes data to the format: [(length1 || data1), (length2 || data2), ...]
Assumes each length is a u32 in little-endian order.


<pre><code><b>public</b> <b>fun</b> <a href="vec_utils.md#0x1_vec_utils_flatten_nested_vec_to_vec">flatten_nested_vec_to_vec</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="vec_utils.md#0x1_vec_utils_flatten_nested_vec_to_vec">flatten_nested_vec_to_vec</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;{
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_supra_vec_utils_enabled">features::supra_vec_utils_enabled</a>(), <a href="vec_utils.md#0x1_vec_utils_EVEC_UTILS_FEATURE_DISABLED">EVEC_UTILS_FEATURE_DISABLED</a>);
    <b>let</b> result = <a href="vec_utils.md#0x1_vec_utils_native_flatten_nested_vec_to_vec">native_flatten_nested_vec_to_vec</a>(data);
    result
}
</code></pre>



</details>

<a id="0x1_vec_utils_read_u32"></a>

## Function `read_u32`

Reads a u32 from a vector<u8> at position i in little-endian order.


<pre><code><b>fun</b> <a href="vec_utils.md#0x1_vec_utils_read_u32">read_u32</a>(data: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, i: u64): u32
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="vec_utils.md#0x1_vec_utils_read_u32">read_u32</a>(data: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, i: u64): u32 {
    <b>let</b> b0 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i) <b>as</b> u32);
    <b>let</b> b1 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i + 1) <b>as</b> u32);
    <b>let</b> b2 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i + 2) <b>as</b> u32);
    <b>let</b> b3 = (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(data, i + 3) <b>as</b> u32);
    b0 | (b1 &lt;&lt; 8) | (b2 &lt;&lt; 16) | (b3 &lt;&lt; 24)
}
</code></pre>



</details>

<a id="0x1_vec_utils_unflatten_vec_to_nested_vec"></a>

## Function `unflatten_vec_to_nested_vec`

Function for deserializing a vector<u8> into a vector<vector<u8>>.
Input Format: [(length1 || data1), (length2 || data2), ...]
Assumes each length is a u32 in little-endian order.


<pre><code><b>public</b> <b>fun</b> <a href="vec_utils.md#0x1_vec_utils_unflatten_vec_to_nested_vec">unflatten_vec_to_nested_vec</a>(serialized: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="vec_utils.md#0x1_vec_utils_unflatten_vec_to_nested_vec">unflatten_vec_to_nested_vec</a>(serialized: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt; {
    <b>let</b> result = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;();
    <b>let</b> i:u64 = 0;
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&serialized);

    <b>while</b> (i &lt; len) {
        // Read the next 4 bytes <b>as</b> the length of the inner <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>
        <b>let</b> len_inner = <a href="vec_utils.md#0x1_vec_utils_read_u32">read_u32</a>(&serialized, i);
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

<a id="0x1_vec_utils_native_flatten_nested_vec_to_vec"></a>

## Function `native_flatten_nested_vec_to_vec`



<pre><code><b>fun</b> <a href="vec_utils.md#0x1_vec_utils_native_flatten_nested_vec_to_vec">native_flatten_nested_vec_to_vec</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="vec_utils.md#0x1_vec_utils_native_flatten_nested_vec_to_vec">native_flatten_nested_vec_to_vec</a>(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
