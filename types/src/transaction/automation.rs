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

/// Represents set of parameters required to register automation task.
#[derive(Clone, Debug, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub struct RegistrationParams {
    /// Entry function to be automated.
    automated_function: EntryFunction,
    /// Max gas amount for automated transaction.
    max_gas_amount: u64,
    /// Gas Uint price upper limit that user is willing to pay.
    gas_price_cap: u64,
    /// Expiration time of the automated transaction in seconds since UTC Epoch start.
    expiration_timestamp_secs: u64,
}

impl RegistrationParams {
    pub fn new(
        automated_function: EntryFunction,
        expiration_timestamp_secs: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
    ) -> RegistrationParams {
        Self {
            automated_function,
            max_gas_amount,
            gas_price_cap,
            expiration_timestamp_secs,
        }
    }

    pub fn automated_function(&self) -> &EntryFunction {
       &self.automated_function
    }

    pub fn into_inner(self) -> (EntryFunction, u64, u64, u64) {
        (self.automated_function, self.max_gas_amount, self.gas_price_cap, self.expiration_timestamp_secs)
    }
    /// Module id containing registration function.
    pub fn module_id(&self) -> &ModuleId {
        &AUTOMATION_TRANSACTION_ENTRY.module_id
    }

    /// Registration function name accepting enclosed parameters.
    pub fn function(&self) -> &IdentStr {
        &AUTOMATION_TRANSACTION_ENTRY.function
    }

    /// Type arguments required by registration function.
    pub fn ty_args(&self) -> &[TypeTag] {
        &[]
    }
}

impl From<RegistrationParams> for EntryFunction {
    fn from(value: RegistrationParams) -> EntryFunction {
        let RegistrationParams {
            automated_function,
            max_gas_amount,
            gas_price_cap,
            expiration_timestamp_secs,
        } = value;
        EntryFunction::new(
            AUTOMATION_TRANSACTION_ENTRY.module_id.clone(),
            AUTOMATION_TRANSACTION_ENTRY.function.clone(),
            vec![],
            vec![
                bcs::to_bytes(&bcs::to_bytes(&automated_function).unwrap()).unwrap(),
                bcs::to_bytes(&expiration_timestamp_secs).unwrap(),
                bcs::to_bytes(&max_gas_amount).unwrap(),
                bcs::to_bytes(&gas_price_cap).unwrap(),
            ],
        )
    }
}
