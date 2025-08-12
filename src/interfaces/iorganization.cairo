use starknet::ContractAddress;
use crate::structs::organization::{OrganizationConfig, OrganizationInfo};

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
}
