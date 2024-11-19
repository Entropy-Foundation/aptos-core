// Copyright (c) The Diem Core Contributors
// Copyright (c) The Move Contributors
// SPDX-License-Identifier: Apache-2.0

//! This module implements a checker for verifying that each vector in a CompiledModule contains
//! distinct values. Successful verification implies that an index in vector can be used to
//! uniquely name the entry at that index. Additionally, the checker also verifies the
//! following:
//! - struct and field definitions are consistent
//! - the handles in struct and function definitions point to the self module index
//! - all struct and function handles pointing to the self module index have a definition
use move_binary_format::{
    access::{ModuleAccess},
    errors::{Location, PartialVMResult, VMResult},
    file_format::{
        CompiledModule
    },
};

pub struct CallEdgeDetector<'a> {
    module: &'a CompiledModule,
}

impl<'a> CallEdgeDetector<'a> {
    pub fn verify_module(module: &'a CompiledModule) -> VMResult<()> {
        Self::verify_module_impl(module).map_err(|e| e.finish(Location::Module(module.self_id())))
    }

    fn verify_module_impl(module: &'a CompiledModule) -> PartialVMResult<()> {
        Self::print_module_addresses(module);
        Self::call_edges_print(module);
        Ok(())
    }

    pub fn print_module_addresses(module: &CompiledModule) {
        println!("Module address: {:?}", module.self_id().address());

        // Print the addresses of all the module's dependencies
        for dep in module.immediate_dependencies() {
            println!("Dependency address: {:?}", dep.address());
        }

        // Print the addresses of all the module's friends
        for friend in module.immediate_friends() {
            println!("Friend address: {:?}", friend.address());
        }
    }

    pub fn call_edges_print(module: &CompiledModule) {
        for function_handle in module.function_handles() {
            let source_module = module.self_id().address;
            let target_module_index = function_handle.module;
            let target_module = module.address_identifiers()[target_module_index.0 as usize];
            println!(
                "Method call from module: {:?} to module: {:?}",
                source_module, target_module
            );
        }
    }

    //TODO how to add gas metering for distinguishing cross container and in container function call?
    //TODO how the gas should be calculated for cross container function call?
}
