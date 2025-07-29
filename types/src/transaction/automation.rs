// Copyright (c) 2025 Supra.
// SPDX-License-Identifier: Apache-2.0

use crate::transaction::{EntryFunction, Transaction};
use aptos_crypto::HashValue;
use move_core_types::account_address::AccountAddress;
use move_core_types::identifier::{IdentStr, Identifier};
use move_core_types::language_storage::{ModuleId, TypeTag, CORE_CODE_ADDRESS};
use move_core_types::value::{serialize_values, MoveValue};
use once_cell::sync::Lazy;
#[cfg(any(test, feature = "fuzzing"))]
use proptest_derive::Arbitrary;
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;

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
pub enum RegistrationParams {
    V1(RegistrationParamsV1),
}
impl RegistrationParams {
    pub fn new_v1(
        automated_function: EntryFunction,
        expiration_timestamp_secs: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
        automation_fee_cap_for_epoch: u64,
        aux_data: Vec<Vec<u8>>,
    ) -> RegistrationParams {
        RegistrationParams::V1(RegistrationParamsV1::new(
            automated_function,
            expiration_timestamp_secs,
            max_gas_amount,
            gas_price_cap,
            automation_fee_cap_for_epoch,
            aux_data,
        ))
    }

    pub fn automated_function(&self) -> &EntryFunction {
        let RegistrationParams::V1(v1_self) = self;
        v1_self.automated_function()
    }

    pub fn expiration_timestamp_secs(&self) -> u64 {
        let RegistrationParams::V1(v1_self) = self;
        v1_self.expiration_timestamp_secs
    }

    pub fn gas_price_cap(&self) -> u64 {
        let RegistrationParams::V1(v1_self) = self;
        v1_self.gas_price_cap
    }

    pub fn max_gas_amount(&self) -> u64 {
        let RegistrationParams::V1(v1_self) = self;
        v1_self.max_gas_amount
    }

    pub fn into_v1(self) -> Option<RegistrationParamsV1> {
        let RegistrationParams::V1(v1_self) = self;
        Some(v1_self)
    }

    /// Module id containing registration function.
    pub fn module_id(&self) -> &ModuleId {
        let RegistrationParams::V1(v1_self) = self;
        v1_self.module_id()
    }

    /// Registration function name accepting enclosed parameters.
    pub fn function(&self) -> &IdentStr {
        let RegistrationParams::V1(v1_self) = self;
        v1_self.function()
    }

    /// Type arguments required by registration function.
    pub fn ty_args(&self) -> Vec<TypeTag> {
        vec![]
    }

    pub fn serialized_args_with_sender_and_parent_hash(
        &self,
        sender: AccountAddress,
        parent_hash: Vec<u8>,
    ) -> Vec<Vec<u8>> {
        let RegistrationParams::V1(v1_self) = self;
        v1_self.serialized_args_with_sender_and_parent_hash(sender, parent_hash)
    }
}

/// Initial set of parameters required to register automation task.
#[derive(Clone, Debug, Hash, PartialEq, Eq, Serialize, Deserialize)]
pub struct RegistrationParamsV1 {
    /// Entry function to be automated.
    automated_function: EntryFunction,
    /// Max gas amount for automated transaction.
    max_gas_amount: u64,
    /// Gas Uint price upper limit that user is willing to pay.
    gas_price_cap: u64,
    /// Maximum automation fee that user is willing to pay for epoch.
    automation_fee_cap_for_epoch: u64,
    /// Expiration time of the automated transaction in seconds since UTC Epoch start.
    expiration_timestamp_secs: u64,
    /// Reserved for future extensions of registration parameters.
    /// Will be helpful if the new registration parameters will affect only registration but not
    /// task execution layer in native layer.
    /// If a newly added parameter affects automation-task execution flow, that means
    /// the entire flow of the automation task execution is going to be affected in native layer,
    /// which will require all components upgrade( not only supra-framework/state but also node)
    /// then it is advised to add a new version of registration parameters and have the new parameter properly
    /// integrated in the automation-task/automated-transaction execution flow.
    aux_data: Vec<Vec<u8>>,
}

impl RegistrationParamsV1 {
    pub fn new(
        automated_function: EntryFunction,
        expiration_timestamp_secs: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
        automation_fee_cap_for_epoch: u64,
        aux_data: Vec<Vec<u8>>,
    ) -> RegistrationParamsV1 {
        Self {
            automated_function,
            max_gas_amount,
            gas_price_cap,
            automation_fee_cap_for_epoch,
            expiration_timestamp_secs,
            aux_data,
        }
    }

    pub fn automated_function(&self) -> &EntryFunction {
        &self.automated_function
    }

    pub fn into_inner(self) -> (EntryFunction, u64, u64, u64, u64, Vec<Vec<u8>>) {
        (
            self.automated_function,
            self.max_gas_amount,
            self.gas_price_cap,
            self.expiration_timestamp_secs,
            self.automation_fee_cap_for_epoch,
            self.aux_data,
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

    pub fn serialized_args_with_sender_and_parent_hash(
        &self,
        sender: AccountAddress,
        parent_hash: Vec<u8>,
    ) -> Vec<Vec<u8>> {
        let aux_move_args = self
            .aux_data
            .iter()
            .map(|item| MoveValue::vector_u8(item.clone()))
            .collect();
        serialize_values(&[
            MoveValue::Address(sender),
            MoveValue::vector_u8(bcs::to_bytes(&self.automated_function).unwrap()),
            MoveValue::U64(self.expiration_timestamp_secs),
            MoveValue::U64(self.max_gas_amount),
            MoveValue::U64(self.gas_price_cap),
            MoveValue::U64(self.automation_fee_cap_for_epoch),
            MoveValue::vector_u8(parent_hash),
            MoveValue::Vector(aux_move_args),
        ])
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
    /// Maximum gas price for the task to be paid ever.
    pub(crate) gas_price_cap: u64,
    /// Maximum automation fee for epoch to be paid ever.
    pub(crate) automation_fee_cap_for_epoch: u64,
    /// Auxiliary data specified for the task to aid registration.
    /// Not used currently. Reserved for future extentions.
    pub(crate) aux_data: Vec<Vec<u8>>,
    /// Registration epoch timestamp
    pub(crate) registration_time: u64,
    /// Flag indicating whether the task is active.
    pub(crate) is_active: bool,
    /// Fee locked for the task estimated for the next epoch at the start of the current epoch.
    pub(crate) locked_fee_for_next_epoch: u64,
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
        automation_fee_cap_for_epoch: u64,
        aux_data: Vec<Vec<u8>>,
        registration_time: u64,
        is_active: bool,
    ) -> Self {
        Self::new_with_locked_fee(
            id,
            owner,
            payload_tx,
            expiry_time,
            tx_hash,
            max_gas_amount,
            gas_price_cap,
            automation_fee_cap_for_epoch,
            aux_data,
            registration_time,
            is_active,
            0,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn new_with_locked_fee(
        id: u64,
        owner: AccountAddress,
        payload_tx: Vec<u8>,
        expiry_time: u64,
        tx_hash: Vec<u8>,
        max_gas_amount: u64,
        gas_price_cap: u64,
        automation_fee_cap_for_epoch: u64,
        aux_data: Vec<Vec<u8>>,
        registration_time: u64,
        is_active: bool,
        locked_fee_for_next_epoch: u64,
    ) -> Self {
        Self {
            id,
            owner,
            payload_tx,
            expiry_time,
            tx_hash,
            max_gas_amount,
            gas_price_cap,
            automation_fee_cap_for_epoch,
            aux_data,
            registration_time,
            is_active,
            locked_fee_for_next_epoch,
        }
    }

    pub fn is_active(&self) -> bool {
        self.is_active
    }

    pub fn gas_price_cap(&self) -> u64 {
        self.gas_price_cap
    }

    pub fn payload_tx(&self) -> &[u8] {
        &self.payload_tx
    }

    pub fn expiry_time(&self) -> u64 {
        self.expiry_time
    }

    pub fn tx_hash(&self) -> &[u8] {
        &self.tx_hash
    }

    pub fn max_gas_amount(&self) -> u64 {
        self.max_gas_amount
    }

    pub fn registration_time(&self) -> u64 {
        self.registration_time
    }

    pub fn owner(&self) -> AccountAddress {
        self.owner
    }

    pub fn id(&self) -> u64 {
        self.id
    }

    pub fn locked_fee_for_next_epoch(&self) -> u64 {
        self.locked_fee_for_next_epoch
    }
}

static AUTOMATION_REGISTRY_PROCESS_TASKS_ENTRY: Lazy<AutomationTransactionEntryRef> =
    Lazy::new(|| AutomationTransactionEntryRef {
        module_id: ModuleId::new(
            CORE_CODE_ADDRESS,
            Identifier::new("automation_registry").unwrap(),
        ),
        function: Identifier::new("process_tasks").unwrap(),
    });

/// Action to be performed on automation registry.
#[derive(Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
#[cfg_attr(any(test, feature = "fuzzing"), derive(Arbitrary))]
pub enum AutomationRegistryAction {
    Process { task_indexes: Vec<u64> },
}

impl AutomationRegistryAction {
    pub fn process(task_indexes: Vec<u64>) -> Self {
        AutomationRegistryAction::Process { task_indexes }
    }

    pub fn process_task(task_index: u64) -> Self {
        AutomationRegistryAction::Process {
            task_indexes: vec![task_index],
        }
    }

    pub fn as_move_value(&self) -> MoveValue {
        let AutomationRegistryAction::Process { task_indexes } = self;
        let value_indexes = task_indexes
            .iter()
            .map(|v| MoveValue::U64(*v))
            .collect::<Vec<_>>();
        MoveValue::Vector(value_indexes)
    }

    /// Returns a tuple of min and max task indexes included in the action.
    pub fn task_range(&self) -> (u64, u64) {
        let AutomationRegistryAction::Process { task_indexes } = self;
        (
            task_indexes.iter().min().copied().unwrap_or(u64::MAX),
            task_indexes.iter().max().copied().unwrap_or(u64::MAX),
        )
    }

    /// Module id containing automation registry target function.
    pub fn module_id(&self) -> &ModuleId {
        &AUTOMATION_REGISTRY_PROCESS_TASKS_ENTRY.module_id
    }

    /// Action function name accepting enclosed tasks.
    pub fn function(&self) -> &IdentStr {
        &AUTOMATION_REGISTRY_PROCESS_TASKS_ENTRY.function
    }

    /// Type arguments required by action function.
    pub fn ty_args(&self) -> Vec<TypeTag> {
        vec![]
    }
}

/// Automation Registry transaction payload to be executed on cycle transition.
#[derive(Clone, Debug, Hash, Eq, PartialEq, Serialize, Deserialize)]
#[cfg_attr(any(test, feature = "fuzzing"), derive(Arbitrary))]
pub struct AutomationRegistryRecord {
    /// Index of the record. Should be unique in set of the records shceduled in scope of the same block.
    index: u64,
    /// Index of the new cycle to be moved to.
    cycle_id: u64,
    /// Height of the block in scope of which registry action is requested/scheduled.
    block_height: u64,
    /// Action to perform in scope of the request.
    action: AutomationRegistryAction,
}

impl PartialOrd<Self> for AutomationRegistryRecord {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        let this_range = self.action.task_range();
        let other_range = other.action.task_range();
        this_range.partial_cmp(&other_range)
    }
}

impl Ord for AutomationRegistryRecord {
    fn cmp(&self, other: &Self) -> Ordering {
        let this_range = self.action.task_range();
        let other_range = other.action.task_range();
        this_range.cmp(&other_range)
    }
}

impl AutomationRegistryRecord {
    pub fn new(
        record_index: u64,
        cycle_id: u64,
        block_height: u64,
        action: AutomationRegistryAction,
    ) -> AutomationRegistryRecord {
        Self {
            index: record_index,
            cycle_id,
            block_height,
            action,
        }
    }

    pub fn serialize_args_with_sender(&self, sender: AccountAddress) -> Vec<Vec<u8>> {
        let action_as_value = self.action.as_move_value();
        serialize_values(&[
            MoveValue::Address(sender),
            MoveValue::U64(self.cycle_id),
            action_as_value,
        ])
    }

    pub fn hash(&self) -> HashValue {
        HashValue::keccak_256_of(
            &bcs::to_bytes(self).expect("AutomationRegistryRecord serialization should never fail"),
        )
    }

    /// Module id containing automation registry target function.
    pub fn module_id(&self) -> &ModuleId {
        self.action.module_id()
    }

    /// Action  function name accepting enclosed parameters.
    pub fn function(&self) -> &IdentStr {
        self.action.function()
    }

    /// Type arguments required by registration function.
    pub fn ty_args(&self) -> Vec<TypeTag> {
        self.action.ty_args()
    }

    pub fn index(&self) -> u64 {
        self.index
    }

    pub fn cycle_id(&self) -> u64 {
        self.cycle_id
    }

    pub fn block_height(&self) -> u64 {
        self.block_height
    }

    pub fn action(&self) -> &AutomationRegistryAction {
        &self.action
    }
}

impl From<AutomationRegistryRecord> for Transaction {
    fn from(value: AutomationRegistryRecord) -> Self {
        Transaction::AutomationRegistryTransaction(value)
    }
}

#[derive(Debug, Clone, Default)]
pub struct AutomationRegistryRecordBuilder {
    record_index: Option<u64>,
    action: Option<AutomationRegistryAction>,
    cycle_id: Option<u64>,
    block_height: Option<u64>,
}

impl AutomationRegistryRecordBuilder {
    pub fn new(cycle_id: u64) -> Self {
        Self {
            action: None,
            cycle_id: Some(cycle_id),
            record_index: None,
            block_height: None,
        }
    }

    pub fn task_range(&self) -> (u64, u64) {
        if self.action.is_none() {
            return (u64::MAX, u64::MAX);
        }
        self.action.as_ref().unwrap().task_range()
    }

    pub fn with_record_index(mut self, record_index: u64) -> Self {
        self.record_index = Some(record_index);
        self
    }

    pub fn with_action(mut self, action: AutomationRegistryAction) -> Self {
        self.action = Some(action);
        self
    }

    pub fn with_cycle_id(mut self, cycle_id: u64) -> Self {
        self.cycle_id = Some(cycle_id);
        self
    }

    pub fn with_block_height(mut self, block_height: u64) -> Self {
        self.block_height = Some(block_height);
        self
    }

    /// Splits the existing record builder into single task based actions if possible.
    /// If no action is specified the same instance is returned.
    pub fn split(mut self) -> Vec<Self> {
        match self.action.take() {
            None => vec![self],
            Some(AutomationRegistryAction::Process { task_indexes }) => task_indexes
                .into_iter()
                .map(AutomationRegistryAction::process_task)
                .map(|action| Self {
                    record_index: None,
                    action: Some(action),
                    cycle_id: self.cycle_id,
                    block_height: self.block_height,
                })
                .collect::<Vec<_>>(),
        }
    }

    pub fn build(self) -> Result<AutomationRegistryRecord, String> {
        let Some(action) = self.action else {
            return Err("AutomationRegistryRecord must have an action".to_string());
        };
        let Some(cycle_id) = self.cycle_id else {
            return Err("AutomationRegistryRecord must have a cycle id".to_string());
        };
        let Some(block_height) = self.block_height else {
            return Err("AutomationRegistryRecord must have a block height".to_string());
        };
        let Some(record_index) = self.record_index else {
            return Err("AutomationRegistryRecord must have an index ".to_string());
        };
        Ok(AutomationRegistryRecord::new(
            record_index,
            cycle_id,
            block_height,
            action,
        ))
    }
}
