use starknet::ContractAddress;

/// Admin permission enums for different administrative actions
#[derive(Drop, Copy, Serde, PartialEq)]
pub enum AdminPermission {
    ADD_MEMBER,
    REMOVE_MEMBER,
    SEND_MEMBER_INVITES,
    SET_BASE_SALARIES,
    CHANGE_BASE_SALARIES,
    SET_DISBURSEMENT_SCHEDULES,
    ADD_VAULT_TOKENS,
    VAULT_FUNCTIONS, // All vault functions except deposit
    GRANT_ADMIN_STATUS,
    REVOKE_ADMIN_STATUS,
    GRANT_PERMISSIONS,
    REVOKE_PERMISSIONS,
}

/// Trait for converting AdminPermission to felt252 for storage
pub impl AdminPermissionIntoFelt252 of Into<AdminPermission, felt252> {
    fn into(self: AdminPermission) -> felt252 {
        match self {
            AdminPermission::ADD_MEMBER => 'ADD_MEMBER',
            AdminPermission::REMOVE_MEMBER => 'REMOVE_MEMBER',
            AdminPermission::SEND_MEMBER_INVITES => 'SEND_INVITES',
            AdminPermission::SET_BASE_SALARIES => 'SET_SALARIES',
            AdminPermission::CHANGE_BASE_SALARIES => 'CHANGE_SALARIES',
            AdminPermission::SET_DISBURSEMENT_SCHEDULES => 'SET_SCHEDULES',
            AdminPermission::ADD_VAULT_TOKENS => 'ADD_VAULT_TOKENS',
            AdminPermission::VAULT_FUNCTIONS => 'VAULT_FUNCTIONS',
            AdminPermission::GRANT_ADMIN_STATUS => 'GRANT_ADMIN_STATUS',
            AdminPermission::REVOKE_ADMIN_STATUS => 'REVOKE_ADMIN_STATUS',
            AdminPermission::GRANT_PERMISSIONS => 'GRANT_PERMISSIONS',
            AdminPermission::REVOKE_PERMISSIONS => 'REVOKE_PERMISSIONS',
        }
    }
}

/// Trait for converting felt252 back to AdminPermission
pub impl Felt252IntoAdminPermission of Into<felt252, AdminPermission> {
    fn into(self: felt252) -> AdminPermission {
        if self == 'ADD_MEMBER' {
            AdminPermission::ADD_MEMBER
        } else if self == 'REMOVE_MEMBER' {
            AdminPermission::REMOVE_MEMBER
        } else if self == 'SEND_INVITES' {
            AdminPermission::SEND_MEMBER_INVITES
        } else if self == 'SET_SALARIES' {
            AdminPermission::SET_BASE_SALARIES
        } else if self == 'CHANGE_SALARIES' {
            AdminPermission::CHANGE_BASE_SALARIES
        } else if self == 'SET_SCHEDULES' {
            AdminPermission::SET_DISBURSEMENT_SCHEDULES
        } else if self == 'ADD_VAULT_TOKENS' {
            AdminPermission::ADD_VAULT_TOKENS
        } else if self == 'VAULT_FUNCTIONS' {
            AdminPermission::VAULT_FUNCTIONS
        } else if self == 'GRANT_ADMIN_STATUS' {
            AdminPermission::GRANT_ADMIN_STATUS
        } else if self == 'REVOKE_ADMIN_STATUS' {
            AdminPermission::REVOKE_ADMIN_STATUS
        } else if self == 'GRANT_PERMISSIONS' {
            AdminPermission::GRANT_PERMISSIONS
        } else if self == 'REVOKE_PERMISSIONS' {
            AdminPermission::REVOKE_PERMISSIONS
        } else {
            AdminPermission::ADD_MEMBER // Default fallback
        }
    }
}

/// Trait for AdminPermission utilities
pub trait AdminPermissionTrait {
    fn to_mask(self: AdminPermission) -> u16;
    fn has_permission_from_mask(self: AdminPermission, mask: u16) -> bool;
    fn get_all_permissions() -> Array<AdminPermission>;
}

pub impl AdminPermissionImpl of AdminPermissionTrait {
    fn to_mask(self: AdminPermission) -> u16 {
        match self {
            AdminPermission::ADD_MEMBER => 1,
            AdminPermission::REMOVE_MEMBER => 2,
            AdminPermission::SEND_MEMBER_INVITES => 4,
            AdminPermission::SET_BASE_SALARIES => 8,
            AdminPermission::CHANGE_BASE_SALARIES => 16,
            AdminPermission::SET_DISBURSEMENT_SCHEDULES => 32,
            AdminPermission::ADD_VAULT_TOKENS => 64,
            AdminPermission::VAULT_FUNCTIONS => 128,
            AdminPermission::GRANT_ADMIN_STATUS => 256,
            AdminPermission::REVOKE_ADMIN_STATUS => 512,
            AdminPermission::GRANT_PERMISSIONS => 1024,
            AdminPermission::REVOKE_PERMISSIONS => 2048,
        }
    }

    fn has_permission_from_mask(self: AdminPermission, mask: u16) -> bool {
        (mask & self.to_mask()) != 0
    }

    fn get_all_permissions() -> Array<AdminPermission> {
        array![
            AdminPermission::ADD_MEMBER,
            AdminPermission::REMOVE_MEMBER,
            AdminPermission::SEND_MEMBER_INVITES,
            AdminPermission::SET_BASE_SALARIES,
            AdminPermission::CHANGE_BASE_SALARIES,
            AdminPermission::SET_DISBURSEMENT_SCHEDULES,
            AdminPermission::ADD_VAULT_TOKENS,
            AdminPermission::VAULT_FUNCTIONS,
            AdminPermission::GRANT_ADMIN_STATUS,
            AdminPermission::REVOKE_ADMIN_STATUS,
            AdminPermission::GRANT_PERMISSIONS,
            AdminPermission::REVOKE_PERMISSIONS,
        ]
    }
}

/// Events for permission management
#[derive(Drop, starknet::Event)]
pub struct AdminPermissionGranted {
    pub permission: felt252,
    pub admin: ContractAddress,
    pub granted_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AdminPermissionRevoked {
    pub permission: felt252,
    pub admin: ContractAddress,
    pub revoked_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AllAdminPermissionsGranted {
    pub admin: ContractAddress,
    pub granted_by: ContractAddress,
}

#[derive(Drop, starknet::Event)]
pub struct AllAdminPermissionsRevoked {
    pub admin: ContractAddress,
    pub revoked_by: ContractAddress,
}
