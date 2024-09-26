
<a id="0x1_anyhow"></a>

# Module `0x1::anyhow`



-  [Constants](#@Constants_0)
-  [Function `throw`](#0x1_anyhow_throw)


<pre><code></code></pre>



<a id="@Constants_0"></a>

## Constants


<a id="0x1_anyhow_SORRY_DEV_IS_TOO_LAZY"></a>



<pre><code><b>const</b> <a href="anyhow.md#0x1_anyhow_SORRY_DEV_IS_TOO_LAZY">SORRY_DEV_IS_TOO_LAZY</a>: u64 = 1111111111;
</code></pre>



<a id="0x1_anyhow_throw"></a>

## Function `throw`



<pre><code><b>public</b> <b>fun</b> <a href="anyhow.md#0x1_anyhow_throw">throw</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="anyhow.md#0x1_anyhow_throw">throw</a>() {
    <b>assert</b>!(<b>false</b>, <a href="anyhow.md#0x1_anyhow_SORRY_DEV_IS_TOO_LAZY">SORRY_DEV_IS_TOO_LAZY</a>);
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
