// Copyright (c) 2024 Supra.
// SPDX-License-Identifier: Apache-2.0

use crate::tests::automation_registration::AutomationRegistrationTestContext;
use aptos_cached_packages::aptos_framework_sdk_builder;
use aptos_crypto::HashValue;
use aptos_types::{
    chain_id::ChainId,
    on_chain_config::{AutomationCycleState, FeatureFlag},
    transaction::{
        automated_transaction::{
            AutomatedTransaction, AutomatedTransactionBuilder, AutomatedTransactionDescriptor,
            BuilderResult,
        },
        automation::AutomationTaskType,
        EntryFunction, ExecutionStatus, Transaction, TransactionStatus,
    },
};
use move_core_types::{
    account_address::AccountAddress, identifier::Identifier, language_storage::ModuleId,
    vm_status::StatusCode,
};

// ─────────────────────────────────────────────────────────────────────────────
// Shared test constants
// ─────────────────────────────────────────────────────────────────────────────

/// Number of seconds by which a test must advance the chain clock to trigger a
/// cycle transition (CYCLE_STARTED → CYCLE_FINISHED).
const CYCLE_ADVANCE_SECS: u64 = 1200;

/// Automation-fee cap (in quants) used when registering test tasks.
/// Large enough to satisfy the estimated-fee assertion inside `register`.
const AUTOMATION_FEE_CAP: u64 = 100_000;

/// Max-gas amount and gas-price cap used for test tasks.  Small enough that
/// `gas_price_cap × max_gas_amount` (10 000) is well within the test sender's
/// initial balance of 100 billion tokens, so the gas-balance prologue check
/// passes even after deducting registration fees.
const TASK_MAX_GAS_AMOUNT: u64 = 1_000;
const TASK_GAS_PRICE_CAP: u64 = 100;

/// A canonical 32-byte dummy transaction hash used as the `tx_hash` field
/// when registering tasks via the bypass helper.  The prologue does not check
/// this field, so any 32-byte value is valid.
const DUMMY_TX_HASH: [u8; 32] = [42u8; 32];

/// Auxiliary data for a User-Submitted Task (UST) with no explicit priority.
/// Format required by `check_and_validate_aux_data` in `automation_registry.move`:
///   - element 0: `[1u8]`  → task type byte (1 = UST)
///   - element 1: `[]`      → empty priority → registry auto-assigns task_index
fn ust_aux_data() -> Vec<Vec<u8>> {
    // UST type byte = 1 (mirrors `const UST: u8 = 1` in automation_registry.move)
    vec![vec![1u8], vec![]]
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build an EntryFunction that references a module which does NOT exist
// in the framework.
//
// The resulting BCS bytes are well-formed (`bcs::from_bytes::<EntryFunction>`
// succeeds) but when the automated-transaction processor calls
// `load_and_validate_entry_function` the VM cannot find the module and returns
// `StatusCode::INVALID_AUTOMATION_INNER_PAYLOAD`.
// ─────────────────────────────────────────────────────────────────────────────
fn make_nonexistent_entry_function() -> EntryFunction {
    EntryFunction::new(
        ModuleId::new(
            // 0x0 never has user modules deployed; "phantom_automation_mod" is
            // deliberately absent from the genesis framework.
            AccountAddress::ZERO,
            Identifier::new("phantom_automation_mod").expect("identifier must be valid"),
        ),
        Identifier::new("phantom_fn").expect("identifier must be valid"),
        vec![], // no type arguments
        vec![], // no runtime arguments (function signature is irrelevant — it doesn't exist)
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: activate the first registered task (task index 0).
//
// Steps:
//   1. Advance the chain clock by CYCLE_ADVANCE_SECS to move the cycle into
//      CYCLE_FINISHED state.
//   2. Submit the registry-action transaction that transitions the cycle back
//      to CYCLE_STARTED and marks task 0 as ACTIVE.
// ─────────────────────────────────────────────────────────────────────────────
fn activate_first_task(ctx: &mut AutomationRegistrationTestContext) {
    ctx.advance_chain_time_in_secs(CYCLE_ADVANCE_SECS);

    let cycle_info = ctx.get_cycle_info();
    assert_eq!(
        cycle_info.state,
        AutomationCycleState::FINISHED,
        "cycle must be FINISHED before it can be restarted"
    );

    let registry_action =
        ctx.create_automation_registry_transaction(0, cycle_info.index + 1, 1, vec![0]);
    ctx.execute_and_apply_transaction(Transaction::AutomationRegistryTransaction(registry_action));

    let cycle_info = ctx.get_cycle_info();
    assert_eq!(
        cycle_info.state,
        AutomationCycleState::STARTED,
        "cycle must be STARTED after the registry action"
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: build an AutomatedTransactionDescriptor for task 0 using the given
// entry function and gas-unit price.
//
// The `entry_fn` parameter is decoupled from the registry's `payload_tx` bytes
// intentionally: this lets tests inject an invalid entry function into the
// automated transaction even when the stored bytes might differ, or use the
// canonical entry function fetched from the registry for positive-path tests.
// ─────────────────────────────────────────────────────────────────────────────
fn build_automated_txn(
    ctx: &mut AutomationRegistrationTestContext,
    task_index: u64,
    entry_fn: EntryFunction,
    gas_unit_price: u64,
    expiry_time: u64,
) -> AutomatedTransactionDescriptor {
    // The authenticator is the stored tx_hash from the registry task.  It is
    // used only to populate TransactionMetadata.authentication_key; the prologue
    // does not validate it, so using the same DUMMY_TX_HASH works here.
    let authenticator = HashValue::new(DUMMY_TX_HASH);
    let sender_address = ctx.sender_account_address();

    let result = AutomatedTransactionBuilder::default()
        .with_sender(sender_address)
        .with_sequence_number(task_index)
        .with_entry_function(entry_fn)
        .with_max_gas_amount(TASK_MAX_GAS_AMOUNT)
        .with_gas_price_cap(TASK_GAS_PRICE_CAP)
        .with_expiration_timestamp_secs(expiry_time)
        .with_authenticator(authenticator)
        // Priority must match the auto-assigned value (= task_index) so that
        // the AutomatedTransactionDescriptor is valid.
        .with_task_priority(task_index)
        .with_task_type(AutomationTaskType::User)
        .with_chain_id(ChainId::test())
        .with_block_height(1)
        .with_gas_unit_price(gas_unit_price)
        .build();

    match result {
        BuilderResult::Success(txn) => txn,
        other => panic!("Expected successful automated-transaction build, got: {other:?}"),
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Existing tests (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

#[test]
fn check_unregistered_automated_transaction() {
    let mut test_context = AutomationRegistrationTestContext::new();
    let dest_account = test_context.new_account_data(0, 0);
    let payload = aptos_framework_sdk_builder::supra_coin_mint(dest_account.address().clone(), 100);
    let sequence_number = 0;

    let raw_transaction = test_context
        .sender_account_data()
        .account()
        .transaction()
        .payload(payload)
        .sequence_number(sequence_number)
        .ttl(4000)
        .raw();
    let parent_has = HashValue::new([42; HashValue::LENGTH]);
    let automated_txn = AutomatedTransaction::new(raw_transaction.clone(), parent_has, 1);
    let result =
        test_context.execute_tagged_transaction(Transaction::AutomatedTransaction(automated_txn));
    AutomationRegistrationTestContext::check_discarded_output(
        result,
        StatusCode::NO_ACTIVE_AUTOMATED_TASK,
    );
}

#[test]
fn check_expired_automated_transaction() {
    let mut test_context = AutomationRegistrationTestContext::new();
    test_context.advance_chain_time_in_secs(2500);
    let dest_account = test_context.new_account_data(0, 0);
    let payload = aptos_framework_sdk_builder::supra_coin_mint(dest_account.address().clone(), 100);
    let sequence_number = 0;

    let raw_transaction = test_context
        .sender_account_data()
        .account()
        .transaction()
        .payload(payload)
        .sequence_number(sequence_number)
        .ttl(1000)
        .raw();

    let parent_hash = HashValue::new([42; HashValue::LENGTH]);
    let automated_txn = AutomatedTransaction::new(raw_transaction.clone(), parent_hash, 1);
    let result =
        test_context.execute_tagged_transaction(Transaction::AutomatedTransaction(automated_txn));
    AutomationRegistrationTestContext::check_discarded_output(
        result,
        StatusCode::TRANSACTION_EXPIRED,
    );
}

#[test]
fn check_automated_transaction_with_insufficient_balance() {
    let mut test_context = AutomationRegistrationTestContext::new();
    let dest_account = test_context.new_account_data(0, 0);
    let payload =
        aptos_framework_sdk_builder::supra_account_transfer(dest_account.address().clone(), 100);
    let sequence_number = 0;

    let raw_transaction = test_context
        .sender_account_data()
        .account()
        .transaction()
        .payload(payload)
        .sequence_number(sequence_number)
        .gas_unit_price(1_000_000)
        .max_gas_amount(1_000_000)
        .ttl(1000)
        .raw();

    let parent_hash = HashValue::new([42; HashValue::LENGTH]);
    let automated_txn = AutomatedTransaction::new(raw_transaction.clone(), parent_hash, 1);
    let result =
        test_context.execute_tagged_transaction(Transaction::AutomatedTransaction(automated_txn));
    AutomationRegistrationTestContext::check_discarded_output(
        result,
        StatusCode::INSUFFICIENT_BALANCE_FOR_TRANSACTION_FEE,
    );
}

#[test]
fn check_automated_transaction_successful_execution() {
    let mut test_context = AutomationRegistrationTestContext::new();
    test_context.set_supra_native_automation(true);
    let dest_account = test_context.new_account_data(1_000_000, 0);
    let payload =
        aptos_framework_sdk_builder::supra_account_transfer(dest_account.address().clone(), 100);

    // Register automation task using the module-level shared constants so that
    // the gas parameters here stay in sync with the new bypass-registration tests.
    let inner_entry_function = payload.clone().into_entry_function();
    let expiration_time = test_context.chain_time_now() + 8_000;
    let automation_txn = test_context.create_automation_txn(
        0,
        inner_entry_function.clone(),
        expiration_time,
        TASK_GAS_PRICE_CAP,  // gas_price_cap = 100
        TASK_MAX_GAS_AMOUNT, // max_gas_amount = 1 000
        AUTOMATION_FEE_CAP,  // automation_fee_cap_for_epoch = 100 000
    );

    let output = test_context.execute_and_apply(automation_txn);
    assert_eq!(
        output.status(),
        &TransactionStatus::Keep(ExecutionStatus::Success),
        "{output:?}"
    );
    let next_task_index = test_context.get_next_task_index_from_registry();
    assert_eq!(next_task_index, 1);
    let automated_task_details = test_context.get_task_details(next_task_index - 1);
    let automated_txn_builder = AutomatedTransactionBuilder::try_from(automated_task_details)
        .expect("Successful builder creation");
    let maybe_automated_txn = automated_txn_builder
        .clone()
        .with_chain_id(ChainId::test())
        .with_block_height(1)
        .with_gas_unit_price(TASK_GAS_PRICE_CAP)
        .build();
    let BuilderResult::Success(automated_txn) = maybe_automated_txn else {
        panic!("Automated transaction should successfully build: {maybe_automated_txn:?}")
    };

    // The task is PENDING — execution must be rejected before the first cycle starts.
    let result = test_context.execute_tagged_transaction(automated_txn.clone().into());
    AutomationRegistrationTestContext::check_discarded_output(
        result,
        StatusCode::NO_ACTIVE_AUTOMATED_TASK,
    );

    // Advance the chain clock and run the registry action to transition the task
    // from PENDING → ACTIVE and the cycle from FINISHED → STARTED.
    // `activate_first_task` encapsulates the advance + registry-action + state
    // assertions that are identical to the setup in the bypass-registration tests.
    activate_first_task(&mut test_context);

    // Execute automated transaction; task is now ACTIVE so it should succeed.
    let sender_address = test_context.sender_account_address();
    let sender_seq_num = test_context.account_sequence_number(sender_address);
    let output = test_context.execute_and_apply_transaction(automated_txn.clone().into());
    assert_eq!(
        output.status(),
        &TransactionStatus::Keep(ExecutionStatus::Success),
        "{output:?}"
    );
    let dest_account_balance = test_context.account_balance(dest_account.address().clone());
    assert_eq!(dest_account_balance, 1000_100);
    // Automated transactions must NOT increment the owner's sequence number.
    assert_eq!(
        sender_seq_num,
        test_context.account_sequence_number(sender_address)
    );

    // Submitting the same automated transaction with the wrong sender must fail:
    // the prologue's `has_sender_active_task_with_id_and_type` check uses the
    // sender address as part of the task-lookup key.
    let maybe_automated_txn = automated_txn_builder
        .with_sender(*dest_account.address())
        .with_chain_id(ChainId::test())
        .with_block_height(1)
        .with_gas_unit_price(TASK_GAS_PRICE_CAP)
        .build();
    let BuilderResult::Success(automated_txn) = maybe_automated_txn else {
        panic!("Automated transaction should successfully build")
    };
    let result = test_context.execute_tagged_transaction(automated_txn.clone().into());
    AutomationRegistrationTestContext::check_discarded_output(
        result,
        StatusCode::NO_ACTIVE_AUTOMATED_TASK,
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests for tasks registered *without* payload validation
// (simulates the `register_without_validation` / SUPRA_AUTOMATION_V2_1 path)
// ─────────────────────────────────────────────────────────────────────────────

/// **Positive case — V2_1 enabled, valid payload, registered without validation.**
///
/// A task whose `payload_tx` bytes encode a *valid* EntryFunction (one that
/// exists in the framework and whose arguments match) is registered through the
/// bypass helper (simulating `register_without_validation`).  Because the entry
/// function is valid, the automated-transaction processor's Phase-1 load succeeds
/// and the function body runs normally, producing a `Keep(Success)` output.
///
/// This establishes the baseline: `SUPRA_AUTOMATION_V2_1` being enabled does not
/// break execution of valid tasks, it only changes the behaviour for *invalid*
/// ones (see the negative cases below).
#[test]
fn check_valid_payload_task_registered_without_validation_executes_successfully() {
    let mut test_context = AutomationRegistrationTestContext::new();

    // SUPRA_AUTOMATION_V2_1 is in the default feature set (see aptos_features.rs).
    // Enable SUPRA_NATIVE_AUTOMATION to transition the registry from CYCLE_READY
    // to CYCLE_STARTED (required for task registration and activation).
    test_context.set_supra_native_automation(true);

    let dest_account = test_context.new_account_data(0, 0);
    let inner_fn =
        aptos_framework_sdk_builder::supra_account_transfer(dest_account.address().clone(), 100)
            .into_entry_function();

    // BCS-encode the valid EntryFunction — this is what the registry stores as
    // `payload_tx` in both the validated and the non-validated registration paths.
    let valid_payload_bytes =
        bcs::to_bytes(&inner_fn).expect("EntryFunction must BCS-serialize successfully");

    let expiry_time = test_context.chain_time_now() + 8_000;
    let sender_address = test_context.sender_account_address();

    // Register via exec bypass (skips native-layer BCS/type-check validation).
    // The Move `register` function still runs and charges the registration fee.
    test_context.register_task_bypassing_native_validation(
        sender_address,
        valid_payload_bytes,
        expiry_time,
        TASK_MAX_GAS_AMOUNT,
        TASK_GAS_PRICE_CAP,
        AUTOMATION_FEE_CAP,
        DUMMY_TX_HASH.to_vec(),
        ust_aux_data(),
    );

    assert_eq!(
        test_context.get_next_task_index_from_registry(),
        1,
        "exactly one task should now be in the registry"
    );

    // Advance the cycle and make the task ACTIVE.
    activate_first_task(&mut test_context);

    let automated_txn = build_automated_txn(
        &mut test_context,
        0,        // task_index
        inner_fn, // the same valid entry function
        1,        // gas_unit_price (≤ TASK_GAS_PRICE_CAP)
        expiry_time,
    );

    // The entry function exists and its arguments match — execution must succeed.
    let output = test_context.execute_and_apply_transaction(automated_txn.into());
    assert_eq!(
        output.status(),
        &TransactionStatus::Keep(ExecutionStatus::Success),
        "valid payload registered without validation must execute successfully: {output:?}"
    );

    // Verify the transfer actually happened.
    let dest_balance = test_context.account_balance(*dest_account.address());
    assert_eq!(
        dest_balance, 100,
        "100 tokens should have been transferred to dest_account"
    );
}

/// **Negative case — V2_1 enabled, invalid inner payload, registered without validation.**
///
/// When `SUPRA_AUTOMATION_V2_1` is enabled, a task whose `payload_tx` bytes
/// point to a non-existent module is *discarded* at execution time without
/// charging any gas.  The special path in `execute_transaction_impl` catches
/// `INVALID_AUTOMATION_INNER_PAYLOAD` and returns `discarded_output(...)` instead
/// of running the failure epilogue.
///
/// # Rationale
/// Tasks registered through `register_without_validation` skip the BCS/entry-
/// function check performed by the normal registration flow.  A malformed payload
/// that was never verified at registration time should not drain the task owner's
/// account with repeated gas charges if it turns out to be permanently invalid.
/// The `SUPRA_AUTOMATION_V2_1` discard path is the mechanism that prevents this.
#[test]
fn check_invalid_inner_payload_is_discarded_when_v2_1_enabled() {
    let mut test_context = AutomationRegistrationTestContext::new();

    // SUPRA_AUTOMATION_V2_1 is enabled by default via default_features().
    // No explicit toggle needed.  SUPRA_NATIVE_AUTOMATION must be enabled
    // separately to start the registry cycle.
    test_context.set_supra_native_automation(true);

    // Build an EntryFunction that BCS-serialises successfully (so the payload
    // bytes are syntactically valid) but references a module that does not exist
    // at runtime.  `load_and_validate_entry_function` will fail with
    // INVALID_AUTOMATION_INNER_PAYLOAD when the processor tries to load it.
    let nonexistent_fn = make_nonexistent_entry_function();
    let invalid_payload_bytes = bcs::to_bytes(&nonexistent_fn)
        .expect("EntryFunction must BCS-serialize even if the module is absent at runtime");

    let expiry_time = test_context.chain_time_now() + 8_000;
    let sender_address = test_context.sender_account_address();

    // Register via exec bypass — the native validator is NOT called, so the
    // syntactically-valid-but-semantically-invalid payload is accepted.
    test_context.register_task_bypassing_native_validation(
        sender_address,
        invalid_payload_bytes,
        expiry_time,
        TASK_MAX_GAS_AMOUNT,
        TASK_GAS_PRICE_CAP,
        AUTOMATION_FEE_CAP,
        DUMMY_TX_HASH.to_vec(),
        ust_aux_data(),
    );

    assert_eq!(
        test_context.get_next_task_index_from_registry(),
        1,
        "exactly one task should be registered"
    );

    // Activate the task so the prologue's `has_sender_active_task_with_id_and_type`
    // check will pass.
    activate_first_task(&mut test_context);

    // Record the balance AFTER registration (coins were transferred for the fee)
    // but BEFORE executing the automated transaction.  We will compare against
    // this to verify that the discard path charges nothing extra.
    let balance_before_exec = test_context.account_balance(sender_address);

    // Build the automated transaction carrying the non-existent entry function.
    // The builder itself succeeds because it only BCS-decodes the stored bytes
    // (which are valid) — it does not query the VM for module existence.
    let automated_txn = build_automated_txn(&mut test_context, 0, nonexistent_fn, 1, expiry_time);

    // Execute without applying state changes.  We use execute_tagged_transaction
    // because the output is DISCARDED (no write set to apply) and
    // execute_and_apply_transaction panics on discarded outputs.
    let output = test_context.execute_tagged_transaction(automated_txn.into());

    // With SUPRA_AUTOMATION_V2_1 enabled the processor's special path triggers:
    // the output is discarded and no failure epilogue runs.
    AutomationRegistrationTestContext::check_discarded_output(
        output.clone(),
        StatusCode::INVALID_AUTOMATION_INNER_PAYLOAD,
    );

    // Discarded outputs carry FeeStatement::zero(), so gas_used must be 0.
    assert_eq!(
        output.gas_used(),
        0,
        "a discarded output must not charge any gas (FeeStatement::zero())"
    );

    // The sender's balance must be unchanged since the discard path commits
    // no write set.  (execute_tagged_transaction does not apply state.)
    let balance_after_exec = test_context.account_balance(sender_address);
    assert_eq!(
        balance_before_exec, balance_after_exec,
        "balance must not change when the automated transaction is discarded"
    );
}

/// **Negative case — V2_1 *disabled*, invalid inner payload registered without validation.**
///
/// When `SUPRA_AUTOMATION_V2_1` is disabled, the special discard path in
/// `execute_transaction_impl` does NOT trigger.  Instead the
/// `INVALID_AUTOMATION_INNER_PAYLOAD` error flows through
/// `on_transaction_execution_failure` → `failed_transaction_cleanup`, which runs
/// the failure epilogue and charges the sender for gas consumed up to that point
/// (at minimum the intrinsic-gas charge).
///
/// The resulting output is `Keep(MiscellaneousError(INVALID_AUTOMATION_INNER_PAYLOAD))`
/// (status code 1132 is in the Verification range, so `keep_or_discard()` returns
/// `Ok(KeptVMStatus::MiscellaneousError)`).  Gas *is* charged even though the
/// entry function body never ran, because `charge_intrinsic_gas_for_transaction`
/// was called before the failed load attempt.
///
/// # Key difference from the enabled case
/// Without V2_1 the protocol has no way to know that the payload was registered
/// without validation, so it applies the same fee-charging logic as for any other
/// kind of execution failure.
#[test]
fn check_invalid_inner_payload_charges_fee_when_v2_1_disabled() {
    let mut test_context = AutomationRegistrationTestContext::new();

    // Enable the base automation feature so the cycle starts and registration
    // is accepted.  Then explicitly disable SUPRA_AUTOMATION_V2_1 so the
    // special discard path in the processor is inactive.
    test_context.set_supra_native_automation(true);
    // SUPRA_AUTOMATION_V2_1 is in default_features() so we must turn it off.
    // set_feature_flag updates the on-chain feature bitset directly; no
    // on_new_epoch call is needed because V2_1 does not affect the registry
    // state machine (only the VM's error-handling path).
    test_context.set_feature_flag(FeatureFlag::SUPRA_AUTOMATION_V2_1, false);

    let nonexistent_fn = make_nonexistent_entry_function();
    let invalid_payload_bytes =
        bcs::to_bytes(&nonexistent_fn).expect("EntryFunction must BCS-serialize successfully");

    let expiry_time = test_context.chain_time_now() + 8_000;
    let sender_address = test_context.sender_account_address();

    // Register the task with the invalid payload.  SUPRA_NATIVE_AUTOMATION is
    // enabled (so the Move `register` function accepts the call) and the Move
    // function itself does not check SUPRA_AUTOMATION_V2_1, so registration
    // succeeds regardless of the V2_1 flag.
    test_context.register_task_bypassing_native_validation(
        sender_address,
        invalid_payload_bytes,
        expiry_time,
        TASK_MAX_GAS_AMOUNT,
        TASK_GAS_PRICE_CAP,
        AUTOMATION_FEE_CAP,
        DUMMY_TX_HASH.to_vec(),
        ust_aux_data(),
    );

    assert_eq!(
        test_context.get_next_task_index_from_registry(),
        1,
        "exactly one task should be registered"
    );

    activate_first_task(&mut test_context);

    let balance_before_exec = test_context.account_balance(sender_address);

    let automated_txn = build_automated_txn(&mut test_context, 0, nonexistent_fn, 1, expiry_time);

    // Execute via execute_tagged_transaction so we can inspect the output before
    // deciding whether to apply it.  The output is Keep(MiscellaneousError),
    // so the write set contains gas-deduction entries.
    let output = test_context.execute_tagged_transaction(automated_txn.into());

    // Without V2_1 the special discard path is bypassed; the failure epilogue
    // runs and the output is Keep(MiscellaneousError).
    AutomationRegistrationTestContext::check_miscellaneous_output(
        output.clone(),
        StatusCode::INVALID_AUTOMATION_INNER_PAYLOAD,
    );

    // The failure epilogue charges at least intrinsic gas.
    assert!(
        output.gas_used() > 0,
        "gas must be charged by the failure epilogue when V2_1 is disabled \
         (gas_used = {})",
        output.gas_used()
    );

    // Apply the write set manually so the balance change is reflected in the
    // fake data store, then assert the balance decreased.
    test_context.apply_write_set(output.write_set());
    let balance_after_exec = test_context.account_balance(sender_address);

    assert!(
        balance_after_exec < balance_before_exec,
        "sender balance must decrease when the failure epilogue charges gas \
         (before = {balance_before_exec}, after = {balance_after_exec})"
    );
}

/// **Transient execution failure — failure epilogue runs regardless of V2_1.**
///
/// A task whose `payload_tx` points to an existing function is registered
/// normally (with full validation).  At execution time, the Phase-1 load
/// succeeds (the function exists and its argument types are correct), but the
/// function body *aborts* because the transfer amount far exceeds the sender's
/// balance.
///
/// This produces a `VMStatus::MoveAbort`, which does **not** match the special
/// `INVALID_AUTOMATION_INNER_PAYLOAD` condition in `execute_transaction_impl`.
/// Therefore the failure epilogue always runs — the sender is charged for gas
/// regardless of whether `SUPRA_AUTOMATION_V2_1` is enabled.
///
/// # What this test verifies
/// * The V2_1 discard path is narrowly scoped to `INVALID_AUTOMATION_INNER_PAYLOAD`
///   (Phase-1 load failure); it does NOT affect ordinary runtime aborts.
/// * The failure epilogue correctly charges gas for a task whose body aborted.
/// * The output status is `Keep(MoveAbort)` — the write set contains gas fees.
#[test]
fn check_transient_execution_failure_charges_fee_regardless_of_v2_1() {
    let mut test_context = AutomationRegistrationTestContext::new();

    // SUPRA_AUTOMATION_V2_1 is enabled by default.  We leave it enabled to
    // confirm that V2_1 does NOT suppress transient (runtime) failures.
    test_context.set_supra_native_automation(true);

    // Use a destination that can receive coins (create it with 0 initial balance).
    let dest_account = test_context.new_account_data(0, 0);

    // Transfer amount is astronomically larger than the sender's balance (~100
    // billion quants after registration fees).  The prologue only checks that
    // `gas_price × max_gas_amount` fits within the balance, NOT the transfer
    // amount itself — so the prologue passes.  The transfer then aborts inside
    // `supra_account_transfer` when it tries to withdraw more than available.
    let oversized_transfer_amount = 500_000_000_000_000u64; // 500 trillion >> sender's ~100 billion

    let inner_fn = aptos_framework_sdk_builder::supra_account_transfer(
        dest_account.address().clone(),
        oversized_transfer_amount,
    )
    .into_entry_function();

    // Register with the validated path to prove the inner function is valid at
    // registration time.  Only the runtime execution will fail.
    let expiry_time = test_context.chain_time_now() + 8_000;
    let automation_txn = test_context.create_automation_txn(
        0,
        inner_fn.clone(),
        expiry_time,
        TASK_MAX_GAS_AMOUNT,
        TASK_GAS_PRICE_CAP,
        AUTOMATION_FEE_CAP,
    );

    let reg_output = test_context.execute_and_apply(automation_txn);
    assert_eq!(
        reg_output.status(),
        &TransactionStatus::Keep(ExecutionStatus::Success),
        "registration must succeed: {reg_output:?}"
    );

    assert_eq!(
        test_context.get_next_task_index_from_registry(),
        1,
        "exactly one task should be registered"
    );

    activate_first_task(&mut test_context);

    let sender_address = test_context.sender_account_address();
    let balance_before_exec = test_context.account_balance(sender_address);

    // Build the automated transaction using the same entry function that was
    // registered (which the builder obtains via try_from(task_details)).
    let task_details = test_context.get_task_details(0);
    let builder = AutomatedTransactionBuilder::try_from(task_details)
        .expect("builder construction from registered task must succeed");

    let result = builder
        .with_chain_id(ChainId::test())
        .with_block_height(1)
        .with_gas_unit_price(1)
        .build();

    let BuilderResult::Success(automated_txn) = result else {
        panic!("automated transaction builder must succeed for a validly registered task");
    };

    // Execute without applying so we can inspect the output first.
    let output = test_context.execute_tagged_transaction(automated_txn.into());

    // Phase-1 (load) succeeded.  Phase-2 (execution body) aborted.
    // This is a transient failure → `on_transaction_execution_failure` runs.
    // keep_or_discard() for MoveAbort returns Ok(KeptVMStatus::MoveAbort), so
    // the output is Keep(MoveAbort { ... }).
    match output.status() {
        TransactionStatus::Keep(ExecutionStatus::MoveAbort { .. }) => {
            // Expected: the execution body aborted at runtime.
        },
        other => panic!("expected Keep(MoveAbort) for runtime abort, got: {other:?}"),
    }

    // Gas must have been charged by the failure epilogue.
    assert!(
        output.gas_used() > 0,
        "gas must be charged for a runtime abort (failure epilogue ran)"
    );

    // Apply the write set and verify balance decreased.
    test_context.apply_write_set(output.write_set());
    let balance_after_exec = test_context.account_balance(sender_address);

    assert!(
        balance_after_exec < balance_before_exec,
        "sender balance must decrease after a runtime abort \
         (before = {balance_before_exec}, after = {balance_after_exec})"
    );

    // The destination should NOT have received any coins because the transfer
    // was rolled back as part of the abort.
    let dest_balance = test_context.account_balance(*dest_account.address());
    assert_eq!(
        dest_balance, 0,
        "destination must not receive tokens when the transfer aborts"
    );
}

/// **Symmetry check — transient failure with V2_1 explicitly disabled.**
///
/// Mirrors `check_transient_execution_failure_charges_fee_regardless_of_v2_1`
/// but with `SUPRA_AUTOMATION_V2_1` turned off.  The result must be identical
/// (`Keep(MoveAbort)`, gas charged) because the V2_1 flag only influences the
/// `INVALID_AUTOMATION_INNER_PAYLOAD` path, not ordinary runtime aborts.
///
/// Together with the test above this provides full cross-flag coverage for the
/// transient-failure branch of `execute_transaction_impl`.
#[test]
fn check_transient_execution_failure_charges_fee_when_v2_1_disabled() {
    let mut test_context = AutomationRegistrationTestContext::new();

    test_context.set_supra_native_automation(true);
    // Disable V2_1 to confirm it has no effect on runtime aborts.
    test_context.set_feature_flag(FeatureFlag::SUPRA_AUTOMATION_V2_1, false);

    let dest_account = test_context.new_account_data(0, 0);
    let oversized_transfer_amount = 500_000_000_000_000u64;

    let inner_fn = aptos_framework_sdk_builder::supra_account_transfer(
        dest_account.address().clone(),
        oversized_transfer_amount,
    )
    .into_entry_function();

    let expiry_time = test_context.chain_time_now() + 8_000;
    let automation_txn = test_context.create_automation_txn(
        0,
        inner_fn.clone(),
        expiry_time,
        TASK_MAX_GAS_AMOUNT,
        TASK_GAS_PRICE_CAP,
        AUTOMATION_FEE_CAP,
    );

    let reg_output = test_context.execute_and_apply(automation_txn);
    assert_eq!(
        reg_output.status(),
        &TransactionStatus::Keep(ExecutionStatus::Success),
        "registration must succeed: {reg_output:?}"
    );

    activate_first_task(&mut test_context);

    let sender_address = test_context.sender_account_address();
    let balance_before_exec = test_context.account_balance(sender_address);

    let task_details = test_context.get_task_details(0);
    let builder = AutomatedTransactionBuilder::try_from(task_details)
        .expect("builder must succeed for a validly registered task");

    let result = builder
        .with_chain_id(ChainId::test())
        .with_block_height(1)
        .with_gas_unit_price(1)
        .build();

    let BuilderResult::Success(automated_txn) = result else {
        panic!("automated transaction builder must succeed");
    };

    let output = test_context.execute_tagged_transaction(automated_txn.into());

    // Result is identical to the V2_1-enabled case: Keep(MoveAbort).
    match output.status() {
        TransactionStatus::Keep(ExecutionStatus::MoveAbort { .. }) => {},
        other => panic!(
            "expected Keep(MoveAbort) regardless of V2_1 flag for runtime abort, got: {other:?}"
        ),
    }

    assert!(
        output.gas_used() > 0,
        "gas must be charged by the failure epilogue regardless of V2_1"
    );

    test_context.apply_write_set(output.write_set());
    let balance_after_exec = test_context.account_balance(sender_address);
    assert!(
        balance_after_exec < balance_before_exec,
        "sender balance must decrease (before = {balance_before_exec}, after = {balance_after_exec})"
    );
}
