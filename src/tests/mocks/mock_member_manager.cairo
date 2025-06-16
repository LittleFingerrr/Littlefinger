use littlefinger::interfaces::imember_manager::IMemberManager as IMockMemberManager;
use littlefinger::structs::member_structs::{
    InviteStatus, Member, MemberConfig, MemberConfigNode, MemberDetails, MemberEnum, MemberEvent,
    MemberInvite, MemberInvited, MemberNode, MemberResponse, MemberRole, MemberStatus, MemberTrait,
};
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockMemberManager {
    use littlefinger::components::member_manager::MemberManagerComponent;
    use littlefinger::structs::member_structs::{MemberConfig, MemberResponse, MemberRole};
    use starknet::ContractAddress;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };

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
    ) {
        self
            .member_manager
            ._initialize(first_admin_fname, first_admin_lname, first_admin_alias, admin);

        // Initialize role values if needed
        self.member_manager.role_value.append().write(1);
        self.member_manager.role_value.append().write(2);
        self.member_manager.role_value.append().write(3);
    }
}
