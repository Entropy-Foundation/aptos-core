spec supra_framework::evm_config {

    spec module {
        use supra_framework::chain_status;
        pragma verify = true;
        pragma aborts_if_is_strict;
        /// The Evm config does not exist on chain from genesis.
        /// So we do not require below condition.
        // chain_status::is_operating() ==> exists<EvmConfig>(@supra_framework);
    }

    spec set_for_next_epoch(account: &signer, config: vector<u8>) {
        include config_buffer::SetForNextEpochAbortsIf;
    }

    spec on_new_epoch(framework: &signer) {
        requires @supra_framework == std::signer::address_of(framework);
        include config_buffer::OnNewEpochRequirement<EvmConfig>;
        aborts_if false;
    }

}
