
<a id="0x1_leader_ban_registry_config"></a>

# Module `0x1::leader_ban_registry_config`

Provides the config related to leader ban registry


-  [Resource `BanRegistryParameters`](#0x1_leader_ban_registry_config_BanRegistryParameters)
-  [Resource `BanRegistryParametersV0`](#0x1_leader_ban_registry_config_BanRegistryParametersV0)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_leader_ban_registry_config_initialize)
-  [Function `set_for_next_epoch`](#0x1_leader_ban_registry_config_set_for_next_epoch)
-  [Function `on_new_epoch`](#0x1_leader_ban_registry_config_on_new_epoch)
-  [Function `get_ban_registry_params`](#0x1_leader_ban_registry_config_get_ban_registry_params)
-  [Function `get_ban_registry_params_v0`](#0x1_leader_ban_registry_config_get_ban_registry_params_v0)
-  [Function `get_initial_elections_denied`](#0x1_leader_ban_registry_config_get_initial_elections_denied)
-  [Function `get_max_elections_denied`](#0x1_leader_ban_registry_config_get_max_elections_denied)
-  [Function `get_minimum_unbanned_proposers`](#0x1_leader_ban_registry_config_get_minimum_unbanned_proposers)
-  [Function `get_probation_elections`](#0x1_leader_ban_registry_config_get_probation_elections)
-  [Function `deserialise_v0_params`](#0x1_leader_ban_registry_config_deserialise_v0_params)


<pre><code><b>use</b> <a href="config_buffer.md#0x1_config_buffer">0x1::config_buffer</a>;
<b>use</b> <a href="../../supra-stdlib/doc/decode_bcs.md#0x1_decode_bcs">0x1::decode_bcs</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
</code></pre>



<a id="0x1_leader_ban_registry_config_BanRegistryParameters"></a>

## Resource `BanRegistryParameters`

Holds ban registry parameters bytes and it's version


<pre><code><b>struct</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a> <b>has</b> drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>
 Denotes config bcs bytes
</dd>
<dt>
<code><a href="version.md#0x1_version">version</a>: u8</code>
</dt>
<dd>
 Denotes config version
</dd>
</dl>


</details>

<a id="0x1_leader_ban_registry_config_BanRegistryParametersV0"></a>

## Resource `BanRegistryParametersV0`

Ban registry parameters v0


<pre><code><b>struct</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> <b>has</b> drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>initial_elections_denied: u8</code>
</dt>
<dd>
 Denotes initial election count denied
</dd>
<dt>
<code>max_elections_denied: u32</code>
</dt>
<dd>
 Denotes max election count denied
</dd>
<dt>
<code>minimum_unbanned_proposers: u8</code>
</dt>
<dd>
 Denotes the minimum number of validators that must remain eligible for proposal. This
 helps to preserve liveness in the presence of extended periods of network asynchrony.
</dd>
<dt>
<code>probation_elections: u8</code>
</dt>
<dd>
 Denotes the number of elections a validator must serve on probation after ban expires.
 The ban duration compounds each time a validator is banned whilst on probation, and
 resets to the base duration if the validator passes probation.
</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_leader_ban_registry_config_EALREADY_INITIALISED"></a>

The BanRegistryParameters already initialised


<pre><code><b>const</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EALREADY_INITIALISED">EALREADY_INITIALISED</a>: u64 = 4;
</code></pre>



<a id="0x1_leader_ban_registry_config_EINVALID_CONFIG"></a>

The provided on chain config bytes are empty or invalid


<pre><code><b>const</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EINVALID_CONFIG">EINVALID_CONFIG</a>: u64 = 1;
</code></pre>



<a id="0x1_leader_ban_registry_config_EINVALID_VERSION"></a>

The provided on chain config version should be equal or greater than existing


<pre><code><b>const</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EINVALID_VERSION">EINVALID_VERSION</a>: u64 = 2;
</code></pre>



<a id="0x1_leader_ban_registry_config_EINVALID_VERSION_BYTES"></a>

Decoding from version bytes failed


<pre><code><b>const</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EINVALID_VERSION_BYTES">EINVALID_VERSION_BYTES</a>: u64 = 3;
</code></pre>



<a id="0x1_leader_ban_registry_config_initialize"></a>

## Function `initialize`

Publishes the BanRegistryParameters config.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_initialize">initialize</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&config) != 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EINVALID_CONFIG">EINVALID_CONFIG</a>));
    <b>assert</b>!(
        !<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EALREADY_INITIALISED">EALREADY_INITIALISED</a>)
    );
    <b>let</b> v0 = <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_deserialise_v0_params">deserialise_v0_params</a>(config);
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_none">option::is_none</a>(&v0)) {
        <b>abort</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EINVALID_VERSION_BYTES">EINVALID_VERSION_BYTES</a>)
    };
    // we always init <b>with</b> <a href="version.md#0x1_version">version</a> 0
    <b>move_to</b>(supra_framework, <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a> { config, <a href="version.md#0x1_version">version</a>: 0 });
    <b>let</b> v0_params = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> v0);
    <b>move_to</b>(supra_framework, v0_params);
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_set_for_next_epoch"></a>

## Function `set_for_next_epoch`

This can be called by on-chain governance to update on-chain configs for the next epoch.
Example usage:
```
supra_framework::leader_ban_registry_config::set_for_next_epoch(&framework_signer, some_config_bytes, version);
supra_framework::supra_governance::reconfigure(&framework_signer);
```


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_set_for_next_epoch">set_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <a href="version.md#0x1_version">version</a>: u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_set_for_next_epoch">set_for_next_epoch</a>(
    <a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, <a href="version.md#0x1_version">version</a>: u8
) <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(<a href="account.md#0x1_account">account</a>);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&config) != 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EINVALID_CONFIG">EINVALID_CONFIG</a>));
    <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
        <b>let</b> ban_registry_params =
            <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>assert</b>!(
            <a href="version.md#0x1_version">version</a> &gt;= ban_registry_params.<a href="version.md#0x1_version">version</a>,
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_EINVALID_VERSION">EINVALID_VERSION</a>)
        );
    };
    std::config_buffer::upsert&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(
        <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a> { config, <a href="version.md#0x1_version">version</a> }
    );
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_on_new_epoch"></a>

## Function `on_new_epoch`

Only used in reconfigurations to apply the pending <code><a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a></code>, if there is any.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_on_new_epoch">on_new_epoch</a>(
    framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
) <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>, <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(framework);
    <b>if</b> (<a href="config_buffer.md#0x1_config_buffer_does_exist">config_buffer::does_exist</a>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;()) {
        <b>let</b> new_config = <a href="config_buffer.md#0x1_config_buffer_extract">config_buffer::extract</a>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;();
        <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
            *<b>borrow_global_mut</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework) = new_config;
        } <b>else</b> {
            <b>move_to</b>(framework, new_config);
        };
        <b>let</b> params = <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>if</b> (params.<a href="version.md#0x1_version">version</a> == 0) {
            <b>let</b> v0 = <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_deserialise_v0_params">deserialise_v0_params</a>(params.config);
            // This is <b>to</b> prevent <b>abort</b> on new epoch <b>if</b> deserialise failed.
            <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&v0)) {
                <b>let</b> ban_registry_params = <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> v0);
                <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;(@supra_framework)) {
                    *<b>borrow_global_mut</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;(@supra_framework) = ban_registry_params;
                } <b>else</b> {
                    <b>move_to</b>(framework, ban_registry_params);
                }
            }
        }
        // later <a href="version.md#0x1_version">version</a> can be assigned here
    }
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_get_ban_registry_params"></a>

## Function `get_ban_registry_params`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_ban_registry_params">get_ban_registry_params</a>(): (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_ban_registry_params">get_ban_registry_params</a>(): (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, u8) <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
        <b>let</b> ban_registry_config =
            <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>return</b> (ban_registry_config.config, ban_registry_config.<a href="version.md#0x1_version">version</a>)
    };
    (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>(), 0)
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_get_ban_registry_params_v0"></a>

## Function `get_ban_registry_params_v0`



<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_ban_registry_params_v0">get_ban_registry_params_v0</a>(): (u8, u32, u8, u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_ban_registry_params_v0">get_ban_registry_params_v0</a>(): (u8, u32, u8, u8) <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>, <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
        <b>let</b> ban_registry_config =
            <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>if</b> (ban_registry_config.<a href="version.md#0x1_version">version</a> == 0) {
            <b>let</b> ban_registry_params =
                <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;(@supra_framework);
            <b>return</b> (
                ban_registry_params.initial_elections_denied,
                ban_registry_params.max_elections_denied,
                ban_registry_params.minimum_unbanned_proposers,
                ban_registry_params.probation_elections
            )
        }
    };
    (0, 0, 0, 0)
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_get_initial_elections_denied"></a>

## Function `get_initial_elections_denied`

Provide initial election denied value


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_initial_elections_denied">get_initial_elections_denied</a>(): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_initial_elections_denied">get_initial_elections_denied</a>(): u8 <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>, <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
        <b>let</b> ban_registry_config =
            <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>if</b> (ban_registry_config.<a href="version.md#0x1_version">version</a> == 0) {
            <b>let</b> ban_registry_params =
                <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;(@supra_framework);
            <b>return</b> ban_registry_params.initial_elections_denied
        }
    };
    0
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_get_max_elections_denied"></a>

## Function `get_max_elections_denied`

Provide max election denied value


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_max_elections_denied">get_max_elections_denied</a>(): u32
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_max_elections_denied">get_max_elections_denied</a>(): u32 <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>, <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
        <b>let</b> ban_registry_config =
            <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>if</b> (ban_registry_config.<a href="version.md#0x1_version">version</a> == 0) {
            <b>let</b> ban_registry_params =
                <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;(@supra_framework);
            <b>return</b> ban_registry_params.max_elections_denied
        }
    };
    0
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_get_minimum_unbanned_proposers"></a>

## Function `get_minimum_unbanned_proposers`

Provide minimum unbanned proposers value


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_minimum_unbanned_proposers">get_minimum_unbanned_proposers</a>(): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_minimum_unbanned_proposers">get_minimum_unbanned_proposers</a>(): u8 <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>, <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
        <b>let</b> ban_registry_config =
            <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>if</b> (ban_registry_config.<a href="version.md#0x1_version">version</a> == 0) {
            <b>let</b> ban_registry_params =
                <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;(@supra_framework);
            <b>return</b> ban_registry_params.minimum_unbanned_proposers
        }
    };
    0
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_get_probation_elections"></a>

## Function `get_probation_elections`

Provide probation elections value


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_probation_elections">get_probation_elections</a>(): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_probation_elections">get_probation_elections</a>(): u8 <b>acquires</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>, <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework)) {
        <b>let</b> ban_registry_config =
            <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParameters">BanRegistryParameters</a>&gt;(@supra_framework);
        <b>if</b> (ban_registry_config.<a href="version.md#0x1_version">version</a> == 0) {
            <b>let</b> ban_registry_params =
                <b>borrow_global</b>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;(@supra_framework);
            <b>return</b> ban_registry_params.probation_elections
        }
    };
    0
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_config_deserialise_v0_params"></a>

## Function `deserialise_v0_params`

Decoding bytes to <code><a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a></code> using bcs


<pre><code><b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_deserialise_v0_params">deserialise_v0_params</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">leader_ban_registry_config::BanRegistryParametersV0</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_deserialise_v0_params">deserialise_v0_params</a>(bytes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;): Option&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt; {
    <b>let</b> bcs_bytes = <a href="../../supra-stdlib/doc/decode_bcs.md#0x1_decode_bcs_new">decode_bcs::new</a>(bytes);
    <b>let</b> initial_elections_denied: u8 = <a href="../../supra-stdlib/doc/decode_bcs.md#0x1_decode_bcs_peel_u8">decode_bcs::peel_u8</a>(&<b>mut</b> bcs_bytes);
    <b>let</b> max_elections_denied: u32 = <a href="../../supra-stdlib/doc/decode_bcs.md#0x1_decode_bcs_peel_u32">decode_bcs::peel_u32</a>(&<b>mut</b> bcs_bytes);
    <b>let</b> minimum_unbanned_proposers: u8 = <a href="../../supra-stdlib/doc/decode_bcs.md#0x1_decode_bcs_peel_u8">decode_bcs::peel_u8</a>(&<b>mut</b> bcs_bytes);
    <b>let</b> probation_elections: u8 = <a href="../../supra-stdlib/doc/decode_bcs.md#0x1_decode_bcs_peel_u8">decode_bcs::peel_u8</a>(&<b>mut</b> bcs_bytes);
    // making sure no bytes left <b>to</b> decode means correct parameter <a href="version.md#0x1_version">version</a>
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&<a href="../../supra-stdlib/doc/decode_bcs.md#0x1_decode_bcs_into_remainder_bytes">decode_bcs::into_remainder_bytes</a>(bcs_bytes)) == 0) {
        <b>return</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_some">option::some</a>(
            <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a> {
                initial_elections_denied,
                max_elections_denied,
                minimum_unbanned_proposers,
                probation_elections
            }
        )
    };
    <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_none">option::none</a>&lt;<a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_BanRegistryParametersV0">BanRegistryParametersV0</a>&gt;()
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
