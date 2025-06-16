#[starknet::component]
pub mod MemberManagerComponent {
    use core::num::traits::Zero;
    // use littlefinger::interfaces::icore::IConfig;
    use littlefinger::interfaces::imember_manager::IMemberManager;
    use littlefinger::structs::member_structs::{
        InviteStatus, Member, MemberConfig, MemberConfigNode, MemberDetails, MemberEnum,
        MemberEvent, MemberInvite, MemberInvited, MemberNode, MemberResponse, MemberRole,
        MemberStatus, MemberTrait,
    };
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    #[storage]
    pub struct Storage {
        pub admin_count: u64,
        pub admin_ca: Map<ContractAddress, bool>,
        pub members: Map<u256, MemberNode>,
        pub member_count: u256,
        pub role_value: Vec<u16>,
        pub config: MemberConfigNode,
        pub member_invites: Map<ContractAddress, MemberInvite>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        MemberEnum: MemberEnum,
    }

    #[embeddable_as(MemberManager)]
    pub impl MemberManagerImpl<
        TContractState, +HasComponent<TContractState>,
    > of IMemberManager<ComponentState<TContractState>> {
        fn add_member(
            ref self: ComponentState<TContractState>,
            fname: felt252,
            lname: felt252,
            alias: felt252,
            role: MemberRole,
            address: ContractAddress,
            // base_pay: u256
        ) {
            // In this implementation, we are imagining the person who wants to register is calling
            // the function with their wallet actually.
            // This means that we'll have to put verify_member to add to it
            // Will have to find another means to hash the id, or not. Let us see how things go
            let caller = get_caller_address();
            let id: u256 = self.member_count.read() + 1;
            assert(!caller.is_zero(), 'Zero Address Caller');
            let reg_time = get_block_timestamp();
            let status: MemberStatus = Default::default();
            let member = self.members.entry(id);

            let (new_member, details) = MemberTrait::with_details(
                id, fname, lname, status, role, alias, address, 0,
            );
            member.details.write(details);
            // member.base_pay.write(base_pay);
            member.member.write(new_member);
            member.reg_time.write(reg_time);
            member.total_received.write(Option::Some(0));
            member.total_disbursements.write(Option::Some(0));
            self.member_count.write(id);
        }

        fn add_admin(ref self: ComponentState<TContractState>, member_id: u256) {
            let caller = get_caller_address();
            assert(self.admin_ca.entry(caller).read(), 'Caller Not an Admin');
            let member_node = self.members.entry(member_id);
            let mut member = member_node.member.read();
            let old_role = member.role;

            //TODO: When you add events to this, you'll get something from here

            member.role = MemberRole::ADMIN(1);
            self.admin_ca.entry(member.address).write(true);
            self.admin_count.write(self.admin_count.read() + 1);

            member_node.member.write(member);
            // EMIT THE EVENT HERE
        }

        fn update_member_details(
            ref self: ComponentState<TContractState>,
            member_id: u256,
            fname: Option<felt252>,
            lname: Option<felt252>,
            alias: Option<felt252>,
        ) {
            let m = self.members.entry(member_id);
            let member = m.member.read();
            assert(member != Default::default(), 'Member does not exist');
            // check for now
            // in the future, an admin might override this check in the case a member loses
            // access to it's address, or you can use a catridge controller
            member.verify(get_caller_address());
            let mut details = m.details.read();

            if let Option::Some(val) = fname {
                details.fname = val;
            }
            if let Option::Some(val) = lname {
                details.lname = val;
            }
            if let Option::Some(val) = alias {
                details.alias = val;
            }

            m.details.write(details);
        }

        fn update_member_base_pay(
            ref self: ComponentState<TContractState>, member_id: u256, base_pay: u256,
        ) {
            let caller = get_caller_address();
            assert(self.admin_ca.entry(caller).read(), 'UNAUTHORIZED');
            let member_node = self.members.entry(member_id);
            let mut member = member_node.member.read();
            assert(member.is_member(), 'INVALID MEMBER ID');
            // member.base_pay = base_pay;
            member_node.member.write(member);
            member_node.base_pay.write(base_pay);
        }

        fn get_member_base_pay(ref self: ComponentState<TContractState>, member_id: u256) -> u256 {
            let member_node = self.members.entry(member_id);
            let member_base_pay = member_node.base_pay.read();
            member_base_pay
        }

        fn suspend_member(
            ref self: ComponentState<TContractState>,
            member_id: u256 // suspension_duration: u64 //block timestamp operation
        ) {
            let m = self.members.entry(member_id);
            let mut member = m.member.read();
            member.suspend();
            m.member.write(member);
        }

        fn reinstate_member(ref self: ComponentState<TContractState>, member_id: u256) {
            let mut member = self.members.entry(member_id).member.read();
            member.reinstate();
            self.members.entry(member_id).member.write(member);
        }

        fn get_members(self: @ComponentState<TContractState>) -> Span<MemberResponse> {
            let member_count: u256 = self.member_count.read().into();
            let mut members: Array<MemberResponse> = array![];
            for i in 1..member_count + 1 {
                let m = self.members.entry(i);
                let current_member = m.member.read();
                members.append(current_member.to_response(m));
            }

            members.span()
        }

        fn invite_member(
            ref self: ComponentState<TContractState>,
            role: u16, // 0 means contractor, 1 means employee, 2 means admin
            address: ContractAddress,
            renumeration: u256,
        ) -> felt252 {
            // The flow:
            // any admin can invite a member
            // the member can accept
            // For this protocol, the member must accept before other admins verify the member...
            // this can only happen when the member config requires multisig.
            // let id: u256 = (self.member_count.read() + 1).into();
            let caller = get_caller_address();
            assert(self.admin_ca.entry(caller).read(), 'UNAUTHORIZED CALLER');
            assert(role <= 2 && role >= 0, 'Invalid Role');
            let mut actual_role = MemberRole::EMPLOYEE(1);
            if (role == 0) {
                actual_role = MemberRole::CONTRACTOR(1)
            }
            if role == 2 {
                actual_role = MemberRole::ADMIN(1)
            }

            // let new_member = MemberTrait::new(id, fname, lname, Default::default(), '', address,
            // 0);
            // self.members.entry(id).write(new_member);
            let new_member_invite = MemberInvite {
                address,
                role: actual_role,
                base_pay: renumeration,
                invite_status: InviteStatus::PENDING,
                expiry: get_block_timestamp() + 604800 // a week for invite to expire
            };
            // let status: MemberStatus = Default::default();
            self.member_invites.entry(address).write(new_member_invite);
            let timestamp = get_block_timestamp();
            let event = MemberInvited { address, role: actual_role, timestamp };
            self.emit(MemberEnum::Invited(event));
            0
        }

        fn accept_invite(
            ref self: ComponentState<TContractState>,
            fname: felt252,
            lname: felt252,
            alias: felt252,
        ) {
            let caller = get_caller_address();
            let current_timestamp = get_block_timestamp();
            let mut invite = self.member_invites.entry(caller).read();
            if current_timestamp > invite.expiry {
                invite.invite_status = InviteStatus::EXPIRED;
            }
            assert(invite.invite_status == InviteStatus::PENDING, 'Invite used/expired');

            //Signing this function means they accept the invite
            let id = self.member_count.read() + 1;
            let member = Member {
                id, address: caller, status: MemberStatus::ACTIVE, role: invite.role,
                // base_pay: invite.base_pay,
            };
            let member_details = MemberDetails { fname, lname, alias };
            let mut member_node = self.members.entry(id);
            member_node.member.write(member);
            member_node.details.write(member_details);
            member_node.base_pay.write(invite.base_pay);
            member_node.reg_time.write(current_timestamp);
            member_node.no_of_payouts.write(0);
            self.member_count.write(self.member_count.read() + 1);
        }

        fn get_member(self: @ComponentState<TContractState>, member_id: u256) -> MemberResponse {
            let member_ref = self.members.entry(member_id);
            let member = member_ref.member.read();
            member.to_response(member_ref)
        }
        // fn verify_member(
        //     ref self: ComponentState<TContractState>, address: ContractAddress,
        //) { // can be verified only if invitee has accepted, and config is checked.
        // at some scenario, the config is checked, and this fuction just returns
        // if config.<param> != that, return;

        // }

        fn update_member_config(ref self: ComponentState<TContractState>, config: MemberConfig) {}

        fn record_member_payment(
            ref self: ComponentState<TContractState>, member_id: u256, amount: u256, timestamp: u64,
        ) {
            let mut member_node = self.members.entry(member_id);
            member_node
                .total_received
                .write(Option::Some(member_node.total_received.read().unwrap() + 1));
            member_node.no_of_payouts.write(member_node.no_of_payouts.read() + 1);
            member_node.last_disbursement_timestamp.write(Option::Some(timestamp));
            member_node
                .total_disbursements
                .write(Option::Some(member_node.total_disbursements.read().unwrap() + 1));
        }
    }

    // this might init the public key, where necessary
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of MemberInternalTrait<TContractState> {
        fn _initialize(
            ref self: ComponentState<TContractState>,
            fname: felt252,
            lname: felt252,
            alias: felt252,
            owner: ContractAddress,
            // config: MemberConfig,
        ) {
            // This will be for making admins and giving people control/taking it away
            let caller = get_caller_address();
            let id: u256 = (self.member_count.read() + 1).into();
            assert(!caller.is_zero(), 'Zero Address Caller');

            let reg_time = get_block_timestamp();
            let role = MemberRole::ADMIN(0);
            // let (new_admin, details) = MemberTrait::with_details(
            //     id, fname, lname, status, role, alias, caller,
            // );
            let new_admin = Member { id, address: caller, status: MemberStatus::ACTIVE, role };
            let new_admin_details = MemberDetails { fname, lname, alias };
            // let new_admin = MemberTrait::new(id, fname, lname, role, alias, caller, reg_time);

            let mut new_admin_node = self.members.entry(id);

            // This is where you write to the node
            new_admin_node.details.write(new_admin_details);
            new_admin_node.member.write(new_admin);
            new_admin_node.reg_time.write(reg_time);

            self.admin_ca.entry(caller).write(true);
            self.admin_ca.entry(owner).write(true);
            let admin_count = self.admin_count.read();

            // self.admins.entry(admin_count + 1).write(new_admin);
            self.member_count.write(self.member_count.read() + 1);
            self.admin_count.write(admin_count + 1);
        }

        fn get_role_value(self: @ComponentState<TContractState>, member_id: u256) -> u16 {
            // read member node
            let role = self.members.entry(member_id).member.read().role;
            assert(role != Default::default(), 'INVALID MEMBER ID');
            match role {
                MemberRole::CONTRACTOR(val) => val * self.role_value.at(0).read(),
                MemberRole::EMPLOYEE(val) => val * self.role_value.at(1).read(),
                MemberRole::ADMIN(val) => val * self.role_value.at(2).read(),
                _ => 0,
            }
        }

        fn assert_admin(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(self.admin_ca.entry(caller).read(), 'UNAUTHORIZED');
        }
    }
}
