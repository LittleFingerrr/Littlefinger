use littlefinger::interfaces::dao_controller::{IVoteDispatcher, IVoteDispatcherTrait};
use littlefinger::interfaces::imember_manager::{
    IMemberManagerDispatcher, IMemberManagerDispatcherTrait,
};
use littlefinger::structs::dao_controller::{
    Poll, PollCreated, PollReason, PollResolved, PollStatus, PollStopped, PollTrait,
    ThresholdChanged, Voted, VotingConfig, VotingConfigNode, ADDMEMBER,
};
use littlefinger::structs::member_structs::{MemberInvite, MemberRoleIntoU16, MemberRole, InviteStatus};
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