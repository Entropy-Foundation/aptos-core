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
        aborts_if !simple_map::spec_contains_key(global<VestingContract>(vesting_contract_address).shareholders, shareholder_address);
        ensures result == simple_map::spec_get(global<VestingContract>(vesting_contract_address).shareholders, shareholder_address).left_amount;
    }

    spec beneficiary {
        pragma verify = true;
        include VestingContractExists{contract_address: vesting_contract_address};
    }

    spec vesting_contracts {
        pragma verify = true;
        aborts_if false;
        ensures !exists<AdminStore>(admin) ==> result == vector::empty<address>();
        ensures exists<AdminStore>(admin) ==> result == global<AdminStore>(admin).vesting_contracts;
    }

    spec vesting_schedule {
        pragma verify = true;
        include VestingContractExists{contract_address: vesting_contract_address};
        ensures result == global<VestingContract>(vesting_contract_address).vesting_schedule;
    }

    // spec shareholders {
    //     pragma verify = true;
    //     include VestingContractActive{contract_address: vesting_contract_address};
    // }

    // spec shareholder {
    //     pragma verify = true;
    // }

    spec create_vesting_schedule {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        aborts_if vector::length(schedule) == 0;
        aborts_if period_duration <= 0;
        aborts_if start_timestamp_secs < timestamp::spec_now_seconds();
    }

    // spec create_vesting_contract {
    //     pragma verify = true;
    //     pragma aborts_if_is_partial = true;
    //     aborts_if system_addresses::is_reserved_address(withdrawal_address);
    // }

    spec vest {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        include VestingContractActive;
        let vesting_contract_pre = global<VestingContract>(contract_address);
        let post vesting_contract_post = global<VestingContract>(contract_address);
        let vesting_schedule = vesting_contract_pre.vesting_schedule;
        let last_vested_period = vesting_schedule.last_vested_period;
        let next_period_to_vest = last_vested_period + 1;
        let last_completed_period =
            (timestamp::spec_now_seconds() - vesting_schedule.start_timestamp_secs) / vesting_schedule.period_duration;
        // TODO : whenever it is changed, time is already passed
        ensures vesting_contract_pre.vesting_schedule.start_timestamp_secs > timestamp::spec_now_seconds() ==> vesting_contract_pre == vesting_contract_post;
        ensures last_completed_period < next_period_to_vest ==> vesting_contract_pre == vesting_contract_post;
        // ensures last_completed_period > next_period_to_vest ==> TRACE(vesting_contract_post.vesting_schedule.last_vested_period) == TRACE(next_period_to_vest);
    }

    spec distribute {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        include VestingContractActive;
        let post vesting_contract_post = global<VestingContract>(contract_address);
        let post total_balance = coin::balance<AptosCoin>(contract_address);
        ensures total_balance == 0 ==> vesting_contract_post.state == VESTING_POOL_TERMINATED;
    }

    spec remove_shareholder {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        include AdminAborts;
        let vesting_contract = global<VestingContract>(contract_address);
        let post vesting_contract_post = global<VestingContract>(contract_address);
        let balance_pre = coin::balance<AptosCoin>(vesting_contract.withdrawal_address);
        let post balance_post = coin::balance<AptosCoin>(vesting_contract_post.withdrawal_address);
        let shareholder_amount = simple_map::spec_get(vesting_contract.shareholders, shareholder_address).left_amount;
// ensure that `withdrawal address` receives the `shareholder_amount`
        ensures vesting_contract_post.withdrawal_address != vesting_contract.signer_cap.account ==> balance_post == balance_pre + shareholder_amount;
        // ensure that `shareholder_address` is indeed removed from the contract
        ensures !simple_map::spec_contains_key(vesting_contract_post.shareholders, shareholder_address);
        // ensure that beneficiary doesn't exist for the corresponding shareholder
        ensures !simple_map::spec_contains_key(vesting_contract_post.beneficiaries, shareholder_address);
    }

    // spec terminate_vesting_contract {
    //     pragma verify = true;
    //     // include AdminAborts;
    //     // include VestingContractActive;
    // }

    spec admin_withdraw {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        aborts_if !(global<VestingContract>(contract_address).state == VESTING_POOL_TERMINATED);
    }

    spec set_beneficiary {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        let vesting_contract_pre = global<VestingContract>(contract_address);
        let post vesting_contract_post = global<VestingContract>(contract_address);
        include AdminAborts{vesting_contract: vesting_contract_pre};
        ensures simple_map::spec_get(vesting_contract_post.beneficiaries, shareholder) == new_beneficiary;
    }

    spec reset_beneficiary {
        pragma verify = true;
    }

    spec set_management_role {
        pragma verify = true;
    }

    spec set_beneficiary_resetter {
        pragma verify = true;
    }

    spec get_role_holder {
        pragma verify = true;
    }

    spec get_vesting_account_signer {
        pragma verify = true;
        let vesting_contract = global<VestingContract>(contract_address);
        include AdminAborts;
        aborts_if !exists<VestingContract>(contract_address);
    }

    spec get_vesting_account_signer_internal {
        pragma verify = true;
        aborts_if false;
        let address = vesting_contract.signer_cap.account;
        ensures signer::address_of(result) == address;
    }

    spec create_vesting_contract_account {
        pragma verify = true;
        pragma aborts_if_is_partial = true;
        aborts_if !exists<AdminStore>(signer::address_of(admin));
    }

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
        let vesting_contract = global<VestingContract>(contract_address);
        aborts_if !(vesting_contract.state == VESTING_POOL_ACTIVE);
    }

    spec get_beneficiary {
        pragma verify = true;
        pragma opaque;
        aborts_if false;
        ensures simple_map::spec_contains_key(contract.beneficiaries, shareholder) ==> result == simple_map::spec_get(contract.beneficiaries, shareholder);
        ensures !simple_map::spec_contains_key(contract.beneficiaries, shareholder) ==> result == shareholder;
    }

    spec set_terminate_vesting_contract {
        pragma verify = true;
        aborts_if !exists<VestingContract>(contract_address);
        let post vesting_contract_post = global<VestingContract>(contract_address);
        ensures vesting_contract_post.state == VESTING_POOL_TERMINATED;
    }
}
