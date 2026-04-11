
<a id="0x1_leader_ban_registry"></a>

# Module `0x1::leader_ban_registry`

Maintains the list of banned validators and updates counters on every epoch.

This implementation assumes that each validator is elected once every <code>n</code> consensus rounds on expectation,
where <code>n</code> is the number of validators in the consensus committee (i.e. the <code>ValidatorSet</code>).


-  [Struct `ActiveBan`](#0x1_leader_ban_registry_ActiveBan)
-  [Struct `ValidatorBans`](#0x1_leader_ban_registry_ValidatorBans)
-  [Resource `BanRegistry`](#0x1_leader_ban_registry_BanRegistry)
-  [Resource `LatestView`](#0x1_leader_ban_registry_LatestView)
-  [Struct `Banned`](#0x1_leader_ban_registry_Banned)
-  [Struct `ReinstatedWithProbation`](#0x1_leader_ban_registry_ReinstatedWithProbation)
-  [Struct `Reinstated`](#0x1_leader_ban_registry_Reinstated)
-  [Constants](#@Constants_0)
-  [Function `initialize_leader_ban_registry`](#0x1_leader_ban_registry_initialize_leader_ban_registry)
-  [Function `get_ban_registry`](#0x1_leader_ban_registry_get_ban_registry)
-  [Function `get_latest_view`](#0x1_leader_ban_registry_get_latest_view)
-  [Function `get_initial_ban_duration`](#0x1_leader_ban_registry_get_initial_ban_duration)
-  [Function `get_max_ban_duration`](#0x1_leader_ban_registry_get_max_ban_duration)
-  [Function `get_probation_duration`](#0x1_leader_ban_registry_get_probation_duration)
-  [Function `get_remaining_ban_duration`](#0x1_leader_ban_registry_get_remaining_ban_duration)
-  [Function `get_remaining_probation_duration`](#0x1_leader_ban_registry_get_remaining_probation_duration)
-  [Function `update_ban_registry`](#0x1_leader_ban_registry_update_ban_registry)
-  [Function `ban_failed_proposers`](#0x1_leader_ban_registry_ban_failed_proposers)
-  [Function `reinstate_expired_bans`](#0x1_leader_ban_registry_reinstate_expired_bans)
-  [Function `on_new_epoch`](#0x1_leader_ban_registry_on_new_epoch)
-  [Function `remaining_ban_duration`](#0x1_leader_ban_registry_remaining_ban_duration)
-  [Function `remaining_probation_duration`](#0x1_leader_ban_registry_remaining_probation_duration)
-  [Function `can_be_banned`](#0x1_leader_ban_registry_can_be_banned)
-  [Function `assert_registry_initialized`](#0x1_leader_ban_registry_assert_registry_initialized)


<pre><code><b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="event.md#0x1_event">0x1::event</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features">0x1::features</a>;
<b>use</b> <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config">0x1::leader_ban_registry_config</a>;
<b>use</b> <a href="../../aptos-stdlib/doc/math64.md#0x1_math64">0x1::math64</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option">0x1::option</a>;
<b>use</b> <a href="stake.md#0x1_stake">0x1::stake</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">0x1::vector</a>;
</code></pre>



<a id="0x1_leader_ban_registry_ActiveBan"></a>

## Struct `ActiveBan`

Information about a ban that is currently in effect for a validator.


<pre><code><b>struct</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_ActiveBan">ActiveBan</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>epoch_earned: u64</code>
</dt>
<dd>
 The consensus epoch in which the current ban was issued (if <code>on_probation</code> is <code><b>false</b></code>) or
 when its probation period started (if <code>on_probation</code> is <code><b>true</b></code>).
</dd>
<dt>
<code>round_earned: u64</code>
</dt>
<dd>
 The consensus round in which the current ban was issued (if <code>on_probation</code> is <code><b>false</b></code>) or
 when its probation period started (if <code>on_probation</code> is <code><b>true</b></code>).
</dd>
<dt>
<code>rounds_served_in_previous_epochs: u64</code>
</dt>
<dd>
 Round count incremented on every epoch change
</dd>
<dt>
<code>on_probation: bool</code>
</dt>
<dd>
 If <code><b>true</b></code> then the current ban period has expired and the validator is currently on probation; i.e., it is
 eligible for election but will be banned for a longer period if it once again fails to propose a canonical
 block when elected. If <code><b>true</b></code> then the other fields of this struct denote the consensus view in which
 the probation period started.
</dd>
</dl>


</details>

<a id="0x1_leader_ban_registry_ValidatorBans"></a>

## Struct `ValidatorBans`

Holds validator metrics regarding duration pool address etc


<pre><code><b>struct</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>active: <a href="leader_ban_registry.md#0x1_leader_ban_registry_ActiveBan">leader_ban_registry::ActiveBan</a></code>
</dt>
<dd>
 Information about the ban that is currently in effect.
</dd>
<dt>
<code>consecutive_bans: u32</code>
</dt>
<dd>
 The number of consecutive probations that this validator has failed.
</dd>
<dt>
<code>pool_address: <b>address</b></code>
</dt>
<dd>
 Validator's pool address
</dd>
</dl>


</details>

<a id="0x1_leader_ban_registry_BanRegistry"></a>

## Resource `BanRegistry`

Holds ban registry


<pre><code><b>struct</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a> <b>has</b> drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>bans: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">leader_ban_registry::ValidatorBans</a>&gt;</code>
</dt>
<dd>
 List of validator active bans with pool address
</dd>
</dl>


</details>

<a id="0x1_leader_ban_registry_LatestView"></a>

## Resource `LatestView`

Holds latest processed round and epoch


<pre><code><b>struct</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> <b>has</b> <b>copy</b>, drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>epoch: u64</code>
</dt>
<dd>
 Epoch
</dd>
<dt>
<code>round: u64</code>
</dt>
<dd>
 Round
</dd>
</dl>


</details>

<a id="0x1_leader_ban_registry_Banned"></a>

## Struct `Banned`

Emits when validator receives a ban or consucutive ban occurred


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_Banned">Banned</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>pool_address: <b>address</b></code>
</dt>
<dd>
 Validator's pool address
</dd>
<dt>
<code>epoch: u64</code>
</dt>
<dd>
 Epoch
</dd>
<dt>
<code>round: u64</code>
</dt>
<dd>
 Round
</dd>
<dt>
<code>consecutive_bans: u32</code>
</dt>
<dd>
 The number of consecutive probations that this validator has failed.
</dd>
</dl>


</details>

<a id="0x1_leader_ban_registry_ReinstatedWithProbation"></a>

## Struct `ReinstatedWithProbation`

Emitted when a validator's ban is lifted and its probation period starts. A validator that is on probation is
eligible for election again, but will be banned for longer if it once again fails to propose a canonical block.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_ReinstatedWithProbation">ReinstatedWithProbation</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>pool_address: <b>address</b></code>
</dt>
<dd>
 Validator's pool address
</dd>
<dt>
<code>epoch: u64</code>
</dt>
<dd>
 Epoch
</dd>
<dt>
<code>round: u64</code>
</dt>
<dd>
 Round
</dd>
</dl>


</details>

<a id="0x1_leader_ban_registry_Reinstated"></a>

## Struct `Reinstated`

Emitted when a validator's probation period ends without the validator earning a new ban.


<pre><code>#[<a href="event.md#0x1_event">event</a>]
<b>struct</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_Reinstated">Reinstated</a> <b>has</b> drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>pool_address: <b>address</b></code>
</dt>
<dd>
 Validator's pool address
</dd>
<dt>
<code>epoch: u64</code>
</dt>
<dd>
 Epoch
</dd>
<dt>
<code>round: u64</code>
</dt>
<dd>
 Round
</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_leader_ban_registry_EBAN_REGISTRY_ALREADY_EXISTS"></a>

Leader ban registry already initialized


<pre><code><b>const</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_EBAN_REGISTRY_ALREADY_EXISTS">EBAN_REGISTRY_ALREADY_EXISTS</a>: u64 = 1;
</code></pre>



<a id="0x1_leader_ban_registry_EBAN_REGISTRY_NOT_INITIALIZED"></a>

Leader ban registry not initialized


<pre><code><b>const</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_EBAN_REGISTRY_NOT_INITIALIZED">EBAN_REGISTRY_NOT_INITIALIZED</a>: u64 = 2;
</code></pre>



<a id="0x1_leader_ban_registry_ELATEST_VIEW_ALREADY_EXISTS"></a>

Latest view already initialized


<pre><code><b>const</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_ELATEST_VIEW_ALREADY_EXISTS">ELATEST_VIEW_ALREADY_EXISTS</a>: u64 = 3;
</code></pre>



<a id="0x1_leader_ban_registry_initialize_leader_ban_registry"></a>

## Function `initialize_leader_ban_registry`

Initialise leader ban registry


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_initialize_leader_ban_registry">initialize_leader_ban_registry</a>(supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_initialize_leader_ban_registry">initialize_leader_ban_registry</a>(
    supra_framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>
) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(supra_framework);
    <b>assert</b>!(
        !<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="leader_ban_registry.md#0x1_leader_ban_registry_EBAN_REGISTRY_ALREADY_EXISTS">EBAN_REGISTRY_ALREADY_EXISTS</a>)
    );
    <b>assert</b>!(
        !<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_already_exists">error::already_exists</a>(<a href="leader_ban_registry.md#0x1_leader_ban_registry_EBAN_REGISTRY_ALREADY_EXISTS">EBAN_REGISTRY_ALREADY_EXISTS</a>)
    );
    <b>move_to</b>(supra_framework, <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a> { bans: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>() });
    <b>move_to</b>(supra_framework, <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> { epoch: 0, round: 0 });
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_get_ban_registry"></a>

## Function `get_ban_registry`

Returns list of validators active ban with it's pool address


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_ban_registry">get_ban_registry</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">leader_ban_registry::ValidatorBans</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_ban_registry">get_ban_registry</a>(): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a>&gt; <b>acquires</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework)) {
        <b>return</b> <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>()
    };
    <b>let</b> ban_registry = <b>borrow_global</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework);
    ban_registry.bans
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_get_latest_view"></a>

## Function `get_latest_view`

Return latest view


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_latest_view">get_latest_view</a>(): <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">leader_ban_registry::LatestView</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_latest_view">get_latest_view</a>(): <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> <b>acquires</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework)) {
        <b>return</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> { epoch: 0, round: 0 }
    };
    <b>let</b> latest_view = <b>borrow_global</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework);
    *latest_view
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_get_initial_ban_duration"></a>

## Function `get_initial_ban_duration`

Returns the number of consensus rounds that a validator is banned for when it fails to propose a
canonical block when elected as leader whilst not on probation.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_initial_ban_duration">get_initial_ban_duration</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_initial_ban_duration">get_initial_ban_duration</a>(): u64 {
    <b>let</b> initial_elections_denied =
        <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_initial_elections_denied">leader_ban_registry_config::get_initial_elections_denied</a>();
    <b>let</b> committee_size = <a href="stake.md#0x1_stake_get_committee_size">stake::get_committee_size</a>();
    committee_size * (initial_elections_denied <b>as</b> u64)
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_get_max_ban_duration"></a>

## Function `get_max_ban_duration`

Returns the maximum number of consensus rounds that a validator may banned for when it repeatedly fails to
propose a canonical block when elected as leader whilst on probation.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_max_ban_duration">get_max_ban_duration</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_max_ban_duration">get_max_ban_duration</a>(): u64 {
    <b>let</b> max_elections_denied = <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_max_elections_denied">leader_ban_registry_config::get_max_elections_denied</a>();
    <b>let</b> committee_size = <a href="stake.md#0x1_stake_get_committee_size">stake::get_committee_size</a>();
    committee_size * (max_elections_denied <b>as</b> u64)
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_get_probation_duration"></a>

## Function `get_probation_duration`

Returns the number of consensus rounds that a validator is considered to be on probation for after having
served its most recent ban.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_probation_duration">get_probation_duration</a>(): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_probation_duration">get_probation_duration</a>(): u64 {
    <b>let</b> probation_elections = <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_probation_elections">leader_ban_registry_config::get_probation_elections</a>();
    <b>let</b> committee_size = <a href="stake.md#0x1_stake_get_committee_size">stake::get_committee_size</a>();
    committee_size * (probation_elections <b>as</b> u64)
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_get_remaining_ban_duration"></a>

## Function `get_remaining_ban_duration`

Returns the number of consensus rounds remaining in the ban for the validator with the given
pool address. Returns 0 if the validator is not banned (including if it is on probation).


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_remaining_ban_duration">get_remaining_ban_duration</a>(pool_address: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_remaining_ban_duration">get_remaining_ban_duration</a>(
    pool_address: <b>address</b>
): u64 <b>acquires</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>, <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework)
        || !<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework)) {
        <b>return</b> 0
    };
    <b>let</b> ban_registry = <b>borrow_global</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework);
    <b>let</b> latest_view = <b>borrow_global</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework);
    <b>let</b> (found, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_find">vector::find</a>(
        &ban_registry.bans,
        |v| {
            <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
            v.pool_address == pool_address && !v.active.on_probation
        }
    );
    <b>if</b> (found) {
        <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_ban_duration">remaining_ban_duration</a>(
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&ban_registry.bans, index), latest_view
        )
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_get_remaining_probation_duration"></a>

## Function `get_remaining_probation_duration`

Returns the number of consensus rounds remaining in the probation period for the validator
with the given pool address. Returns 0 if the validator is not on probation.


<pre><code>#[view]
<b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_remaining_probation_duration">get_remaining_probation_duration</a>(pool_address: <b>address</b>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_remaining_probation_duration">get_remaining_probation_duration</a>(
    pool_address: <b>address</b>
): u64 <b>acquires</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>, <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework)
        || !<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework)) {
        <b>return</b> 0
    };
    <b>let</b> ban_registry = <b>borrow_global</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework);
    <b>let</b> latest_view = <b>borrow_global</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework);
    <b>let</b> (found, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_find">vector::find</a>(
        &ban_registry.bans,
        |v| {
            <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
            v.pool_address == pool_address && v.active.on_probation
        }
    );
    <b>if</b> (found) {
        <b>let</b> probation_dur = <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_probation_duration">get_probation_duration</a>();
        <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_probation_duration">remaining_probation_duration</a>(
            <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&ban_registry.bans, index),
            latest_view,
            probation_dur
        )
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_update_ban_registry"></a>

## Function `update_ban_registry`

Add or update the ban registry as per block metadata


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_update_ban_registry">update_ban_registry</a>(current_epoch: u64, current_round: u64, proposer_index: <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_Option">option::Option</a>&lt;u64&gt;, failed_proposer_indices: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_update_ban_registry">update_ban_registry</a>(
    current_epoch: u64,
    current_round: u64,
    proposer_index: Option&lt;u64&gt;,
    failed_proposer_indices: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;
) <b>acquires</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>, <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework)) { <b>return</b> };
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework)) { <b>return</b> };
    <b>let</b> ban_registry = <b>borrow_global_mut</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework);
    <b>let</b> latest_view = <b>borrow_global_mut</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework);
    latest_view.epoch = current_epoch;
    latest_view.round = current_round;

    // ban the failed proposers
    <a href="leader_ban_registry.md#0x1_leader_ban_registry_ban_failed_proposers">ban_failed_proposers</a>(latest_view, failed_proposer_indices, ban_registry);

    // remove expired bans
    <a href="leader_ban_registry.md#0x1_leader_ban_registry_reinstate_expired_bans">reinstate_expired_bans</a>(latest_view, ban_registry);
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_ban_failed_proposers"></a>

## Function `ban_failed_proposers`

Adds failed proposer indices to ban registry


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_ban_failed_proposers">ban_failed_proposers</a>(latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">leader_ban_registry::LatestView</a>, failed_proposer_indices: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;, ban_registry: &<b>mut</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">leader_ban_registry::BanRegistry</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_ban_failed_proposers">ban_failed_proposers</a>(
    latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>,
    failed_proposer_indices: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;u64&gt;,
    ban_registry: &<b>mut</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>
) {
    <b>let</b> initial_ban_duration = <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_initial_ban_duration">get_initial_ban_duration</a>();
    <b>if</b> (initial_ban_duration == 0) { <b>return</b> };

    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each">vector::for_each</a>(
        failed_proposer_indices,
        |failed_validator_index| {
            <b>let</b> validator_pool_address_opt =
                <a href="stake.md#0x1_stake_get_pool_address_from_index">stake::get_pool_address_from_index</a>(failed_validator_index);

            <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_is_some">option::is_some</a>(&validator_pool_address_opt)) {
                <b>let</b> validator_pool_address =
                    <a href="../../aptos-stdlib/../move-stdlib/doc/option.md#0x1_option_extract">option::extract</a>(&<b>mut</b> validator_pool_address_opt);
                <b>let</b> (is_banned, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_find">vector::find</a>(
                    &ban_registry.bans,
                    |v| {
                        <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
                        validator_pool_address == v.pool_address
                    }
                );
                <b>if</b> (is_banned) {
                    // Validator is already in registry (either banned or on probation).
                    // Re-banning resets the ban period and increases consecutive count.
                    // If the consensus <a href="code.md#0x1_code">code</a> is implemented correctly then the validator should
                    // not be re-banned whilst serving a ban <b>as</b> it should not be eligible for election
                    // when banned (i.e. this branch should only be taken when a validator is on probation).
                    <b>let</b> bans = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow_mut">vector::borrow_mut</a>(&<b>mut</b> ban_registry.bans, index);
                    bans.consecutive_bans = bans.consecutive_bans + 1;
                    bans.active.round_earned = latest_view.round;
                    bans.active.epoch_earned = latest_view.epoch;
                    bans.active.rounds_served_in_previous_epochs = 0;
                    bans.active.on_probation = <b>false</b>; // Reset <b>to</b> banned state

                    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_module_event_enabled">features::module_event_enabled</a>()) {
                        <a href="event.md#0x1_event_emit">event::emit</a>(
                            <a href="leader_ban_registry.md#0x1_leader_ban_registry_Banned">Banned</a> {
                                pool_address: validator_pool_address,
                                epoch: latest_view.epoch,
                                round: latest_view.round,
                                consecutive_bans: bans.consecutive_bans
                            }
                        );
                    }
                } <b>else</b> {
                    <b>let</b> ban_registry_len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&ban_registry.bans);
                    <b>if</b> (<a href="leader_ban_registry.md#0x1_leader_ban_registry_can_be_banned">can_be_banned</a>(ban_registry_len)) {
                        <b>let</b> ban_with_address = <a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> {
                            active: <a href="leader_ban_registry.md#0x1_leader_ban_registry_ActiveBan">ActiveBan</a> {
                                epoch_earned: latest_view.epoch,
                                round_earned: latest_view.round,
                                rounds_served_in_previous_epochs: 0,
                                on_probation: <b>false</b>
                            },
                            consecutive_bans: 0,
                            pool_address: validator_pool_address
                        };
                        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> ban_registry.bans, ban_with_address);

                        <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_module_event_enabled">features::module_event_enabled</a>()) {
                            <a href="event.md#0x1_event_emit">event::emit</a>(
                                <a href="leader_ban_registry.md#0x1_leader_ban_registry_Banned">Banned</a> {
                                    pool_address: ban_with_address.pool_address,
                                    epoch: ban_with_address.active.epoch_earned,
                                    round: ban_with_address.active.round_earned,
                                    consecutive_bans: ban_with_address.consecutive_bans
                                }
                            );
                        }
                    }
                };
            };
        }
    );
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_reinstate_expired_bans"></a>

## Function `reinstate_expired_bans`

Handles ban and probation expiry:
- When probation expires: removes from registry, emits Reinstated
- When ban expires and probation_duration > 0: transitions to probation, emits ReinstatedWithProbation
- When ban expires and probation_duration == 0: removes from registry, emits Reinstated


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_reinstate_expired_bans">reinstate_expired_bans</a>(latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">leader_ban_registry::LatestView</a>, ban_registry: &<b>mut</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">leader_ban_registry::BanRegistry</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_reinstate_expired_bans">reinstate_expired_bans</a>(
    latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>, ban_registry: &<b>mut</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>
) {
    <b>let</b> probation_duration = <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_probation_duration">get_probation_duration</a>();

    // First pass: remove validators whose probation <b>has</b> expired.
    // Done before ban-<b>to</b>-probation transitions <b>to</b> avoid iterating just-transitioned validators.
    // Always runs (even when probation_duration == 0) <b>to</b> clean up validators that were already
    // on probation before a config change set probation_duration <b>to</b> 0.
    <b>let</b> pool_addresses_for_full_reinstatement = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>();
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_ref">vector::for_each_ref</a>(
        &ban_registry.bans,
        |v| {
            <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
            <b>if</b> (v.active.on_probation
                && <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_probation_duration">remaining_probation_duration</a>(v, latest_view, probation_duration)
                    == 0) {
                <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(
                    &<b>mut</b> pool_addresses_for_full_reinstatement, v.pool_address
                );
            }
        }
    );

    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_ref">vector::for_each_ref</a>(
        &pool_addresses_for_full_reinstatement,
        |p| {
            <b>let</b> (found, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_find">vector::find</a>(
                &ban_registry.bans,
                |v| {
                    <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
                    &v.pool_address == p
                }
            );
            <b>if</b> (found) {
                <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_swap_remove">vector::swap_remove</a>(&<b>mut</b> ban_registry.bans, index);

                <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_module_event_enabled">features::module_event_enabled</a>()) {
                    <a href="event.md#0x1_event_emit">event::emit</a>(
                        <a href="leader_ban_registry.md#0x1_leader_ban_registry_Reinstated">Reinstated</a> {
                            epoch: latest_view.epoch,
                            round: latest_view.round,
                            pool_address: *p
                        }
                    )
                }
            }
        }
    );

    // Second pass: handle expired bans
    <b>let</b> pool_addresses_with_expired_bans = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>();
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_ref">vector::for_each_ref</a>(
        &ban_registry.bans,
        |v| {
            <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
            <b>if</b> (!v.active.on_probation
                && <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_ban_duration">remaining_ban_duration</a>(v, latest_view) == 0) {
                <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(
                    &<b>mut</b> pool_addresses_with_expired_bans, v.pool_address
                );
            }
        }
    );

    <b>if</b> (probation_duration &gt; 0) {
        // Transition expired bans <b>to</b> probation
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_ref">vector::for_each_ref</a>(
            &pool_addresses_with_expired_bans,
            |p| {
                <b>let</b> (found, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_find">vector::find</a>(
                    &ban_registry.bans,
                    |v| {
                        <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
                        &v.pool_address == p
                    }
                );
                <b>if</b> (found) {
                    <b>let</b> ban = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow_mut">vector::borrow_mut</a>(&<b>mut</b> ban_registry.bans, index);
                    ban.active.on_probation = <b>true</b>;
                    // Reset active fields so probation duration is calculated from this point
                    ban.active.epoch_earned = latest_view.epoch;
                    ban.active.round_earned = latest_view.round;
                    ban.active.rounds_served_in_previous_epochs = 0;

                    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_module_event_enabled">features::module_event_enabled</a>()) {
                        <a href="event.md#0x1_event_emit">event::emit</a>(
                            <a href="leader_ban_registry.md#0x1_leader_ban_registry_ReinstatedWithProbation">ReinstatedWithProbation</a> {
                                epoch: latest_view.epoch,
                                round: latest_view.round,
                                pool_address: *p
                            }
                        )
                    }
                }
            }
        );
    } <b>else</b> {
        // No probation period - directly remove validators whose ban expired
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_ref">vector::for_each_ref</a>(
            &pool_addresses_with_expired_bans,
            |p| {
                <b>let</b> (found, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_find">vector::find</a>(
                    &ban_registry.bans,
                    |v| {
                        <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
                        &v.pool_address == p
                    }
                );
                <b>if</b> (found) {
                    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_swap_remove">vector::swap_remove</a>(&<b>mut</b> ban_registry.bans, index);

                    <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_module_event_enabled">features::module_event_enabled</a>()) {
                        <a href="event.md#0x1_event_emit">event::emit</a>(
                            <a href="leader_ban_registry.md#0x1_leader_ban_registry_Reinstated">Reinstated</a> {
                                epoch: latest_view.epoch,
                                round: latest_view.round,
                                pool_address: *p
                            }
                        )
                    }
                }
            }
        );
    };
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_on_new_epoch"></a>

## Function `on_new_epoch`

Increments the total number of consensus rounds served by each banned validator and removes
registry entries for validators that have left the validator set.

The number of rounds in each epoch may vary due to network asynchrony, so we must record the
number of rounds served in previous epochs to be able to ensure that a banned validator serves its
full ban period when its ban span multiple epochs.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_on_new_epoch">on_new_epoch</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_on_new_epoch">on_new_epoch</a>() <b>acquires</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>, <a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a> {
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework)) { <b>return</b> };
    <b>if</b> (!<b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework)) { <b>return</b> };
    <b>let</b> latest_view = <b>borrow_global</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>&gt;(@supra_framework);
    <b>let</b> ban_registry = <b>borrow_global_mut</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework);

    // The pool addresses of the validators for the new epoch.
    <b>let</b> new_committee_pool_addresses = <a href="stake.md#0x1_stake_get_committee_pool_addresses">stake::get_committee_pool_addresses</a>();
    // The pool addresses of the validators that have left the committee.
    <b>let</b> retired_validators = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_empty">vector::empty</a>();
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_mut">vector::for_each_mut</a>(
        &<b>mut</b> ban_registry.bans,
        |v| {
            <b>let</b> v: &<b>mut</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
            <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_contains">vector::contains</a>(&new_committee_pool_addresses, &v.pool_address)) {
                <b>if</b> (latest_view.epoch &gt; v.active.epoch_earned) {
                    v.active.rounds_served_in_previous_epochs =
                        v.active.rounds_served_in_previous_epochs
                            + latest_view.round;
                } <b>else</b> <b>if</b> (latest_view.epoch == v.active.epoch_earned
                    && latest_view.round &gt; v.active.round_earned) {
                    v.active.rounds_served_in_previous_epochs =
                        latest_view.round - v.active.round_earned;
                };
                // <b>else</b>: The ban hasn't started yet.
            } <b>else</b> {
                <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_push_back">vector::push_back</a>(&<b>mut</b> retired_validators, v.pool_address)
            }
        }
    );

    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_for_each_ref">vector::for_each_ref</a>(
        &retired_validators,
        |p| {
            <b>let</b> (is_banned, index) = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_find">vector::find</a>(
                &ban_registry.bans,
                |v| {
                    <b>let</b> v: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a> = v;
                    &v.pool_address == p
                }
            );
            <b>if</b> (is_banned) {
                <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_swap_remove">vector::swap_remove</a>(&<b>mut</b> ban_registry.bans, index);

                <b>if</b> (<a href="../../aptos-stdlib/../move-stdlib/doc/features.md#0x1_features_module_event_enabled">features::module_event_enabled</a>()) {
                    <a href="event.md#0x1_event_emit">event::emit</a>(
                        <a href="leader_ban_registry.md#0x1_leader_ban_registry_Reinstated">Reinstated</a> {
                            pool_address: *p,
                            epoch: latest_view.epoch,
                            round: latest_view.round
                        }
                    );
                }
            }
        }
    );
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_remaining_ban_duration"></a>

## Function `remaining_ban_duration`

Calculate the number of rounds remaining in a given ban (not including probation).


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_ban_duration">remaining_ban_duration</a>(ban: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">leader_ban_registry::ValidatorBans</a>, latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">leader_ban_registry::LatestView</a>): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_ban_duration">remaining_ban_duration</a>(
    ban: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a>, latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>
): u64 {
    <b>let</b> initial_ban_duration = <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_initial_ban_duration">get_initial_ban_duration</a>();
    <b>let</b> max_ban_duration = <a href="leader_ban_registry.md#0x1_leader_ban_registry_get_max_ban_duration">get_max_ban_duration</a>();
    <b>let</b> duration = initial_ban_duration * pow(2, (ban.consecutive_bans <b>as</b> u64));
    <b>let</b> duration = <b>min</b>(duration, max_ban_duration);
    <b>let</b> rounds_served =
        <b>if</b> (latest_view.epoch &gt; ban.active.epoch_earned) {
            ban.active.rounds_served_in_previous_epochs + latest_view.round
        } <b>else</b> <b>if</b> (latest_view.epoch == ban.active.epoch_earned
            && latest_view.round &gt; ban.active.round_earned) {
            latest_view.round - ban.active.round_earned
        } <b>else</b> {
            // The ban hasn't started yet.
            0
        };
    <b>if</b> (duration &gt; rounds_served) {
        duration - rounds_served
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_remaining_probation_duration"></a>

## Function `remaining_probation_duration`

Calculate the number of rounds remaining in probation.
Probation duration is constant and does not scale with consecutive bans.


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_probation_duration">remaining_probation_duration</a>(ban: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">leader_ban_registry::ValidatorBans</a>, latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">leader_ban_registry::LatestView</a>, probation_duration: u64): u64
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_remaining_probation_duration">remaining_probation_duration</a>(
    ban: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_ValidatorBans">ValidatorBans</a>, latest_view: &<a href="leader_ban_registry.md#0x1_leader_ban_registry_LatestView">LatestView</a>, probation_duration: u64
): u64 {
    <b>let</b> rounds_served =
        <b>if</b> (latest_view.epoch &gt; ban.active.epoch_earned) {
            ban.active.rounds_served_in_previous_epochs + latest_view.round
        } <b>else</b> <b>if</b> (latest_view.epoch == ban.active.epoch_earned
            && latest_view.round &gt; ban.active.round_earned) {
            latest_view.round - ban.active.round_earned
        } <b>else</b> {
            // The ban hasn't started yet.
            0
        };
    <b>if</b> (probation_duration &gt; rounds_served) {
        probation_duration - rounds_served
    } <b>else</b> { 0 }
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_can_be_banned"></a>

## Function `can_be_banned`

Returns true until ban registry size + minimum proposers required count less than committee size


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_can_be_banned">can_be_banned</a>(ban_registry_len: u64): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_can_be_banned">can_be_banned</a>(ban_registry_len: u64): bool {
    <b>let</b> minimum_unbanned_proposers =
        <a href="leader_ban_registry_config.md#0x1_leader_ban_registry_config_get_minimum_unbanned_proposers">leader_ban_registry_config::get_minimum_unbanned_proposers</a>();
    <b>let</b> committee_size = <a href="stake.md#0x1_stake_get_committee_size">stake::get_committee_size</a>();
    committee_size &gt; ban_registry_len + (minimum_unbanned_proposers <b>as</b> u64)
}
</code></pre>



</details>

<a id="0x1_leader_ban_registry_assert_registry_initialized"></a>

## Function `assert_registry_initialized`

Validates registry initialised if not aborted with <code><a href="leader_ban_registry.md#0x1_leader_ban_registry_EBAN_REGISTRY_NOT_INITIALIZED">EBAN_REGISTRY_NOT_INITIALIZED</a></code>


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_assert_registry_initialized">assert_registry_initialized</a>()
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="leader_ban_registry.md#0x1_leader_ban_registry_assert_registry_initialized">assert_registry_initialized</a>() {
    <b>assert</b>!(
        <b>exists</b>&lt;<a href="leader_ban_registry.md#0x1_leader_ban_registry_BanRegistry">BanRegistry</a>&gt;(@supra_framework),
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_state">error::invalid_state</a>(<a href="leader_ban_registry.md#0x1_leader_ban_registry_EBAN_REGISTRY_NOT_INITIALIZED">EBAN_REGISTRY_NOT_INITIALIZED</a>)
    );
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
