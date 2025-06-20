use crate::structs::voting::{Poll, PollReason, VotingConfig};

#[starknet::interface]
pub trait IVote<TContractState> {
    fn create_poll(ref self: TContractState, member_id: u256, reason: PollReason) -> u256;
    fn vote(ref self: TContractState, support: bool, poll_id: u256);
    fn set_threshold(ref self: TContractState, threshold: u256);
    fn get_poll(self: @TContractState, poll_id: u256) -> Poll;
    fn get_all_polls(self: @TContractState) -> Array<Poll>;
    // fn end_poll(ref self: TContractState, id: u256);
    fn update_voting_config(ref self: TContractState, config: VotingConfig);
    fn get_threshold(self: @TContractState) -> u256;
}
