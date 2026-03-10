module supra_framework::evm_contracts_details {

    use std::error;
    use std::string::String;
    use std::vector;
    use aptos_std::simple_map;
    use aptos_std::simple_map::SimpleMap;
    use supra_framework::config_buffer;
    use supra_framework::event;
    use supra_framework::system_addresses;

    friend  supra_framework::genesis;
    friend  supra_framework::reconfiguration_with_dkg;

    /// Empty keys/values to update config.
    const EEMPTY_DATA: u64 = 1;

    /// Input keys and values should have the same amount of data
    const EKEYS_VALUES_MISMATCH: u64 = 2;

    #[event]
    struct EvmContractsDetails has key, store, copy, drop {
        details: SimpleMap<String, address>,
    }

    /// Publishes the EvmContractInfo details.
    public(friend) fun initialize(
        supra_framework: &signer, keys: vector<String>, values: vector<address>
    ) {
        system_addresses::assert_supra_framework(supra_framework);
        assert!(!vector::is_empty(&keys), error::invalid_argument(EEMPTY_DATA));
        assert!(vector::length(&keys) == vector::length(&values), error::invalid_argument(EKEYS_VALUES_MISMATCH));
        let contract_details = EvmContractsDetails {
            details: simple_map::new_from(keys, values)
        };
        move_to(supra_framework, contract_details);
        event::emit(contract_details);
    }

    /// This can be called by on-chain governance to update on-chain evm contract details for the next epoch.
    /// Keys and values will match in lenght and should not be empty, otherwise the call will fail.
    /// Example usage:
    /// ```
    /// supra_framework::evm_genesis_config::set_for_next_epoch(&framework_signer, vector["contact1_name"], [contract1_address]);
    /// supra_framework::supra_governance::reconfigure(&framework_signer);
    /// ```
    public fun upset_for_next_epoch(account: &signer, keys: vector<String>, values: vector<address>) acquires EvmContractsDetails {
        system_addresses::assert_supra_framework(account);
        assert!(!vector::is_empty(&keys), error::invalid_argument(EEMPTY_DATA));
        assert!(vector::length(&keys) == vector::length(&values), error::invalid_argument(EKEYS_VALUES_MISMATCH));
        if (!exists<EvmContractsDetails>(@supra_framework)) {
            std::config_buffer::upsert<EvmContractsDetails>(EvmContractsDetails { details: simple_map::new_from(keys, values) });
            return
        };
        let updated_config = *borrow_global<EvmContractsDetails>(@supra_framework);
        vector::zip(keys, values, |key, value| {
           simple_map::upsert(&mut updated_config.details, key, value);
        });
        std::config_buffer::upsert<EvmContractsDetails>(updated_config);
    }

    /// Only used in reconfigurations to apply the pending `EvmContractDetails` in buffer, if there is any.
    /// If supra_framework has a EvmContractDetails, then update the new config to supra_framework.
    /// Otherwise, move the new config to supra_framework.
    public(friend) fun on_new_epoch(framework: &signer) acquires EvmContractsDetails {
        system_addresses::assert_supra_framework(framework);
        if (config_buffer::does_exist<EvmContractsDetails>()) {
            let new_config = config_buffer::extract<EvmContractsDetails>();
            if (!exists<EvmContractsDetails>(@supra_framework)) {
                move_to(framework, new_config);
            } else  {
                let  old_config = borrow_global_mut<EvmContractsDetails>(@supra_framework);
                *old_config = new_config;
            };
            event::emit(new_config)
        }
    }
}
