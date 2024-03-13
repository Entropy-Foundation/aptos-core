spec aptos_framework::vesting_without_staking {
    spec module {
        pragma verify = false;
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
}
