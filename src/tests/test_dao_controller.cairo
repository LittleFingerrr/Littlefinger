use littlefinger::interfaces::dao_controller::{IVoteDispatcher, IVoteDispatcherTrait};
use littlefinger::structs::dao_controller::{
    Poll, PollCreated, PollReason, PollResolved, PollStatus, PollStopped, PollTrait,
    ThresholdChanged, Voted, VotingConfig, VotingConfigNode,
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
        private: true, threshold: 1000, weighted: true, weighted_with: dummy_address(),
    };
    let contract_class = declare("MockDAOController").unwrap().contract_class();
    let mut calldata = array![admin.into()];
    Serde::serialize(@config, ref calldata);
    threshold.serialize(ref calldata);
    let (contract_address, _) = contract_class.deploy(@calldata.into()).unwrap();
    IVoteDispatcher { contract_address }
}

fn admin() -> ContractAddress {
    contract_address_const::<'admin'>()
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

fn unauthorized_caller() -> ContractAddress {
    contract_address_const::<'unauthorized'>()
}
