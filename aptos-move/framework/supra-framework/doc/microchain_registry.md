
<a id="0x1_microchain_registry"></a>

# Module `0x1::microchain_registry`

Copyright (c) 2025 Supra

Microchain Registry Module

This module manages the registration and lifecycle of microchains on Supra-L1.

1. To enable support for a new microchain on Supra-L1, it must be first registered by Supra Governance
using the <code>register_microchain</code> method of this module.
2. If a registered microchain misbehaves, it can be deactivated by Supra Governance through the <code>deactivate_microchain</code> method.
3. A previously deactivated microchain can be reactivated by Supra Governance using the <code>reactivate_microchain</code> method.
4. Although the registry data is updated immediately, the changes are only considered by Supra-L1 validators
after an epoch change. Therefore, it is strongly recommended to trigger an epoch change by invoking
<code><a href="supra_governance.md#0x1_supra_governance_reconfigure">0x1::supra_governance::reconfigure</a></code>.
5. Supra-L1 validators consider the updated registry data only after the epoch change. Hence, it is
highly recommended to perform an epoch change whenever the following methods are invoked:
a. <code>register_microchain</code>
b. <code>deactivate_microchain</code>
c. <code>reactivate_microchain</code>


-  [Struct `ReservedRange`](#0x1_microchain_registry_ReservedRange)
-  [Struct `MicrochainInfo`](#0x1_microchain_registry_MicrochainInfo)
-  [Resource `MicrochainRegistry`](#0x1_microchain_registry_MicrochainRegistry)
-  [Struct `MicrochainRegistered`](#0x1_microchain_registry_MicrochainRegistered)
-  [Struct `MicrochainDeactivated`](#0x1_microchain_registry_MicrochainDeactivated)
-  [Struct `MicrochainReactivated`](#0x1_microchain_registry_MicrochainReactivated)
-  [Struct `MicrochainMetadataLinkUpdated`](#0x1_microchain_registry_MicrochainMetadataLinkUpdated)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_microchain_registry_initialize)
-  [Function `register_microchain`](#0x1_microchain_registry_register_microchain)
-  [Function `deactivate_microchain`](#0x1_microchain_registry_deactivate_microchain)
-  [Function `reactivate_microchain`](#0x1_microchain_registry_reactivate_microchain)
-  [Function `update_microchain_metadata_link`](#0x1_microchain_registry_update_microchain_metadata_link)
-  [Function `add_reserved_range`](#0x1_microchain_registry_add_reserved_range)
-  [Function `new_reserved_range`](#0x1_microchain_registry_new_reserved_range)
-  [Function `microchain_state`](#0x1_microchain_registry_microchain_state)
-  [Function `is_microchain_active`](#0x1_microchain_registry_is_microchain_active)
-  [Function `active_microchains`](#0x1_microchain_registry_active_microchains)
-  [Function `microchain_metadata_link`](#0x1_microchain_registry_microchain_metadata_link)
-  [Function `microchain_info`](#0x1_microchain_registry_microchain_info)
-  [Function `is_chain_id_reserved`](#0x1_microchain_registry_is_chain_id_reserved)
-  [Function `borrow_global_microchain_registry`](#0x1_microchain_registry_borrow_global_microchain_registry)
-  [Function `borrow_global_mut_microchain_registry`](#0x1_microchain_registry_borrow_global_mut_microchain_registry)
-  [Function `assert_microchain_registered`](#0x1_microchain_registry_assert_microchain_registered)
-  [Function `is_chain_id_reserved_internal`](#0x1_microchain_registry_is_chain_id_reserved_internal)
-  [Specification](#@Specification_1)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map">0x1::simple_map</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
</code></pre>



<a id="0x1_microchain_registry_ReservedRange"></a>

## Struct `ReservedRange`

Represents reserved chain ID range.


<pre><code><b>struct</b> <a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">ReservedRange</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>start: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>end: u8</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_microchain_registry_MicrochainInfo"></a>

## Struct `MicrochainInfo`

Represents information about the registered microchain.


<pre><code><b>struct</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainInfo">MicrochainInfo</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>state: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>metadata_link: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_microchain_registry_MicrochainRegistry"></a>

## Resource `MicrochainRegistry`

Global microchain registry resource.


<pre><code>#[resource_group_member(#[group = <a href="object.md#0x1_object_ObjectGroup">0x1::object::ObjectGroup</a>])]
<b>struct</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>microchains: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_SimpleMap">simple_map::SimpleMap</a>&lt;u8, <a href="microchain_registry.md#0x1_microchain_registry_MicrochainInfo">microchain_registry::MicrochainInfo</a>&gt;</code>
</dt>
<dd>
 Map from chain ID to microchain info.
</dd>
<dt>
<code>reserved_ranges: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">microchain_registry::ReservedRange</a>&gt;</code>
</dt>
<dd>
 Reserved chain ID ranges.
</dd>
</dl>


</details>

<a id="0x1_microchain_registry_MicrochainRegistered"></a>

## Struct `MicrochainRegistered`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistered">MicrochainRegistered</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code><a href="chain_id.md#0x1_chain_id">chain_id</a>: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>metadata_link: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_microchain_registry_MicrochainDeactivated"></a>

## Struct `MicrochainDeactivated`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainDeactivated">MicrochainDeactivated</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code><a href="chain_id.md#0x1_chain_id">chain_id</a>: u8</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_microchain_registry_MicrochainReactivated"></a>

## Struct `MicrochainReactivated`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainReactivated">MicrochainReactivated</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code><a href="chain_id.md#0x1_chain_id">chain_id</a>: u8</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_microchain_registry_MicrochainMetadataLinkUpdated"></a>

## Struct `MicrochainMetadataLinkUpdated`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainMetadataLinkUpdated">MicrochainMetadataLinkUpdated</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code><a href="chain_id.md#0x1_chain_id">chain_id</a>: u8</code>
</dt>
<dd>

</dd>
<dt>
<code>old_metadata_link: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a></code>
</dt>
<dd>

</dd>
<dt>
<code>new_metadata_link: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a></code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_microchain_registry_EINVALID_RANGE"></a>

The provided range is invalid, start value must be less than or equal to end value.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_EINVALID_RANGE">EINVALID_RANGE</a>: u64 = 7;
</code></pre>



<a id="0x1_microchain_registry_EREGISTRY_NOT_INITIALIZED"></a>

The <code><a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a></code> resource has not been initialized at @supra_framework.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_EREGISTRY_NOT_INITIALIZED">EREGISTRY_NOT_INITIALIZED</a>: u64 = 6;
</code></pre>



<a id="0x1_microchain_registry_ECHAIN_ID_RESERVED"></a>

The chain ID falls within a reserved range and cannot be used for registration.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_ECHAIN_ID_RESERVED">ECHAIN_ID_RESERVED</a>: u64 = 3;
</code></pre>



<a id="0x1_microchain_registry_EMICROCHAIN_ALREADY_ACTIVE"></a>

The microchain is already in the <code>ACTIVE</code> state and cannot be reactivated.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_ALREADY_ACTIVE">EMICROCHAIN_ALREADY_ACTIVE</a>: u64 = 5;
</code></pre>



<a id="0x1_microchain_registry_EMICROCHAIN_ALREADY_DEACTIVATED"></a>

The microchain is already in the <code>INACTIVE</code> state and cannot be deactivated again.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_ALREADY_DEACTIVATED">EMICROCHAIN_ALREADY_DEACTIVATED</a>: u64 = 4;
</code></pre>



<a id="0x1_microchain_registry_EMICROCHAIN_ALREADY_REGISTERED"></a>

The microchain with the given chain ID is already registered in the microchain registry.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_ALREADY_REGISTERED">EMICROCHAIN_ALREADY_REGISTERED</a>: u64 = 1;
</code></pre>



<a id="0x1_microchain_registry_EMICROCHAIN_NOT_REGISTERED"></a>

The microchain with the given chain ID is not found in the microchain registry.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_NOT_REGISTERED">EMICROCHAIN_NOT_REGISTERED</a>: u64 = 2;
</code></pre>



<a id="0x1_microchain_registry_STATE_ACTIVE"></a>

Registered as a microchain and actively working.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_STATE_ACTIVE">STATE_ACTIVE</a>: u8 = 1;
</code></pre>



<a id="0x1_microchain_registry_STATE_INACTIVE"></a>

Registered as a microchain, but decommissioned from the Supra-L1.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_STATE_INACTIVE">STATE_INACTIVE</a>: u8 = 0;
</code></pre>



<a id="0x1_microchain_registry_STATE_UNKNOWN"></a>

Never registered as a microchain.


<pre><code><b>const</b> <a href="microchain_registry.md#0x1_microchain_registry_STATE_UNKNOWN">STATE_UNKNOWN</a>: u8 = 2;
</code></pre>



<a id="0x1_microchain_registry_initialize"></a>

## Function `initialize`

Initializes the microchain registry.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, reserved_ranges: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">microchain_registry::ReservedRange</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, reserved_ranges: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">ReservedRange</a>&gt;) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>move_to</b>(supra_framework, <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
        microchains: <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_new">simple_map::new</a>(),
        reserved_ranges,
    });
}
</code></pre>



</details>

<a id="0x1_microchain_registry_register_microchain"></a>

## Function `register_microchain`

Registers a new microchain.

This method requires the <code>supra_framework</code> as a signer. Therefore, externally (out of the supra-framework package),
it can only be invoked through a governance proposal move-script.

It is strongly recommended to trigger an epoch change by calling <code><a href="supra_governance.md#0x1_supra_governance_reconfigure">0x1::supra_governance::reconfigure</a></code>
after invoking this method. While this method could perform the reconfiguration internally, it
intentionally does not. This is because governance proposal move-scripts may need to invoke
additional methods after this one, so the responsibility of reconfiguration is left to the caller.

Example usage:
```
supra_framework::microchain_registry::register_microchain(&supra_framework, chain_id, metadata_link);
supra_framework::supra_governance::reconfigure(&supra_framework);
```


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_register_microchain">register_microchain</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8, metadata_link: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_register_microchain">register_microchain</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8,
    metadata_link: String,
) <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_mut_microchain_registry">borrow_global_mut_microchain_registry</a>(supra_framework);

    // Checks <b>if</b> given chain ID is reserved.
    <b>assert</b>!(
        !<a href="microchain_registry.md#0x1_microchain_registry_is_chain_id_reserved_internal">is_chain_id_reserved_internal</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>, &<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.reserved_ranges),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="microchain_registry.md#0x1_microchain_registry_ECHAIN_ID_RESERVED">ECHAIN_ID_RESERVED</a>)
    );
    // Checks <b>if</b> a microchain is already registered.
    <b>assert</b>!(
        !<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_ALREADY_REGISTERED">EMICROCHAIN_ALREADY_REGISTERED</a>)
    );

    <b>let</b> microchain_info = <a href="microchain_registry.md#0x1_microchain_registry_MicrochainInfo">MicrochainInfo</a> {
        state: <a href="microchain_registry.md#0x1_microchain_registry_STATE_ACTIVE">STATE_ACTIVE</a>,
        metadata_link,
    };
    <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_add">simple_map::add</a>(&<b>mut</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, <a href="chain_id.md#0x1_chain_id">chain_id</a>, microchain_info);

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistered">MicrochainRegistered</a> {
        <a href="chain_id.md#0x1_chain_id">chain_id</a>,
        metadata_link,
    });
}
</code></pre>



</details>

<a id="0x1_microchain_registry_deactivate_microchain"></a>

## Function `deactivate_microchain`

Deactivates the already registered microchain.

This method requires the <code>supra_framework</code> as a signer. Therefore, externally (out of the supra-framework package),
it can only be invoked through a governance proposal move-script.

It is strongly recommended to trigger an epoch change by calling <code><a href="supra_governance.md#0x1_supra_governance_reconfigure">0x1::supra_governance::reconfigure</a></code>
after invoking this method. While this method could perform the reconfiguration internally, it
intentionally does not. This is because governance proposal move-scripts may need to invoke
additional methods after this one, so the responsibility of reconfiguration is left to the caller.

Example usage:
```
supra_framework::microchain_registry::deactivate_microchain(&supra_framework, chain_id);
supra_framework::supra_governance::reconfigure(&supra_framework);
```


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_deactivate_microchain">deactivate_microchain</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_deactivate_microchain">deactivate_microchain</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8,
) <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_mut_microchain_registry">borrow_global_mut_microchain_registry</a>(supra_framework);
    <a href="microchain_registry.md#0x1_microchain_registry_assert_microchain_registered">assert_microchain_registered</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);

    <b>let</b> microchain_infp = <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow_mut">simple_map::borrow_mut</a>(&<b>mut</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);
    <b>assert</b>!(microchain_infp.state == <a href="microchain_registry.md#0x1_microchain_registry_STATE_ACTIVE">STATE_ACTIVE</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_ALREADY_DEACTIVATED">EMICROCHAIN_ALREADY_DEACTIVATED</a>));

    microchain_infp.state = <a href="microchain_registry.md#0x1_microchain_registry_STATE_INACTIVE">STATE_INACTIVE</a>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="microchain_registry.md#0x1_microchain_registry_MicrochainDeactivated">MicrochainDeactivated</a> {
        <a href="chain_id.md#0x1_chain_id">chain_id</a>,
    });
}
</code></pre>



</details>

<a id="0x1_microchain_registry_reactivate_microchain"></a>

## Function `reactivate_microchain`

Reactivates the deactivated microchain.

This method requires the <code>supra_framework</code> as a signer. Therefore, externally (out of the supra-framework package),
it can only be invoked through a governance proposal move-script.

It is strongly recommended to trigger an epoch change by calling <code><a href="supra_governance.md#0x1_supra_governance_reconfigure">0x1::supra_governance::reconfigure</a></code>
after invoking this method. While this method could perform the reconfiguration internally, it
intentionally does not. This is because governance proposal move-scripts may need to invoke
additional methods after this one, so the responsibility of reconfiguration is left to the caller.

Example usage:
```
supra_framework::microchain_registry::reactivate_microchain(&supra_framework, chain_id);
supra_framework::supra_governance::reconfigure(&supra_framework);
```


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_reactivate_microchain">reactivate_microchain</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_reactivate_microchain">reactivate_microchain</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8,
) <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_mut_microchain_registry">borrow_global_mut_microchain_registry</a>(supra_framework);
    <a href="microchain_registry.md#0x1_microchain_registry_assert_microchain_registered">assert_microchain_registered</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);

    <b>let</b> microchain_infp = <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow_mut">simple_map::borrow_mut</a>(&<b>mut</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);
    <b>assert</b>!(microchain_infp.state == <a href="microchain_registry.md#0x1_microchain_registry_STATE_INACTIVE">STATE_INACTIVE</a>, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_ALREADY_ACTIVE">EMICROCHAIN_ALREADY_ACTIVE</a>));

    microchain_infp.state = <a href="microchain_registry.md#0x1_microchain_registry_STATE_ACTIVE">STATE_ACTIVE</a>;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="microchain_registry.md#0x1_microchain_registry_MicrochainReactivated">MicrochainReactivated</a> {
        <a href="chain_id.md#0x1_chain_id">chain_id</a>,
    });
}
</code></pre>



</details>

<a id="0x1_microchain_registry_update_microchain_metadata_link"></a>

## Function `update_microchain_metadata_link`

Updates metadata link of a registered microchain.


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_update_microchain_metadata_link">update_microchain_metadata_link</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8, new_metadata_link: <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_update_microchain_metadata_link">update_microchain_metadata_link</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8,
    new_metadata_link: String,
) <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_mut_microchain_registry">borrow_global_mut_microchain_registry</a>(supra_framework);
    <a href="microchain_registry.md#0x1_microchain_registry_assert_microchain_registered">assert_microchain_registered</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);

    <b>let</b> microchain_infp = <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow_mut">simple_map::borrow_mut</a>(&<b>mut</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);
    <b>let</b> old_metadata_link = microchain_infp.metadata_link;
    microchain_infp.metadata_link = new_metadata_link;

    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="microchain_registry.md#0x1_microchain_registry_MicrochainMetadataLinkUpdated">MicrochainMetadataLinkUpdated</a> {
        <a href="chain_id.md#0x1_chain_id">chain_id</a>,
        old_metadata_link,
        new_metadata_link,
    });
}
</code></pre>



</details>

<a id="0x1_microchain_registry_add_reserved_range"></a>

## Function `add_reserved_range`

Adds a reserved chain ID range.


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_add_reserved_range">add_reserved_range</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, start: u8, end: u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_add_reserved_range">add_reserved_range</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    start: u8,
    end: u8,
) <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_mut_microchain_registry">borrow_global_mut_microchain_registry</a>(supra_framework);
    <b>assert</b>!(start &lt;= end, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="microchain_registry.md#0x1_microchain_registry_EINVALID_RANGE">EINVALID_RANGE</a>));

    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.reserved_ranges, <a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">ReservedRange</a> { start, end });
}
</code></pre>



</details>

<a id="0x1_microchain_registry_new_reserved_range"></a>

## Function `new_reserved_range`

Constructor to create an instance of the <code><a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">ReservedRange</a></code>.
This will be utilized in move-script to initialize the microchain registry with reserved ranges.


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_new_reserved_range">new_reserved_range</a>(start: u8, end: u8): <a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">microchain_registry::ReservedRange</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_new_reserved_range">new_reserved_range</a>(
    start: u8,
    end: u8,
): <a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">ReservedRange</a> {
    <b>assert</b>!(start &lt;= end, <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="microchain_registry.md#0x1_microchain_registry_EINVALID_RANGE">EINVALID_RANGE</a>));
    <a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">ReservedRange</a> { start, end }
}
</code></pre>



</details>

<a id="0x1_microchain_registry_microchain_state"></a>

## Function `microchain_state`

Get the state of a microchain.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_microchain_state">microchain_state</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): u8
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_microchain_state">microchain_state</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): u8 <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_microchain_registry">borrow_global_microchain_registry</a>();
    <b>if</b> (<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>)) {
        <b>return</b> <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow">simple_map::borrow</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>).state;
    };

    <a href="microchain_registry.md#0x1_microchain_registry_STATE_UNKNOWN">STATE_UNKNOWN</a>
}
</code></pre>



</details>

<a id="0x1_microchain_registry_is_microchain_active"></a>

## Function `is_microchain_active`

Check if a microchain is active.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_is_microchain_active">is_microchain_active</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_is_microchain_active">is_microchain_active</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): bool <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <a href="microchain_registry.md#0x1_microchain_registry_microchain_state">microchain_state</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>) == <a href="microchain_registry.md#0x1_microchain_registry_STATE_ACTIVE">STATE_ACTIVE</a>
}
</code></pre>



</details>

<a id="0x1_microchain_registry_active_microchains"></a>

## Function `active_microchains`

Get chain IDs of all microchain with <code>Active</code> state.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_active_microchains">active_microchains</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_active_microchains">active_microchains</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u8&gt; <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_microchain_registry">borrow_global_microchain_registry</a>();
    <b>let</b> microchains_chain_id = <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_keys">simple_map::keys</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains);
    <b>let</b> microchains_info = <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_values">simple_map::values</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains);
    <b>let</b> active_microchains_chain_id = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>&lt;u8&gt;();
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_zip_reverse">vector::zip_reverse</a>&lt;u8, <a href="microchain_registry.md#0x1_microchain_registry_MicrochainInfo">MicrochainInfo</a>&gt;(microchains_chain_id, microchains_info, |<a href="chain_id.md#0x1_chain_id">chain_id</a>, microchain_info|{
        // New helper variable <b>with</b> explicit type annotation is required due <b>to</b> Move's lambda type inference
        // limitations. When I don't <b>use</b> this new variable <b>with</b> explicit type declaration, compiler throws <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">error</a>
        // and ask <b>to</b> infer the type.
        <b>let</b> info: <a href="microchain_registry.md#0x1_microchain_registry_MicrochainInfo">MicrochainInfo</a> = microchain_info;
        <b>if</b> (info.state == <a href="microchain_registry.md#0x1_microchain_registry_STATE_ACTIVE">STATE_ACTIVE</a>) {
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> active_microchains_chain_id, <a href="chain_id.md#0x1_chain_id">chain_id</a>);
        }
    });
    active_microchains_chain_id
}
</code></pre>



</details>

<a id="0x1_microchain_registry_microchain_metadata_link"></a>

## Function `microchain_metadata_link`

Get microchain metadata link.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_microchain_metadata_link">microchain_metadata_link</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_microchain_metadata_link">microchain_metadata_link</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): String <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_microchain_registry">borrow_global_microchain_registry</a>();
    <a href="microchain_registry.md#0x1_microchain_registry_assert_microchain_registered">assert_microchain_registered</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);

    <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow">simple_map::borrow</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>).metadata_link
}
</code></pre>



</details>

<a id="0x1_microchain_registry_microchain_info"></a>

## Function `microchain_info`

Get microchain info.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_microchain_info">microchain_info</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): (u8, <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_microchain_info">microchain_info</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): (u8, String) <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>let</b> <a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a> = <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_microchain_registry">borrow_global_microchain_registry</a>();
    <a href="microchain_registry.md#0x1_microchain_registry_assert_microchain_registered">assert_microchain_registered</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);

    <b>let</b> microchain = <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_borrow">simple_map::borrow</a>(&<a href="microchain_registry.md#0x1_microchain_registry">microchain_registry</a>.microchains, &<a href="chain_id.md#0x1_chain_id">chain_id</a>);
    (microchain.state, microchain.metadata_link)
}
</code></pre>



</details>

<a id="0x1_microchain_registry_is_chain_id_reserved"></a>

## Function `is_chain_id_reserved`

Check if a chain ID falls within reserved ranges.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_is_chain_id_reserved">is_chain_id_reserved</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_is_chain_id_reserved">is_chain_id_reserved</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8): bool <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <a href="microchain_registry.md#0x1_microchain_registry_is_chain_id_reserved_internal">is_chain_id_reserved_internal</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>, &<a href="microchain_registry.md#0x1_microchain_registry_borrow_global_microchain_registry">borrow_global_microchain_registry</a>().reserved_ranges)
}
</code></pre>



</details>

<a id="0x1_microchain_registry_borrow_global_microchain_registry"></a>

## Function `borrow_global_microchain_registry`



<pre><code><b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_microchain_registry">borrow_global_microchain_registry</a>(): &<a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">microchain_registry::MicrochainRegistry</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_microchain_registry">borrow_global_microchain_registry</a>(): &<a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <b>assert</b>!(<b>exists</b>&lt;<a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a>&gt;(@supra_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="microchain_registry.md#0x1_microchain_registry_EREGISTRY_NOT_INITIALIZED">EREGISTRY_NOT_INITIALIZED</a>));
    <b>borrow_global</b>&lt;<a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a>&gt;(@supra_framework)
}
</code></pre>



</details>

<a id="0x1_microchain_registry_borrow_global_mut_microchain_registry"></a>

## Function `borrow_global_mut_microchain_registry`



<pre><code><b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_mut_microchain_registry">borrow_global_mut_microchain_registry</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>): &<b>mut</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">microchain_registry::MicrochainRegistry</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_borrow_global_mut_microchain_registry">borrow_global_mut_microchain_registry</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
): &<b>mut</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> <b>acquires</b> <a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>assert</b>!(<b>exists</b>&lt;<a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a>&gt;(@supra_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="microchain_registry.md#0x1_microchain_registry_EREGISTRY_NOT_INITIALIZED">EREGISTRY_NOT_INITIALIZED</a>));
    <b>borrow_global_mut</b>&lt;<a href="microchain_registry.md#0x1_microchain_registry_MicrochainRegistry">MicrochainRegistry</a>&gt;(@supra_framework)
}
</code></pre>



</details>

<a id="0x1_microchain_registry_assert_microchain_registered"></a>

## Function `assert_microchain_registered`



<pre><code><b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_assert_microchain_registered">assert_microchain_registered</a>(microchains: &<a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_SimpleMap">simple_map::SimpleMap</a>&lt;u8, <a href="microchain_registry.md#0x1_microchain_registry_MicrochainInfo">microchain_registry::MicrochainInfo</a>&gt;, <a href="chain_id.md#0x1_chain_id">chain_id</a>: &u8)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_assert_microchain_registered">assert_microchain_registered</a>(microchains: &SimpleMap&lt;u8, <a href="microchain_registry.md#0x1_microchain_registry_MicrochainInfo">MicrochainInfo</a>&gt;, <a href="chain_id.md#0x1_chain_id">chain_id</a>: &u8) {
    <b>assert</b>!(
        <a href="../../aptos-stdlib/doc/simple_map.md#0x1_simple_map_contains_key">simple_map::contains_key</a>(microchains, <a href="chain_id.md#0x1_chain_id">chain_id</a>),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="microchain_registry.md#0x1_microchain_registry_EMICROCHAIN_NOT_REGISTERED">EMICROCHAIN_NOT_REGISTERED</a>)
    );
}
</code></pre>



</details>

<a id="0x1_microchain_registry_is_chain_id_reserved_internal"></a>

## Function `is_chain_id_reserved_internal`



<pre><code><b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_is_chain_id_reserved_internal">is_chain_id_reserved_internal</a>(<a href="chain_id.md#0x1_chain_id">chain_id</a>: u8, reserved_ranges: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">microchain_registry::ReservedRange</a>&gt;): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="microchain_registry.md#0x1_microchain_registry_is_chain_id_reserved_internal">is_chain_id_reserved_internal</a>(
    <a href="chain_id.md#0x1_chain_id">chain_id</a>: u8,
    reserved_ranges: &<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="microchain_registry.md#0x1_microchain_registry_ReservedRange">ReservedRange</a>&gt;
): bool {
    <b>let</b> i = 0;
    <b>let</b> total_ranges = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(reserved_ranges);
    <b>while</b> (i &lt; total_ranges) {
        <b>let</b> range = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(reserved_ranges, i);
        <b>if</b> (<a href="chain_id.md#0x1_chain_id">chain_id</a> &gt;= range.start && <a href="chain_id.md#0x1_chain_id">chain_id</a> &lt;= range.end) {
            <b>return</b> <b>true</b>
        };
        i = i + 1;
    };

    <b>false</b>
}
</code></pre>



</details>

<a id="@Specification_1"></a>

## Specification



<pre><code><b>pragma</b> verify = <b>false</b>;
</code></pre>


[move-book]: https://aptos.dev/move/book/SUMMARY
