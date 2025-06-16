#[starknet::component]
pub mod VotingComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_caller_address};
    // use crate::interfaces::icore::IConfig;
    use crate::interfaces::voting::IVote;
    use crate::structs::member_structs::MemberTrait;
    use crate::structs::voting::{
        DEFAULT_THRESHOLD, Poll, PollConfig, PollStatus, PollTrait, Voted, VotingConfig,
        VotingConfigNode,
    };
    use super::super::member_manager::MemberManagerComponent;

    #[storage]
    pub struct Storage {
        pub polls: Map<u256, Poll>,
        pub voters: Map<(ContractAddress, u256), bool>,
        pub nonce: u256,
        pub config: VotingConfigNode,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Voted: Voted,
    }

    #[embeddable_as(VotingImpl)]
    pub impl Voting<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Member: MemberManagerComponent::HasComponent<TContractState>,
    > of IVote<ComponentState<TContractState>> {
        // revamp
        // add additional creator member details to the poll struct if necessary
        // TODO: Later on, add implementations that can bypass the caller. Perhaps, implement
        // a permit function where admins sign a permit for a user to change his/her address.
        // as the address is used for auth.
        fn create_poll(
            ref self: ComponentState<TContractState>,
            name: ByteArray,
            desc: ByteArray,
            member_id: u256,
        ) -> u256 {
            let caller = get_caller_address();
            let mc = get_dep_component!(@self, Member);
            let member = mc.members.entry(member_id).member.read();
            member.verify(caller);
            let id = self.nonce.read() + 1;
            assert(name.len() > 0 && desc.len() > 0, 'NAME OR DESC IS EMPTY');
            let mut poll: Poll = Default::default();
            poll.name = name;
            poll.desc = desc;
            self.polls.entry(id).write(poll);
            self.nonce.write(id);
            id
        }

        fn vote(ref self: ComponentState<TContractState>, support: bool, id: u256) {
            let mut poll = self.polls.entry(id).read();
            assert(poll != Default::default(), 'INVALID POLL');
            assert(poll.status == Default::default(), 'POLL NOT PENDING');
            let caller = get_caller_address();
            let has_voted = self.voters.entry((caller, id)).read();
            assert(!has_voted, 'CALLER HAS VOTED');
            self.voters.entry((caller, id)).write(true);
            self.emit(Voted { id, voter: caller });

            match support {
                true => poll.yes_votes += 1,
                _ => poll.no_votes += 1,
            }

            let vote_count = poll.yes_votes + poll.no_votes;
            if vote_count >= DEFAULT_THRESHOLD {
                poll.resolve();
                // emit a Poll Resolved Event
            }

            self.polls.entry(id).write(poll);
        }

        fn get_poll(self: @ComponentState<TContractState>, id: u256) -> Poll {
            self.polls.entry(id).read()
        }

        fn end_poll(ref self: ComponentState<TContractState>, id: u256) {}

        fn update_voting_config(ref self: ComponentState<TContractState>, config: VotingConfig) {
            // assert that the config is of VoteConfig
            // for now
            let _ = 0;
        }
    }

    #[generate_trait]
    pub impl VoteInternalImpl<
        TContractState, +HasComponent<ComponentState<TContractState>>,
    > of VoteTrait<TContractState> {
        fn _initialize(
            ref self: ComponentState<TContractState>, admin: ContractAddress, config: VotingConfig,
        ) { // The config should consist of the privacy, voting threshold, weighted (with power) or
        }
    }
}
