
<a id="0x1_evm_config"></a>

# Module `0x1::evm_config`



-  [Resource `EvmContractsDetails`](#0x1_evm_config_EvmContractsDetails)
-  [Resource `EvmScalarConfig`](#0x1_evm_config_EvmScalarConfig)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_evm_config_initialize)
-  [Function `upsert_evm_contract_details_for_next_epoch`](#0x1_evm_config_upsert_evm_contract_details_for_next_epoch)
-  [Function `upsert_config_for_next_epoch`](#0x1_evm_config_upsert_config_for_next_epoch)
-  [Function `get_contract_value`](#0x1_evm_config_get_contract_value)
-  [Function `get_scalar_config_value`](#0x1_evm_config_get_scalar_config_value)
-  [Function `validate_scalar_config`](#0x1_evm_config_validate_scalar_config)
-  [Function `is_valid_evm_address`](#0x1_evm_config_is_valid_evm_address)
-  [Function `on_new_epoch`](#0x1_evm_config_on_new_epoch)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs">0x1::bcs</a>;
<b>use</b> <a href="config_buffer.md#0x1_config_buffer">0x1::config_buffer</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map">0x1::simple_map</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_evm_config_EvmContractsDetails"></a>

## Resource `EvmContractsDetails`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a> <b>has</b> <b>copy</b>, drop, store, key
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

<a id="0x1_evm_config_EvmScalarConfig"></a>

## Resource `EvmScalarConfig`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a> <b>has</b> <b>copy</b>, drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>config: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_SimpleMap">simple_map::SimpleMap</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>, u128&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_evm_config_EKEY_NOT_FOUND"></a>

Requested key does not exist in the map


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_EKEY_NOT_FOUND">EKEY_NOT_FOUND</a>: u64 = 4;
</code></pre>



<a id="0x1_evm_config_CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM"></a>

Well-known config key for the EVM gas normalisation denominator.
This u64 value is used to scale EVM gas units into Supra gas units.


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM">CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [101, 118, 109, 95, 103, 97, 115, 95, 110, 111, 114, 109, 97, 108, 105, 122, 97, 116, 105, 111, 110, 95, 100, 101, 110, 111, 109];
</code></pre>



<a id="0x1_evm_config_EEMPTY_DATA"></a>

Empty keys/values to update config.


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_EEMPTY_DATA">EEMPTY_DATA</a>: u64 = 1;
</code></pre>



<a id="0x1_evm_config_EINVALID_EVM_ADDRESS"></a>

Invalid EVM address, valid EVM address must fit in 20 bytes


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_EINVALID_EVM_ADDRESS">EINVALID_EVM_ADDRESS</a>: u64 = 3;
</code></pre>



<a id="0x1_evm_config_EKEYS_VALUES_MISMATCH"></a>

Input keys and values should have the same amount of data


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>: u64 = 2;
</code></pre>



<a id="0x1_evm_config_EMISSING_KEY_OR_INCORRECT_VAL_TYPE"></a>

Required Key is missing or value type is incorrect for a key


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_EMISSING_KEY_OR_INCORRECT_VAL_TYPE">EMISSING_KEY_OR_INCORRECT_VAL_TYPE</a>: u64 = 5;
</code></pre>



<a id="0x1_evm_config_ERESOURCE_ALREADY_EXISTS"></a>

Resource already exist at address


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_ERESOURCE_ALREADY_EXISTS">ERESOURCE_ALREADY_EXISTS</a>: u64 = 6;
</code></pre>



<a id="0x1_evm_config_EVM_ADDRESS_BYTE_LENGTH"></a>

Evm and Move address length


<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_EVM_ADDRESS_BYTE_LENGTH">EVM_ADDRESS_BYTE_LENGTH</a>: u64 = 12;
</code></pre>



<a id="0x1_evm_config_MOVE_ADDRESS_BYTE_LENGTH"></a>



<pre><code><b>const</b> <a href="evm_config.md#0x1_evm_config_MOVE_ADDRESS_BYTE_LENGTH">MOVE_ADDRESS_BYTE_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_evm_config_initialize"></a>

## Function `initialize`

Publishes both the EVM contract address map and the scalar config map.
<code>contract_keys</code>/<code>contract_values</code> must be the same length and every address
must be a valid 20-byte EVM address (upper 12 bytes of the 32-byte Move
address must be zero).  <code>config_keys</code>/<code>config_values</code> must be the same
length and must include all required keys (e.g. evm_gas_normalization_denom).


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_config.md#0x1_evm_config_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, contract_keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;, contract_values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;, config_keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;, config_values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u128&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_config.md#0x1_evm_config_initialize">initialize</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    contract_keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;,
    contract_values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;,
    config_keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;,
    config_values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u128&gt;
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>assert</b>!(!<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&contract_keys), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EEMPTY_DATA">EEMPTY_DATA</a>));
    <b>assert</b>!(!<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&config_keys), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EEMPTY_DATA">EEMPTY_DATA</a>));
    <b>let</b> supra_framework_addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(supra_framework);
    <b>assert</b>!(!<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(supra_framework_addr),<a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="evm_config.md#0x1_evm_config_ERESOURCE_ALREADY_EXISTS">ERESOURCE_ALREADY_EXISTS</a>));
    <b>assert</b>!(!<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(supra_framework_addr),<a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="evm_config.md#0x1_evm_config_ERESOURCE_ALREADY_EXISTS">ERESOURCE_ALREADY_EXISTS</a>));
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&contract_keys) == <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&contract_values),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>)
    );
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&config_keys) == <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&config_values),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>)
    );

    // Check that no contract value is invalid EVM <b>address</b>
    <b>let</b> all_valid_evm_address = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_all">vector::all</a>(&contract_values,
    |v|{ <a href="evm_config.md#0x1_evm_config_is_valid_evm_address">is_valid_evm_address</a>(v) });
    <b>assert</b>!(all_valid_evm_address, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EINVALID_EVM_ADDRESS">EINVALID_EVM_ADDRESS</a>));

    <b>let</b> contract_details = <a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a> {
        details: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_new_from">simple_map::new_from</a>(contract_keys, contract_values)
    };
    <b>move_to</b>(supra_framework, contract_details);
    <a href="event.md#0x1_event_emit">event::emit</a>(contract_details);

    <b>let</b> <a href="evm_config.md#0x1_evm_config">evm_config</a> = <a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a> {
        config: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_new_from">simple_map::new_from</a>(config_keys, config_values)
    };
    <a href="evm_config.md#0x1_evm_config_validate_scalar_config">validate_scalar_config</a>(&<a href="evm_config.md#0x1_evm_config">evm_config</a>);
    <b>move_to</b>(supra_framework, <a href="evm_config.md#0x1_evm_config">evm_config</a>);
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="evm_config.md#0x1_evm_config">evm_config</a>);
}
</code></pre>



</details>

<a id="0x1_evm_config_upsert_evm_contract_details_for_next_epoch"></a>

## Function `upsert_evm_contract_details_for_next_epoch`

This can be called by on-chain governance to update on-chain evm contract
details for the next epoch.
Example usage:
```
supra_framework::evm_config::upsert_evm_contract_details_for_next_epoch(
&framework_signer, vector["contract1_name"], vector[contract1_address]);
supra_framework::supra_governance::reconfigure(&framework_signer);
```


<pre><code><b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_upsert_evm_contract_details_for_next_epoch">upsert_evm_contract_details_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_upsert_evm_contract_details_for_next_epoch">upsert_evm_contract_details_for_next_epoch</a>(
    <a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;,
    values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<b>address</b>&gt;
) <b>acquires</b> <a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(<a href="account.md#0x1_account">account</a>);
    <b>assert</b>!(!<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&keys), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EEMPTY_DATA">EEMPTY_DATA</a>));
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&keys) == <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&values),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>)
    );
    <b>let</b> all_valid_evm_address = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_all">vector::all</a>(&values, |v| { <a href="evm_config.md#0x1_evm_config_is_valid_evm_address">is_valid_evm_address</a>(v) });
    <b>assert</b>!(all_valid_evm_address, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EINVALID_EVM_ADDRESS">EINVALID_EVM_ADDRESS</a>));
    <b>if</b> (!<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework)) {
        std::config_buffer::upsert&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(
            <a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a> { details: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_new_from">simple_map::new_from</a>(keys, values) }
        );
        <b>return</b>
    };
    <b>let</b> updated_config = *<b>borrow_global</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework);
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_zip">vector::zip</a>(keys, values, |key, value| {
        <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_upsert">simple_map::upsert</a>(&<b>mut</b> updated_config.details, key, value);
    });
    std::config_buffer::upsert&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(updated_config);
}
</code></pre>



</details>

<a id="0x1_evm_config_upsert_config_for_next_epoch"></a>

## Function `upsert_config_for_next_epoch`

This can be called by on-chain governance to update on-chain evm config
for the next epoch.  Values are plain u128 scalars.
Example usage:
```
supra_framework::evm_config::upsert_config_for_next_epoch(
&framework_signer, vector["config_key"], vector[new_value]);
supra_framework::supra_governance::reconfigure(&framework_signer);
```


<pre><code><b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_upsert_config_for_next_epoch">upsert_config_for_next_epoch</a>(<a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;, values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u128&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_upsert_config_for_next_epoch">upsert_config_for_next_epoch</a>(
    <a href="account.md#0x1_account">account</a>: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    keys: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;,
    values: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u128&gt;
) <b>acquires</b> <a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(<a href="account.md#0x1_account">account</a>);
    <b>assert</b>!(!<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&keys), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EEMPTY_DATA">EEMPTY_DATA</a>));
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&keys) == <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&values),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EKEYS_VALUES_MISMATCH">EKEYS_VALUES_MISMATCH</a>)
    );
    <b>if</b> (!<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(@supra_framework)) {
        <b>let</b> <a href="evm_config.md#0x1_evm_config">evm_config</a> =
            <a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a> { config: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_new_from">simple_map::new_from</a>(keys, values) };
        // Config did not exist earlier, so validate the config for
        // presence of required keys and value type match
        <a href="evm_config.md#0x1_evm_config_validate_scalar_config">validate_scalar_config</a>(&<a href="evm_config.md#0x1_evm_config">evm_config</a>);
        std::config_buffer::upsert&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(<a href="evm_config.md#0x1_evm_config">evm_config</a>);
        <b>return</b>;
    };
    // Copy existing config
    <b>let</b> updated_config = *<b>borrow_global</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(@supra_framework);
    // We are never removing existing keys so by induction <b>if</b> all required
    // keys are present in config during initialization
    // they will be there later <b>as</b> well, so no need <b>to</b> validate here
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_zip">vector::zip</a>(keys, values, |key, value| {
        <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_upsert">simple_map::upsert</a>(&<b>mut</b> updated_config.config, key, value);
    });
    std::config_buffer::upsert&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(updated_config);
}
</code></pre>



</details>

<a id="0x1_evm_config_get_contract_value"></a>

## Function `get_contract_value`

Returns the contract address stored under <code>key</code> in the EvmContractsDetails map.
Aborts with EKEY_NOT_FOUND if the resource has not been initialised or the key
is not present in the map.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_get_contract_value">get_contract_value</a>(key: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_get_contract_value">get_contract_value</a>(key: String): <b>address</b> <b>acquires</b> <a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a> {
    <b>assert</b>!(<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="evm_config.md#0x1_evm_config_EKEY_NOT_FOUND">EKEY_NOT_FOUND</a>));
    <b>let</b> details = <b>borrow_global</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework);
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(&details.details, &key),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="evm_config.md#0x1_evm_config_EKEY_NOT_FOUND">EKEY_NOT_FOUND</a>)
    );
    *<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow">simple_map::borrow</a>(&details.details, &key)
}
</code></pre>



</details>

<a id="0x1_evm_config_get_scalar_config_value"></a>

## Function `get_scalar_config_value`

Returns the u128 value stored under <code>key</code> in the EvmScalarConfig map.
Aborts with EKEY_NOT_FOUND if the resource has not been initialised or the key
is not present in the map.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_get_scalar_config_value">get_scalar_config_value</a>(key: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>): u128
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="evm_config.md#0x1_evm_config_get_scalar_config_value">get_scalar_config_value</a>(key: String): u128 <b>acquires</b> <a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a> {
    <b>assert</b>!(<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(@supra_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="evm_config.md#0x1_evm_config_EKEY_NOT_FOUND">EKEY_NOT_FOUND</a>));
    <b>let</b> config = <b>borrow_global</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(@supra_framework);
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(&config.config, &key),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="evm_config.md#0x1_evm_config_EKEY_NOT_FOUND">EKEY_NOT_FOUND</a>)
    );
    *<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow">simple_map::borrow</a>(&config.config, &key)
}
</code></pre>



</details>

<a id="0x1_evm_config_validate_scalar_config"></a>

## Function `validate_scalar_config`



<pre><code><b>fun</b> <a href="evm_config.md#0x1_evm_config_validate_scalar_config">validate_scalar_config</a>(<a href="evm_config.md#0x1_evm_config">evm_config</a>: &<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">evm_config::EvmScalarConfig</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="evm_config.md#0x1_evm_config_validate_scalar_config">validate_scalar_config</a>(<a href="evm_config.md#0x1_evm_config">evm_config</a>: &<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>) {
    <b>let</b> required_keys = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_utf8">string::utf8</a>(<a href="evm_config.md#0x1_evm_config_CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM">CONFIG_KEY_EVM_GAS_NORMALIZATION_DENOM</a>)];
    // With u128 <b>as</b> the value type, the Move type system prevents type mismatches at
    // compile time. The only meaningful runtime check is key presence.
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_reverse">vector::for_each_reverse</a>(required_keys, |rk| {
        <b>assert</b>!(
            <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>&lt;String, u128&gt;(&<a href="evm_config.md#0x1_evm_config">evm_config</a>.config, &rk),
            <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="evm_config.md#0x1_evm_config_EMISSING_KEY_OR_INCORRECT_VAL_TYPE">EMISSING_KEY_OR_INCORRECT_VAL_TYPE</a>)
        );
    });
}
</code></pre>



</details>

<a id="0x1_evm_config_is_valid_evm_address"></a>

## Function `is_valid_evm_address`



<pre><code><b>fun</b> <a href="evm_config.md#0x1_evm_config_is_valid_evm_address">is_valid_evm_address</a>(addr: &<b>address</b>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="evm_config.md#0x1_evm_config_is_valid_evm_address">is_valid_evm_address</a>(addr: &<b>address</b>): bool {
    // BCS serialises a Move `<b>address</b>` <b>as</b> a raw fixed-size 32-byte array in
    // big-endian order (most-significant byte first).  An EVM <b>address</b> is only
    // 20 bytes wide, so when a 20-byte EVM <b>address</b> is stored in a 32-byte Move
    // <b>address</b> the EVM bytes occupy the last 20 positions (indices 12-31) and the
    // leading 12 bytes (indices 0-11) must all be zero.
    // We iterate only over that prefix and bail immediately on the first non-zero
    // byte <b>to</b> avoid unnecessary work.
    <b>let</b> evm_addr_bytes = <a href="../../aptos-stdlib/../move-stdlib/doc/bcs.md#0x1_bcs_to_bytes">bcs::to_bytes</a>(addr);

    // Sanity check: BCS encoding of an <b>address</b> is always 32 bytes. If somehow
    // the length differs, the <b>address</b> cannot be valid.
    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&evm_addr_bytes) != <a href="evm_config.md#0x1_evm_config_MOVE_ADDRESS_BYTE_LENGTH">MOVE_ADDRESS_BYTE_LENGTH</a>) {
        <b>return</b> <b>false</b>
    };

    // Check that all 12 high-order prefix bytes are zero.  A non-zero byte here
    // means the value cannot fit in 20 bytes and is therefore not a valid EVM <b>address</b>.
    <b>let</b> i = 0u64;
    <b>let</b> addr_length_diff = <a href="evm_config.md#0x1_evm_config_MOVE_ADDRESS_BYTE_LENGTH">MOVE_ADDRESS_BYTE_LENGTH</a> - <a href="evm_config.md#0x1_evm_config_EVM_ADDRESS_BYTE_LENGTH">EVM_ADDRESS_BYTE_LENGTH</a>;
    <b>while</b> (i &lt; addr_length_diff) {
        <b>if</b> (*<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&evm_addr_bytes, i) != 0u8) {
            // Non-zero prefix byte found - not a valid 20-byte EVM <b>address</b>.
            <b>return</b> <b>false</b>
        };
        i = i + 1;
    };

    <b>true</b>
}
</code></pre>



</details>

<a id="0x1_evm_config_on_new_epoch"></a>

## Function `on_new_epoch`

Only used in reconfigurations to apply the pending configs in buffer, if any.
If supra_framework already holds the resource, overwrite it; otherwise move it in.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_config.md#0x1_evm_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="evm_config.md#0x1_evm_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>, <a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(framework);
    <b>if</b> (<a href="config_buffer.md#0x1_config_buffer_does_exist">config_buffer::does_exist</a>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;()) {
        //TODO: change <b>to</b> extract_v2 when extract_v2 is merged and available
        <b>let</b> new_config = <a href="config_buffer.md#0x1_config_buffer_extract">config_buffer::extract</a>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;();
        <b>if</b> (!<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework)) {
            <b>move_to</b>(framework, new_config);
        } <b>else</b> {
            <b>let</b> old_config = <b>borrow_global_mut</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmContractsDetails">EvmContractsDetails</a>&gt;(@supra_framework);
            *old_config = new_config;
        };
        <a href="event.md#0x1_event_emit">event::emit</a>(new_config)
    };
    <b>if</b> (<a href="config_buffer.md#0x1_config_buffer_does_exist">config_buffer::does_exist</a>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;()) {
        // change <b>to</b> extract_v2 when it is available
        <b>let</b> new_config = <a href="config_buffer.md#0x1_config_buffer_extract">config_buffer::extract</a>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;();
        <b>if</b> (!<b>exists</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(@supra_framework)) {
            <b>move_to</b>(framework, new_config);
        } <b>else</b> {
            <b>let</b> old_config = <b>borrow_global_mut</b>&lt;<a href="evm_config.md#0x1_evm_config_EvmScalarConfig">EvmScalarConfig</a>&gt;(@supra_framework);
            *old_config = new_config;
        };
        <a href="event.md#0x1_event_emit">event::emit</a>(new_config)
    };
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
