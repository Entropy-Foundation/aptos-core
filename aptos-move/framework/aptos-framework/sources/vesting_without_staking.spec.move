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

    spec vesting_start_secs {
        pragma verify = true;
        include VestingContractExists{contract_address: vesting_contract_address};
    }

    spec period_duration_secs {
        pragma verify = true;
        include VestingContractExists{contract_address: vesting_contract_address};
    }

    spec remaining_grant {
        pragma verify = true;
        include VestingContractExists{contract_address: vesting_contract_address};
        aborts_if !simple_map::spec_contains_key(borrow_global<VestingContract>(vesting_contract_address).shareholders, shareholder_address);
        ensures result == simple_map::spec_get(borrow_global<VestingContract>(vesting_contract_address).shareholders, shareholder_address).left_amount;
    }

    spec beneficiary {
        pragma verify = true;
        include VestingContractExists{contract_address: vesting_contract_address};
    }

    spec vesting_contracts {
        pragma verify = true;
        aborts_if false;
        ensures !exists<AdminStore>(admin) ==> result == vector::empty<address>();
        ensures exists<AdminStore>(admin) ==> result == borrow_global<AdminStore>(admin).vesting_contracts;
    }

    spec vesting_schedule {
        pragma verify = true;
        include VestingContractExists{contract_address: vesting_contract_address};
        ensures result == borrow_global<VestingContract>(vesting_contract_address).vesting_schedule;
    }

    spec vest {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        include VestingContractActive;
        let vesting_contract_pre = borrow_global<VestingContract>(contract_address);
        let post vesting_contract_post = borrow_global<VestingContract>(contract_address);
        // ensures vesting_contract.vesting_schedule.start_timestamp_secs <= time::current_timestamp() ==> vesting_contract_pre == vesting_contract_post;
    }

    spec distribute {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        include VestingContractActive;
        let post vesting_contract_post = borrow_global<VestingContract>(contract_address);
        let post total_balance = coin::balance<AptosCoin>(contract_address);
        ensures total_balance == 0 ==> vesting_contract_post.state == VESTING_POOL_TERMINATED;
    }

    spec remove_shareholder {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        include AdminAborts;
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
        pragma opaque;
        aborts_if false;
        ensures simple_map::spec_contains_key(contract.beneficiaries, shareholder) ==> result == simple_map::spec_get(contract.beneficiaries, shareholder);
        ensures !simple_map::spec_contains_key(contract.beneficiaries, shareholder) ==> result == shareholder;
    }
}
