module supra_framework::test_missing_native {
    native fun missing_native();
    public fun missing_native_function(framework: &signer) {
        missing_native();
    }
}
