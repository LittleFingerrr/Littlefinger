use littlefinger::interfaces::dao_controller::{IVoteDispatcher, IVoteDispatcherTrait};
use littlefinger::interfaces::imember_manager::{
    IMemberManagerDispatcher, IMemberManagerDispatcherTrait,
};
use littlefinger::structs::dao_controller::{
    ADDMEMBER, Poll, PollCreated, PollReason, PollResolved, PollStatus, PollStopped, PollTrait,
    ThresholdChanged, Voted, VotingConfig, VotingConfigNode,
};
use littlefinger::structs::member_structs::{
    InviteStatus, MemberInvite, MemberRole, MemberRoleIntoU16,
};
use littlefinger::tests::mocks::mock_dao_controller::MockDaoController;
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_block_timestamp,
    start_cheat_caller_address, stop_cheat_block_timestamp, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_voting_contract() -> IVoteDispatcher {
    let admin: ContractAddress = admin();
    let threshold: u256 = 2.into(); // Minimum votes required to resolve poll
    let config: VotingConfig = VotingConfig {
        private: true, threshold: 1000, weighted: true, weighted_with: admin.into(),
    };
    let contract_class = declare("MockDaoController").unwrap().contract_class();
    let mut calldata = array![admin.into()];
    Serde::serialize(@config, ref calldata);
    threshold.serialize(ref calldata);
    let first_admin_fname: felt252 = 'Admin';
    let first_admin_lname: felt252 = 'User';
    let first_admin_alias: felt252 = 'adminuser';
    first_admin_fname.serialize(ref calldata);
    first_admin_lname.serialize(ref calldata);
    first_admin_alias.serialize(ref calldata);
    let member1: ContractAddress = member1();
    let member2: ContractAddress = member2();
    let member3: ContractAddress = member3();
    member1.serialize(ref calldata);
    member2.serialize(ref calldata);
    member3.serialize(ref calldata);
    let (contract_address, _) = contract_class.deploy(@calldata.into()).unwrap();
    IVoteDispatcher { contract_address }
}

fn admin() -> ContractAddress {
    contract_address_const::<'admin'>()
}

fn admin_details() -> (felt252, felt252, felt252) {
    ('Admin', 'User', 'adminuser')
}

fn dummy_address() -> ContractAddress {
    contract_address_const::<'dummy'>()
}

fn member1() -> ContractAddress {
    contract_address_const::<'member1'>()
}

fn member2() -> ContractAddress {
    contract_address_const::<'member2'>()
}

fn member3() -> ContractAddress {
    contract_address_const::<'member3'>()
}

fn member4() -> ContractAddress {
    contract_address_const::<'member4'>()
}

fn unauthorized_caller() -> ContractAddress {
    contract_address_const::<'unauthorized'>()
}

fn multiple_approve(voting: IVoteDispatcher, poll_id: u256) {
    start_cheat_caller_address(voting.contract_address, member1());
    let mut member_id: u256 = 2;
    voting.approve(poll_id, member_id);
    stop_cheat_caller_address(voting.contract_address);
    start_cheat_caller_address(voting.contract_address, member2());
    member_id = 3;
    voting.approve(poll_id, member_id);
    stop_cheat_caller_address(voting.contract_address);
    start_cheat_caller_address(voting.contract_address, member3());
    member_id = 4;
    voting.approve(poll_id, member_id);
    stop_cheat_caller_address(voting.contract_address);
}


#[test]
fn test_poll_creation_success() {
    let voting = deploy_mock_voting_contract();

    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);
    let member_invite_instance = MemberInvite {
        address: member1(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member1() };

    let member1_id = 2;

    let reason = PollReason::ADDMEMBER(add_member_data);
    let poll_id = voting.create_poll(member1_id, reason);

    assert(poll_id == 0, 'Poll ID should be 0');
    let poll = voting.get_poll(poll_id);
    assert(poll.proposer == member1_id, 'Proposer ID should match');
    assert(poll.poll_id == poll_id, 'Poll ID should match');
    assert(poll.reason == reason, 'Poll reason should match');
    assert(poll.up_votes == 0, 'Up votes should be 0');
    assert(poll.down_votes == 0, 'Down votes should be 0');
    assert(poll.status == PollStatus::ACTIVE, 'Poll status should be ACTIVE');
    assert(poll.created_at == 1000, 'Poll timestamp should match');

    stop_cheat_caller_address(voting.contract_address);
    stop_cheat_block_timestamp(voting.contract_address);
}

#[test]
#[should_panic(expected: 'VERIFICATION FAILED')]
fn test_poll_creation_fail_verification() {
    let voting = deploy_mock_voting_contract();

    let member_invite_instance = MemberInvite {
        address: member4(),
        role: MemberRole::None,
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member4() };

    start_cheat_caller_address(voting.contract_address, unauthorized_caller());
    start_cheat_block_timestamp(voting.contract_address, 1000);

    let member1_id = 2;
    let reason = PollReason::ADDMEMBER(add_member_data);

    voting.create_poll(member1_id, reason);
}

#[test]
fn test_poll_approval_success() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);
    let member_invite_instance = MemberInvite {
        address: member4(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member4() };
    let member1_id = 2;
    let reason = PollReason::ADDMEMBER(add_member_data);
    let poll_id = voting.create_poll(member1_id, reason);
    voting.approve(poll_id, member1_id);
    let poll = voting.get_poll(poll_id);
    assert(poll.up_votes == 1, 'Up votes should be 1');
    assert(poll.down_votes == 0, 'Down votes should be 0');
    assert(poll.status == PollStatus::ACTIVE, 'Poll status not ACTIVE');
    assert(poll.created_at == 1000, 'Poll timestamp should match');

    stop_cheat_caller_address(voting.contract_address);
    stop_cheat_block_timestamp(voting.contract_address);
}

#[test]
#[should_panic(expected: 'CALLER HAS VOTED')]
fn test_poll_approval_fail_double_vote() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);
    let member_invite_instance = MemberInvite {
        address: member4(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member4() };
    let member1_id = 2;
    let reason = PollReason::ADDMEMBER(add_member_data);
    let poll_id = voting.create_poll(member1_id, reason);
    voting.approve(poll_id, member1_id);
    voting.approve(poll_id, member1_id);
}

#[test]
#[should_panic(expected: 'POLL NOT ACTIVE')]
fn test_poll_approval_fail_inactive_poll() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);
    let member_invite_instance = MemberInvite {
        address: member4(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member4() };
    let member_id = 2;
    let reason = PollReason::ADDMEMBER(add_member_data);
    let poll_id = voting.create_poll(member_id, reason);
    stop_cheat_block_timestamp(voting.contract_address);
    multiple_approve(voting, poll_id);
    let mut poll = voting.get_poll(poll_id);
    poll.resolve(2);
    start_cheat_caller_address(voting.contract_address, admin());
    voting.approve(poll_id, 1);
    stop_cheat_caller_address(voting.contract_address);
}

#[test]
fn test_poll_rejection_success() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);
    let member_invite_instance = MemberInvite {
        address: member4(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member4() };
    let member1_id = 2;
    let reason = PollReason::ADDMEMBER(add_member_data);
    let poll_id = voting.create_poll(member1_id, reason);
    voting.reject(poll_id, member1_id);
    let poll = voting.get_poll(poll_id);
    assert(poll.up_votes == 0, 'Up votes should be 0');
    assert(poll.down_votes == 1, 'Down votes should be 1');
    assert(poll.status == PollStatus::ACTIVE, 'Poll status not ACTIVE');
    assert(poll.created_at == 1000, 'Poll timestamp should match');

    stop_cheat_caller_address(voting.contract_address);
    stop_cheat_block_timestamp(voting.contract_address);
}

#[test]
#[should_panic(expected: 'CALLER HAS VOTED')]
fn test_poll_rejection_fail_double_vote() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);
    let member_invite_instance = MemberInvite {
        address: member4(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member4() };
    let member1_id = 2;
    let reason = PollReason::ADDMEMBER(add_member_data);
    let poll_id = voting.create_poll(member1_id, reason);
    voting.reject(poll_id, member1_id);
    voting.reject(poll_id, member1_id);
}

#[test]
#[should_panic(expected: 'POLL NOT ACTIVE')]
fn test_poll_reject_fail_inactive_poll() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);
    let member_invite_instance = MemberInvite {
        address: member4(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member4() };
    let member_id = 2;
    let reason = PollReason::ADDMEMBER(add_member_data);
    let poll_id = voting.create_poll(member_id, reason);
    stop_cheat_block_timestamp(voting.contract_address);
    multiple_approve(voting, poll_id);
    let mut poll = voting.get_poll(poll_id);
    poll.resolve(2);
    start_cheat_caller_address(voting.contract_address, admin());
    voting.reject(poll_id, 1);
    stop_cheat_caller_address(voting.contract_address);
}

#[test]
fn test_set_threshold_success() {
    let voting = deploy_mock_voting_contract();

    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);

    let prev_threshold = voting.get_threshold();

    let member1_id = 2;
    let new_threshold: u256 = 42;

    voting.set_threshold(new_threshold, member1_id);

    let updated_threshold = voting.get_threshold();
    assert(updated_threshold == new_threshold, 'Threshold should be updated');
    assert(updated_threshold != prev_threshold, 'Threshold should change');

    stop_cheat_caller_address(voting.contract_address);
    stop_cheat_block_timestamp(voting.contract_address);
}


#[test]
#[should_panic(expected: 'VERIFICATION FAILED')]
fn test_set_threshold_fail_verification() {
    let voting = deploy_mock_voting_contract();

    start_cheat_caller_address(voting.contract_address, unauthorized_caller());
    start_cheat_block_timestamp(voting.contract_address, 1000);

    let member_id = 2;
    let new_threshold: u256 = 77;

    voting.set_threshold(new_threshold, member_id);

    stop_cheat_caller_address(voting.contract_address);
    stop_cheat_block_timestamp(voting.contract_address);
}

#[test]
fn test_get_all_polls_returns_all_created_polls() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);

    let member_invite_instance = MemberInvite {
        address: member1(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member1() };
    let reason = PollReason::ADDMEMBER(add_member_data);

    let poll_id_1 = voting.create_poll(2, reason);
    let poll_id_2 = voting.create_poll(2, reason);

    let polls = voting.get_all_polls();
    println!("Poll len: {}", polls.len());
    assert(*polls.at(0).poll_id == poll_id_1, 'First poll id mismatch');
    assert(*polls.at(1).poll_id == poll_id_2, 'Second poll id mismatch');

    stop_cheat_caller_address(voting.contract_address);
    stop_cheat_block_timestamp(voting.contract_address);
}

#[test]
fn test_get_threshold_returns_current_threshold() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());

    let initial_threshold = voting.get_threshold();
    assert(initial_threshold == 2, 'Initial threshold incorrect');

    let new_threshold: u256 = 55;
    voting.set_threshold(new_threshold, 2);
    let updated_threshold = voting.get_threshold();
    assert(updated_threshold == new_threshold, 'Threshold should be updated');

    stop_cheat_caller_address(voting.contract_address);
}

#[test]
fn test_get_poll_returns_correct_poll() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());
    start_cheat_block_timestamp(voting.contract_address, 1000);

    let member_invite_instance = MemberInvite {
        address: member1(),
        role: MemberRole::EMPLOYEE(5),
        base_pay: 5_u256,
        invite_status: InviteStatus::PENDING,
        expiry: 2000,
    };
    let add_member_data = ADDMEMBER { member: member_invite_instance, member_address: member1() };
    let reason = PollReason::ADDMEMBER(add_member_data);

    let poll_id = voting.create_poll(2, reason);
    let poll = voting.get_poll(poll_id);

    assert(poll.poll_id == poll_id, 'Poll id mismatch');
    assert(poll.proposer == 2, 'Proposer id mismatch');
    assert(poll.reason == reason, 'Poll reason mismatch');

    stop_cheat_caller_address(voting.contract_address);
    stop_cheat_block_timestamp(voting.contract_address);
}

#[test]
fn test_update_voting_config_does_not_panic() {
    let voting = deploy_mock_voting_contract();
    start_cheat_caller_address(voting.contract_address, member1());

    let config = VotingConfig {
        private: false, threshold: 123, weighted: false, weighted_with: member1(),
    };
    voting.update_voting_config(config);

    stop_cheat_caller_address(voting.contract_address);
}

#[test]
fn test_get_eligible_voters_returns_expected_ids() {
    let voting = deploy_mock_voting_contract();
    let eligible_voters = voting.get_eligible_voters();
    assert(eligible_voters.len() > 0, 'Incorrect eligible voters');
}

#[test]
fn test_get_eligible_pollers_returns_expected_ids() {
    let voting = deploy_mock_voting_contract();
    let eligible_pollers = voting.get_eligible_pollers();
    assert(eligible_pollers.len() > 0, 'Incorrect eligible pollers');
}

#[test]
fn test_get_eligible_executors_returns_expected_ids() {
    let voting = deploy_mock_voting_contract();
    let eligible_executors = voting.get_eligible_executors();
    assert(eligible_executors.len() > 0, 'incorrect eligible executors');
}
