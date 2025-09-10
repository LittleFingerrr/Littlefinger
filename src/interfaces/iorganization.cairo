use starknet::ContractAddress;
use crate::structs::organization::{Contract, ContractType, OrganizationConfig, OrganizationInfo};

// Some functions here might require multiple signing to execute.
/// # IOrganization
///
/// This trait defines the public interface for an organization component.
/// It outlines functions for managing high-level organizational settings,
/// such as ownership, committee members, and configuration. In a production
/// environment, sensitive functions might be protected by multi-signature checks.
#[starknet::interface]
pub trait IOrganization<TContractState> {
    /// # transfer_organization_claim
    ///
    /// Transfers ownership of the organization to a new address.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `to`: The `ContractAddress` of the new owner.
    fn transfer_organization_claim(ref self: TContractState, to: ContractAddress);

    /// # adjust_committee
    ///
    /// Modifies the composition of the organization's governing committee.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `add`: An `Array` of `ContractAddress` to be added to the committee.
    /// - `subtract`: An `Array` of `ContractAddress` to be removed from the committee.
    fn adjust_committee(
        ref self: TContractState, add: Array<ContractAddress>, subtract: Array<ContractAddress>,
    );

    /// # update_organization_config
    ///
    /// Updates the general configuration settings for the organization.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `config`: An `OrganizationConfig` struct containing the new configuration values.
    fn update_organization_config(ref self: TContractState, config: OrganizationConfig);

    /// # get_organization_details
    ///
    /// Retrieves the fundamental information about the organization.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// An `OrganizationInfo` struct containing the organization's details.
    fn get_organization_details(self: @TContractState) -> OrganizationInfo;
    // fn create_contract(
    //     ref self: TContractState,
    //     contract_type: ContractType,
    //     parties: Array<ContractAddress>,
    //     ipfs_hash: felt252,
    //     expiry: Option<u64>,
    // );

    fn create_company_to_member_contract(
        ref self: TContractState,
        contract_type: ContractType,
        member_id: u256,
        ipfs_hash: felt252,
        expiry: Option<u64>,
    );

    fn create_company_to_partner_contract(
        ref self: TContractState,
        contract_type: ContractType,
        partner_address: ContractAddress,
        ipfs_hash: felt252,
        expiry: Option<u64>,
    );

    fn sign_contract(ref self: TContractState, contract_id: u256, signature: Array<felt252>);

    fn update_contract(
        ref self: TContractState, contract_id: u256, new_ipfs_hash: felt252, expiry: Option<u64>,
    );

    fn terminate_contract(ref self: TContractState, contract_id: u256, signature: Array<felt252>);

    fn get_contract(self: @TContractState, contract_id: u256) -> Contract;
}
