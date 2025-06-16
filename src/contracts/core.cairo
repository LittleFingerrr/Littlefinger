#[starknet::contract]
mod Core {
    use MemberManagerComponent::MemberInternalTrait;
    use OrganizationComponent::OrganizationInternalTrait;
    use littlefinger::components::disbursement::DisbursementComponent;
    use littlefinger::components::member_manager::MemberManagerComponent;
    use littlefinger::components::organization::OrganizationComponent;
    use littlefinger::components::voting::VotingComponent;
    use littlefinger::interfaces::icore::ICore;
    use littlefinger::interfaces::ivault::{IVaultDispatcher, IVaultDispatcherTrait};
    use littlefinger::structs::disbursement_structs::{ScheduleStatus, UnitDisbursement};
    // use littlefinger::structs::organization::{OrganizationConfig, OrganizationInfo, OwnerInit};
    use littlefinger::structs::member_structs::{Member, MemberResponse, MemberRoleIntoU16};
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
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    impl DisbursementInternalImpl = DisbursementComponent::InternalImpl<ContractState>;

    #[storage]
    #[allow(starknet::colliding_storage_paths)]
    struct Storage {
        vault_address: ContractAddress,
        #[substorage(v0)]
        member: MemberManagerComponent::Storage, //my component
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        organization: OrganizationComponent::Storage, //my component
        #[substorage(v0)]
        voting: VotingComponent::Storage, //my component
        #[substorage(v0)]
        disbursement: DisbursementComponent::Storage //my component
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        MemberEvent: MemberManagerComponent::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        OrganizationEvent: OrganizationComponent::Event,
        #[flat]
        VotingEvent: VotingComponent::Event,
        #[flat]
        DisbursementEvent: DisbursementComponent::Event,
    }

    // #[derive(Drop, Copy, Serde)]
    // pub struct OwnerInit {
    //     pub address: ContractAddress,
    //     pub fnmae: felt252,
    //     pub lastname: felt252,
    // }

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
    ) { // owner
        self
            .organization
            ._init(Option::Some(owner), org_name, ipfs_url, vault_address, org_id, deployer);
        // MemberManagerComponent::InternalImpl::_initialize(
        //     ref self.member, first_admin_fname, first_admin_lname, first_admin_alias
        // )
        self.member._initialize(first_admin_fname, first_admin_lname, first_admin_alias, owner);
        self.vault_address.write(vault_address);
        self.disbursement._init(owner);
        // self.disbursement._add_authorized_caller(deployer);
        // let this_contract = get_contract_address();
        // self.disbursement._add_authorized_caller(this_contract);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This might be upgraded from the factory
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    // TODO: ADD ADMIN FROM HERE

    // TODO: DO TRANSFER FROM HERE WHEN YOU WANT TO PAYOUT

    #[abi(embed_v0)]
    impl CoreImpl of ICore<ContractState> {
        // fn add_admin(ref self: ContractState, member_id: u256) {
        //     // let member_node = self.member.members.entry(member_id);
        // }
        fn initialize_disbursement_schedule(
            ref self: ContractState,
            schedule_type: u8,
            //schedule_id: felt252,
            start: u64, //timestamp
            end: u64,
            interval: u64,
        ) {
            self.disbursement._initialize(schedule_type, start, end, interval)
        }

        fn schedule_payout(ref self: ContractState) {
            let caller = get_caller_address();
            let members = self.member.get_members();
            let no_of_members = members.len();

            let org_info = self.organization.get_organization_details();
            let vault_address = org_info.vault_address;

            let vault_dispatcher = IVaultDispatcher { contract_address: vault_address };
            let total_bonus = vault_dispatcher.get_bonus_allocation();
            let total_funds = vault_dispatcher.get_balance();

            let current_schedule = self.disbursement.get_current_schedule();
            assert(current_schedule.status == ScheduleStatus::ACTIVE, 'Schedule not active');

            let now = get_block_timestamp();
            assert(now >= current_schedule.start_timestamp, 'Payout has not started');
            assert(now < current_schedule.end_timestamp, 'Payout period ended');

            // if let Option::Some(last_execution) = current_schedule.last_execution {
            //     assert(
            //         now >= last_execution + current_schedule.interval, 'Too soon to execute
            //         payout',
            //     );
            // }
            // let last_execution_ref = current_schedule.last_execution;
            // if last_execution_ref.is_some() {
            //     assert(now >= (last_execution_ref.unwrap() + current_schedule.interval), 'Too
            //     soon to payout');
            // }

            // let mut failed_disbursements = array![];

            // Everyone uses a base weight multiplier at the start, of 1
            let mut total_weight: u16 = 0;
            for i in 0..no_of_members {
                let current_member = *members.at(i);
                let current_member_role = MemberRoleIntoU16::into(current_member.role);
                total_weight += current_member_role;
            }
            let mut i = 0;
            while i < no_of_members {
                let current_member_response = *members.at(i);
                // let pseudo_current_member = Member {
                //     id: current_member_response.id,
                //     address: current_member_response.address,
                //     status: current_member_response.status,
                //     role: current_member_response.role,
                //     // base_pay: current_member_response.base_pay,
                // };
                let amount = self
                    .disbursement
                    .compute_renumeration(current_member_response, total_bonus, total_weight);
                let timestamp = get_block_timestamp();
                vault_dispatcher.pay_member(current_member_response.address, amount);

                // let unit_disbursement = UnitDisbursement {
                //     caller, timestamp, member: pseudo_current_member,
                // };
                // self.member.record_member_payment(current_member_response.id, amount, timestamp)
                i += 1;
            }

            self.disbursement.update_current_schedule_last_execution(now);
        }
    }
}
