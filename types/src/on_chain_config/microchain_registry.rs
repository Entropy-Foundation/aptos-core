use crate::account_config::CORE_CODE_ADDRESS;
use move_core_types::value::{serialize_values, MoveStruct, MoveValue};

#[derive(Clone, Debug, Default)]
pub struct MicrochainRegistryConfig {
    reserved_ranges: Vec<ReservedRange>,
}

impl MicrochainRegistryConfig {
    pub fn new(reserved_ranges: Vec<ReservedRange>) -> Self {
        Self { reserved_ranges }
    }

    pub fn serialize_into_move_values(&self) -> Vec<Vec<u8>> {
        let reserved_ranges_vec_move_value = self
            .reserved_ranges
            .iter()
            .map(|range| MoveValue::from(range))
            .collect::<Vec<MoveValue>>();
        let arguments = vec![
            MoveValue::Signer(CORE_CODE_ADDRESS),
            MoveValue::Vector(reserved_ranges_vec_move_value),
        ];
        serialize_values(&arguments)
    }
}

#[derive(Clone, Debug, Default)]
pub struct ReservedRange {
    start: u8,
    end: u8,
}

impl ReservedRange {
    pub fn new(start: u8, end: u8) -> Self {
        Self { start, end }
    }
}

impl From<&ReservedRange> for MoveValue {
    fn from(value: &ReservedRange) -> MoveValue {
        MoveValue::Struct(MoveStruct::new(vec![
            MoveValue::U8(value.start),
            MoveValue::U8(value.end),
        ]))
    }
}
