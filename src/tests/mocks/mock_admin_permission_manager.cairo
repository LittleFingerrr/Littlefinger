#[starknet::contract]
pub mod MockAdminPermissionManager {
    use littlefinger::components::admin_permission_manager::AdminPermissionManagerComponent;
    use starknet::ContractAddress;

    component!(
        path: AdminPermissionManagerComponent,
        storage: admin_permissions,
        event: AdminPermissionManagerEvent,
    );

    #[abi(embed_v0)]
    pub impl AdminPermissionManagerImpl =
        AdminPermissionManagerComponent::AdminPermissionManagerImpl<ContractState>;

    pub impl AdminPermissionManagerInternalImpl =
        AdminPermissionManagerComponent::AdminPermissionManagerInternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub admin_permissions: AdminPermissionManagerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        AdminPermissionManagerEvent: AdminPermissionManagerComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.admin_permissions.initialize_admin_permissions(owner);
    }
}
