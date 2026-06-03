
<a id="0x1_dkg_config"></a>

# Module `0x1::dkg_config`

DKG configuration module for configurable DKG parameters.
This config can be updated via governance and takes effect at the next epoch.


-  [Struct `ReceiverCommitteeConfig`](#0x1_dkg_config_ReceiverCommitteeConfig)
-  [Resource `DkgConfig`](#0x1_dkg_config_DkgConfig)
-  [Constants](#@Constants_0)
-  [Function `initialize`](#0x1_dkg_config_initialize)
-  [Function `set_for_next_epoch`](#0x1_dkg_config_set_for_next_epoch)
-  [Function `has_key_threshold_type`](#0x1_dkg_config_has_key_threshold_type)
-  [Function `on_new_epoch`](#0x1_dkg_config_on_new_epoch)
-  [Function `new`](#0x1_dkg_config_new)
-  [Function `new_receiver_committee_config`](#0x1_dkg_config_new_receiver_committee_config)
-  [Function `default`](#0x1_dkg_config_default)
-  [Function `current`](#0x1_dkg_config_current)
-  [Function `get_dealer_committee_threshold_type`](#0x1_dkg_config_get_dealer_committee_threshold_type)
-  [Function `get_receiver_committee_configs`](#0x1_dkg_config_get_receiver_committee_configs)
-  [Function `get_is_resharing`](#0x1_dkg_config_get_is_resharing)
-  [Function `get_committee_threshold_type`](#0x1_dkg_config_get_committee_threshold_type)
-  [Function `get_dkg_threshold_type`](#0x1_dkg_config_get_dkg_threshold_type)


<pre><code><b>use</b> <a href="config_buffer.md#0x1_config_buffer">0x1::config_buffer</a>;
<b>use</b> <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error">0x1::error</a>;
<b>use</b> <a href="system_addresses.md#0x1_system_addresses">0x1::system_addresses</a>;
<b>use</b> <a href="validator_public_keys.md#0x1_validator_public_keys">0x1::validator_public_keys</a>;
</code></pre>



<a id="0x1_dkg_config_ReceiverCommitteeConfig"></a>

## Struct `ReceiverCommitteeConfig`

Configuration for a single receiver committee in DKG.


<pre><code><b>struct</b> <a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a> <b>has</b> <b>copy</b>, drop, store
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>is_resharing: bool</code>
</dt>
<dd>
 Whether this committee uses resharing from the previous epoch's public key.
</dd>
<dt>
<code>committee_threshold_type: <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a></code>
</dt>
<dd>
 The threshold type for this committee (e.g., quorum, clan_majority).
</dd>
<dt>
<code>dkg_threshold_type: <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a></code>
</dt>
<dd>
 The threshold type for output keys in DKG for this committee (e.g., validity, quorum).
</dd>
</dl>


</details>

<a id="0x1_dkg_config_DkgConfig"></a>

## Resource `DkgConfig`

Main DKG configuration stored at @supra_framework.
Controls DKG parameters that can be updated via governance.


<pre><code><b>struct</b> <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> <b>has</b> <b>copy</b>, drop, store, key
</code></pre>



<details>
<summary>Fields</summary>


<dl>
<dt>
<code>dealer_committee_threshold_type: <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a></code>
</dt>
<dd>
 Threshold type for the dealer committee. (e.g., quorum, clan_majority).
</dd>
<dt>
<code>receiver_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">dkg_config::ReceiverCommitteeConfig</a>&gt;</code>
</dt>
<dd>
 Configuration for each receiver committee.
 Default: [(false, validity), (false, quorum)]
</dd>
</dl>


</details>

<a id="@Constants_0"></a>

## Constants


<a id="0x1_dkg_config_EEMPTY_RECEIVER_COMMITTEES"></a>

Error: Receiver committees vector cannot be empty.


<pre><code><b>const</b> <a href="dkg_config.md#0x1_dkg_config_EEMPTY_RECEIVER_COMMITTEES">EEMPTY_RECEIVER_COMMITTEES</a>: u64 = 1;
</code></pre>



<a id="0x1_dkg_config_ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE"></a>

Error: Cannot enable resharing for a threshold type that doesn't exist in current config.


<pre><code><b>const</b> <a href="dkg_config.md#0x1_dkg_config_ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE">ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE</a>: u64 = 2;
</code></pre>



<a id="0x1_dkg_config_initialize"></a>

## Function `initialize`

Initialize DKG config during genesis.


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_initialize">initialize</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_initialize">initialize</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(framework);
    <b>if</b> (!<b>exists</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>&gt;(@supra_framework)) {
        <b>move_to</b>(framework, <a href="dkg_config.md#0x1_dkg_config_default">default</a>());
    }
}
</code></pre>



</details>

<a id="0x1_dkg_config_set_for_next_epoch"></a>

## Function `set_for_next_epoch`

Set a new DKG config for the next epoch.
This can only be called by on-chain governance.
Example usage:
```
let new_config = dkg_config::new(
quorum_certificate_type(),
vector[
dkg_config::new_receiver_committee_config(true, validity_certificate_type()),
dkg_config::new_receiver_committee_config(true, quorum_certificate_type()),
]
);
dkg_config::set_for_next_epoch(&framework_signer, new_config);
supra_governance::reconfigure(&framework_signer);
```


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_set_for_next_epoch">set_for_next_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_config: <a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_set_for_next_epoch">set_for_next_epoch</a>(
    framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>, new_config: <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>
) <b>acquires</b> <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(framework);

    // Validate: receiver_committees cannot be empty
    <b>assert</b>!(
        <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&new_config.receiver_committees) &gt; 0,
        <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg_config.md#0x1_dkg_config_EEMPTY_RECEIVER_COMMITTEES">EEMPTY_RECEIVER_COMMITTEES</a>)
    );

    // Validate: <b>if</b> resharing is enabled for a <a href="dkg.md#0x1_dkg">dkg</a> threshold type, it must exist in current config
    <b>let</b> current_config = <a href="dkg_config.md#0x1_dkg_config_current">current</a>();
    <b>let</b> i = 0;
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&new_config.receiver_committees);
    <b>while</b> (i &lt; len) {
        <b>let</b> new_rc = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&new_config.receiver_committees, i);
        <b>if</b> (new_rc.is_resharing) {
            // Check <b>if</b> this threshold type <b>exists</b> in current config
            <b>assert</b>!(
                <a href="dkg_config.md#0x1_dkg_config_has_key_threshold_type">has_key_threshold_type</a>(&current_config, new_rc.dkg_threshold_type),
                <a href="../../aptos-stdlib/../move-stdlib/doc/error.md#0x1_error_invalid_argument">error::invalid_argument</a>(<a href="dkg_config.md#0x1_dkg_config_ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE">ERESHARING_FOR_NONEXISTENT_THRESHOLD_TYPE</a>)
            );
        };
        i = i + 1;
    };

    <a href="config_buffer.md#0x1_config_buffer_upsert">config_buffer::upsert</a>(new_config);
}
</code></pre>



</details>

<a id="0x1_dkg_config_has_key_threshold_type"></a>

## Function `has_key_threshold_type`

Check if a threshold type exists in the config's receiver committees.


<pre><code><b>fun</b> <a href="dkg_config.md#0x1_dkg_config_has_key_threshold_type">has_key_threshold_type</a>(config: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>, threshold_type: <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>fun</b> <a href="dkg_config.md#0x1_dkg_config_has_key_threshold_type">has_key_threshold_type</a>(
    config: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>, threshold_type: CertificateThresholdType
): bool {
    <b>let</b> i = 0;
    <b>let</b> len = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_length">vector::length</a>(&config.receiver_committees);
    <b>while</b> (i &lt; len) {
        <b>let</b> rc = <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector_borrow">vector::borrow</a>(&config.receiver_committees, i);
        <b>if</b> (rc.dkg_threshold_type == threshold_type) {
            <b>return</b> <b>true</b>
        };
        i = i + 1;
    };
    <b>false</b>
}
</code></pre>



</details>

<a id="0x1_dkg_config_on_new_epoch"></a>

## Function `on_new_epoch`

Apply any pending DKG config at epoch boundary.
Called from reconfiguration_with_dkg::finish().


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>)
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b>(<b>friend</b>) <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_on_new_epoch">on_new_epoch</a>(framework: &<a href="../../aptos-stdlib/../move-stdlib/doc/signer.md#0x1_signer">signer</a>) <b>acquires</b> <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {
    <a href="system_addresses.md#0x1_system_addresses_assert_supra_framework">system_addresses::assert_supra_framework</a>(framework);
    <b>if</b> (<a href="config_buffer.md#0x1_config_buffer_does_exist">config_buffer::does_exist</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>&gt;()) {
        <b>let</b> new_config = <a href="config_buffer.md#0x1_config_buffer_extract">config_buffer::extract</a>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>&gt;();
        <b>if</b> (<b>exists</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>&gt;(@supra_framework)) {
            *<b>borrow_global_mut</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>&gt;(@supra_framework) = new_config;
        } <b>else</b> {
            <b>move_to</b>(framework, new_config);
        }
    }
}
</code></pre>



</details>

<a id="0x1_dkg_config_new"></a>

## Function `new`

Create a new DkgConfig.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_new">new</a>(dealer_committee_threshold_type: <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>, receiver_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">dkg_config::ReceiverCommitteeConfig</a>&gt;): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_new">new</a>(
    dealer_committee_threshold_type: CertificateThresholdType,
    receiver_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a>&gt;
): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {
    <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> { dealer_committee_threshold_type, receiver_committees }
}
</code></pre>



</details>

<a id="0x1_dkg_config_new_receiver_committee_config"></a>

## Function `new_receiver_committee_config`

Create a new ReceiverCommitteeConfig.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_new_receiver_committee_config">new_receiver_committee_config</a>(is_resharing: bool, committee_threshold_type: <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>, dkg_threshold_type: <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>): <a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">dkg_config::ReceiverCommitteeConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_new_receiver_committee_config">new_receiver_committee_config</a>(
    is_resharing: bool,
    committee_threshold_type: CertificateThresholdType,
    dkg_threshold_type: CertificateThresholdType
): <a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a> {
    <a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a> {
        is_resharing,
        committee_threshold_type,
        dkg_threshold_type
    }
}
</code></pre>



</details>

<a id="0x1_dkg_config_default"></a>

## Function `default`

Returns the default DKG configuration.

Assumes that the <code>SUPRA_BCFT_CERTIFICATES</code> feature flag is enabled.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_default">default</a>(): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_default">default</a>(): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {
    <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {
        dealer_committee_threshold_type: quorum_certificate_type(),
        receiver_committees: <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>[
            <a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a> {
                is_resharing: <b>false</b>,
                committee_threshold_type: quorum_certificate_type(),
                dkg_threshold_type: bcft_quorum_certificate_type()
            },
            <a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a> {
                is_resharing: <b>false</b>,
                committee_threshold_type: quorum_certificate_type(),
                dkg_threshold_type: bcft_validity_certificate_type()
            },
            <a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a> {
                is_resharing: <b>false</b>,
                committee_threshold_type: quorum_certificate_type(),
                dkg_threshold_type: clan_majority_certificate_type()
            }
        ]
    }
}
</code></pre>



</details>

<a id="0x1_dkg_config_current"></a>

## Function `current`

Get the current DKG config.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_current">current</a>(): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_current">current</a>(): <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> <b>acquires</b> <a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a> {
    <b>if</b> (<b>exists</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>&gt;(@supra_framework)) {
        *<b>borrow_global</b>&lt;<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>&gt;(@supra_framework)
    } <b>else</b> {
        // This branch should not be executed:
        //     1. If the network is started from <a href="genesis.md#0x1_genesis">genesis</a> then the default config should be
        //        applied during <a href="genesis.md#0x1_genesis">genesis</a>.
        //     2. If the DKG feature flag is enabled in an existing network, then governance
        //        should set a config before enabling the feature flag.
        //
        // This branch <b>exists</b> <b>as</b> a fallback that <b>ensures</b> that the `BlockMetadata` transaction
        // does not fail in case of misconfiguration.
        <a href="dkg_config.md#0x1_dkg_config_default">default</a>()
    }
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_dealer_committee_threshold_type"></a>

## Function `get_dealer_committee_threshold_type`

Get the dealer threshold type from the config.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dealer_committee_threshold_type">get_dealer_committee_threshold_type</a>(config: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dealer_committee_threshold_type">get_dealer_committee_threshold_type</a>(config: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>):
    CertificateThresholdType {
    config.dealer_committee_threshold_type
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_receiver_committee_configs"></a>

## Function `get_receiver_committee_configs`

Get the receiver committee configs from the DkgConfig.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_receiver_committee_configs">get_receiver_committee_configs</a>(config: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">dkg_config::DkgConfig</a>): <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">dkg_config::ReceiverCommitteeConfig</a>&gt;
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_receiver_committee_configs">get_receiver_committee_configs</a>(config: &<a href="dkg_config.md#0x1_dkg_config_DkgConfig">DkgConfig</a>):
    <a href="../../aptos-stdlib/../move-stdlib/doc/vector.md#0x1_vector">vector</a>&lt;<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a>&gt; {
    config.receiver_committees
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_is_resharing"></a>

## Function `get_is_resharing`

Get is_resharing from a ReceiverCommitteeConfig.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_is_resharing">get_is_resharing</a>(config: &<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">dkg_config::ReceiverCommitteeConfig</a>): bool
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_is_resharing">get_is_resharing</a>(config: &<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a>): bool {
    config.is_resharing
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_committee_threshold_type"></a>

## Function `get_committee_threshold_type`

Get committee_threshold_type from a ReceiverCommitteeConfig.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_committee_threshold_type">get_committee_threshold_type</a>(config: &<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">dkg_config::ReceiverCommitteeConfig</a>): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_committee_threshold_type">get_committee_threshold_type</a>(
    config: &<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a>
): CertificateThresholdType {
    config.committee_threshold_type
}
</code></pre>



</details>

<a id="0x1_dkg_config_get_dkg_threshold_type"></a>

## Function `get_dkg_threshold_type`

Get dkg_threshold_type from a ReceiverCommitteeConfig.


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_threshold_type">get_dkg_threshold_type</a>(config: &<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">dkg_config::ReceiverCommitteeConfig</a>): <a href="validator_public_keys.md#0x1_validator_public_keys_CertificateThresholdType">validator_public_keys::CertificateThresholdType</a>
</code></pre>



<details>
<summary>Implementation</summary>


<pre><code><b>public</b> <b>fun</b> <a href="dkg_config.md#0x1_dkg_config_get_dkg_threshold_type">get_dkg_threshold_type</a>(config: &<a href="dkg_config.md#0x1_dkg_config_ReceiverCommitteeConfig">ReceiverCommitteeConfig</a>):
    CertificateThresholdType {
    config.dkg_threshold_type
}
</code></pre>



</details>


[move-book]: https://aptos.dev/move/book/SUMMARY
