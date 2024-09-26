
<a id="0x1_math32"></a>

# Module `0x1::math32`

Added via upgrade


-  [Function `max`](#0x1_math32_max)
-  [Function `min`](#0x1_math32_min)
-  [Function `average`](#0x1_math32_average)


<pre><code></code></pre>



<a id="0x1_math32_max"></a>

## Function `max`

Return the largest of two numbers.


<pre><code><b>public</b> <b>fun</b> <a href="math32.md#0x1_math32_max">max</a>(a: u64, b: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="math32.md#0x1_math32_max">max</a>(a: u64, b: u64): u64 {
    <b>if</b> (a &gt;= b) a <b>else</b> b
}
</code></pre>



</details>

<a id="0x1_math32_min"></a>

## Function `min`

Return the smallest of two numbers.


<pre><code><b>public</b> <b>fun</b> <b>min</b>(a: u64, b: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <b>min</b>(a: u64, b: u64): u64 {
    <b>if</b> (a &lt; b) a <b>else</b> b
}
</code></pre>



</details>

<a id="0x1_math32_average"></a>

## Function `average`

Return the average of two.


<pre><code><b>public</b> <b>fun</b> <a href="math32.md#0x1_math32_average">average</a>(a: u64, b: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="math32.md#0x1_math32_average">average</a>(a: u64, b: u64): u64 {
    <b>if</b> (a &lt; b) {
        a + (b - a) / 2
    } <b>else</b> {
        b + (a - b) / 2
    }
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
