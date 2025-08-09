/// ## A Starknet component for managing payroll and disbursement schedules.
///
/// This component handles the logic for:
/// - Creating, pausing, and resuming payment schedules.
/// - Storing a history of past schedules.
/// - Calculating individual member payments based on base pay and a weighted share of bonuses.
/// - Tracking the timing of disbursement cycles.
///
/// It is intended to be integrated into a `Core` contract to manage an organization's payroll
/// system.
#[starknet::component]
pub mod DisbursementComponent {
    use littlefinger::interfaces::idisbursement::IDisbursement;
    use littlefinger::structs::disbursement_structs::{
        DisbursementSchedule, ScheduleStatus, ScheduleType, UnitDisbursement,
    };
    use littlefinger::structs::member_structs::MemberResponse;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    /// Defines the storage layout for the `DisbursementComponent`.
    #[storage]
    pub struct Storage {
        /// Maps an address to a boolean indicating if it is authorized to call privileged
        /// functions.
        authorized_callers: Map<ContractAddress, bool>,
        /// The address of the component's owner.
        owner: ContractAddress,
        /// Maps a schedule ID to an archived `DisbursementSchedule`.
        previous_schedules: Map<u64, DisbursementSchedule>, // only one active schedule at a time
        /// The currently active disbursement schedule for the organization.
        current_schedule: DisbursementSchedule,
        /// Maps a disbursement ID to a `UnitDisbursement` struct for tracking failed payments.
        failed_disbursements: Map<
            u256, UnitDisbursement,
        >, //map disbursement id to a failed disbursement
        /// A counter for the total number of schedules created.
        schedules_count: u64,
    }

    /// # DisbursementManager
    ///
    /// Public-facing implementation of the `IDisbursement` interface.
    #[embeddable_as(DisbursementManager)]
    pub impl DisbursementImpl<
        TContractState, +HasComponent<TContractState> //, +Drop<TContractState>,
        //impl Member: MemberManagerComponent::HasComponent<TContractState>,
    > of IDisbursement<ComponentState<TContractState>> {
        /// Creates and activates a new disbursement schedule.
        ///
        /// ### Parameters
        /// - `schedule_type`: Type of schedule (0: Recurring, 1: One-Time).
        /// - `start`: Unix timestamp for the schedule's start time.
        /// - `end`: Unix timestamp for the schedule's end time.
        /// - `interval`: Payout interval in seconds.
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
                last_execution: 0,
            };
            self._delete_schedule(schedule_count);
            self.previous_schedules.entry(schedule_count).write(current_schedule);
            self.schedules_count.write(schedule_count + 1);
            self.current_schedule.write(new_disbursement_schedule);
        }

        /// Pauses the currently active disbursement schedule.
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

        /// Resumes a paused disbursement schedule.
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

        /// Updates the `last_execution` timestamp for the active schedule.
        ///
        /// ### Parameters
        /// - `timestamp`: The Unix timestamp of the last successful execution.
        fn update_current_schedule_last_execution(
            ref self: ComponentState<TContractState>, timestamp: u64,
        ) {
            self._assert_caller();
            let mut current_schedule = self.current_schedule.read();
            current_schedule.last_execution = timestamp;
            self.current_schedule.write(current_schedule);
        }

        /// Sets an archived schedule as the new active one.
        ///
        /// ### Parameters
        /// - `schedule_id`: The ID of the schedule to activate.
        fn set_current_schedule(ref self: ComponentState<TContractState>, schedule_id: u64) {
            self._assert_caller();
            let schedule = self.previous_schedules.entry(schedule_id).read();
            assert(schedule.status == ScheduleStatus::ACTIVE, 'Schedule Not Active');
            self.current_schedule.write(schedule);
        }

        /// Returns the details of the currently active schedule.
        ///
        /// ### Returns
        /// - `DisbursementSchedule`: A struct containing the active schedule's details.
        fn get_current_schedule(self: @ComponentState<TContractState>) -> DisbursementSchedule {
            let disbursement_schedule = self.current_schedule.read();
            assert(disbursement_schedule != Default::default(), 'No schedule set');
            disbursement_schedule
        }

        /// Returns a list of all historical and current schedules.
        ///
        /// ### Returns
        /// - `Array<DisbursementSchedule>`: An array of all non-deleted schedules.
        fn get_disbursement_schedules(
            self: @ComponentState<TContractState>,
        ) -> Array<DisbursementSchedule> {
            let mut disbursement_schedules_array: Array<DisbursementSchedule> = array![];

            for i in 1..(self.schedules_count.read() + 1) {
                let current_schedule = self.previous_schedules.entry(i).read();
                if current_schedule.schedule_id != 0
                    && current_schedule.status != ScheduleStatus::DELETED
                    && current_schedule != Default::default() { // Add validation
                    disbursement_schedules_array.append(current_schedule);
                }
            }
            disbursement_schedules_array.append(self.current_schedule.read());

            disbursement_schedules_array
        }

        /// Calculates the total payment for a member for one cycle.
        ///
        /// ### Parameters
        /// - `member`: The details of the member.
        /// - `total_bonus_available`: The total bonus pool for the cycle.
        /// - `total_members_weight`: The sum of role weights for all members.
        ///
        /// ### Returns
        /// - `u256`: The calculated total remuneration.
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

        /// Updates the payout interval for an existing schedule.
        ///
        /// ### Parameters
        /// - `schedule_id`: The ID of the schedule to modify.
        /// - `new_interval`: The new interval in seconds.
        fn update_schedule_interval(
            ref self: ComponentState<TContractState>, schedule_id: u64, new_interval: u64,
        ) {
            self._assert_caller();
            let mut disbursement_schedule = self.previous_schedules.entry(schedule_id).read();
            assert(disbursement_schedule.status != ScheduleStatus::DELETED, 'Schedule Deleted');

            disbursement_schedule.interval = new_interval;

            self.previous_schedules.entry(schedule_id).write(disbursement_schedule);
        }

        /// Updates the type (Recurring/One-Time) for an existing schedule.
        ///
        /// ### Parameters
        /// - `schedule_id`: The ID of the schedule to modify.
        /// - `schedule_type`: The new schedule type.
        fn update_schedule_type(
            ref self: ComponentState<TContractState>, schedule_id: u64, schedule_type: ScheduleType,
        ) {
            self._assert_caller();
            let mut disbursement_schedule = self.previous_schedules.entry(schedule_id).read();
            assert(disbursement_schedule.status != ScheduleStatus::DELETED, 'Schedule Deleted');

            disbursement_schedule.schedule_type = schedule_type;

            self.previous_schedules.entry(schedule_id).write(disbursement_schedule);
        }

        /// Returns the timestamp of the last payout for the active schedule.
        ///
        /// ### Returns
        /// - `u64`: The Unix timestamp of the last execution.
        fn get_last_disburse_time(self: @ComponentState<TContractState>) -> u64 {
            self.current_schedule.read().last_execution
        }

        /// Calculates the timestamp for the next expected payout.
        ///
        /// ### Returns
        /// - `u64`: The Unix timestamp of the next disbursement.
        fn get_next_disburse_time(self: @ComponentState<TContractState>) -> u64 {
            let current_schedule = self.current_schedule.read();
            let now = get_block_timestamp();
            assert(now < current_schedule.end_timestamp, 'No more disbursement');
            let last_execution = current_schedule.last_execution;
            if last_execution == 0 {
                current_schedule.start_timestamp
            } else {
                last_execution + current_schedule.interval
            }
        }
    }

    /// # InternalImpl
    ///
    /// Internal functions for initialization and privileged operations.
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of InternalTrait<TContractState> {
        /// Grants another address permission to call privileged functions.
        ///
        /// ### Parameters
        /// - `user`: The address to authorize.
        fn _add_authorized_caller(ref self: ComponentState<TContractState>, user: ContractAddress) {
            self._assert_caller();
            self.authorized_callers.entry(user).write(true);
        }

        /// Asserts that the function caller is authorized. Reverts if not.
        fn _assert_caller(ref self: ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(
                self.authorized_callers.entry(caller).read() || caller == self.owner.read(),
                'Caller Not Permitted',
            );
        }

        /// Marks a schedule as deleted.
        ///
        /// ### Parameters
        /// - `schedule_id`: The ID of the schedule to delete.
        fn _delete_schedule(ref self: ComponentState<TContractState>, schedule_id: u64) {
            self._assert_caller();
            let mut disbursement_schedule = self.current_schedule.read();
            assert(
                disbursement_schedule.status != ScheduleStatus::DELETED, 'Scedule Already Deleted',
            );
            disbursement_schedule.status = ScheduleStatus::DELETED;
            self.current_schedule.write(disbursement_schedule);
        }

        /// Initializes the first disbursement schedule for the component.
        ///
        /// ### Parameters
        /// - `schedule_type`: Type of schedule (0: Recurring, 1: One-Time).
        /// - `start`: Unix timestamp for the schedule's start time.
        /// - `end`: Unix timestamp for the schedule's end time.
        /// - `interval`: Payout interval in seconds.
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
                last_execution: 0,
            };
            self.previous_schedules.entry(schedule_count + 1).write(disbursement_schedule);
            self.schedules_count.write(schedule_count + 1);
            self.current_schedule.write(disbursement_schedule);
        }

        /// Initializes the component's basic state, setting the owner.
        ///
        /// ### Parameters
        /// - `owner`: The address of the owner.
        fn _init(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self.owner.write(owner);
            self.authorized_callers.entry(owner).write(true);
            self.schedules_count.write(0);
        }
    }
}
