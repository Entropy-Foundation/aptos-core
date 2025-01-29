
<a id="0x1_automation_registry"></a>

# Module `0x1::automation_registry`

Supra Automation Registry

This contract is part of the Supra Framework and is designed to manage automated task entries


-  [Resource `ActiveAutomationRegistryConfig`](#0x1_automation_registry_ActiveAutomationRegistryConfig)
-  [Resource `AutomationRegistryConfig`](#0x1_automation_registry_AutomationRegistryConfig)
-  [Resource `AutomationRegistry`](#0x1_automation_registry_AutomationRegistry)
-  [Resource `AutomationEpochInfo`](#0x1_automation_registry_AutomationEpochInfo)
-  [Resource `AutomationTaskMetaData`](#0x1_automation_registry_AutomationTaskMetaData)
-  [Struct `FeeWithdrawnAdmin`](#0x1_automation_registry_FeeWithdrawnAdmin)
-  [Struct `AutomationCancellationRefund`](#0x1_automation_registry_AutomationCancellationRefund)
-  [Struct `CancelledAutomationTask`](#0x1_automation_registry_CancelledAutomationTask)
-  [Constants](#@Constants_0)
-  [Function `initializate_by_default`](#0x1_automation_registry_initializate_by_default)
-  [Function `initialize`](#0x1_automation_registry_initialize)
-  [Function `on_new_epoch`](#0x1_automation_registry_on_new_epoch)
-  [Function `fee_charges_on_new_epoch`](#0x1_automation_registry_fee_charges_on_new_epoch)
-  [Function `fee_charges_on_new_epoch_for_single_task`](#0x1_automation_registry_fee_charges_on_new_epoch_for_single_task)
-  [Function `update_config_from_buffer`](#0x1_automation_registry_update_config_from_buffer)
-  [Function `withdraw_automation_task_fees`](#0x1_automation_registry_withdraw_automation_task_fees)
-  [Function `transfer_fee_to_account_internal`](#0x1_automation_registry_transfer_fee_to_account_internal)
-  [Function `update_config`](#0x1_automation_registry_update_config)
-  [Function `register`](#0x1_automation_registry_register)
-  [Function `check_registration_task_duration`](#0x1_automation_registry_check_registration_task_duration)
-  [Function `cancel_task`](#0x1_automation_registry_cancel_task)
-  [Function `refund_automation_task_fee`](#0x1_automation_registry_refund_automation_task_fee)
-  [Function `update_epoch_interval_in_registry`](#0x1_automation_registry_update_epoch_interval_in_registry)
-  [Function `get_next_task_index`](#0x1_automation_registry_get_next_task_index)
-  [Function `get_active_task_ids`](#0x1_automation_registry_get_active_task_ids)
-  [Function `get_task_details`](#0x1_automation_registry_get_task_details)
-  [Function `has_sender_active_task_with_id`](#0x1_automation_registry_has_sender_active_task_with_id)
-  [Function `get_registry_fee_address`](#0x1_automation_registry_get_registry_fee_address)
-  [Function `get_gas_committed_for_next_epoch`](#0x1_automation_registry_get_gas_committed_for_next_epoch)
-  [Function `get_automation_registry_config`](#0x1_automation_registry_get_automation_registry_config)
-  [Function `get_next_epoch_registry_max_gas_cap`](#0x1_automation_registry_get_next_epoch_registry_max_gas_cap)


<pre><code><b>use</b> <a href="account.md#0x1_account">0x1::account</a>;
<b>use</b> <a href="config_buffer.md#0x1_config_buffer">0x1::config_buffer</a>;
<b>use</b> <a href="create_signer.md#0x1_create_signer">0x1::create_signer</a>;
<b>use</b> <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map">0x1::enumerable_map</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">0x1::signer</a>;
<b>use</b> <a href="supra_account.md#0x1_supra_account">0x1::supra_account</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="timestamp.md#0x1_timestamp">0x1::timestamp</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_automation_registry_ActiveAutomationRegistryConfig"></a>

## Resource `ActiveAutomationRegistryConfig`



<pre><code>#[resource_group_member(#[group = <a href="object.md#0x1_object_ObjectGroup">0x1::object::ObjectGroup</a>])]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>main_config: <a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">automation_registry::AutomationRegistryConfig</a></code>
</dt>
<dd>

</dd>
<dt>
<code>next_epoch_registry_max_gas_cap: u64</code>
</dt>
<dd>
 Will be the same as main_config.registry_max_gas_cap, unless updated during the epoch.
</dd>
</dl>


</details>

<a id="0x1_automation_registry_AutomationRegistryConfig"></a>

## Resource `AutomationRegistryConfig`

Automation registry config


<pre><code>#[<a href="event.md#0x1_event">event</a>]
#[resource_group_member(#[group = <a href="object.md#0x1_object_ObjectGroup">0x1::object::ObjectGroup</a>])]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a> <b>has</b> <b>copy</b>, drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>task_duration_cap_in_secs: u64</code>
</dt>
<dd>
 Maximum allowable duration (in seconds) from the registration time that an automation task can run.
 If the expiration time exceeds this duration, the task registration will fail.
</dd>
<dt>
<code>registry_max_gas_cap: u64</code>
</dt>
<dd>
 Maximum gas allocation for automation tasks per epoch
 Exceeding this limit during task registration will cause failure and is used in fee calculation.
</dd>
<dt>
<code>automation_base_fee_in_quants_per_sec: u64</code>
</dt>
<dd>
 Base fee per second for the full capacity of the automation registry, measured in quants/sec.
 The capacity is considered full if the total committed gas of all registered tasks equals registry_max_gas_cap.
</dd>
<dt>
<code>flat_registration_fee_in_quants: u64</code>
</dt>
<dd>
 Flat registration fee charged by default for each task.
</dd>
<dt>
<code>congestion_threshold_percentage: u8</code>
</dt>
<dd>
 Ratio (in the range [0;100]) representing the acceptable upper limit of committed gas amount
 relative to registry_max_gas_cap. Beyond this threshold, congestion fees apply.
</dd>
<dt>
<code>congestion_base_fee_in_quants_per_sec: u64</code>
</dt>
<dd>
 Base fee per second for the full capacity of the automation registry when the congestion threshold is exceeded.
</dd>
</dl>


</details>

<a id="0x1_automation_registry_AutomationRegistry"></a>

## Resource `AutomationRegistry`

It tracks entries both pending and completed, organized by unique indices.


<pre><code>#[resource_group_member(#[group = <a href="object.md#0x1_object_ObjectGroup">0x1::object::ObjectGroup</a>])]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> <b>has</b> store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>tasks: <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_EnumerableMap">enumerable_map::EnumerableMap</a>&lt;u64, <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>&gt;</code>
</dt>
<dd>
 A collection of automation task entries that are active state.
</dd>
<dt>
<code>current_index: u64</code>
</dt>
<dd>
 Automation task id which increase
</dd>
<dt>
<code>gas_committed_for_next_epoch: u64</code>
</dt>
<dd>
 Gas committed for next epoch
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
</dl>


</details>

<a id="0x1_automation_registry_AutomationEpochInfo"></a>

## Resource `AutomationEpochInfo`

Epoch state


<pre><code>#[resource_group_member(#[group = <a href="object.md#0x1_object_ObjectGroup">0x1::object::ObjectGroup</a>])]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>expected_epoch_duration: u64</code>
</dt>
<dd>
 Epoch expected duration at the beginning of the new epoch, Based on this and actual
 epoch_duration which will be (current_time - last_reconfiguration_time) automation tasks
 refunds will be calculated.
 it will be updated upon each new epoch start with epoch_interval value.
 Although we should be careful with refunds if block production interval is quite high.
</dd>
<dt>
<code>epoch_interval: u64</code>
</dt>
<dd>
 Epoch interval that can be updated any moment of the time
</dd>
<dt>
<code>start_time: u64</code>
</dt>
<dd>
 Current epoch start time which is the same as last_reconfiguration_time
</dd>
</dl>


</details>

<a id="0x1_automation_registry_AutomationTaskMetaData"></a>

## Resource `AutomationTaskMetaData`

<code><a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a></code> represents a single automation task item, containing metadata.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
#[resource_group_member(#[group = <a href="object.md#0x1_object_ObjectGroup">0x1::object::ObjectGroup</a>])]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a> <b>has</b> <b>copy</b>, drop, store, key
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
<code>automation_fee_cap_for_epoch: u64</code>
</dt>
<dd>
 Maximum automation fee for epoch to be paid ever.
</dd>
<dt>
<code>aux_data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;</code>
</dt>
<dd>
 Auxiliary data specified for the task to aid registration.
 Not used currently. Reserved for future extentions.
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

<a id="0x1_automation_registry_AutomationCancellationRefund"></a>

## Struct `AutomationCancellationRefund`

Withdraw user's registration fee event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_AutomationCancellationRefund">AutomationCancellationRefund</a> <b>has</b> drop, store
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
<code>task_index: u64</code>
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

<a id="0x1_automation_registry_CancelledAutomationTask"></a>

## Struct `CancelledAutomationTask`

Cancelled automation task registry event


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="automation_registry.md#0x1_automation_registry_CancelledAutomationTask">CancelledAutomationTask</a> <b>has</b> drop, store
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


<a id="0x1_automation_registry_MAX_U64"></a>

Max U64 value


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_MAX_U64">MAX_U64</a>: u128 = 18446744073709551615;
</code></pre>



<a id="0x1_automation_registry_CANCELLED"></a>



<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_CANCELLED">CANCELLED</a>: u8 = 2;
</code></pre>



<a id="0x1_automation_registry_ACTIVE"></a>



<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_ACTIVE">ACTIVE</a>: u8 = 1;
</code></pre>



<a id="0x1_automation_registry_DECIMAL"></a>

Decimal place to make


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_DECIMAL">DECIMAL</a>: u256 = 100000000;
</code></pre>



<a id="0x1_automation_registry_EALREADY_CANCELLED"></a>

Task is already cancelled.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EALREADY_CANCELLED">EALREADY_CANCELLED</a>: u64 = 11;
</code></pre>



<a id="0x1_automation_registry_EAUTOMATION_TASK_NOT_FOUND"></a>

Task with provided Id not found


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EAUTOMATION_TASK_NOT_FOUND">EAUTOMATION_TASK_NOT_FOUND</a>: u64 = 6;
</code></pre>



<a id="0x1_automation_registry_EEXPIRY_BEFORE_NEXT_EPOCH"></a>

Expiry time must be after the start of the next epoch


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_BEFORE_NEXT_EPOCH">EEXPIRY_BEFORE_NEXT_EPOCH</a>: u64 = 3;
</code></pre>



<a id="0x1_automation_registry_EEXPIRY_TIME_UPPER"></a>

Expiry time does not go beyond upper cap duration


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_TIME_UPPER">EEXPIRY_TIME_UPPER</a>: u64 = 2;
</code></pre>



<a id="0x1_automation_registry_EGAS_AMOUNT_UPPER"></a>

Gas amount must not go beyond upper cap limit


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EGAS_AMOUNT_UPPER">EGAS_AMOUNT_UPPER</a>: u64 = 7;
</code></pre>



<a id="0x1_automation_registry_EGAS_COMMITTEED_VALUE_OVERFLOW"></a>

The gas committed for next epoch value is overflow after adding new max gas


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EGAS_COMMITTEED_VALUE_OVERFLOW">EGAS_COMMITTEED_VALUE_OVERFLOW</a>: u64 = 12;
</code></pre>



<a id="0x1_automation_registry_EGAS_COMMITTEED_VALUE_UNDERFLOW"></a>

The gas committed for next epoch value is underflow after remove old max gas


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EGAS_COMMITTEED_VALUE_UNDERFLOW">EGAS_COMMITTEED_VALUE_UNDERFLOW</a>: u64 = 13;
</code></pre>



<a id="0x1_automation_registry_EINVALID_EXPIRY_TIME"></a>

Invalid expiry time: it cannot be earlier than the current time


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EINVALID_EXPIRY_TIME">EINVALID_EXPIRY_TIME</a>: u64 = 1;
</code></pre>



<a id="0x1_automation_registry_EINVALID_GAS_PRICE"></a>

Invalid gas price: it cannot be zero


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EINVALID_GAS_PRICE">EINVALID_GAS_PRICE</a>: u64 = 4;
</code></pre>



<a id="0x1_automation_registry_EINVALID_MAX_GAS_AMOUNT"></a>

Invalid max gas amount for automated task: it cannot be zero


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EINVALID_MAX_GAS_AMOUNT">EINVALID_MAX_GAS_AMOUNT</a>: u64 = 5;
</code></pre>



<a id="0x1_automation_registry_EINVALID_TXN_HASH"></a>

Transactoin hash that registring current task is invalid. Lenght should be 32.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EINVALID_TXN_HASH">EINVALID_TXN_HASH</a>: u64 = 9;
</code></pre>



<a id="0x1_automation_registry_ENO_AUX_DATA_SUPPORTED"></a>

Auxiliary data during registration is not supported


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_ENO_AUX_DATA_SUPPORTED">ENO_AUX_DATA_SUPPORTED</a>: u64 = 14;
</code></pre>



<a id="0x1_automation_registry_EUNACCEPTABLE_AUTOMATION_GAS_LIMIT"></a>

Current committed gas amount is greater than the automation gas limit.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EUNACCEPTABLE_AUTOMATION_GAS_LIMIT">EUNACCEPTABLE_AUTOMATION_GAS_LIMIT</a>: u64 = 10;
</code></pre>



<a id="0x1_automation_registry_EUNAUTHORIZED_TASK_OWNER"></a>

Unauthorized access: the caller is not the owner of the task


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_EUNAUTHORIZED_TASK_OWNER">EUNAUTHORIZED_TASK_OWNER</a>: u64 = 8;
</code></pre>



<a id="0x1_automation_registry_MICROSECS_CONVERSION_FACTOR"></a>

Conversion factor between microseconds and second


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_MICROSECS_CONVERSION_FACTOR">MICROSECS_CONVERSION_FACTOR</a>: u64 = 1000000;
</code></pre>



<a id="0x1_automation_registry_PENDING"></a>

Constants describing task state.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_PENDING">PENDING</a>: u8 = 0;
</code></pre>



<a id="0x1_automation_registry_REGISTRY_RESOURCE_SEED"></a>

Registry resource creation seed


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_REGISTRY_RESOURCE_SEED">REGISTRY_RESOURCE_SEED</a>: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; = [115, 117, 112, 114, 97, 95, 102, 114, 97, 109, 101, 119, 111, 114, 107, 58, 58, 97, 117, 116, 111, 109, 97, 116, 105, 111, 110, 95, 114, 101, 103, 105, 115, 116, 114, 121];
</code></pre>



<a id="0x1_automation_registry_TXN_HASH_LENGTH"></a>

The lenght of the transaction hash.


<pre><code><b>const</b> <a href="automation_registry.md#0x1_automation_registry_TXN_HASH_LENGTH">TXN_HASH_LENGTH</a>: u64 = 32;
</code></pre>



<a id="0x1_automation_registry_initializate_by_default"></a>

## Function `initializate_by_default`

This is temporary function : until we have initialization flow properly implemented


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initializate_by_default">initializate_by_default</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, epoch_interval_microsecs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initializate_by_default">initializate_by_default</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, epoch_interval_microsecs: u64) {
    <a href="automation_registry.md#0x1_automation_registry_initialize">initialize</a>(
        supra_framework,
        epoch_interval_microsecs,
        2_626_560,
        100_000_000,
        1000,
        100_000_000, // 1 supra
        80,
        100,
    );
}
</code></pre>



</details>

<a id="0x1_automation_registry_initialize"></a>

## Function `initialize`

Initialization of Automation Registry


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, epoch_interval_microsecs: u64, task_duration_cap_in_secs: u64, registry_max_gas_cap: u64, automation_base_fee_in_quants_per_sec: u64, flat_registration_fee_in_quants: u64, congestion_threshold_percentage: u8, congestion_base_fee_in_quants_per_sec: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_initialize">initialize</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    epoch_interval_microsecs: u64,
    task_duration_cap_in_secs: u64,
    registry_max_gas_cap: u64,
    automation_base_fee_in_quants_per_sec: u64,
    flat_registration_fee_in_quants: u64,
    congestion_threshold_percentage: u8,
    congestion_base_fee_in_quants_per_sec: u64,
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> (registry_fee_resource_signer, registry_fee_address_signer_cap) = <a href="account.md#0x1_account_create_resource_account">account::create_resource_account</a>(
        supra_framework,
        <a href="automation_registry.md#0x1_automation_registry_REGISTRY_RESOURCE_SEED">REGISTRY_RESOURCE_SEED</a>
    );

    <b>move_to</b>(supra_framework, <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
        tasks: <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_new_map">enumerable_map::new_map</a>(),
        current_index: 0,
        gas_committed_for_next_epoch: 0,
        registry_fee_address: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(&registry_fee_resource_signer),
        registry_fee_address_signer_cap,
    });

    <b>move_to</b>(supra_framework, <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
        main_config: <a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a> {
            task_duration_cap_in_secs,
            registry_max_gas_cap,
            automation_base_fee_in_quants_per_sec,
            flat_registration_fee_in_quants,
            congestion_threshold_percentage,
            congestion_base_fee_in_quants_per_sec,
        },
        next_epoch_registry_max_gas_cap: registry_max_gas_cap
    });

    <b>let</b> epoch_interval = epoch_interval_microsecs / <a href="automation_registry.md#0x1_automation_registry_MICROSECS_CONVERSION_FACTOR">MICROSECS_CONVERSION_FACTOR</a>;
    <b>move_to</b>(supra_framework, <a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a> {
        expected_epoch_duration: epoch_interval,
        epoch_interval,
        start_time: 0,
    });
}
</code></pre>



</details>

<a id="0x1_automation_registry_on_new_epoch"></a>

## Function `on_new_epoch`

On new epoch this function will be triggered and update the automation registry state


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_on_new_epoch">on_new_epoch</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_on_new_epoch">on_new_epoch</a>() <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>, <a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>, <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>let</b> ids = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_map_list">enumerable_map::get_map_list</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks);

    <b>let</b> automation_epoch_info = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>&gt;(@supra_framework);

    <b>let</b> current_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();
    <b>let</b> gas_committed_for_next_epoch = 0;

    // Apply the latest configuration <b>if</b> <a href="../../aptos-stdlib/doc/any.md#0x1_any">any</a> parameter <b>has</b> been updated.
    <a href="automation_registry.md#0x1_automation_registry_update_config_from_buffer">update_config_from_buffer</a>();
    <b>let</b> automation_registry_config = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a>&gt;(
        @supra_framework
    ).main_config;

    // Accumulated maximum gas amount of the registered tasks for the current epoch
    <b>let</b> tcmg = 0;

    // Perform clean up and updation of state
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(ids, |id| {
        <b>let</b> task = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value_mut">enumerable_map::get_value_mut</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);

        // Tasks that are active during next epoch and are not canceled
        // current_time shows the start time of the current new epoch.
        <b>if</b> (task.state != <a href="automation_registry.md#0x1_automation_registry_CANCELLED">CANCELLED</a> && task.expiry_time &gt; (current_time + automation_epoch_info.epoch_interval)) {
            gas_committed_for_next_epoch = gas_committed_for_next_epoch + task.max_gas_amount;
        };

        // Drop or activate task for this current epoch.
        <b>if</b> (task.expiry_time &lt;= current_time || task.state == <a href="automation_registry.md#0x1_automation_registry_CANCELLED">CANCELLED</a>) {
            <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_remove_value">enumerable_map::remove_value</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);
        } <b>else</b> {
            task.state = <a href="automation_registry.md#0x1_automation_registry_ACTIVE">ACTIVE</a>;
            tcmg = tcmg + (task.max_gas_amount <b>as</b> u256);
        }
    });

    <a href="automation_registry.md#0x1_automation_registry_fee_charges_on_new_epoch">fee_charges_on_new_epoch</a>(
        <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>,
        automation_epoch_info,
        &automation_registry_config,
        ids,
        current_time,
        tcmg
    );

    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch = gas_committed_for_next_epoch;
    automation_epoch_info.start_time = current_time;
    automation_epoch_info.expected_epoch_duration = automation_epoch_info.epoch_interval;
}
</code></pre>



</details>

<a id="0x1_automation_registry_fee_charges_on_new_epoch"></a>

## Function `fee_charges_on_new_epoch`

Charges automation task fees for all active tasks at the beginning of a new epoch.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_fee_charges_on_new_epoch">fee_charges_on_new_epoch</a>(ar: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">automation_registry::AutomationRegistry</a>, aei: &<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">automation_registry::AutomationEpochInfo</a>, arc: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">automation_registry::AutomationRegistryConfig</a>, ids: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;, current_time: u64, tcmg: u256)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_fee_charges_on_new_epoch">fee_charges_on_new_epoch</a>(
    ar: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>,
    aei: &<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>,
    arc: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a>,
    ids: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;,
    current_time: u64,
    tcmg: u256
) {
    <b>let</b> max_gas_cap = (arc.registry_max_gas_cap <b>as</b> u256);
    <b>let</b> threshold_percentage = (arc.congestion_threshold_percentage <b>as</b> u256) * <a href="automation_registry.md#0x1_automation_registry_DECIMAL">DECIMAL</a>;

    // Calculate congestion threshold surplus for the current epoch
    <b>let</b> threshold_usage = (tcmg * <a href="automation_registry.md#0x1_automation_registry_DECIMAL">DECIMAL</a> / max_gas_cap) * 100;
    <b>let</b> threshold_surplus = <b>if</b> (threshold_usage &lt; threshold_percentage) 0
    <b>else</b> threshold_usage - threshold_percentage;

    // Compute the automation congestion fee (acf) for the epoch
    <b>let</b> acf = <b>if</b> (threshold_surplus &gt; 0) {
        ((arc.congestion_base_fee_in_quants_per_sec <b>as</b> u256) * threshold_surplus / 100) / <a href="automation_registry.md#0x1_automation_registry_DECIMAL">DECIMAL</a>
    } <b>else</b> 0;

    // Process each active task and <b>apply</b> the fee charges for the new epoch
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(ids, |id| {
        <b>let</b> task = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&ar.tasks, id);
        <b>if</b> (task.state == <a href="automation_registry.md#0x1_automation_registry_ACTIVE">ACTIVE</a>) {
            <a href="automation_registry.md#0x1_automation_registry_fee_charges_on_new_epoch_for_single_task">fee_charges_on_new_epoch_for_single_task</a>(ar.registry_fee_address, aei, arc, &task, current_time, acf);
        }
    });
}
</code></pre>



</details>

<a id="0x1_automation_registry_fee_charges_on_new_epoch_for_single_task"></a>

## Function `fee_charges_on_new_epoch_for_single_task`

Charges automation task fees for a single task at the beginning of a new epoch.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_fee_charges_on_new_epoch_for_single_task">fee_charges_on_new_epoch_for_single_task</a>(registry_fee_address: <b>address</b>, aei: &<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">automation_registry::AutomationEpochInfo</a>, arc: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">automation_registry::AutomationRegistryConfig</a>, task: &<a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>, current_time: u64, acf: u256)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_fee_charges_on_new_epoch_for_single_task">fee_charges_on_new_epoch_for_single_task</a>(
    registry_fee_address: <b>address</b>,
    aei: &<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>,
    arc: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a>,
    task: &<a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a>,
    current_time: u64,
    acf: u256
) {
    <b>let</b> abf = (arc.automation_base_fee_in_quants_per_sec <b>as</b> u256);
    <b>let</b> max_gas_cap = (arc.registry_max_gas_cap <b>as</b> u256);
    <b>let</b> task_max_gas = (task.max_gas_amount <b>as</b> u256);

    <b>let</b> epoch_interval = aei.epoch_interval;
    <b>let</b> remaining_time = task.expiry_time - current_time;
    <b>let</b> min_interval = <b>if</b> (remaining_time &lt; epoch_interval) remaining_time <b>else</b> epoch_interval;

    // Compute the base automation fee (taf)
    <b>let</b> gas_proportion = (task_max_gas * <a href="automation_registry.md#0x1_automation_registry_DECIMAL">DECIMAL</a> / max_gas_cap);
    <b>let</b> base_fee = (abf * gas_proportion) / <a href="automation_registry.md#0x1_automation_registry_DECIMAL">DECIMAL</a>;
    <b>let</b> taf = base_fee * (min_interval <b>as</b> u256); // Total base fee for the interval

    // Compute the congestion fee per task (tcf)
    <b>let</b> tcf = <b>if</b> (acf &gt; 0) {
        (acf * gas_proportion * (min_interval <b>as</b> u256)) / <a href="automation_registry.md#0x1_automation_registry_DECIMAL">DECIMAL</a>
    } <b>else</b> 0;

    <b>let</b> transfer_fee_amount = (taf + tcf <b>as</b> u64);
    <a href="supra_account.md#0x1_supra_account_transfer">supra_account::transfer</a>(&<a href="create_signer.md#0x1_create_signer">create_signer</a>(task.owner), registry_fee_address, transfer_fee_amount)
}
</code></pre>



</details>

<a id="0x1_automation_registry_update_config_from_buffer"></a>

## Function `update_config_from_buffer`

The function updates the ActiveAutomationRegistryConfig structure with values extracted from the buffer, if the buffer exists.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_config_from_buffer">update_config_from_buffer</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_config_from_buffer">update_config_from_buffer</a>() <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
    <b>if</b> (<a href="config_buffer.md#0x1_config_buffer_does_exist">config_buffer::does_exist</a>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a>&gt;()) {
        <b>let</b> buffer = <a href="config_buffer.md#0x1_config_buffer_extract">config_buffer::extract</a>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a>&gt;();
        <b>let</b> automation_registry_config = &<b>mut</b> <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a>&gt;(
            @supra_framework
        ).main_config;
        automation_registry_config.task_duration_cap_in_secs = buffer.task_duration_cap_in_secs;
        automation_registry_config.registry_max_gas_cap = buffer.registry_max_gas_cap;
        automation_registry_config.automation_base_fee_in_quants_per_sec = buffer.automation_base_fee_in_quants_per_sec;
        automation_registry_config.flat_registration_fee_in_quants = buffer.flat_registration_fee_in_quants;
        automation_registry_config.congestion_threshold_percentage = buffer.congestion_threshold_percentage;
        automation_registry_config.congestion_base_fee_in_quants_per_sec = buffer.congestion_base_fee_in_quants_per_sec;
    };
}
</code></pre>



</details>

<a id="0x1_automation_registry_withdraw_automation_task_fees"></a>

## Function `withdraw_automation_task_fees`

Withdraw accumulated automation task fees from the resource account - access by admin


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_withdraw_automation_task_fees">withdraw_automation_task_fees</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <b>to</b>: <b>address</b>, amount: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_withdraw_automation_task_fees">withdraw_automation_task_fees</a>(
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

<a id="0x1_automation_registry_update_config"></a>

## Function `update_config`

Update Automation Registry Config


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_config">update_config</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, task_duration_cap_in_secs: u64, registry_max_gas_cap: u64, automation_base_fee_in_quants_per_sec: u64, flat_registration_fee_in_quants: u64, congestion_threshold_percentage: u8, congestion_base_fee_in_quants_per_sec: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_config">update_config</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    task_duration_cap_in_secs: u64,
    registry_max_gas_cap: u64,
    automation_base_fee_in_quants_per_sec: u64,
    flat_registration_fee_in_quants: u64,
    congestion_threshold_percentage: u8,
    congestion_base_fee_in_quants_per_sec: u64,
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>, <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);

    <b>assert</b>!(
        <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch &lt; registry_max_gas_cap,
        <a href="automation_registry.md#0x1_automation_registry_EUNACCEPTABLE_AUTOMATION_GAS_LIMIT">EUNACCEPTABLE_AUTOMATION_GAS_LIMIT</a>
    );

    <b>let</b> new_automation_registry_config = <a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a> {
        task_duration_cap_in_secs,
        registry_max_gas_cap,
        automation_base_fee_in_quants_per_sec,
        flat_registration_fee_in_quants,
        congestion_threshold_percentage,
        congestion_base_fee_in_quants_per_sec,
    };
    <a href="config_buffer.md#0x1_config_buffer_upsert">config_buffer::upsert</a>(<b>copy</b> new_automation_registry_config);

    // next_epoch_registry_max_gas_cap will be <b>update</b> instantly
    <b>let</b> automation_registry_config = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a>&gt;(@supra_framework);
    automation_registry_config.next_epoch_registry_max_gas_cap = registry_max_gas_cap;

    <a href="event.md#0x1_event_emit">event::emit</a>(new_automation_registry_config);
}
</code></pre>



</details>

<a id="0x1_automation_registry_register"></a>

## Function `register`

Registers a new automation task entry.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_register">register</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, expiry_time: u64, max_gas_amount: u64, gas_price_cap: u64, automation_fee_cap_for_epoch: u64, tx_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;, aux_data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_register">register</a>(
    owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    payload_tx: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    expiry_time: u64,
    max_gas_amount: u64,
    gas_price_cap: u64,
    automation_fee_cap_for_epoch: u64,
    tx_hash: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;,
    aux_data: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;&gt;
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>, <a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>, <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_is_empty">vector::is_empty</a>(&aux_data), <a href="automation_registry.md#0x1_automation_registry_ENO_AUX_DATA_SUPPORTED">ENO_AUX_DATA_SUPPORTED</a>);
    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>let</b> automation_registry_config = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a>&gt;(@supra_framework);
    <b>let</b> automation_epoch_info = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>&gt;(@supra_framework);

    //Well-formedness check of payload_tx is done in <b>native</b> layer beforehand.

    <b>let</b> registration_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();
    <b>let</b> task_duration = <a href="automation_registry.md#0x1_automation_registry_check_registration_task_duration">check_registration_task_duration</a>(
        expiry_time,
        registration_time,
        &automation_registry_config.main_config,
        automation_epoch_info
    );

    <b>assert</b>!(gas_price_cap &gt; 0, <a href="automation_registry.md#0x1_automation_registry_EINVALID_GAS_PRICE">EINVALID_GAS_PRICE</a>);
    <b>assert</b>!(max_gas_amount &gt; 0, <a href="automation_registry.md#0x1_automation_registry_EINVALID_MAX_GAS_AMOUNT">EINVALID_MAX_GAS_AMOUNT</a>);
    <b>assert</b>!(<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&tx_hash) == <a href="automation_registry.md#0x1_automation_registry_TXN_HASH_LENGTH">TXN_HASH_LENGTH</a>, <a href="automation_registry.md#0x1_automation_registry_EINVALID_TXN_HASH">EINVALID_TXN_HASH</a>);

    <b>let</b> committed_gas = (<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch <b>as</b> u128) + (max_gas_amount <b>as</b> u128);
    <b>assert</b>!(committed_gas &lt;= <a href="automation_registry.md#0x1_automation_registry_MAX_U64">MAX_U64</a>, <a href="automation_registry.md#0x1_automation_registry_EGAS_COMMITTEED_VALUE_OVERFLOW">EGAS_COMMITTEED_VALUE_OVERFLOW</a>);

    <b>let</b> committed_gas = (committed_gas <b>as</b> u64);
    <b>assert</b>!(committed_gas &lt; automation_registry_config.next_epoch_registry_max_gas_cap, <a href="automation_registry.md#0x1_automation_registry_EGAS_AMOUNT_UPPER">EGAS_AMOUNT_UPPER</a>);
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch = committed_gas;
    <b>let</b> task_index = <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.current_index;

    <b>let</b> automation_task_metadata = <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a> {
        id: task_index,
        owner: <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(owner),
        payload_tx,
        expiry_time,
        max_gas_amount,
        gas_price_cap,
        automation_fee_cap_for_epoch,
        aux_data,
        state: <a href="automation_registry.md#0x1_automation_registry_PENDING">PENDING</a>,
        registration_time,
        tx_hash,
    };

    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_add_value">enumerable_map::add_value</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, task_index, automation_task_metadata);
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.current_index = <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.current_index + 1;

    // Charge flate registration fee from the user at the time of registration
    <a href="supra_account.md#0x1_supra_account_transfer">supra_account::transfer</a>(
        owner,
        <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.registry_fee_address,
        automation_registry_config.main_config.flat_registration_fee_in_quants
    );

    <a href="event.md#0x1_event_emit">event::emit</a>(automation_task_metadata);
}
</code></pre>



</details>

<a id="0x1_automation_registry_check_registration_task_duration"></a>

## Function `check_registration_task_duration`



<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_check_registration_task_duration">check_registration_task_duration</a>(expiry_time: u64, registration_time: u64, automation_registry_config: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">automation_registry::AutomationRegistryConfig</a>, automation_epoch_info: &<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">automation_registry::AutomationEpochInfo</a>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_check_registration_task_duration">check_registration_task_duration</a>(
    expiry_time: u64,
    registration_time: u64,
    automation_registry_config: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a>,
    automation_epoch_info: &<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>
): u64 {
    <b>assert</b>!(expiry_time &gt; registration_time, <a href="automation_registry.md#0x1_automation_registry_EINVALID_EXPIRY_TIME">EINVALID_EXPIRY_TIME</a>);
    <b>let</b> task_duration = expiry_time - registration_time;
    <b>assert</b>!(task_duration &lt; automation_registry_config.task_duration_cap_in_secs, <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_TIME_UPPER">EEXPIRY_TIME_UPPER</a>);

    // Check that task is valid at least in the next epoch
    <b>assert</b>!(
        expiry_time &gt; (automation_epoch_info.start_time + automation_epoch_info.epoch_interval),
        <a href="automation_registry.md#0x1_automation_registry_EEXPIRY_BEFORE_NEXT_EPOCH">EEXPIRY_BEFORE_NEXT_EPOCH</a>
    );
    task_duration
}
</code></pre>



</details>

<a id="0x1_automation_registry_cancel_task"></a>

## Function `cancel_task`

Cancel Automation task with specified id.
Only existing task, which is PENDING or ACTIVE, can be cancled and only by task onwer.
If the task is
- active, its state is updated to be CANCELLED.
- pending, it is removed form the list.
- cancelled, an error is reported
Committed gas-limit is updated by reducing it with the max-gas-amount of the cancelled task.


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_cancel_task">cancel_task</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, id: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> entry <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_cancel_task">cancel_task</a>(owner: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, id: u64) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>, <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>let</b> automation_registry_config = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a>&gt;(@supra_framework);
    <b>assert</b>!(<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&<a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id), <a href="automation_registry.md#0x1_automation_registry_EAUTOMATION_TASK_NOT_FOUND">EAUTOMATION_TASK_NOT_FOUND</a>);

    <b>let</b> automation_task_metadata = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);
    <b>assert</b>!(automation_task_metadata.owner == <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(owner), <a href="automation_registry.md#0x1_automation_registry_EUNAUTHORIZED_TASK_OWNER">EUNAUTHORIZED_TASK_OWNER</a>);
    <b>assert</b>!(automation_task_metadata.state != <a href="automation_registry.md#0x1_automation_registry_CANCELLED">CANCELLED</a>, <a href="automation_registry.md#0x1_automation_registry_EALREADY_CANCELLED">EALREADY_CANCELLED</a>);
    <b>if</b> (automation_task_metadata.state == <a href="automation_registry.md#0x1_automation_registry_PENDING">PENDING</a>) {
        <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_remove_value">enumerable_map::remove_value</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);
    } <b>else</b> <b>if</b> (automation_task_metadata.state == <a href="automation_registry.md#0x1_automation_registry_ACTIVE">ACTIVE</a>) {
        <b>let</b> automation_task_metadata_mut = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value_mut">enumerable_map::get_value_mut</a>(&<b>mut</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.tasks, id);
        automation_task_metadata_mut.state = <a href="automation_registry.md#0x1_automation_registry_CANCELLED">CANCELLED</a>;
    };

    <b>assert</b>!(
        <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch &gt;= automation_task_metadata.max_gas_amount,
        <a href="automation_registry.md#0x1_automation_registry_EGAS_COMMITTEED_VALUE_UNDERFLOW">EGAS_COMMITTEED_VALUE_UNDERFLOW</a>
    );
    // Adjust the gas committed for the next epoch by subtracting the gas amount of the cancelled task
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch = <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch - automation_task_metadata.max_gas_amount;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="automation_registry.md#0x1_automation_registry_CancelledAutomationTask">CancelledAutomationTask</a> { id: automation_task_metadata.id });
    <a href="automation_registry.md#0x1_automation_registry_refund_automation_task_fee">refund_automation_task_fee</a>(
        <a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer_address_of">signer::address_of</a>(owner),
        &automation_task_metadata,
        &automation_registry_config.main_config
    );
}
</code></pre>



</details>

<a id="0x1_automation_registry_refund_automation_task_fee"></a>

## Function `refund_automation_task_fee`

Refunds the automation task fee to the user who has removed their task registration from the list.


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_refund_automation_task_fee">refund_automation_task_fee</a>(user: <b>address</b>, automation_task_metadata: &<a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>, automation_registry_config: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">automation_registry::AutomationRegistryConfig</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="automation_registry.md#0x1_automation_registry_refund_automation_task_fee">refund_automation_task_fee</a>(
    user: <b>address</b>,
    automation_task_metadata: &<a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a>,
    automation_registry_config: &<a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a>,
) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> current_time = <a href="timestamp.md#0x1_timestamp_now_seconds">timestamp::now_seconds</a>();
    <b>if</b> (automation_task_metadata.expiry_time &gt; current_time) {
        <b>let</b> residual_ttl = automation_task_metadata.expiry_time - current_time;

        <b>let</b> refund_amount = residual_ttl * automation_registry_config.automation_base_fee_in_quants_per_sec;
        <a href="automation_registry.md#0x1_automation_registry_transfer_fee_to_account_internal">transfer_fee_to_account_internal</a>(user, refund_amount);
        <a href="event.md#0x1_event_emit">event::emit</a>(
            <a href="automation_registry.md#0x1_automation_registry_AutomationCancellationRefund">AutomationCancellationRefund</a> { user, task_index: automation_task_metadata.id, amount: refund_amount }
        );
    }
}
</code></pre>



</details>

<a id="0x1_automation_registry_update_epoch_interval_in_registry"></a>

## Function `update_epoch_interval_in_registry`

Update epoch interval in registry while actually update happens in block module


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_epoch_interval_in_registry">update_epoch_interval_in_registry</a>(epoch_interval_microsecs: u64)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_update_epoch_interval_in_registry">update_epoch_interval_in_registry</a>(epoch_interval_microsecs: u64) <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>&gt;(@supra_framework)) {
        <b>let</b> automation_epoch_info = <b>borrow_global_mut</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationEpochInfo">AutomationEpochInfo</a>&gt;(@supra_framework);
        automation_epoch_info.epoch_interval = epoch_interval_microsecs / <a href="automation_registry.md#0x1_automation_registry_MICROSECS_CONVERSION_FACTOR">MICROSECS_CONVERSION_FACTOR</a>;
    };
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
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.current_index
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_active_task_ids"></a>

## Function `get_active_task_ids`

List all active automation task ids for the current epoch.
Note that the tasks with CANCELLED state are still considered active for the current epoch,
as cancellation takes effect in the next epoch only.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_active_task_ids">get_active_task_ids</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_active_task_ids">get_active_task_ids</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt; <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> state = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);

    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_filter_map">enumerable_map::filter_map</a>(&state.tasks, |task| {
        <b>let</b> task: <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a> = task; // we need <b>to</b> define task type here <b>to</b> avoid compiler <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">error</a>
        <b>if</b> (task.state != <a href="automation_registry.md#0x1_automation_registry_PENDING">PENDING</a>) (<b>true</b>, task.id)
        <b>else</b> (<b>false</b>, task.id)
    })
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_task_details"></a>

## Function `get_task_details`

Retrieves the details of a automation task entry by its ID.
Error will be returned if entry with specified ID does not exist.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_task_details">get_task_details</a>(id: u64): <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">automation_registry::AutomationTaskMetaData</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_task_details">get_task_details</a>(id: u64): <a href="automation_registry.md#0x1_automation_registry_AutomationTaskMetaData">AutomationTaskMetaData</a> <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> automation_task_metadata = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>assert</b>!(<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&automation_task_metadata.tasks, id), <a href="automation_registry.md#0x1_automation_registry_EAUTOMATION_TASK_NOT_FOUND">EAUTOMATION_TASK_NOT_FOUND</a>);
    <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value">enumerable_map::get_value</a>(&automation_task_metadata.tasks, id)
}
</code></pre>



</details>

<a id="0x1_automation_registry_has_sender_active_task_with_id"></a>

## Function `has_sender_active_task_with_id`

Checks whether there is an active task in registry with specified input task id.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_has_sender_active_task_with_id">has_sender_active_task_with_id</a>(sender: <b>address</b>, id: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_has_sender_active_task_with_id">has_sender_active_task_with_id</a>(sender: <b>address</b>, id: u64): bool <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> automation_task_metadata = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <b>if</b> (<a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_contains">enumerable_map::contains</a>(&automation_task_metadata.tasks, id)) {
        <b>let</b> value = <a href="../../supra-stdlib/doc/enumerable_map.md#0x1_enumerable_map_get_value_ref">enumerable_map::get_value_ref</a>(&automation_task_metadata.tasks, id);
        value.state != <a href="automation_registry.md#0x1_automation_registry_PENDING">PENDING</a> && value.owner == sender
    } <b>else</b> {
        <b>false</b>
    }
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

Get gas committed for next epoch


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_gas_committed_for_next_epoch">get_gas_committed_for_next_epoch</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_gas_committed_for_next_epoch">get_gas_committed_for_next_epoch</a>(): u64 <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a> {
    <b>let</b> <a href="automation_registry.md#0x1_automation_registry">automation_registry</a> = <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_AutomationRegistry">AutomationRegistry</a>&gt;(@supra_framework);
    <a href="automation_registry.md#0x1_automation_registry">automation_registry</a>.gas_committed_for_next_epoch
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_automation_registry_config"></a>

## Function `get_automation_registry_config`

Get automation registry configration


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_automation_registry_config">get_automation_registry_config</a>(): <a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">automation_registry::AutomationRegistryConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_automation_registry_config">get_automation_registry_config</a>(): <a href="automation_registry.md#0x1_automation_registry_AutomationRegistryConfig">AutomationRegistryConfig</a> <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
    <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a>&gt;(@supra_framework).main_config
}
</code></pre>



</details>

<a id="0x1_automation_registry_get_next_epoch_registry_max_gas_cap"></a>

## Function `get_next_epoch_registry_max_gas_cap`

Get automation registry configration


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_next_epoch_registry_max_gas_cap">get_next_epoch_registry_max_gas_cap</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="automation_registry.md#0x1_automation_registry_get_next_epoch_registry_max_gas_cap">get_next_epoch_registry_max_gas_cap</a>(): u64 <b>acquires</b> <a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a> {
    <b>borrow_global</b>&lt;<a href="automation_registry.md#0x1_automation_registry_ActiveAutomationRegistryConfig">ActiveAutomationRegistryConfig</a>&gt;(@supra_framework).next_epoch_registry_max_gas_cap
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
