
<a id="0x1_vector_utils"></a>

# Module `0x1::vector_utils`



-  [Function `sort_vector_u64`](#0x1_vector_utils_sort_vector_u64)
-  [Function `sort_vector_u64_by_keys`](#0x1_vector_utils_sort_vector_u64_by_keys)
-  [Function `native_sort_vector_u64`](#0x1_vector_utils_native_sort_vector_u64)
-  [Function `native_sort_vector_u64_by_key`](#0x1_vector_utils_native_sort_vector_u64_by_key)


<pre><code></code></pre>



<a id="0x1_vector_utils_sort_vector_u64"></a>

## Function `sort_vector_u64`

Sorts values in ascending order.


<pre><code><b>public</b> <b>fun</b> <a href="vector_utils.md#0x1_vector_utils_sort_vector_u64">sort_vector_u64</a>(values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="vector_utils.md#0x1_vector_utils_sort_vector_u64">sort_vector_u64</a>(values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;) : <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt; {
    <a href="vector_utils.md#0x1_vector_utils_native_sort_vector_u64">native_sort_vector_u64</a>(values)
}
</code></pre>



</details>

<a id="0x1_vector_utils_sort_vector_u64_by_keys"></a>

## Function `sort_vector_u64_by_keys`

Sorts values based on the input keys in ascending order.
The keys and values should match in lenght, otherwise function will abort.


<pre><code><b>public</b> <b>fun</b> <a href="vector_utils.md#0x1_vector_utils_sort_vector_u64_by_keys">sort_vector_u64_by_keys</a>(keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="vector_utils.md#0x1_vector_utils_sort_vector_u64_by_keys">sort_vector_u64_by_keys</a>(keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;) : <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt; {
    <a href="vector_utils.md#0x1_vector_utils_native_sort_vector_u64_by_key">native_sort_vector_u64_by_key</a>(keys, values)
}
</code></pre>



</details>

<a id="0x1_vector_utils_native_sort_vector_u64"></a>

## Function `native_sort_vector_u64`

Sorts values in ascending order.


<pre><code><b>fun</b> <a href="vector_utils.md#0x1_vector_utils_native_sort_vector_u64">native_sort_vector_u64</a>(values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="vector_utils.md#0x1_vector_utils_native_sort_vector_u64">native_sort_vector_u64</a>(values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;;
</code></pre>



</details>

<a id="0x1_vector_utils_native_sort_vector_u64_by_key"></a>

## Function `native_sort_vector_u64_by_key`

Sorts values based on the input keys in ascending order.
The keys and values should match in lenght, otherwise function will abort.


<pre><code><b>fun</b> <a href="vector_utils.md#0x1_vector_utils_native_sort_vector_u64_by_key">native_sort_vector_u64_by_key</a>(keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>fun</b> <a href="vector_utils.md#0x1_vector_utils_native_sort_vector_u64_by_key">native_sort_vector_u64_by_key</a>(keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;;
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
