//! Admin permission control system for managing administrative permissions in LittleFinger.

/// ## A Starknet component responsible for managing administrative permissions within an
/// organization.
///
/// This component handles:
/// - Permission granting and revoking
/// - Owner privilege management
/// - Permission validation and querying
/// - Bitmask operations for efficient storage
/// - Event emission for permission changes
///
/// The component ensures that only authorized users can modify permissions and provides
/// fine-grained control over administrative capabilities within the organization.
#[starknet::component]
pub mod AdminPermissionManagerComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    use crate::interfaces::iadmin_permission_manager::IAdminPermissionManager;
    use crate::structs::admin_permissions::{
        AdminPermission, AdminPermissionGranted, AdminPermissionIntoFelt252, AdminPermissionRevoked,
        AdminPermissionTrait, AllAdminPermissionsGranted, AllAdminPermissionsRevoked,
    };

    /// Defines the storage layout for the `AdminPermissionManagerComponent`.
    #[storage]
    pub struct Storage {
        /// Maps (permission_felt252, admin_address) to boolean indicating if permission is granted.
        /// This allows efficient lookup of specific permissions for specific admins.
        pub admin_permissions: Map<(felt252, ContractAddress), bool>,
        /// The owner address who has all permissions by default and cannot have permissions
        /// revoked.
        pub owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        AdminPermissionGranted: AdminPermissionGranted,
        AdminPermissionRevoked: AdminPermissionRevoked,
        AllAdminPermissionsGranted: AllAdminPermissionsGranted,
        AllAdminPermissionsRevoked: AllAdminPermissionsRevoked,
    }

    #[embeddable_as(AdminPermissionManagerImpl)]
    impl AdminPermissionManager<
        TContractState, +HasComponent<TContractState>,
    > of IAdminPermissionManager<ComponentState<TContractState>> {
        /// # has_admin_permission
        ///
        /// Checks if a specific admin has a particular permission.
        /// The owner always has all permissions and returns true for any permission check.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        /// - `admin`: The contract address of the admin to check.
        /// - `permission`: The specific permission to verify.
        ///
        /// ## Returns
        ///
        /// A boolean indicating whether the admin has the specified permission.
        ///
        /// ## Implementation Details
        ///
        /// - Owner check is performed first for efficiency
        /// - Permission is converted to felt252 for storage lookup
        /// - Uses efficient map lookup for permission verification
        fn has_admin_permission(
            self: @ComponentState<TContractState>,
            admin: ContractAddress,
            permission: AdminPermission,
        ) -> bool {
            if admin == self.owner.read() {
                return true;
            }

            let permission_felt: felt252 = permission.into();
            self.admin_permissions.entry((permission_felt, admin)).read()
        }

        /// # get_admin_permissions
        ///
        /// Retrieves all permissions currently granted to a specific admin.
        /// For the owner, returns all available permissions without checking storage.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        /// - `admin`: The contract address of the admin whose permissions to retrieve.
        ///
        /// ## Returns
        ///
        /// An array of `AdminPermission` values representing all permissions granted to the admin.
        ///
        /// ## Implementation Details
        ///
        /// - Owner receives all permissions automatically
        /// - For non-owners, iterates through all possible permissions and checks each one
        /// - Uses the `has_admin_permission` method for consistent permission checking
        fn get_admin_permissions(
            self: @ComponentState<TContractState>, admin: ContractAddress,
        ) -> Array<AdminPermission> {
            let mut permissions: Array<AdminPermission> = array![];

            if admin == self.owner.read() {
                return AdminPermissionTrait::get_all_permissions();
            }

            let all_permissions = AdminPermissionTrait::get_all_permissions();
            let mut i = 0;
            while i != all_permissions.len() {
                let permission = *all_permissions.at(i);
                if self.has_admin_permission(admin, permission) {
                    permissions.append(permission);
                }
                i += 1;
            }

            permissions
        }

        /// # grant_admin_permission
        ///
        /// Grants a specific permission to an admin. This is a privileged action that requires
        /// the caller to have GRANT_PERMISSIONS permission or be the owner.
        ///
        /// ## Parameters
        ///
        /// - `ref self: ComponentState<TContractState>`: The current state of the component.
        /// - `admin`: The contract address of the admin to grant permission to.
        /// - `permission`: The specific permission to grant.
        ///
        /// ## Authorization
        ///
        /// - Caller must be the owner OR have GRANT_PERMISSIONS permission
        /// - Fails with 'Not authorized to grant' if authorization check fails
        ///
        /// ## Events
        ///
        /// Emits `AdminPermissionGranted` event if permission was not already granted.
        ///
        /// ## Implementation Details
        ///
        /// - Only grants permission if not already present (idempotent)
        /// - Converts permission to felt252 for efficient storage
        /// - Records the granter for audit purposes
        fn grant_admin_permission(
            ref self: ComponentState<TContractState>,
            admin: ContractAddress,
            permission: AdminPermission,
        ) {
            let caller = get_caller_address();

            assert(
                caller == self.owner.read()
                    || self.has_admin_permission(caller, AdminPermission::GRANT_PERMISSIONS),
                'Not authorized to grant',
            );

            let permission_felt: felt252 = permission.into();

            if !self.admin_permissions.entry((permission_felt, admin)).read() {
                self.admin_permissions.entry((permission_felt, admin)).write(true);
                self
                    .emit(
                        Event::AdminPermissionGranted(
                            AdminPermissionGranted {
                                permission: permission_felt, admin, granted_by: caller,
                            },
                        ),
                    );
            }
        }

        /// # revoke_admin_permission
        ///
        /// Revokes a specific permission from an admin. This is a privileged action that requires
        /// the caller to have REVOKE_PERMISSIONS permission or be the owner. Owner permissions
        /// cannot be revoked.
        ///
        /// ## Parameters
        ///
        /// - `ref self: ComponentState<TContractState>`: The current state of the component.
        /// - `admin`: The contract address of the admin to revoke permission from.
        /// - `permission`: The specific permission to revoke.
        ///
        /// ## Authorization
        ///
        /// - Caller must be the owner OR have REVOKE_PERMISSIONS permission
        /// - Cannot revoke permissions from the owner
        /// - Fails with 'Not authorized to revoke' if authorization check fails
        /// - Fails with 'Cannot revoke from owner' if attempting to revoke from owner
        ///
        /// ## Events
        ///
        /// Emits `AdminPermissionRevoked` event if permission was previously granted.
        ///
        /// ## Implementation Details
        ///
        /// - Only revokes permission if currently present (idempotent)
        /// - Converts permission to felt252 for efficient storage
        /// - Records the revoker for audit purposes
        fn revoke_admin_permission(
            ref self: ComponentState<TContractState>,
            admin: ContractAddress,
            permission: AdminPermission,
        ) {
            let caller = get_caller_address();

            assert(
                caller == self.owner.read()
                    || self.has_admin_permission(caller, AdminPermission::REVOKE_PERMISSIONS),
                'Not authorized to revoke',
            );

            assert(admin != self.owner.read(), 'Cannot revoke from owner');

            let permission_felt: felt252 = permission.into();

            if self.admin_permissions.entry((permission_felt, admin)).read() {
                self.admin_permissions.entry((permission_felt, admin)).write(false);
                self
                    .emit(
                        Event::AdminPermissionRevoked(
                            AdminPermissionRevoked {
                                permission: permission_felt, admin, revoked_by: caller,
                            },
                        ),
                    );
            }
        }

        /// # grant_all_admin_permissions
        ///
        /// Grants all available permissions to an admin at once. This is a privileged action
        /// that requires the caller to have GRANT_PERMISSIONS permission or be the owner.
        ///
        /// ## Parameters
        ///
        /// - `ref self: ComponentState<TContractState>`: The current state of the component.
        /// - `admin`: The contract address of the admin to grant all permissions to.
        ///
        /// ## Authorization
        ///
        /// - Caller must be the owner OR have GRANT_PERMISSIONS permission
        /// - Fails with 'Not authorized to grant' if authorization check fails
        ///
        /// ## Events
        ///
        /// Emits `AllAdminPermissionsGranted` event after granting all permissions.
        ///
        /// ## Implementation Details
        ///
        /// - Iterates through all available permissions and grants each one
        /// - Overwrites existing permissions (idempotent operation)
        /// - More efficient than calling grant_admin_permission multiple times
        /// - Records the granter for audit purposes
        fn grant_all_admin_permissions(
            ref self: ComponentState<TContractState>, admin: ContractAddress,
        ) {
            let caller = get_caller_address();

            assert(
                caller == self.owner.read()
                    || self.has_admin_permission(caller, AdminPermission::GRANT_PERMISSIONS),
                'Not authorized to grant',
            );

            let all_permissions = AdminPermissionTrait::get_all_permissions();
            let mut i = 0;
            while i != all_permissions.len() {
                let permission = *all_permissions.at(i);
                let permission_felt: felt252 = permission.into();
                self.admin_permissions.entry((permission_felt, admin)).write(true);
                i += 1;
            }

            self
                .emit(
                    Event::AllAdminPermissionsGranted(
                        AllAdminPermissionsGranted { admin, granted_by: caller },
                    ),
                );
        }

        /// # revoke_all_admin_permissions
        ///
        /// Revokes all permissions from an admin at once. This is a privileged action
        /// that requires the caller to have REVOKE_PERMISSIONS permission or be the owner.
        /// Owner permissions cannot be revoked.
        ///
        /// ## Parameters
        ///
        /// - `ref self: ComponentState<TContractState>`: The current state of the component.
        /// - `admin`: The contract address of the admin to revoke all permissions from.
        ///
        /// ## Authorization
        ///
        /// - Caller must be the owner OR have REVOKE_PERMISSIONS permission
        /// - Cannot revoke permissions from the owner
        /// - Fails with 'Not authorized to revoke' if authorization check fails
        /// - Fails with 'Cannot revoke from owner' if attempting to revoke from owner
        ///
        /// ## Events
        ///
        /// Emits `AllAdminPermissionsRevoked` event after revoking all permissions.
        ///
        /// ## Implementation Details
        ///
        /// - Iterates through all available permissions and revokes each one
        /// - Sets all permissions to false (idempotent operation)
        /// - More efficient than calling revoke_admin_permission multiple times
        /// - Records the revoker for audit purposes
        fn revoke_all_admin_permissions(
            ref self: ComponentState<TContractState>, admin: ContractAddress,
        ) {
            let caller = get_caller_address();

            assert(
                caller == self.owner.read()
                    || self.has_admin_permission(caller, AdminPermission::REVOKE_PERMISSIONS),
                'Not authorized to revoke',
            );

            assert(admin != self.owner.read(), 'Cannot revoke from owner');

            let all_permissions = AdminPermissionTrait::get_all_permissions();
            let mut i = 0;
            while i != all_permissions.len() {
                let permission = *all_permissions.at(i);
                let permission_felt: felt252 = permission.into();
                self.admin_permissions.entry((permission_felt, admin)).write(false);
                i += 1;
            }

            self
                .emit(
                    Event::AllAdminPermissionsRevoked(
                        AllAdminPermissionsRevoked { admin, revoked_by: caller },
                    ),
                );
        }

        /// # get_owner
        ///
        /// Retrieves the owner address of the contract. The owner has all permissions by default
        /// and their permissions cannot be revoked.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        ///
        /// ## Returns
        ///
        /// The `ContractAddress` of the contract owner.
        ///
        /// ## Implementation Details
        ///
        /// - Simple storage read operation
        /// - Owner is set during component initialization
        /// - Owner address is immutable after initialization
        fn get_owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.owner.read()
        }

        /// # is_owner
        ///
        /// Checks if a given address is the contract owner.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        /// - `address`: The contract address to check for ownership.
        ///
        /// ## Returns
        ///
        /// A boolean indicating whether the address is the contract owner.
        ///
        /// ## Implementation Details
        ///
        /// - Performs simple address comparison
        /// - Used internally for authorization checks
        /// - More readable than direct owner comparison in calling code
        fn is_owner(self: @ComponentState<TContractState>, address: ContractAddress) -> bool {
            address == self.owner.read()
        }

        /// # permissions_to_mask
        ///
        /// Converts an array of permissions to a bitmask representation for efficient storage and
        /// operations.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        /// - `permissions`: An array of `AdminPermission` values to convert.
        ///
        /// ## Returns
        ///
        /// A `u16` bitmask representing the permissions.
        ///
        /// ## Implementation Details
        ///
        /// - Uses bitwise OR operations to combine individual permission masks
        /// - Each permission has a unique bit position in the mask
        /// - Allows compact representation of multiple permissions
        /// - Useful for batch operations and efficient storage
        fn permissions_to_mask(
            self: @ComponentState<TContractState>, permissions: Array<AdminPermission>,
        ) -> u16 {
            let mut mask: u16 = 0;
            let mut i = 0;
            while i != permissions.len() {
                let permission = *permissions.at(i);
                mask = mask | permission.to_mask();
                i += 1;
            }
            mask
        }

        /// # permissions_from_mask
        ///
        /// Converts a bitmask representation back to an array of permissions.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        /// - `mask`: A `u16` bitmask representing permissions.
        ///
        /// ## Returns
        ///
        /// An array of `AdminPermission` values represented by the bitmask.
        ///
        /// ## Implementation Details
        ///
        /// - Iterates through all possible permissions
        /// - Checks each permission's bit in the mask using bitwise AND
        /// - Reconstructs the original permission set from the compact representation
        /// - Useful for converting stored masks back to usable permission arrays
        fn permissions_from_mask(
            self: @ComponentState<TContractState>, mask: u16,
        ) -> Array<AdminPermission> {
            let mut permissions_array: Array<AdminPermission> = array![];
            let all_permissions = AdminPermissionTrait::get_all_permissions();

            let mut i = 0;
            while i != all_permissions.len() {
                let permission = *all_permissions.at(i);
                if permission.has_permission_from_mask(mask) {
                    permissions_array.append(permission);
                }
                i += 1;
            }

            permissions_array
        }

        /// # is_valid_admin_mask
        ///
        /// Validates whether a bitmask represents a valid combination of admin permissions.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        /// - `mask`: A `u16` bitmask to validate.
        ///
        /// ## Returns
        ///
        /// A boolean indicating whether the bitmask is valid.
        ///
        /// ## Implementation Details
        ///
        /// - Checks if at least one valid permission bit is set in the mask
        /// - Iterates through all known permissions to verify validity
        /// - Returns false for empty masks (no permissions set)
        /// - Useful for input validation and preventing invalid permission states
        fn is_valid_admin_mask(self: @ComponentState<TContractState>, mask: u16) -> bool {
            let all_permissions = AdminPermissionTrait::get_all_permissions();
            let mut valid = false;

            let mut i = 0;
            while i != all_permissions.len() {
                let permission = *all_permissions.at(i);
                if permission.has_permission_from_mask(mask) {
                    valid = true;
                    break;
                }
                i += 1;
            }

            valid
        }
    }

    /// # AdminPermissionManagerInternalTrait
    ///
    /// Internal implementation providing utility functions for the admin permission manager
    /// component.
    /// These functions are intended for use by the contract implementation and other components.
    #[generate_trait]
    pub impl AdminPermissionManagerInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of AdminPermissionManagerInternalTrait<TContractState> {
        /// # initialize_admin_permissions
        ///
        /// Initializes the admin permission manager component by setting the contract owner.
        /// This function should be called during contract construction.
        ///
        /// ## Parameters
        ///
        /// - `ref self: ComponentState<TContractState>`: The current state of the component.
        /// - `owner`: The contract address to set as the owner.
        ///
        /// ## Implementation Details
        ///
        /// - Sets the owner address in storage
        /// - Owner automatically has all permissions
        /// - Should only be called once during contract initialization
        /// - Owner address cannot be changed after initialization
        fn initialize_admin_permissions(
            ref self: ComponentState<TContractState>, owner: ContractAddress,
        ) {
            self.owner.write(owner);
        }

        /// # require_admin_permission
        ///
        /// Utility function to enforce permission requirements in contract methods.
        /// Reverts the transaction if the caller doesn't have the required permission.
        ///
        /// ## Parameters
        ///
        /// - `self: @ComponentState<TContractState>`: A snapshot of the component's state.
        /// - `caller`: The contract address of the caller to check.
        /// - `required_permission`: The permission that the caller must have.
        ///
        /// ## Panics
        ///
        /// Reverts with 'Insufficient admin permissions' if the caller doesn't have the required
        /// permission.
        ///
        /// ## Implementation Details
        ///
        /// - Uses the `has_admin_permission` method for consistent permission checking
        /// - Provides a convenient way to add permission checks to contract methods
        /// - Owner automatically passes all permission checks
        fn require_admin_permission(
            self: @ComponentState<TContractState>,
            caller: ContractAddress,
            required_permission: AdminPermission,
        ) {
            assert(
                self.has_admin_permission(caller, required_permission),
                'Insufficient admin permissions',
            );
        }
    }
}
