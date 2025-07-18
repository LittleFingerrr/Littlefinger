#[starknet::component]
pub mod DisbursementComponent {
    use littlefinger::interfaces::idisbursement::IDisbursement;
    use littlefinger::structs::disbursement_structs::{
        DisbursementSchedule, ScheduleStatus, ScheduleType, UnitDisbursement,
    };
    use littlefinger::structs::member_structs::{MemberResponse};
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    #[storage]
    pub struct Storage {
        authorized_callers: Map<ContractAddress, bool>,
        owner: ContractAddress,
        previous_schedules: Map<u64, DisbursementSchedule>, // only one active schedule at a time
        current_schedule: DisbursementSchedule,
        failed_disbursements: Map<
            u256, UnitDisbursement,
        >, //map disbursement id to a failed disbursement
        schedules_count: u64,
    }

    #[embeddable_as(DisbursementManager)]
    pub impl DisbursementImpl<
        TContractState, +HasComponent<TContractState> //, +Drop<TContractState>,
        //impl Member: MemberManagerComponent::HasComponent<TContractState>,
    > of IDisbursement<ComponentState<TContractState>> {
        fn create_disbursement_schedule(
            ref self: ComponentState<TContractState>,
            schedule_type: u8,
            start: u64, //timestamp
            end: u64,
            interval: u64,
        ) {
            self._assert_caller();
            let schedule_count = self.schedules_count.read();
            let current_schedule = self.previous_schedules.entry(schedule_count).read();
            let schedule_id = schedule_count + 1;
            let mut processed_schedule_type = ScheduleType::ONETIME;
            if schedule_type == 0 {
                processed_schedule_type = ScheduleType::RECURRING;
            }
            let new_disbursement_schedule = DisbursementSchedule {
                schedule_id,
                status: ScheduleStatus::ACTIVE,
                schedule_type: processed_schedule_type,
                start_timestamp: start,
                end_timestamp: end,
                interval,
                last_execution: Option::None,
            };
            self._delete_schedule(schedule_count);
            self.previous_schedules.entry(schedule_count).write(current_schedule);
            self.schedules_count.write(schedule_count + 1);
            self.current_schedule.write(new_disbursement_schedule);
        }

        fn pause_disbursement(ref self: ComponentState<TContractState>) {
            self._assert_caller();
            let mut disbursement_schedule = self.current_schedule.read();
            assert(
                disbursement_schedule.status == ScheduleStatus::ACTIVE,
                'Schedule Paused or Deleted',
            );
            disbursement_schedule.status = ScheduleStatus::PAUSED;
            self.current_schedule.write(disbursement_schedule);
        }

        fn resume_schedule(ref self: ComponentState<TContractState>) {
            self._assert_caller();
            let mut disbursement_schedule = self.current_schedule.read();
            assert(
                disbursement_schedule.status == ScheduleStatus::PAUSED,
                'Schedule Active or Deleted',
            );
            disbursement_schedule.status = ScheduleStatus::ACTIVE;
            self.current_schedule.write(disbursement_schedule);
        }

        // fn add_failed_disbursement(
        //     ref self: ComponentState<TContractState>,
        //     member: Member,
        //     disbursement_id: u256,
        //     timestamp: u64,
        //     caller: ContractAddress,
        // ) -> bool {
        //     let disbursement = UnitDisbursement { caller, timestamp, member };
        //     self.failed_disbursements.entry(disbursement_id).write(disbursement);
        //     true
        // }

        fn update_current_schedule_last_execution(
            ref self: ComponentState<TContractState>, timestamp: u64,
        ) {
            self._assert_caller();
            let mut current_schedule = self.current_schedule.read();
            current_schedule.last_execution = Option::Some(timestamp);
            self.current_schedule.write(current_schedule);
        }

        fn set_current_schedule(ref self: ComponentState<TContractState>, schedule_id: u64) {
            self._assert_caller();
            let schedule = self.previous_schedules.entry(schedule_id).read();
            assert(schedule.status == ScheduleStatus::ACTIVE, 'Schedule Not Active');
            self.current_schedule.write(schedule);
        }

        fn get_current_schedule(self: @ComponentState<TContractState>) -> DisbursementSchedule {
            let disbursement_schedule = self.current_schedule.read();
            assert(disbursement_schedule != Default::default(), 'No schedule set');
            disbursement_schedule
        }

        fn get_disbursement_schedules(
            self: @ComponentState<TContractState>,
        ) -> Array<DisbursementSchedule> {
            let mut disbursement_schedules_array: Array<DisbursementSchedule> = array![];

            for i in 1..(self.schedules_count.read() + 1) {
                let current_schedule = self.previous_schedules.entry(i).read();
                if current_schedule.schedule_id != 0 && current_schedule.status != ScheduleStatus::DELETED { // Add validation
                    disbursement_schedules_array.append(current_schedule);
                }
            }
            disbursement_schedules_array.append(self.current_schedule.read());

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
            ref self: ComponentState<TContractState>, schedule_id: u64, new_interval: u64,
        ) {
            self._assert_caller();
            let mut disbursement_schedule = self.previous_schedules.entry(schedule_id).read();
            assert(disbursement_schedule.status != ScheduleStatus::DELETED, 'Schedule Deleted');

            disbursement_schedule.interval = new_interval;

            self.previous_schedules.entry(schedule_id).write(disbursement_schedule);
        }

        fn update_schedule_type(
            ref self: ComponentState<TContractState>, schedule_id: u64, schedule_type: ScheduleType,
        ) {
            self._assert_caller();
            let mut disbursement_schedule = self.previous_schedules.entry(schedule_id).read();
            assert(disbursement_schedule.status != ScheduleStatus::DELETED, 'Schedule Deleted');

            disbursement_schedule.schedule_type = schedule_type;

            self.previous_schedules.entry(schedule_id).write(disbursement_schedule);
        }

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

        fn _delete_schedule(ref self: ComponentState<TContractState>, schedule_id: u64) {
            self._assert_caller();
            let mut disbursement_schedule = self.current_schedule.read();
            assert(
                disbursement_schedule.status != ScheduleStatus::DELETED, 'Scedule Already Deleted',
            );
            disbursement_schedule.status = ScheduleStatus::DELETED;
            self.current_schedule.write(disbursement_schedule);
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
            self.previous_schedules.entry(schedule_count + 1).write(disbursement_schedule);
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
