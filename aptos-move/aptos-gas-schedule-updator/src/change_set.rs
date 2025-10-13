use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub type Entries = HashMap<String, u64>;

/// A set of changes to be applied to a gas schedule.
/// Additions are new entries to be added to the gas schedule.
/// Deletions are entries to be removed from the gas schedule.
/// Mutations are entries to be updated in the gas schedule.
#[derive(Clone, Debug, Deserialize, PartialEq, Eq, Serialize)]
pub struct GasScheduleChangeSet {
    additions: Entries,
    deletions: Entries,
    mutations: Entries,
}

impl GasScheduleChangeSet {

    /// Deserialize a GasScheduleChangeSet from a JSON string.
    pub fn from_json_string(json_str: String) -> anyhow::Result<Self> {
        serde_json::from_str(&json_str).map_err(|e| anyhow::anyhow!(e))
    }

    pub fn deletions(&self) -> &Entries {
        &self.deletions
    }

    pub fn additions(&self) -> &Entries {
        &self.additions
    }

    pub fn mutations(&self) -> &Entries {
        &self.mutations
    }

    /// Returns true if the change set is empty.
    pub fn is_empty(&self) -> bool {
        self.additions.is_empty() && self.deletions.is_empty() && self.mutations.is_empty()
    }

    /// Returns true if the change set contains any additions or deletions.
    /// This indicates that a feature version bump is required.
    /// A mutation alone does not require a feature version bump.
    // Check `aptos-core/aptos-move/aptos-gas-schedule/src/ver.rs` for more context.
    pub fn should_bump_feature_version(&self) -> bool {
        !self.additions.is_empty() || !self.deletions.is_empty()
    }
}

#[test]
// Test deserialization of GasScheduleChangeSet from JSON string.
fn test_deserialize_change_set() {
    let json = r#"{
        "additions": {
             "foo": 123,
             "bar": 100999
        },
        "deletions": {
            "bar": 456
        },
        "mutations": {
            "foo": 789
        }
    }"#
    .to_string();

    let change_set = GasScheduleChangeSet::from_json_string(json).unwrap();

    assert_eq!(change_set.additions.len(), 2);
    assert_eq!(change_set.deletions.len(), 1);
    assert_eq!(change_set.mutations.len(), 1);
    assert_eq!(change_set.additions.get("foo").unwrap(), &123u64);
    assert_eq!(change_set.additions.get("bar").unwrap(), &100999u64);
    assert_eq!(change_set.deletions.get("foo").unwrap(), &789u64);
}
