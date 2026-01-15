// Copyright (c) 2025 Supra.

/***************************************************************************************************
 * native fun class_group_validate_pubkey
 *
 *   gas cost: per_pubkey_deserialize_cost + pop_proof_validation
 *
 * where +? indicates that the expression stops evaluating there if the previous gas-charging step
 * failed
 **************************************************************************************************/
use aptos_gas_schedule::gas_params::natives::supra_stdlib::{
    CLASS_GROUPS_PER_PUBKEY_DESERIALIZE, CLASS_GROUPS_POP,
};
use aptos_native_interface::{
    safely_pop_arg, RawSafeNative, SafeNativeBuilder, SafeNativeContext, SafeNativeResult,
};
#[cfg(feature = "testing")]
use crypto::bls12381::cl_utils::rng;
use move_core_types::gas_algebra::NumArgs;
use move_vm_runtime::native_functions::NativeFunction;
use move_vm_types::{loaded_data::runtime_types::Type, values::Value};
use smallvec::{smallvec, SmallVec};
use std::collections::VecDeque;

fn native_class_group_validate_pubkey(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    debug_assert!(_ty_args.is_empty());
    debug_assert!(arguments.len() == 1);

    context.charge(CLASS_GROUPS_PER_PUBKEY_DESERIALIZE * NumArgs::one())?;
    context.charge(CLASS_GROUPS_POP)?;

    let pk_bytes = safely_pop_arg!(arguments, Vec<u8>);
    match crypto::cg_public_key::CGEncryptionKeyBls12381::try_from(pk_bytes.as_slice()) {
        Ok(_) => Ok(smallvec![Value::bool(true)]),
        Err(_) => Ok(smallvec![Value::bool(false)]),
    }
}

#[cfg(feature = "testing")]
pub fn native_generate_keys(
    _context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    _arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    let (sk, pk) = crypto::bls12381::cg_encryption::keygen(&mut rng(), &vec![]).unwrap();

    Ok(smallvec![
        Value::vector_u8(bcs::to_bytes(&sk).unwrap()),
        Value::vector_u8(pk.to_vec()),
    ])
}

/***************************************************************************************************
 * module
 *
 **************************************************************************************************/
pub fn make_all(
    builder: &SafeNativeBuilder,
) -> impl Iterator<Item = (String, NativeFunction)> + '_ {
    let mut natives = vec![];

    natives.extend([(
        "validate_pubkey_internal",
        native_class_group_validate_pubkey as RawSafeNative,
    )]);

    #[cfg(feature = "testing")]
    natives.append(&mut vec![(
        "generate_keys_internal",
        native_generate_keys as RawSafeNative,
    )]);

    builder.make_named_natives(natives)
}
