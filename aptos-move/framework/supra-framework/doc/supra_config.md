
<a id="0x1_supra_config"></a>

# Module `0x1::supra_config`

Maintains protocol configuation settings specific to Supra. The config is stored in a
Reconfiguration, and may be updated by root.


-  [Resource `SupraConfig`](#0x1_supra_config_SupraConfig)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_supra_config_initialize)
-  [Function `set_for_next_epoch`](#0x1_supra_config_set_for_next_epoch)
-  [Function `on_new_epoch`](#0x1_supra_config_on_new_epoch)
-  [Specification](#@Specification_1)
    -  [High-level Requirements](#high-level-req)
    -  [Module-level Specification](#module-level-spec)
    -  [Function `initialize`](#@Specification_1_initialize)
    -  [Function `set_for_next_epoch`](#@Specification_1_set_for_next_epoch)
    -  [Function `on_new_epoch`](#@Specification_1_on_new_epoch)


<pre><code><b>use</b> <a href="config_buffer.md#0x1_config_buffer">0x1::config_buffer</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
</code></pre>



<a id="0x1_supra_config_SupraConfig"></a>

## Resource `SupraConfig`



<pre><code><b>struct</b> <a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a> <b>has</b> drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_supra_config_EINVALID_CONFIG"></a>

The provided on chain config bytes are empty or invalid


<pre><code><b>const</b> <a href="supra_config.md#0x1_supra_config_EINVALID_CONFIG">EINVALID_CONFIG</a>: u64 = 1;
</code></pre>



<a id="0x1_supra_config_initialize"></a>

## Function `initialize`

Publishes the SupraConfig config.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_config.md#0x1_supra_config_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_config.md#0x1_supra_config_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&config) &gt; 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="supra_config.md#0x1_supra_config_EINVALID_CONFIG">EINVALID_CONFIG</a>));
    <b>move_to</b>(supra_framework, <a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a> { config });
}
</code></pre>



</details>

<a id="0x1_supra_config_set_for_next_epoch"></a>

## Function `set_for_next_epoch`

This can be called by on-chain governance to update on-chain configs for the next epoch.
Example usage:
```
supra_framework::supra_config::set_for_next_epoch(&framework_signer, some_config_bytes);
supra_framework::supra_governance::reconfigure(&framework_signer);
```


<pre><code><b>public</b> <b>fun</b> <a href="supra_config.md#0x1_supra_config_set_for_next_epoch">set_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="supra_config.md#0x1_supra_config_set_for_next_epoch">set_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(<a href="account.md#0x1_account">account</a>);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&config) &gt; 0, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="supra_config.md#0x1_supra_config_EINVALID_CONFIG">EINVALID_CONFIG</a>));
    std::config_buffer::upsert&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;(<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a> {config});
}
</code></pre>



</details>

<a id="0x1_supra_config_on_new_epoch"></a>

## Function `on_new_epoch`

Only used in reconfigurations to apply the pending <code><a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a></code>, if there is any.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_config.md#0x1_supra_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_config.md#0x1_supra_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(framework);
    <b>if</b> (<a href="config_buffer.md#0x1_config_buffer_does_exist">config_buffer::does_exist</a>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;()) {
        <b>let</b> new_config = <a href="config_buffer.md#0x1_config_buffer_extract">config_buffer::extract</a>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;();
        <b>if</b> (<b>exists</b>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;(@supra_framework)) {
            *<b>borrow_global_mut</b>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;(@supra_framework) = new_config;
        } <b>else</b> {
            <b>move_to</b>(framework, new_config);
        };
    }
}
</code></pre>



</details>

<a id="@Specification_1"></a>

## Specification




<a id="high-level-req"></a>

### High-level Requirements

<table>
<tr>
<th>No.</th><th>Requirement</th><th>Criticality</th><th>Implementation</th><th>Enforcement</th>
</tr>

<tr>
<td>1</td>
<td>During genesis, the Supra framework account should be assigned the supra config resource.</td>
<td>Medium</td>
<td>The supra_config::initialize function calls the assert_supra_framework function to ensure that the signer is the supra_framework and then assigns the SupraConfig resource to it.</td>
<td>Formally verified via <a href="#high-level-req-1">initialize</a>.</td>
</tr>

<tr>
<td>2</td>
<td>Only aptos framework account is allowed to update the supra protocol configuration.</td>
<td>Medium</td>
<td>The supra_config::set function ensures that the signer is supra_framework.</td>
<td>Formally verified via <a href="#high-level-req-2">set</a>.</td>
</tr>

<tr>
<td>3</td>
<td>Only a valid configuration can be used during initialization and update.</td>
<td>Medium</td>
<td>Both the initialize and set functions validate the config by ensuring its length to be greater than 0.</td>
<td>Formally verified via <a href="#high-level-req-3.1">initialize</a> and <a href="#high-level-req-3.2">set</a>.</td>
</tr>

</table>




<a id="module-level-spec"></a>

### Module-level Specification


<pre><code><b>pragma</b> verify = <b>true</b>;
<b>pragma</b> aborts_if_is_strict;
<b>invariant</b> [suspendable] <a href="chain_status.md#0x1_chain_status_is_operating">chain_status::is_operating</a>() ==&gt; <b>exists</b>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;(@supra_framework);
</code></pre>



<a id="@Specification_1_initialize"></a>

### Function `initialize`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_config.md#0x1_supra_config_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>


Ensure caller is admin.
Aborts if StateStorageUsage already exists.


<pre><code><b>let</b> addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(supra_framework);
// This enforces <a id="high-level-req-1" href="#high-level-req">high-level requirement 1</a>:
<b>aborts_if</b> !<a href="system_addresses.md#0x1_system_addresses_is_supra_framework_address">system_addresses::is_supra_framework_address</a>(addr);
<b>aborts_if</b> <b>exists</b>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;(@supra_framework);
// This enforces <a id="high-level-req-3.1" href="#high-level-req">high-level requirement 3</a>:
<b>aborts_if</b> !(len(config) &gt; 0);
<b>ensures</b> <b>global</b>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;(addr) == <a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a> { config };
</code></pre>



<a id="@Specification_1_set_for_next_epoch"></a>

### Function `set_for_next_epoch`


<pre><code><b>public</b> <b>fun</b> <a href="supra_config.md#0x1_supra_config_set_for_next_epoch">set_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, config: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>




<pre><code><b>include</b> <a href="config_buffer.md#0x1_config_buffer_SetForNextEpochAbortsIf">config_buffer::SetForNextEpochAbortsIf</a>;
</code></pre>



<a id="@Specification_1_on_new_epoch"></a>

### Function `on_new_epoch`


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="supra_config.md#0x1_supra_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>




<pre><code><b>requires</b> @supra_framework == std::signer::address_of(framework);
<b>include</b> <a href="config_buffer.md#0x1_config_buffer_OnNewEpochRequirement">config_buffer::OnNewEpochRequirement</a>&lt;<a href="supra_config.md#0x1_supra_config_SupraConfig">SupraConfig</a>&gt;;
<b>aborts_if</b> <b>false</b>;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY