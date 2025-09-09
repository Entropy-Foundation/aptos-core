use std::collections::VecDeque;
use byteorder::{LittleEndian, WriteBytesExt};
use smallvec::{smallvec, SmallVec};
use aptos_gas_schedule::gas_params::natives::aptos_framework::{VEC_UTILS_ENCODE_DECODE_BASE, VEC_UTILS_ENCODE_DECODE_PER_BYTE};
use aptos_native_interface::{safely_pop_vec_arg, RawSafeNative, SafeNativeBuilder, SafeNativeContext, SafeNativeError, SafeNativeResult};
use move_core_types::gas_algebra::NumBytes;
use move_vm_runtime::native_functions::NativeFunction;
use move_vm_types::loaded_data::runtime_types::Type;
use move_vm_types::values::Value;

const E_ENCODE_FAILURE: u64 = 0x1;

/// Helper function to serialize a Vec<Vec<u8>> into a flat Vec<u8>.
fn flatten_nested_vec_to_vec(context: &mut SafeNativeContext,
                             _ty_args: Vec<Type>,
                             mut args: VecDeque<Value>) -> SafeNativeResult<SmallVec<[Value; 1]>> {

    let data: Vec<Vec<u8>> = safely_pop_vec_arg!(args, Vec<u8>);
    context.charge(
        VEC_UTILS_ENCODE_DECODE_BASE+
            VEC_UTILS_ENCODE_DECODE_PER_BYTE * NumBytes::new(data.len() as u64)
    )?;

    let encoded_data = flatten_nested_vec_to_vec_inner(data)?;
    Ok(smallvec![Value::vector_u8(encoded_data)])
}

pub fn flatten_nested_vec_to_vec_inner(data: Vec<Vec<u8>>) -> Result<Vec<u8>, SafeNativeError> {

    let mut serialized = Vec::new();
    for inner_vec in data {
        let len = inner_vec.len() as u32;
        // Write length as 4-byte u32 in little-endian
        serialized
            .write_u32::<LittleEndian>(len)
            .map_err(|_| SafeNativeError::Abort {
                abort_code: E_ENCODE_FAILURE,
            })?;
        // Append the inner vector's data
        serialized.extend_from_slice(&inner_vec);
    }
    Ok(serialized)
}

pub fn make_all(
    builder: &SafeNativeBuilder,
) -> impl Iterator<Item = (String, NativeFunction)> + '_ {
    let mut natives = vec![];

    natives.extend([
        ("native_flatten_nested_vec_to_vec", flatten_nested_vec_to_vec as RawSafeNative),
    ]);

    builder.make_named_natives(natives)
}

