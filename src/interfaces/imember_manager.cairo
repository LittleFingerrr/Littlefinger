use littlefinger::structs::member_structs::{MemberConfig, MemberResponse, MemberRole};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemberManager<TContractState> {
    fn add_member(
        ref self: TContractState,
        fname: felt252,
        lname: felt252,
        alias: felt252,
        role: MemberRole,
        address: ContractAddress,
        // base_pay: u256
    // weight: u256
    ); //-> u256;
    fn add_admin(ref self: TContractState, member_id: u256);
    fn invite_member(
        ref self: TContractState, role: u16, address: ContractAddress, renumeration: u256,
    ) -> felt252;
    // fn get_member_invite()
    fn accept_invite(ref self: TContractState, fname: felt252, lname: felt252, alias: felt252);
    // fn verify_member(ref self: TContractState, address: ContractAddress);
    fn update_member_details(
        ref self: TContractState,
        member_id: u256,
        fname: Option<felt252>,
        lname: Option<felt252>,
        alias: Option<felt252>,
    );
    // pub id: u256,
    // pub address: ContractAddress,
    // pub status: MemberStatus,
    // pub role: MemberRole,
    // pub base_pay: u256,
    fn update_member_base_pay(ref self: TContractState, member_id: u256, base_pay: u256);
    fn get_member_base_pay(ref self: TContractState, member_id: u256) -> u256;
    fn suspend_member(
        ref self: TContractState,
        member_id: u256 // suspension_duration: u64 //block timestamp operation
    );
    fn reinstate_member(ref self: TContractState, member_id: u256);
    fn get_members(self: @TContractState) -> Span<MemberResponse>;
    fn get_member(self: @TContractState, member_id: u256) -> MemberResponse;
    fn update_member_config(ref self: TContractState, config: MemberConfig);
    fn record_member_payment(
        ref self: TContractState, member_id: u256, amount: u256, timestamp: u64,
    );
    // ROLE MANAGEMENT

    // ALLOCATION WEIGHT MANAGEMENT (PROMOTION & DELETION)

}
