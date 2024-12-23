
<a id="0x1_automation_registry_state"></a>

# Module `0x1::automation_registry_state`

Supra Automation Registry State

This contract is part of the Supra Framework and is designed to manage automated task entries


-  [Resource `AutomationRegistryState`](#0x1_automation_registry_state_AutomationRegistryState)
-  [Struct `AutomationTaskMetaData`](#0x1_automation_registry_state_AutomationTaskMetaData)
-  [Struct `UpdateAutomationGasLimit`](#0x1_automation_registry_state_UpdateAutomationGasLimit)
-  [Struct `CanclledAutomationTask`](#0x1_automation_registry_state_CanclledAutomationTask)
-  [Constants](#@Constants_0)
-  [Function `task_expiry_time`](#0x1_automation_registry_state_task_expiry_time)
-  [Function `initialize`](#0x1_automation_registry_state_initialize)
-  [Function `on_new_epoch`](#0x1_automation_registry_state_on_new_epoch)
-  [Function `register`](#0x1_automation_registry_state_register)
-  [Function `cancel_task`](#0x1_automation_registry_state_cancel_task)
-  [Function `update_automation_gas_limit`](#0x1_automation_registry_state_update_automation_gas_limit)
-  [Function `get_active_task_ids`](#0x1_automation_registry_state_get_active_task_ids)
-  [Function `get_task_details`](#0x1_automation_registry_state_get_task_details)
-  [Function `has_active_task_with_id`](#0x1_automation_registry_state_has_active_task_with_id)
-  [Function `get_next_task_index`](#0x1_automation_registry_state_get_next_task_index)
-  [Function `get_gas_committed_for_next_epoch`](#0x1_automation_registry_state_get_gas_committed_for_next_epoch)


<pre><code><b>use</b> <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map">0x1::enumerable_map</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_automation_registry_state_AutomationRegistryState"></a>

## Resource `AutomationRegistryState`

It tracks entries both pending and completed, organized by unique indices.


<pre><code><b>struct</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> <b>has</b> store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>tasks: <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_EnumerableMap">enumerable_map::EnumerableMap</a>&lt;u64, <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">automation_registry_state::AutomationTaskMetaData</a>&gt;</code>
</dt>
<dd>
 A collection of automation task entries that are active state.
</dd>
<dt>
<code>current_index: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>gas_committed_for_next_epoch: u64</code>
</dt>
<dd>

</dd>
<dt>
<code>automation_gas_limit: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_automation_registry_state_AutomationTaskMetaData"></a>

## Struct `AutomationTaskMetaData`

<code><a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">AutomationTaskMetaData</a></code> represents a single automation task item, containing metadata.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">AutomationTaskMetaData</a> <b>has</b> <b>copy</b>, drop, store
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
<code>state: u8</code>
</dt>
<dd>
 Flag indicating whether the task is active, canclled or pending.
</dd>
</dl>


</details>

<a id="0x1_automation_registry_state_UpdateAutomationGasLimit"></a>

## Struct `UpdateAutomationGasLimit`

Update automation gas limit event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry_state.md#0x1_automation_registry_state_UpdateAutomationGasLimit">UpdateAutomationGasLimit</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>automation_gas_limit: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_automation_registry_state_CanclledAutomationTask"></a>

## Struct `CanclledAutomationTask`

Remove automation task registry event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry_state.md#0x1_automation_registry_state_CanclledAutomationTask">CanclledAutomationTask</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>id: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_automation_registry_state_CANCELLED"></a>



<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_CANCELLED">CANCELLED</a>: u8 = 2;
</code></pre>



<a id="0x1_automation_registry_state_ACTIVE"></a>



<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_ACTIVE">ACTIVE</a>: u8 = 1;
</code></pre>



<a id="0x1_automation_registry_state_EAUTOMATION_TASK_NOT_FOUND"></a>

Task with provided Id not found


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EAUTOMATION_TASK_NOT_FOUND">EAUTOMATION_TASK_NOT_FOUND</a>: u64 = 4;
</code></pre>



<a id="0x1_automation_registry_state_EGAS_AMOUNT_UPPER"></a>

Gas amount does not go beyond upper cap limit


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EGAS_AMOUNT_UPPER">EGAS_AMOUNT_UPPER</a>: u64 = 5;
</code></pre>



<a id="0x1_automation_registry_state_EINVALID_CANCELLATION"></a>

Trying to cancel a task which is already cancelled.


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_CANCELLATION">EINVALID_CANCELLATION</a>: u64 = 10;
</code></pre>



<a id="0x1_automation_registry_state_EINVALID_COMMITTED_GAS_CALCULATION"></a>

Upon new epoch entry failed to propertly calculated committed gas for the next epoch.
It is greater than current epoch committed gas.


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_COMMITTED_GAS_CALCULATION">EINVALID_COMMITTED_GAS_CALCULATION</a>: u64 = 7;
</code></pre>



<a id="0x1_automation_registry_state_EINVALID_EXPIRY_TIME"></a>

Invalid expiry time: it cannot be earlier than the current time


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_EXPIRY_TIME">EINVALID_EXPIRY_TIME</a>: u64 = 1;
</code></pre>



<a id="0x1_automation_registry_state_EINVALID_GAS_PRICE"></a>

Invalid gas price: it cannot be zero


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_GAS_PRICE">EINVALID_GAS_PRICE</a>: u64 = 2;
</code></pre>



<a id="0x1_automation_registry_state_EINVALID_MAX_GAS_AMOUNT"></a>

Invalid max gas amount for automated task: it cannot be zero


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_MAX_GAS_AMOUNT">EINVALID_MAX_GAS_AMOUNT</a>: u64 = 3;
</code></pre>



<a id="0x1_automation_registry_state_EINVALID_TXN_HASH"></a>

Transactoin hash that registring current task is invalid. Lenght should be 32.


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_TXN_HASH">EINVALID_TXN_HASH</a>: u64 = 8;
</code></pre>



<a id="0x1_automation_registry_state_EUNACCEPTABLE_AUTOMATION_GAS_LIMIT"></a>

Current committed gas amount is greater than the automation gas limit.


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EUNACCEPTABLE_AUTOMATION_GAS_LIMIT">EUNACCEPTABLE_AUTOMATION_GAS_LIMIT</a>: u64 = 9;
</code></pre>



<a id="0x1_automation_registry_state_EUNAUTHORIZED_TASK_OWNER"></a>

Unauthorized access: the caller is not the owner of the task


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_EUNAUTHORIZED_TASK_OWNER">EUNAUTHORIZED_TASK_OWNER</a>: u64 = 6;
</code></pre>



<a id="0x1_automation_registry_state_MICROSECS_CONVERSION_FACTOR"></a>

Conversion factor between microseconds and second


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_MICROSECS_CONVERSION_FACTOR">MICROSECS_CONVERSION_FACTOR</a>: u64 = 1000000;
</code></pre>



<a id="0x1_automation_registry_state_PENDING"></a>

Constants describing task state.


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_PENDING">PENDING</a>: u8 = 0;
</code></pre>



<a id="0x1_automation_registry_state_TXN_HASH_LENGTH"></a>

The lenght of the transaction hash.


<pre><code><b>const</b> <a href="automation_registry_state.md#0x1_automation_registry_state_TXN_HASH_LENGTH">TXN_HASH_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_automation_registry_state_task_expiry_time"></a>

## Function `task_expiry_time`



<pre><code><b>public</b> <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_task_expiry_time">task_expiry_time</a>(task: &<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">automation_registry_state::AutomationTaskMetaData</a>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_task_expiry_time">task_expiry_time</a>(task: &<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">AutomationTaskMetaData</a>): u64 {
    task.expiry_time
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_initialize"></a>

## Function `initialize`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, automation_gas_limit: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, automation_gas_limit: u64) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>move_to</b>(supra_framework, <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
        tasks: <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_new_map">enumerable_map::new_map</a>(),
        current_index: 0,
        gas_committed_for_next_epoch: 0,
        automation_gas_limit
    })
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_on_new_epoch"></a>

## Function `on_new_epoch`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_on_new_epoch">on_new_epoch</a>(epoch_interval_micro: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_on_new_epoch">on_new_epoch</a>(epoch_interval_micro: u64) <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> state = <b>borrow_global_mut</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    <b>let</b> ids = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_map_list">enumerable_map::get_map_list</a>(&state.tasks);

    <b>let</b> epoch_interval_secs = epoch_interval_micro / <a href="automation_registry_state.md#0x1_automation_registry_state_MICROSECS_CONVERSION_FACTOR">MICROSECS_CONVERSION_FACTOR</a>;
    <b>let</b> current_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();
    <b>let</b> gas_committed_for_next_epoch = 0;

    // Perform clean up and updation of state
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(ids, |id| {
        <b>let</b> task = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value_mut">enumerable_map::get_value_mut</a>(&<b>mut</b> state.tasks, id);

        // Tasks that are active during next epoch and are not cancled
        <b>if</b> (task.state != <a href="automation_registry_state.md#0x1_automation_registry_state_CANCELLED">CANCELLED</a> && task.expiry_time &gt; (current_time + epoch_interval_secs) ) {
            gas_committed_for_next_epoch = gas_committed_for_next_epoch + task.max_gas_amount;
        };

        // Drop or activate task
        <b>if</b> (task.expiry_time &lt;= current_time || task.state == <a href="automation_registry_state.md#0x1_automation_registry_state_CANCELLED">CANCELLED</a>) {
            <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_remove_value">enumerable_map::remove_value</a>(&<b>mut</b> state.tasks, id);
        } <b>else</b> {
            task.state = <a href="automation_registry_state.md#0x1_automation_registry_state_ACTIVE">ACTIVE</a>;
        }
    });

    state.gas_committed_for_next_epoch = gas_committed_for_next_epoch;
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_register"></a>

## Function `register`

Registers a new automation task entry.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_register">register</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, expiry_time: u64, max_gas_amount: u64, gas_price_cap: u64, registration_epoch: u64, tx_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_register">register</a>(
    owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    expiry_time: u64,
    max_gas_amount: u64,
    gas_price_cap: u64,
    registration_epoch: u64,
    tx_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
) <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> registry_data = <b>borrow_global_mut</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    <b>let</b> registration_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();

    <b>assert</b>!(expiry_time &gt; registration_time, <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_EXPIRY_TIME">EINVALID_EXPIRY_TIME</a>);
    <b>assert</b>!(gas_price_cap &gt; 0, <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_GAS_PRICE">EINVALID_GAS_PRICE</a>);
    <b>assert</b>!(max_gas_amount &gt; 0, <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_MAX_GAS_AMOUNT">EINVALID_MAX_GAS_AMOUNT</a>);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&tx_hash) == <a href="automation_registry_state.md#0x1_automation_registry_state_TXN_HASH_LENGTH">TXN_HASH_LENGTH</a>, <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_TXN_HASH">EINVALID_TXN_HASH</a>);

    <b>let</b> committed_gas = registry_data.gas_committed_for_next_epoch + max_gas_amount;
    <b>assert</b>!(committed_gas &lt; registry_data.automation_gas_limit, <a href="automation_registry_state.md#0x1_automation_registry_state_EGAS_AMOUNT_UPPER">EGAS_AMOUNT_UPPER</a>);
    registry_data.gas_committed_for_next_epoch = committed_gas;
    <b>let</b> task_index = registry_data.current_index;

    <b>let</b> automation_task_metadata = <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">AutomationTaskMetaData</a> {
        id: task_index,
        owner: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(owner),
        payload_tx,
        expiry_time,
        max_gas_amount,
        gas_price_cap,
        state: <a href="automation_registry_state.md#0x1_automation_registry_state_PENDING">PENDING</a>,
        registration_epoch,
        registration_time,
        tx_hash,
    };

    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_add_value">enumerable_map::add_value</a>(&<b>mut</b> registry_data.tasks, task_index, automation_task_metadata);
    registry_data.current_index = registry_data.current_index + 1;
    <a href="event.md#0x1_event_emit">event::emit</a>(automation_task_metadata);
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_cancel_task"></a>

## Function `cancel_task`

Cancel Automation task with specified id.
If the task was active its state is updated to be CANCELLED. Otherwise task is removed form the list.
Committed gas-limit is updated accordingly.
Only existing task can be cancled and only by task onwer.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_cancel_task">cancel_task</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, id: u64): <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">automation_registry_state::AutomationTaskMetaData</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> (<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_cancel_task">cancel_task</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, id: u64): <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">AutomationTaskMetaData</a> <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> state = <b>borrow_global_mut</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    <b>assert</b>!(<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&state.tasks, id), <a href="automation_registry_state.md#0x1_automation_registry_state_EAUTOMATION_TASK_NOT_FOUND">EAUTOMATION_TASK_NOT_FOUND</a>);

    <b>let</b> automation_task_metadata = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&state.tasks, id);
    <b>assert</b>!(automation_task_metadata.owner == <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(owner), <a href="automation_registry_state.md#0x1_automation_registry_state_EUNAUTHORIZED_TASK_OWNER">EUNAUTHORIZED_TASK_OWNER</a>);
    <b>assert</b>!(automation_task_metadata.state != <a href="automation_registry_state.md#0x1_automation_registry_state_CANCELLED">CANCELLED</a>, <a href="automation_registry_state.md#0x1_automation_registry_state_EINVALID_CANCELLATION">EINVALID_CANCELLATION</a>);
    <b>if</b> (automation_task_metadata.state == <a href="automation_registry_state.md#0x1_automation_registry_state_PENDING">PENDING</a>) {
        <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_remove_value">enumerable_map::remove_value</a>(&<b>mut</b> state.tasks, id);
    } <b>else</b> <b>if</b> (automation_task_metadata.state == <a href="automation_registry_state.md#0x1_automation_registry_state_ACTIVE">ACTIVE</a>) {
        automation_task_metadata.state = <a href="automation_registry_state.md#0x1_automation_registry_state_CANCELLED">CANCELLED</a>;
        <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_update_value">enumerable_map::update_value</a>(&<b>mut</b> state.tasks, id, automation_task_metadata);
    };

    // Adjust the gas committed for the next epoch by subtracting the gas amount of the cancelled task
    state.gas_committed_for_next_epoch = state.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry_state.md#0x1_automation_registry_state_CanclledAutomationTask">CanclledAutomationTask</a> { id: automation_task_metadata.id });
    automation_task_metadata
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_update_automation_gas_limit"></a>

## Function `update_automation_gas_limit`

Update Automation gas limit


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_update_automation_gas_limit">update_automation_gas_limit</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, automation_gas_limit: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> (<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_update_automation_gas_limit">update_automation_gas_limit</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    automation_gas_limit: u64
) <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> state = <b>borrow_global_mut</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    <b>assert</b>!(state.gas_committed_for_next_epoch &lt; automation_gas_limit, <a href="automation_registry_state.md#0x1_automation_registry_state_EUNACCEPTABLE_AUTOMATION_GAS_LIMIT">EUNACCEPTABLE_AUTOMATION_GAS_LIMIT</a>);

    state.automation_gas_limit = automation_gas_limit;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry_state.md#0x1_automation_registry_state_UpdateAutomationGasLimit">UpdateAutomationGasLimit</a> { automation_gas_limit });
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_get_active_task_ids"></a>

## Function `get_active_task_ids`

List all the automation task ids


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_active_task_ids">get_active_task_ids</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_active_task_ids">get_active_task_ids</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt; <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> state = <b>borrow_global</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);

    <b>let</b> active_task_ids = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> ids = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_map_list">enumerable_map::get_map_list</a>(&state.tasks);

    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(ids, |id| {
        <b>let</b> task = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&state.tasks, id);
        <b>if</b> (task.state != <a href="automation_registry_state.md#0x1_automation_registry_state_PENDING">PENDING</a>) {
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> active_task_ids, id);
        };
    });
    <b>return</b> active_task_ids
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_get_task_details"></a>

## Function `get_task_details`

Retrieves the details of a automation task entry by its ID.
Error will be returned if entry with specified ID does not exist.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_task_details">get_task_details</a>(id: u64): <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">automation_registry_state::AutomationTaskMetaData</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> (<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_task_details">get_task_details</a>(id: u64): <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationTaskMetaData">AutomationTaskMetaData</a> <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> automation_task_metadata = <b>borrow_global</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    <b>assert</b>!(<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&automation_task_metadata.tasks, id), <a href="automation_registry_state.md#0x1_automation_registry_state_EAUTOMATION_TASK_NOT_FOUND">EAUTOMATION_TASK_NOT_FOUND</a>);
    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&automation_task_metadata.tasks, id)
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_has_active_task_with_id"></a>

## Function `has_active_task_with_id`

Checks whether there is an active task in registry with specified input task id.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_has_active_task_with_id">has_active_task_with_id</a>(id: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_has_active_task_with_id">has_active_task_with_id</a>(id: u64): bool <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> automation_task_metadata = <b>borrow_global</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    <b>if</b> (<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&automation_task_metadata.tasks, id)) {
        <b>let</b> value = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&automation_task_metadata.tasks, id);
        value.state != <a href="automation_registry_state.md#0x1_automation_registry_state_PENDING">PENDING</a>
    } <b>else</b>  {
        <b>false</b>
    }
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_get_next_task_index"></a>

## Function `get_next_task_index`

Returns next task index in registry


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_next_task_index">get_next_task_index</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> (<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_next_task_index">get_next_task_index</a>(): u64 <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> state = <b>borrow_global</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    state.current_index
}
</code></pre>



</details>

<a id="0x1_automation_registry_state_get_gas_committed_for_next_epoch"></a>

## Function `get_gas_committed_for_next_epoch`

Ge gas committed for next epoch


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_gas_committed_for_next_epoch">get_gas_committed_for_next_epoch</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry_state.md#0x1_automation_registry_state_get_gas_committed_for_next_epoch">get_gas_committed_for_next_epoch</a>(): u64 <b>acquires</b> <a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a> {
    <b>let</b> state = <b>borrow_global</b>&lt;<a href="automation_registry_state.md#0x1_automation_registry_state_AutomationRegistryState">AutomationRegistryState</a>&gt;(@supra_framework);
    state.gas_committed_for_next_epoch
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
