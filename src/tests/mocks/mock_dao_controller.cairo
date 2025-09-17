use littlefinger::interfaces::dao_controller::IVote as IMockVote;
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockDaoController {
    use AdminPermissionManagerComponent::AdminPermissionManagerInternalTrait;
    use littlefinger::components::admin_permission_manager::AdminPermissionManagerComponent;
    use littlefinger::components::dao_controller::VotingComponent;
    use littlefinger::components::member_manager::MemberManagerComponent;
    use littlefinger::interfaces::imember_manager::{
        IMemberManagerDispatcher, IMemberManagerDispatcherTrait,
    };
    use littlefinger::structs::dao_controller::{
        Poll, PollCreated, PollReason, PollResolved, PollStatus, PollStopped, PollTrait,
        ThresholdChanged, Voted, VotingConfig, VotingConfigNode,
    };
    use littlefinger::structs::member_structs::{
        Member, MemberDetails, MemberRole, MemberRoleIntoU16, MemberStatus, MemberTrait,
    };
    use starknet::storage::{StoragePathEntry, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp};

    component!(path: VotingComponent, storage: dao_controller, event: DaoControllerEvent);
    component!(path: MemberManagerComponent, storage: member_manager, event: MemberManagerEvent);
    component!(
        path: AdminPermissionManagerComponent,
        storage: admin_permission_manager,
        event: AdminPermissionManagerEvent,
    );

    #[abi(embed_v0)]
    pub impl VotingImpl = VotingComponent::VotingImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl MemberManagerImpl =
        MemberManagerComponent::MemberManager<ContractState>;

    #[abi(embed_v0)]
    impl AdminPermissionManagerImpl =
        AdminPermissionManagerComponent::AdminPermissionManagerImpl<ContractState>;


    pub impl InternalImpl = VotingComponent::VoteInternalImpl<ContractState>;
    pub impl MemberInternalImpl = MemberManagerComponent::InternalImpl<ContractState>;

    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    pub struct Storage {
        #[substorage(v0)]
        pub dao_controller: VotingComponent::Storage,
        #[substorage(v0)]
        pub member_manager: MemberManagerComponent::Storage,
        #[substorage(v0)]
        pub admin_permission_manager: AdminPermissionManagerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        DaoControllerEvent: VotingComponent::Event,
        #[flat]
        MemberManagerEvent: MemberManagerComponent::Event,
        #[flat]
        AdminPermissionManagerEvent: AdminPermissionManagerComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        config: VotingConfig,
        threshold: u256,
        first_admin_fname: felt252,
        first_admin_lname: felt252,
        first_admin_alias: felt252,
        member1: ContractAddress,
        member2: ContractAddress,
        member3: ContractAddress,
        factory: ContractAddress,
        core_org: ContractAddress,
    ) {
        // Initialize admin permission manager first
        self.admin_permission_manager.initialize_admin_permissions(admin);

        self.dao_controller._initialize(admin, config, threshold);
        self
            .member_manager
            ._initialize(
                first_admin_fname, first_admin_lname, first_admin_alias, admin, factory, core_org,
            );

        // Add the test members to the system
        // Member 1 - Employee role
        let member1_node = self.member_manager.members.entry(2);
        let member1_details = MemberDetails { fname: 'Member', lname: 'One', alias: 'member1' };
        let member1_struct = Member {
            id: 2, address: member1, status: MemberStatus::ACTIVE, role: MemberRole::EMPLOYEE(5),
        };
        member1_node.details.write(member1_details);
        member1_node.member.write(member1_struct);
        member1_node.reg_time.write(starknet::get_block_timestamp());
        member1_node.total_received.write(0);
        member1_node.total_disbursements.write(0);

        // Member 2 - Employee role
        let member2_node = self.member_manager.members.entry(3);
        let member2_details = MemberDetails { fname: 'Member', lname: 'Two', alias: 'member2' };
        let member2_struct = Member {
            id: 3, address: member2, status: MemberStatus::ACTIVE, role: MemberRole::EMPLOYEE(5),
        };
        member2_node.details.write(member2_details);
        member2_node.member.write(member2_struct);
        member2_node.reg_time.write(starknet::get_block_timestamp());
        member2_node.total_received.write(0);
        member2_node.total_disbursements.write(0);

        // Member 3 - Employee role
        let member3_node = self.member_manager.members.entry(4);
        let member3_details = MemberDetails { fname: 'Member', lname: 'Three', alias: 'member3' };
        let member3_struct = Member {
            id: 4, address: member3, status: MemberStatus::ACTIVE, role: MemberRole::EMPLOYEE(5),
        };
        member3_node.details.write(member3_details);
        member3_node.member.write(member3_struct);
        member3_node.reg_time.write(starknet::get_block_timestamp());
        member3_node.total_received.write(0);
        member3_node.total_disbursements.write(0);

        // Update member count to reflect the added members
        self.member_manager.member_count.write(4);
    }
}
