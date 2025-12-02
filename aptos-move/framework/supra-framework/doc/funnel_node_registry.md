
<a id="0x1_funnel_node_registry"></a>

# Module `0x1::funnel_node_registry`

Copyright (c) 2025 Supra

Funnel Node Registry Module

This module manages a list of registered funnel nodes' IP/DNS addresses.


-  [Resource `FunnelNodeRegistry`](#0x1_funnel_node_registry_FunnelNodeRegistry)
-  [Struct `FunnelNodesUpdated`](#0x1_funnel_node_registry_FunnelNodesUpdated)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_funnel_node_registry_initialize)
-  [Function `update_funnel_nodes`](#0x1_funnel_node_registry_update_funnel_nodes)
-  [Function `funnel_nodes`](#0x1_funnel_node_registry_funnel_nodes)
-  [Function `assert_registry_initialized`](#0x1_funnel_node_registry_assert_registry_initialized)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string">0x1::string</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
</code></pre>



<a id="0x1_funnel_node_registry_FunnelNodeRegistry"></a>

## Resource `FunnelNodeRegistry`

Global funnel node registry resource.


<pre><code>#[resource_group_member(#[group = <a href="object.md#0x1_object_ObjectGroup">0x1::object::ObjectGroup</a>])]
<b>struct</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a> <b>has</b> key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>funnel_nodes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="0x1_funnel_node_registry_FunnelNodesUpdated"></a>

## Struct `FunnelNodesUpdated`



<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodesUpdated">FunnelNodesUpdated</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>old_funnel_nodes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;</code>
</dt>
<dd>

</dd>
<dt>
<code>new_funnel_nodes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;</code>
</dt>
<dd>

</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_funnel_node_registry_EREGISTRY_NOT_INITIALIZED"></a>

The <code><a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a></code> resource has not been initialized at @supra_framework.


<pre><code><b>const</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_EREGISTRY_NOT_INITIALIZED">EREGISTRY_NOT_INITIALIZED</a>: u64 = 1;
</code></pre>



<a id="0x1_funnel_node_registry_initialize"></a>

## Function `initialize`

Initializes the funnel node registry.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, funnel_nodes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_initialize">initialize</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, funnel_nodes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);

    <b>move_to</b>(supra_framework, <a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a> {
        funnel_nodes,
    });
}
</code></pre>



</details>

<a id="0x1_funnel_node_registry_update_funnel_nodes"></a>

## Function `update_funnel_nodes`

Updates the funnel nodes in the funnel node registry.

This method replaces the existing list of funnel nodes with the provided list. Therefore, it is
strongly recommended that the new list contains valid URLs for all funnel nodes, and that the nodes
are ordered based on their reputation and trust level.

Technically, deduplication of <code>new_funnel_nodes</code> is necessary. However, performing it consumes a
significant amount of execution gas. Since this method is expected to be invoked by appchain
governance - which is assumed to perform governance operations carefully - the <code>new_funnel_nodes</code>
list is **not** deduplicated internally. As a result, it is possible to pass a list containing duplicate
entries without triggering an error. Therefore, deduplication should be performed as part of
the validator node's sanity checks.

This method requires the <code>supra_framework</code> as a signer. Therefore, externally (out of the supra-framework package),
it can only be invoked through a governance proposal move-script.

It is strongly recommended to trigger an epoch change by calling <code><a href="supra_governance.md#0x1_supra_governance_reconfigure">0x1::supra_governance::reconfigure</a></code>
after invoking this method. While this method could perform the reconfiguration internally, it
intentionally does not. This is because governance proposal move-scripts may need to invoke
additional methods after this one, so the responsibility of reconfiguration is left to the caller.

Example usage:
```
supra_framework::funnel_node_registry::update_funnel_nodes(&supra_framework, new_funnel_nodes);
supra_framework::supra_governance::reconfigure(&supra_framework);
```


<pre><code><b>public</b> <b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_update_funnel_nodes">update_funnel_nodes</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_funnel_nodes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_update_funnel_nodes">update_funnel_nodes</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>,
    new_funnel_nodes: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt;
) <b>acquires</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <a href="funnel_node_registry.md#0x1_funnel_node_registry_assert_registry_initialized">assert_registry_initialized</a>();

    <b>let</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry">funnel_node_registry</a> = <b>borrow_global_mut</b>&lt;<a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a>&gt;(@supra_framework);
    <b>let</b> old_funnel_nodes = <a href="funnel_node_registry.md#0x1_funnel_node_registry">funnel_node_registry</a>.funnel_nodes;
    <a href="funnel_node_registry.md#0x1_funnel_node_registry">funnel_node_registry</a>.funnel_nodes = new_funnel_nodes;
    <a href="event.md#0x1_event_emit">event::emit</a>(<a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodesUpdated">FunnelNodesUpdated</a> {
        old_funnel_nodes,
        new_funnel_nodes
    })
}
</code></pre>



</details>

<a id="0x1_funnel_node_registry_funnel_nodes"></a>

## Function `funnel_nodes`

Get funnel nodes list.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_funnel_nodes">funnel_nodes</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="../../aptos-stdlib/../move-stdlib/doc/string.md#0x1_string_String">string::String</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_funnel_nodes">funnel_nodes</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;String&gt; <b>acquires</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a> {
    <a href="funnel_node_registry.md#0x1_funnel_node_registry_assert_registry_initialized">assert_registry_initialized</a>();
    <b>borrow_global_mut</b>&lt;<a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a>&gt;(@supra_framework).funnel_nodes
}
</code></pre>



</details>

<a id="0x1_funnel_node_registry_assert_registry_initialized"></a>

## Function `assert_registry_initialized`



<pre><code><b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_assert_registry_initialized">assert_registry_initialized</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code>inline <b>fun</b> <a href="funnel_node_registry.md#0x1_funnel_node_registry_assert_registry_initialized">assert_registry_initialized</a>() {
    <b>assert</b>!(<b>exists</b>&lt;<a href="funnel_node_registry.md#0x1_funnel_node_registry_FunnelNodeRegistry">FunnelNodeRegistry</a>&gt;(@supra_framework), <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_not_found">error::not_found</a>(<a href="funnel_node_registry.md#0x1_funnel_node_registry_EREGISTRY_NOT_INITIALIZED">EREGISTRY_NOT_INITIALIZED</a>));
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
