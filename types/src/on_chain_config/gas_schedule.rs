// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::on_chain_config::OnChainConfig;
use serde::de::{self, Deserializer};
use serde::{Deserialize, Serialize};
use std::collections::{btree_map, BTreeMap};

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct GasSchedule {
    pub entries: Vec<(String, u64)>,
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct GasScheduleV2 {
    pub feature_version: u64,
    #[serde(deserialize_with = "deserialize_gas_schedule_entries")]
    pub entries: Vec<(String, u64)>,
}

#[derive(Debug)]
pub enum DiffItem<T> {
    Add { new_val: T },
    Delete { old_val: T },
    Modify { old_val: T, new_val: T },
}

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct StorageGasSchedule {
    pub per_item_read: u64,
    pub per_item_create: u64,
    pub per_item_write: u64,
    pub per_byte_read: u64,
    pub per_byte_create: u64,
    pub per_byte_write: u64,
}

impl StorageGasSchedule {
    pub fn zeros() -> Self {
        Self {
            per_item_read: 0,
            per_item_create: 0,
            per_item_write: 0,
            per_byte_read: 0,
            per_byte_create: 0,
            per_byte_write: 0,
        }
    }
}

impl GasSchedule {
    pub fn into_btree_map(self) -> BTreeMap<String, u64> {
        // TODO: what if the gas schedule contains duplicated entries?
        self.entries.into_iter().collect()
    }
}

impl GasScheduleV2 {
    pub fn from_json_string(json_str: String) -> anyhow::Result<Self> {
        serde_json::from_str(&json_str).map_err(|e| anyhow::anyhow!(e))
    }

    pub fn into_btree_map(self) -> BTreeMap<String, u64> {
        // TODO: what if the gas schedule contains duplicated entries?
        self.entries.into_iter().collect()
    }

    pub fn to_btree_map_borrowed(&self) -> BTreeMap<&str, u64> {
        self.entries.iter().map(|(k, v)| (k.as_str(), *v)).collect()
    }

    pub fn diff<'a>(old: &'a Self, new: &'a Self) -> BTreeMap<&'a str, DiffItem<u64>> {
        let mut old = old.to_btree_map_borrowed();
        let new = new.to_btree_map_borrowed();

        let mut diff = BTreeMap::new();
        for (param_name, new_val) in new {
            match old.entry(param_name) {
                btree_map::Entry::Occupied(entry) => {
                    let (param_name, old_val) = entry.remove_entry();

                    if old_val != new_val {
                        diff.insert(param_name, DiffItem::Modify { old_val, new_val });
                    }
                },
                btree_map::Entry::Vacant(entry) => {
                    let param_name = entry.into_key();
                    diff.insert(param_name, DiffItem::Add { new_val });
                },
            }
        }
        diff.extend(
            old.into_iter()
                .map(|(param_name, old_val)| (param_name, DiffItem::Delete { old_val })),
        );

        diff
    }
}

// Helper enum to facilitate deserialization of gas schedule entries that can be either
// tuples or maps.
// Examples of valid formats:
// 1. Tuple format: ["foo", 123]
// 2. Map format: { "key": "foo", "val": 123 }
// 3. Map format with string value: { "key": "foo", "val": "123" }
#[derive(Deserialize)]
#[serde(untagged)]
enum GasEntryHelper {
    Tuple((String, u64)),
    Map { key: String, val: GasEntryValue },
}

// Helper enum to represent the value in the map format, which can be either a number or a string.
#[derive(Deserialize)]
#[serde(untagged)]
enum GasEntryValue {
    Number(u64),
    String(String),
}

// Custom deserializer for gas schedule entries to handle both tuple and map formats.
fn deserialize_gas_schedule_entries<'de, D>(deserializer: D) -> Result<Vec<(String, u64)>, D::Error>
where
    D: Deserializer<'de>,
{
    let raw_entries: Vec<GasEntryHelper> = Vec::deserialize(deserializer)?;
    raw_entries
        .into_iter()
        .map(|entry| match entry {
            GasEntryHelper::Tuple(pair) => Ok(pair),
            GasEntryHelper::Map { key, val } => {
                let parsed_val = match val {
                    GasEntryValue::Number(n) => n,
                    GasEntryValue::String(s) => s.parse::<u64>().map_err(|e| {
                        de::Error::custom(format!(
                            "failed to parse gas entry value for {}: {}",
                            key, e
                        ))
                    })?,
                };
                Ok((key, parsed_val))
            },
        })
        .collect()
}

impl OnChainConfig for GasSchedule {
    const MODULE_IDENTIFIER: &'static str = "gas_schedule";
    const TYPE_IDENTIFIER: &'static str = "GasSchedule";
}

impl OnChainConfig for GasScheduleV2 {
    const MODULE_IDENTIFIER: &'static str = "gas_schedule";
    const TYPE_IDENTIFIER: &'static str = "GasScheduleV2";
}

impl OnChainConfig for StorageGasSchedule {
    const MODULE_IDENTIFIER: &'static str = "storage_gas";
    const TYPE_IDENTIFIER: &'static str = "StorageGas";
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_deserialize_map_entries_with_string_values() {
        let json = r#"{
            "feature_version": 42,
            "entries": [
                { "key": "foo", "val": "123" },
                { "key": "bar", "val": 456 },
                { "key": "txn.min_price_per_gas_unit", "val": 50 }
            ]
        }"#
        .to_string();

        let mut schedule = GasScheduleV2::from_json_string(json).unwrap();

        assert_eq!(schedule.feature_version, 42);
        assert_eq!(schedule.entries.len(), 3);
        assert_eq!(schedule.entries[0], ("foo".to_string(), 123));
        assert_eq!(schedule.entries[1], ("bar".to_string(), 456));
        assert_eq!(
            schedule.entries[2],
            ("txn.min_price_per_gas_unit".to_string(), 50)
        );
    }
}
