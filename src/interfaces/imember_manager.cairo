use littlefinger::structs::member_structs::{MemberConfig, MemberResponse};
use starknet::ContractAddress;

/// # IMemberManager
///
/// This trait defines the public interface for a member management component.
/// It outlines the essential functions for handling members within an organization,
/// including their addition, invitation, and the modification and retrieval of their data.
/// This interface is designed to be implemented by a Starknet component that manages
/// the lifecycle and properties of organization members.
#[starknet::interface]
pub trait IMemberManager<TContractState> {
    /// # add_member
    ///
    /// Directly adds a new member to the organization. This is typically an administrative action.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `fname`: The first name of the new member.
    /// - `lname`: The last name of the new member.
    /// - `alias`: A unique alias or username for the member.
    /// - `role`: A numerical value representing the member's role (e.g., 0-14).
    /// - `address`: The Starknet contract address of the new member.
    fn add_member(
        ref self: TContractState,
        fname: felt252,
        lname: felt252,
        alias: felt252,
        role: u16, // Role goes from 0 to 14
        address: ContractAddress,
        // weight: u256
    ); //-> u256;

    /// # add_admin
    ///
    /// Promotes an existing member to an admin role. This is a privileged action.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `member_id`: The unique identifier of the member to be granted admin rights.
    fn add_admin(ref self: TContractState, member_id: u256);

    /// # invite_member
    ///
    /// Creates and sends an invitation to a prospective member.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `role`: The numerical role identifier for the invitee.
    /// - `address`: The Starknet address to which the invitation is sent.
    /// - `renumeration`: The proposed renumeration or base pay for the invitee.
    ///
    /// ## Returns
    ///
    /// A `felt252` value, often used for status or tracking purposes.
    fn invite_member(
        ref self: TContractState, role: u16, address: ContractAddress, renumeration: u256,
    ) -> felt252;

    // fn get_member_invite()

    /// # accept_invite
    ///
    /// Allows a user to accept a pending invitation and officially become a member.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `fname`: The first name of the accepting user.
    /// - `lname`: The last name of the accepting user.
    /// - `alias`: An alias for the new member.
    fn accept_invite(ref self: TContractState, fname: felt252, lname: felt252, alias: felt252);

    // fn verify_member(ref self: TContractState, address: ContractAddress);

    /// # update_member_details
    ///
    /// Updates the personal details of an existing member.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `member_id`: The ID of the member to update.
    /// - `fname`: An optional new first name.
    /// - `lname`: An optional new last name.
    /// - `alias`: An optional new alias.
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

    /// # update_member_base_pay
    ///
    /// Updates the base pay for a specific member.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `member_id`: The ID of the member whose base pay is to be updated.
    /// - `base_pay`: The new base pay amount.
    fn update_member_base_pay(ref self: TContractState, member_id: u256, base_pay: u256);

    /// # get_member_base_pay
    ///
    /// Retrieves the base pay of a specific member.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `member_id`: The ID of the member.
    ///
    /// ## Returns
    ///
    /// The base pay of the member as a `u256`.
    fn get_member_base_pay(ref self: TContractState, member_id: u256) -> u256;

    /// # suspend_member
    ///
    /// Suspends a member, temporarily revoking their active status.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `member_id`: The ID of the member to be suspended.
    fn suspend_member(
        ref self: TContractState,
        member_id: u256 // suspension_duration: u64 //block timestamp operation
    );

    /// # reinstate_member
    ///
    /// Reinstates a previously suspended member to active status.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `member_id`: The ID of the member to be reinstated.
    fn reinstate_member(ref self: TContractState, member_id: u256);

    /// # get_members
    ///
    /// Retrieves a list of all members in the organization.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// A `Span<MemberResponse>` containing the data of all members.
    fn get_members(self: @TContractState) -> Span<MemberResponse>;

    /// # get_member
    ///
    /// Retrieves detailed information for a single member.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `member_id`: The ID of the member to retrieve.
    ///
    /// ## Returns
    ///
    /// A `MemberResponse` struct with the member's details.
    fn get_member(self: @TContractState, member_id: u256) -> MemberResponse;

    /// # update_member_config
    ///
    /// Updates the general configuration settings for members.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `config`: A `MemberConfig` struct with the new configuration values.
    fn update_member_config(ref self: TContractState, config: MemberConfig);

    /// # record_member_payment
    ///
    /// Records a payment made to a member.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `member_id`: The ID of the member receiving the payment.
    /// - `amount`: The amount of the payment.
    /// - `timestamp`: The timestamp of the payment transaction.
    fn record_member_payment(
        ref self: TContractState, member_id: u256, amount: u256, timestamp: u64,
    );

    /// # get_factory_address
    ///
    /// Retrieves the address of the associated factory contract.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The `ContractAddress` of the factory contract.
    fn get_factory_address(self: @TContractState) -> ContractAddress;

    /// # get_core_org_address
    ///
    /// Retrieves the address of the core organization contract.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The `ContractAddress` of the core organization contract.
    fn get_core_org_address(self: @TContractState) -> ContractAddress;
    // ROLE MANAGEMENT

    // ALLOCATION WEIGHT MANAGEMENT (PROMOTION & DEMOTION)
    fn is_admin(self: @TContractState, member_address: ContractAddress) -> bool;

}
