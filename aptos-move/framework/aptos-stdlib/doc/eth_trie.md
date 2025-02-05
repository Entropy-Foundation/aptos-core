
<a id="0x1_eth_trie"></a>

# Module `0x1::eth_trie`



-  [Function `verify_proof`](#0x1_eth_trie_verify_proof)
-  [Function `native_verify_proof_eth_trie`](#0x1_eth_trie_native_verify_proof_eth_trie)


<pre><code></code></pre>



<a id="0x1_eth_trie_verify_proof"></a>

## Function `verify_proof`

Public wrapper function that calls the native and returns a bool.
Returns true if the proof is valid and the key exists in the trie, and false if the proof is valid but the key does not exist.
Returns an error if the proof is invalid


<pre><code><b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_verify_proof">verify_proof</a>(root: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, key: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): (<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_verify_proof">verify_proof</a>(
    root: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    key: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    proof: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
): (<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, bool) {
    // Call the <b>native</b> function. (Arguments are passed in the order declared.)
    <b>let</b> (value, <b>exists</b>) = <a href="eth_trie.md#0x1_eth_trie_native_verify_proof_eth_trie">native_verify_proof_eth_trie</a>(root, key, proof);
    (value, <b>exists</b>)
}
</code></pre>



</details>

<a id="0x1_eth_trie_native_verify_proof_eth_trie"></a>

## Function `native_verify_proof_eth_trie`



<pre><code><b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_native_verify_proof_eth_trie">native_verify_proof_eth_trie</a>(root: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, key: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): (<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>native</b> <b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_native_verify_proof_eth_trie">native_verify_proof_eth_trie</a>(
    root: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    key: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    proof: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
): (<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, bool);
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
