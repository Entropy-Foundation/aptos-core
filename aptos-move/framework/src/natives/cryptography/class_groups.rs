

/***************************************************************************************************
 * native fun class_group_validate_pubkey
 *
 *   gas cost: base_cost + per_pubkey_deserialize_cost +? pop_proof_validation
 *
 * where +? indicates that the expression stops evaluating there if the previous gas-charging step
 * failed
 **************************************************************************************************/
use std::collections::VecDeque;
use smallvec::{smallvec, SmallVec};
use aptos_gas_schedule::gas_params::natives::aptos_framework::BLS12381_BASE;
use aptos_native_interface::{safely_pop_arg, RawSafeNative, SafeNativeBuilder, SafeNativeContext, SafeNativeResult};
use move_vm_runtime::native_functions::NativeFunction;
use move_vm_types::loaded_data::runtime_types::Type;
use move_vm_types::values::Value;
#[cfg(feature = "testing")]
use crypto::bls12381::utils::{cpp_rng, get_cl};

fn native_class_group_validate_pubkey(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    debug_assert!(_ty_args.is_empty());
    debug_assert!(arguments.len() == 1);

    //todo: update gas cost
    context.charge(BLS12381_BASE)?;

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
    mut _arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {

    let cl = get_cl();
    let mut cpp_rng = cpp_rng();
    let (sk, pk) = crypto::bls12381::cg_encryption::keygen(&cl, &mut cpp_rng, &vec![]);

    Ok(smallvec![
        Value::vector_u8(sk.to_bytes()),
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

    natives.extend([
        ("validate_pubkey_internal", native_class_group_validate_pubkey as RawSafeNative),
    ]);

    #[cfg(feature = "testing")]
    natives.append(&mut vec![
        ("generate_keys_internal", native_generate_keys as RawSafeNative),
    ]);

    builder.make_named_natives(natives)
}
