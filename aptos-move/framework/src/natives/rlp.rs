use std::collections::VecDeque;
use smallvec::{smallvec, SmallVec};
use aptos_gas_schedule::gas_params::natives::aptos_framework::{RLP_ENCODE_DECODE_BASE, RLP_ENCODE_DECODE_PER_BYTE};
use aptos_native_interface::{safely_pop_arg, RawSafeNative, SafeNativeBuilder, SafeNativeContext, SafeNativeError, SafeNativeResult};
use move_core_types::gas_algebra::{NumBytes};
use move_vm_runtime::native_functions::NativeFunction;
use move_vm_types::loaded_data::runtime_types::Type;
use move_vm_types::values::Value;

pub const E_DECODE_FAILURE: u64 = 0x1;

pub fn native_rlp_encode(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {

    let data: Vec<u8> = safely_pop_arg!(arguments, Vec<u8>);
    context.charge(RLP_ENCODE_DECODE_BASE + RLP_ENCODE_DECODE_PER_BYTE * NumBytes::new(data.len() as u64))?;
    let encoded_data = rlp::encode(&data);
    Ok(smallvec![Value::vector_u8(encoded_data.to_vec())])
}

pub fn native_rlp_decode(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {

    let encoded_data: Vec<u8> = safely_pop_arg!(arguments, Vec<u8>);
    context.charge(RLP_ENCODE_DECODE_BASE + RLP_ENCODE_DECODE_PER_BYTE * NumBytes::new(encoded_data.len() as u64))?;

    // Attempt RLP decode
    match rlp::decode::<Vec<u8>>(&encoded_data) {
        Ok(decoded_bytes) => {
            Ok(smallvec![Value::vector_u8(decoded_bytes)])
        },
        Err(_e) => {
            Err(SafeNativeError::Abort {
                abort_code: E_DECODE_FAILURE,
            })
        }
    }
}

pub fn make_all(
    builder: &SafeNativeBuilder,
) -> impl Iterator<Item = (String, NativeFunction)> + '_ {
    let mut natives = vec![];

    natives.extend([
        (
            "native_rlp_encode",
            native_rlp_encode as RawSafeNative,
        ),
        (
            "native_rlp_decode",
            native_rlp_decode as RawSafeNative,
        ),
    ]);

    builder.make_named_natives(natives)
}
