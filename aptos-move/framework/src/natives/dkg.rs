use std::collections::VecDeque;
use smallvec::{smallvec, SmallVec};
use aptos_native_interface::{safely_pop_arg, RawSafeNative, SafeNativeBuilder, SafeNativeContext, SafeNativeResult};
use move_vm_runtime::native_functions::NativeFunction;
use move_vm_types::loaded_data::runtime_types::Type;
use move_vm_types::values::Value;

fn native_get_family_committee_indices(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    debug_assert!(_ty_args.is_empty());
    debug_assert!(arguments.len() == 2);

    //todo: charge gas
    //context.charge(GAS_COST)?;

    let seed = safely_pop_arg!(arguments, Vec<u8>);
    let tribe_size = safely_pop_arg!(arguments, u32);

    match crypto::utils::get_family_node_indices(tribe_size, seed) {
        Some(family_indices) => {
            let family_indices_u32: Vec<u32> = family_indices.iter().map(|&x| x as u32).collect();
            Ok(smallvec![Value::vector_u32(family_indices_u32)])
        },
        None => Ok(smallvec![Value::vector_u32(vec![])])
    }
}

fn native_get_clan_committee_indices(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    debug_assert!(_ty_args.is_empty());
    debug_assert!(arguments.len() == 2);

    //todo: charge gas
    //context.charge(GAS_COST)?;

    let seed = safely_pop_arg!(arguments, Vec<u8>);
    let tribe_size = safely_pop_arg!(arguments, u32);

    match crypto::utils::get_clan_node_indices(tribe_size, seed) {
        Some(clan_indices) => {
            let clan_indices_u32: Vec<u32> = clan_indices.iter().map(|&x| x as u32).collect();
            Ok(smallvec![Value::vector_u32(clan_indices_u32)])
        },
        None => Ok(smallvec![Value::vector_u32(vec![])])
    }
}

pub fn make_all(
    builder: &SafeNativeBuilder,
) -> impl Iterator<Item = (String, NativeFunction)> + '_ {
    let mut natives = vec![];

    natives.extend([
        (
            "native_get_family_committee_indices",
            native_get_family_committee_indices as RawSafeNative,
        ),
        (
            "native_get_clan_committee_indices",
            native_get_clan_committee_indices as RawSafeNative,
        ),
    ]);

    builder.make_named_natives(natives)
}
