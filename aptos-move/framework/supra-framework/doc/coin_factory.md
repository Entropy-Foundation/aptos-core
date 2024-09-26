
<a id="0x1_coin_factory"></a>

# Module `0x1::coin_factory`

Added via upgrade


-  [Struct `USDC`](#0x1_coin_factory_USDC)
-  [Struct `USDT`](#0x1_coin_factory_USDT)
-  [Struct `WBTC`](#0x1_coin_factory_WBTC)
-  [Struct `WETH`](#0x1_coin_factory_WETH)
-  [Struct `WSOL`](#0x1_coin_factory_WSOL)
-  [Resource `CoinManager`](#0x1_coin_factory_CoinManager)
-  [Constants](#@Constants_0)
-  [Function `create_coin`](#0x1_coin_factory_create_coin)
-  [Function `register_user`](#0x1_coin_factory_register_user)
-  [Function `mint`](#0x1_coin_factory_mint)
-  [Function `burn`](#0x1_coin_factory_burn)
-  [Function `freeze_user_coin_store`](#0x1_coin_factory_freeze_user_coin_store)


<pre><code><b>use</b> <a href="coin.md#0x1_coin">0x1::coin</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
</code></pre>



<a id="0x1_coin_factory_USDC"></a>

## Struct `USDC`



<pre><code><b>struct</b> <a href="coin_factory.md#0x1_coin_factory_USDC">USDC</a>
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dummy_field: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_coin_factory_USDT"></a>

## Struct `USDT`



<pre><code><b>struct</b> <a href="coin_factory.md#0x1_coin_factory_USDT">USDT</a>
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dummy_field: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_coin_factory_WBTC"></a>

## Struct `WBTC`



<pre><code><b>struct</b> <a href="coin_factory.md#0x1_coin_factory_WBTC">WBTC</a>
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dummy_field: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_coin_factory_WETH"></a>

## Struct `WETH`



<pre><code><b>struct</b> <a href="coin_factory.md#0x1_coin_factory_WETH">WETH</a>
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dummy_field: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_coin_factory_WSOL"></a>

## Struct `WSOL`



<pre><code><b>struct</b> <a href="coin_factory.md#0x1_coin_factory_WSOL">WSOL</a>
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dummy_field: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_coin_factory_CoinManager"></a>

## Resource `CoinManager`



<pre><code><b>struct</b> <a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a>&lt;CoinType&gt; <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>mint_capability: <a href="coin.md#0x1_coin_MintCapability">coin::MintCapability</a>&lt;CoinType&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>freez_capability: <a href="coin.md#0x1_coin_FreezeCapability">coin::FreezeCapability</a>&lt;CoinType&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>burn_capability: <a href="coin.md#0x1_coin_BurnCapability">coin::BurnCapability</a>&lt;CoinType&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_coin_factory_ONLY_COIN_MANAGER"></a>



<pre><code><b>const</b> <a href="coin_factory.md#0x1_coin_factory_ONLY_COIN_MANAGER">ONLY_COIN_MANAGER</a>: u64 = 1;
</code></pre>



<a id="0x1_coin_factory_create_coin"></a>

## Function `create_coin`



<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_create_coin">create_coin</a>&lt;CoinType&gt;(tx_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, name: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>, symbol: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>, deciamals: u8, monitory_supply: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_create_coin">create_coin</a>&lt;CoinType&gt;(
    tx_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    name: String,
    symbol: String,
    deciamals: u8,
    monitory_supply: bool
) {
    <b>let</b> (burn_capability, freez_capability, mint_capability) = <a href="coin.md#0x1_coin_initialize">coin::initialize</a>&lt;CoinType&gt;(
        tx_sender,
        name,
        symbol,
        deciamals,
        monitory_supply,
    );
    <b>move_to</b>(tx_sender, <a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a> {
        mint_capability,
        freez_capability,
        burn_capability,
    })
}
</code></pre>



</details>

<a id="0x1_coin_factory_register_user"></a>

## Function `register_user`



<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_register_user">register_user</a>&lt;CoinType&gt;(tx_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_register_user">register_user</a>&lt;CoinType&gt;(tx_sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="coin.md#0x1_coin_register">coin::register</a>&lt;CoinType&gt;(tx_sender)
}
</code></pre>



</details>

<a id="0x1_coin_factory_mint"></a>

## Function `mint`



<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_mint">mint</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_mint">mint</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <b>to</b>: <b>address</b>, amount: u64) <b>acquires</b> <a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a> {
    <b>let</b> sender_addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <b>assert</b>!(<b>exists</b>&lt;<a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a>&lt;CoinType&gt;&gt;(sender_addr) == <b>true</b>,
        <a href="coin_factory.md#0x1_coin_factory_ONLY_COIN_MANAGER">ONLY_COIN_MANAGER</a>);
    <a href="coin.md#0x1_coin_deposit">coin::deposit</a>(
        <b>to</b>,
        <a href="coin.md#0x1_coin_mint">coin::mint</a>&lt;CoinType&gt;(amount, &<b>borrow_global</b>&lt;<a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a>&lt;CoinType&gt;&gt;(sender_addr).mint_capability)
    )
}
</code></pre>



</details>

<a id="0x1_coin_factory_burn"></a>

## Function `burn`



<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_burn">burn</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, from: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_burn">burn</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, from: <b>address</b>, amount: u64) <b>acquires</b> <a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a> {
    <b>let</b> sender_addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <b>assert</b>!(<b>exists</b>&lt;<a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a>&lt;CoinType&gt;&gt;(sender_addr) == <b>true</b>,
        <a href="coin_factory.md#0x1_coin_factory_ONLY_COIN_MANAGER">ONLY_COIN_MANAGER</a>);
    <a href="coin.md#0x1_coin_burn_from">coin::burn_from</a>&lt;CoinType&gt;(
        from,
        amount,
        &<b>borrow_global</b>&lt;<a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a>&lt;CoinType&gt;&gt;(sender_addr).burn_capability
    )
}
</code></pre>



</details>

<a id="0x1_coin_factory_freeze_user_coin_store"></a>

## Function `freeze_user_coin_store`



<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_freeze_user_coin_store">freeze_user_coin_store</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, user: <b>address</b>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="coin_factory.md#0x1_coin_factory_freeze_user_coin_store">freeze_user_coin_store</a>&lt;CoinType&gt;(sender: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, user: <b>address</b>) <b>acquires</b> <a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a> {
    <b>let</b> sender_addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(sender);
    <b>assert</b>!(<b>exists</b>&lt;<a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a>&lt;CoinType&gt;&gt;(sender_addr) == <b>true</b>,
        <a href="coin_factory.md#0x1_coin_factory_ONLY_COIN_MANAGER">ONLY_COIN_MANAGER</a>);
    <a href="coin.md#0x1_coin_freeze_coin_store">coin::freeze_coin_store</a>&lt;CoinType&gt;(
        user,
        &<b>borrow_global</b>&lt;<a href="coin_factory.md#0x1_coin_factory_CoinManager">CoinManager</a>&lt;CoinType&gt;&gt;(sender_addr).freez_capability
    )
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
