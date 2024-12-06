
<a id="0x1_automation_registry"></a>

# Module `0x1::automation_registry`

Supra Automation Registry

This contract is part of the Supra Framework and is designed to manage automated task entries


-  [Resource `AutomationRegistry`](#0x1_automation_registry_AutomationRegistry)
-  [Struct `AutomationTaskMetaData`](#0x1_automation_registry_AutomationTaskMetaData)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_automation_registry_initialize)
-  [Function `withdraw`](#0x1_automation_registry_withdraw)
-  [Function `on_new_epoch`](#0x1_automation_registry_on_new_epoch)
-  [Function `register`](#0x1_automation_registry_register)
-  [Function `get_next_task_index`](#0x1_automation_registry_get_next_task_index)
-  [Function `get_active_task_ids`](#0x1_automation_registry_get_active_task_ids)
-  [Function `get_task_details`](#0x1_automation_registry_get_task_details)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="enumerable_map.md#0x1_enumerable_map">0x1::enumerable_map</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="reconfiguration.md#0x1_reconfiguration">0x1::reconfiguration</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="transaction_context.md#0x1_transaction_context">0x1::transaction_context</a>;
</code></pre>



<a id="0x1_automation_registry_AutomationRegistry"></a>

## Resource `AutomationRegistry`

It tracks entries both pending and completed, organized by unique indices.


<pre><code><b>struct</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> <b>has</b> store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>current_index: u64</code>
</dt>
<dd>
 The current unique index counter for registered tasks. This value increments as new tasks are added.
</dd>
<dt>
<code>automation_gas_limit: u64</code>
</dt>
<dd>
 Automation task gas limit
</dd>
<dt>
<code>duration_upper_limit: u64</code>
</dt>
<dd>
 Automation task duration upper limit.
</dd>
<dt>
<code>registry_fee_address: <b>address</b></code>
</dt>
<dd>
 It's resource address which is use to deposit user automation fee
</dd>
<dt>
<code>registry_fee_address_signer_cap: <a href="account.md#0x1_account_SignerCapability">account::SignerCapability</a></code>
</dt>
<dd>
 Resource account signature capability
</dd>
<dt>
<code>tasks: <a href="enumerable_map.md#0x1_enumerable_map_EnumerableMap">enumerable_map::EnumerableMap</a>&lt;u64, <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>&gt;</code>
</dt>
<dd>
 A collection of automation task entries that are active state.
</dd>
</dl>


</details>

<a id="0x1_automation_registry_AutomationTaskMetaData"></a>

## Struct `AutomationTaskMetaData`

<code><a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a></code> represents a single automation task item, containing metadata.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>id: u64</code>
</dt>
<dd>
 Automation task index in registry
</dd>
<dt>
<code>owner: <b>address</b></code>
</dt>
<dd>
 The address of the task owner.
</dd>
<dt>
<code>payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>
 The function signature associated with the registry entry.
</dd>
<dt>
<code>expiry_time: u64</code>
</dt>
<dd>
 Expiry of the task, represented in a timestamp in second.
</dd>
<dt>
<code>tx_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;</code>
</dt>
<dd>
 The transaction hash of the request transaction.
</dd>
<dt>
<code>max_gas_amount: u64</code>
</dt>
<dd>
 Max gas amount of automation task
</dd>
<dt>
<code>gas_price_cap: u64</code>
</dt>
<dd>
 Maximum gas price cap for the task
</dd>
<dt>
<code>registration_epoch: u64</code>
</dt>
<dd>
 Registration epoch number
</dd>
<dt>
<code>registration_time: u64</code>
</dt>
<dd>
 Registration epoch time
</dd>
<dt>
<code>is_active: bool</code>
</dt>
<dd>
 Flag indicating whether the task is active.
</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_automation_registry_DEFAULT_AUTOMATION_GAS_LIMIT"></a>

Default automation gas limit


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_DEFAULT_AUTOMATION_GAS_LIMIT">DEFAULT_AUTOMATION_GAS_LIMIT</a>: u64 = 1000000;
</code></pre>



<a id="0x1_automation_registry_DEFAULT_DURATION_UPPER_LIMIT"></a>

Default upper gas duration in seconds - 3 days


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_DEFAULT_DURATION_UPPER_LIMIT">DEFAULT_DURATION_UPPER_LIMIT</a>: u64 = 2592000;
</code></pre>



<a id="0x1_automation_registry_EEXPIRY_TIME_UPPER"></a>

Expiry time does not go beyond upper cap duration.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_TIME_UPPER">EEXPIRY_TIME_UPPER</a>: u64 = 2;
</code></pre>



<a id="0x1_automation_registry_ENOT_AUTOMATION_TXN_CONTEXT"></a>

Entry function is called not from automation transaction context.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_ENOT_AUTOMATION_TXN_CONTEXT">ENOT_AUTOMATION_TXN_CONTEXT</a>: u64 = 3;
</code></pre>



<a id="0x1_automation_registry_EREGITRY_NOT_FOUND"></a>

Registry Id not found.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EREGITRY_NOT_FOUND">EREGITRY_NOT_FOUND</a>: u64 = 1;
</code></pre>



<a id="0x1_automation_registry_REGISTRY_RESOURCE_SEED"></a>

Registry resource creation seed


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_REGISTRY_RESOURCE_SEED">REGISTRY_RESOURCE_SEED</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [115, 117, 112, 114, 97, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 97, 117, 116, 111, 109, 97, 116, 105, 111, 110, 95, 114, 101, 103, 105, 115, 116, 114, 121];
</code></pre>



<a id="0x1_automation_registry_initialize"></a>

## Function `initialize`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> (registry_fee_resource_signer, registry_fee_address_signer_cap) = <a href="account.md#0x1_account_create_resource_account">account::create_resource_account</a>(
        supra_framework,
        <a href="automation_registry.md#0x1_automation_registry_REGISTRY_RESOURCE_SEED">REGISTRY_RESOURCE_SEED</a>
    );

    <b>move_to</b>(supra_framework, <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
        current_index: 0,
        automation_gas_limit: <a href="automation_registry.md#0x1_automation_registry_DEFAULT_AUTOMATION_GAS_LIMIT">DEFAULT_AUTOMATION_GAS_LIMIT</a>,
        duration_upper_limit: <a href="automation_registry.md#0x1_automation_registry_DEFAULT_DURATION_UPPER_LIMIT">DEFAULT_DURATION_UPPER_LIMIT</a>,
        registry_fee_address: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(&registry_fee_resource_signer),
        registry_fee_address_signer_cap,
        tasks: <a href="enumerable_map.md#0x1_enumerable_map_new_map">enumerable_map::new_map</a>(),
    })
}
</code></pre>



</details>

<a id="0x1_automation_registry_withdraw"></a>

## Function `withdraw`



<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_withdraw">withdraw</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_withdraw">withdraw</a>() {}
</code></pre>



</details>

<a id="0x1_automation_registry_on_new_epoch"></a>

## Function `on_new_epoch`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_on_new_epoch">on_new_epoch</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_on_new_epoch">on_new_epoch</a>() {
    // todo : should perform clean up and updation of state
}
</code></pre>



</details>

<a id="0x1_automation_registry_register"></a>

## Function `register`

Registers a new automation task entry.


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_register">register</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, expiry_time: u64, max_gas_amount: u64, gas_price_cap: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_register">register</a>(
    owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    expiry_time: u64,
    max_gas_amount: u64,
    gas_price_cap: u64
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>assert</b>!(<a href="transaction_context.md#0x1_transaction_context_has_automation_payload">transaction_context::has_automation_payload</a>(), <a href="automation_registry.md#0x1_automation_registry_ENOT_AUTOMATION_TXN_CONTEXT">ENOT_AUTOMATION_TXN_CONTEXT</a>);
    <b>let</b> registry_data = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);

    // todo : well formedness check of payload_tx
    // todo : pre-paid amount collect from the user
    // todo : duration/expiry in seconds
    // Expiry time does not go beyond upper cap duration set by admin/governance
    <b>assert</b>!(expiry_time &lt; registry_data.duration_upper_limit, <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_TIME_UPPER">EEXPIRY_TIME_UPPER</a>);
    // todo : expiry should not be before the start of next epoch
    // todo : automation_gas_limit check
    // todo : gas_price_cap should not below chain minimum

    registry_data.current_index = registry_data.current_index + 1;

    <b>let</b> automation_task_metadata = <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a> {
        id: registry_data.current_index,
        owner: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(owner),
        payload_tx,
        expiry_time,
        max_gas_amount,
        gas_price_cap,
        is_active: <b>false</b>,
        registration_epoch: <a href="reconfiguration.md#0x1_reconfiguration_current_epoch">reconfiguration::current_epoch</a>(),
        registration_time: <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>(),
        tx_hash: <a href="transaction_context.md#0x1_transaction_context_get_transaction_hash">transaction_context::get_transaction_hash</a>() // todo : need <b>to</b> double check is that work or not
    };

    <a href="enumerable_map.md#0x1_enumerable_map_add_value">enumerable_map::add_value</a>(&<b>mut</b> registry_data.tasks, registry_data.current_index, automation_task_metadata);

    <a href="event.md#0x1_event_emit">event::emit</a>(automation_task_metadata);
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_next_task_index"></a>

## Function `get_next_task_index`

List all the automation task ids


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_next_task_index">get_next_task_index</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_next_task_index">get_next_task_index</a>(): u64 <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.current_index + 1
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_active_task_ids"></a>

## Function `get_active_task_ids`

List all the automation task ids


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_active_task_ids">get_active_task_ids</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_active_task_ids">get_active_task_ids</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt; <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <a href="enumerable_map.md#0x1_enumerable_map_get_map_list">enumerable_map::get_map_list</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks)
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_task_details"></a>

## Function `get_task_details`

Retrieves the details of a automation task entry by its ID.
Returns a tuple where the first element indicates if the registry is completed/failed (<code><b>true</b></code>) or pending (<code><b>false</b></code>),
and the second element contains the <code><a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a></code> details.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_task_details">get_task_details</a>(id: u64): <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_task_details">get_task_details</a>(id: u64): <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a> <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> automation_task_metadata = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>assert</b>!(<a href="enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&automation_task_metadata.tasks, id), <a href="automation_registry.md#0x1_automation_registry_EREGITRY_NOT_FOUND">EREGITRY_NOT_FOUND</a>);
    <a href="enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&automation_task_metadata.tasks, id)
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
