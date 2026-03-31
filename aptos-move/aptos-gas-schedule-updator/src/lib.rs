// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

//! This crate implements a script for generating governance proposals to update the
//! on-chain gas schedule. It can be used as both a library and a standalone binary.
//!
//! The generated proposal includes a comment section, listing the contents of the
//! gas schedule in a human readable format.

mod change_set;

use crate::change_set::GasScheduleChangeSet;
use anyhow::{anyhow, Result};
use aptos_gas_schedule::{
    AptosGasParameters, InitialGasSchedule, ToOnChainGasSchedule, LATEST_GAS_FEATURE_VERSION,
};
use aptos_package_builder::PackageBuilder;
use aptos_types::on_chain_config::GasScheduleV2;
use clap::{Args, Parser};
use move_core_types::account_address::AccountAddress;
use move_model::{code_writer::CodeWriter, emit, emitln, model::Loc};
use std::fs;
use std::path::{Path, PathBuf};

const DEFAULT_GAS_SCHEDULE_SCRIPT_UPDATE_PATH: &str = "./proposals";

fn generate_blob(writer: &CodeWriter, data: &[u8]) {
    emitln!(writer, "vector[");
    writer.indent();
    for (i, b) in data.iter().enumerate() {
        if i % 20 == 0 {
            if i > 0 {
                emitln!(writer);
            }
        } else {
            emit!(writer, " ");
        }
        emit!(writer, "{},", b);
    }
    emitln!(writer);
    writer.unindent();
    emit!(writer, "]")
}

fn generate_script(gas_schedule: &GasScheduleV2) -> Result<String> {
    let gas_schedule_blob = bcs::to_bytes(gas_schedule)?;

    assert!(gas_schedule_blob.len() < 65536);

    let writer = CodeWriter::new(Loc::default());
    emitln!(writer, "// Gas schedule update proposal\n");

    emitln!(
        writer,
        "// Feature version: {}",
        gas_schedule.feature_version
    );
    emitln!(writer, "//");
    emitln!(writer, "// Entries:");
    let max_len = gas_schedule
        .entries
        .iter()
        .fold(0, |acc, (name, _)| usize::max(acc, name.len()));
    for (name, val) in &gas_schedule.entries {
        let name_with_spaces = format!("{}{}", name, " ".repeat(max_len - name.len()));
        emitln!(writer, "//     {} : {}", name_with_spaces, val);
    }
    emitln!(writer);

    emitln!(writer, "script {");
    writer.indent();

    emitln!(writer, "use supra_framework::supra_governance;");
    emitln!(writer, "use supra_framework::gas_schedule;");
    emitln!(writer);

    emitln!(writer, "fun main(proposal_id: u64) {");
    writer.indent();

    emitln!(
        writer,
        "let framework_signer = supra_governance::supra_resolve(proposal_id, @{});\n",
        AccountAddress::ONE,
    );

    emit!(writer, "let gas_schedule_blob: vector<u8> = ");
    generate_blob(&writer, &gas_schedule_blob);
    emitln!(writer, ";\n");

    emitln!(
        writer,
        "gas_schedule::set_for_next_epoch(&framework_signer, gas_schedule_blob);"
    );
    emitln!(writer, "supra_governance::reconfigure(&framework_signer);");

    writer.unindent();
    emitln!(writer, "}");

    writer.unindent();
    emitln!(writer, "}");

    Ok(writer.process_result(|s| s.to_string()))
}

fn aptos_framework_path() -> PathBuf {
    Path::join(
        Path::new(env!("CARGO_MANIFEST_DIR")),
        "../framework/supra-framework",
    )
}

/// Command line interface for the gas schedule update proposal generation tool.
/// It supports two modes:
/// 1. Generate a new gas schedule from the current hardcoded values.
/// 2. Update an existing gas schedule with a change set.
/// The generated proposal is written to a Move package in the specified output directory.
/// If no output directory is specified, it defaults to `./proposals`.
/// The generated package contains a single Move script `update_gas_schedule.move`.
/// This script can be submitted as a governance proposal to update the on-chain gas schedule.
/// The script includes a comment section listing the contents of the gas schedule in a human readable format.
#[derive(Parser, Debug)]
pub enum GasScheduleGenerator {
    /// Generate a new gas schedule from the current hardcoded values.
    /// Optionally specify the feature version of the gas schedule.
    /// If not specified, it defaults to the latest feature version.
    GenerateNew(GenerateNewSchedule),
    /// Update an existing gas schedule with a change set.
    /// The change set is specified in a JSON file.
    /// The current gas schedule is also specified in a JSON file.
    /// The change set can include additions, deletions, and mutations of gas parameters.
    /// If the change set includes any additions or deletions, the feature version of the gas
    /// schedule is bumped by 1.
    UpdateSchedule(UpdateSchedule),
}

/// Command line arguments to the gas schedule update proposal generation tool.
#[derive(Debug, Args)]
pub struct GenerateNewSchedule {
    /// Path to file to write the output script.
    /// If not specified, it defaults to `./proposals`.
    #[clap(short, long, help = "Path to file to write the output script")]
    pub output: Option<String>,

    /// Feature version of the gas schedule to generate.
    /// If not specified, it defaults to the latest feature version.
    #[clap(short, long, help = "Feature version of the GasSchedule generated")]
    pub gas_feature_version: Option<u64>,
}

impl GenerateNewSchedule {
    pub fn execute(self) -> Result<()> {
        let feature_version = self
            .gas_feature_version
            .unwrap_or(LATEST_GAS_FEATURE_VERSION);

        let gas_schedule = current_gas_schedule(feature_version);

        generate_update_proposal(
            &gas_schedule,
            self.output
                .unwrap_or_else(|| DEFAULT_GAS_SCHEDULE_SCRIPT_UPDATE_PATH.to_string()),
        )
    }
}

#[derive(Parser, Debug)]
pub struct UpdateSchedule {
    /// Path to file to write the output script.
    /// If not specified, it defaults to `./proposals`.
    #[clap(short, long, help = "Path to file to write the output script")]
    pub output: Option<String>,

    /// Path to JSON file containing the current GasScheduleV2 to update.
    /// The JSON file should be in the format produced by the `to_json_string` method
    /// of the `GasScheduleV2` struct.
    #[clap(
        short,
        long,
        help = "Path to JSON file containing the GasScheduleV2 to update"
    )]
    pub current_schedule_path: String,

    /// Path to JSON file containing the change set to apply to the current GasScheduleV2.
    /// The JSON file should be in the format produced by the `to_json_string` method
    /// of the `GasScheduleChangeSet` struct.
    #[clap(
        short,
        long,
        help = "Path to JSON file containing change set to the GasScheduleV2"
    )]
    pub change_set_path: String,
}

impl UpdateSchedule {
    pub fn execute(self) -> Result<()> {
        let change_set_json_str = fs::read_to_string(self.change_set_path)?;
        let change_set = GasScheduleChangeSet::from_json_string(change_set_json_str)?;

        if change_set.is_empty() {
            return Err(anyhow::anyhow!("The change set is empty"));
        }

        let current_schedule_json_str = fs::read_to_string(self.current_schedule_path)?;
        let mut current_schedule = GasScheduleV2::from_json_string(current_schedule_json_str)?;

        // Apply additions to the gas schedule
        for (name, value) in change_set.additions().iter() {
            if current_schedule
                .entries
                .iter()
                .any(|entry| entry.0 == *name && entry.1 == *value)
            {
                return Err(anyhow!(
                    "Addition entry ({}, {}) is already found in GasSchedule",
                    name,
                    value
                ));
            }

            current_schedule.entries.push((name.clone(), *value));
        }

        // Apply deletions to existing entries in the gas schedule
        for (name, value) in change_set.deletions().iter() {
            if let Some(position) = current_schedule
                .entries
                .iter()
                .position(|entry| entry.0 == *name && entry.1 == *value)
            {
                current_schedule.entries.remove(position);
            } else {
                return Err(anyhow!(
                    "Deletion entry ({}, {}) not found in GasSchedule",
                    name,
                    value
                ));
            }
        }

        // Apply mutations to existing entries in the gas schedule
        for (name, value) in change_set.mutations().iter() {
            if let Some(position) = current_schedule
                .entries
                .iter()
                .position(|entry| entry.0 == *name )
            {
                // Remove old entry and insert new entry
                current_schedule.entries.remove(position);
                current_schedule.entries.push((name.clone(), *value));
            } else {
                return Err(anyhow!(
                    "Mutation entry ({}, {}) not found in GasSchedule",
                    name,
                    value
                ));
            }
        }


        // Sort the entries by name to ensure deterministic order
        current_schedule.entries.sort_by(|a, b| a.0.cmp(&b.0));
        // Ensure no duplicate entries exist
        let mut seen = std::collections::HashSet::new();
        for (name, _) in &current_schedule.entries {
            if !seen.insert(name) {
                return Err(anyhow!("Duplicate entry ({}) found in GasSchedule", name));
            }
        }

        // Bump the feature version if we are adding or removing params
        if change_set.should_bump_feature_version() {
            let new_feature_version = current_schedule
                .feature_version
                .checked_add(1)
                .ok_or_else(|| anyhow!("Overflow when bumping feature version"))?;
            current_schedule.feature_version = new_feature_version;
        }

        println!(
            "Updated gas schedule to feature version {}",
            current_schedule.feature_version
        );

        // Generate the update proposal script
        generate_update_proposal(
            &current_schedule,
            self.output
                .unwrap_or_else(|| DEFAULT_GAS_SCHEDULE_SCRIPT_UPDATE_PATH.to_string()),
        )
    }
}

/// Constructs the current gas schedule in on-chain format.
pub fn current_gas_schedule(feature_version: u64) -> GasScheduleV2 {
    GasScheduleV2 {
        feature_version,
        entries: AptosGasParameters::initial().to_on_chain_gas_schedule(feature_version),
    }
}

/// Entrypoint for the update proposal generation tool.
pub fn generate_update_proposal(gas_schedule: &GasScheduleV2, output_path: String) -> Result<()> {
    let mut pack = PackageBuilder::new("GasScheduleUpdate");

    pack.add_source("update_gas_schedule.move", &generate_script(gas_schedule)?);
    // TODO: use relative path here
    pack.add_local_dep("SupraFramework", &aptos_framework_path().to_string_lossy());

    pack.write_to_disk(PathBuf::from(output_path))?;

    Ok(())
}

impl GasScheduleGenerator {
    pub fn execute(self) -> Result<()> {
        match self {
            GasScheduleGenerator::GenerateNew(args) => args.execute(),
            GasScheduleGenerator::UpdateSchedule(args) => args.execute(),
        }
    }
}
