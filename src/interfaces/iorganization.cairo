use starknet::ContractAddress;
use crate::structs::organization::{OrganizationConfig, OrganizationInfo};

// Some functions here might require multiple signing to execute.
#[starknet::interface]
pub trait IOrganization<TContractState> {
    fn transfer_organization_claim(ref self: TContractState, to: ContractAddress);
    fn adjust_committee(
        ref self: TContractState, add: Array<ContractAddress>, subtract: Array<ContractAddress>,
    );
    fn update_organization_config(ref self: TContractState, config: OrganizationConfig);
    fn get_organization_details(self: @TContractState) -> OrganizationInfo;
}
