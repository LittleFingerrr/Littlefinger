/// # MemberManagerComponent
///
/// A Starknet component responsible for managing the members of an organization.
/// This component handles member registration, role assignment, status updates,
/// invitations, and profile management. It interacts with a factory contract
/// to coordinate state across a broader system.
#[starknet::component]
pub mod MemberManagerComponent {
    use core::num::traits::Zero;
    use littlefinger::interfaces::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
    // use littlefinger::interfaces::icore::IConfig;
    use littlefinger::interfaces::imember_manager::IMemberManager;
    use littlefinger::structs::member_structs::{
        InviteAccepted, InviteStatus, Member, MemberConfig, MemberConfigNode, MemberDetails,
        MemberEnum, MemberInvite, MemberInvited, MemberNode, MemberResponse, MemberRole,
        MemberStatus, MemberTrait,
    };
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    /// # Storage
    ///
    /// Defines the storage layout for the MemberManagerComponent.
    #[storage]
    pub struct Storage {
        /// @notice The total number of administrators in the organization.
        pub admin_count: u64,
        /// @notice A mapping from a contract address to a boolean indicating admin status.
        /// Used for quick verification of admin privileges.
        pub admin_ca: Map<ContractAddress, bool>,
        /// @notice A mapping from a unique member ID (u256) to the member's data node
        /// (`MemberNode`).
        pub members: Map<u256, MemberNode>,
        /// @notice A counter for the total number of members, also used to generate new member IDs.
        pub member_count: u256,
        /// @notice A vector of weights or values associated with different role types.
        /// Likely used for governance or weighted calculations.
        pub role_value: Vec<u16>,
        /// @notice A storage node for member-related configurations.
        pub config: MemberConfigNode,
        /// @notice A mapping from a potential member's address to their invitation details
        /// (`MemberInvite`).
        pub member_invites: Map<ContractAddress, MemberInvite>,
        /// @notice The address of the associated factory contract.
        pub factory: ContractAddress,
        /// @notice The address of the core organization contract this component is a part of.
        pub core_org: ContractAddress,
    }

    /// # Event
    ///
    /// Defines the events that can be emitted by the MemberManagerComponent.
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        /// @notice An enum for emitting various member-related events.
        #[flat]
        MemberEnum: MemberEnum,
    }

    /// # MemberManagerImpl
    ///
    /// Implementation of the `IMemberManager` trait, providing the public-facing
    /// functions for managing members.
    #[embeddable_as(MemberManager)]
    pub impl MemberManagerImpl<
        TContractState, +HasComponent<TContractState>,
    > of IMemberManager<ComponentState<TContractState>> {
        /// # add_member
        ///
        /// Adds a new member directly to the organization. This is an administrative function.
        /// It creates a new member with the specified details and role, and updates the factory
        /// contract.
        ///
        /// @param self The component's state.
        /// @param fname The first name of the member.
        /// @param lname The last name of the member.
        /// @param alias An alias or username for the member.
        /// @param role A numerical representation of the member's role (0-14).
        /// @param address The Starknet address of the new member.
        fn add_member(
            ref self: ComponentState<TContractState>,
            fname: felt252,
            lname: felt252,
            alias: felt252,
            role: u16, // Role is from 0 - 14
            address: ContractAddress,
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

            let mut member_role = MemberRole::None;

            match role {
                0 => { member_role = MemberRole::None },
                1 | 2 | 3 | 4 => { member_role = MemberRole::CONTRACTOR(role) },
                5 | 6 | 7 | 8 | 9 | 10 => { member_role = MemberRole::EMPLOYEE(role) },
                11 | 12 | 13 | 14 => { member_role = MemberRole::ADMIN(role) },
                _ => { member_role = MemberRole::None },
            }

            let (new_member, details) = MemberTrait::with_details(
                id, fname, lname, status, member_role, alias, address, 0,
            );
            member.details.write(details);
            member.member.write(new_member);
            member.reg_time.write(reg_time);
            member.total_received.write(Option::Some(0));
            member.total_disbursements.write(Option::Some(0));
            self.member_count.write(id);

            let factory_dispatcher = IFactoryDispatcher { contract_address: self.factory.read() };
            factory_dispatcher.update_member_of(address, self.core_org.read());
        }

        /// # add_admin
        ///
        /// Promotes an existing member to an administrator role.
        /// The caller must be an existing admin to execute this function.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member to be promoted.
        fn add_admin(ref self: ComponentState<TContractState>, member_id: u256) {
            let caller = get_caller_address();
            assert(self.admin_ca.entry(caller).read(), 'Caller Not an Admin');
            let member_node = self.members.entry(member_id);
            let mut member = member_node.member.read();
            // let old_role = member.role;

            // TODO: When you add events to this, you'll get something from here

            member.role = MemberRole::ADMIN(1);
            self.admin_ca.entry(member.address).write(true);
            self.admin_count.write(self.admin_count.read() + 1);

            member_node.member.write(member);
            // EMIT THE EVENT HERE
        }

        /// # update_member_details
        ///
        /// Allows a member to update their own profile details (first name, last name, alias).
        /// The caller must be the member themselves, verified by `member.verify`.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member whose details are to be updated.
        /// @param fname An optional new first name.
        /// @param lname An optional new last name.
        /// @param alias An optional new alias.
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

        /// # update_member_base_pay
        ///
        /// Updates the base pay for a specific member.
        /// This is an administrative function and requires the caller to be an admin.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member to update.
        /// @param base_pay The new base pay amount.
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

        /// # get_member_base_pay
        ///
        /// Retrieves the base pay for a specific member.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member.
        /// @return The base pay of the member.
        fn get_member_base_pay(ref self: ComponentState<TContractState>, member_id: u256) -> u256 {
            let member_node = self.members.entry(member_id);
            let member_base_pay = member_node.base_pay.read();
            member_base_pay
        }

        /// # suspend_member
        ///
        /// Sets a member's status to `SUSPENDED`.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member to suspend.
        fn suspend_member(
            ref self: ComponentState<TContractState>,
            member_id: u256 // suspension_duration: u64 //block timestamp operation
        ) {
            let m = self.members.entry(member_id);
            let mut member = m.member.read();
            member.suspend();
            m.member.write(member);
        }

        /// # reinstate_member
        ///
        /// Reinstates a suspended member, setting their status to `ACTIVE`.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member to reinstate.
        fn reinstate_member(ref self: ComponentState<TContractState>, member_id: u256) {
            let mut member = self.members.entry(member_id).member.read();
            member.reinstate();
            self.members.entry(member_id).member.write(member);
        }

        /// # get_members
        ///
        /// Retrieves a list of all members in the organization by iterating
        /// from the first member ID up to the current `member_count`.
        ///
        /// @param self The component's state.
        /// @return A `Span` containing `MemberResponse` structs for all members.
        fn get_members(self: @ComponentState<TContractState>) -> Span<MemberResponse> {
            let member_count: u256 = self.member_count.read().into();
            let mut members: Array<MemberResponse> = array![];
            for i in 1..(member_count + 1) {
                let m = self.members.entry(i);
                let current_member = m.member.read();
                members.append(current_member.to_response(m));
            }

            members.span()
        }

        /// # invite_member
        ///
        /// Creates an invitation for a new member. The invitation is sent to a specific address
        /// and has an expiration of one week. This is an admin-only function.
        ///
        /// @param self The component's state.
        /// @param role The role to be assigned upon acceptance (0: Contractor, 1: Employee, 2:
        /// Admin).
        /// @param address The address of the person being invited.
        /// @param renumeration The base pay offered in the invitation.
        /// @return A felt252 value (currently 0, used for status).
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
            let factory_dispatcher = IFactoryDispatcher { contract_address: self.factory.read() };
            factory_dispatcher.create_invite(address, new_member_invite, self.core_org.read());
            let event = MemberInvited { address, role: actual_role, timestamp };
            self.emit(MemberEnum::Invited(event));
            0
        }

        /// # accept_invite
        ///
        /// Called by an invited individual to accept their invitation and become a member.
        /// The caller's address must match a pending and unexpired invitation.
        /// On acceptance, a new member is created and the invitation status is updated.
        ///
        /// @param self The component's state.
        /// @param fname The first name of the accepting member.
        /// @param lname The last name of the accepting member.
        /// @param alias An alias for the accepting member.
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

            // Signing this function means they accept the invite
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
            invite.invite_status = InviteStatus::ACCEPTED;
            let factory_dispatcher = IFactoryDispatcher { contract_address: self.factory.read() };
            factory_dispatcher.accpet_invite(caller);
            let event = InviteAccepted { address: caller, timestamp: current_timestamp };
            self.emit(MemberEnum::InviteAccepted(event));
        }

        /// # get_member
        ///
        /// Retrieves the full details of a single member in a response format.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member to retrieve.
        /// @return A `MemberResponse` struct containing the member's public data.
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

        /// # update_member_config
        ///
        /// Placeholder function intended to update member-related configurations. Currently not
        /// implemented.
        ///
        /// @param self The component's state.
        /// @param config The new member configuration.
        fn update_member_config(ref self: ComponentState<TContractState>, config: MemberConfig) {}

        /// # record_member_payment
        ///
        /// Records that a payment has been made to a member, updating their payment statistics,
        /// including total received, number of payouts, and last disbursement timestamp.
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member who received the payment.
        /// @param amount The amount of the payment.
        /// @param timestamp The timestamp of the payment.
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

        /// # get_factory_address
        ///
        /// Retrieves the address of the associated factory contract.
        ///
        /// @param self The component's state.
        /// @return The `ContractAddress` of the factory.
        fn get_factory_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.factory.read()
        }

        /// # get_core_org_address
        ///
        /// Retrieves the address of the core organization contract.
        ///
        /// @param self The component's state.
        /// @return The `ContractAddress` of the core organization.
        fn get_core_org_address(self: @ComponentState<TContractState>) -> ContractAddress {
            self.core_org.read()
        }
    }

    /// # InternalImpl
    ///
    /// Contains internal functions for the component, for initialization
    /// and privileged, non-public operations.
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of MemberInternalTrait<TContractState> {
        /// # _initialize
        ///
        /// Initializes the MemberManagerComponent, setting up the first administrator and
        /// essential contract addresses. This function is designed to be called only once
        /// during the initial deployment of the contract.
        ///
        /// @param self The component's state.
        /// @param fname The first name of the initial admin.
        /// @param lname The last name of the initial admin.
        /// @param alias An alias for the initial admin.
        /// @param owner The address that will own the initial admin member.
        /// @param factory The address of the factory contract.
        /// @param core_org The address of the core organization contract.
        fn _initialize(
            ref self: ComponentState<TContractState>,
            fname: felt252,
            lname: felt252,
            alias: felt252,
            owner: ContractAddress,
            factory: ContractAddress,
            core_org: ContractAddress,
            // config: MemberConfig,
        ) {
            // This will be for making admins and giving people control/taking it away
            let caller = get_caller_address();
            let id: u256 = (self.member_count.read() + 1).into();
            assert(!caller.is_zero(), 'Zero Address Caller');

            let reg_time = get_block_timestamp();
            let role = MemberRole::ADMIN(11);
            // let (new_admin, details) = MemberTrait::with_details(
            //     id, fname, lname, status, role, alias, caller,
            // );
            let new_admin = Member { id, address: owner, status: MemberStatus::ACTIVE, role };
            let new_admin_details = MemberDetails { fname, lname, alias };
            // let new_admin = MemberTrait::new(id, fname, lname, role, alias, caller, reg_time);

            let mut new_admin_node = self.members.entry(id);

            // This is where you write to the node
            new_admin_node.details.write(new_admin_details);
            new_admin_node.member.write(new_admin);
            new_admin_node.reg_time.write(reg_time);
            new_admin_node.total_received.write(Option::Some(0));
            new_admin_node.total_disbursements.write(Option::Some(0));

            self.admin_ca.entry(caller).write(true);
            self.admin_ca.entry(owner).write(true);
            let admin_count = self.admin_count.read();

            // self.admins.entry(admin_count + 1).write(new_admin);
            self.member_count.write(self.member_count.read() + 1);
            self.admin_count.write(admin_count + 1);
            self.factory.write(factory);
            self.core_org.write(core_org);
        }

        /// # get_role_value
        ///
        /// Calculates a weighted value for a member's role based on their specific
        /// role level and the base value for that role type (Contractor, Employee, Admin).
        ///
        /// @param self The component's state.
        /// @param member_id The ID of the member.
        /// @return A `u16` representing the calculated role value. Returns 0 for invalid members or
        /// roles.
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

        /// # assert_admin
        ///
        /// A helper function that asserts whether the current caller is an administrator.
        /// It will revert the transaction with 'UNAUTHORIZED' if the caller is not an admin.
        /// This is used as a security check in privileged functions.
        ///
        /// @param self The component's state.
        fn assert_admin(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(self.admin_ca.entry(caller).read(), 'UNAUTHORIZED');
        }
    }
}
