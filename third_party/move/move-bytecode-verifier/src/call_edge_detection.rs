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
use move_binary_format::file_format::Bytecode;

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

    // Print the function calls and module address from and to in the module
    pub fn call_edges_print(module: &CompiledModule) {
        // Iterate over all the functions in the module
        for function_def in module.function_defs().iter() {
            let function_handle = &module.function_handle_at(function_def.function);
            let function_name = module.identifier_at(function_handle.name);
            println!("Function: {}", function_name);
            // Iterate over all the bytecodes that represent function calls in the function
            if let Some(code) = &function_def.code {
                for bytecode in &code.code {
                    // Case 1: Call instruction; Case 2: CallGeneric instruction
                    match bytecode {
                        Bytecode::Call(handle_index) => {
                            let called_function_handle = module.function_handle_at(*handle_index);
                            let called_function_name = module.identifier_at(called_function_handle.name);
                            let module_id = module.self_id();
                            let source_module = module_id.address();
                            let target_module = module.address_identifiers()[called_function_handle.module.0 as usize];
                            println!(
                                "  Calls: {} from module: {:x} to module: {:x}",
                                called_function_name, source_module, target_module
                            );
                        }
                        Bytecode::CallGeneric(inst_index) => {
                            let inst = module.function_instantiation_at(*inst_index);
                            let called_function_handle = module.function_handle_at(inst.handle);
                            let called_function_name = module.identifier_at(called_function_handle.name);
                            let module_id = module.self_id();
                            let source_module = module_id.address();
                            let target_module = module.address_identifiers()[called_function_handle.module.0 as usize];
                            println!(
                                "  Calls: {} from module: {:x} to module: {:x}",
                                called_function_name, source_module, target_module
                            );
                        }
                        _ => {}
                    }
                }
            }
        }
    }

    //TODO how to add gas metering for distinguishing cross container and in container function call?
    //TODO how the gas should be calculated for cross container function call?
}
