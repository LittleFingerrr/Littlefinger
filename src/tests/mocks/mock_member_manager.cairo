#[starknet::contract]
pub mod MockMemberManager {
    use littlefinger::components::member_manager::MemberManagerComponent;
    use starknet::ContractAddress;
    use starknet::storage::MutableVecTrait;

    component!(path: MemberManagerComponent, storage: member_manager, event: MemberManagerEvent);

    #[abi(embed_v0)]
    pub impl MemberManagerImpl =
        MemberManagerComponent::MemberManager<ContractState>;

    pub impl InternalImpl = MemberManagerComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub member_manager: MemberManagerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MemberManagerEvent: MemberManagerComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        first_admin_fname: felt252,
        first_admin_lname: felt252,
        first_admin_alias: felt252,
        admin: ContractAddress,
        factory: ContractAddress,
        core_org: ContractAddress,
    ) {
        self
            .member_manager
            ._initialize(
                first_admin_fname, first_admin_lname, first_admin_alias, admin, factory, core_org,
            );

        // Initialize role values if needed - using modern storage syntax
        #[feature("starknet-storage-deprecation")]
        {
            self.member_manager.role_value.push(1);
            self.member_manager.role_value.push(2);
            self.member_manager.role_value.push(3);
        }
    }
}
