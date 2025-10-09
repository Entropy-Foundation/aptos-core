use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type Entries = HashMap<String, u64>;

#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct GasScheduleChangeSet {
    additions: Entries,
    deletions: Entries,
}

impl GasScheduleChangeSet {
    pub fn from_json_string(json_str: String) -> anyhow::Result<Self> {
        serde_json::from_str(&json_str).map_err(|e| anyhow::anyhow!(e))
    }

    pub fn deletions(&self) -> &Entries {
        &self.deletions
    }

    pub fn additions(&self) -> &Entries {
        &self.additions
    }

    pub fn deletion_entries(&self) -> &Entries {
        self.deletions()
    }

    pub fn addition_entries(&self) -> &Entries {
        self.additions()
    }

    pub fn is_empty(&self) -> bool {
        self.additions.is_empty() && self.deletions.is_empty()
    }
}

#[test]
fn test_deserialize_change_set() {
    let json = r#"{
        "additions": {
             "foo": 123,
             "bar": 600999
        },
        "deletions": {
            "bar": 456
        }
    }"#
    .to_string();

    let change_set = GasScheduleChangeSet::from_json_string(json).unwrap();

    assert_eq!(change_set.additions.len(), 2);
    assert_eq!(change_set.deletions.len(), 1);
    assert_eq!(change_set.additions.get("foo").unwrap(), &123u64);
    assert_eq!(change_set.additions.get("bar").unwrap(), &600999u64);
    assert_eq!(change_set.deletions.get("bar").unwrap(), &456u64);
}
