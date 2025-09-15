use littlefinger::components::admin_permission_manager::AdminPermissionManagerComponent;
use littlefinger::interfaces::iadmin_permission_manager::{
    IAdminPermissionManagerDispatcher, IAdminPermissionManagerDispatcherTrait,
};
use littlefinger::structs::admin_permissions::{
    AdminPermission, AdminPermissionGranted, AdminPermissionRevoked, AdminPermissionTrait,
    AllAdminPermissionsGranted, AllAdminPermissionsRevoked,
};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::{ContractAddress, contract_address_const};

fn deploy_mock_admin_permission_manager() -> IAdminPermissionManagerDispatcher {
    let owner: ContractAddress = owner();
    let contract_class = declare("MockAdminPermissionManager").unwrap().contract_class();
    let mut calldata = array![owner.into()];
    let (contract_address, _) = contract_class.deploy(@calldata.into()).unwrap();
    IAdminPermissionManagerDispatcher { contract_address }
}

fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn admin1() -> ContractAddress {
    contract_address_const::<'admin1'>()
}

fn admin2() -> ContractAddress {
    contract_address_const::<'admin2'>()
}

fn unauthorized_user() -> ContractAddress {
    contract_address_const::<'unauthorized'>()
}

#[test]
fn test_owner_initialization() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();

    // Owner should be set correctly
    assert(permission_manager.get_owner() == owner_addr, 'Owner not set correctly');
    assert(permission_manager.is_owner(owner_addr), 'Owner check failed');

    // Owner should have all permissions by default
    assert(
        permission_manager.has_admin_permission(owner_addr, AdminPermission::ADD_MEMBER),
        'Owner missing ADD_MEMBER',
    );
    assert(
        permission_manager.has_admin_permission(owner_addr, AdminPermission::REMOVE_MEMBER),
        'Owner missing REMOVE_MEMBER',
    );
    assert(
        permission_manager.has_admin_permission(owner_addr, AdminPermission::GRANT_PERMISSIONS),
        'Owner missing GRANT_PERMS',
    );

    // Get all permissions for owner
    let owner_permissions = permission_manager.get_admin_permissions(owner_addr);
    let all_permissions = AdminPermissionTrait::get_all_permissions();
    assert(owner_permissions.len() == all_permissions.len(), 'Owner missing permissions');
}

#[test]
fn test_grant_single_permission() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Initially admin1 should not have ADD_MEMBER permission
    assert(
        !permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'Admin1 no initial perm',
    );

    // Grant ADD_MEMBER permission to admin1
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);

    // Now admin1 should have ADD_MEMBER permission
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'Admin1 has ADD_MEMBER',
    );

    // Admin1 should not have other permissions
    assert(
        !permission_manager.has_admin_permission(admin1_addr, AdminPermission::REMOVE_MEMBER),
        'Admin1 no REMOVE_MEMBER',
    );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_revoke_single_permission() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant permission first
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'Permission should be granted',
    );

    // Revoke the permission
    permission_manager.revoke_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);

    // Permission should be revoked
    assert(
        !permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'Permission should be revoked',
    );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_grant_all_permissions() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant all permissions to admin1
    permission_manager.grant_all_admin_permissions(admin1_addr);

    // Admin1 should now have all permissions
    let admin1_permissions = permission_manager.get_admin_permissions(admin1_addr);
    let all_permissions = AdminPermissionTrait::get_all_permissions();
    assert(admin1_permissions.len() == all_permissions.len(), 'Admin1 has all perms');

    // Check specific permissions
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'Admin1 missing ADD_MEMBER',
    );
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::VAULT_FUNCTIONS),
        'Admin1 missing VAULT_FUNCS',
    );
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::GRANT_PERMISSIONS),
        'Admin1 missing GRANT_PERMS',
    );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_revoke_all_permissions() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant all permissions first
    permission_manager.grant_all_admin_permissions(admin1_addr);

    // Verify admin1 has permissions
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'Admin1 should have permissions',
    );

    // Revoke all permissions
    permission_manager.revoke_all_admin_permissions(admin1_addr);

    // Admin1 should have no permissions
    let admin1_permissions = permission_manager.get_admin_permissions(admin1_addr);
    assert(admin1_permissions.len() == 0, 'Admin1 has no perms');

    // Check specific permissions are revoked
    assert(
        !permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'ADD_MEMBER should be revoked',
    );
    assert(
        !permission_manager.has_admin_permission(admin1_addr, AdminPermission::GRANT_PERMISSIONS),
        'GRANT_PERMS revoked',
    );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
#[should_panic(expected: 'Not authorized to grant')]
fn test_unauthorized_grant_permission() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let unauthorized_addr = unauthorized_user();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, unauthorized_addr);

    // This should fail as unauthorized user cannot grant permissions
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
#[should_panic(expected: 'Not authorized to revoke')]
fn test_unauthorized_revoke_permission() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let unauthorized_addr = unauthorized_user();
    let admin1_addr = admin1();

    // First grant permission as owner
    start_cheat_caller_address(permission_manager.contract_address, owner_addr);
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);
    stop_cheat_caller_address(permission_manager.contract_address);

    // Try to revoke as unauthorized user - should fail
    start_cheat_caller_address(permission_manager.contract_address, unauthorized_addr);
    permission_manager.revoke_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
#[should_panic(expected: 'Cannot revoke from owner')]
fn test_cannot_revoke_from_owner() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // This should fail as owner permissions cannot be revoked
    permission_manager.revoke_admin_permission(owner_addr, AdminPermission::ADD_MEMBER);

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_delegated_permission_management() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();
    let admin2_addr = admin2();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant GRANT_PERMISSIONS to admin1
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::GRANT_PERMISSIONS);

    stop_cheat_caller_address(permission_manager.contract_address);

    // Now admin1 should be able to grant permissions to admin2
    start_cheat_caller_address(permission_manager.contract_address, admin1_addr);

    permission_manager.grant_admin_permission(admin2_addr, AdminPermission::ADD_MEMBER);

    // Verify admin2 has the permission
    assert(
        permission_manager.has_admin_permission(admin2_addr, AdminPermission::ADD_MEMBER),
        'Admin2 has ADD_MEMBER',
    );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_permission_bitmask_operations() {
    let permission_manager = deploy_mock_admin_permission_manager();

    // Test permissions to mask conversion
    let permissions = array![
        AdminPermission::ADD_MEMBER,
        AdminPermission::REMOVE_MEMBER,
        AdminPermission::GRANT_PERMISSIONS,
    ];

    let mask = permission_manager.permissions_to_mask(permissions);
    assert(mask > 0, 'Mask should be non-zero');

    // Test mask to permissions conversion
    let converted_permissions = permission_manager.permissions_from_mask(mask);
    assert(converted_permissions.len() == 3, 'Should have 3 permissions');

    // Test mask validation
    assert(permission_manager.is_valid_admin_mask(mask), 'Mask should be valid');
    assert(!permission_manager.is_valid_admin_mask(0), 'Zero mask should be invalid');
}

#[test]
fn test_event_emission_on_grant() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    let mut spy = spy_events();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant permission and check event
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);

    spy
        .assert_emitted(
            @array![
                (
                    permission_manager.contract_address,
                    AdminPermissionManagerComponent::Event::AdminPermissionGranted(
                        AdminPermissionGranted {
                            permission: AdminPermission::ADD_MEMBER.into(),
                            admin: admin1_addr,
                            granted_by: owner_addr,
                        },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_event_emission_on_revoke() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant permission first
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);

    let mut spy = spy_events();

    // Revoke permission and check event
    permission_manager.revoke_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);

    spy
        .assert_emitted(
            @array![
                (
                    permission_manager.contract_address,
                    AdminPermissionManagerComponent::Event::AdminPermissionRevoked(
                        AdminPermissionRevoked {
                            permission: AdminPermission::ADD_MEMBER.into(),
                            admin: admin1_addr,
                            revoked_by: owner_addr,
                        },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_event_emission_on_grant_all() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    let mut spy = spy_events();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant all permissions and check event
    permission_manager.grant_all_admin_permissions(admin1_addr);

    spy
        .assert_emitted(
            @array![
                (
                    permission_manager.contract_address,
                    AdminPermissionManagerComponent::Event::AllAdminPermissionsGranted(
                        AllAdminPermissionsGranted { admin: admin1_addr, granted_by: owner_addr },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_event_emission_on_revoke_all() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant all permissions first
    permission_manager.grant_all_admin_permissions(admin1_addr);

    let mut spy = spy_events();

    // Revoke all permissions and check event
    permission_manager.revoke_all_admin_permissions(admin1_addr);

    spy
        .assert_emitted(
            @array![
                (
                    permission_manager.contract_address,
                    AdminPermissionManagerComponent::Event::AllAdminPermissionsRevoked(
                        AllAdminPermissionsRevoked { admin: admin1_addr, revoked_by: owner_addr },
                    ),
                ),
            ],
        );

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_get_admin_permissions_empty() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let admin1_addr = admin1();

    // Admin1 should have no permissions initially
    let permissions = permission_manager.get_admin_permissions(admin1_addr);
    assert(permissions.len() == 0, 'Admin1 has no perms');
}

#[test]
fn test_get_admin_permissions_partial() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant specific permissions
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::SET_BASE_SALARIES);

    let admin1_permissions = permission_manager.get_admin_permissions(admin1_addr);
    assert(admin1_permissions.len() == 2, 'Admin1 has 2 perms');

    stop_cheat_caller_address(permission_manager.contract_address);
}

#[test]
fn test_multiple_permission_operations() {
    let permission_manager = deploy_mock_admin_permission_manager();
    let owner_addr = owner();
    let admin1_addr = admin1();

    start_cheat_caller_address(permission_manager.contract_address, owner_addr);

    // Grant multiple permissions individually
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER);
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::REMOVE_MEMBER);
    permission_manager.grant_admin_permission(admin1_addr, AdminPermission::SET_BASE_SALARIES);

    // Verify all are granted
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'ADD_MEMBER should be granted',
    );
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::REMOVE_MEMBER),
        'REMOVE_MEMBER should be granted',
    );
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::SET_BASE_SALARIES),
        'SET_BASE_SALARIES granted',
    );

    // Revoke one permission
    permission_manager.revoke_admin_permission(admin1_addr, AdminPermission::REMOVE_MEMBER);

    // Verify selective revocation
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::ADD_MEMBER),
        'ADD_MEMBER still granted',
    );
    assert(
        !permission_manager.has_admin_permission(admin1_addr, AdminPermission::REMOVE_MEMBER),
        'REMOVE_MEMBER should be revoked',
    );
    assert(
        permission_manager.has_admin_permission(admin1_addr, AdminPermission::SET_BASE_SALARIES),
        'SET_BASE_SALARIES granted',
    );

    stop_cheat_caller_address(permission_manager.contract_address);
}
