/// Simulates a third-party smart contract (e.g. a DeFi protocol) that registers
/// automation tasks by calling the public `register_without_validation` API.
///
/// In production a DeFi contract would call `automation_registry::register_without_validation`
/// from inside its own module logic.  This module exposes a thin entry-function wrapper so
/// that the Rust e2e test harness can invoke it as a regular signed transaction.
module automation_test::automation_contract_test {
    use supra_framework::automation_registry;

    /// Entry-function wrapper that delegates to `register_without_validation`.
    /// All arguments are forwarded verbatim; the tx_hash is captured automatically
    /// from the native transaction context inside the callee.
    public entry fun register_via_contract(
        owner: &signer,
        payload_tx: vector<u8>,
        expiry_time: u64,
        max_gas_amount: u64,
        gas_price_cap: u64,
        automation_fee_cap_for_epoch: u64,
        aux_data: vector<vector<u8>>,
    ) {
        automation_registry::register_without_validation(
            owner,
            payload_tx,
            expiry_time,
            max_gas_amount,
            gas_price_cap,
            automation_fee_cap_for_epoch,
            aux_data,
        )
    }
}
