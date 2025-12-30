use crate::account_config::CORE_CODE_ADDRESS;
use move_core_types::value::{serialize_values, MoveStruct, MoveValue};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Default, Deserialize, Eq, PartialEq, Serialize)]
pub struct AppchainRegistryConfig {
    reserved_ranges: Vec<ReservedRange>,
}

impl AppchainRegistryConfig {
    pub fn new(reserved_ranges: Vec<ReservedRange>) -> Self {
        Self { reserved_ranges }
    }

    pub fn serialize_into_move_values(&self) -> Vec<Vec<u8>> {
        let reserved_ranges_vec_move_value: Vec<MoveValue> =
            self.reserved_ranges.iter().map(MoveValue::from).collect();
        let arguments = vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::Vector(reserved_ranges_vec_move_value),
        ];
        serialize_values(&arguments)
    }
}

#[derive(Clone, Debug, Deserialize, Eq, PartialEq, Serialize)]
pub struct ReservedRange {
    start: u16,
    end: u16,
}

impl From<&ReservedRange> for MoveValue {
    fn from(value: &ReservedRange) -> MoveValue {
        MoveValue::Struct(MoveStruct::new(vec![
            MoveValue::U16(value.start),
            MoveValue::U16(value.end),
        ]))
    }
}

impl Default for ReservedRange {
    fn default() -> Self {
        Self {
            start: Self::DEFAULT_START,
            end: Self::DEFAULT_END,
        }
    }
}

impl ReservedRange {
    // Currently, default values are not finalized yet, however, by considering that our production
    // networks chain IDs falls between 0-10, according to me the current default values are best.
    pub const DEFAULT_START: u16 = 0;
    pub const DEFAULT_END: u16 = 10;

    pub fn new(start: u16, end: u16) -> Self {
        Self { start, end }
    }
}
