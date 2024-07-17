script {
    use supra_framework::supra_governance;
    use supra_framework::transaction_fee;

    fun main(core_resources: &signer, burn_percentage: u8) {
        let framework_signer = supra_governance::get_signer_testnet_only(core_resources, @supra_framework);
        transaction_fee::upgrade_burn_percentage(&framework_signer, burn_percentage);

        // Make sure to trigger a reconfiguration!
        supra_governance::reconfigure(&framework_signer);
    }
}
