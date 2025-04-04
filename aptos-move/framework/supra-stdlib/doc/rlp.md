
<a id="0x1_rlp"></a>

# Module `0x1::rlp`



-  [Function `encode`](#0x1_rlp_encode)
-  [Function `decode`](#0x1_rlp_decode)
-  [Function `encode_list`](#0x1_rlp_encode_list)
-  [Function `decode_list`](#0x1_rlp_decode_list)
-  [Function `native_rlp_encode`](#0x1_rlp_native_rlp_encode)
-  [Function `native_rlp_decode`](#0x1_rlp_native_rlp_decode)
-  [Function `native_rlp_encode_list`](#0x1_rlp_native_rlp_encode_list)
-  [Function `native_rlp_decode_list`](#0x1_rlp_native_rlp_decode_list)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
</code></pre>



<a id="0x1_rlp_encode"></a>

## Function `encode`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode">encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode">encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
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
    <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>(encoded_rlp)
}
</code></pre>



</details>

<a id="0x1_rlp_encode_list"></a>

## Function `encode_list`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_list">encode_list</a>&lt;T: drop&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_encode_list">encode_list</a>&lt;T: drop&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_encode_list">native_rlp_encode_list</a>&lt;T&gt;(<a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(&data))
}
</code></pre>



</details>

<a id="0x1_rlp_decode_list"></a>

## Function `decode_list`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_list">decode_list</a>&lt;T&gt;(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_decode_list">decode_list</a>&lt;T&gt;(encoded_rlp: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt; {
    <a href="rlp.md#0x1_rlp_native_rlp_decode_list">native_rlp_decode_list</a>(encoded_rlp)
}
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_encode"></a>

## Function `native_rlp_encode`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode">native_rlp_encode</a>&lt;T&gt;(x: T): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_decode"></a>

## Function `native_rlp_decode`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): T
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode">native_rlp_decode</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): T;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_encode_list"></a>

## Function `native_rlp_encode_list`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode_list">native_rlp_encode_list</a>&lt;T&gt;(x: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_encode_list">native_rlp_encode_list</a>&lt;T&gt;(x: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;;
</code></pre>



</details>

<a id="0x1_rlp_native_rlp_decode_list"></a>

## Function `native_rlp_decode_list`



<pre><code><b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode_list">native_rlp_decode_list</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>public</b> <b>fun</b> <a href="rlp.md#0x1_rlp_native_rlp_decode_list">native_rlp_decode_list</a>&lt;T&gt;(data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;T&gt;;
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
