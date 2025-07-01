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
        ref self: ContractState, admin: ContractAddress, config: VotingConfig, threshold: u256,
    ) {
        self.dao_controller._initialize(admin, config, threshold);
    }
}
