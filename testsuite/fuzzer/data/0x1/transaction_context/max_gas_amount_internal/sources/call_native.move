module poc::max_gas_amount_internal {
    use supra_framework::transaction_context;

    public entry fun main(_owner:&signer) {
        let _max_gas = transaction_context::max_gas_amount();
    }

    #[test(owner=@0x123)]
    #[expected_failure(abort_code=196609, location = supra_framework::transaction_context)]
    fun a(owner:&signer){
        main(owner);
    }
}
