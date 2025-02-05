use std::collections::VecDeque;
use std::sync::Arc;
use keccak_hash::{keccak, H256};
use move_vm_types::values::Value;
use move_vm_types::loaded_data::runtime_types::Type;
use eth_trie::{EthTrie, Trie, DB};
use eth_trie::MemoryDB;
use smallvec::{smallvec, SmallVec};
use aptos_native_interface::{safely_pop_arg, safely_pop_vec_arg, RawSafeNative, SafeNativeBuilder, SafeNativeContext, SafeNativeError, SafeNativeResult};
use move_core_types::gas_algebra::InternalGas;
use move_vm_runtime::native_functions::NativeFunction;
use rand::Rng;

/// Abort code when merkle proof is invalid
pub mod abort_codes {
    pub const E_INVALID_PROOF: u64 = 1;
}

/// The minimum length (in bytes) for an encoded node to be stored by hash.
const HASHED_LENGTH: usize = 32;

/// Gas cost parameters for verifying a Merkle proof.
const MERKLE_PROOF_BASE: u64 = 15_000;
const MERKLE_PROOF_PER_NODE: u64 = 20_000;

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
///   - Otherwise, returns `(empty vector, false)` to show the key does not exist.
///   - Returns an error if the proof is invalid
///
/// Gas is charged as a fixed base plus a cost per proof node.
pub fn native_verify_proof_eth_trie(
    context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {

    // First pop the proof (a Vec<Vec<u8>>)
    let proof: Vec<Vec<u8>> = safely_pop_vec_arg!(arguments, Vec<u8>);

    // Next pop the key (a Vec<u8>)
    let key: Vec<u8> = safely_pop_arg!(arguments, Vec<u8>);

    // Finally pop the root (a Vec<u8>)
    let root: Vec<u8> = safely_pop_arg!(arguments, Vec<u8>);

    // Charge gas: base cost plus a per–node cost.
    let total_gas = MERKLE_PROOF_BASE + MERKLE_PROOF_PER_NODE * (proof.len() as u64);
    context.charge(InternalGas::new(total_gas))?;

    // Convert the root (a Vec<u8>) into a H256 hash.
    let root_hash = H256::from_slice(&root);

    // Build a temporary in–memory DB from the proof nodes.
    let memdb = MemoryDB::new(true);
    let db = Arc::new(memdb);
    for node_encoded in proof.iter() {
        let hash: H256 = keccak(&node_encoded).as_fixed_bytes().into();
        // Insert the node if it is the root or if its encoded length is at least HASHED_LENGTH.
        if root_hash.eq(&hash) || node_encoded.len() >= HASHED_LENGTH {
            db.insert(hash.as_bytes(), node_encoded.clone()).unwrap();
        }
    }

    // Create an EthTrie instance using the temporary DB and the given root.
    let trie = EthTrie::new(db).at_root(root_hash);

    // Call the trie’s get method.
    let value_opt = match trie.get(key.as_slice()) {
        Ok(value_opt) => value_opt,
        Err(_) => {
            return Err(SafeNativeError::Abort {
                abort_code: abort_codes::E_INVALID_PROOF,
            })
        },
    };

    // Convert the Option<Vec<u8>> result into a tuple (vector, bool).
    // If Some(val) is returned, we output (val, true); if None, we output (empty vector, false).
    let result = match value_opt {
        Some(val) => smallvec![Value::vector_u8(val), Value::bool(true)],
        None => smallvec![Value::vector_u8(vec![]), Value::bool(false)],
    };

    Ok(result)
}


#[cfg(feature = "testing")]
pub fn native_generate_random_trie(
    _context: &mut SafeNativeContext,
    _ty_args: Vec<Type>,
    mut arguments: VecDeque<Value>,
) -> SafeNativeResult<SmallVec<[Value; 1]>> {
    // 1. Pop argument: number of random keys to insert
    let num_keys: u64 = safely_pop_arg!(arguments, u64);

    // 3. Build a random trie
    let memdb = Arc::new(MemoryDB::new(true));
    let mut trie = EthTrie::new(Arc::clone(&memdb));
    let mut rng = rand::thread_rng();

    // For storing the final data
    let mut all_key_proofs: Vec<Value> = Vec::new();
    let mut all_keys: Vec<Vec<u8>> = Vec::new();

    for _ in 0..num_keys {
        // Generate a random key (and use the same bytes as the value)
        let len: u8 = rng.gen_range(2, 30);
        let random_key: Vec<u8> = (0..len).map(|_| rng.gen()).collect();
        // Insert into trie
        trie.insert(&random_key, &random_key).unwrap();
        all_keys.push(random_key.clone());
    }

    // Grab the final root
    let root = trie.root_hash().unwrap();

    for k in &all_keys {
        let proof = trie.get_proof(k).unwrap();

        // Build a "Value::Vector" representing `[ key, proof_node1, proof_node2, ... ]`
        // 1) Key as a Value::vector_u8
        let mut subvec_items: Vec<Value> = Vec::with_capacity(1 + proof.len());
        subvec_items.push(Value::vector_u8(k.clone()));
        // 2) Each proof node as a Value::vector_u8
        for node in &proof {
            subvec_items.push(Value::vector_u8(node.clone()));
        }
        let subvec_val = Value::vector_for_testing_only(subvec_items);

        all_key_proofs.push(subvec_val);
    }

    // Build the top-level vector
    let big_vector_val = Value::vector_for_testing_only(all_key_proofs);

    // Return `(root_as_vector_u8, big_vector_of_vectors)`
    // so Move sees a pair:  (vector<u8>, vector<vector<vector<u8>>>)
    Ok(smallvec![
        Value::vector_u8(root.as_bytes().to_vec()),
        big_vector_val
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

    #[cfg(feature = "testing")]
    natives.extend([(
        "generate_random_trie",
        native_generate_random_trie as RawSafeNative,
    )]);

    natives.extend([
        (
            "native_verify_proof_eth_trie",
            native_verify_proof_eth_trie as RawSafeNative,
        ),
    ]);

    builder.make_named_natives(natives)
}
