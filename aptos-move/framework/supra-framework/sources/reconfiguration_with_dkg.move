/// Reconfiguration with DKG helper functions.
module supra_framework::reconfiguration_with_dkg {
    use std::features;
    use std::option;
    use std::vector;
    use supra_framework::validator_consensus_info::ValidatorConsensusInfo;
    use supra_framework::dkg_config::{DkgConfig, DkgNodeConfig};
    use supra_framework::randomness::permutation;
    use supra_framework::dkg_config;
    use supra_framework::consensus_config;
    use supra_framework::dkg;
    use supra_framework::execution_config;
    use supra_framework::gas_schedule;
    use supra_framework::jwk_consensus_config;
    use supra_framework::jwks;
    use supra_framework::keyless_account;
    use supra_framework::randomness_api_v0_config;
    use supra_framework::randomness_config;
    use supra_framework::randomness_config_seqnum;
    use supra_framework::reconfiguration;
    use supra_framework::reconfiguration_state;
    use supra_framework::stake;
    use supra_framework::supra_config;
    use supra_framework::system_addresses;
    use supra_framework::validator_consensus_info;
    friend supra_framework::block;
    friend supra_framework::supra_governance;

    const EINVALID_COMMITTEE_SIZE: u64 = 1;

    //todo: replace with computing the sizes using a native function
    /// The appropriate clan sizes to ensure a simple majority with high probability (1-10^(-9)) for a tribe of size n=(11,1000)
    const CLAN_SIZES: vector<u64> = vector[10, 10, 10, 10, 10, 10, 10, 12, 12, 12, 14, 14, 14, 16, 16, 16, 18, 18, 18, 20, 20, 20, 22, 22, 22, 24, 24, 24, 26, 26, 26, 28, 28, 28, 30, 30, 30, 32, 32, 32, 34, 34, 34, 36, 36, 36, 38, 38, 38, 40, 40, 40, 42, 42, 42, 44, 44, 44, 46, 46, 46, 48, 48, 48, 50, 50, 50, 52, 52, 52, 54, 54, 54, 56, 56, 56, 58, 58, 58, 60, 60, 60, 62, 62, 62, 64, 64, 64, 66, 66, 66, 68, 68, 68, 70, 70, 70, 72, 72, 72, 74, 74, 74, 76, 74, 74, 76, 76, 76, 78, 78, 78, 80, 80, 80, 82, 82, 80, 84, 82, 82, 84, 84, 84, 86, 86, 86, 88, 88, 86, 90, 88, 88, 90, 90, 90, 92, 92, 92, 94, 92, 92, 94, 94, 94, 96, 96, 96, 98, 96, 96, 98, 98, 98, 100, 100, 100, 102, 100, 100, 102, 102, 102, 104, 104, 102, 106, 104, 104, 106, 106, 106, 108, 108, 106, 108, 108, 108, 110, 110, 108, 112, 110, 110, 112, 112, 112, 114, 112, 112, 114, 114, 114, 116, 116, 114, 116, 116, 116, 118, 118, 116, 118, 118, 118, 120, 120, 118, 122, 120, 120, 122, 122, 120, 124, 122, 122, 124, 124, 122, 126, 124, 124, 126, 126, 124, 128, 126, 126, 128, 128, 126, 130, 128, 128, 130, 130, 128, 132, 130, 130, 132, 132, 130, 132, 132, 132, 134, 134, 132, 134, 134, 134, 136, 134, 134, 136, 136, 136, 138, 136, 136, 138, 138, 136, 140, 138, 138, 140, 140, 138, 140, 140, 140, 142, 140, 140, 142, 142, 142, 144, 142, 142, 144, 144, 142, 144, 144, 144, 146, 144, 144, 146, 146, 146, 148, 146, 146, 148, 148, 146, 148, 148, 148, 150, 148, 148, 150, 150, 148, 152, 150, 150, 152, 152, 150, 152, 152, 152, 154, 152, 152, 154, 154, 152, 154, 154, 154, 156, 154, 154, 156, 156, 154, 156, 156, 156, 158, 156, 156, 158, 158, 156, 158, 158, 158, 160, 158, 158, 160, 160, 158, 160, 160, 160, 162, 160, 160, 162, 162, 160, 162, 162, 162, 164, 162, 162, 164, 164, 162, 164, 164, 164, 166, 164, 164, 166, 166, 164, 166, 166, 164, 168, 166, 166, 168, 166, 166, 168, 168, 166, 168, 168, 168, 170, 168, 168, 170, 170, 168, 170, 170, 170, 172, 170, 170, 172, 172, 170, 172, 172, 170, 172, 172, 172, 174, 172, 172, 174, 174, 172, 174, 174, 172, 176, 174, 174, 176, 174, 174, 176, 176, 174, 176, 176, 176, 178, 176, 176, 178, 176, 176, 178, 178, 176, 178, 178, 178, 180, 178, 178, 180, 180, 178, 180, 180, 178, 180, 180, 180, 182, 180, 180, 182, 180, 180, 182, 182, 180, 182, 182, 182, 184, 182, 182, 184, 182, 182, 184, 184, 182, 184, 184, 184, 186, 184, 184, 186, 184, 184, 186, 186, 184, 186, 186, 184, 186, 186, 186, 188, 186, 186, 188, 188, 186, 188, 188, 186, 188, 188, 188, 190, 188, 188, 190, 188, 188, 190, 190, 188, 190, 190, 188, 190, 190, 190, 192, 190, 190, 192, 190, 190, 192, 192, 190, 192, 192, 190, 192, 192, 192, 194, 192, 192, 194, 192, 192, 194, 194, 192, 194, 194, 192, 194, 194, 194, 196, 194, 194, 196, 194, 194, 196, 196, 194, 196, 196, 194, 196, 196, 196, 198, 196, 196, 198, 196, 196, 198, 198, 196, 198, 198, 196, 198, 198, 198, 200, 198, 198, 200, 198, 198, 200, 200, 198, 200, 200, 198, 200, 200, 198, 200, 200, 200, 202, 200, 200, 202, 200, 200, 202, 202, 200, 202, 202, 200, 202, 202, 202, 202, 202, 202, 204, 202, 202, 204, 202, 202, 204, 204, 202, 204, 204, 202, 204, 204, 204, 204, 204, 204, 206, 204, 204, 206, 204, 204, 206, 206, 204, 206, 206, 204, 206, 206, 206, 206, 206, 206, 208, 206, 206, 208, 206, 206, 208, 208, 206, 208, 208, 206, 208, 208, 206, 208, 208, 208, 210, 208, 208, 210, 208, 208, 210, 208, 208, 210, 210, 208, 210, 210, 208, 210, 210, 210, 210, 210, 210, 212, 210, 210, 212, 210, 210, 212, 210, 210, 212, 212, 210, 212, 212, 210, 212, 212, 212, 212, 212, 212, 214, 212, 212, 214, 212, 212, 214, 212, 212, 214, 214, 212, 214, 214, 212, 214, 214, 214, 214, 214, 214, 216, 214, 214, 216, 214, 214, 216, 214, 214, 216, 216, 214, 216, 216, 214, 216, 216, 214, 216, 216, 216, 216, 216, 216, 218, 216, 216, 218, 216, 216, 218, 216, 216, 218, 218, 216, 218, 218, 216, 218, 218, 216, 218, 218, 218, 218, 218, 218, 220, 218, 218, 220, 218, 218, 220, 218, 218, 220, 220, 218, 220, 220, 218, 220, 220, 218, 220, 220, 220, 220, 220, 220, 222, 220, 220, 222, 220, 220, 222, 220, 220, 222, 222, 220, 222, 222, 220, 222, 222, 220, 222, 222, 222, 222, 222, 222, 222, 222, 222, 224, 222, 222, 224, 222, 222, 224, 222, 222, 224, 224, 222, 224, 224, 222, 224, 224, 222, 224, 224, 224, 224, 224, 224, 224, 224, 224, 226, 224, 224, 226, 224, 224, 226, 224, 224, 226, 226, 224, 226, 226, 224, 226, 226, 224, 226, 226, 226, 226, 226, 226, 226, 226, 226, 228, 226, 226, 228, 226, 226, 228, 226, 226, 228, 226, 226, 228, 228, 226, 228, 228, 226, 228, 228, 226, 228, 228, 228, 228, 228, 228, 228, 228, 228, 230, 228, 228, 230, 228, 228, 230, 228, 228, 230, 228, 228, 230, 230, 228, 230, 230, 228, 230, 230, 228, 230, 230, 230, 230, 230, 230, 230, 230, 230, 232, 230, 230, 232, 230, 230, 232, 230, 230, 232, 230, 230, 232, 232, 230, 232, 232, 230, 232, 232, 230, 232, 232, 230, 232, 232, 232, 232, 232, 232, 232, 232, 232, 234, 232, 232, 234, 232];
    /// The appropriate family sizes to ensure atleast 1 honest node with high probability (1-10^(-9)) for a tribe of size n=(11,1000)
    const FAMILY_SIZES: vector<u64> = vector[3, 4, 4, 4, 5, 5, 5, 6, 6, 6, 7, 7, 7, 8, 8, 8, 9, 9, 9, 10, 10, 10, 11, 11, 11, 12, 12, 11, 12, 12, 12, 13, 12, 12, 13, 13, 13, 13, 13, 13, 14, 13, 13, 14, 14, 14, 14, 14, 14, 14, 14, 14, 15, 14, 14, 15, 15, 14, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 16, 15, 15, 16, 16, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 17, 16, 16, 17, 17, 16, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 17, 18, 17, 17, 18, 17, 17, 18, 18, 17, 18, 18, 17, 18, 18, 17, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 19, 18, 18, 19, 18, 18, 19, 18, 18, 19, 18, 18, 19, 18, 18, 19, 18, 18, 19, 19, 18, 19, 19, 18, 19, 19, 18, 19, 19, 18, 19, 19, 18, 19, 19, 18, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19, 19];

    fun calculate_clan_size(n: u64): u64{
        assert!(n>= 11 && n<=1000, EINVALID_COMMITTEE_SIZE);
        *vector::borrow(&CLAN_SIZES, n-11)
    }

    fun calculate_family_size(n: u64): u64{
        assert!(n>= 11 && n<=1000, EINVALID_COMMITTEE_SIZE);
        *vector::borrow(&FAMILY_SIZES, n-11)
    }

    fun get_validator_set_dkg_config(validator_set: &vector<ValidatorConsensusInfo>): vector<DkgNodeConfig>{
        let validator_set_dkg_config = vector[];
        vector::for_each_ref(validator_set, |validator| {
            let validator_address = validator_consensus_info::get_addr(validator);
            let node_dkg_config = dkg_config::get_dkg_node_config(validator_address);
            vector::push_back(&mut validator_set_dkg_config, node_dkg_config);
        });
        validator_set_dkg_config
    }

    /// Select a random committee of nodes from node_set of size dkg_committee_size
    fun select_random_dkg_committee(node_set: &vector<DkgNodeConfig>, dkg_committee_size: u64): vector<DkgNodeConfig>{
        assert!(dkg_committee_size <= vector::length(node_set), EINVALID_COMMITTEE_SIZE);

        let n_validators = vector::length(node_set);
        let permutation = permutation(n_validators);
        let indices = vector::slice(&permutation, 0, dkg_committee_size);
        let committee = vector[];
        vector::for_each(indices, |node_index| {
            vector::push_back(&mut committee, *vector::borrow(node_set, node_index))
        });
        committee
    }

    /// Retrieve validator nodes of current and next epoch
    /// Create DKG config consisting of a randomly selected dealer_clan and a node family from current validator set
    /// And the recipients of the dealings are validator nodes of the next epoch
    fun get_dkg_config(): DkgConfig{

        let current_validator_set_dkg_config = get_validator_set_dkg_config(&stake::cur_validator_consensus_infos());
        let next_validator_set_dkg_config = get_validator_set_dkg_config(&stake::next_validator_consensus_infos());

        let n_current_validators = vector::length(&current_validator_set_dkg_config);
        let clan_size = calculate_clan_size(n_current_validators);
        let family_size = calculate_family_size(n_current_validators);

        let clan_committee = select_random_dkg_committee(&current_validator_set_dkg_config, clan_size);
        let family_committee = select_random_dkg_committee(&current_validator_set_dkg_config, family_size);

        dkg_config::create_dkg_config(clan_committee,
            family_committee,
        next_validator_set_dkg_config)
    }

    /// Trigger a reconfiguration with DKG.
    /// Do nothing if one is already in progress.
    public(friend) fun try_start() {
        let incomplete_dkg_session = dkg::incomplete_session();
        if (option::is_some(&incomplete_dkg_session)) {
            let session = option::borrow(&incomplete_dkg_session);
            if (dkg::session_dealer_epoch(session) == (reconfiguration::current_epoch() as u32)) {
                return
            }
        };
        reconfiguration_state::on_reconfig_start();
        let cur_epoch = reconfiguration::current_epoch();
        let dkg_config = get_dkg_config();

        dkg::start(
            cur_epoch,
            dkg_config
        );
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
        jwk_consensus_config::on_new_epoch(framework);
        jwks::on_new_epoch(framework);
        keyless_account::on_new_epoch(framework);
        randomness_config_seqnum::on_new_epoch(framework);
        randomness_config::on_new_epoch(framework);
        randomness_api_v0_config::on_new_epoch(framework);
        reconfiguration::reconfigure();
    }

    /// Complete the current reconfiguration with DKG.
    /// Abort if no DKG is in progress or DKG Meta is not set for the in-progress session.
    fun finish_dkg(account: &signer) {
        dkg::finish();
        finish(account);
    }
}
