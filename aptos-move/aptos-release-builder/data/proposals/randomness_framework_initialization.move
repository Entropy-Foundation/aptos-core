// Initialize on-chain randomness resources.
script {
    use supra_framework::supra_governance;
    use supra_framework::config_buffer;
    use supra_framework::dkg;
    use supra_framework::randomness;
    use supra_framework::randomness_config;
    use supra_framework::reconfiguration_state;

    fun main(proposal_id: u64) {
        let framework = supra_governance::resolve_multi_step_proposal(
            proposal_id,
            @0x1,
            {{ script_hash }},
        );
        config_buffer::initialize(&framework); // on-chain config buffer
        dkg::initialize(&framework); // DKG state holder
        reconfiguration_state::initialize(&framework); // reconfiguration in progress global indicator
        randomness::initialize(&framework); // randomness seed holder

        let config = randomness_config::new_off();
        randomness_config::initialize(&framework, config);
    }
}
