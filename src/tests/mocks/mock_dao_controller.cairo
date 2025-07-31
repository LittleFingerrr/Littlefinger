use littlefinger::interfaces::dao_controller::IVote as IMockVote;
use starknet::ContractAddress;

#[starknet::contract]
pub mod MockDaoController {
    use littlefinger::components::dao_controller::VotingComponent;
    use littlefinger::components::member_manager::MemberManagerComponent;
    use littlefinger::structs::dao_controller::{
        Poll, PollCreated, PollReason, PollResolved, PollStatus, PollStopped, PollTrait,
        ThresholdChanged, Voted, VotingConfig, VotingConfigNode,
    };
    use littlefinger::structs::member_structs::{MemberRoleIntoU16, MemberTrait};
    use starknet::ContractAddress;

    component!(path: VotingComponent, storage: dao_controller, event: DaoControllerEvent);
    component!(path: MemberManagerComponent, storage: member_manager, event: MemberManagerEvent);

    #[abi(embed_v0)]
    pub impl VotingImpl = VotingComponent::VotingImpl<ContractState>;

    #[abi(embed_v0)]
    pub impl MemberManagerImpl =
        MemberManagerComponent::MemberManager<ContractState>;


    pub impl InternalImpl = VotingComponent::VoteInternalImpl<ContractState>;
    pub impl MemberInternalImpl = MemberManagerComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub dao_controller: VotingComponent::Storage,
        #[substorage(v0)]
        pub member_manager: MemberManagerComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        DaoControllerEvent: VotingComponent::Event,
        #[flat]
        MemberManagerEvent: MemberManagerComponent::Event,
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
        self.dao_controller._initialize(admin, config, threshold);
        self
            .member_manager
            ._initialize(
                first_admin_fname, first_admin_lname, first_admin_alias, admin, factory, core_org,
            );
        self
            .member_manager
            .add_member('Member1'.into(), 'LastName1'.into(), 'Alias1'.into(), 5, member1);
        self
            .member_manager
            .add_member('Member2'.into(), 'LastName2'.into(), 'Alias2'.into(), 0, member2);
        self
            .member_manager
            .add_member('Member3'.into(), 'LastName3'.into(), 'Alias3'.into(), 5, member3);
    }
}
