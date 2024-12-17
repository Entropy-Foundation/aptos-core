
<a id="0x1_automation_registry"></a>

# Module `0x1::automation_registry`

Supra Automation Registry

This contract is part of the Supra Framework and is designed to manage automated task entries


-  [Resource `AutomationRegistry`](#0x1_automation_registry_AutomationRegistry)
-  [Struct `AutomationTaskMetaData`](#0x1_automation_registry_AutomationTaskMetaData)
-  [Struct `FeeWithdrawnAdmin`](#0x1_automation_registry_FeeWithdrawnAdmin)
-  [Struct `RefundFeeUser`](#0x1_automation_registry_RefundFeeUser)
-  [Struct `UpdateAutomationGasLimit`](#0x1_automation_registry_UpdateAutomationGasLimit)
-  [Struct `UpdateDurationUpperLimit`](#0x1_automation_registry_UpdateDurationUpperLimit)
-  [Struct `RemoveAutomationTask`](#0x1_automation_registry_RemoveAutomationTask)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_automation_registry_initialize)
-  [Function `on_new_epoch`](#0x1_automation_registry_on_new_epoch)
-  [Function `withdraw_automation_task_fees`](#0x1_automation_registry_withdraw_automation_task_fees)
-  [Function `transfer_fee_to_account_internal`](#0x1_automation_registry_transfer_fee_to_account_internal)
-  [Function `update_automation_gas_limit`](#0x1_automation_registry_update_automation_gas_limit)
-  [Function `update_duration_upper_limit`](#0x1_automation_registry_update_duration_upper_limit)
-  [Function `charge_automation_fee_from_user`](#0x1_automation_registry_charge_automation_fee_from_user)
-  [Function `get_last_epoch_time_second`](#0x1_automation_registry_get_last_epoch_time_second)
-  [Function `register`](#0x1_automation_registry_register)
-  [Function `remove_task`](#0x1_automation_registry_remove_task)
-  [Function `refund_automation_task_fee`](#0x1_automation_registry_refund_automation_task_fee)
-  [Function `get_next_task_index`](#0x1_automation_registry_get_next_task_index)
-  [Function `get_active_task_ids`](#0x1_automation_registry_get_active_task_ids)
-  [Function `get_task_details`](#0x1_automation_registry_get_task_details)
-  [Function `get_registry_fee_address`](#0x1_automation_registry_get_registry_fee_address)
-  [Function `get_gas_committed_for_next_epoch`](#0x1_automation_registry_get_gas_committed_for_next_epoch)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="block.md#0x1_block">0x1::block</a>;
<b>use</b> <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map">0x1::enumerable_map</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="reconfiguration.md#0x1_reconfiguration">0x1::reconfiguration</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="supra_account.md#0x1_supra_account">0x1::supra_account</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="transaction_context.md#0x1_transaction_context">0x1::transaction_context</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
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
 Automation task gas limit.
</dd>
<dt>
<code>duration_upper_limit: u64</code>
</dt>
<dd>
 Automation task duration upper limit.
</dd>
<dt>
<code>gas_committed_for_next_epoch: u64</code>
</dt>
<dd>
 Gas committed for next epoch
</dd>
<dt>
<code>automation_unit_price: u64</code>
</dt>
<dd>
 Automation task unit price per second
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
<code>tasks: <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_EnumerableMap">enumerable_map::EnumerableMap</a>&lt;u64, <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>&gt;</code>
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

<a id="0x1_automation_registry_FeeWithdrawnAdmin"></a>

## Struct `FeeWithdrawnAdmin`

Withdraw user's registration fee event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_FeeWithdrawnAdmin">FeeWithdrawnAdmin</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code><b>to</b>: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>amount: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_automation_registry_RefundFeeUser"></a>

## Struct `RefundFeeUser`

Withdraw user's registration fee event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_RefundFeeUser">RefundFeeUser</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>user: <b>address</b></code>
</dt>
<dd>

</dd>
<dt>
<code>amount: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_automation_registry_UpdateAutomationGasLimit"></a>

## Struct `UpdateAutomationGasLimit`

Update automation gas limit event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_UpdateAutomationGasLimit">UpdateAutomationGasLimit</a> <b>has</b> drop, store
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

<a id="0x1_automation_registry_UpdateDurationUpperLimit"></a>

## Struct `UpdateDurationUpperLimit`

Update duration upper limit event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_UpdateDurationUpperLimit">UpdateDurationUpperLimit</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>duration_upper_limit: u64</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_automation_registry_RemoveAutomationTask"></a>

## Struct `RemoveAutomationTask`

Remove automation task registry event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_RemoveAutomationTask">RemoveAutomationTask</a> <b>has</b> drop, store
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


<a id="0x1_automation_registry_DEFAULT_AUTOMATION_GAS_LIMIT"></a>

The default automation task gas limit


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_DEFAULT_AUTOMATION_GAS_LIMIT">DEFAULT_AUTOMATION_GAS_LIMIT</a>: u64 = 100000000;
</code></pre>



<a id="0x1_automation_registry_DEFAULT_AUTOMATION_UNIT_PRICE"></a>

The default Automation unit price for per second, in Quants


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_DEFAULT_AUTOMATION_UNIT_PRICE">DEFAULT_AUTOMATION_UNIT_PRICE</a>: u64 = 1000;
</code></pre>



<a id="0x1_automation_registry_DEFAULT_DURATION_UPPER_LIMIT"></a>

The default upper limit duration for automation task, specified in seconds (30 days).


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_DEFAULT_DURATION_UPPER_LIMIT">DEFAULT_DURATION_UPPER_LIMIT</a>: u64 = 2592000;
</code></pre>



<a id="0x1_automation_registry_EAUTOMATION_TASK_NOT_EXIST"></a>

Automation task not found


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EAUTOMATION_TASK_NOT_EXIST">EAUTOMATION_TASK_NOT_EXIST</a>: u64 = 7;
</code></pre>



<a id="0x1_automation_registry_EEXPIRY_BEFORE_NEXT_EPOCH"></a>

Expiry time must be after the start of the next epoch


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_BEFORE_NEXT_EPOCH">EEXPIRY_BEFORE_NEXT_EPOCH</a>: u64 = 4;
</code></pre>



<a id="0x1_automation_registry_EEXPIRY_TIME_UPPER"></a>

Expiry time does not go beyond upper cap duration


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_TIME_UPPER">EEXPIRY_TIME_UPPER</a>: u64 = 3;
</code></pre>



<a id="0x1_automation_registry_EGAS_AMOUNT_UPPER"></a>

Gas amount does not go beyond upper cap limit


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EGAS_AMOUNT_UPPER">EGAS_AMOUNT_UPPER</a>: u64 = 5;
</code></pre>



<a id="0x1_automation_registry_EINVALID_EXPIRY_TIME"></a>

Invalid expiry time: it cannot be earlier than the current time


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EINVALID_EXPIRY_TIME">EINVALID_EXPIRY_TIME</a>: u64 = 2;
</code></pre>



<a id="0x1_automation_registry_EINVALID_GAS_PRICE"></a>

Invalid gas price: it cannot be zero


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EINVALID_GAS_PRICE">EINVALID_GAS_PRICE</a>: u64 = 6;
</code></pre>



<a id="0x1_automation_registry_EREGITRY_NOT_FOUND"></a>

Registry Id not found


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EREGITRY_NOT_FOUND">EREGITRY_NOT_FOUND</a>: u64 = 1;
</code></pre>



<a id="0x1_automation_registry_EUNAUTHORIZED_TASK_OWNER"></a>

Unauthorized access: the caller is not the owner of the task


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EUNAUTHORIZED_TASK_OWNER">EUNAUTHORIZED_TASK_OWNER</a>: u64 = 8;
</code></pre>



<a id="0x1_automation_registry_MILLISECOND_CONVERSION_FACTOR"></a>

Conversion factor between microseconds and millisecond || millisecond and second


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_MILLISECOND_CONVERSION_FACTOR">MILLISECOND_CONVERSION_FACTOR</a>: u64 = 1000;
</code></pre>



<a id="0x1_automation_registry_REGISTRY_RESOURCE_SEED"></a>

Registry resource creation seed


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_REGISTRY_RESOURCE_SEED">REGISTRY_RESOURCE_SEED</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [115, 117, 112, 114, 97, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 97, 117, 116, 111, 109, 97, 116, 105, 111, 110, 95, 114, 101, 103, 105, 115, 116, 114, 121];
</code></pre>



<a id="0x1_automation_registry_initialize"></a>

## Function `initialize`



<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> (registry_fee_resource_signer, registry_fee_address_signer_cap) = <a href="account.md#0x1_account_create_resource_account">account::create_resource_account</a>(
        supra_framework,
        <a href="automation_registry.md#0x1_automation_registry_REGISTRY_RESOURCE_SEED">REGISTRY_RESOURCE_SEED</a>
    );

    <b>move_to</b>(supra_framework, <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
        current_index: 0,
        automation_gas_limit: <a href="automation_registry.md#0x1_automation_registry_DEFAULT_AUTOMATION_GAS_LIMIT">DEFAULT_AUTOMATION_GAS_LIMIT</a>,
        duration_upper_limit: <a href="automation_registry.md#0x1_automation_registry_DEFAULT_DURATION_UPPER_LIMIT">DEFAULT_DURATION_UPPER_LIMIT</a>,
        gas_committed_for_next_epoch: 0,
        automation_unit_price: <a href="automation_registry.md#0x1_automation_registry_DEFAULT_AUTOMATION_UNIT_PRICE">DEFAULT_AUTOMATION_UNIT_PRICE</a>,
        registry_fee_address: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(&registry_fee_resource_signer),
        registry_fee_address_signer_cap,
        tasks: <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_new_map">enumerable_map::new_map</a>(),
    })
}
</code></pre>



</details>

<a id="0x1_automation_registry_on_new_epoch"></a>

## Function `on_new_epoch`



<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_on_new_epoch">on_new_epoch</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_on_new_epoch">on_new_epoch</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>let</b> ids = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_map_list">enumerable_map::get_map_list</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks);

    <b>let</b> current_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();
    <b>let</b> epoch_interval = <a href="block.md#0x1_block_get_epoch_interval_secs">block::get_epoch_interval_secs</a>();
    <b>let</b> expired_task_gas = 0;

    // Perform clean up and updation of state
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(ids, |id| {
        <b>let</b> task = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value_mut">enumerable_map::get_value_mut</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);

        // Tasks that are active during this new epoch but will be already expired for the next epoch
        <b>if</b> (task.expiry_time &lt; (current_time + epoch_interval)) {
            expired_task_gas = expired_task_gas + task.max_gas_amount;
        };

        <b>if</b> (task.expiry_time &lt;= current_time) {
            <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_remove_value">enumerable_map::remove_value</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);
        } <b>else</b> <b>if</b> (!task.is_active && task.expiry_time &gt; current_time) {
            task.is_active = <b>true</b>;
        }
    });

    // Adjust the gas committed for the next epoch by subtracting the gas amount of the expired task
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch = <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch - expired_task_gas;
}
</code></pre>



</details>

<a id="0x1_automation_registry_withdraw_automation_task_fees"></a>

## Function `withdraw_automation_task_fees`

Withdraw accumulated automation task fees from the resource account - access by admin


<pre><code>entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_withdraw_automation_task_fees">withdraw_automation_task_fees</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_withdraw_automation_task_fees">withdraw_automation_task_fees</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <b>to</b>: <b>address</b>,
    amount: u64
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <a href="automation_registry.md#0x1_automation_registry_transfer_fee_to_account_internal">transfer_fee_to_account_internal</a>(<b>to</b>, amount);
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry.md#0x1_automation_registry_FeeWithdrawnAdmin">FeeWithdrawnAdmin</a> { <b>to</b>, amount });
}
</code></pre>



</details>

<a id="0x1_automation_registry_transfer_fee_to_account_internal"></a>

## Function `transfer_fee_to_account_internal`

Transfers the specified fee amount from the resource account to the target account.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_transfer_fee_to_account_internal">transfer_fee_to_account_internal</a>(<b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_transfer_fee_to_account_internal">transfer_fee_to_account_internal</a>(<b>to</b>: <b>address</b>, amount: u64) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>let</b> resource_signer = <a href="account.md#0x1_account_create_signer_with_capability">account::create_signer_with_capability</a>(
        &<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.registry_fee_address_signer_cap
    );
    <a href="supra_account.md#0x1_supra_account_transfer">supra_account::transfer</a>(&resource_signer, <b>to</b>, amount);
}
</code></pre>



</details>

<a id="0x1_automation_registry_update_automation_gas_limit"></a>

## Function `update_automation_gas_limit`

Update Automation gas limit


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_automation_gas_limit">update_automation_gas_limit</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, automation_gas_limit: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_automation_gas_limit">update_automation_gas_limit</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    automation_gas_limit: u64
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.automation_gas_limit = automation_gas_limit;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry.md#0x1_automation_registry_UpdateAutomationGasLimit">UpdateAutomationGasLimit</a> { automation_gas_limit });
}
</code></pre>



</details>

<a id="0x1_automation_registry_update_duration_upper_limit"></a>

## Function `update_duration_upper_limit`

Update duration upper limit


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_duration_upper_limit">update_duration_upper_limit</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, duration_upper_limit: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_duration_upper_limit">update_duration_upper_limit</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    duration_upper_limit: u64
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.duration_upper_limit = duration_upper_limit;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry.md#0x1_automation_registry_UpdateDurationUpperLimit">UpdateDurationUpperLimit</a> { duration_upper_limit });
}
</code></pre>



</details>

<a id="0x1_automation_registry_charge_automation_fee_from_user"></a>

## Function `charge_automation_fee_from_user`

Deducts the automation fee from the user's account based on the selected expiry time.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_charge_automation_fee_from_user">charge_automation_fee_from_user</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, fee: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_charge_automation_fee_from_user">charge_automation_fee_from_user</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, fee: u64) {
    // todo : dynamic price calculation is pending
    <b>let</b> registry_fee_address = <a href="automation_registry.md#0x1_automation_registry_get_registry_fee_address">get_registry_fee_address</a>();
    <a href="supra_account.md#0x1_supra_account_transfer">supra_account::transfer</a>(owner, registry_fee_address, fee);
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_last_epoch_time_second"></a>

## Function `get_last_epoch_time_second`

Get last epoch time in second


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_last_epoch_time_second">get_last_epoch_time_second</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_last_epoch_time_second">get_last_epoch_time_second</a>(): u64 {
    <b>let</b> last_epoch_time_ms = <a href="reconfiguration.md#0x1_reconfiguration_last_reconfiguration_time">reconfiguration::last_reconfiguration_time</a>() / <a href="automation_registry.md#0x1_automation_registry_MILLISECOND_CONVERSION_FACTOR">MILLISECOND_CONVERSION_FACTOR</a>;
    last_epoch_time_ms / <a href="automation_registry.md#0x1_automation_registry_MILLISECOND_CONVERSION_FACTOR">MILLISECOND_CONVERSION_FACTOR</a>
}
</code></pre>



</details>

<a id="0x1_automation_registry_register"></a>

## Function `register`

Registers a new automation task entry.


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_register">register</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, expiry_time: u64, max_gas_amount: u64, gas_price_cap: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_register">register</a>(
    owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    expiry_time: u64,
    max_gas_amount: u64,
    gas_price_cap: u64
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> registry_data = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);

    // todo : well formedness check of payload_tx

    <b>let</b> current_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();
    <b>assert</b>!(expiry_time &gt; current_time, <a href="automation_registry.md#0x1_automation_registry_EINVALID_EXPIRY_TIME">EINVALID_EXPIRY_TIME</a>);

    <b>let</b> expiry_time_duration = expiry_time - current_time;
    <b>assert</b>!(expiry_time_duration &lt; registry_data.duration_upper_limit, <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_TIME_UPPER">EEXPIRY_TIME_UPPER</a>);

    <b>let</b> epoch_interval = <a href="block.md#0x1_block_get_epoch_interval_secs">block::get_epoch_interval_secs</a>();
    <b>let</b> last_epoch_time = <a href="automation_registry.md#0x1_automation_registry_get_last_epoch_time_second">get_last_epoch_time_second</a>();
    <b>assert</b>!(expiry_time &gt; (last_epoch_time + epoch_interval), <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_BEFORE_NEXT_EPOCH">EEXPIRY_BEFORE_NEXT_EPOCH</a>);

    registry_data.gas_committed_for_next_epoch = registry_data.gas_committed_for_next_epoch + max_gas_amount;
    <b>assert</b>!(registry_data.gas_committed_for_next_epoch &lt; registry_data.automation_gas_limit, <a href="automation_registry.md#0x1_automation_registry_EGAS_AMOUNT_UPPER">EGAS_AMOUNT_UPPER</a>);

    <b>assert</b>!(gas_price_cap &gt; 0, <a href="automation_registry.md#0x1_automation_registry_EINVALID_GAS_PRICE">EINVALID_GAS_PRICE</a>);

    <b>let</b> fee = expiry_time_duration * registry_data.automation_unit_price;
    <a href="automation_registry.md#0x1_automation_registry_charge_automation_fee_from_user">charge_automation_fee_from_user</a>(owner, fee);

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
        tx_hash: <a href="transaction_context.md#0x1_transaction_context_txn_app_hash">transaction_context::txn_app_hash</a>()
    };

    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_add_value">enumerable_map::add_value</a>(&<b>mut</b> registry_data.tasks, registry_data.current_index, automation_task_metadata);

    <a href="event.md#0x1_event_emit">event::emit</a>(automation_task_metadata);
}
</code></pre>



</details>

<a id="0x1_automation_registry_remove_task"></a>

## Function `remove_task`

Remove Automatioon task entry.


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_remove_task">remove_task</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, registry_id: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_remove_task">remove_task</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, registry_id: u64) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> user_addr = <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(owner);

    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>assert</b>!(<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, registry_id), <a href="automation_registry.md#0x1_automation_registry_EAUTOMATION_TASK_NOT_EXIST">EAUTOMATION_TASK_NOT_EXIST</a>);

    <b>let</b> automation_task_metadata = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, registry_id);
    <b>assert</b>!(automation_task_metadata.owner == user_addr, <a href="automation_registry.md#0x1_automation_registry_EUNAUTHORIZED_TASK_OWNER">EUNAUTHORIZED_TASK_OWNER</a>);

    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_remove_value">enumerable_map::remove_value</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, registry_id);

    // Adjust the gas committed for the next epoch by subtracting the gas amount of the expired task
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch = <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

    // Calculate refund fee and transfer it <b>to</b> user
    <a href="automation_registry.md#0x1_automation_registry_refund_automation_task_fee">refund_automation_task_fee</a>(user_addr, automation_task_metadata, <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.automation_unit_price);

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry.md#0x1_automation_registry_RemoveAutomationTask">RemoveAutomationTask</a> { id: automation_task_metadata.id });
}
</code></pre>



</details>

<a id="0x1_automation_registry_refund_automation_task_fee"></a>

## Function `refund_automation_task_fee`

Refunds the automation task fee to the user who has removed their task registration from the list.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_refund_automation_task_fee">refund_automation_task_fee</a>(user: <b>address</b>, automation_task_metadata: <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>, automation_unit_price: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_refund_automation_task_fee">refund_automation_task_fee</a>(
    user: <b>address</b>,
    automation_task_metadata: <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a>,
    automation_unit_price: u64,
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> current_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();
    <b>let</b> expiry_time_duration = automation_task_metadata.expiry_time - current_time;

    <b>let</b> refund_amount = expiry_time_duration * automation_unit_price;
    <a href="automation_registry.md#0x1_automation_registry_transfer_fee_to_account_internal">transfer_fee_to_account_internal</a>(user, refund_amount);
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry.md#0x1_automation_registry_RefundFeeUser">RefundFeeUser</a> { user, amount: refund_amount });
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_next_task_index"></a>

## Function `get_next_task_index`

Returns next task index in registry


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

    <b>let</b> active_task_ids = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[];
    <b>let</b> ids = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_map_list">enumerable_map::get_map_list</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks);

    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(ids, |id| {
        <b>let</b> task = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);
        <b>if</b> (task.is_active) {
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> active_task_ids, id);
        };
    });
    <b>return</b> active_task_ids
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
    <b>assert</b>!(<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&automation_task_metadata.tasks, id), <a href="automation_registry.md#0x1_automation_registry_EREGITRY_NOT_FOUND">EREGITRY_NOT_FOUND</a>);
    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&automation_task_metadata.tasks, id)
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_registry_fee_address"></a>

## Function `get_registry_fee_address`

Get registry fee resource account address


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_registry_fee_address">get_registry_fee_address</a>(): <b>address</b>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_registry_fee_address">get_registry_fee_address</a>(): <b>address</b> {
    <a href="account.md#0x1_account_create_resource_address">account::create_resource_address</a>(&@supra_framework, <a href="automation_registry.md#0x1_automation_registry_REGISTRY_RESOURCE_SEED">REGISTRY_RESOURCE_SEED</a>)
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_gas_committed_for_next_epoch"></a>

## Function `get_gas_committed_for_next_epoch`

Ge gas committed for next epoch


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_gas_committed_for_next_epoch">get_gas_committed_for_next_epoch</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_gas_committed_for_next_epoch">get_gas_committed_for_next_epoch</a>(): u64 <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> automation_task_metadata = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    automation_task_metadata.gas_committed_for_next_epoch
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
