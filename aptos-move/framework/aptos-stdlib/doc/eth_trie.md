
<a id="0x1_eth_trie"></a>

# Module `0x1::eth_trie`



-  [Function `verify_proof`](#0x1_eth_trie_verify_proof)
-  [Function `native_verify_proof_eth_trie`](#0x1_eth_trie_native_verify_proof_eth_trie)
-  [Function `test_proof_one_element`](#0x1_eth_trie_test_proof_one_element)


<pre><code></code></pre>



<a id="0x1_eth_trie_verify_proof"></a>

## Function `verify_proof`

Public wrapper function that calls the native and returns a bool.
Returns true if the proof is valid (i.e. the key exists in the trie), and false otherwise.


<pre><code><b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_verify_proof">verify_proof</a>(root: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, key: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, proof: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_verify_proof">verify_proof</a>(
    root: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    key: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    proof: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
): bool {
    // Call the <b>native</b> function. (Arguments are passed in the order declared.)
    <b>let</b> (_value, <b>exists</b>) = <a href="eth_trie.md#0x1_eth_trie_native_verify_proof_eth_trie">native_verify_proof_eth_trie</a>(root, key, proof);
    <b>exists</b>
}
</code></pre>



</details>

<a id="0x1_eth_trie_native_verify_proof_eth_trie"></a>

## Function `native_verify_proof_eth_trie`

The native function is expected to have the following signature:
native_verify_proof_eth_trie(root: vector<u8>, key: vector<u8>, proof: vector<vector<u8>>): (vector<u8>, bool)

Note: The order of arguments in the Move declaration must match what your Rust native function expects.


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

<a id="0x1_eth_trie_test_proof_one_element"></a>

## Function `test_proof_one_element`

Test with a trie of one element.


<pre><code><b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_test_proof_one_element">test_proof_one_element</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="eth_trie.md#0x1_eth_trie_test_proof_one_element">test_proof_one_element</a>() {
    // Suppose a trie <b>with</b> only one key "k" mapped <b>to</b> "v" produces a certain root.
    <b>let</b> root: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>[
        // (Fill in the correct root bytes for the one-element trie.)
        0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89,
        0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89,
        0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89,
        0xab, 0xcd, 0xef, 0x01, 0x23, 0x45, 0x67, 0x89
    ];
    <b>let</b> key: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = b"k";
    <b>let</b> proof: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt; = <a href="../../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>();
    // Assume the one proof node for the key "k" is <b>as</b> follows:
    <b>let</b> node: <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = <a href="../../move-stdlib/doc/vector.md#0x1_vector">vector</a>[
        // (Fill in the proof node bytes.)
        0xde, 0xad, 0xbe, 0xef
    ];
    <a href="../../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> proof, node);
    <b>let</b> <b>exists</b> = <a href="eth_trie.md#0x1_eth_trie_verify_proof">verify_proof</a>(root, key, proof);
    <b>assert</b>!(<b>exists</b>, 400);
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
