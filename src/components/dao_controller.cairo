#[starknet::component]
pub mod VotingComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    // use crate::interfaces::icore::IConfig;
    use crate::interfaces::dao_controller::IVote;
    use crate::structs::dao_controller::{
        Poll, PollCreated, PollReason, PollResolved, PollStatus, PollStopped, PollTrait,
        ThresholdChanged, Voted, VotingConfig, VotingConfigNode,
    };
    use crate::structs::member_structs::{MemberRoleIntoU16, MemberTrait};
    use super::super::member_manager::MemberManagerComponent;

    #[storage]
    pub struct Storage {
        pub polls: Map<u256, Poll>,
        pub has_voted: Map<(ContractAddress, u256), bool>,
        pub no_of_polls: u256,
        pub config: VotingConfigNode,
        pub generic_threshold: u256,
        pub min_role_for_voting: u16,
        pub min_role_for_polling: u16,
        pub min_role_for_executing: u16,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Voted: Voted,
        PollResolved: PollResolved,
        PollCreated: PollCreated,
        PollStopped: PollStopped,
        ThresholdChanged: ThresholdChanged,
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
            member_id: u256,
            reason: PollReason,
        ) -> u256 {
            let caller = get_caller_address();
            let mc = get_dep_component!(@self, Member);
            let member = mc.members.entry(member_id).member.read();
            member.verify(caller);
            let role_in_u16 = MemberRoleIntoU16::into(member.role);
            assert(role_in_u16 >= self.min_role_for_polling.read(), 'Not qualified to poll');
            let id = self.no_of_polls.read();
            let poll = Poll {
                proposer: member_id,
                poll_id: id,
                reason,
                up_votes: 0,
                down_votes: 0,
                status: PollStatus::ACTIVE,
                created_at: get_block_timestamp(),
            };

            self.polls.entry(id).write(poll);
            self.no_of_polls.write(self.no_of_polls.read() + 1);
            self
                .emit(
                    PollCreated { id, proposer: caller, reason, timestamp: get_block_timestamp() },
                );
            id
        }

        fn approve(ref self: ComponentState<TContractState>, poll_id: u256, member_id: u256) {
            let caller = get_caller_address();
            let mc = get_dep_component!(@self, Member);
            let member = mc.members.entry(member_id).member.read();
            member.verify(caller);

            let role_in_u16 = MemberRoleIntoU16::into(member.role);
            assert(role_in_u16 >= self.min_role_for_voting.read(), 'Not qualified to poll');

            let mut poll = self.polls.entry(poll_id).read();
            assert(poll != Default::default(), 'INVALID POLL');
            assert(poll.status == PollStatus::ACTIVE, 'POLL NOT ACTIVE');

            let has_voted = self.has_voted.entry((caller, poll_id)).read();
            assert(!has_voted, 'CALLER HAS VOTED');

            let timestamp = get_block_timestamp();

            poll.up_votes += 1;

            let threshold = self.generic_threshold.read();
            // Right now, the threshold means the number of people that will vote in the election
            // which is wrong. What it should be is the minimum number of approvers (yes_votes)
            // required for the poll to be deemed wrong or right. However, do not try to implement
            // this until the permission control component is added to the codebase

            if poll.up_votes >= threshold {
                let outcome = poll.resolve();
                self.emit(PollResolved { id: poll_id, outcome, timestamp })
            }
            self.has_voted.entry((caller, poll_id)).write(true);
            self.emit(Voted { id: poll_id, voter: caller, timestamp });

            self.polls.entry(poll_id).write(poll);
        }

        fn reject(ref self: ComponentState<TContractState>, poll_id: u256, member_id: u256) {
            let caller = get_caller_address();
            let mc = get_dep_component!(@self, Member);
            let member = mc.members.entry(member_id).member.read();
            member.verify(caller);

            let role_in_u16 = MemberRoleIntoU16::into(member.role);
            assert(role_in_u16 >= self.min_role_for_voting.read(), 'Not qualified to poll');

            let mut poll = self.polls.entry(poll_id).read();
            assert(poll != Default::default(), 'INVALID POLL');
            assert(poll.status == PollStatus::ACTIVE, 'POLL NOT ACTIVE');

            let has_voted = self.has_voted.entry((caller, poll_id)).read();
            assert(!has_voted, 'CALLER HAS VOTED');
            let timestamp = get_block_timestamp();

            poll.down_votes += 1;

            let threshold = self.generic_threshold.read();

            let max_possible_of_voters: u256 = self.get_eligible_voters().len().into();
            let max_no_of_possible_approvals = max_possible_of_voters - poll.down_votes;

            if max_no_of_possible_approvals < threshold {
                let outcome = poll.resolve();
                self.emit(PollResolved { id: poll_id, outcome, timestamp })
            }

            self.has_voted.entry((caller, poll_id)).write(true);
            self.emit(Voted { id: poll_id, voter: caller, timestamp });

            self.polls.entry(poll_id).write(poll);
        }

        fn set_threshold(
            ref self: ComponentState<TContractState>, new_threshold: u256, member_id: u256,
        ) {
            // Protect this with permissions later
            let caller = get_caller_address();
            let mc = get_dep_component!(@self, Member);
            let member = mc.members.entry(member_id).member.read();
            member.verify(caller);

            let role_in_u16 = MemberRoleIntoU16::into(member.role);
            assert(role_in_u16 >= self.min_role_for_executing.read(), 'Setter not qualified');

            let previous_threshold = self.generic_threshold.read();
            self.generic_threshold.write(new_threshold);
            self
                .emit(
                    ThresholdChanged {
                        previous_threshold, new_threshold, timestamp: get_block_timestamp(),
                    },
                );
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

        fn get_eligible_voters(self: @ComponentState<TContractState>) -> Array<u256> {
            let mc = get_dep_component!(self, Member);
            let mut eligible_voters: Array<u256> = array![];

            for i in 0..mc.member_count.read() {
                let current_member = mc.members.entry(i).member.read();
                let role_in_u16 = MemberRoleIntoU16::into(current_member.role);
                if role_in_u16 >= self.min_role_for_voting.read() {
                    eligible_voters.append(current_member.id)
                }
            }

            eligible_voters
        }

        fn get_eligible_pollers(self: @ComponentState<TContractState>) -> Array<u256> {
            let mc = get_dep_component!(self, Member);
            let mut eligible_voters: Array<u256> = array![];

            for i in 0..mc.member_count.read() {
                let current_member = mc.members.entry(i).member.read();
                let role_in_u16 = MemberRoleIntoU16::into(current_member.role);
                if role_in_u16 >= self.min_role_for_polling.read() {
                    eligible_voters.append(current_member.id)
                }
            }

            eligible_voters
        }

        fn get_eligible_executors(self: @ComponentState<TContractState>) -> Array<u256> {
            let mc = get_dep_component!(self, Member);
            let mut eligible_voters: Array<u256> = array![];

            for i in 0..mc.member_count.read() {
                let current_member = mc.members.entry(i).member.read();
                let role_in_u16 = MemberRoleIntoU16::into(current_member.role);
                if role_in_u16 >= self.min_role_for_executing.read() {
                    eligible_voters.append(current_member.id)
                }
            }

            eligible_voters
        }
    }

    #[generate_trait]
    pub impl VoteInternalImpl<
        TContractState, +HasComponent<TContractState>,
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
