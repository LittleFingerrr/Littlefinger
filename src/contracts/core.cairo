/// ## A Starknet contract that acts as the central hub for an organization.
///
/// This core contract integrates multiple components to manage a complete organizational structure.
/// It is responsible for:
/// - Initializing all components with the organization's details.
/// - Coordinating high-level workflows, such as payroll and disbursements.
/// - Acting as the primary entry point for managing the organization.
///
/// It brings together the following components:
/// - `MemberManagerComponent`: For handling member data and roles.
/// - `OrganizationComponent`: For storing general organization metadata.
/// - `VotingComponent`: For governance and proposals.
/// - `DisbursementComponent`: For managing payment schedules and calculations.
/// - `OwnableComponent` and `UpgradeableComponent`: For access control and contract upgrades.
#[starknet::contract]
mod Core {
    use MemberManagerComponent::MemberInternalTrait;
    use OrganizationComponent::OrganizationInternalTrait;
    use littlefinger::components::admin_permission_manager::AdminPermissionManagerComponent;
    use littlefinger::components::dao_controller::VotingComponent;
    use littlefinger::components::disbursement::DisbursementComponent;
    use littlefinger::components::member_manager::MemberManagerComponent;
    use littlefinger::components::organization::OrganizationComponent;
    use littlefinger::interfaces::icore::ICore;
    use littlefinger::interfaces::ivault::{IVaultDispatcher, IVaultDispatcherTrait};
    use littlefinger::structs::admin_permissions::AdminPermission;
    use littlefinger::structs::disbursement_structs::ScheduleStatus;
    // use littlefinger::structs::organization::{OrganizationConfig, OrganizationInfo, OwnerInit};
    use littlefinger::structs::member_structs::MemberRoleIntoU16;
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::StoragePointerWriteAccess;
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::interfaces::imember_manager::IMemberManager;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: MemberManagerComponent, storage: member, event: MemberEvent);
    component!(path: OrganizationComponent, storage: organization, event: OrganizationEvent);
    component!(path: VotingComponent, storage: voting, event: VotingEvent);
    component!(path: DisbursementComponent, storage: disbursement, event: DisbursementEvent);
    component!(
        path: AdminPermissionManagerComponent,
        storage: admin_permission_manager,
        event: AdminPermissionManagerEvent,
    );

    #[abi(embed_v0)]
    impl MemberImpl = MemberManagerComponent::MemberManager<ContractState>;
    #[abi(embed_v0)]
    impl DisbursementImpl =
        DisbursementComponent::DisbursementManager<ContractState>;
    #[abi(embed_v0)]
    impl OrganizationImpl =
        OrganizationComponent::OrganizationManager<ContractState>;
    #[abi(embed_v0)]
    impl VotingImpl = VotingComponent::VotingImpl<ContractState>;
    #[abi(embed_v0)]
    impl AdminPermissionManagerImpl =
        AdminPermissionManagerComponent::AdminPermissionManagerImpl<ContractState>;

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;
    impl DisbursementInternalImpl = DisbursementComponent::InternalImpl<ContractState>;


    /// Defines the storage layout for the `Core` contract.
    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    struct Storage {
        /// The address of the associated vault contract.
        vault_address: ContractAddress,
        /// Substorage for the MemberManager component.
        #[substorage(v0)]
        member: MemberManagerComponent::Storage, //my component
        /// Substorage for the Ownable component.
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        /// Substorage for the Upgradeable component.
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        /// Substorage for the Organization component.
        #[substorage(v0)]
        organization: OrganizationComponent::Storage, //my component
        /// Substorage for the Voting component.
        #[substorage(v0)]
        voting: VotingComponent::Storage, //my component
        /// Substorage for the Disbursement component.
        #[substorage(v0)]
        disbursement: DisbursementComponent::Storage, //my component
        /// Substorage for the AdminPermissionManager component.
        #[substorage(v0)]
        admin_permission_manager: AdminPermissionManagerComponent::Storage //my component
    }

    /// Events emitted by the `Core` contract, including events from all its components.
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        /// Emits member-related events.
        #[flat]
        MemberEvent: MemberManagerComponent::Event,
        /// Emits ownable-related events.
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        /// Emits upgradeable-related events.
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        /// Emits organization-related events.
        #[flat]
        OrganizationEvent: OrganizationComponent::Event,
        /// Emits voting-related events.
        #[flat]
        VotingEvent: VotingComponent::Event,
        /// Emits disbursement-related events.
        #[flat]
        DisbursementEvent: DisbursementComponent::Event,
        /// Emits admin permission manager-related events.
        #[flat]
        AdminPermissionManagerEvent: AdminPermissionManagerComponent::Event,
    }

    // #[derive(Drop, Copy, Serde)]
    // pub struct OwnerInit {
    //     pub address: ContractAddress,
    //     pub fnmae: felt252,
    //     pub lastname: felt252,
    // }

    /// Initializes the Core contract and all its integrated components.
    ///
    /// ### Parameters
    /// - `org_id`: A unique identifier for the organization.
    /// - `org_name`: The name of the organization.
    /// - `owner`: The address of the initial owner and first admin.
    /// - `ipfs_url`: A URL pointing to organization metadata (e.g., on IPFS).
    /// - `vault_address`: The address of the organization's vault contract.
    /// - `first_admin_fname`: First name of the initial admin.
    /// - `first_admin_lname`: Last name of the initial admin.
    /// - `first_admin_alias`: Alias of the initial admin.
    /// - `deployer`: The address of the contract deployer.
    /// - `organization_type`: A numerical identifier for the type of organization.
    /// - `factory`: The address of the factory contract that deployed this core contract.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        // organization_info: OrganizationInfo,
        org_id: u256,
        org_name: ByteArray,
        owner: ContractAddress,
        ipfs_url: ByteArray,
        vault_address: ContractAddress,
        first_admin_fname: felt252,
        first_admin_lname: felt252,
        first_admin_alias: felt252,
        deployer: ContractAddress,
        organization_type: u8,
        factory: ContractAddress,
    ) { // owner
        self
            .organization
            ._init(
                Option::Some(owner),
                org_name,
                ipfs_url,
                vault_address,
                org_id,
                deployer,
                organization_type,
            );
        self
            .member
            ._initialize(
                first_admin_fname,
                first_admin_lname,
                first_admin_alias,
                owner,
                factory,
                get_contract_address(),
            );
        self.vault_address.write(vault_address);
        self.disbursement._init(owner);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        /// Upgrades the contract to a new class hash.
        ///
        /// ### Parameters
        /// - `new_class_hash`: The class hash of the new contract implementation.
        ///
        /// ### Panics
        /// - If the caller is not the owner.
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This might be upgraded from the factory
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // TODO: ADD ADMIN FROM HERE

    /// # CoreImpl
    ///
    /// Public-facing implementation of the `ICore` interface.
    #[abi(embed_v0)]
    impl CoreImpl of ICore<ContractState> {
        /// Initializes a new disbursement schedule. This function is a pass-through
        /// to the Disbursement component.
        ///
        /// ### Parameters
        /// - `schedule_type`: Type of schedule (e.g., weekly, monthly).
        /// - `start`: Unix timestamp for the schedule's start time.
        /// - `end`: Unix timestamp for the schedule's end time.
        /// - `interval`: Payout interval in seconds.
        fn initialize_disbursement_schedule(
            ref self: ContractState,
            schedule_type: u8,
            start: u64, //timestamp
            end: u64,
            interval: u64,
        ) {
            self
                .admin_permission_manager
                .has_admin_permission(
                    get_caller_address(), AdminPermission::SET_DISBURSEMENT_SCHEDULES,
                );

            self.disbursement._initialize(schedule_type, start, end, interval)
        }

        /// Executes a scheduled payout to all members.
        ///
        /// This function calculates the total weight of all members based on their roles,
        /// determines each member's share of the available funds and bonus allocation,
        /// and instructs the vault to transfer the corresponding amounts.
        ///
        /// ### Panics
        /// - If there is no active disbursement schedule.
        /// - If the payout is attempted before the scheduled start time or after the end time.
        /// - If the payout is attempted before the required interval has passed since the last
        /// execution.
        fn schedule_payout(ref self: ContractState, token: ContractAddress) {
            // self.admin_permission_manager.has_admin_permission(get_caller_address(),
            // AdminPermission::);

            let members = self.member.get_members();
            let no_of_members = members.len();

            let org_info = self.organization.get_organization_details();
            let vault_address = org_info.vault_address;

            let vault_dispatcher = IVaultDispatcher { contract_address: vault_address };
            let total_bonus = vault_dispatcher.get_bonus_allocation(token);

            let current_schedule = self.disbursement.get_current_schedule();
            assert(current_schedule.status == ScheduleStatus::ACTIVE, 'Schedule not active');

            let now = get_block_timestamp();
            assert(now >= current_schedule.start_timestamp, 'Payout has not started');
            assert(now < current_schedule.end_timestamp, 'Payout period ended');

            if current_schedule.last_execution != 0 {
                assert(
                    now >= current_schedule.last_execution + current_schedule.interval,
                    'Payout premature',
                );
            }

            // Everyone uses a base weight multiplier at the start, of 1
            let mut total_weight: u16 = 0;
            for i in 0..no_of_members {
                let current_member = *members.at(i);
                let current_member_role = MemberRoleIntoU16::into(current_member.role);
                total_weight += current_member_role;
            }
            for i in 0..no_of_members {
                let current_member_response = *members.at(i);
                let timestamp = get_block_timestamp();
                let amount = self
                    .disbursement
                    .compute_renumeration(current_member_response, total_bonus, total_weight);
                vault_dispatcher.pay_member(token, current_member_response.address, amount);
                self.member.record_member_payment(current_member_response.id, amount, timestamp)
            }

            self.disbursement.update_current_schedule_last_execution(now);
        }
    }
}
