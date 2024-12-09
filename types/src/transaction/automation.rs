// Copyright (c) 2024 Supra.

use crate::transaction::EntryFunction;
use move_core_types::identifier::{IdentStr, Identifier};
use move_core_types::language_storage::{ModuleId, TypeTag, CORE_CODE_ADDRESS};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

struct AutomationTransactionEntryRef {
    module_id: ModuleId,
    function: Identifier,
}

static AUTOMATION_TRANSACTION_ENTRY: Lazy<AutomationTransactionEntryRef> =
    Lazy::new(|| AutomationTransactionEntryRef {
        module_id: ModuleId::new(
            CORE_CODE_ADDRESS,
            Identifier::new("automation_registry").unwrap(),
        ),
        function: Identifier::new("register").unwrap(),
    });

#[derive(Clone, Debug, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub struct AutomationTransactionArguments {
    /// Entry function to be automated.
    inner_payload: EntryFunction,
    /// Max gas amount for automated transaction.
    max_gas_amount: u64,
    /// Gas Uint price upper limit that user is willing to pay.
    gas_price_cap: u64,
    /// Expiration time of the automated transaction in seconds since UTC Epoch start.
    expiration_timestamp_secs: u64,
}

impl AutomationTransactionArguments {
    pub fn new(
        inner_payload: EntryFunction,
        expiration_timestamp_secs: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
    ) -> AutomationTransactionArguments {
        Self {
            inner_payload,
            max_gas_amount,
            gas_price_cap,
            expiration_timestamp_secs,
        }
    }

    pub fn inner_payload(&self) -> &EntryFunction {
       &self.inner_payload
    }

    pub fn into_inner(self) -> (EntryFunction, u64, u64, u64) {
        (self.inner_payload, self.max_gas_amount, self.gas_price_cap, self.expiration_timestamp_secs)
    }
}

impl From<AutomationTransactionArguments> for EntryFunction {
    fn from(value: AutomationTransactionArguments) -> EntryFunction {
        let AutomationTransactionArguments {
            inner_payload,
            max_gas_amount,
            gas_price_cap,
            expiration_timestamp_secs,
        } = value;
        EntryFunction::new(
            AUTOMATION_TRANSACTION_ENTRY.module_id.clone(),
            AUTOMATION_TRANSACTION_ENTRY.function.clone(),
            vec![],
            vec![
                bcs::to_bytes(&bcs::to_bytes(&inner_payload).unwrap()).unwrap(),
                bcs::to_bytes(&expiration_timestamp_secs).unwrap(),
                bcs::to_bytes(&max_gas_amount).unwrap(),
                bcs::to_bytes(&gas_price_cap).unwrap(),
            ],
        )
    }
}

/// Represents options for Automation transaction payload.
#[derive(Clone, Debug, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub enum AutomationTransactionPayload {
    EntryFunction(EntryFunction),
    EntryFunctionArguments(AutomationTransactionArguments),
}

impl AutomationTransactionPayload {

    pub fn is_valid(&self) -> bool {
        let AutomationTransactionPayload::EntryFunction(e) = self else {
            return true;
        };
        e.module().eq(&AUTOMATION_TRANSACTION_ENTRY.module_id)
            && e.function().eq(&AUTOMATION_TRANSACTION_ENTRY.function)
    }

    pub fn entry_function_reference() -> String {
        format!(
            "Expected module-id: {}, function: {} ",
            AUTOMATION_TRANSACTION_ENTRY.module_id, AUTOMATION_TRANSACTION_ENTRY.function,
        )
    }

    pub fn module_id(&self) -> &ModuleId {
        match self {
            AutomationTransactionPayload::EntryFunction(e) => e.module(),
            AutomationTransactionPayload::EntryFunctionArguments(_) => {
                &AUTOMATION_TRANSACTION_ENTRY.module_id
            },
        }
    }

    pub fn function(&self) -> &IdentStr {
        match self {
            AutomationTransactionPayload::EntryFunction(e) => e.function(),
            AutomationTransactionPayload::EntryFunctionArguments(_) => {
                &AUTOMATION_TRANSACTION_ENTRY.function
            },
        }
    }

    pub fn ty_args(&self) -> &[TypeTag] {
        match self {
            AutomationTransactionPayload::EntryFunction(e) => e.ty_args(),
            AutomationTransactionPayload::EntryFunctionArguments(_) => &[]
        }

    }
}
