spec aptos_framework::vesting_without_staking {
    spec module {
        pragma verify = false;
    }

    spec VestingRecord {
        invariant init_amount >= left_amount;
    }

    spec VestingContract {
        // let shareholders_address = simple_map::spec
        // let amount = simple_map::values(shareholders);
        // invariant
    }

    spec distribute {
        pragma verify = true;

        let post vesting_contract_post = borrow_global<VestingContract>(contract_address);
        let post total_balance = coin::balance<AptosCoin>(contract_address);
        ensures total_balance == 0 ==> vesting_contract_post.state == VESTING_POOL_TERMINATED; //Proved
    }

    spec remove_shareholder {
        pragma verify = true;
        let vesting_contract = borrow_global<VestingContract>(contract_address);
        ensures !simple_map::spec_contains_key(vesting_contract.shareholders, shareholder_address);
        ensures !simple_map::spec_contains_key(vesting_contract.beneficiaries, simple_map::spec_get(vesting_contract.beneficiaries, shareholder_address));
    }
    // spec terminate_vesting_contract {
    //     pragma verify = true;
    //     // include AdminAborts;
    //     // include VestingContractActive;
    // }
    spec verify_admin {
        pragma verify = true;
        include AdminAborts;
    }
    spec schema AdminAborts {
        admin: &signer;
        vesting_contract: &VestingContract;
        aborts_if signer::address_of(admin) != vesting_contract.admin;
    }

    spec assert_vesting_contract_exists {
        pragma verify = true;
        include VestingContractExists;
    }

    spec schema VestingContractExists {
        contract_address: address;
        aborts_if !exists<VestingContract>(contract_address);
    }

    spec assert_active_vesting_contract {
        pragma verify = true;
        include VestingContractActive;
    }

    spec schema VestingContractActive {
        include VestingContractExists;
        contract_address: address;
        let vesting_contract = borrow_global<VestingContract>(contract_address);
        aborts_if !(vesting_contract.state == VESTING_POOL_ACTIVE);
    }

    spec get_beneficiary {
        pragma verify = true;
        ensures simple_map::spec_contains_key(contract.beneficiaries, shareholder) ==> result == simple_map::spec_get(contract.beneficiaries, shareholder);
        ensures !simple_map::spec_contains_key(contract.beneficiaries, shareholder) ==> result == shareholder;
    }
}
