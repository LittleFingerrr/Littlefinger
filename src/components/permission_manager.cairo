/// ## A Starknet component for managing granular permissions.
///
/// This component assigns specific permissions to accounts using a bitmask.
#[starknet::component]
pub mod PermissionManagerComponent {
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_caller_address};
    use core::array::{ArrayTrait, array, SpanTrait};
    use core::option::OptionTrait;
    use core::integer::u256;

    /// Permissions in the organization, represented as a bitmask.
    #[derive(Copy, Drop, Serde, PartialEq)]
    pub enum Permission {
        ADD_MEMBER = 1,
        REMOVE_MEMBER = 2,
        SEND_INVITES = 4,
        SET_SALARIES = 8,
        SET_DISBURSEMENT = 16,
        ADD_VAULT_TOKENS = 32,
        VAULT_FUNCTIONS = 64,
        GRANT_ADMIN = 128,
        REVOKE_ADMIN = 256,
    }

    /// Defines the storage layout for the `PermissionManagerComponent`.
    #[storage]
    pub struct Storage {
        /// Maps an address to its bitmask of permissions.
        pub permissions: Map<ContractAddress, u256>,
    }

    /// Events emitted by the `PermissionManagerComponent`.
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        PermissionGranted: PermissionGranted,
        PermissionRevoked: PermissionRevoked,
        AllPermissionsGranted: AllPermissionsGranted,
        AllPermissionsRevoked: AllPermissionsRevoked,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionGranted {
        #[key]
        pub account: ContractAddress,
        pub permission: Permission,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PermissionRevoked {
        #[key]
        pub account: ContractAddress,
        pub permission: Permission,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AllPermissionsGranted {
        #[key]
        pub account: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AllPermissionsRevoked {
        #[key]
        pub account: ContractAddress,
    }

    /// # PermissionManagerComponent
    ///
    /// Public-facing API for permission management.
    #[embeddable_as(PermissionManager)]
    pub impl Permission<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of crate::interfaces::ipermission::IPermission<ComponentState<TContractState>> {
        /// Grants a specific permission to an account.
        fn grant_permission(ref self: ComponentState<TContractState>, account: ContractAddress, permission: Permission) {
            let caller = get_caller_address();
            let has_permission = self.internal._has_permission(caller, Permission::GRANT_ADMIN);
            assert(has_permission, 'Perm: caller not admin');

            let mut current_permissions = self.permissions.read(account);
            current_permissions = current_permissions | (permission.into());
            self.permissions.write(account, current_permissions);
            self.emit(Event::PermissionGranted(PermissionGranted { account, permission }));
        }

        /// Revokes a specific permission from an account.
        fn revoke_permission(ref self: ComponentState<TContractState>, account: ContractAddress, permission: Permission) {
            let caller = get_caller_address();
            let has_permission = self.internal._has_permission(caller, Permission::REVOKE_ADMIN);
            assert(has_permission, 'Perm: caller not admin');

            let mut current_permissions = self.permissions.read(account);
            current_permissions = current_permissions & (!(permission.into()));
            self.permissions.write(account, current_permissions);
            self.emit(Event::PermissionRevoked(PermissionRevoked { account, permission }));
        }

        /// Grants all permissions to an account.
        fn grant_all_permissions(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let caller = get_caller_address();
            let has_permission = self.internal._has_permission(caller, Permission::GRANT_ADMIN);
            assert(has_permission, 'Perm: caller not admin');

            // Set all bits to 1 (full permissions)
            let all_perms = 511; // Sum of all enum values
            self.permissions.write(account, all_perms);
            self.emit(Event::AllPermissionsGranted(AllPermissionsGranted { account }));
        }

        /// Revokes all permissions from an account.
        fn revoke_all_permissions(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let caller = get_caller_address();
            let has_permission = self.internal._has_permission(caller, Permission::REVOKE_ADMIN);
            assert(has_permission, 'Perm: caller not admin');

            self.permissions.write(account, 0);
            self.emit(Event::AllPermissionsRevoked(AllPermissionsRevoked { account }));
        }

        /// Checks if an account has a specific permission.
        fn has_permission(self: @ComponentState<TContractState>, account: ContractAddress, permission: Permission) -> bool {
            self.internal._has_permission(account, permission)
        }
    }

    /// # InternalImpl
    #[generate_trait]
    pub impl InternalImpl<TContractState, +HasComponent<TContractState>, > of PermissionInternalTrait<TContractState> {
        /// Initializes the permission manager with an owner who has all permissions.
        fn _init(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            let all_perms = 511; // Sum of all enum values
            self.permissions.write(owner, all_perms);
        }

        /// Internal function to check if an account has a specific permission.
        fn _has_permission(self: @ComponentState<TContractState>, account: ContractAddress, permission: Permission) -> bool {
            let account_perms = self.permissions.read(account);
            (account_perms & (permission.into())) != 0
        }
    }
}