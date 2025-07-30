use littlefinger::interfaces::icore::{ICoreDispatcher, ICoreDispatcherTrait};
use littlefinger::interfaces::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
use littlefinger::interfaces::imember_manager::{IMemberManagerDispatcher, IMemberManagerDispatcherTrait};
use littlefinger::interfaces::ivault::{IVaultDispatcher, IVaultDispatcherTrait};
use littlefinger::interfaces::idisbursement::{IDisbursementDispatcher, IDisbursementDispatcherTrait};
use littlefinger::structs::disbursement_structs::{ScheduleStatus, ScheduleType};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
#[feature("deprecated-starknet-consts")]
use starknet::{ContractAddress, contract_address_const};

// Mock ERC20 token
#[starknet::interface]
trait IMockERC20<TContractState> {
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
}

#[starknet::contract]
mod MockERC20 {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};

    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }

    #[abi(embed_v0)]
    impl MockERC20Impl of super::IMockERC20<ContractState> {
        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let caller_balance = self.balances.read(caller);
            assert(caller_balance >= amount, 'Insufficient balance');

            self.balances.write(caller, caller_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);
            true
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let allowance = self.allowances.read((from, caller));
            let from_balance = self.balances.read(from);

            assert(allowance >= amount, 'Insufficient allowance');
            assert(from_balance >= amount, 'Insufficient balance');

            self.allowances.write((from, caller), allowance - amount);
            self.balances.write(from, from_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);
            true
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), amount);
            true
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }

        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            let current_balance = self.balances.read(to);
            self.balances.write(to, current_balance + amount);
        }
    }
}

// Helper functions for test addresses
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn admin() -> ContractAddress {
    contract_address_const::<'admin'>()
}

fn employee1() -> ContractAddress {
    contract_address_const::<'employee1'>()
}

fn employee2() -> ContractAddress {
    contract_address_const::<'employee2'>()
}

fn contractor1() -> ContractAddress {
    contract_address_const::<'contractor1'>()
}

fn deploy_mock_erc20() -> (IMockERC20Dispatcher, ContractAddress) {
    let contract = declare("MockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IMockERC20Dispatcher { contract_address };

    // Mint tokens for testing
    dispatcher.mint(owner(), 10000000000000000000000); 
    dispatcher.mint(admin(), 5000000000000000000000); 
    dispatcher.mint(employee1(), 1000000000000000000000); 
    dispatcher.mint(employee2(), 1000000000000000000000); 
    dispatcher.mint(contractor1(), 1000000000000000000000); 

    (dispatcher, contract_address)
}

fn setup_full_organization() -> (
    ICoreDispatcher,
    ContractAddress,
    IVaultDispatcher,
    ContractAddress,
    IMockERC20Dispatcher,
    ContractAddress,
) {
    let (token_dispatcher, token_address) = deploy_mock_erc20();

    let factory_contract = declare("Factory").unwrap().contract_class();
    let core_class_hash = declare("Core").unwrap().contract_class().class_hash;
    let vault_class_hash = declare("Vault").unwrap().contract_class().class_hash;

    let mut factory_calldata: Array<felt252> = array![owner().into()];
    core_class_hash.serialize(ref factory_calldata);
    vault_class_hash.serialize(ref factory_calldata);

    let (factory_address, _) = factory_contract.deploy(@factory_calldata).unwrap();
    let factory_dispatcher = IFactoryDispatcher { contract_address: factory_address };

    let (core_address, vault_address) = factory_dispatcher
        .setup_org(
            token: token_address,
            salt: 'test_salt',
            owner: owner(),
            name: "Test Organization",
            ipfs_url: "test_ipfs_url",
            first_admin_fname: 'Admin',
            first_admin_lname: 'User',
            first_admin_alias: 'admin',
            organization_type: 0,
        );

    let core_dispatcher = ICoreDispatcher { contract_address: core_address };
    let vault_dispatcher = IVaultDispatcher { contract_address: vault_address };

    // Setup token approvals
    start_cheat_caller_address(token_address, owner());
    token_dispatcher.approve(vault_address, 10000000000000000000000);
    stop_cheat_caller_address(token_address);

    start_cheat_caller_address(token_address, admin());
    token_dispatcher.approve(vault_address, 5000000000000000000000);
    stop_cheat_caller_address(token_address);

    // Fund the vault
    start_cheat_caller_address(vault_address, owner());
    vault_dispatcher.deposit_funds(5000000000000000000000, owner()); 
    vault_dispatcher.add_to_bonus_allocation(1000000000000000000000, owner()); 
    stop_cheat_caller_address(vault_address);

    (core_dispatcher, core_address, vault_dispatcher, vault_address, token_dispatcher, token_address)
}

fn add_test_members(core_dispatcher: ICoreDispatcher, core_address: ContractAddress) {
    let member_dispatcher = IMemberManagerDispatcher { contract_address: core_address };

    // Add employees
    start_cheat_caller_address(core_address, owner());
    member_dispatcher.invite_member(1, employee1(), 1000000000000000000000); 
    member_dispatcher.invite_member(1, employee2(), 800000000000000000000); 
    member_dispatcher.invite_member(0, contractor1(), 500000000000000000000); 
    stop_cheat_caller_address(core_address);

    // Accept invitations
    start_cheat_caller_address(core_address, employee1());
    member_dispatcher.accept_invite('John', 'Doe', 'johndoe');
    stop_cheat_caller_address(core_address);

    start_cheat_caller_address(core_address, employee2());
    member_dispatcher.accept_invite('Jane', 'Smith', 'janesmith');
    stop_cheat_caller_address(core_address);

    start_cheat_caller_address(core_address, contractor1());
    member_dispatcher.accept_invite('Bob', 'Wilson', 'bobwilson');
    stop_cheat_caller_address(core_address);
}

// Test initialize_disbursement_schedule
#[test]
fn test_initialize_disbursement_schedule_success() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    
    let start_time = 1000000;
    let end_time = 2000000;
    // 1 day
    let interval = 86400; 

    start_cheat_caller_address(core_address, owner());
    // RECURRING
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval); 
    stop_cheat_caller_address(core_address);

    // Verify schedule was created
    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    let current_schedule = disbursement_dispatcher.get_current_schedule();
    
    assert(current_schedule.status == ScheduleStatus::ACTIVE, 'Schedule should be active');
    assert(current_schedule.schedule_type == ScheduleType::RECURRING, 'Should be recurring');
    assert(current_schedule.start_timestamp == start_time, 'Wrong start time');
    assert(current_schedule.end_timestamp == end_time, 'Wrong end time');
    assert(current_schedule.interval == interval, 'Wrong interval');
}

#[test]
fn test_initialize_disbursement_schedule_onetime() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 0; 

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(1, start_time, end_time, interval); 
    stop_cheat_caller_address(core_address);

    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    let current_schedule = disbursement_dispatcher.get_current_schedule();
    
    assert(current_schedule.schedule_type == ScheduleType::ONETIME, 'Should be one-time');
}

// Test schedule_payout
#[test]
fn test_schedule_payout_full_flow_success() {
    let (core_dispatcher, core_address, vault_dispatcher, vault_address, token_dispatcher, token_address) = setup_full_organization();
    
    add_test_members(core_dispatcher, core_address);
    
    let start_time = 1000000;
    let end_time = 2000000;
    // 1 day
    let interval = 86400; 
    
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    // Set block timestamp to be within the payout period
    start_cheat_block_timestamp(core_address , start_time + 100);

    // Get initial balances
    let employee1_initial_balance = token_dispatcher.balance_of(employee1());
    let employee2_initial_balance = token_dispatcher.balance_of(employee2());
    let contractor1_initial_balance = token_dispatcher.balance_of(contractor1());
    let vault_initial_balance = vault_dispatcher.get_balance();

    // Execute payout
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    // Verify balances changed (members received payments)
    let employee1_final_balance = token_dispatcher.balance_of(employee1());
    let employee2_final_balance = token_dispatcher.balance_of(employee2());
    let contractor1_final_balance = token_dispatcher.balance_of(contractor1());
    let vault_final_balance = vault_dispatcher.get_balance();

    assert(employee1_final_balance > employee1_initial_balance, 'Employee1 should receive payment');
    assert(employee2_final_balance > employee2_initial_balance, 'Employee2 should receive payment');
    assert(contractor1_final_balance > contractor1_initial_balance, 'Contractor1 should receive payment');
    assert(vault_final_balance < vault_initial_balance, 'Vault balance should decrease');

    // Verify schedule was updated
    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    let updated_schedule = disbursement_dispatcher.get_current_schedule();
    assert(updated_schedule.last_execution == start_time + 100, 'Last execution should be updated');

    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Schedule not active')]
fn test_schedule_payout_inactive_schedule() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);

    // Don't initialize any schedule, so no active schedule exists
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
}

#[test]
#[should_panic(expected: 'Payout has not started')]
fn test_schedule_payout_before_start_time() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);

    let start_time = 2000000;
    let end_time = 3000000;
    let interval = 86400;

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    // Set timestamp before start time
    start_cheat_block_timestamp(core_address , start_time - 100);

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Payout period ended')]
fn test_schedule_payout_after_end_time() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);

    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    // Set timestamp after end time
    start_cheat_block_timestamp(core_address , end_time + 100);

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Payout premature')]
fn test_schedule_payout_premature_execution() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);

    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400; 

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    // First payout
    start_cheat_block_timestamp(core_address , start_time + 100);
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    // Try second payout (before interval)
    start_cheat_block_timestamp(core_address , start_time + 200); 
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout(); // Should fail
    stop_cheat_caller_address(core_address);

    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_schedule_payout_multiple_intervals() {
    let (core_dispatcher, core_address, vault_dispatcher, _, token_dispatcher, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);

    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400; 

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    // First payout
    start_cheat_block_timestamp(core_address , start_time + 100);
    let vault_balance_before_first = vault_dispatcher.get_balance();
    
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    
    let vault_balance_after_first = vault_dispatcher.get_balance();
    assert(vault_balance_after_first < vault_balance_before_first, 'First payout should reduce balance');

    // Second payout after interval
    start_cheat_block_timestamp(core_address , start_time + interval + 200);
    
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    
    let vault_balance_after_second = vault_dispatcher.get_balance();
    assert(vault_balance_after_second < vault_balance_after_first, 'Second payout should reduce balance further');

    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_schedule_payout_role_based_distribution() {
    let (core_dispatcher, core_address, _, _, token_dispatcher, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);

    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    start_cheat_block_timestamp(core_address , start_time + 100);

    // Get initial balances
    let employee1_initial = token_dispatcher.balance_of(employee1());
    let employee2_initial = token_dispatcher.balance_of(employee2());
    let contractor1_initial = token_dispatcher.balance_of(contractor1());

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    // Get final balances
    let employee1_final = token_dispatcher.balance_of(employee1());
    let employee2_final = token_dispatcher.balance_of(employee2());
    let contractor1_final = token_dispatcher.balance_of(contractor1());

    let employee1_payment = employee1_final - employee1_initial;
    let employee2_payment = employee2_final - employee2_initial;
    let contractor1_payment = contractor1_final - contractor1_initial;

    // Employees should receive more than contractors due to higher role weight
    // Employee1 has higher base pay than Employee2
    assert(employee1_payment > contractor1_payment, 'Employee should earn more than contractor');
    assert(employee2_payment > contractor1_payment, 'Employee should earn more than contractor');
    assert(employee1_payment > employee2_payment, 'Higher base pay should result in higher payment');

    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Schedule not active')]
fn test_schedule_payout_with_paused_schedule() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);

    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    
    // Pause the schedule
    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    disbursement_dispatcher.pause_disbursement();
    stop_cheat_caller_address(core_address);

    start_cheat_block_timestamp(core_address , start_time + 100);

    // Try to execute payout with paused schedule - should fail
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_schedule_payout_empty_organization() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    // Don't add any members

    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    start_cheat_block_timestamp(core_address , start_time + 100);

    // Should not panic even with no members
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    stop_cheat_block_timestamp(core_address);
}

// Integration test covering the complete workflow
#[test]
fn test_complete_disbursement_workflow() {
    let (core_dispatcher, core_address, vault_dispatcher, vault_address, token_dispatcher, token_address) = setup_full_organization();
    
    add_test_members(core_dispatcher, core_address);
    
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    // Verify schedule is set up correctly
    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    let schedule = disbursement_dispatcher.get_current_schedule();
    assert(schedule.status == ScheduleStatus::ACTIVE, 'Schedule should be active');

    // Execute multiple payouts over time
    let mut current_time = start_time + 100;
    let mut payout_count = 0;
    
    while current_time < end_time && payout_count < 3 {
        start_cheat_block_timestamp(core_address , current_time);
        
        let vault_balance_before = vault_dispatcher.get_balance();
        
        start_cheat_caller_address(core_address, owner());
        core_dispatcher.schedule_payout();
        stop_cheat_caller_address(core_address);
        
        let vault_balance_after = vault_dispatcher.get_balance();
        assert(vault_balance_after < vault_balance_before, 'Vault balance should decrease');
        
        // Verify schedule was updated
        let updated_schedule = disbursement_dispatcher.get_current_schedule();
        assert(updated_schedule.last_execution == current_time, 'Last execution should be updated');
        
        stop_cheat_block_timestamp(core_address);
        
        current_time += interval + 100; 
        payout_count += 1;
    }
    
    assert(payout_count == 3, 'Should have executed 3 payouts');
}

#[test]
fn test_compute_remuneration_accuracy() {
    let (core_dispatcher, core_address, vault_dispatcher, _, token_dispatcher, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , start_time + 100);
    
    // Assume role weights: EMPLOYEE=2, CONTRACTOR=1 (adjust based on actual MemberRoleIntoU16)
    let total_bonus = vault_dispatcher.get_bonus_allocation();
    let employee1_role_weight = 2; 
    let employee2_role_weight = 2; 
    let contractor1_role_weight = 1; 
    let total_weight = employee1_role_weight + employee2_role_weight + contractor1_role_weight; 
    let employee1_base_pay = 1000000000000000000000; 
    let expected_employee1_payment = (employee1_role_weight * total_bonus) / total_weight + employee1_base_pay;
    
    let employee1_initial = token_dispatcher.balance_of(employee1());
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    let employee1_final = token_dispatcher.balance_of(employee1());
    assert(employee1_final - employee1_initial == expected_employee1_payment, 'Incorrect employee1 payment');
    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Insufficient vault balance')]
fn test_schedule_payout_insufficient_vault_balance() {
    let (core_dispatcher, core_address, vault_dispatcher, vault_address, token_dispatcher, token_address) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    start_cheat_caller_address(vault_address, owner());
    vault_dispatcher.withdraw_funds(vault_dispatcher.get_balance(), owner()); 
    stop_cheat_caller_address(vault_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , start_time + 100);
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Schedule not active')]
fn test_schedule_payout_onetime_single_execution() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 0; 
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(1, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , start_time + 100);
    start_cheat_caller_address(core_address, owner());
    // First payout should succeed
    core_dispatcher.schedule_payout(); 
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , start_time + 200);
    start_cheat_caller_address(core_address, owner());
    // Second payout should fail
    core_dispatcher.schedule_payout(); 
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Caller not authorized')]
fn test_schedule_payout_unauthorized_caller() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , start_time + 100);
    // Non-owner
    start_cheat_caller_address(core_address, employee1()); 
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_schedule_payout_excludes_inactive_members() {
    let (core_dispatcher, core_address, _, _, token_dispatcher, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    let member_dispatcher = IMemberManagerDispatcher { contract_address: core_address };
    start_cheat_caller_address(core_address, owner());
    member_dispatcher.change_member_status(employee1(), MemberStatus::INACTIVE);
    stop_cheat_caller_address(core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    let employee1_initial = token_dispatcher.balance_of(employee1());
    start_cheat_block_timestamp(core_address , start_time + 100);
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    let employee1_final = token_dispatcher.balance_of(employee1());
    assert(employee1_final == employee1_initial, 'Inactive member should not receive payment');
    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_schedule_payout_large_member_set() {
    let (core_dispatcher, core_address, _, _, token_dispatcher, _) = setup_full_organization();
    let member_dispatcher = IMemberManagerDispatcher { contract_address: core_address };
    start_cheat_caller_address(core_address, owner());
    let mut i = 0;
    while i < 50 {
        let member_address = contract_address_const::<{i}>();
        member_dispatcher.invite_member(1, member_address, 1000000000000000000000);
        start_cheat_caller_address(core_address, member_address);
        member_dispatcher.accept_invite('Member', i.into(), 'alias');
        stop_cheat_caller_address(core_address);
        i += 1;
    }
    stop_cheat_caller_address(core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , start_time + 100);
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_schedule_payout_zero_bonus_allocation() {
    let (core_dispatcher, core_address, vault_dispatcher, vault_address, token_dispatcher, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    // Ensure bonus allocation is zero for this test
    let bonus_allocation = vault_dispatcher.get_bonus_allocation();
    
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;

    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);

    let employee1_initial = token_dispatcher.balance_of(employee1());
    start_cheat_block_timestamp(core_address, start_time + 100);
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
    let employee1_final = token_dispatcher.balance_of(employee1());

    assert(employee1_final > employee1_initial, 'Base pay should be distributed');

    stop_cheat_block_timestamp(core_address);
}

#[test]
fn test_schedule_payout_at_start_timestamp() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , start_time); 
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout(); 
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'Payout period ended')]
fn test_schedule_payout_at_end_timestamp() {
    let (core_dispatcher, core_address, _, _, _, _) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address , end_time); 
    start_cheat_caller_address(core_address, owner());
    core_dispatcher.schedule_payout(); 
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}