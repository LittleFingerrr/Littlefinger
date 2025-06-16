use littlefinger::structs::vault_structs::{Transaction, VaultStatus};
use starknet::ContractAddress;

#[starknet::interface]
pub trait IVault<TContractState> {
    fn deposit_funds(ref self: TContractState, amount: u256, address: ContractAddress);
    fn withdraw_funds(ref self: TContractState, amount: u256, address: ContractAddress);
    fn emergency_freeze(ref self: TContractState);
    fn unfreeze_vault(ref self: TContractState);
    // fn bulk_transfer(ref self: TContractState, recipients: Span<ContractAddress>);
    fn pay_member(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn add_to_bonus_allocation(ref self: TContractState, amount: u256, address: ContractAddress);
    fn get_balance(self: @TContractState) -> u256;
    fn get_vault_status(self: @TContractState) -> VaultStatus;
    fn get_bonus_allocation(self: @TContractState) -> u256;
    fn get_transaction_history(self: @TContractState) -> Array<Transaction>;
    fn allow_org_core_address(ref self: TContractState, org_address: ContractAddress);
}
