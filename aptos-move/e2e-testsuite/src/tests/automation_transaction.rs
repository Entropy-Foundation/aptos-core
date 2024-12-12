// Copyright (c) 2024 Supra.

use aptos_cached_packages::aptos_framework_sdk_builder;
use aptos_language_e2e_tests::account::{Account, AccountData};
use aptos_language_e2e_tests::executor::FakeExecutor;
use aptos_types::transaction::automation::RegistrationParams;
use aptos_types::transaction::{
    EntryFunction, ExecutionStatus, SignedTransaction, TransactionOutput, TransactionPayload,
    TransactionStatus,
};
use move_core_types::vm_status::StatusCode;
use std::ops::{Deref, DerefMut};

const TIMESTAMP_NOW_SECONDS: &str = "0x1::timestamp::now_seconds";
const AUTOMATION_NEXT_TASK_ID: &str = "0x1::automation_registry::get_next_task_index";

struct AutomationTransactionTestContext {
    executor: FakeExecutor,
    txn_sender: AccountData,
}

impl AutomationTransactionTestContext {
    fn new() -> Self {
        let mut executor = FakeExecutor::from_head_genesis();
        let mut root = Account::new_aptos_root();
        let (private_key, public_key) = aptos_vm_genesis::GENESIS_KEYPAIR.clone();
        root.rotate_key(private_key, public_key);

        // Prepare automation transaction sender
        let txn_sender = executor.create_raw_account_data(100_000_000, 0);
        executor.add_account_data(&txn_sender);
        Self {
            executor,
            txn_sender,
        }
    }

    fn new_account_data(&mut self, amount: u64, seq_num: u64) -> AccountData {
        let new_account_data = self.create_raw_account_data(amount, seq_num);
        self.add_account_data(&new_account_data);
        new_account_data
    }

    fn create_automation_txn(
        &self,
        seq_num: u64,
        inner_payload: EntryFunction,
        expiry_time: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
    ) -> SignedTransaction {
        let txn_arguments =
            RegistrationParams::new(inner_payload, expiry_time, max_gas_amount, gas_price_cap);
        let automation_txn = TransactionPayload::Automation(txn_arguments);
        self.txn_sender
            .account()
            .transaction()
            .payload(automation_txn)
            .sequence_number(seq_num)
            .sign()
    }

    fn check_miscellaneous_output(output: TransactionOutput, expected_status_code: StatusCode) {
        match output.status() {
            TransactionStatus::Keep(ExecutionStatus::MiscellaneousError(maybe_status_code)) => {
                assert_eq!(
                    maybe_status_code.as_ref().unwrap(),
                    &expected_status_code,
                    "{output:?}"
                );
            },
            _ => panic!("Unexpected transaction status: {output:?}"),
        }
    }
}

impl Deref for AutomationTransactionTestContext {
    type Target = FakeExecutor;

    fn deref(&self) -> &Self::Target {
        &self.executor
    }
}

impl DerefMut for AutomationTransactionTestContext {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.executor
    }
}

#[test]
fn check_successful_registration() {
    let mut test_context = AutomationTransactionTestContext::new();
    // Prepare inner-entry-function to be automated.
    let dest_account = test_context.new_account_data(0, 0);
    let inner_entry_function =
        aptos_framework_sdk_builder::supra_coin_mint(dest_account.address().clone(), 100)
            .into_entry_function();

    let view_output = test_context.execute_view_function(
        str::parse(TIMESTAMP_NOW_SECONDS).unwrap(),
        vec![],
        vec![],
    );
    let result = view_output.values.expect("Valid result");
    assert_eq!(result.len(), 1);
    let now = bcs::from_bytes::<u64>(&result[0]).unwrap();
    let expiration_time = now + 4000;
    let automation_txn = test_context.create_automation_txn(
        0,
        inner_entry_function.clone(),
        expiration_time,
        100,
        100,
    );

    let output = test_context.execute_and_apply(automation_txn);
    assert_eq!(
        output.status(),
        &TransactionStatus::Keep(ExecutionStatus::Success),
        "{output:?}"
    );

    // Check automation registry state.
    let view_output = test_context.execute_view_function(
        str::parse(AUTOMATION_NEXT_TASK_ID).unwrap(),
        vec![],
        vec![],
    );
    let result = view_output.values.expect("Valid result");
    assert_eq!(result.len(), 1);
    let next_task_id = bcs::from_bytes::<u64>(&result[0]).unwrap();
    assert_eq!(next_task_id, 2);
}

#[test]
fn check_registration_from_non_automation_context() {
    let mut test_context = AutomationTransactionTestContext::new();
    // Prepare inner-entry-function to be automated.
    let dest_account = test_context.new_account_data(0, 0);
    let inner_entry_function =
        aptos_framework_sdk_builder::supra_coin_mint(dest_account.address().clone(), 100)
            .into_entry_function();
    let inner_entry_function_bytes =
        bcs::to_bytes(&inner_entry_function).expect("Can't serialize entry function");

    let entry_with_register = aptos_framework_sdk_builder::automation_registry_register(
        inner_entry_function_bytes,
        3600,
        100,
        100,
    );
    let user_txn_with_register_entry = test_context
        .txn_sender
        .account()
        .transaction()
        .payload(entry_with_register)
        .sequence_number(0)
        .sign();

    let output = test_context.execute_transaction(user_txn_with_register_entry);
    match output.status() {
        TransactionStatus::Keep(ExecutionStatus::MoveAbort { code, .. }) => {
            //ENOT_AUTOMATION_TXN_CONTEXT
            assert_eq!(*code, 7);
        },
        _ => panic!("Unexpected transaction status: {output:?}"),
    }
}

#[test]
fn check_invalid_automation_txn() {
    let mut test_context = AutomationTransactionTestContext::new();
    // Create automation transaction with entry-function with invalid arguments.
    let dest_account = test_context.new_account_data(0, 0);
    let (m_id, f_id, _, _) =
        aptos_framework_sdk_builder::supra_coin_mint(dest_account.address().clone(), 100)
            .into_entry_function()
            .into_inner();
    let inner_entry_function = EntryFunction::new(m_id, f_id, vec![], vec![]);
    let automation_txn =
        test_context.create_automation_txn(0, inner_entry_function, 3600, 100, 100);

    let output = test_context.execute_transaction(automation_txn);
    AutomationTransactionTestContext::check_miscellaneous_output(
        output,
        StatusCode::INVALID_AUTOMATION_INNER_PAYLOAD,
    );
}
