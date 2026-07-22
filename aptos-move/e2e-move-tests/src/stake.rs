// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

use crate::harness::MoveHarness;
use aptos_cached_packages::aptos_stdlib;
use aptos_crypto::{
    bls12381, bls12381::ProofOfPossession, ed25519, PrivateKey, SigningKey, Uniform,
};
use aptos_language_e2e_tests::account::Account;
use aptos_types::{
    account_address::AccountAddress, account_config::CORE_CODE_ADDRESS,
    on_chain_config::ValidatorSet, stake_pool::StakePool, transaction::TransactionStatus,
    validator_config::ValidatorConfig, validator_public_keys::ValidatorPublicKeys,
};
use move_core_types::parser::parse_struct_tag;

// Used for generating the consesus pub key while doing rotate consensus key
pub fn generate_consensus_pub_key() -> Vec<u8> {
    let mut rng = rand::thread_rng();
    let network_key = ed25519::PrivateKey::generate_for_testing();
    let network_pubkey_bytes = network_key.public_key().to_bytes().to_vec();

    let bls_key = bls12381::PrivateKey::generate(&mut rng);
    let bls_pub_key = bls12381::PublicKey::from(&bls_key);
    let bls_pubkey_bytes = bls_pub_key.to_bytes().to_vec();

    let cg_pubkey_bytes = {
        let mut cg_rng = crypto::bls12381::cl_utils::rng();
        crypto::bls12381::cg_encryption::keygen(&mut cg_rng, &[])
            .expect("CG keygen must succeed")
            .1
            .to_vec()
    };

    let pop = ProofOfPossession::create_with_pubkey(&bls_key, &bls_pub_key);
    let supra_ed_key = ed25519::PrivateKey::generate_for_testing();
    let supra_ed_pubkey_bytes = supra_ed_key.public_key().to_bytes().to_vec();

    // When SUPRA_BLS_KEYS feature is enabled (default), the genesis validator key must be
    // BCS-encoded ValidatorPublicKeys, not a plain ed25519 key.
    let validator_public_keys = ValidatorPublicKeys::new(
        network_pubkey_bytes,
        bls_pubkey_bytes,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        cg_pubkey_bytes,
        supra_ed_pubkey_bytes,
    );
    let mut consensus_pubkey =
        bcs::to_bytes(&validator_public_keys).expect("ValidatorPublicKeys must serialize");
    let mut pop_bytes = pop.to_bytes().to_vec();
    consensus_pubkey.append(&mut pop_bytes);
    let consensus_pub_key_with_pop = consensus_pubkey;
    consensus_pub_key_with_pop
}

pub fn setup_staking(
    harness: &mut MoveHarness,
    account: &Account,
    initial_stake_amount: u64,
) -> TransactionStatus {
    let address = *account.address();
    initialize_staking(harness, account, initial_stake_amount, address, address);
    rotate_consensus_key(harness, account, address);
    join_validator_set(harness, account, address)
}

pub fn initialize_staking(
    harness: &mut MoveHarness,
    account: &Account,
    initial_stake_amount: u64,
    operator_address: AccountAddress,
    voter_address: AccountAddress,
) -> TransactionStatus {
    harness.run_transaction_payload(
        account,
        aptos_stdlib::stake_initialize_stake_owner(
            initial_stake_amount,
            operator_address,
            voter_address,
        ),
    )
}

pub fn add_stake(harness: &mut MoveHarness, account: &Account, amount: u64) -> TransactionStatus {
    harness.run_transaction_payload(account, aptos_stdlib::stake_add_stake(amount))
}

pub fn unlock_stake(
    harness: &mut MoveHarness,
    account: &Account,
    amount: u64,
) -> TransactionStatus {
    harness.run_transaction_payload(account, aptos_stdlib::stake_unlock(amount))
}

pub fn withdraw_stake(
    harness: &mut MoveHarness,
    account: &Account,
    amount: u64,
) -> TransactionStatus {
    harness.run_transaction_payload(account, aptos_stdlib::stake_withdraw(amount))
}

pub fn join_validator_set(
    harness: &mut MoveHarness,
    account: &Account,
    pool_address: AccountAddress,
) -> TransactionStatus {
    harness.run_transaction_payload(
        account,
        aptos_stdlib::stake_join_validator_set(pool_address),
    )
}

pub fn rotate_consensus_key(
    harness: &mut MoveHarness,
    account: &Account,
    pool_address: AccountAddress,
) -> TransactionStatus {
    // let consensus_key = ed25519::PrivateKey::generate_for_testing();
    let consensus_pubkey = generate_consensus_pub_key();
    harness.run_transaction_payload(
        account,
        aptos_stdlib::stake_rotate_consensus_key(pool_address, consensus_pubkey),
    )
}

pub fn leave_validator_set(
    harness: &mut MoveHarness,
    account: &Account,
    pool_address: AccountAddress,
) -> TransactionStatus {
    harness.run_transaction_payload(
        account,
        aptos_stdlib::stake_leave_validator_set(pool_address),
    )
}

pub fn increase_lockup(harness: &mut MoveHarness, account: &Account) -> TransactionStatus {
    harness.run_transaction_payload(account, aptos_stdlib::stake_increase_lockup())
}

pub fn get_stake_pool(harness: &MoveHarness, pool_address: &AccountAddress) -> StakePool {
    harness
        .read_resource::<StakePool>(
            pool_address,
            parse_struct_tag("0x1::stake::StakePool").unwrap(),
        )
        .unwrap()
}

pub fn get_validator_config(
    harness: &MoveHarness,
    pool_address: &AccountAddress,
) -> ValidatorConfig {
    harness
        .read_resource::<ValidatorConfig>(
            pool_address,
            parse_struct_tag("0x1::stake::ValidatorConfig").unwrap(),
        )
        .unwrap()
}

pub fn get_validator_set(harness: &MoveHarness) -> ValidatorSet {
    harness
        .read_resource::<ValidatorSet>(
            &CORE_CODE_ADDRESS,
            parse_struct_tag("0x1::stake::ValidatorSet").unwrap(),
        )
        .unwrap()
}
