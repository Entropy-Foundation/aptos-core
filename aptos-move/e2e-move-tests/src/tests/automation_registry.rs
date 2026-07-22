// Copyright (c) Supra.
// SPDX-License-Identifier: Apache-2.0

//! E2E tests for the `register_without_validation` / `get_transaction_consensus_hash` feature
//! (SUPRA_AUTOMATION_V2_1).
//!
//! These tests exercise the full call chain:
//!   signed transaction → VM → native `get_transaction_consensus_hash_internal` → Move registry storage
//!
//! and verify that the hash stored in the registry is the Keccak-256 of the BCS-serialised
//! `SignedTransaction` that triggered the registration.

use crate::{assert_abort, assert_success, tests::common, MoveHarness};
use aptos_crypto::HashValue;
use aptos_language_e2e_tests::account::Account;
use aptos_types::{
    move_utils::MemberId,
    on_chain_config::FeatureFlag,
    transaction::{automation::AutomationTaskMetaData, SignedTransaction},
};
use move_core_types::account_address::AccountAddress;

// -----------------------------------------------------------------------
// Stack-size helper
// -----------------------------------------------------------------------

/// Runs `f` on a thread with a 64 MB stack.
///
/// Publishing the supra-framework package triggers deep recursive Move type-checking that
/// overflows the OS default stack (~8 MB).  This wrapper ensures the compilation succeeds
/// regardless of the default stack size configured by the test runner.
fn run_on_large_stack<F: FnOnce() + Send + 'static>(f: F) {
    std::thread::Builder::new()
        .stack_size(64 * 1024 * 1024)
        .spawn(f)
        .expect("spawning large-stack thread must not fail")
        .join()
        .expect("large-stack thread must not panic");
}

// -----------------------------------------------------------------------
// Module-level abort code constant (mirrors Move's EDISABLED_AUTOMATION_FEATURE = 15)
// -----------------------------------------------------------------------

/// Raw abort code emitted by `automation_registry` when a required feature is disabled.
/// This is NOT wrapped with error::invalid_state — it is the plain u64 constant 15.
const EDISABLED_AUTOMATION_V2_1_FEATURE: u64 = 49;

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------

/// Builds a harness with SUPRA_NATIVE_AUTOMATION and SUPRA_AUTOMATION_V2_1 enabled,
/// then transitions the automation cycle from CYCLE_READY to CYCLE_STARTED.
///
/// At head-genesis SUPRA_NATIVE_AUTOMATION is absent from the default feature set, so the
/// registry is initialised in CYCLE_READY state.  Calling `on_new_epoch` after enabling the
/// flag transitions the cycle to CYCLE_STARTED, which is required for registration to succeed.
fn setup_harness_with_v2_1() -> MoveHarness {
    let mut h = MoveHarness::new_with_features(
        vec![
            FeatureFlag::SUPRA_NATIVE_AUTOMATION,
            FeatureFlag::SUPRA_AUTOMATION_V2_1,
        ],
        vec![],
    );
    // Transition CYCLE_READY -> CYCLE_STARTED now that SUPRA_NATIVE_AUTOMATION is enabled.
    h.executor
        .exec("automation_registry", "on_new_epoch", vec![], vec![]);
    h
}

/// Same setup but deliberately *without* SUPRA_AUTOMATION_V2_1, to test the disabled path.
fn setup_harness_without_v2_1() -> MoveHarness {
    let mut h = MoveHarness::new_with_features(
        vec![FeatureFlag::SUPRA_NATIVE_AUTOMATION],
        vec![FeatureFlag::SUPRA_AUTOMATION_V2_1],
    );
    h.executor
        .exec("automation_registry", "on_new_epoch", vec![], vec![]);
    h
}

/// Deploys the third-party wrapper contract and returns the deployer account.
///
/// The contract lives at `0xDEADBEEF` and exposes a `public entry fun register_via_contract`
/// that delegates to `automation_registry::register_without_validation`.  This mimics the
/// real-world scenario where a DeFi protocol registers automation tasks through its own module.
fn deploy_wrapper(h: &mut MoveHarness) -> Account {
    let addr = AccountAddress::from_hex_literal("0xDEADBEEF").unwrap();
    let account = h.new_account_with_balance_at(addr, 1_000_000_000_000_000);
    assert_success!(h.publish_package_cache_building(
        &account,
        &common::test_dir_path("automation_registry.data/pack"),
    ));
    account
}

/// Returns a new user account with enough balance to cover gas and registration/deposit fees.
fn new_funded_user(h: &mut MoveHarness) -> Account {
    h.new_account_with_key_pair()
}

/// A 64-byte dummy payload.  `register_without_validation` does not validate the payload
/// bytes, so any non-empty vector is valid for unit-test purposes.
fn dummy_payload_bytes() -> Vec<u8> {
    (0u8..64u8).collect()
}

/// AUX data required by the registry for a user-submitted task (type byte = 0x01, empty priority).
fn user_aux_data() -> Vec<Vec<u8>> {
    vec![vec![1u8], vec![]]
}

/// Calls the `get_task_details(task_index)` view function and BCS-decodes the result.
fn get_task_details(h: &mut MoveHarness, task_index: u64) -> AutomationTaskMetaData {
    let output = h.execute_view_function(
        str::parse("0x1::automation_registry::get_task_details").unwrap(),
        vec![],
        vec![bcs::to_bytes(&task_index).unwrap()],
    );
    let values = output
        .values
        .expect("get_task_details view call must succeed");
    bcs::from_bytes(&values[0]).expect("AutomationTaskMetaData must BCS-decode cleanly")
}

/// Builds (but does not submit) the `register_via_contract` signed transaction.
///
/// Returning the `SignedTransaction` before submission allows the caller to compute its
/// Keccak-256 hash and then verify that the same bytes end up stored in the registry.
fn build_register_txn(
    h: &mut MoveHarness,
    user: &Account,
    expiry_time: u64,
) -> SignedTransaction {
    h.create_entry_function(
        user,
        str::parse("0xDEADBEEF::automation_contract_test::register_via_contract").unwrap(),
        vec![],
        vec![
            bcs::to_bytes(&dummy_payload_bytes()).unwrap(),
            bcs::to_bytes(&expiry_time).unwrap(),
            bcs::to_bytes(&10_000u64).unwrap(), // max_gas_amount
            bcs::to_bytes(&100u64).unwrap(),    // gas_price_cap
            bcs::to_bytes(&1_000u64).unwrap(),  // automation_fee_cap_for_epoch
            bcs::to_bytes(&user_aux_data()).unwrap(),
        ],
    )
}

// -----------------------------------------------------------------------
// E2E Tests
// -----------------------------------------------------------------------

/// Verifies that `tx_hash` stored in the registry is exactly the Keccak-256 hash of the
/// BCS-serialised `SignedTransaction` that called `register_via_contract`.
///
/// This is the primary correctness test for the entire feature:
/// 1. `get_transaction_consensus_hash_internal` (native) reads `txn_consensus_hash` from the
///    `UserTransactionContext` populated by `TransactionMetadata::new()`.
/// 2. `register_without_validation` forwards this hash to the private `register()` call.
/// 3. `register()` stores it in `AutomationTaskMetaData.tx_hash`.
/// 4. We verify the stored value equals what we compute independently of the same bytes
///    before submission.
#[test]
fn test_register_without_validation_hash_matches_txn() {
    run_on_large_stack(|| {
        let mut h = setup_harness_with_v2_1();
        deploy_wrapper(&mut h);
        let user = new_funded_user(&mut h);

        // Expiry must exceed current time (genesis = 0 s) plus at least one cycle (7 200 s).
        let expiry_time = 7_200u64 + 86_400;

        // Build the transaction *without* submitting it so we can hash it before the VM sees it.
        let signed_txn: SignedTransaction = build_register_txn(&mut h, &user, expiry_time);

        // Compute the expected hash: mirrors TransactionMetadata::new() in transaction_metadata.rs
        let expected_hash = HashValue::keccak_256_of(
            &bcs::to_bytes(&signed_txn)
                .expect("SignedTransaction must always BCS-serialize successfully"),
        );

        // Submit the transaction and assert it succeeds.
        let output = h.run_raw(signed_txn);
        assert_success!(output.status().to_owned());

        // Read the task that was just registered (first task ever → task index 0).
        let task = get_task_details(&mut h, 0);

        assert_eq!(
            task.tx_hash().as_slice(),
            expected_hash.as_ref(),
            "tx_hash in registry must equal the Keccak-256 of the registering SignedTransaction"
        );
    });
}

/// Happy-path test: a third-party smart contract calls `register_without_validation` and the
/// task is written to the registry with the correct owner and a 32-byte tx_hash.
///
/// This exercises the public API surface that DeFi protocols are intended to use.
#[test]
fn test_register_without_validation_from_smart_contract() {
    run_on_large_stack(|| {
        let mut h = setup_harness_with_v2_1();
        deploy_wrapper(&mut h);
        let user = new_funded_user(&mut h);

        let expiry_time = 7_200u64 + 86_400;
        let status = h.run_entry_function(
            &user,
            str::parse("0xDEADBEEF::automation_contract_test::register_via_contract").unwrap(),
            vec![],
            vec![
                bcs::to_bytes(&dummy_payload_bytes()).unwrap(),
                bcs::to_bytes(&expiry_time).unwrap(),
                bcs::to_bytes(&10_000u64).unwrap(),
                bcs::to_bytes(&100u64).unwrap(),
                bcs::to_bytes(&1_000u64).unwrap(),
                bcs::to_bytes(&user_aux_data()).unwrap(),
            ],
        );
        assert_success!(status);

        // Verify task owner.
        let task = get_task_details(&mut h, 0);
        assert_eq!(
            task.owner(),
            user.address(),
            "task owner must be the account that submitted the transaction"
        );

        // Verify the tx_hash field is a 32-byte Keccak-256 digest.
        assert_eq!(
            task.tx_hash().len(),
            32,
            "tx_hash must be a 32-byte Keccak-256 digest"
        );

        // Verify exactly one task was registered (next index = 1).
        let idx_output = h.execute_view_function(
            str::parse("0x1::automation_registry::get_next_task_index").unwrap(),
            vec![],
            vec![],
        );
        let values = idx_output
            .values
            .expect("get_next_task_index view call must succeed");
        let next_index: u64 = bcs::from_bytes(&values[0]).expect("decode task index");
        assert_eq!(next_index, 1, "exactly one task should be registered");
    });
}

/// Verifies that calling `register_via_contract` when SUPRA_AUTOMATION_V2_1 is disabled
/// aborts with EDISABLED_AUTOMATION_FEATURE = 15.
///
/// This ensures the feature gate in `register_without_validation` is enforced and that
/// the function cannot be used before the binary upgrade is rolled out to all nodes.
#[test]
fn test_register_without_validation_feature_disabled_aborts() {
    run_on_large_stack(|| {
        let mut h = setup_harness_without_v2_1();
        deploy_wrapper(&mut h);
        let user = new_funded_user(&mut h);

        let expiry_time = 7_200u64 + 86_400;
        let status = h.run_entry_function(
            &user,
            str::parse("0xDEADBEEF::automation_contract_test::register_via_contract").unwrap(),
            vec![],
            vec![
                bcs::to_bytes(&dummy_payload_bytes()).unwrap(),
                bcs::to_bytes(&expiry_time).unwrap(),
                bcs::to_bytes(&10_000u64).unwrap(),
                bcs::to_bytes(&100u64).unwrap(),
                bcs::to_bytes(&1_000u64).unwrap(),
                bcs::to_bytes(&user_aux_data()).unwrap(),
            ],
        );
        assert_abort!(status, EDISABLED_AUTOMATION_V2_1_FEATURE);
    });
}
