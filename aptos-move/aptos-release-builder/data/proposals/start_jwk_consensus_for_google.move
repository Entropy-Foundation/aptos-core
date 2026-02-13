// Start JWK Consensus for Google.
script {
    use supra_framework::supra_governance;
    use supra_framework::jwks;

    fun main(proposal_id: u64) {
        let framework_signer = supra_governance::resolve_multi_step_proposal(
            proposal_id,
            @0x1,
            {{ script_hash }},
        );

        jwks::upsert_oidc_provider_for_next_epoch(
            &framework_signer,
            b"https://accounts.google.com",
            b"https://accounts.google.com/.well-known/openid-configuration"
        );
        supra_framework::reconfigure(&framework_signer);
    }
}
