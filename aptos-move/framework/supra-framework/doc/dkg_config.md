
<a id="0x1_dkg_config"></a>

# Module `0x1::dkg_config`



-  [Resource `DkgFeatureFlag`](#0x1_dkg_config_DkgFeatureFlag)
-  [Resource `DkgNodeConfig`](#0x1_dkg_config_DkgNodeConfig)
-  [Resource `DkgConfig`](#0x1_dkg_config_DkgConfig)
-  [Constants](#@Constants_0)
-  [Function `update_dkg_feature_flag`](#0x1_dkg_config_update_dkg_feature_flag)
-  [Function `get_dkg_feature_flag`](#0x1_dkg_config_get_dkg_feature_flag)
-  [Function `store_dkg_node_config`](#0x1_dkg_config_store_dkg_node_config)
-  [Function `dkg_node_config_exists`](#0x1_dkg_config_dkg_node_config_exists)
-  [Function `get_dkg_node_config`](#0x1_dkg_config_get_dkg_node_config)
-  [Function `create_dkg_config`](#0x1_dkg_config_create_dkg_config)
-  [Function `get_dealer_clan_committee`](#0x1_dkg_config_get_dealer_clan_committee)
-  [Function `is_node_family_committee_member`](#0x1_dkg_config_is_node_family_committee_member)
-  [Function `get_dkg_node_bls_pubkey`](#0x1_dkg_config_get_dkg_node_bls_pubkey)


<pre><code><b>use</b> <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381">0x1::bls12381</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519">0x1::ed25519</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_dkg_config_DkgFeatureFlag"></a>

## Resource `DkgFeatureFlag`

Configuration that controls if the dkg is enabled for validators


<pre><code><b>struct</b> <a href="dkg_config.md#0x1_dkg_config_DkgFeatureFlag">DkgFeatureFlag</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>enable_dkg: bool</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_config_DkgNodeConfig"></a>

## Resource `DkgNodeConfig`



<pre><code><b>struct</b> <a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a> <b>has</b> <b>copy</b>, drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>addr: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>network_address: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>ed_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>cg_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_dkg_config_DkgConfig"></a>

## Resource `DkgConfig`



<pre><code><b>struct</b> <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> <b>has</b> <b>copy</b>, drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dealer_clan_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>family_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>target_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_dkg_config_EDKG_NODE_CONFIG_NOT_EXIST"></a>

Missing node dkg config


<pre><code><b>const</b> <a href="dkg_config.md#0x1_dkg_config_EDKG_NODE_CONFIG_NOT_EXIST">EDKG_NODE_CONFIG_NOT_EXIST</a>: u64 = 5;
</code></pre>



<a id="0x1_dkg_config_EINVALID_BLS_PUBLIC_KEY"></a>

Invalid bls public key


<pre><code><b>const</b> <a href="dkg_config.md#0x1_dkg_config_EINVALID_BLS_PUBLIC_KEY">EINVALID_BLS_PUBLIC_KEY</a>: u64 = 2;
</code></pre>



<a id="0x1_dkg_config_EINVALID_CG_PUBLIC_KEY"></a>

Invalid cg public key


<pre><code><b>const</b> <a href="dkg_config.md#0x1_dkg_config_EINVALID_CG_PUBLIC_KEY">EINVALID_CG_PUBLIC_KEY</a>: u64 = 3;
</code></pre>



<a id="0x1_dkg_config_EINVALID_DKG_CONFIG"></a>

Invalid dkg config


<pre><code><b>const</b> <a href="dkg_config.md#0x1_dkg_config_EINVALID_DKG_CONFIG">EINVALID_DKG_CONFIG</a>: u64 = 4;
</code></pre>



<a id="0x1_dkg_config_EINVALID_EDPUBLIC_KEY"></a>

Invalid ed25519 public key


<pre><code><b>const</b> <a href="dkg_config.md#0x1_dkg_config_EINVALID_EDPUBLIC_KEY">EINVALID_EDPUBLIC_KEY</a>: u64 = 1;
</code></pre>



<a id="0x1_dkg_config_update_dkg_feature_flag"></a>

## Function `update_dkg_feature_flag`

This should be called by on-chain governance to enable/disable dkg for the validator nodes


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_update_dkg_feature_flag">update_dkg_feature_flag</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, enable: bool)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_update_dkg_feature_flag">update_dkg_feature_flag</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, enable: bool) <b>acquires</b> <a href="dkg_config.md#0x1_dkg_config_DkgFeatureFlag">DkgFeatureFlag</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>let</b> enable_dkg_flag = &<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgFeatureFlag">DkgFeatureFlag</a>&gt;(@supra_framework).enable_dkg;
    *enable_dkg_flag = enable;
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_dkg_feature_flag"></a>

## Function `get_dkg_feature_flag`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_feature_flag">get_dkg_feature_flag</a>(): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_feature_flag">get_dkg_feature_flag</a>(): bool <b>acquires</b> <a href="dkg_config.md#0x1_dkg_config_DkgFeatureFlag">DkgFeatureFlag</a> {
    <b>let</b> enable_dkg_flag = <b>borrow_global</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgFeatureFlag">DkgFeatureFlag</a>&gt;(@supra_framework).enable_dkg;
    enable_dkg_flag
}
</code></pre>



</details>

<a id="0x1_dkg_config_store_dkg_node_config"></a>

## Function `store_dkg_node_config`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_store_dkg_node_config">store_dkg_node_config</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <b>address</b>: <b>address</b>, network_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, ed_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, pop_bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, cg_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_store_dkg_node_config">store_dkg_node_config</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
                                         <b>address</b>: <b>address</b>,
                                         network_addresses: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
                                         ed_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
                                         bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
                                         pop_bls_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
                                         cg_pubkey: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    // Checks the ed key is valid <b>to</b> prevent rogue-key attacks.
    <b>let</b> valid_ed_public_key = <a href="../../aptos-stdlib/doc/ed25519.md#0x1_ed25519_new_validated_public_key_from_bytes">ed25519::new_validated_public_key_from_bytes</a>(ed_pubkey);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&valid_ed_public_key), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg_config.md#0x1_dkg_config_EINVALID_EDPUBLIC_KEY">EINVALID_EDPUBLIC_KEY</a>));

    // Checks the bls key is valid <b>to</b> prevent rogue-key attacks.
    <b>let</b> pop = <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_proof_of_possession_from_bytes">bls12381::proof_of_possession_from_bytes</a>(pop_bls_pubkey);
    <b>let</b> valid_bls_public_key = <a href="../../aptos-stdlib/doc/bls12381.md#0x1_bls12381_public_key_from_bytes_with_pop">bls12381::public_key_from_bytes_with_pop</a>(bls_pubkey, &pop);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&valid_bls_public_key), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg_config.md#0x1_dkg_config_EINVALID_BLS_PUBLIC_KEY">EINVALID_BLS_PUBLIC_KEY</a>));

    // Validating CG <b>public</b> key <b>requires</b> class group arithmatics not supported in MOVE
    // we can add a <b>native</b> function for cg key verification
    // for now atleast check the key is not empty
    //todo: add cg_key verification
    <b>assert</b>!(!<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&cg_pubkey), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg_config.md#0x1_dkg_config_EINVALID_CG_PUBLIC_KEY">EINVALID_CG_PUBLIC_KEY</a>));

    <b>let</b> <a href="dkg_config.md#0x1_dkg_config">dkg_config</a> = <a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a> {
        addr: <b>address</b>,
        network_address: network_addresses,
        ed_pubkey,
        bls_pubkey,
        cg_pubkey,
    };

    <b>move_to</b>(<a href="account.md#0x1_account">account</a>, <a href="dkg_config.md#0x1_dkg_config">dkg_config</a>);
}
</code></pre>



</details>

<a id="0x1_dkg_config_dkg_node_config_exists"></a>

## Function `dkg_node_config_exists`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_dkg_node_config_exists">dkg_node_config_exists</a>(account_address: <b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_dkg_node_config_exists">dkg_node_config_exists</a>(account_address: <b>address</b>): bool{
    <b>exists</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a>&gt;(account_address)
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_dkg_node_config"></a>

## Function `get_dkg_node_config`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_node_config">get_dkg_node_config</a>(account_address: <b>address</b>): <a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_node_config">get_dkg_node_config</a>(account_address: <b>address</b>): <a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a> <b>acquires</b> <a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a> {
    <b>assert</b>!(<a href="dkg_config.md#0x1_dkg_config_dkg_node_config_exists">dkg_node_config_exists</a>(account_address), <a href="dkg_config.md#0x1_dkg_config_EDKG_NODE_CONFIG_NOT_EXIST">EDKG_NODE_CONFIG_NOT_EXIST</a>);
    <b>let</b> dkg_node_config = <b>borrow_global</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a>&gt;(account_address);
    *dkg_node_config
}
</code></pre>



</details>

<a id="0x1_dkg_config_create_dkg_config"></a>

## Function `create_dkg_config`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_create_dkg_config">create_dkg_config</a>(dealer_clan_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>&gt;, family_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>&gt;, target_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>&gt;): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_create_dkg_config">create_dkg_config</a>(dealer_clan_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a>&gt;,
                             family_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a>&gt;,
                             target_committee: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a>&gt;,): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {

    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&dealer_clan_committee) &gt;= 3 &&
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&family_committee) &gt;= 1 &&
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&target_committee) &gt;= 4, <a href="dkg_config.md#0x1_dkg_config_EINVALID_DKG_CONFIG">EINVALID_DKG_CONFIG</a>);

    <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {
        dealer_clan_committee,
        family_committee,
        target_committee
    }
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_dealer_clan_committee"></a>

## Function `get_dealer_clan_committee`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dealer_clan_committee">get_dealer_clan_committee</a>(<a href="dkg_config.md#0x1_dkg_config">dkg_config</a>: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dealer_clan_committee">get_dealer_clan_committee</a>(<a href="dkg_config.md#0x1_dkg_config">dkg_config</a>: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a>&gt;{
    <a href="dkg_config.md#0x1_dkg_config">dkg_config</a>.dealer_clan_committee
}
</code></pre>



</details>

<a id="0x1_dkg_config_is_node_family_committee_member"></a>

## Function `is_node_family_committee_member`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_is_node_family_committee_member">is_node_family_committee_member</a>(addr: <b>address</b>, <a href="dkg_config.md#0x1_dkg_config">dkg_config</a>: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_is_node_family_committee_member">is_node_family_committee_member</a>(addr: <b>address</b>, <a href="dkg_config.md#0x1_dkg_config">dkg_config</a>: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>): bool {
    <b>let</b> family_committee = &<a href="dkg_config.md#0x1_dkg_config">dkg_config</a>.family_committee; // Borrow the <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(family_committee);         // Get the <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>'s length
    <b>let</b> i = 0;                                          // Initialize index
    <b>while</b> (i &lt; len) {
        <b>let</b> family_node = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(family_committee, i); // Borrow each element
        <b>if</b> (family_node.addr == addr) {
            <b>return</b> <b>true</b>;                                // Match found, <b>return</b> <b>true</b>
        };
        i = i + 1;                                      // Increment index
    };
    <b>false</b>                                               // No match found
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_dkg_node_bls_pubkey"></a>

## Function `get_dkg_node_bls_pubkey`



<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_node_bls_pubkey">get_dkg_node_bls_pubkey</a>(dkg_node_config: &<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">dkg_config::DkgNodeConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_node_bls_pubkey">get_dkg_node_bls_pubkey</a>(dkg_node_config: &<a href="dkg_config.md#0x1_dkg_config_DkgNodeConfig">DkgNodeConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;{
    dkg_node_config.bls_pubkey
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
