// Copyright (c) 2025 Supra.

//! This module defines the gas parameters for Supra Stdlib.

use crate::gas_schedule::NativeGasParameters;
use aptos_gas_algebra::{InternalGas, InternalGasPerArg};

crate::gas_schedule::macros::define_gas_parameters!(
    SupraStdlibGasParameters,
    "supra_stdlib",
    NativeGasParameters => .supra_stdlib,
    [
        // Note(Gas): this initial value is guesswork.
        [class_groups_per_pubkey_deserialize: InternalGasPerArg, "class.groups.per_pubkey_deserialize", 400684],
        // Note(Gas): this initial value is guesswork.
        [class_groups_pop: InternalGas, "class.groups.base", 206000000],

    ]
);
