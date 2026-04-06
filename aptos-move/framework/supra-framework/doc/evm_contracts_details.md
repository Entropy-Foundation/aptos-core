
<a id="0x1_evm_contracts_details"></a>

# Module `0x1::evm_contracts_details`



-  [Resource `EvmContractsDetails`](#0x1_evm_contracts_details_EvmContractsDetails)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_evm_contracts_details_initialize)
-  [Function `upsert_for_next_epoch`](#0x1_evm_contracts_details_upsert_for_next_epoch)
-  [Function `on_new_epoch`](#0x1_evm_contracts_details_on_new_epoch)


<pre><code><b>use</b> <a href="config_buffer.md#0x1_config_buffer">0x1::config_buffer</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map">0x1::simple_map</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_evm_contracts_details_EvmContractsDetails"></a>

## Resource `EvmContractsDetails`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a> <b>has</b> <b>copy</b>, drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>details: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_SimpleMap">simple_map::SimpleMap</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>, <b>address</b>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_evm_contracts_details_EEMPTY_DATA"></a>

Empty keys/values to update config.


<pre><code><b>const</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_EEMPTY_DATA">EEMPTY_DATA</a>: u64 = 1;
</code></pre>



<a id="0x1_evm_contracts_details_EKEYS_VALUES_MISMATCH"></a>

Input keys and values should have the same amount of data


<pre><code><b>const</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>: u64 = 2;
</code></pre>



<a id="0x1_evm_contracts_details_initialize"></a>

## Function `initialize`

Publishes the EvmContractInfo details.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_initialize">initialize</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>assert</b>!(!<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&keys), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_contracts_details.md#0x1_evm_contracts_details_EEMPTY_DATA">EEMPTY_DATA</a>));
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&keys) == <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&values), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_contracts_details.md#0x1_evm_contracts_details_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>));
    <b>let</b> contract_details = <a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a> {
        details: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_new_from">simple_map::new_from</a>(keys, values)
    };
    <b>move_to</b>(supra_framework, contract_details);
    <a href="event.md#0x1_event_emit">event::emit</a>(contract_details);
}
</code></pre>



</details>

<a id="0x1_evm_contracts_details_upsert_for_next_epoch"></a>

## Function `upsert_for_next_epoch`

This can be called by on-chain governance to update on-chain evm contract details for the next epoch.
Keys and values will match in lenght and should not be empty, otherwise the call will fail.
Example usage:
```
supra_framework::evm_contracts_details::upsert_for_next_epoch(&framework_signer, vector["contact1_name"], vector[contract1_address]);
supra_framework::supra_governance::reconfigure(&framework_signer);
```


<pre><code><b>public</b> <b>fun</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_upsert_for_next_epoch">upsert_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_upsert_for_next_epoch">upsert_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;) <b>acquires</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(<a href="account.md#0x1_account">account</a>);
    <b>assert</b>!(!<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&keys), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_contracts_details.md#0x1_evm_contracts_details_EEMPTY_DATA">EEMPTY_DATA</a>));
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&keys) == <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&values), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_contracts_details.md#0x1_evm_contracts_details_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>));
    <b>if</b> (!<b>exists</b>&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework)) {
        std::config_buffer::upsert&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;(<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a> { details: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_new_from">simple_map::new_from</a>(keys, values) });
        <b>return</b>
    };
    <b>let</b> updated_config = *<b>borrow_global</b>&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework);
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_zip">vector::zip</a>(keys, values, |key, value| {
       <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_upsert">simple_map::upsert</a>(&<b>mut</b> updated_config.details, key, value);
    });
    std::config_buffer::upsert&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;(updated_config);
}
</code></pre>



</details>

<a id="0x1_evm_contracts_details_on_new_epoch"></a>

## Function `on_new_epoch`

Only used in reconfigurations to apply the pending <code>EvmContractDetails</code> in buffer, if there is any.
If supra_framework has a EvmContractDetails, then update the new config to supra_framework.
Otherwise, move the new config to supra_framework.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(framework);
    <b>if</b> (<a href="config_buffer.md#0x1_config_buffer_does_exist">config_buffer::does_exist</a>&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;()) {
        <b>let</b> new_config = <a href="config_buffer.md#0x1_config_buffer_extract">config_buffer::extract</a>&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;();
        <b>if</b> (!<b>exists</b>&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework)) {
            <b>move_to</b>(framework, new_config);
        } <b>else</b>  {
            <b>let</b>  old_config = <b>borrow_global_mut</b>&lt;<a href="evm_contracts_details.md#0x1_evm_contracts_details_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework);
            *old_config = new_config;
        };
        <a href="event.md#0x1_event_emit">event::emit</a>(new_config)
    }
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
