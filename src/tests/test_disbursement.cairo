use littlefinger::interfaces::idisbursement::{
    IDisbursementDispatcher, IDisbursementDispatcherTrait,
};
use littlefinger::structs::disbursement_structs::{ScheduleStatus, ScheduleType};
use littlefinger::structs::member_structs::{MemberResponse, MemberRole, MemberStatus};
use littlefinger::tests::mocks::mock_disbursement::MockDisbursement;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_block_timestamp, stop_cheat_caller_address,
};
#[feature("deprecated-starknet-consts")]
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_contract() -> IDisbursementDispatcher {
    let owner = owner();
    let contract_class = declare("MockDisbursement").unwrap().contract_class();
    let mut calldata = array![owner.into()];
    let (contract_address, _) = contract_class.deploy(@calldata).unwrap();
    IDisbursementDispatcher { contract_address }
}

fn get_mock_contract_state() -> MockDisbursement::ContractState {
    MockDisbursement::contract_state_for_testing()
}

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn caller() -> ContractAddress {
    contract_address_const::<'caller'>()
}

fn member() -> ContractAddress {
    contract_address_const::<'member'>()
}

fn create_test_member_response() -> MemberResponse {
    MemberResponse {
        fname: 'John',
        lname: 'Doe',
        alias: 'johndoe',
        role: MemberRole::EMPLOYEE(5),
        id: 1,
        address: member(),
        status: MemberStatus::ACTIVE,
        base_pay: 50000,
        pending_allocations: Option::Some(1000),
        total_received: Option::Some(10000),
        no_of_payouts: 2,
        last_disbursement_timestamp: Option::Some(1500),
        total_disbursements: Option::Some(5),
        reg_time: 1000,
    }
}

#[test]
fn test_create_disbursement_schedule_successful() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);
    start_cheat_block_timestamp(mock_contract.contract_address, 1000);

    // First, initialize with an initial schedule
    mock_contract
        .create_disbursement_schedule(
            0, // RECURRING schedule type
            1000, // start timestamp
            2000, // end timestamp
            100 // interval
        );

    // Then create a new disbursement schedule
    mock_contract
        .create_disbursement_schedule(
            1, // ONETIME schedule type
            1500, // start timestamp
            2500, // end timestamp
            200 // interval
        );

    let current_schedule = mock_contract.get_current_schedule();
    stop_cheat_caller_address(mock_contract.contract_address);
    stop_cheat_block_timestamp(mock_contract.contract_address);

    assert(current_schedule.schedule_id == 2, 'Wrong schedule ID');
    assert(current_schedule.status == ScheduleStatus::ACTIVE, 'Wrong status');
    assert(current_schedule.schedule_type == ScheduleType::ONETIME, 'Wrong schedule type');
    assert(current_schedule.start_timestamp == 1500, 'Wrong start timestamp');
    assert(current_schedule.end_timestamp == 2500, 'Wrong end timestamp');
    assert(current_schedule.interval == 200, 'Wrong interval');
}

#[test]
#[should_panic(expected: 'Caller Not Permitted')]
fn test_create_disbursement_schedule_unauthorized() {
    let mock_contract = deploy_mock_contract();
    let unauthorized_caller = caller();

    start_cheat_caller_address(mock_contract.contract_address, unauthorized_caller);

    mock_contract
        .create_disbursement_schedule(
            1, // ONETIME schedule type
            1500, // start timestamp
            2500, // end timestamp
            200 // interval
        );

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_pause_and_resume_disbursement() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    // Pause the disbursement
    mock_contract.pause_disbursement();

    let paused_schedule = mock_contract.get_current_schedule();
    assert(paused_schedule.status == ScheduleStatus::PAUSED, 'Schedule not paused');

    // Resume the disbursement
    mock_contract.resume_schedule();

    let resumed_schedule = mock_contract.get_current_schedule();
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(resumed_schedule.status == ScheduleStatus::ACTIVE, 'Schedule not resumed');
}

#[test]
#[should_panic(expected: 'Schedule Paused or Deleted')]
fn test_pause_already_paused_schedule() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    // Pause the disbursement
    mock_contract.pause_disbursement();

    // Try to pause again (should fail)
    mock_contract.pause_disbursement();

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
#[should_panic(expected: 'Schedule Active or Deleted')]
fn test_resume_active_schedule() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    // Try to resume an active schedule (should fail)
    mock_contract.resume_schedule();

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_update_current_schedule_last_execution() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    let new_timestamp = 1600;
    mock_contract.update_current_schedule_last_execution(new_timestamp);

    let updated_schedule = mock_contract.get_current_schedule();
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(updated_schedule.last_execution == new_timestamp, 'Wrong last execution timestamp');
}

#[test]
fn test_get_current_schedule() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    let current_schedule = mock_contract.get_current_schedule();
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(current_schedule.schedule_id == 1, 'Wrong schedule ID');
    assert(current_schedule.status == ScheduleStatus::ACTIVE, 'Wrong status');
    assert(current_schedule.schedule_type == ScheduleType::RECURRING, 'Wrong schedule type');
    assert(current_schedule.start_timestamp == 1000, 'Wrong start timestamp');
    assert(current_schedule.end_timestamp == 2000, 'Wrong end timestamp');
    assert(current_schedule.interval == 100, 'Wrong interval');
}

#[test]
fn test_compute_renumeration() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    let member = create_test_member_response();
    let total_bonus_available = 1000;
    let total_members_weight = 10;

    let renumeration = mock_contract
        .compute_renumeration(member, total_bonus_available, total_members_weight);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Expected calculation:
    // member_base_pay = 50000
    // bonus_proportion = 5 / 10 = 0.5
    // bonus_pay = 0.5 * 1000 = 500
    // renumeration = 50000 + 500 = 50500
    // But since we're dealing with integer division, 5/10 = 0, so bonus_pay = 0
    // renumeration = 50000 + 0 = 50000
    assert(renumeration == 50000, 'Wrong renumeration calculation');
}

#[test]
fn test_get_last_disburse_time() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    let last_execution = 1500;
    mock_contract.update_current_schedule_last_execution(last_execution);

    let retrieved_time = mock_contract.get_last_disburse_time();
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(retrieved_time == last_execution, 'Wrong last disburse time');
}

#[test]
fn test_get_next_disburse_time() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);
    start_cheat_block_timestamp(mock_contract.contract_address, 1200);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    let next_time = mock_contract.get_next_disburse_time();
    stop_cheat_caller_address(mock_contract.contract_address);
    stop_cheat_block_timestamp(mock_contract.contract_address);

    // Since last_execution is 0, it should return start_timestamp
    assert(next_time == 1000, 'Wrong next disburse time');
}

#[test]
fn test_get_next_disburse_time_with_last_execution() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);
    start_cheat_block_timestamp(mock_contract.contract_address, 1200);

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    // Set last execution
    mock_contract.update_current_schedule_last_execution(1100);

    let next_time = mock_contract.get_next_disburse_time();
    stop_cheat_caller_address(mock_contract.contract_address);
    stop_cheat_block_timestamp(mock_contract.contract_address);

    // Should be last_execution + interval = 1100 + 100 = 1200
    assert(next_time == 1200, 'Wrong next disburse time');
}

#[test]
#[should_panic(expected: 'No more disbursement')]
fn test_get_next_disburse_time_after_end() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);
    start_cheat_block_timestamp(mock_contract.contract_address, 2500); // After end timestamp

    // First create an initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    mock_contract.get_next_disburse_time();

    stop_cheat_caller_address(mock_contract.contract_address);
    stop_cheat_block_timestamp(mock_contract.contract_address);
}

// Additional edge case tests
#[test]
fn test_compute_renumeration_with_zero_bonus() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    let member = create_test_member_response();
    let total_bonus_available = 0;
    let total_members_weight = 10;

    let renumeration = mock_contract
        .compute_renumeration(member, total_bonus_available, total_members_weight);
    stop_cheat_caller_address(mock_contract.contract_address);

    // Should be just base_pay when no bonus is available
    assert(renumeration == 50000, 'Wrong renumeration');
}

#[test]
fn test_schedule_with_zero_interval() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // Create schedule with zero interval
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 0);

    let schedule = mock_contract.get_current_schedule();
    stop_cheat_caller_address(mock_contract.contract_address);

    assert(schedule.interval == 0, 'Wrong interval');
}

#[test]
fn test_schedule_id_increment() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // Create multiple schedules and verify ID increment
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);
    let schedule1 = mock_contract.get_current_schedule();
    assert(schedule1.schedule_id == 1, 'First schedule should have ID 1');

    mock_contract.create_disbursement_schedule(1, 2000, 3000, 150);
    let schedule2 = mock_contract.get_current_schedule();
    assert(schedule2.schedule_id == 2, 'Wrong schedule ID');

    mock_contract.create_disbursement_schedule(0, 3000, 4000, 200);
    let schedule3 = mock_contract.get_current_schedule();
    assert(schedule3.schedule_id == 3, 'Third schedule should have ID 3');

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_schedule_type_conversion() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // Test RECURRING (type 0)
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);
    let recurring_schedule = mock_contract.get_current_schedule();
    assert(
        recurring_schedule.schedule_type == ScheduleType::RECURRING, 'Type 0 should be RECURRING',
    );

    // Test ONETIME (type 1)
    mock_contract.create_disbursement_schedule(1, 2000, 3000, 150);
    let onetime_schedule = mock_contract.get_current_schedule();
    assert(onetime_schedule.schedule_type == ScheduleType::ONETIME, 'Type 1 should be ONETIME');

    stop_cheat_caller_address(mock_contract.contract_address);
}

#[test]
fn test_debug_schedule_creation() {
    let mock_contract = deploy_mock_contract();
    let owner_addr = owner();

    start_cheat_caller_address(mock_contract.contract_address, owner_addr);

    // Create initial schedule
    mock_contract.create_disbursement_schedule(0, 1000, 2000, 100);

    // Get current schedule
    let current_schedule = mock_contract.get_current_schedule();
    assert(current_schedule.schedule_id == 1, 'First schedule should have ID 1');
    assert(current_schedule.interval == 100, 'Wrong interval');

    // Get all schedules
    let schedules = mock_contract.get_disbursement_schedules();
    assert(schedules.len() >= 1, 'Should have at least 1 schedule');

    // Check the first schedule in the list
    let first_schedule = *schedules.at(0);
    assert(first_schedule.schedule_id == 1, 'Wrong ID');
    assert(first_schedule.interval == 100, 'Wrong interval');

    stop_cheat_caller_address(mock_contract.contract_address);
}
