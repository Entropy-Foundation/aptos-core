// Copyright (c) 2024 Supra.

use crate::transaction::EntryFunction;
use move_core_types::account_address::AccountAddress;
use move_core_types::identifier::{IdentStr, Identifier};
use move_core_types::language_storage::{ModuleId, TypeTag, CORE_CODE_ADDRESS};
use move_core_types::value::{serialize_values, MoveValue};
use once_cell::sync::Lazy;
use serde::{Deserialize, Serialize};

struct AutomationTransactionEntryRef {
    module_id: ModuleId,
    function: Identifier,
}

static AUTOMATION_REGISTRATION_ENTRY: Lazy<AutomationTransactionEntryRef> =
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
    pub fn serialized_args_with_sender_and_parent_hash(
        &self,
        sender: AccountAddress,
        parent_hash: Vec<u8>,
    ) -> Vec<Vec<u8>> {
        serialize_values(&[
            MoveValue::Address(sender),
            MoveValue::vector_u8(bcs::to_bytes(&self.automated_function).unwrap()),
            MoveValue::U64(self.expiration_timestamp_secs),
            MoveValue::U64(self.max_gas_amount),
            MoveValue::U64(self.gas_price_cap),
            MoveValue::vector_u8(parent_hash),
        ])
    }
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
        (
            self.automated_function,
            self.max_gas_amount,
            self.gas_price_cap,
            self.expiration_timestamp_secs,
        )
    }
    /// Module id containing registration function.
    pub fn module_id(&self) -> &ModuleId {
        &AUTOMATION_REGISTRATION_ENTRY.module_id
    }

    /// Registration function name accepting enclosed parameters.
    pub fn function(&self) -> &IdentStr {
        &AUTOMATION_REGISTRATION_ENTRY.function
    }

    /// Type arguments required by registration function.
    pub fn ty_args(&self) -> Vec<TypeTag> {
        vec![]
    }
}

/// Rust representation of the Automation task meta information in Move.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AutomationTaskMetaData {
    /// Automation task index in registry
    pub(crate) id: u64,
    /// The address of the task owner.
    pub(crate) owner: AccountAddress,
    /// The function signature associated with the registry entry.
    pub(crate) payload_tx: Vec<u8>,
    /// Expiry of the task, represented in a timestamp in second.
    pub(crate) expiry_time: u64,
    /// The transaction hash of the request transaction.
    pub(crate) tx_hash: Vec<u8>,
    /// Max gas amount of automation task
    pub(crate) max_gas_amount: u64,
    /// Maximum gas price cap for the task
    pub(crate) gas_price_cap: u64,
    /// Registration epoch number
    pub(crate) registration_epoch: u64,
    /// Registration epoch time
    pub(crate) registration_time: u64,
    /// Flag indicating whether the task is active.
    pub(crate) is_active: bool,
}

impl AutomationTaskMetaData {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        id: u64,
        owner: AccountAddress,
        payload_tx: Vec<u8>,
        expiry_time: u64,
        tx_hash: Vec<u8>,
        max_gas_amount: u64,
        gas_price_cap: u64,
        registration_epoch: u64,
        registration_time: u64,
        is_active: bool,
    ) -> Self {
        Self {
            id,
            owner,
            payload_tx,
            expiry_time,
            tx_hash,
            max_gas_amount,
            gas_price_cap,
            registration_epoch,
            registration_time,
            is_active,
        }
    }

    pub fn is_active(&self) -> bool {
        self.is_active
    }

    pub fn gas_price_cap(&self) -> u64 {
        self.gas_price_cap
    }
}
