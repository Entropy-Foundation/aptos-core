/// Reconfiguration with DKG helper functions.
module supra_framework::reconfiguration_with_dkg {
    use std::dkg_committee::{
        new_dkg_committee_from_validator_consensus_info,
        new_receiver_committee
    };
    use std::features;
    use std::option;
    use std::vector;
    use supra_framework::automation_registry;
    use supra_framework::randomness;
    use supra_framework::consensus_config;
    use supra_framework::dkg;
    use supra_framework::dkg_config;
    use supra_framework::execution_config;
    use supra_framework::gas_schedule;
    use supra_framework::jwk_consensus_config;
    use supra_framework::jwks;
    use supra_framework::keyless_account;
    use supra_framework::leader_ban_registry_config;
    use supra_framework::randomness_api_v0_config;
    use supra_framework::randomness_config;
    use supra_framework::randomness_config_seqnum;
    use supra_framework::reconfiguration;
    use supra_framework::reconfiguration_state;
    use supra_framework::stake;
    use supra_framework::supra_config;
    use supra_framework::system_addresses;
    use supra_framework::evm_genesis_config;

    friend supra_framework::block;
    friend supra_framework::supra_governance;

    /// Trigger a reconfiguration with DKG.
    /// Do nothing if one is already in progress.
    public(friend) fun try_start() {
        let incomplete_dkg_session = dkg::incomplete_session();
        if (option::is_some(&incomplete_dkg_session)) {
            let session = option::borrow(&incomplete_dkg_session);
            if (dkg::session_dealer_epoch(session) == reconfiguration::current_epoch()) {
                return
            }
        };
        reconfiguration_state::on_reconfig_start();
        let cur_epoch = reconfiguration::current_epoch();
        let randomness_seed = randomness::bytes(32);

        // Get DKG configuration (dealer threshold type and receiver committee configs)
        let config = dkg_config::current();
        let receiver_configs = dkg_config::get_receiver_committee_configs(&config);

        // Build receiver committees from config
        let receiver_committees = vector[];
        let i = 0;
        let len = vector::length(&receiver_configs);
        while (i < len) {
            let rc = vector::borrow(&receiver_configs, i);
            vector::push_back(
                &mut receiver_committees,
                new_receiver_committee(
                    dkg_config::get_is_resharing(rc),
                    dkg_config::get_dkg_threshold_type(rc),
                    new_dkg_committee_from_validator_consensus_info(
                        stake::next_epoch_validator_consensus_infos_for_dkg(),
                        dkg_config::get_committee_threshold_type(rc)
                    )
                )
            );
            i = i + 1;
        };

        // DKG for configured receiver committees
        dkg::start(
            cur_epoch,
            randomness_seed,
            new_dkg_committee_from_validator_consensus_info(
                stake::cur_validator_consensus_infos(),
                dkg_config::get_dealer_committee_threshold_type(&config)
            ),
            receiver_committees
        );
    }

    fun set_dkg_meta(dkg_meta: vector<u8>) {
        dkg::set_dkg_meta(dkg_meta);
    }

    /// Clear incomplete DKG session, if it exists.
    /// Apply buffered on-chain configs (except for ValidatorSet, which is done inside `reconfiguration::reconfigure()`).
    /// Re-enable validator set changes.
    /// Run the default reconfiguration to enter the new epoch.
    public(friend) fun finish(framework: &signer) {
        system_addresses::assert_supra_framework(framework);
        dkg::try_clear_incomplete_session(framework);
        consensus_config::on_new_epoch(framework);
        execution_config::on_new_epoch(framework);
        supra_config::on_new_epoch(framework);
        gas_schedule::on_new_epoch(framework);
        std::version::on_new_epoch(framework);
        features::on_new_epoch(framework);
        automation_registry::on_new_epoch();
        jwk_consensus_config::on_new_epoch(framework);
        jwks::on_new_epoch(framework);
        keyless_account::on_new_epoch(framework);
        leader_ban_registry_config::on_new_epoch(framework);
        randomness_config_seqnum::on_new_epoch(framework);
        randomness_config::on_new_epoch(framework);
        randomness_api_v0_config::on_new_epoch(framework);
        evm_genesis_config::on_new_epoch(framework);
        dkg_config::on_new_epoch(framework);
        reconfiguration::reconfigure();
    }

    /// Complete the current reconfiguration with DKG.
    /// Abort if no DKG is in progress.
    fun finish_with_dkg_result(account: &signer, dkg_result: vector<u8>) {
        dkg::finish(dkg_result);
        finish(account);
    }
}
