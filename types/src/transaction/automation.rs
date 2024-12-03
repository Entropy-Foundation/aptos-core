// Copyright (c) 2024 Supra.

use crate::transaction::user_transaction_context::EntryFunctionPayload;
use crate::transaction::EntryFunction;
use move_core_types::identifier::{IdentStr, Identifier};
use move_core_types::language_storage::{ModuleId, CORE_CODE_ADDRESS};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

struct AutomationTransactionEntryRef {
    module_id: ModuleId,
    entry_name: String,
}

static AUTOMATION_TRANSACTION_ENTRY: Lazy<AutomationTransactionEntryRef> =
    Lazy::new(|| AutomationTransactionEntryRef {
        module_id: ModuleId::new(
            CORE_CODE_ADDRESS,
            Identifier::new("automation_registry").unwrap(),
        ),
        entry_name: "register".to_string(),
    });

/// Represents options for Automation transaction payload.
#[derive(Clone, Debug, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub enum AutomationTransactionPayload {
    EntryFunction(EntryFunction),
}

impl AutomationTransactionPayload {
    pub fn entry_function(&self) -> Option<&EntryFunction> {
        let AutomationTransactionPayload::EntryFunction(function) = &self else {
            return None;
        };
        Some(function)
    }

    pub fn as_entry_function_payload(&self) -> Option<EntryFunctionPayload> {
        self.entry_function().map(|e| e.as_entry_function_payload())
    }

    pub fn is_valid(&self) -> bool {
        self.entry_function()
            .map(|e| {
                e.module().eq(&AUTOMATION_TRANSACTION_ENTRY.module_id)
                    && e.function()
                        .eq(&IdentStr::new(&AUTOMATION_TRANSACTION_ENTRY.entry_name).unwrap())
            })
            .unwrap_or(false)
    }

    pub fn entry_function_reference() -> String {
        format!(
            "Expected module-id: {}, function: {} ",
            AUTOMATION_TRANSACTION_ENTRY.module_id, AUTOMATION_TRANSACTION_ENTRY.entry_name,
        )
    }
}
