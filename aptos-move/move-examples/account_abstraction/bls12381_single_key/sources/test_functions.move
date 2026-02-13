module aa::test_functions {
    use supra_framework::supra_account;

    /// test function for multi-agent aa.
    public entry fun transfer_to_the_last(a: &signer, b: &signer, c: &signer, d: address) {
        supra_account::transfer(a, d, 1);
        supra_account::transfer(b, d, 1);
        supra_account::transfer(c, d, 1);
    }
}
