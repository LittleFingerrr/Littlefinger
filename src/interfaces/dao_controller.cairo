use crate::structs::dao_controller::{Poll, PollReason, VotingConfig};

#[starknet::interface]
pub trait IVote<TContractState> {
    fn create_poll(ref self: TContractState, member_id: u256, reason: PollReason) -> u256;
    fn approve(ref self: TContractState, poll_id: u256, member_id: u256);
    fn reject(ref self: TContractState, poll_id: u256, member_id: u256);
    fn set_threshold(ref self: TContractState, new_threshold: u256, member_id: u256);
    fn get_poll(self: @TContractState, poll_id: u256) -> Poll;
    fn get_all_polls(self: @TContractState) -> Array<Poll>;
    // fn end_poll(ref self: TContractState, id: u256);
    fn update_voting_config(ref self: TContractState, config: VotingConfig);
    fn get_threshold(self: @TContractState) -> u256;
    fn get_eligible_voters(self: @TContractState) -> Array<u256>;
    fn get_eligible_pollers(self: @TContractState) -> Array<u256>;
    fn get_eligible_executors(self: @TContractState) -> Array<u256>;
}
