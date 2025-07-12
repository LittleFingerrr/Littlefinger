#[starknet::component]
pub mod DisbursementComponent {
    use littlefinger::interfaces::idisbursement::IDisbursement;
    use littlefinger::structs::disbursement_structs::{
        DisbursementSchedule, ScheduleStatus, ScheduleType, UnitDisbursement,
    };
    use littlefinger::structs::member_structs::{Member, MemberResponse};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    use super::super::organization;
    use super::super::dao_controller;
    use super::super::organization::OrganizationComponent::{OrganizationManager, Organization};
    use super::super::dao_controller::VotingComponent::{VotingImpl, Voting, VotingTrait};
    use crate::structs::organization::OrganizationType;
    use crate::structs::dao_controller::{PollReason, CHANGESCHEDULESTATUS, SETCURRENTDISBURSEMENTSCHEDULE};


    #[storage]
    pub struct Storage {
        authorized_callers: Map<ContractAddress, bool>,
        owner: ContractAddress,
        disbursement_schedules: Map<u64, DisbursementSchedule>,
        current_schedule: DisbursementSchedule,
        failed_disbursements: Map<
            u256, UnitDisbursement,
        >, //map disbursement id to a failed disbursement
        schedules_count: u64,
    }

    #[embeddable_as(DisbursementManager)]
    pub impl DisbursementImpl<
        TContractState, +HasComponent<TContractState>,//, +Drop<TContractState>,
        //impl Member: MemberManagerComponent::HasComponent<TContractState>,
        impl Organization: OrganizationManager::HasComponent<TContractState>,
        impl Voting: dao_controller::VotingComponent::HasComponent<TContractState>,
    > of IDisbursement<ComponentState<TContractState>> {
        fn create_disbursement_schedule(
            ref self: ComponentState<TContractState>,
            schedule_type: u8,
            start: u64, //timestamp
            end: u64,
            interval: u64,
            member_id: u256, // member id for proposal
        ) {
            let org = get_dep_component!(@self, Organization);
            let org_info = org.get_organization_details();
            match org_info.organization_type {
                OrganizationType::CENTRALIZED => {
                    // Execute directly
                    self._assert_caller();
                    let schedule_count = self.schedules_count.read();
                    let schedule_id = schedule_count + 1;
                    let mut processed_schedule_type = ScheduleType::ONETIME;
                    if schedule_type == 0 {
                        processed_schedule_type = ScheduleType::RECURRING;
                    }
                    let disbursement_schedule = DisbursementSchedule {
                        schedule_id,
                        status: ScheduleStatus::ACTIVE,
                        schedule_type: processed_schedule_type,
                        start_timestamp: start,
                        end_timestamp: end,
                        interval,
                        last_execution: Option::None,
                    };
                    self.schedules_count.write(schedule_count + 1);
                    self.disbursement_schedules.entry(schedule_count + 1).write(disbursement_schedule);
                },
                OrganizationType::DECENTRALIZED => {
                    // Create a proposal for setting the schedule
                    let mut voting_mut = get_dep_component_mut!(ref self, Voting);
                    let previous_schedule = self.current_schedule.read();
                    let new_schedule = DisbursementSchedule {
                        schedule_id: self.schedules_count.read() + 1,
                        status: ScheduleStatus::ACTIVE,
                        schedule_type: if schedule_type == 0 { ScheduleType::RECURRING } else { ScheduleType::ONETIME },
                        start_timestamp: start,
                        end_timestamp: end,
                        interval,
                        last_execution: Option::None,
                    };
                    let reason = PollReason::SETCURRENTDISBURSEMENTSCHEDULE(
                        SETCURRENTDISBURSEMENTSCHEDULE {
                            schedule_id: new_schedule.schedule_id,
                            previous_schedule,
                            new_schedule,
                        }
                    );
                    let poll_id = voting_mut.create_poll(member_id, reason);
                },
            }
        }

        fn pause_disbursement_schedule(ref self: ComponentState<TContractState>, schedule_id: u64, member_id: u256) {
            let org = get_dep_component!(@self, Organization);
            let org_info = org.get_organization_details();
            match org_info.organization_type {
                OrganizationType::CENTRALIZED => {
                    self._assert_caller();
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    assert(
                        disbursement_schedule.status == ScheduleStatus::ACTIVE,
                        'Schedule Paused or Deleted',
                    );
                    disbursement_schedule.status = ScheduleStatus::PAUSED;
                    self.disbursement_schedules.entry(schedule_id).write(disbursement_schedule);
                },
                OrganizationType::DECENTRALIZED => {
                    let mut voting_mut = get_dep_component_mut!(ref self, Voting);
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    let reason = PollReason::CHANGESCHEDULESTATUS(
                        CHANGESCHEDULESTATUS {
                            schedule_id,
                            previous_status: disbursement_schedule.status,
                            new_status: ScheduleStatus::PAUSED,
                        }
                    );
                    let poll_id = voting_mut.create_poll(member_id, reason);
                },
            }
        }

        fn resume_schedule(ref self: ComponentState<TContractState>, schedule_id: u64, member_id: u256) {
            let org = get_dep_component!(@self, Organization);
            let org_info = org.get_organization_details();
            match org_info.organization_type {
                OrganizationType::CENTRALIZED => {
                    self._assert_caller();
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    assert(
                        disbursement_schedule.status == ScheduleStatus::PAUSED,
                        'Schedule Active or Deleted',
                    );
                    disbursement_schedule.status = ScheduleStatus::ACTIVE;
                    self.disbursement_schedules.entry(schedule_id).write(disbursement_schedule);
                },
                OrganizationType::DECENTRALIZED => {
                    let mut voting_mut = get_dep_component_mut!(ref self, Voting);
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    let reason = PollReason::CHANGESCHEDULESTATUS(
                        CHANGESCHEDULESTATUS {
                            schedule_id,
                            previous_status: disbursement_schedule.status,
                            new_status: ScheduleStatus::ACTIVE,
                        }
                    );
                    let poll_id = voting_mut.create_poll(member_id, reason);
                },
            }
        }

        fn delete_schedule(ref self: ComponentState<TContractState>, schedule_id: u64, member_id: u256) {
            let org = get_dep_component!(@self, Organization);
            let org_info = org.get_organization_details();
            match org_info.organization_type {
                OrganizationType::CENTRALIZED => {
                    self._assert_caller();
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    assert(
                        disbursement_schedule.status != ScheduleStatus::DELETED, 'Scedule Already Deleted',
                    );
                    disbursement_schedule.status = ScheduleStatus::DELETED;
                    self.disbursement_schedules.entry(schedule_id).write(disbursement_schedule);
                },
                OrganizationType::DECENTRALIZED => {
                    let mut voting_mut = get_dep_component_mut!(ref self, Voting);
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    let reason = PollReason::CHANGESCHEDULESTATUS(
                        CHANGESCHEDULESTATUS {
                            schedule_id,
                            previous_status: disbursement_schedule.status,
                            new_status: ScheduleStatus::DELETED,
                        }
                    );
                    let poll_id = voting_mut.create_poll(member_id, reason);
                },
            }
        }

        fn add_failed_disbursement(
            ref self: ComponentState<TContractState>,
            member: Member,
            disbursement_id: u256,
            timestamp: u64,
            caller: ContractAddress,
        ) -> bool {
            let disbursement = UnitDisbursement { caller, timestamp, member };
            self.failed_disbursements.entry(disbursement_id).write(disbursement);
            true
        }

        fn update_current_schedule_last_execution(
            ref self: ComponentState<TContractState>, timestamp: u64,
        ) {
            self._assert_caller();
            let mut current_schedule = self.current_schedule.read();
            current_schedule.last_execution = Option::Some(timestamp);
            self.current_schedule.write(current_schedule);
        }

        fn set_current_schedule(ref self: ComponentState<TContractState>, schedule_id: u64, member_id: u256) {
            let org = get_dep_component!(@self, Organization);
            let org_info = org.get_organization_details();
            match org_info.organization_type {
                OrganizationType::CENTRALIZED => {
                    self._assert_caller();
                    let schedule = self.disbursement_schedules.entry(schedule_id).read();
                    assert(schedule.status == ScheduleStatus::ACTIVE, 'Schedule Not Active');
                    self.current_schedule.write(schedule);
                },
                OrganizationType::DECENTRALIZED => {
                    let mut voting_mut = get_dep_component_mut!(ref self, Voting);
                    let previous_schedule = self.current_schedule.read();
                    let new_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    let reason = PollReason::SETCURRENTDISBURSEMENTSCHEDULE(
                        SETCURRENTDISBURSEMENTSCHEDULE {
                            schedule_id,
                            previous_schedule,
                            new_schedule,
                        }
                    );
                    let poll_id = voting_mut.create_poll(member_id, reason);
                },
            }
        }

        fn get_current_schedule(self: @ComponentState<TContractState>) -> DisbursementSchedule {
            let disbursement_schedule = self.current_schedule.read();
            disbursement_schedule
        }

        fn get_disbursement_schedules(
            self: @ComponentState<TContractState>,
        ) -> Array<DisbursementSchedule> {
            let mut disbursement_schedules_array: Array<DisbursementSchedule> = array![];

            for i in 1..(self.schedules_count.read() + 1) {
                let current_schedule = self.disbursement_schedules.entry(i).read();
                if current_schedule.schedule_id != 0 { // Add validation
                    disbursement_schedules_array.append(current_schedule);
                }
            }

            disbursement_schedules_array
        }

        fn compute_renumeration(
            ref self: ComponentState<TContractState>,
            member: MemberResponse,
            total_bonus_available: u256,
            total_members_weight: u16,
        ) -> u256 {
            let member_base_pay = member.base_pay;
            let bonus_proportion = member.role.into() / total_members_weight;
            let bonus_pay: u256 = bonus_proportion.into() * total_bonus_available;

            let renumeration = member_base_pay + bonus_pay;
            renumeration
        }

        fn update_schedule_interval(
            ref self: ComponentState<TContractState>, schedule_id: u64, new_interval: u64, member_id: u256,
        ) {
            let org = get_dep_component!(@self, Organization);
            let org_info = org.get_organization_details();
            match org_info.organization_type {
                OrganizationType::CENTRALIZED => {
                    self._assert_caller();
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    assert(disbursement_schedule.status != ScheduleStatus::DELETED, 'Schedule Deleted');
                    
                    disbursement_schedule.interval = new_interval;
                    
                    self.disbursement_schedules.entry(schedule_id).write(disbursement_schedule);
                },
                OrganizationType::DECENTRALIZED => {
                    let mut voting_mut = get_dep_component_mut!(ref self, Voting);
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    let reason = PollReason::CHANGESCHEDULESTATUS(
                        CHANGESCHEDULESTATUS {
                            schedule_id,
                            previous_status: disbursement_schedule.status,
                            new_status: disbursement_schedule.status, // interval change, status unchanged
                        }
                    );
                    let poll_id = voting_mut.create_poll(member_id, reason);
                },
            }
        }

        fn update_schedule_type(
            ref self: ComponentState<TContractState>, schedule_id: u64, schedule_type: ScheduleType, member_id: u256,
        ) {
            let org = get_dep_component!(@self, Organization);
            let org_info = org.get_organization_details();
            match org_info.organization_type {
                OrganizationType::CENTRALIZED => {
                    self._assert_caller();
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    assert(disbursement_schedule.status != ScheduleStatus::DELETED, 'Schedule Deleted');

                    disbursement_schedule.schedule_type = schedule_type;

                    self.disbursement_schedules.entry(schedule_id).write(disbursement_schedule);
                },
                OrganizationType::DECENTRALIZED => {
                    let mut voting_mut = get_dep_component_mut!(ref self, Voting);
                    let mut disbursement_schedule = self.disbursement_schedules.entry(schedule_id).read();
                    let reason = PollReason::CHANGESCHEDULESTATUS(
                        CHANGESCHEDULESTATUS {
                            schedule_id,
                            previous_status: disbursement_schedule.status,
                            new_status: disbursement_schedule.status, // type change, status unchanged
                        }
                    );
                    let mut poll_id = voting_mut.create_poll(member_id, reason);
                },
            }
        }

        fn retry_failed_disbursement(ref self: ComponentState<TContractState>, schedule_id: u64) {
            self._assert_caller();
        }

        fn get_pending_failed_disbursements(self: @ComponentState<TContractState>) {}

        fn get_last_disburse_time(self: @ComponentState<TContractState>) -> u64 {
            let mut last_disburse_time = 0;
            if let Option::Some(mut last_execution) = self.current_schedule.read().last_execution {
                last_disburse_time = last_execution
            }
            last_disburse_time
        }

        fn get_next_disburse_time(self: @ComponentState<TContractState>) -> u64 {
            let current_schedule = self.current_schedule.read();
            let now = get_block_timestamp();
            assert(now < current_schedule.end_timestamp, 'No more disbursement');
            let mut next_disburse_time = 0;
            if let Option::Some(mut last_execution) = self.current_schedule.read().last_execution {
                next_disburse_time = last_execution + current_schedule.interval;
            } else {
                next_disburse_time = current_schedule.start_timestamp;
            }

            next_disburse_time
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        fn _add_authorized_caller(ref self: ComponentState<TContractState>, user: ContractAddress) {
            self._assert_caller();
            self.authorized_callers.entry(user).write(true);
        }

        fn _assert_caller(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(self.authorized_callers.entry(caller).read(), 'Caller Not Permitted');
        }

        fn _initialize(
            ref self: ComponentState<TContractState>,
            schedule_type: u8,
            start: u64, //timestamp
            end: u64,
            interval: u64,
        ) {
            self._assert_caller();
            let schedule_count = self.schedules_count.read();
            let mut processed_schedule_type = ScheduleType::ONETIME;
            if schedule_type == 0 {
                processed_schedule_type = ScheduleType::RECURRING;
            }
            let disbursement_schedule = DisbursementSchedule {
                schedule_id: schedule_count + 1,
                status: ScheduleStatus::ACTIVE,
                schedule_type: processed_schedule_type,
                start_timestamp: start,
                end_timestamp: end,
                interval,
                last_execution: Option::None,
            };
            self.disbursement_schedules.entry(schedule_count + 1).write(disbursement_schedule);
            self.schedules_count.write(schedule_count + 1);
            self.current_schedule.write(disbursement_schedule);
        }

        fn _init(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self.owner.write(owner);
            self.authorized_callers.entry(owner).write(true);
            self.schedules_count.write(0);
        }
    }
}
