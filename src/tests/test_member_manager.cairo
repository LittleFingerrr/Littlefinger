use littlefinger::interfaces::imember_manager::{
    IMemberManagerDispatcher, IMemberManagerDispatcherTrait,
};
use littlefinger::structs::member_structs::{
    InviteStatus, Member, MemberConfig, MemberConfigNode, MemberDetails, MemberEnum, MemberEvent,
    MemberInvite, MemberInvited, MemberNode, MemberResponse, MemberRole, MemberStatus, MemberTrait,
};
use littlefinger::tests::mocks::mock_member_manager::MockMemberManager;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_block_timestamp, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_contract() -> IMemberManagerDispatcher {
    let (fname, lname, alias) = admin_details();
    let admin = admin();
    let contract_class = declare("MockMemberManager").unwrap().contract_class();
    let mut calldata = array![fname.into(), lname.into(), alias.into(), admin.into()];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IMemberManagerDispatcher { contract_address }
}

fn get_mock_contract_state() -> MockMemberManager::ContractState {
    MockMemberManager::contract_state_for_testing()
}

fn calculate_role_value(role: MemberRole, multiplier: u16) -> u16 {
    match role {
        MemberRole::EMPLOYEE(level) => level * multiplier,
        MemberRole::CONTRACTOR(level) => level * multiplier,
        MemberRole::ADMIN(level) => level * multiplier,
        _ => 0,
    }
}

fn admin() -> ContractAddress {
    contract_address_const::<'admin'>()
}

fn caller() -> ContractAddress {
    contract_address_const::<'caller'>()
}

fn admin_details() -> (felt252, felt252, felt252) {
    ('Admin', 'User', 'adminuser')
}

fn member_details() -> (felt252, felt252, felt252, MemberRole, ContractAddress) {
    ('John', 'Doe', 'johndoe', MemberRole::EMPLOYEE(5), member())
}

fn member() -> ContractAddress {
    contract_address_const::<'member'>()
}

fn member2() -> ContractAddress {
    contract_address_const::<'member2'>()
}

#[test]
fn test_add_member_successful() {
    let mock_contract = deploy_mock_contract();

    let (fname, lname, alias, role, member) = member_details();

    let caller = caller();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member(fname, lname, alias, role, member);

    let member_response = mock_contract.get_member(2);

    stop_cheat_caller_address(mock_contract.contract_address);
    assert(member_response.fname == fname, 'Wrong first name');
    assert(member_response.lname == lname, 'Wrong last name');
    assert(member_response.alias == alias, 'Wrong alias');
    assert(member_response.role == role, 'Wrong role');
    assert(member_response.address == member, 'Wrong address');
}

#[test]
fn test_add_admin_successful() {
    let mock_contract = deploy_mock_contract();

    let (fname, lname, alias, role, member) = member_details();

    let caller = caller();
    let admin = admin();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member(fname, lname, alias, role, member);
    let mut member_response = mock_contract.get_member(2);
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(member_response.fname == fname, 'Wrong first name');
    assert(member_response.lname == lname, 'Wrong last name');
    assert(member_response.alias == alias, 'Wrong alias');
    assert(member_response.role == role, 'Wrong role');
    assert(member_response.address == member, 'Wrong address');

    start_cheat_caller_address(mock_contract.contract_address, admin);
    mock_contract.add_admin(1);
    member_response = mock_contract.get_member(1);
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(member_response.role == MemberRole::ADMIN(1), 'Wrong role');
}

#[test]
#[should_panic(expected: 'Caller Not an Admin')]
fn test_add_admin_not_admin() {
    let mock_contract = deploy_mock_contract();
    let (fname, lname, alias, role, member) = member_details();

    let caller = caller();

    start_cheat_caller_address(mock_contract.contract_address, caller);
    mock_contract.add_member(fname, lname, alias, role, member);
    let mut member_response = mock_contract.get_member(1);
    mock_contract.add_admin(1);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_update_member_details_successful() {
    let mock_contract = deploy_mock_contract();

    let (fname, lname, alias, role, member_addr) = member_details();

    // Add member first
    start_cheat_caller_address(mock_contract.contract_address, member_addr);
    mock_contract.add_member(fname, lname, alias, role, member_addr);

    // Update member details
    let new_fname = 'Jane';
    let new_lname = 'Smith';
    let new_alias = 'janesmith';

    mock_contract
        .update_member_details(
            2, Option::Some(new_fname), Option::Some(new_lname), Option::Some(new_alias),
        );

    let updated_member = mock_contract.get_member(2);
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(updated_member.fname == new_fname, 'Wrong updated fname');
    assert(updated_member.lname == new_lname, 'Wrong updated lname');
    assert(updated_member.alias == new_alias, 'Wrong updated alias');
}

#[test]
fn test_update_member_base_pay_successful() {
    let mock_contract = deploy_mock_contract();

    let (fname, lname, alias, role, member_addr) = member_details();
    let admin_addr = admin();

    // Add member first
    start_cheat_caller_address(mock_contract.contract_address, member_addr);
    mock_contract.add_member(fname, lname, alias, role, member_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Update base pay as admin
    let new_base_pay = 50000;
    start_cheat_caller_address(mock_contract.contract_address, admin_addr);
    mock_contract.update_member_base_pay(1, new_base_pay);

    let retrieved_pay = mock_contract.get_member_base_pay(1);
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(retrieved_pay == new_base_pay, 'Wrong base pay');
}

#[test]
#[should_panic(expected: 'UNAUTHORIZED')]
fn test_update_member_base_pay_unauthorized() {
    let mock_contract = deploy_mock_contract();

    let (fname, lname, alias, role, member_addr) = member_details();
    let unauthorized_caller = caller();

    // Add member first
    start_cheat_caller_address(mock_contract.contract_address, member_addr);
    mock_contract.add_member(fname, lname, alias, role, member_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Try to update base pay as non-admin (should fail)
    start_cheat_caller_address(mock_contract.contract_address, unauthorized_caller);
    mock_contract.update_member_base_pay(1, 50000);
    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_suspend_and_reinstate_member() {
    let mock_contract = deploy_mock_contract();

    let (fname, lname, alias, role, member_addr) = member_details();
    let admin_addr = admin();

    // Add member first
    start_cheat_caller_address(mock_contract.contract_address, member_addr);
    mock_contract.add_member(fname, lname, alias, role, member_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Suspend member
    start_cheat_caller_address(mock_contract.contract_address, admin_addr);
    mock_contract.suspend_member(1);

    let suspended_member = mock_contract.get_member(1);
    assert(suspended_member.status == MemberStatus::SUSPENDED, 'Member not suspended');

    // Reinstate member
    mock_contract.reinstate_member(1);

    let reinstated_member = mock_contract.get_member(1);
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(reinstated_member.status == MemberStatus::ACTIVE, 'Member not reinstated');
}

#[test]
fn test_get_members() {
    let mock_contract = deploy_mock_contract();

    let (fname1, lname1, alias1, role1, member1_addr) = member_details();

    let fname2 = 'Jane';
    let lname2 = 'Smith';
    let alias2 = 'janesmith';
    let role2 = MemberRole::CONTRACTOR(3);
    let member2_addr = member2();

    // Add first member
    start_cheat_caller_address(mock_contract.contract_address, member1_addr);
    mock_contract.add_member(fname1, lname1, alias1, role1, member1_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Add second member
    start_cheat_caller_address(mock_contract.contract_address, member2_addr);
    mock_contract.add_member(fname2, lname2, alias2, role2, member2_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    let members = mock_contract.get_members();

    assert(members.len() == 3, 'Wrong number of members');
    assert(*members.at(1).fname == fname1, 'Wrong first member fname');
    assert(*members.at(2).fname == fname2, 'Wrong second member fname');
}

#[test]
fn test_invite_member_successful() {
    let mock_contract = deploy_mock_contract();
    let admin_addr = admin();
    let invitee_addr = member();

    start_cheat_caller_address(mock_contract.contract_address, admin_addr);
    start_cheat_block_timestamp(mock_contract.contract_address, 1000);

    let result = mock_contract.invite_member(1, invitee_addr, 40000); // Employee role

    stop_cheat_block_timestamp(mock_contract.contract_address);
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(result == 0, 'Invite should return 0');
}

#[test]
#[should_panic(expected: 'UNAUTHORIZED CALLER')]
fn test_invite_member_unauthorized() {
    let mock_contract = deploy_mock_contract();
    let unauthorized_caller = caller();
    let invitee_addr = member();

    start_cheat_caller_address(mock_contract.contract_address, unauthorized_caller);

    mock_contract.invite_member(1, invitee_addr, 40000);

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Invalid Role')]
fn test_invite_member_invalid_role() {
    let mock_contract = deploy_mock_contract();
    let admin_addr = admin();
    let invitee_addr = member();

    start_cheat_caller_address(mock_contract.contract_address, admin_addr);

    mock_contract.invite_member(5, invitee_addr, 40000); // Invalid role

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_accept_invite_successful() {
    let mock_contract = deploy_mock_contract();
    let admin_addr = admin();
    let invitee_addr = member();

    // Admin invites member
    start_cheat_caller_address(mock_contract.contract_address, admin_addr);
    start_cheat_block_timestamp(mock_contract.contract_address, 1000);

    mock_contract.invite_member(1, invitee_addr, 40000); // Employee role

    stop_cheat_caller_address(mock_contract.contract_address);

    // Member accepts invite
    start_cheat_caller_address(mock_contract.contract_address, invitee_addr);
    stop_cheat_block_timestamp(mock_contract.contract_address);

    start_cheat_block_timestamp(mock_contract.contract_address, 1100);

    mock_contract.accept_invite('John', 'Doe', 'johndoe');

    let new_member = mock_contract.get_member(2);

    stop_cheat_caller_address(mock_contract.contract_address);

    assert(new_member.fname == 'John', 'Wrong fname');
    assert(new_member.status == MemberStatus::ACTIVE, 'Wrong status');
    assert(new_member.lname == 'Doe', 'Wrong lname');
    assert(new_member.alias == 'johndoe', 'Wrong alias');
    assert(new_member.role == MemberRole::EMPLOYEE(1), 'Wrong role');
    assert(new_member.address == invitee_addr, 'Wrong address');
}


#[test]
fn test_get_role_value() {
    let mock_contract = deploy_mock_contract();
    let member_addr = member();

    // Add member first
    start_cheat_caller_address(mock_contract.contract_address, member_addr);
    mock_contract.add_member('John', 'Doe', 'johndoe', MemberRole::EMPLOYEE(5), member_addr);
    stop_cheat_caller_address(mock_contract.contract_address);

    let role = mock_contract.get_member(2).role;

    let role_value = calculate_role_value(role, 2);

    // Employee role (5) * multiplier (2) = 10
    assert(role_value == 10, 'Wrong role value calculation');
}


#[test]
#[should_panic(expected: 'Member does not exist')]
fn test_update_member_details_invalid_member() {
    let mock_contract = deploy_mock_contract();
    let caller_addr = caller();

    start_cheat_caller_address(mock_contract.contract_address, caller_addr);

    mock_contract.update_member_details(999, Option::Some('New'), Option::None, Option::None);

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Zero Address Caller')]
fn test_add_member_zero_address() {
    let mock_contract = deploy_mock_contract();

    start_cheat_caller_address(mock_contract.contract_address, contract_address_const::<0>());

    mock_contract.add_member('John', 'Doe', 'johndoe', MemberRole::EMPLOYEE(5), member());

    stop_cheat_caller_address(mock_contract.contract_address);
}
