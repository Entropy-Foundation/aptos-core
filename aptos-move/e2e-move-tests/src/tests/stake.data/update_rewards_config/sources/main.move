script {
    use supra_framework::supra_governance;
    use supra_framework::staking_config;
    use aptos_std::fixed_point64;
    use std::features;

    fun main(core_resources: &signer) {
        let framework_signer = supra_governance::get_signer_testnet_only(core_resources, @supra_framework);
        staking_config::update_rewards_config(
            &framework_signer,
            fixed_point64::create_from_rational(1, 100),
            fixed_point64::create_from_rational(3, 1000),
            365 * 24 * 60 * 60,
            fixed_point64::create_from_rational(50, 100),
        );
        let feature = features::get_periodical_reward_rate_decrease_feature();
        features::change_feature_flags_for_next_epoch(&framework_signer, vector[feature], vector[]);
        supra_governance::force_end_epoch(&framework_signer);
    }
}
