#[starknet::component]
pub mod VotingComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    // use crate::interfaces::icore::IConfig;
    use crate::interfaces::voting::IVote;
    use crate::structs::member_structs::MemberTrait;
    use crate::structs::voting::{
        Poll, PollConfig, PollReason, PollStatus, PollTrait, Voted, VotingConfig, VotingConfigNode,
    };
    use super::super::member_manager::MemberManagerComponent;

    #[storage]
    pub struct Storage {
        pub polls: Map<u256, Poll>,
        pub has_voted: Map<(ContractAddress, u256), bool>,
        pub no_of_polls: u256,
        pub config: VotingConfigNode,
        pub generic_threshold: u256,
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
            ref self: ComponentState<TContractState>, // name: ByteArray,
            // desc: ByteArray,
            member_id: u256, reason: PollReason,
        ) -> u256 {
            let caller = get_caller_address();
            let mc = get_dep_component!(@self, Member);
            let member = mc.members.entry(member_id).member.read();
            member.verify(caller);
            let id = self.no_of_polls.read();
            let poll = Poll {
                proposer: member_id,
                poll_id: id,
                reason,
                up_votes: 0,
                down_votes: 0,
                status: PollStatus::Pending,
                created_at: get_block_timestamp(),
            };

            self.polls.entry(id).write(poll);
            self.no_of_polls.write(self.no_of_polls.read() + 1);
            id
        }

        fn vote(ref self: ComponentState<TContractState>, support: bool, poll_id: u256) {
            let mut poll = self.polls.entry(poll_id).read();
            assert(poll != Default::default(), 'INVALID POLL');
            assert(poll.status == Default::default(), 'POLL NOT PENDING');
            let caller = get_caller_address();
            let has_voted = self.has_voted.entry((caller, poll_id)).read();
            assert(!has_voted, 'CALLER HAS VOTED');

            match support {
                true => poll.up_votes += 1,
                _ => poll.down_votes += 1,
            }

            let threshold = self.generic_threshold.read();
            // Right now, the threshold means the number of people that will vote in the election
            // which is wrong. What it should be is the minimum number of approvers (yes_votes)
            // required for the poll to be deemed wrong or right. However, do not try to implement
            // this until the permission control component is added to the codebase

            let vote_count = poll.up_votes + poll.down_votes;
            if vote_count >= threshold {
                poll.resolve();
                // emit a Poll Resolved Event
            }
            self.has_voted.entry((caller, poll_id)).write(true);
            self.emit(Voted { id: poll_id, voter: caller });

            self.polls.entry(poll_id).write(poll);
        }

        fn set_threshold(ref self: ComponentState<TContractState>, threshold: u256) {
            // Protect this with permissions later
            self.generic_threshold.write(threshold);
        }

        fn get_all_polls(self: @ComponentState<TContractState>) -> Array<Poll> {
            let mut poll_array = array![];

            for i in 0..(self.no_of_polls.read() + 1) {
                let current_poll = self.polls.entry(i).read();
                poll_array.append(current_poll);
            }

            poll_array
        }

        fn get_threshold(self: @ComponentState<TContractState>) -> u256 {
            self.generic_threshold.read()
        }

        fn get_poll(self: @ComponentState<TContractState>, poll_id: u256) -> Poll {
            self.polls.entry(poll_id).read()
        }

        // fn end_poll(ref self: ComponentState<TContractState>, id: u256) {}

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
            ref self: ComponentState<TContractState>,
            admin: ContractAddress,
            config: VotingConfig,
            threshold: u256,
        ) { // The config should consist of the privacy, voting threshold, weighted (with power) or
            self.no_of_polls.write(0);
            self.generic_threshold.write(threshold);
        }
    }
}
