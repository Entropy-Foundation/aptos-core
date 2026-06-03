// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

#![forbid(unsafe_code)]

mod genesis_context;

use crate::genesis_context::GenesisStateView;
use aptos_crypto::{
    bls12381,
    ed25519,
    ed25519::{Ed25519PrivateKey, Ed25519PublicKey},
    HashValue, PrivateKey, Uniform,
};
use aptos_framework::{ReleaseBundle, ReleasePackage};
use aptos_gas_schedule::{
    AptosGasParameters, InitialGasSchedule, ToOnChainGasSchedule, LATEST_GAS_FEATURE_VERSION,
};
use aptos_types::{
    account_address::{create_resource_address, create_seed_for_pbo_module},
    account_config::{
        self, CORE_CODE_ADDRESS, aptos_test_root_address, events::NewEpochEvent,
        EXPERIMENTAL_CODE_ADDRESS,
    },
    chain_id::ChainId,
    contract_event::{ContractEvent, ContractEventV1},
    executable::ModulePath,
    jwks::{
        jwk::{JWKMoveStruct, JWK},
        patch::{IssuerJWK, PatchJWKMoveStruct, PatchUpsertJWK},
        secure_test_rsa_jwk,
    },
    keyless::{
        self, test_utils::get_sample_iss, Groth16VerificationKey, KEYLESS_ACCOUNT_MODULE_NAME,
    },
    move_utils::as_move_value::AsMoveValue,
    on_chain_config::{
        APTOS_MAX_KNOWN_VERSION, AutomationRegistryConfig, BanRegistryParameters, BanRegistryParametersV0, FeatureFlag, Features, GasScheduleV2, OnChainConsensusConfig, OnChainEvmGenesisConfig, OnChainExecutionConfig, OnChainJWKConsensusConfig, OnChainRandomnessConfig, RandomnessConfigMoveStruct, randomness_api_v0_config::{AllowCustomMaxGasFlag, RequiredGasDeposit}
    },
    state_store::state_key::StateKey,
    transaction::{authenticator::AuthenticationKey, ChangeSet, Transaction, WriteSetPayload},
    validator_public_keys::ValidatorPublicKeys,
    write_set::{TransactionWrite, WriteOp, WriteSet},
};
use aptos_vm::{
    data_cache::AsMoveResolver,
    move_vm_ext::{
        convert_modules_into_write_ops, AptosMoveResolver, GenesisMoveVm, GenesisRuntimeBuilder,
        SessionExt,
    },
};
use aptos_vm_types::{
    change_set::VMChangeSet,
    module_and_script_storage::{module_storage::AptosModuleStorage, AsAptosCodeStorage},
    module_write_set::{ModuleWrite, ModuleWriteSet},
};
use bytes::Bytes;
use claims::assert_ok;
use move_binary_format::errors::{Location, VMResult};
use move_core_types::{
    account_address::AccountAddress,
    identifier::Identifier,
    language_storage::{ModuleId, TypeTag},
    value::{serialize_values, MoveValue},
};
use move_vm_runtime::{
    module_traversal::{TraversalContext, TraversalStorage},
    ModuleStorage, RuntimeEnvironment, StagingModuleStorage,
};
use move_vm_types::gas::UnmeteredGasMeter;
use once_cell::sync::Lazy;
use rand::prelude::*;
use serde::{Deserialize, Serialize};
use std::{
    collections::BTreeSet,
    hash::{Hash, Hasher},
};
use std::collections::BTreeMap;

// The seed is arbitrarily picked to produce a consistent key. XXX make this more formal?
const GENESIS_SEED: [u8; 32] = [42; 32];

const GENESIS_MODULE_NAME: &str = "genesis";
const PBO_DELEGATION_POOL_MODULE_NAME: &str = "pbo_delegation_pool";
const GOVERNANCE_MODULE_NAME: &str = "supra_governance";
const CODE_MODULE_NAME: &str = "code";
const VERSION_MODULE_NAME: &str = "version";
const JWK_CONSENSUS_CONFIG_MODULE_NAME: &str = "jwk_consensus_config";
const JWKS_MODULE_NAME: &str = "jwks";
const CONFIG_BUFFER_MODULE_NAME: &str = "config_buffer";
const DKG_MODULE_NAME: &str = "supra_dkg";
const RANDOMNESS_API_V0_CONFIG_MODULE_NAME: &str = "randomness_api_v0_config";
const RANDOMNESS_CONFIG_SEQNUM_MODULE_NAME: &str = "randomness_config_seqnum";
const RANDOMNESS_CONFIG_MODULE_NAME: &str = "randomness_config";
const RANDOMNESS_MODULE_NAME: &str = "randomness";
const ACCOUNT_ABSTRACTION_MODULE_NAME: &str = "account_abstraction";
const RECONFIGURATION_STATE_MODULE_NAME: &str = "reconfiguration_state";

// Allows an APY with 2 decimals of precision to be specified as a u64.
const APY_PRECISION: u64 = 10_000;
const NUM_SECONDS_PER_YEAR: u64 = 365 * 24 * 60 * 60;
const MICRO_SECONDS_PER_SECOND: u64 = 1_000_000;
const APTOS_COINS_BASE_WITH_DECIMALS: u64 = u64::pow(10, 8);

pub const PBO_DELEGATION_POOL_LOCKUP_PERCENTAGE: u64 = 90;

pub struct GenesisConfiguration {
    pub allow_new_validators: bool,
    pub epoch_duration_secs: u64,
    // If true, genesis will create a special core resources account that can mint coins.
    pub is_test: bool,
    pub max_stake: u64,
    pub min_stake: u64,
    pub min_voting_threshold: u64,
    pub recurring_lockup_duration_secs: u64,
    pub required_proposer_stake: u64,
    // The APY rewards rate specified as a percentage plus 3 decimals of precision.
    // That is, 10% should be written as 10_000.
    pub rewards_apy_percentage: u64,
    pub voting_duration_secs: u64,
    pub voters: Vec<AccountAddress>,
    pub voting_power_increase_limit: u64,
    pub genesis_timestamp_in_microseconds: u64,
    pub employee_vesting_start: u64,
    pub employee_vesting_period_duration: u64,
    pub initial_features_override: Option<Features>,
    pub randomness_config_override: Option<OnChainRandomnessConfig>,
    pub jwk_consensus_config_override: Option<OnChainJWKConsensusConfig>,
    pub automation_registry_config: Option<AutomationRegistryConfig>,
    pub leader_ban_registry_config: Option<BanRegistryParameters>,
    pub initial_jwks: Vec<IssuerJWK>,
    pub keyless_groth16_vk: Option<Groth16VerificationKey>,
}

pub static GENESIS_KEYPAIR: Lazy<(Ed25519PrivateKey, Ed25519PublicKey)> = Lazy::new(|| {
    let mut rng = StdRng::from_seed(GENESIS_SEED);
    let private_key = Ed25519PrivateKey::generate(&mut rng);
    let public_key = private_key.public_key();
    (private_key, public_key)
});

// Cannot be impl Default in GasScheduleV2, due to circular dependencies.
pub fn default_gas_schedule() -> GasScheduleV2 {
    GasScheduleV2 {
        feature_version: LATEST_GAS_FEATURE_VERSION,
        entries: AptosGasParameters::initial().to_on_chain_gas_schedule(LATEST_GAS_FEATURE_VERSION),
    }
}

pub fn encode_supra_mainnet_genesis_transaction(
    accounts: &BTreeSet<AccountBalance>,
    multisig_accounts: &[MultiSigAccountWithBalance],
    owner_group: Option<MultiSigAccountSchema>,
    delegation_pools: &[PboDelegatorConfiguration],
    owner_stake_for_pbo_pool: u64,
    vesting_pools: &[VestingPoolsMap],
    initial_unlock_vesting_pools: &[VestingPoolsMap],
    framework: &ReleaseBundle,
    chain_id: ChainId,
    genesis_config: &GenesisConfiguration,
    supra_config_bytes: Vec<u8>,
) -> Transaction {
    assert!(!genesis_config.is_test, "This is mainnet!");
    validate_genesis_config(genesis_config);

    let mut state_view = GenesisStateView::new();
    for (module_bytes, module) in framework.code_and_compiled_modules() {
        state_view.add_module(&module.self_id(), module_bytes);
    }

    let genesis_runtime_builder = GenesisRuntimeBuilder::new(chain_id);
    let genesis_runtime_environment = genesis_runtime_builder.build_genesis_runtime_environment();

    let module_storage = state_view.as_aptos_code_storage(&genesis_runtime_environment);
    let resolver = state_view.as_move_resolver();

    let genesis_vm = genesis_runtime_builder.build_genesis_vm();
    let genesis_change_set_configs = genesis_vm.genesis_change_set_configs();
    let mut session = genesis_vm.new_genesis_session(&resolver, HashValue::zero());

    let traversal_storage = TraversalStorage::new();
    let mut traversal_context = TraversalContext::new(&traversal_storage);

    // On-chain genesis process.
    let consensus_config = OnChainConsensusConfig::default_for_genesis();
    let execution_config = OnChainExecutionConfig::default_for_genesis();
    let gas_schedule = default_gas_schedule();

    initialize(
        &mut session,
        &module_storage,
        &mut traversal_context,
        chain_id,
        genesis_config,
        &consensus_config,
        &execution_config,
        &gas_schedule,
        supra_config_bytes,
    );
    initialize_features(
        &mut session,
        &module_storage,
        &mut traversal_context,
        genesis_config
            .initial_features_override
            .clone()
            .map(Features::into_flag_vec),
    );
    initialize_supra_coin(&mut session, &module_storage, &mut traversal_context);
    initialize_supra_native_automation(&mut session, &module_storage, &mut traversal_context, genesis_config);
    initialize_on_chain_governance(&mut session, &module_storage, &mut traversal_context, genesis_config);
    create_accounts(&mut session, &module_storage, &mut traversal_context, accounts);

    if let Some(owner_group) = owner_group {
        create_multiple_multisig_accounts_with_schema(&mut session, &module_storage, &mut traversal_context, owner_group);
    }

    create_multisig_accounts_with_balance(&mut session, &module_storage, &mut traversal_context, multisig_accounts);

    // All PBO delegated validators are initialized here
    create_pbo_delegation_pools(&mut session, &module_storage, &mut traversal_context, delegation_pools);

    add_owner_stakes_for_delegation_pools(&mut session, &module_storage, &mut traversal_context, delegation_pools, owner_stake_for_pbo_pool);

    // PBO vesting accounts, employees, investors etc. are placed in their vesting pools
    create_vesting_without_staking_pools(&mut session, &module_storage, &mut traversal_context, vesting_pools);

    // Lock up the remaining available balances of the accounts for TGE
    create_vesting_without_staking_pools(&mut session, &module_storage, &mut traversal_context, initial_unlock_vesting_pools);

    set_genesis_end(&mut session, &module_storage, &mut traversal_context);

    // Reconfiguration should happen after all on-chain invocations.
    emit_new_block_and_epoch_event(&mut session, &module_storage, &mut traversal_context);

    // Create a change set with all initialized resources.
    let mut change_set = assert_ok!(session.finish(&genesis_change_set_configs, &module_storage,));

    // Publish the framework, using a different session id, in case both sessions create tables.
    let mut new_id = [0u8; 32];
    new_id[31] = 1;

    let (additional_change_set, module_write_set) = publish_framework(
        &genesis_vm,
        &genesis_runtime_environment,
        HashValue::new(new_id),
        framework,
    );
    assert_ok!(change_set.squash_additional_change_set(additional_change_set));

    let change_set = assert_ok!(change_set.try_combine_into_storage_change_set(module_write_set));
    verify_genesis_module_write_set(change_set.write_set());
    verify_genesis_events(change_set.events());

    Transaction::GenesisTransaction(WriteSetPayload::Direct(change_set))
}

pub fn encode_genesis_transaction_for_testnet(
    aptos_root_key: Ed25519PublicKey,
    validators: &[Validator],
    owner_group: Option<MultiSigAccountSchema>,
    owner_stake_for_pbo_pool: u64,
    delegation_pools: &[PboDelegatorConfiguration],
    vesting_pools: &[VestingPoolsMap],
    initial_unlock_vesting_pools: &[VestingPoolsMap],
    framework: &ReleaseBundle,
    chain_id: ChainId,
    genesis_config: &GenesisConfiguration,
    consensus_config: &OnChainConsensusConfig,
    execution_config: &OnChainExecutionConfig,
    gas_schedule: &GasScheduleV2,
    supra_config_bytes: Vec<u8>,
    evm_genesis_config: Option<OnChainEvmGenesisConfig>,
) -> Transaction {
    Transaction::GenesisTransaction(WriteSetPayload::Direct(
        encode_genesis_change_set_for_testnet(
            &aptos_root_key,
            &BTreeSet::new(),
            &[],
            owner_group,
            validators,
            delegation_pools,
            owner_stake_for_pbo_pool,
            vesting_pools,
            initial_unlock_vesting_pools,
            framework,
            chain_id,
            genesis_config,
            consensus_config,
            execution_config,
            gas_schedule,
            supra_config_bytes,
            evm_genesis_config,
        ),
    ))
}

pub fn encode_genesis_change_set_for_testnet(
    core_resources_key: &Ed25519PublicKey,
    accounts: &BTreeSet<AccountBalance>,
    multisig_account: &[MultiSigAccountWithBalance],
    owner_group: Option<MultiSigAccountSchema>,
    validators: &[Validator],
    delegation_pools: &[PboDelegatorConfiguration],
    owner_stake_for_pbo_pool: u64,
    vesting_pools: &[VestingPoolsMap],
    initial_unlock_vesting_pools: &[VestingPoolsMap],
    framework: &ReleaseBundle,
    chain_id: ChainId,
    genesis_config: &GenesisConfiguration,
    consensus_config: &OnChainConsensusConfig,
    execution_config: &OnChainExecutionConfig,
    gas_schedule: &GasScheduleV2,
    supra_config_bytes: Vec<u8>,
    evm_genesis_config: Option<OnChainEvmGenesisConfig>,
) -> ChangeSet {
    validate_genesis_config(genesis_config);
    // Create a Move VM session so we can invoke on-chain genesis initializations.
    let mut state_view = GenesisStateView::new();
    for (module_bytes, module) in framework.code_and_compiled_modules() {
        state_view.add_module(&module.self_id(), module_bytes);
    }

    let genesis_runtime_builder = GenesisRuntimeBuilder::new(chain_id);
    let genesis_runtime_environment = genesis_runtime_builder.build_genesis_runtime_environment();

    let module_storage = state_view.as_aptos_code_storage(&genesis_runtime_environment);
    let resolver = state_view.as_move_resolver();

    let genesis_vm = genesis_runtime_builder.build_genesis_vm();
    let genesis_change_set_configs = genesis_vm.genesis_change_set_configs();
    let mut session = genesis_vm.new_genesis_session(&resolver, HashValue::zero());

    let traversal_storage = TraversalStorage::new();
    let mut traversal_context = TraversalContext::new(&traversal_storage);

    // On-chain genesis process.
    initialize(
        &mut session,
        &module_storage,
        &mut traversal_context,
        chain_id,
        genesis_config,
        consensus_config,
        execution_config,
        gas_schedule,
        supra_config_bytes,
    );
    initialize_features(
        &mut session,
        &module_storage,
        &mut traversal_context,
        genesis_config
            .initial_features_override
            .clone()
            .map(Features::into_flag_vec),
    );
    if genesis_config.is_test {
        initialize_core_resources_and_supra_coin(
            &mut session,
            &module_storage,
            &mut traversal_context,
            core_resources_key,
        );
    } else {
        initialize_supra_coin(&mut session, &module_storage, &mut traversal_context);
    }
    initialize_supra_native_automation(&mut session, &module_storage, &mut traversal_context, genesis_config);
    initialize_config_buffer(&mut session, &module_storage, &mut traversal_context);
    initialize_dkg(&mut session, &module_storage, &mut traversal_context);
    initialize_reconfiguration_state(&mut session, &module_storage, &mut traversal_context);
    let randomness_config = genesis_config
        .randomness_config_override
        .clone()
        .unwrap_or_else(OnChainRandomnessConfig::default_for_genesis);
    initialize_randomness_api_v0_config(&mut session, &module_storage, &mut traversal_context);
    initialize_randomness_config_seqnum(&mut session, &module_storage, &mut traversal_context);
    initialize_randomness_config(
        &mut session,
        &module_storage,
        &mut traversal_context,
        randomness_config,
    );
    initialize_randomness_resources(&mut session, &module_storage, &mut traversal_context);
    initialize_on_chain_governance(
        &mut session,
        &module_storage,
        &mut traversal_context,
        genesis_config,
    );
    initialize_leader_ban_config(&mut session, &module_storage, &mut traversal_context, genesis_config);

    if let Some(evm_genesis_config) = evm_genesis_config {
        initialize_evm_genesis_config(&mut session, &module_storage, &mut traversal_context, &evm_genesis_config);
    }

    create_accounts(&mut session, &module_storage, &mut traversal_context, accounts);

    if let Some(owner_group) = owner_group {
        create_multiple_multisig_accounts_with_schema(&mut session, &module_storage, &mut traversal_context, owner_group);
    }

    create_multisig_accounts_with_balance(&mut session, &module_storage, &mut traversal_context, multisig_account);
    initialize_account_abstraction(&mut session, &module_storage, &mut traversal_context);

    if validators.len() > 0 {
        create_and_initialize_validators(
            &mut session,
            &module_storage,
            &mut traversal_context,
            validators,
        );
    } else {
        // All PBO delegated validators are initialized here
        create_pbo_delegation_pools(&mut session, &module_storage, &mut traversal_context, delegation_pools);

        add_owner_stakes_for_delegation_pools(
            &mut session,
            &module_storage,
            &mut traversal_context,
            delegation_pools,
            owner_stake_for_pbo_pool,
        );

        // PBO vesting accounts, employees, investors etc. are placed in their vesting pools
        create_vesting_without_staking_pools(&mut session, &module_storage, &mut traversal_context, vesting_pools);

        // Lock up the remaining available balances of the accounts for TGE
        create_vesting_without_staking_pools(&mut session, &module_storage, &mut traversal_context, initial_unlock_vesting_pools);
    }

    if genesis_config.is_test {
        allow_core_resources_to_set_version(&mut session, &module_storage, &mut traversal_context);
    }
    let jwk_consensus_config = genesis_config
        .jwk_consensus_config_override
        .clone()
        .unwrap_or_else(OnChainJWKConsensusConfig::default_for_genesis);
    initialize_jwk_consensus_config(
        &mut session,
        &module_storage,
        &mut traversal_context,
        &jwk_consensus_config,
    );
    initialize_jwks_resources(&mut session, &module_storage, &mut traversal_context);
    initialize_keyless_accounts(
        &mut session,
        &module_storage,
        &mut traversal_context,
        chain_id,
        genesis_config.initial_jwks.clone(),
        genesis_config.keyless_groth16_vk.clone(),
    );
    initialize_confidential_asset(
        &mut session,
        &module_storage,
        chain_id,
        &mut traversal_context,
    );
    set_genesis_end(&mut session, &module_storage, &mut traversal_context);

    // Reconfiguration should happen after all on-chain invocations.
    emit_new_block_and_epoch_event(&mut session, &module_storage, &mut traversal_context);

    let mut change_set = assert_ok!(session.finish(&genesis_change_set_configs, &module_storage,));

    // Publish the framework, using a different id, in case both sessions create tables.
    let mut new_id = [0u8; 32];
    new_id[31] = 1;

    let (additional_change_set, module_write_set) = publish_framework(
        &genesis_vm,
        &genesis_runtime_environment,
        HashValue::new(new_id),
        framework,
    );
    assert_ok!(change_set.squash_additional_change_set(additional_change_set));

    let change_set = assert_ok!(change_set.try_combine_into_storage_change_set(module_write_set));
    verify_genesis_module_write_set(change_set.write_set());
    verify_genesis_events(change_set.events());

    change_set
}

fn validate_genesis_config(genesis_config: &GenesisConfiguration) {
    assert!(
        genesis_config.min_stake <= genesis_config.max_stake,
        "Min stake must be smaller than or equal to max stake"
    );
    assert!(
        genesis_config.epoch_duration_secs > 0,
        "Epoch duration must be > 0"
    );
    assert!(
        genesis_config.recurring_lockup_duration_secs > 0,
        "Recurring lockup duration must be > 0"
    );
    assert!(
        genesis_config.recurring_lockup_duration_secs >= genesis_config.epoch_duration_secs,
        "Recurring lockup duration must be at least as long as epoch duration"
    );
    assert!(
        genesis_config.rewards_apy_percentage > 0
            && genesis_config.rewards_apy_percentage < APY_PRECISION,
        "Rewards APY must between >= 1 (i.e. 0.01%) and < 10,000 (i.e. 100%)"
    );
    assert!(
        genesis_config.voting_duration_secs > 0,
        "On-chain voting duration must be > 0"
    );
    assert!(
        genesis_config.voting_duration_secs < genesis_config.recurring_lockup_duration_secs,
        "Voting duration must be strictly smaller than recurring lockup"
    );
    assert!(
        genesis_config.voting_power_increase_limit > 0
            && genesis_config.voting_power_increase_limit <= 50,
        "voting_power_increase_limit must be > 0 and <= 50"
    );
}

fn exec_function_internal(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl ModuleStorage,
    traversal_context: &mut TraversalContext,
    module_name: &str,
    function_name: &str,
    ty_args: Vec<TypeTag>,
    args: Vec<Vec<u8>>,
    address: AccountAddress,
) {
    session
        .execute_function_bypass_visibility(
            &ModuleId::new(address, Identifier::new(module_name).unwrap()),
            &Identifier::new(function_name).unwrap(),
            ty_args,
            args,
            &mut UnmeteredGasMeter,
            traversal_context,
            module_storage,
        )
        .unwrap_or_else(|e| {
            panic!(
                "Error calling {}.{}.{}: ({:#x}) {}",
                address,
                module_name,
                function_name,
                e.sub_status().unwrap_or_default(),
                e,
            )
        });
}

fn exec_function(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl ModuleStorage,
    traversal_context: &mut TraversalContext,
    module_name: &str,
    function_name: &str,
    ty_args: Vec<TypeTag>,
    args: Vec<Vec<u8>>,
) {
    exec_function_internal(
        session,
        module_storage,
        traversal_context,
        module_name,
        function_name,
        ty_args,
        args,
        CORE_CODE_ADDRESS,
    );
}

fn exec_experimental_function(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl ModuleStorage,
    traversal_context: &mut TraversalContext,
    module_name: &str,
    function_name: &str,
    ty_args: Vec<TypeTag>,
    args: Vec<Vec<u8>>,
) {
    exec_function_internal(
        session,
        module_storage,
        traversal_context,
        module_name,
        function_name,
        ty_args,
        args,
        EXPERIMENTAL_CODE_ADDRESS,
    );
}

fn initialize(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    chain_id: ChainId,
    genesis_config: &GenesisConfiguration,
    consensus_config: &OnChainConsensusConfig,
    execution_config: &OnChainExecutionConfig,
    gas_schedule: &GasScheduleV2,
    supra_config_bytes: Vec<u8>,
) {
    let gas_schedule_blob =
        bcs::to_bytes(gas_schedule).expect("Failure serializing genesis gas schedule");

    let consensus_config_bytes =
        bcs::to_bytes(consensus_config).expect("Failure serializing genesis consensus config");

    let execution_config_bytes =
        bcs::to_bytes(execution_config).expect("Failure serializing genesis consensus config");

    // Calculate the per-epoch rewards rate, represented as 2 separate ints (numerator and
    // denominator).
    let rewards_rate_denominator = 1_000_000_000;
    let num_epochs_in_a_year = NUM_SECONDS_PER_YEAR / genesis_config.epoch_duration_secs;
    // Multiplication before division to minimize rounding errors due to integer division.
    let rewards_rate_numerator = (genesis_config.rewards_apy_percentage * rewards_rate_denominator
        / APY_PRECISION)
        / num_epochs_in_a_year;

    // Block timestamps are in microseconds and epoch_interval is used to check if a block timestamp
    // has crossed into a new epoch. So epoch_interval also needs to be in micro seconds.
    let epoch_interval_usecs = genesis_config.epoch_duration_secs * MICRO_SECONDS_PER_SECOND;
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![
            MoveValue::vector_u8(gas_schedule_blob),
            MoveValue::U8(chain_id.id()),
            MoveValue::U64(APTOS_MAX_KNOWN_VERSION.major),
            MoveValue::vector_u8(consensus_config_bytes),
            MoveValue::vector_u8(execution_config_bytes),
            MoveValue::vector_u8(supra_config_bytes),
            MoveValue::U64(epoch_interval_usecs),
            MoveValue::U64(genesis_config.min_stake),
            MoveValue::U64(genesis_config.max_stake),
            MoveValue::U64(genesis_config.recurring_lockup_duration_secs),
            MoveValue::Bool(genesis_config.allow_new_validators),
            MoveValue::U64(rewards_rate_numerator),
            MoveValue::U64(rewards_rate_denominator),
            MoveValue::U64(genesis_config.voting_power_increase_limit),
            MoveValue::U64(genesis_config.genesis_timestamp_in_microseconds),
        ]),
    );
}

fn initialize_features(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    features_override: Option<Vec<FeatureFlag>>,
) {
    let features: Vec<u64> = features_override
        .unwrap_or_else(FeatureFlag::default_features)
        .into_iter()
        .map(|feature| feature as u64)
        .collect();

    let mut serialized_values = serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]);
    serialized_values.push(bcs::to_bytes(&features).unwrap());
    serialized_values.push(bcs::to_bytes(&Vec::<u64>::new()).unwrap());

    exec_function(
        session,
        module_storage,
        traversal_context,
        "features",
        "change_feature_flags_internal",
        vec![],
        serialized_values,
    );
}

fn initialize_supra_coin(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "initialize_supra_coin",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn initialize_supra_native_automation(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    genesis_config: &GenesisConfiguration,
) {
    let Some(config) = &genesis_config.automation_registry_config else {
        return;
    };
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "initialize_supra_native_automation_v2",
        vec![],
        config.serialize_into_move_values_with_signer(CORE_CODE_ADDRESS),
    );
}

fn initialize_leader_ban_config(
    session: &mut SessionExt,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    genesis_config: &GenesisConfiguration,
) {
    let Some(config) = &genesis_config.leader_ban_registry_config else {
        return;
    };
    exec_function(
        session,
        module_storage: &impl AptosModuleStorage,
        traversal_context: &mut TraversalContext,
        GENESIS_MODULE_NAME,
        "initialize_leader_ban_registry_config",
        vec![],
        config.serialize_into_move_values_with_signer(CORE_CODE_ADDRESS),
    );
}

fn initialize_leader_ban_config(
    session: &mut SessionExt,
    genesis_config: &GenesisConfiguration,
) {
    let Some(config) = &genesis_config.leader_ban_registry_config else {
        return;
    };
    exec_function(
        session,
        GENESIS_MODULE_NAME,
        "initialize_leader_ban_registry_config",
        vec![],
        config.serialize_into_move_values_with_signer(CORE_CODE_ADDRESS),
    );
}

fn initialize_evm_genesis_config(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    evm_genesis_config: &OnChainEvmGenesisConfig,
) {
    let evm_genesis_config_bytes =
        bcs::to_bytes(evm_genesis_config).expect("Failure serializing genesis evm config");

    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "initialize_evm_genesis_config",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::vector_u8(evm_genesis_config_bytes),
        ]),
    );
}

fn initialize_config_buffer(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        CONFIG_BUFFER_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn initialize_dkg(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        DKG_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn initialize_randomness_config_seqnum(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        RANDOMNESS_CONFIG_SEQNUM_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn initialize_randomness_api_v0_config(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        RANDOMNESS_API_V0_CONFIG_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            RequiredGasDeposit::default_for_genesis().as_move_value(),
            AllowCustomMaxGasFlag::default_for_genesis().as_move_value(),
        ]),
    );
}

fn initialize_randomness_config(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    randomness_config: OnChainRandomnessConfig,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        RANDOMNESS_CONFIG_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            RandomnessConfigMoveStruct::from(randomness_config).as_move_value(),
        ]),
    );
}

fn initialize_randomness_resources(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        RANDOMNESS_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn initialize_account_abstraction(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        ACCOUNT_ABSTRACTION_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );

    exec_function(
        session,
        module_storage,
        traversal_context,
        ACCOUNT_ABSTRACTION_MODULE_NAME,
        "register_derivable_authentication_function",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::Address(AccountAddress::SEVEN),
            "test_derivable_account_abstraction_ed25519_hex"
                .to_string()
                .as_move_value(),
            "authenticate".to_string().as_move_value(),
        ]),
    );

    exec_function(
        session,
        module_storage,
        traversal_context,
        ACCOUNT_ABSTRACTION_MODULE_NAME,
        "register_derivable_authentication_function",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::Address(AccountAddress::ONE),
            "solana_derivable_account".to_string().as_move_value(),
            "authenticate".to_string().as_move_value(),
        ]),
    );

    exec_function(
        session,
        module_storage,
        traversal_context,
        ACCOUNT_ABSTRACTION_MODULE_NAME,
        "register_derivable_authentication_function",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::Address(AccountAddress::ONE),
            "ethereum_derivable_account".to_string().as_move_value(),
            "authenticate".to_string().as_move_value(),
        ]),
    );
}

fn initialize_reconfiguration_state(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        RECONFIGURATION_STATE_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn initialize_jwk_consensus_config(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    jwk_consensus_config: &OnChainJWKConsensusConfig,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        JWK_CONSENSUS_CONFIG_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            jwk_consensus_config.as_move_value(),
        ]),
    );
}

fn initialize_jwks_resources(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        JWKS_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn set_genesis_end(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "set_genesis_end",
        vec![],
        serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]),
    );
}

fn initialize_core_resources_and_supra_coin(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    core_resources_key: &Ed25519PublicKey,
) {
    let core_resources_auth_key = AuthenticationKey::ed25519(core_resources_key);
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "initialize_core_resources_and_supra_coin",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::vector_u8(core_resources_auth_key.to_vec()),
        ]),
    );
}

/// Create and initialize Association and Core Code accounts.
fn initialize_on_chain_governance(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    genesis_config: &GenesisConfiguration,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        GOVERNANCE_MODULE_NAME,
        "initialize",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::U64(genesis_config.voting_duration_secs),
            MoveValue::U64(genesis_config.min_voting_threshold),
            MoveValue::vector_address(genesis_config.voters.clone()),
        ]),
    );
}

fn initialize_keyless_accounts(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    chain_id: ChainId,
    mut initial_jwks: Vec<IssuerJWK>,
    vk: Option<Groth16VerificationKey>,
) {
    let config = keyless::Configuration::new_for_devnet();
    exec_function(
        session,
        module_storage,
        traversal_context,
        KEYLESS_ACCOUNT_MODULE_NAME,
        "update_configuration",
        vec![],
        serialize_values(&vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            config.as_move_value(),
        ]),
    );

    if vk.is_some() {
        exec_function(
            session,
            module_storage,
            traversal_context,
            KEYLESS_ACCOUNT_MODULE_NAME,
            "update_groth16_verification_key",
            vec![],
            serialize_values(&vec![
                MoveValue::Signer(CORE_CODE_ADDRESS),
                vk.unwrap().as_move_value(),
            ]),
        );
    }
    if !chain_id.is_mainnet() {
        let additional_jwk_patch = IssuerJWK {
            issuer: get_sample_iss(),
            jwk: JWK::RSA(secure_test_rsa_jwk()),
        };
        initial_jwks.insert(0, additional_jwk_patch);

        let jwk_patches: Vec<PatchJWKMoveStruct> = initial_jwks
            .into_iter()
            .map(|issuer_jwk| {
                let IssuerJWK { issuer, jwk } = issuer_jwk;
                let upsert_patch = PatchUpsertJWK {
                    issuer,
                    jwk: JWKMoveStruct::from(jwk),
                };
                PatchJWKMoveStruct::from(upsert_patch)
            })
            .collect();

        exec_function(
            session,
            module_storage,
            traversal_context,
            JWKS_MODULE_NAME,
            "set_patches",
            vec![],
            serialize_values(&vec![
                MoveValue::Signer(CORE_CODE_ADDRESS),
                jwk_patches.as_move_value(),
            ]),
        );
    }
}

fn initialize_confidential_asset(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    chain_id: ChainId,
    traversal_context: &mut TraversalContext,
) {
    if !chain_id.is_mainnet() && !chain_id.is_testnet() {
        exec_experimental_function(
            session,
            module_storage,
            traversal_context,
            "confidential_asset",
            "init_module_for_genesis",
            vec![],
            serialize_values(&vec![MoveValue::Signer(EXPERIMENTAL_CODE_ADDRESS)]),
        );
    }
}

fn create_accounts(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    accounts: &BTreeSet<AccountBalance>,
) {
    // Creating accounts one by one avoids the quadratic complexity of the Move function create_accounts,
    // which checks uniqueness.
    for account in accounts {
        let accounts = vec![account];
        let accounts_bytes =
            bcs::to_bytes(accounts.as_slice()).expect("Accounts must be serialized");
        let mut serialized_values = serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]);
        serialized_values.push(accounts_bytes);
        exec_function(
            session,
            module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
            "create_accounts",
            vec![],
            serialized_values,
        );
    }
}

/// Creates and initializes each validator owner and validator operator. This method creates all
/// the required accounts, sets the validator operators for each validator owner, and sets the
/// validator config on-chain.
fn create_and_initialize_validators(
    session: &mut SessionExt<impl AptosMoveResolver>, 
    module_storage: &impl ModuleStorage,
    traversal_context: &mut TraversalContext,
    validators: &[Validator],
) {
    let validators_bytes = bcs::to_bytes(validators).expect("Validators can be serialized");
    let mut serialized_values = serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]);
    serialized_values.push(validators_bytes);
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "create_initialize_validators",
        vec![],
        serialized_values,
    );
}

fn create_multiple_multisig_accounts_with_schema(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    multiple_multi_sig_account_with_balance: MultiSigAccountSchema,
) {
    let mut serialized_values = serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]);

    let owners_bytes = bcs::to_bytes(&multiple_multi_sig_account_with_balance.owner)
        .expect("Owner address for MultiSig accounts should be serializable");
    serialized_values.push(owners_bytes);

    let additional_owners_bytes =
        bcs::to_bytes(&multiple_multi_sig_account_with_balance.additional_owners)
            .expect("Additional owners addresses for MultiSig accounts should be serializable");
    serialized_values.push(additional_owners_bytes);

    let num_signatures_required_bytes =
        bcs::to_bytes(&multiple_multi_sig_account_with_balance.num_signatures_required)
            .expect("num_signatures_required for MultiSig accounts should be serializable");
    serialized_values.push(num_signatures_required_bytes);

    let metadata_keys_bytes = bcs::to_bytes(&multiple_multi_sig_account_with_balance.metadata_keys)
        .expect("metadata_keys for MultiSig accounts should be serializable");
    serialized_values.push(metadata_keys_bytes);

    let metadata_values_bytes =
        bcs::to_bytes(&multiple_multi_sig_account_with_balance.metadata_values)
            .expect("metadata_values for MultiSig accounts should be serializable");
    serialized_values.push(metadata_values_bytes);

    let timeout_duration_bytes =
        bcs::to_bytes(&multiple_multi_sig_account_with_balance.timeout_duration)
            .expect("timeout_duration for MultiSig accounts should be serializable");
    serialized_values.push(timeout_duration_bytes);

    let balance_bytes = bcs::to_bytes(&multiple_multi_sig_account_with_balance.balance)
        .expect("balance for MultiSig accounts should be serializable");
    serialized_values.push(balance_bytes);

    let num_of_accounts_bytes =
        bcs::to_bytes(&multiple_multi_sig_account_with_balance.num_of_accounts)
            .expect("num_of_accounts for MultiSig accounts should be serializable");
    serialized_values.push(num_of_accounts_bytes);

    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "create_multiple_multisig_accounts_with_schema",
        vec![],
        serialized_values,
    );
}

fn create_multisig_accounts_with_balance(

    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,

    multisig_accounts: &[MultiSigAccountWithBalance],
) {
    for account_configuration in multisig_accounts {
        let mut serialized_values = serialize_values(&vec![MoveValue::Signer(CORE_CODE_ADDRESS)]);

        let owners_bytes = bcs::to_bytes(&account_configuration.owner)
            .expect("Owner for MultiSig accounts should be serializable");
        serialized_values.push(owners_bytes);

        let additional_owners_bytes = bcs::to_bytes(&account_configuration.additional_owners)
            .expect("Additional owners for MultiSig accounts should be serializable");
        serialized_values.push(additional_owners_bytes);

        let threshold_bytes = bcs::to_bytes(&account_configuration.num_signatures_required)
            .expect("Threshold u64 for MultiSig accounts should be serializable");
        serialized_values.push(threshold_bytes);

        let metadata_keys_bytes = bcs::to_bytes(&account_configuration.metadata_keys)
            .expect("Metadata Keys for MultiSig accounts should be serializable");
        serialized_values.push(metadata_keys_bytes);

        let metadata_values_bytes = bcs::to_bytes(&account_configuration.metadata_values)
            .expect("Metadata Values for MultiSig accounts should be serializable");
        serialized_values.push(metadata_values_bytes);

        let timeout_duration_bytes = bcs::to_bytes(&account_configuration.timeout_duration)
            .expect("Timeout duration for MultiSig accounts should be serializable");
        serialized_values.push(timeout_duration_bytes);

        let balance_bytes = bcs::to_bytes(&account_configuration.balance)
            .expect("Timeout duration for MultiSig accounts should be serializable");
        serialized_values.push(balance_bytes);

        exec_function(
            session,
            module_storage,
            traversal_context,
            GENESIS_MODULE_NAME,
            "create_multisig_account_with_balance",
            vec![],
            serialized_values,
        );
    }
}

fn create_pbo_delegation_pools(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    pbo_delegator_configuration: &[PboDelegatorConfiguration],
) {
    let pbo_config_bytes = bcs::to_bytes(pbo_delegator_configuration)
        .expect("PboDelegatorConfiguration can be serialized");
    let mut serialized_values =
        serialize_values(&vec![MoveValue::U64(PBO_DELEGATION_POOL_LOCKUP_PERCENTAGE)]);
    serialized_values.insert(0, pbo_config_bytes);
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "create_pbo_delegation_pools",
        vec![],
        serialized_values,
    )
}

fn add_owner_stakes_for_delegation_pools(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
    pbo_delegator_configuration: &[PboDelegatorConfiguration],
    owner_stake_for_pbo_pool: u64,
) {
    for pool_config in pbo_delegator_configuration {
        let pbo_pool_seed =
            create_seed_for_pbo_module(&pool_config.delegator_config.delegation_pool_creation_seed);
        let pool_address =
            create_resource_address(pool_config.delegator_config.owner_address, &pbo_pool_seed);
        let serialized_values = serialize_values(&vec![
            MoveValue::Signer(pool_config.delegator_config.owner_address),
            MoveValue::Address(pool_address),
            MoveValue::U64(owner_stake_for_pbo_pool),
        ]);
        exec_function(
            session,
            module_storage,
            traversal_context,
            PBO_DELEGATION_POOL_MODULE_NAME,
            "add_stake",
            vec![],
            serialized_values,
        )
    }
}

fn create_vesting_without_staking_pools(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl ModuleStorage,
    traversal_context: &mut TraversalContext,
    vesting_pools_map: &[VestingPoolsMap],
) {
    let serialized_values =
        vec![bcs::to_bytes(vesting_pools_map).expect("VestingPoolsMap can be serialized")];
    exec_function(
        session,
        module_storage,
        traversal_context,
        GENESIS_MODULE_NAME,
        "create_vesting_without_staking_pools",
        vec![],
        serialized_values,
    )
}

fn allow_core_resources_to_set_version(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        VERSION_MODULE_NAME,
        "initialize_for_test",
        vec![],
        serialize_values(&vec![MoveValue::Signer(aptos_test_root_address())]),
    );
}

fn initialize_package(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl ModuleStorage,
    traversal_context: &mut TraversalContext,
    addr: AccountAddress,
    package: &ReleasePackage,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        CODE_MODULE_NAME,
        "initialize",
        vec![],
        vec![
            MoveValue::Signer(CORE_CODE_ADDRESS)
                .simple_serialize()
                .unwrap(),
            MoveValue::Signer(addr).simple_serialize().unwrap(),
            bcs::to_bytes(package.package_metadata()).unwrap(),
        ],
    );
}

fn code_to_writes_for_publishing(
    genesis_runtime_environment: &RuntimeEnvironment,
    genesis_features: &Features,
    genesis_state_view: &GenesisStateView,
    addr: AccountAddress,
    code: Vec<Bytes>,
) -> VMResult<BTreeMap<StateKey, ModuleWrite<WriteOp>>> {
    let module_storage = genesis_state_view.as_aptos_code_storage(genesis_runtime_environment);
    let resolver = genesis_state_view.as_move_resolver();

    let module_storage_with_staged_modules =
        StagingModuleStorage::create(&addr, &module_storage, code)?;
    let verified_module_bundle =
        module_storage_with_staged_modules.release_verified_module_bundle();

    convert_modules_into_write_ops(
        &resolver,
        genesis_features,
        &module_storage,
        verified_module_bundle,
    )
    .map_err(|e| e.finish(Location::Undefined))
}

/// Produces the changes when a framework is published:
///  1. Resources containing package information.
///  2. Module write set with published code.
fn publish_framework(
    genesis_vm: &GenesisMoveVm,
    genesis_runtime_environment: &RuntimeEnvironment,
    hash_value: HashValue,
    framework: &ReleaseBundle,
) -> (VMChangeSet, ModuleWriteSet) {
    // Reset state view to be empty, to make sure all module write ops are creations.
    let mut state_view = GenesisStateView::new();

    // First, publish modules.
    let mut writes = BTreeMap::new();
    for pack in &framework.packages {
        let modules = pack.sorted_code_and_modules();

        let addr = *modules.first().unwrap().1.self_id().address();
        let code = modules
            .into_iter()
            .map(|(c, _)| c.to_vec().into())
            .collect::<Vec<_>>();

        let package_writes = code_to_writes_for_publishing(
            genesis_runtime_environment,
            genesis_vm.genesis_features(),
            &state_view,
            addr,
            code,
        )
        .unwrap_or_else(|e| {
            panic!(
                "Failure publishing package `{}`: {:?}",
                pack.package_metadata().name,
                e
            )
        });

        // Add write ops so that we can later create a module write set. Also add them to the state
        // view so that modules in subsequent packages can link to them.
        writes.extend(package_writes.clone());
        state_view.add_module_write_ops(package_writes);
    }
    let module_write_set = ModuleWriteSet::new(writes);

    // At this point we processed all packages, and the state view contains all the code. We can
    // run package initialization.

    let module_storage = state_view.as_aptos_code_storage(genesis_runtime_environment);
    let resolver = state_view.as_move_resolver();
    let mut session = genesis_vm.new_genesis_session(&resolver, hash_value);

    let traversal_storage = TraversalStorage::new();
    let mut traversal_context = TraversalContext::new(&traversal_storage);

    for pack in &framework.packages {
        // Unfortunately, package does not contain address information, so we have to access its
        // modules to extract the destination address.
        let addr = *pack
            .sorted_code_and_modules()
            .first()
            .unwrap()
            .1
            .self_id()
            .address();
        initialize_package(
            &mut session,
            &module_storage,
            &mut traversal_context,
            addr,
            pack,
        );
    }

    let change_set =
        assert_ok!(session.finish(&genesis_vm.genesis_change_set_configs(), &module_storage,));
    (change_set, module_write_set)
}

/// Trigger a reconfiguration. This emits an event that will be passed along to the storage layer.
fn emit_new_block_and_epoch_event(
    session: &mut SessionExt<impl AptosMoveResolver>,
    module_storage: &impl AptosModuleStorage,
    traversal_context: &mut TraversalContext,
) {
    exec_function(
        session,
        module_storage,
        traversal_context,
        "block",
        "emit_genesis_block_event",
        vec![],
        serialize_values(&vec![MoveValue::Signer(
            account_config::reserved_vm_address(),
        )]),
    );
    exec_function(
        session,
        module_storage,
        traversal_context,
        "reconfiguration",
        "emit_genesis_reconfiguration_event",
        vec![],
        vec![],
    );
}

/// Verify the consistency of modules in the genesis write set.
fn verify_genesis_module_write_set(write_set: &WriteSet) {
    for (state_key, write_op) in write_set.expect_write_op_iter() {
        if state_key.is_module_path() {
            assert!(write_op.is_creation())
        }
    }
}

/// Verify the consistency of events emitted during genesis.
fn verify_genesis_events(events: &[ContractEvent]) {
    let new_epoch_events: Vec<&ContractEventV1> = events
        .iter()
        .filter_map(|e| {
            if e.event_key() == Some(&NewEpochEvent::event_key()) {
                Some(e.v1().unwrap())
            } else {
                None
            }
        })
        .collect();
    assert_eq!(
        new_epoch_events.len(),
        1,
        "There should only be exactly one NewEpochEvent"
    );
    assert_eq!(new_epoch_events[0].sequence_number(), 0);
}

/// An enum specifying whether the compiled stdlib/scripts should be used or freshly built versions
/// should be used.
#[derive(Debug, Eq, PartialEq)]
pub enum GenesisOptions {
    /// Framework compiled from head
    Head,
    /// Framework as it was released or upgraded in testnet
    Testnet,
    /// Framework as it was released or upgraded in mainnet
    Mainnet,
}

/// Generate an artificial genesis `ChangeSet` for testing
pub fn generate_genesis_change_set_for_testing(genesis_options: GenesisOptions) -> ChangeSet {
    generate_genesis_change_set_for_testing_with_count(genesis_options, 1)
}

pub fn generate_genesis_change_set_for_testing_with_count(
    genesis_options: GenesisOptions,
    count: u64,
) -> ChangeSet {
    let framework = match genesis_options {
        GenesisOptions::Head => aptos_cached_packages::head_release_bundle(),
        GenesisOptions::Testnet => aptos_framework::testnet_release_bundle(),
        GenesisOptions::Mainnet => {
            // We don't yet have mainnet, so returning testnet here
            aptos_framework::testnet_release_bundle()
        },
    };

    generate_test_genesis(framework, Some(count as usize)).0
}

/// Generate a genesis `ChangeSet` for mainnet
pub fn generate_genesis_change_set_for_mainnet(genesis_options: GenesisOptions) -> ChangeSet {
    let framework = match genesis_options {
        GenesisOptions::Head => aptos_cached_packages::head_release_bundle(),
        GenesisOptions::Testnet => aptos_framework::testnet_release_bundle(),
        // We don't yet have mainnet, so returning testnet here
        GenesisOptions::Mainnet => aptos_framework::testnet_release_bundle(),
    };

    generate_mainnet_genesis(framework, Some(1)).0
}

pub fn test_genesis_transaction() -> Transaction {
    let changeset = test_genesis_change_set_and_validators(None).0;
    Transaction::GenesisTransaction(WriteSetPayload::Direct(changeset))
}

pub fn test_genesis_change_set_and_validators(
    count: Option<usize>,
) -> (ChangeSet, Vec<TestValidator>) {
    generate_test_genesis(aptos_cached_packages::head_release_bundle(), count)
}

#[derive(Debug, Clone, Serialize, Deserialize, Hash, PartialEq, Eq, PartialOrd, Ord)]
pub struct Validator {
    /// The Aptos account address of the validator or the admin in the case of a commissioned or
    /// vesting managed validator.
    pub owner_address: AccountAddress,
    /// The Aptos account address of the validator's operator (same as `address` if the validator is
    /// its own operator).
    pub operator_address: AccountAddress,
    pub voter_address: AccountAddress,
    /// Amount to stake for consensus. Also the intial amount minted to the owner account.
    pub stake_amount: u64,

    /// ed25519 public key used to sign consensus messages.
    pub consensus_pubkey: Vec<u8>,
    /// `NetworkAddress` for the validator.
    pub network_addresses: Vec<u8>,
    /// `NetworkAddress` for the validator's full node.
    pub full_node_network_addresses: Vec<u8>,
}

pub struct TestValidator {
    pub key: Ed25519PrivateKey,
    pub consensus_key: ed25519::PrivateKey,
    pub data: Validator,
}

impl TestValidator {
    pub fn new_test_set(count: Option<usize>, initial_stake: Option<u64>) -> Vec<TestValidator> {
        let mut rng = rand::SeedableRng::from_seed([1u8; 32]);
        (0..count.unwrap_or(10))
            .map(|_| TestValidator::gen(&mut rng, initial_stake))
            .collect()
    }

    fn gen(rng: &mut StdRng, initial_stake: Option<u64>) -> TestValidator {
        let key = Ed25519PrivateKey::generate(rng);
        let auth_key = AuthenticationKey::ed25519(&key.public_key());
        let owner_address = auth_key.account_address();
        let consensus_key = ed25519::PrivateKey::generate(rng);
        let network_pubkey_bytes = consensus_key.public_key().to_bytes().to_vec();
        let bls_key = bls12381::PrivateKey::generate(rng);
        let bls_pubkey_bytes = bls12381::PublicKey::from(&bls_key).to_bytes().to_vec();
        let cg_pubkey_bytes = {
            let mut cg_rng = crypto::bls12381::cl_utils::rng();
            crypto::bls12381::cg_encryption::keygen(&mut cg_rng, &[])
                .expect("CG keygen must succeed")
                .1
                .to_vec()
        };
        let supra_ed_key = ed25519::PrivateKey::generate(rng);
        let supra_ed_pubkey_bytes = supra_ed_key.public_key().to_bytes().to_vec();
        // When SUPRA_BLS_KEYS feature is enabled (default), the genesis validator key must be
        // BCS-encoded ValidatorPublicKeys, not a plain ed25519 key.
        let validator_public_keys = ValidatorPublicKeys::new(
            network_pubkey_bytes,
            bls_pubkey_bytes,
            None,
            None,
            None,
            None,
            None,
            None,
            None,
            cg_pubkey_bytes,
            supra_ed_pubkey_bytes,
        );
        let consensus_pubkey =
            bcs::to_bytes(&validator_public_keys).expect("ValidatorPublicKeys must serialize");
        let network_address = [0u8; 0].to_vec();
        let full_node_network_address = [0u8; 0].to_vec();

        let stake_amount = initial_stake.unwrap_or(1);
        let data = Validator {
            owner_address,
            consensus_pubkey,
            operator_address: owner_address,
            voter_address: owner_address,
            network_addresses: network_address,
            full_node_network_addresses: full_node_network_address,
            stake_amount,
        };
        Self {
            key,
            consensus_key,
            data,
        }
    }
}

pub fn generate_test_genesis(
    framework: &ReleaseBundle,
    count: Option<usize>,
) -> (ChangeSet, Vec<TestValidator>) {
    let test_validators = TestValidator::new_test_set(count, Some(100_000_000));
    let validators_: Vec<Validator> = test_validators.iter().map(|t| t.data.clone()).collect();
    let validators = &validators_;

    let genesis = encode_genesis_change_set_for_testnet(
        &GENESIS_KEYPAIR.1,
        &BTreeSet::new(),
        &[],
        None,
        validators,
        &[],
        0,
        &[],
        &[],
        framework,
        ChainId::test(),
        &GenesisConfiguration {
            allow_new_validators: true,
            epoch_duration_secs: 3600,
            is_test: true,
            min_stake: 0,
            min_voting_threshold: 2,
            // 1M APTOS coins (with 8 decimals).
            max_stake: 100_000_000_000_000,
            recurring_lockup_duration_secs: 7200,
            required_proposer_stake: 0,
            rewards_apy_percentage: 1000,
            voting_duration_secs: 3600,
            voters: vec![
                AccountAddress::from_hex_literal("0xdd1").unwrap(),
                AccountAddress::from_hex_literal("0xdd2").unwrap(),
                AccountAddress::from_hex_literal("0xdd3").unwrap(),
            ],
            voting_power_increase_limit: 50,
            genesis_timestamp_in_microseconds: 0,
            employee_vesting_start: 1663456089,
            employee_vesting_period_duration: 5 * 60, // 5 minutes
            initial_features_override: None,
            randomness_config_override: None,
            jwk_consensus_config_override: None,
            automation_registry_config: Some(AutomationRegistryConfig::default()),
            leader_ban_registry_config: Some(BanRegistryParameters::default()),
            initial_jwks: vec![],
            keyless_groth16_vk: None,
        },
        &OnChainConsensusConfig::default_for_genesis(),
        &OnChainExecutionConfig::default_for_genesis(),
        &default_gas_schedule(),
        b"test".to_vec(),
        None,
    );
    (genesis, test_validators)
}

pub fn generate_mainnet_genesis(
    framework: &ReleaseBundle,
    count: Option<usize>,
) -> (ChangeSet, Vec<TestValidator>) {
    // TODO: Update to have custom validators/accounts with initial balances at genesis.
    let test_validators = TestValidator::new_test_set(count, Some(1_000_000_000_000_000));
    let validators_: Vec<Validator> = test_validators.iter().map(|t| t.data.clone()).collect();
    let validators = &validators_;

    let genesis = encode_genesis_change_set_for_testnet(
        &GENESIS_KEYPAIR.1,
        &BTreeSet::new(),
        &[],
        None,
        validators,
        &[],
        0,
        &[],
        &[],
        framework,
        ChainId::test(),
        &mainnet_genesis_config(),
        &OnChainConsensusConfig::default_for_genesis(),
        &OnChainExecutionConfig::default_for_genesis(),
        &default_gas_schedule(),
        b"test".to_vec(),
        None,
    );
    (genesis, test_validators)
}

fn mainnet_genesis_config() -> GenesisConfiguration {
    // TODO: Update once mainnet numbers are decided. These numbers are just placeholders.
    GenesisConfiguration {
        allow_new_validators: true,
        epoch_duration_secs: 2 * 3600, // 2 hours
        is_test: false,
        min_stake: 1_000_000 * APTOS_COINS_BASE_WITH_DECIMALS, // 1M SUPRA
        // 400M SUPRA
        min_voting_threshold: 2,
        max_stake: 50_000_000 * APTOS_COINS_BASE_WITH_DECIMALS, // 50M SUPRA.
        recurring_lockup_duration_secs: 30 * 24 * 3600,         // 1 month
        required_proposer_stake: 1_000_000 * APTOS_COINS_BASE_WITH_DECIMALS, // 1M SUPRA
        rewards_apy_percentage: 1000,
        voting_duration_secs: 7 * 24 * 3600, // 7 days
        voters: vec![
            AccountAddress::from_hex_literal("0xdd1").unwrap(),
            AccountAddress::from_hex_literal("0xdd2").unwrap(),
            AccountAddress::from_hex_literal("0xdd3").unwrap(),
        ],
        voting_power_increase_limit: 30,
        genesis_timestamp_in_microseconds: 0,
        employee_vesting_start: 1663456089,
        employee_vesting_period_duration: 5 * 60, // 5 minutes
        initial_features_override: None,
        randomness_config_override: None,
        jwk_consensus_config_override: None,
        automation_registry_config: Some(AutomationRegistryConfig::default()),
        leader_ban_registry_config: Some(BanRegistryParameters::default()),
        initial_jwks: vec![],
        keyless_groth16_vk: None,
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, PartialOrd, Ord)]
pub struct AccountBalance {
    pub account_address: AccountAddress,
    pub balance: u64,
}

impl Hash for AccountBalance {
    fn hash<H: Hasher>(&self, state: &mut H) {
        state.write(&self.account_address.to_vec());
        let _ = state.finish();
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmployeePool {
    pub accounts: Vec<AccountAddress>,
    pub validator: ValidatorWithCommissionRate,
    pub vesting_schedule_numerators: Vec<u64>,
    pub vesting_schedule_denominator: u64,
    // Address that can reset the beneficiary for any shareholder.
    pub beneficiary_resetter: AccountAddress,
}

#[derive(Debug, Clone, Serialize, Deserialize, Hash, PartialEq, Eq, PartialOrd, Ord)]
pub struct ValidatorWithCommissionRate {
    pub validator: Validator,
    pub validator_commission_percentage: u64,
    /// Whether the validator should be joining the genesis validator set.
    pub join_during_genesis: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Hash, PartialEq, Eq, PartialOrd, Ord)]
pub struct DelegatorConfiguration {
    pub owner_address: AccountAddress,
    pub delegation_pool_creation_seed: Vec<u8>,
    pub validator: ValidatorWithCommissionRate,
    pub delegator_addresses: Vec<AccountAddress>,
    pub delegator_stakes: Vec<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Hash, PartialEq, Eq, Ord, PartialOrd)]
pub struct PboDelegatorConfiguration {
    pub delegator_config: DelegatorConfiguration,
    //Address of the multisig admin of the pool
    pub multisig_admin: AccountAddress,
    //Numerator for unlock fraction
    pub unlock_schedule_numerators: Vec<u64>,
    //Denominator for unlock fraction
    pub unlock_schedule_denominator: u64,
    //Time from `timestamp::now_seconds()` to start unlocking schedule
    pub unlock_startup_time_from_now: u64,
    //Time for each unlock
    pub unlock_period_duration: u64,
}

#[derive(Debug, Clone, PartialEq, PartialOrd, Ord, Eq, Serialize, Deserialize, Hash)]
pub struct VestingPoolsMap {
    // Address of the admin of the vesting pool
    pub admin_address: AccountAddress,
    // Percentage of account balance should be put in vesting pool
    pub vpool_locking_percentage: u8,
    pub vesting_numerators: Vec<u64>,
    pub vesting_denominator: u64,
    //Withdrawal address for the pool
    pub withdrawal_address: AccountAddress,
    // Shareholders in the vesting pool
    pub shareholders: Vec<AccountAddress>,
    //Cliff duration in seconds
    pub cliff_period_in_seconds: u64,
    // Each vesting period duration in seconds
    pub period_duration_in_seconds: u64,
}

#[derive(Clone, Debug, PartialEq, PartialOrd, Ord, Eq, Serialize, Deserialize)]
pub struct MultiSigAccountWithBalance {
    pub owner: AccountAddress,
    pub additional_owners: Vec<AccountAddress>,
    /*
    The reason for this field to exist is for hashing it in the SMR-Moonshot to make sure that
    we are not supplying duplicate multisig data to the Genesis encoder functions. Multiple multisig
    addresses can be created with the same set of owners and parameters as multisig addresses depend
    only on the primary owner and their sequence number. Therefore, as a distinguishing factor, we add
    the multisig address to this field and use in the type's hashing function implemented below.
    The genesis tx encoder functions need to re-written in the future to mitigate this.
     */
    pub multisig_address: AccountAddress,
    pub num_signatures_required: u64,
    pub metadata_keys: Vec<String>,
    pub metadata_values: Vec<Vec<u8>>,
    pub timeout_duration: u64,
    pub balance: u64,
}

impl Hash for MultiSigAccountWithBalance {
    fn hash<H: Hasher>(&self, state: &mut H) {
        state.write(&self.multisig_address.to_vec());
        let _ = state.finish();
    }
}

#[derive(Clone, Debug, PartialEq, PartialOrd, Ord, Eq, Serialize, Deserialize)]
pub struct MultiSigAccountSchema {
    pub owner: AccountAddress,
    pub additional_owners: Vec<AccountAddress>,
    pub num_signatures_required: u64,
    pub metadata_keys: Vec<String>,
    pub metadata_values: Vec<Vec<u8>>,
    pub timeout_duration: u64,
    pub balance: u64,
    pub num_of_accounts: u32,
}

#[test]
pub fn test_genesis_module_publishing() {
    let genesis_runtime_builder = GenesisRuntimeBuilder::new(ChainId::test());

    let genesis_vm = genesis_runtime_builder.build_genesis_vm();
    let genesis_runtime_environment = genesis_runtime_builder.build_genesis_runtime_environment();

    let (change_set, module_write_set) = publish_framework(
        &genesis_vm,
        &genesis_runtime_environment,
        HashValue::zero(),
        aptos_cached_packages::head_release_bundle(),
    );

    // All write ops must be a creation!
    let change_set = assert_ok!(change_set.try_combine_into_storage_change_set(module_write_set));
    verify_genesis_module_write_set(change_set.write_set());
}

#[test]
#[ignore] // TODO: This test needs fixing. Genesis transactions encoding are verified in e2e tests at smr-moonshot
pub fn test_mainnet_end_to_end() {
    const TOTAL_SUPPLY: u64 = 100_000_000_000 * APTOS_COINS_BASE_WITH_DECIMALS;
    const PBO_DELEGATOR_STAKE: u64 = 9_000_000 * APTOS_COINS_BASE_WITH_DECIMALS; // 9 mil

    // 21 Staking accounts - Total 210 million $Supra
    let pbo_balance = 10_000_000 * APTOS_COINS_BASE_WITH_DECIMALS; // 10 million each

    // 7 Operator balances - Total 70 $Supra
    let operator_balance = 10 * APTOS_COINS_BASE_WITH_DECIMALS; // 10 Supra each

    // 9 employees - Total 270 million $Supra
    let employee_balance = 30_000_000 * APTOS_COINS_BASE_WITH_DECIMALS; // 30 million each

    // The rest go to Supra Foundation - 99939999870 $Supra
    // Ninety-Nine Billion, Nine Hundred Thirty-Nine Million, nine hundred ninety-nine thousand, eight hundred seventy.
    let supra_foundation_balance =
        TOTAL_SUPPLY - (21 * pbo_balance) - (7 * operator_balance) - (9 * employee_balance);

    use aptos_types::{
        account_address, on_chain_config::ValidatorSet, state_store::state_key::StateKey,
        write_set::TransactionWrite, write_set::WriteSet
    };

    let balance = 10_000_000 * APTOS_COINS_BASE_WITH_DECIMALS;
    let non_validator_balance = 10 * APTOS_COINS_BASE_WITH_DECIMALS;

    // currently just test that all functions have the right interface
    let supra_foundation = AccountAddress::from_hex_literal("0x777").unwrap();

    let multisig_account01 = AccountAddress::from_hex_literal("0x1231").unwrap();
    let multisig_account02 = AccountAddress::from_hex_literal("0x1232").unwrap();
    let multisig_account03 = AccountAddress::from_hex_literal("0x1233").unwrap();
    let multisig_account04 = AccountAddress::from_hex_literal("0x1234").unwrap();
    let multisig_account05 = AccountAddress::from_hex_literal("0x1235").unwrap();
    let multisig_account06 = AccountAddress::from_hex_literal("0x1236").unwrap();
    let multisig_account07 = AccountAddress::from_hex_literal("0x1237").unwrap();

    let test_validators = TestValidator::new_test_set(Some(7), None);

    let operator_addrs0 = test_validators[0].data.operator_address;
    let operator_addrs1 = test_validators[1].data.operator_address;
    let operator_addrs2 = test_validators[2].data.operator_address;
    let operator_addrs3 = test_validators[3].data.operator_address;
    let operator_addrs4 = test_validators[4].data.operator_address;
    let operator_addrs5 = test_validators[5].data.operator_address;
    let operator_addrs6 = test_validators[6].data.operator_address;

    // PBO winner
    let pbo_account01 = AccountAddress::from_hex_literal("0x01").unwrap();
    let pbo_account02 = AccountAddress::from_hex_literal("0x02").unwrap();
    let pbo_account03 = AccountAddress::from_hex_literal("0x03").unwrap();
    let pbo_account11 = AccountAddress::from_hex_literal("0x11").unwrap();
    let pbo_account12 = AccountAddress::from_hex_literal("0x12").unwrap();
    let pbo_account13 = AccountAddress::from_hex_literal("0x13").unwrap();
    let pbo_account21 = AccountAddress::from_hex_literal("0x21").unwrap();
    let pbo_account22 = AccountAddress::from_hex_literal("0x22").unwrap();
    let pbo_account23 = AccountAddress::from_hex_literal("0x23").unwrap();
    let pbo_account31 = AccountAddress::from_hex_literal("0x31").unwrap();
    let pbo_account32 = AccountAddress::from_hex_literal("0x32").unwrap();
    let pbo_account33 = AccountAddress::from_hex_literal("0x33").unwrap();
    let pbo_account41 = AccountAddress::from_hex_literal("0x41").unwrap();
    let pbo_account42 = AccountAddress::from_hex_literal("0x42").unwrap();
    let pbo_account43 = AccountAddress::from_hex_literal("0x43").unwrap();
    let pbo_account51 = AccountAddress::from_hex_literal("0x51").unwrap();
    let pbo_account52 = AccountAddress::from_hex_literal("0x52").unwrap();
    let pbo_account53 = AccountAddress::from_hex_literal("0x53").unwrap();
    let pbo_account61 = AccountAddress::from_hex_literal("0x61").unwrap();
    let pbo_account62 = AccountAddress::from_hex_literal("0x62").unwrap();
    let pbo_account63 = AccountAddress::from_hex_literal("0x63").unwrap();

    // Voter accounts associated with the validators
    let voter0 = AccountAddress::from_hex_literal("0x200").unwrap();
    let voter1 = AccountAddress::from_hex_literal("0x201").unwrap();
    let voter2 = AccountAddress::from_hex_literal("0x202").unwrap();
    let voter3 = AccountAddress::from_hex_literal("0x203").unwrap();

    // Admin accounts - Not sure where these are used ATM
    let admin0 = AccountAddress::from_hex_literal("0x300").unwrap();
    let admin1 = AccountAddress::from_hex_literal("0x301").unwrap();
    let admin2 = AccountAddress::from_hex_literal("0x302").unwrap();

    // Employee Accounts
    let employee1 = AccountAddress::from_hex_literal("0xe1").unwrap();
    let employee2 = AccountAddress::from_hex_literal("0xe2").unwrap();
    let employee3 = AccountAddress::from_hex_literal("0xe3").unwrap();
    let employee4 = AccountAddress::from_hex_literal("0xe4").unwrap();
    let employee5 = AccountAddress::from_hex_literal("0xe5").unwrap();
    let employee6 = AccountAddress::from_hex_literal("0xe6").unwrap();
    let employee7 = AccountAddress::from_hex_literal("0xe7").unwrap();
    let employee8 = AccountAddress::from_hex_literal("0xe8").unwrap();
    let employee9 = AccountAddress::from_hex_literal("0xe9").unwrap();

    // All the above accounts to be created at genesis
    let accounts = BTreeSet::from([
        AccountBalance {
            account_address: supra_foundation,
            balance: supra_foundation_balance,
        },
        AccountBalance {
            account_address: pbo_account01,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account02,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account03,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account11,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account12,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account13,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account21,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account22,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account23,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account31,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account32,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account33,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account41,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account42,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account43,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account51,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account52,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account53,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account61,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account62,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: pbo_account63,
            balance: pbo_balance,
        },
        AccountBalance {
            account_address: admin0,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: admin1,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: admin2,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: operator_addrs0,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: operator_addrs1,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: operator_addrs2,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: operator_addrs3,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: operator_addrs4,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: operator_addrs5,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: operator_addrs6,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: voter0,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: voter1,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: voter2,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: voter3,
            balance: operator_balance,
        },
        AccountBalance {
            account_address: employee1,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee2,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee3,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee4,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee5,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee6,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee7,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee8,
            balance: employee_balance,
        },
        AccountBalance {
            account_address: employee9,
            balance: employee_balance,
        },
    ]);

    let pbo_config_val0 = PboDelegatorConfiguration {
        delegator_config: DelegatorConfiguration {
            owner_address: supra_foundation,
            delegation_pool_creation_seed: vec![0_u8],
            validator: ValidatorWithCommissionRate {
                validator: test_validators[0].data.clone(),
                validator_commission_percentage: 10,
                join_during_genesis: true,
            },
            delegator_addresses: vec![pbo_account01, pbo_account02, pbo_account03],
            delegator_stakes: vec![
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
            ],
        },
        multisig_admin: multisig_account01,
        unlock_schedule_numerators: vec![],
        unlock_schedule_denominator: 0,
        unlock_startup_time_from_now: 0,
        unlock_period_duration: 0,
    };

    let pbo_config_val1 = PboDelegatorConfiguration {
        delegator_config: DelegatorConfiguration {
            owner_address: supra_foundation,
            delegation_pool_creation_seed: vec![1_u8],
            validator: ValidatorWithCommissionRate {
                validator: test_validators[1].data.clone(),
                validator_commission_percentage: 10,
                join_during_genesis: true,
            },
            delegator_addresses: vec![pbo_account11, pbo_account12, pbo_account13],
            delegator_stakes: vec![
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
            ],
        },
        multisig_admin: multisig_account02,
        unlock_schedule_numerators: vec![],
        unlock_schedule_denominator: 0,
        unlock_startup_time_from_now: 0,
        unlock_period_duration: 0,
    };

    let pbo_config_val2 = PboDelegatorConfiguration {
        delegator_config: DelegatorConfiguration {
            owner_address: supra_foundation,
            delegation_pool_creation_seed: vec![2_u8],
            validator: ValidatorWithCommissionRate {
                validator: test_validators[2].data.clone(),
                validator_commission_percentage: 10,
                join_during_genesis: true,
            },
            delegator_addresses: vec![pbo_account21, pbo_account22, pbo_account13],
            delegator_stakes: vec![
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
            ],
        },
        multisig_admin: multisig_account03,
        unlock_schedule_numerators: vec![],
        unlock_schedule_denominator: 0,
        unlock_startup_time_from_now: 0,
        unlock_period_duration: 0,
    };

    let pbo_config_val3 = PboDelegatorConfiguration {
        delegator_config: DelegatorConfiguration {
            owner_address: supra_foundation,
            delegation_pool_creation_seed: vec![3_u8],
            validator: ValidatorWithCommissionRate {
                validator: test_validators[3].data.clone(),
                validator_commission_percentage: 10,
                join_during_genesis: true,
            },
            delegator_addresses: vec![pbo_account31, pbo_account32, pbo_account33],
            delegator_stakes: vec![
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
            ],
        },
        multisig_admin: multisig_account04,
        unlock_schedule_numerators: vec![],
        unlock_schedule_denominator: 0,
        unlock_startup_time_from_now: 0,
        unlock_period_duration: 0,
    };

    let pbo_config_val4 = PboDelegatorConfiguration {
        delegator_config: DelegatorConfiguration {
            owner_address: supra_foundation,
            delegation_pool_creation_seed: vec![4_u8],
            validator: ValidatorWithCommissionRate {
                validator: test_validators[4].data.clone(),
                validator_commission_percentage: 10,
                join_during_genesis: true,
            },
            delegator_addresses: vec![pbo_account41, pbo_account42, pbo_account43],
            delegator_stakes: vec![
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
            ],
        },
        multisig_admin: multisig_account05,
        unlock_schedule_numerators: vec![],
        unlock_schedule_denominator: 0,
        unlock_startup_time_from_now: 0,
        unlock_period_duration: 0,
    };

    let pbo_config_val5 = PboDelegatorConfiguration {
        delegator_config: DelegatorConfiguration {
            owner_address: supra_foundation,
            delegation_pool_creation_seed: vec![5_u8],
            validator: ValidatorWithCommissionRate {
                validator: test_validators[5].data.clone(),
                validator_commission_percentage: 10,
                join_during_genesis: true,
            },
            delegator_addresses: vec![pbo_account51, pbo_account52, pbo_account53],
            delegator_stakes: vec![
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
            ],
        },
        multisig_admin: multisig_account06,
        unlock_schedule_numerators: vec![],
        unlock_schedule_denominator: 0,
        unlock_startup_time_from_now: 0,
        unlock_period_duration: 0,
    };

    let pbo_config_val6 = PboDelegatorConfiguration {
        delegator_config: DelegatorConfiguration {
            owner_address: supra_foundation,
            delegation_pool_creation_seed: vec![6_u8],
            validator: ValidatorWithCommissionRate {
                validator: test_validators[6].data.clone(),
                validator_commission_percentage: 10,
                join_during_genesis: true,
            },
            delegator_addresses: vec![pbo_account61, pbo_account62, pbo_account63],
            delegator_stakes: vec![
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
                PBO_DELEGATOR_STAKE,
            ],
        },
        multisig_admin: multisig_account07,
        unlock_schedule_numerators: vec![],
        unlock_schedule_denominator: 0,
        unlock_startup_time_from_now: 0,
        unlock_period_duration: 0,
    };

    let employee_vesting_config1 = VestingPoolsMap {
        admin_address: supra_foundation,
        vpool_locking_percentage: 100,
        vesting_numerators: vec![3, 3, 3, 3, 1],
        vesting_denominator: 100,
        withdrawal_address: supra_foundation,
        shareholders: vec![
            employee1, employee2, employee3, employee4, employee5, employee6, employee7, employee8,
            employee9,
        ],
        cliff_period_in_seconds: 0,
        period_duration_in_seconds: 94608000, // 3 years in seconds
    };

    let pbo_delegator_configs = vec![
        pbo_config_val0,
        pbo_config_val1,
        pbo_config_val2,
        pbo_config_val3,
        pbo_config_val4,
        pbo_config_val5,
        pbo_config_val6,
    ];

    let transaction = encode_supra_mainnet_genesis_transaction(
        &accounts,
        &[],
        None,
        &pbo_delegator_configs,
        0,
        &[employee_vesting_config1],
        &[],
        aptos_cached_packages::head_release_bundle(),
        ChainId::mainnet(),
        &mainnet_genesis_config(),
        b"test".to_vec(),
    );

    let direct_writeset = if let Transaction::GenesisTransaction(direct_writeset) = transaction {
        direct_writeset
    } else {
        panic!("Invalid GenesisTransaction");
    };

    let changeset = if let WriteSetPayload::Direct(changeset) = direct_writeset {
        changeset
    } else {
        panic!("Invalid WriteSetPayload");
    };

    let writeset = changeset.write_set().as_v0();

    print!("CHANGESET: {:?}", changeset.events());

    // let state_key =
    //     StateKey::access_path(ValidatorSet::access_path().expect("access path in test"));
    // let bytes = writeset
    //     .get(&state_key)
    //     .unwrap()
    //     .extract_raw_bytes()
    //     .unwrap();
    // let validator_set: ValidatorSet = bcs::from_bytes(&bytes).unwrap();
    // let validator_set_addresses = validator_set
    //     .active_validators
    //     .iter()
    //     .map(|v| v.account_address)
    //     .collect::<Vec<_>>();
    //
    // let zero_commission_validator_pool_address =
    //     account_address::default_stake_pool_address(account44, operator2);
    // let same_owner_validator_1_pool_address =
    //     account_address::default_stake_pool_address(account45, operator3);
    // let same_owner_validator_2_pool_address =
    //     account_address::default_stake_pool_address(account45, operator4);
    // let same_owner_validator_3_pool_address =
    //     account_address::default_stake_pool_address(account45, operator5);
    // let employee_1_pool_address =
    //     account_address::create_vesting_pool_address(admin0, operator0, 0, &[]);
    // let employee_2_pool_address =
    //     account_address::create_vesting_pool_address(admin1, operator1, 0, &[]);
    //
    // assert!(validator_set_addresses.contains(&zero_commission_validator_pool_address));
    // assert!(validator_set_addresses.contains(&employee_1_pool_address));
    // // This validator should not be in the genesis validator set as they specified
    // // join_during_genesis = false.
    // assert!(!validator_set_addresses.contains(&employee_2_pool_address));
    // assert!(validator_set_addresses.contains(&same_owner_validator_1_pool_address));
    // assert!(validator_set_addresses.contains(&same_owner_validator_2_pool_address));
    // // This validator should not be in the genesis validator set as they specified
    // // join_during_genesis = false.
    // assert!(!validator_set_addresses.contains(&same_owner_validator_3_pool_address));
}
