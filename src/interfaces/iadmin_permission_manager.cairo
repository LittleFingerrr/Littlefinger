use littlefinger::structs::admin_permissions::AdminPermission;
use starknet::ContractAddress;

/// # IAdminPermissionManager
///
/// This trait defines the public interface for an admin permission management component.
/// It outlines the essential functions for handling administrative permissions within an
/// organization, including granting, revoking, and querying permissions for administrators. This
/// interface enables fine-grained control over what actions different administrators can perform.
/// This interface is designed to be implemented by a Starknet component that manages
/// the lifecycle and assignment of administrative permissions.
#[starknet::interface]
pub trait IAdminPermissionManager<TContractState> {
    /// # has_admin_permission
    ///
    /// Checks if a specific admin has a particular permission.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `admin`: The contract address of the admin to check.
    /// - `permission`: The specific permission to verify.
    ///
    /// ## Returns
    ///
    /// A boolean indicating whether the admin has the specified permission.
    fn has_admin_permission(
        self: @TContractState, admin: ContractAddress, permission: AdminPermission,
    ) -> bool;

    /// # get_admin_permissions
    ///
    /// Retrieves all permissions currently granted to a specific admin.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `admin`: The contract address of the admin whose permissions to retrieve.
    ///
    /// ## Returns
    ///
    /// An array of `AdminPermission` values representing all permissions granted to the admin.
    fn get_admin_permissions(
        self: @TContractState, admin: ContractAddress,
    ) -> Array<AdminPermission>;

    /// # grant_admin_permission
    ///
    /// Grants a specific permission to an admin. This is a privileged action that requires
    /// the caller to have GRANT_PERMISSIONS permission or be the owner.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `admin`: The contract address of the admin to grant permission to.
    /// - `permission`: The specific permission to grant.
    fn grant_admin_permission(
        ref self: TContractState, admin: ContractAddress, permission: AdminPermission,
    );

    /// # revoke_admin_permission
    ///
    /// Revokes a specific permission from an admin. This is a privileged action that requires
    /// the caller to have GRANT_PERMISSIONS permission or be the owner. Owner permissions cannot be
    /// revoked.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `admin`: The contract address of the admin to revoke permission from.
    /// - `permission`: The specific permission to revoke.
    fn revoke_admin_permission(
        ref self: TContractState, admin: ContractAddress, permission: AdminPermission,
    );

    /// # grant_all_admin_permissions
    ///
    /// Grants all available permissions to an admin at once. This is a privileged action
    /// that requires the caller to have GRANT_PERMISSIONS permission or be the owner.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `admin`: The contract address of the admin to grant all permissions to.
    fn grant_all_admin_permissions(ref self: TContractState, admin: ContractAddress);

    /// # revoke_all_admin_permissions
    ///
    /// Revokes all permissions from an admin at once. This is a privileged action
    /// that requires the caller to have GRANT_PERMISSIONS permission or be the owner.
    /// Owner permissions cannot be revoked.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `admin`: The contract address of the admin to revoke all permissions from.
    fn revoke_all_admin_permissions(ref self: TContractState, admin: ContractAddress);

    /// # get_owner
    ///
    /// Retrieves the owner address of the contract. The owner has all permissions by default
    /// and their permissions cannot be revoked.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The `ContractAddress` of the contract owner.
    fn get_owner(self: @TContractState) -> ContractAddress;

    /// # is_owner
    ///
    /// Checks if a given address is the contract owner.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `address`: The contract address to check for ownership.
    ///
    /// ## Returns
    ///
    /// A boolean indicating whether the address is the contract owner.
    fn is_owner(self: @TContractState, address: ContractAddress) -> bool;

    /// # permissions_to_mask
    ///
    /// Converts an array of permissions to a bitmask representation for efficient storage and
    /// operations.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `permissions`: An array of `AdminPermission` values to convert.
    ///
    /// ## Returns
    ///
    /// A `u16` bitmask representing the permissions.
    fn permissions_to_mask(self: @TContractState, permissions: Array<AdminPermission>) -> u16;

    /// # permissions_from_mask
    ///
    /// Converts a bitmask representation back to an array of permissions.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `mask`: A `u16` bitmask representing permissions.
    ///
    /// ## Returns
    ///
    /// An array of `AdminPermission` values represented by the bitmask.
    fn permissions_from_mask(self: @TContractState, mask: u16) -> Array<AdminPermission>;

    /// # is_valid_admin_mask
    ///
    /// Validates whether a bitmask represents a valid combination of admin permissions.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `mask`: A `u16` bitmask to validate.
    ///
    /// ## Returns
    ///
    /// A boolean indicating whether the bitmask is valid.
    fn is_valid_admin_mask(self: @TContractState, mask: u16) -> bool;
}
