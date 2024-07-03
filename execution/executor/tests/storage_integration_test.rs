// Copyright © Aptos Foundation
// Parts of the project are originally copyright © Meta Platforms, Inc.
// SPDX-License-Identifier: Apache-2.0

use aptos_cached_packages::aptos_stdlib;
use aptos_crypto::{hash::CryptoHash, PrivateKey};
use aptos_executor_test_helpers::{
    gen_block_id, gen_ledger_info_with_sigs, get_test_signed_transaction,
    integration_test_impl::{
        create_db_and_executor, test_execution_with_storage_impl, verify_committed_txn_status,
    },
};
use aptos_executor_types::BlockExecutorTrait;
use aptos_storage_interface::state_view::DbStateViewAtVersion;
use aptos_types::{
    access_path::AccessPath,
    account_config::{aptos_test_root_address, AccountResource, CORE_CODE_ADDRESS},
    account_view::AccountView,
    block_metadata::BlockMetadata,
    state_store::{account_with_state_view::AsAccountWithStateView, state_key::StateKey},
    test_helpers::transaction_test_helpers::TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
    transaction::{
        signature_verified_transaction::into_signature_verified_block, Transaction, WriteSetPayload,
    },
    trusted_state::TrustedState,
    validator_signer::ValidatorSigner,
};
use move_core_types::move_resource::MoveStructType;

#[test]
fn test_genesis() {
    let path = aptos_temppath::TempPath::new();
    path.create_as_dir().unwrap();
    let genesis = aptos_vm_genesis::test_genesis_transaction();
    let (_, db, _executor, waypoint) = create_db_and_executor(path.path(), &genesis, false);

    let trusted_state = TrustedState::from_epoch_waypoint(waypoint);
    let state_proof = db.reader.get_state_proof(trusted_state.version()).unwrap();

    trusted_state.verify_and_ratchet(&state_proof).unwrap();
    let li = state_proof.latest_ledger_info();
    assert_eq!(li.version(), 0);

    let account_resource_path = StateKey::access_path(AccessPath::new(
        CORE_CODE_ADDRESS,
        AccountResource::struct_tag().access_vector(),
    ));
    let (aptos_framework_account_resource, state_proof) = db
        .reader
        .get_state_value_with_proof_by_version(&account_resource_path, 0)
        .unwrap();
    let latest_version = db.reader.get_latest_version().unwrap();
    assert_eq!(latest_version, 0);
    let txn_info = db
        .reader
        .get_transaction_info_iterator(0, 1)
        .unwrap()
        .next()
        .unwrap()
        .unwrap();
    state_proof
        .verify(
            txn_info.state_checkpoint_hash().unwrap(),
            account_resource_path.hash(),
            aptos_framework_account_resource.as_ref(),
        )
        .unwrap();
}

#[test]
#[cfg_attr(feature = "consensus-only-perf-test", ignore)]
fn test_reconfiguration() {
    // When executing a transaction emits a validator set change,
    // storage should propagate the new validator set

    let path = aptos_temppath::TempPath::new();
    path.create_as_dir().unwrap();
    let (genesis, validators) = aptos_vm_genesis::test_genesis_change_set_and_validators(Some(1));
    let genesis_key = &aptos_vm_genesis::GENESIS_KEYPAIR.0;
    let genesis_txn = Transaction::GenesisTransaction(WriteSetPayload::Direct(genesis));
    let (_, db, executor, _waypoint) = create_db_and_executor(path.path(), &genesis_txn, false);
    let parent_block_id = executor.committed_block_id();
    let signer = ValidatorSigner::new(
        validators[0].data.owner_address,
        validators[0].consensus_key.clone(),
    );
    let validator_account = signer.author();

    // test the current keys in the validator's account equals to the key in the validator set
    let state_proof = db.reader.get_state_proof(0).unwrap();
    let current_version = state_proof.latest_ledger_info().version();
    let db_state_view = db
        .reader
        .state_view_at_version(Some(current_version))
        .unwrap();
    let validator_account_state_view = db_state_view.as_account_with_state_view(&validator_account);
    let aptos_framework_account_state_view =
        db_state_view.as_account_with_state_view(&CORE_CODE_ADDRESS);

    assert_eq!(
        aptos_framework_account_state_view
            .get_validator_set()
            .unwrap()
            .unwrap()
            .payload()
            .next()
            .unwrap()
            .consensus_public_key(),
        &validator_account_state_view
            .get_validator_config_resource()
            .unwrap()
            .unwrap()
            .consensus_public_key
    );

    // txn1 = give the validator some money so they can send a tx
    let txn1 = get_test_signed_transaction(
        aptos_test_root_address(),
        /* sequence_number = */ 0,
        genesis_key.clone(),
        genesis_key.public_key(),
        Some(aptos_stdlib::supra_coin_mint(validator_account, 1_000_000)),
    );
    // txn2 = a dummy block prologue to bump the timer.
    let txn2 = Transaction::BlockMetadata(BlockMetadata::new(
        gen_block_id(1),
        0,
        1,
        validator_account,
        vec![0],
        vec![],
        300000001,
    ));

    // txn3 = set the aptos version
    let txn3 = get_test_signed_transaction(
        aptos_test_root_address(),
        /* sequence_number = */ 1,
        genesis_key.clone(),
        genesis_key.public_key(),
        Some(aptos_stdlib::version_set_version(42)),
    );

    let txn_block = into_signature_verified_block(vec![txn1, txn2, txn3]);
    let block_id = gen_block_id(1);
    let vm_output = executor
        .execute_block(
            (block_id, txn_block.clone()).into(),
            parent_block_id,
            TEST_BLOCK_EXECUTOR_ONCHAIN_CONFIG,
        )
        .unwrap();

    // Make sure the execution result sees the reconfiguration
    assert!(
        vm_output.has_reconfiguration(),
        "StateComputeResult does not see a reconfiguration"
    );
    let ledger_info_with_sigs = gen_ledger_info_with_sigs(1, &vm_output, block_id, &[signer]);
    executor
        .commit_blocks(vec![block_id], ledger_info_with_sigs)
        .unwrap();

    let state_proof = db.reader.get_state_proof(0).unwrap();
    let latest_li = state_proof.latest_ledger_info();
    let current_version = latest_li.version();

    let t3 = db
        .reader
        .get_transaction_by_version(3, current_version, /*fetch_events=*/ true)
        .unwrap();
    verify_committed_txn_status(latest_li, &t3, &txn_block[2]).unwrap();

    let db_state_view = db
        .reader
        .state_view_at_version(Some(current_version))
        .unwrap();

    let aptos_framework_account_state_view2 =
        db_state_view.as_account_with_state_view(&CORE_CODE_ADDRESS);

    assert_eq!(
        aptos_framework_account_state_view2
            .get_version()
            .unwrap()
            .unwrap()
            .major,
        42
    );
}

#[test]
#[cfg_attr(feature = "consensus-only-perf-test", ignore)]
fn test_execution_with_storage() {
    test_execution_with_storage_impl();
}
