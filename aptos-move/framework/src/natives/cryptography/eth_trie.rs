use std::collections::VecDeque;
use std::sync::Arc;

use keccak_hash::{keccak, H256};
use move_core_types::vm_status::StatusCode;
use move_vm_types::values::{Struct, Value};
use move_vm_types::loaded_data::runtime_types::Type;

use eth_trie::{EthTrie, Trie, DB};
use eth_trie::MemoryDB;
use smallvec::{smallvec, SmallVec};
use move_binary_format::errors::PartialVMError;
use aptos_native_interface::{safely_pop_arg, safely_pop_vec_arg, SafeNativeBuilder, SafeNativeContext, SafeNativeResult};
use move_core_types::gas_algebra::InternalGas;
use move_vm_runtime::native_functions::NativeFunction;

/// The minimum length (in bytes) for an encoded node to be stored by hash.
const HASHED_LENGTH: usize = 32;

/// Gas cost parameters for verifying a Merkle proof.
const MERKLE_PROOF_BASE: u64 = 100;
const MERKLE_PROOF_PER_NODE: u64 = 10;

/// Pops a `Vec<T>` off the argument stack and converts it to a `Vec<Vec<u8>>` by reading the first
/// field of `T`, which is a `Vec<u8>` field named `bytes`.
fn pop_as_vec_of_vec_u8(arguments: &mut VecDeque<Value>) -> SafeNativeResult<Vec<Vec<u8>>> {
    let structs = safely_pop_vec_arg!(arguments, Struct);
    let mut v = Vec::with_capacity(structs.len());

    for s in structs {
        let field = s
            .unpack()?
            .next()
            .ok_or_else(|| PartialVMError::new(StatusCode::INTERNAL_TYPE_ERROR))?;

        v.push(field.value_as::<Vec<u8>>()?);
    }

    Ok(v)
}

/// Native function for verifying an Ethereum Merkle Patricia Trie proof.
///
/// # Arguments
///
///   1. `proof`: A vector of RLP–encoded trie nodes (`Vec<Vec<u8>>`)
///   2. `key`: The key to be looked up (`Vec<u8>`)
///   3. `root`: The trie root hash (a 32-byte vector, i.e. `Vec<u8>`)
///
/// # Returns
///
/// A tuple of `(vector<u8>, bool)` where:
///   - If the proof is valid and the key exists, returns `(value, true)` (with `value` being the found value).
///   - Otherwise, returns `(empty vector, false)`.
///
/// Gas is charged as a fixed base plus a cost per proof node.
pub fn native_verify_proof_eth_trie(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    // Pop arguments in reverse order:
    // First pop the proof (a Vec<Vec<u8>>)
    let proof: Vec<Vec<u8>> = pop_as_vec_of_vec_u8(&mut arguments)?;
    // Next pop the key (a Vec<u8>)
    let key: Vec<u8> = safely_pop_arg!(arguments, Vec<u8>);
    // Finally pop the root (a Vec<u8>)
    let root: Vec<u8> = safely_pop_arg!(arguments, Vec<u8>);

    // Charge gas: base cost plus a per–node cost.
    let total_gas = MERKLE_PROOF_BASE + MERKLE_PROOF_PER_NODE * (proof.len() as u64);
    context.charge(InternalGas::new(total_gas))?;

    // Convert the root (a Vec<u8>) into a B256 hash.
    let root_hash = H256::from_slice(&root);

    // Build a temporary in–memory DB from the proof nodes.
    let memdb = MemoryDB::new(true);
    let db = Arc::new(memdb);
    for node_encoded in proof.iter() {
        let hash: H256 = keccak(&node_encoded).as_fixed_bytes().into();
        // Insert the node if it is the root or if its encoded length is at least HASHED_LENGTH.
        if root_hash.eq(&hash) || node_encoded.len() >= HASHED_LENGTH {
            db.insert(hash.as_bytes(), node_encoded.clone())
                .map_err(|_| PartialVMError::new(StatusCode::VERIFICATION_ERROR))?;
        }
    }

    // Create an EthTrie instance using the temporary DB and the given root.
    let trie = EthTrie::new(db).at_root(root_hash);

    // Call the trie’s verify_proof method.
    let value_opt = trie.get(key.as_slice())
        .map_err(|_| PartialVMError::new(StatusCode::VERIFICATION_ERROR))?;

    // Convert the Option<Vec<u8>> result into a tuple (vector, bool).
    // If Some(val) is returned, we output (val, true); if None, we output (empty vector, false).
    let result = match value_opt {
        Some(val) => smallvec![Value::vector_u8(val), Value::bool(true)],
        None => smallvec![Value::vector_u8(vec![]), Value::bool(false)],
    };

    Ok(result)
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
        (
            "native_verify_proof_eth_trie",
            native_verify_proof_eth_trie,
        ),
    ]);

    builder.make_named_natives(natives)
}
