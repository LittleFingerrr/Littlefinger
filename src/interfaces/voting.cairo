use crate::structs::voting::{Poll, VotingConfig};

#[starknet::interface]
pub trait IVote<TContractState> {
    fn create_poll(
        ref self: TContractState, name: ByteArray, desc: ByteArray, member_id: u256,
    ) -> u256;
    fn vote(ref self: TContractState, support: bool, id: u256);
    fn get_poll(self: @TContractState, id: u256) -> Poll;
    fn end_poll(ref self: TContractState, id: u256);
    fn update_voting_config(ref self: TContractState, config: VotingConfig);
}
