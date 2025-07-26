#[starknet::contract]
pub mod MockDisbursement {
    use littlefinger::components::disbursement::DisbursementComponent;
    use starknet::ContractAddress;

    component!(path: DisbursementComponent, storage: disbursement, event: DisbursementEvent);

    pub impl DisbursementManagerImpl = DisbursementComponent::DisbursementManager<ContractState>;

    pub impl InternalImpl = DisbursementComponent::InternalImpl<ContractState>;

    // Implement the interface functions by delegating to the component
    #[abi(embed_v0)]
    impl DisbursementImpl of littlefinger::interfaces::idisbursement::IDisbursement<ContractState> {
        fn create_disbursement_schedule(
            ref self: ContractState, schedule_type: u8, start: u64, end: u64, interval: u64,
        ) {
            self.disbursement.create_disbursement_schedule(schedule_type, start, end, interval);
        }

        fn pause_disbursement(ref self: ContractState) {
            self.disbursement.pause_disbursement();
        }

        fn resume_schedule(ref self: ContractState) {
            self.disbursement.resume_schedule();
        }

        fn get_current_schedule(
            self: @ContractState,
        ) -> littlefinger::structs::disbursement_structs::DisbursementSchedule {
            self.disbursement.get_current_schedule()
        }

        fn get_disbursement_schedules(
            self: @ContractState,
        ) -> Array<littlefinger::structs::disbursement_structs::DisbursementSchedule> {
            self.disbursement.get_disbursement_schedules()
        }

        fn update_current_schedule_last_execution(ref self: ContractState, timestamp: u64) {
            self.disbursement.update_current_schedule_last_execution(timestamp);
        }

        fn set_current_schedule(ref self: ContractState, schedule_id: u64) {
            self.disbursement.set_current_schedule(schedule_id);
        }

        fn compute_renumeration(
            ref self: ContractState,
            member: littlefinger::structs::member_structs::MemberResponse,
            total_bonus_available: u256,
            total_members_weight: u16,
        ) -> u256 {
            self
                .disbursement
                .compute_renumeration(member, total_bonus_available, total_members_weight)
        }

        fn update_schedule_interval(ref self: ContractState, schedule_id: u64, new_interval: u64) {
            self.disbursement.update_schedule_interval(schedule_id, new_interval);
        }

        fn update_schedule_type(
            ref self: ContractState,
            schedule_id: u64,
            schedule_type: littlefinger::structs::disbursement_structs::ScheduleType,
        ) {
            self.disbursement.update_schedule_type(schedule_id, schedule_type);
        }

        fn get_last_disburse_time(self: @ContractState) -> u64 {
            self.disbursement.get_last_disburse_time()
        }

        fn get_next_disburse_time(self: @ContractState) -> u64 {
            self.disbursement.get_next_disburse_time()
        }
    }

    #[storage]
    pub struct Storage {
        #[substorage(v0)]
        pub disbursement: DisbursementComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        DisbursementEvent: DisbursementComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        // Initialize the disbursement component
        self.disbursement._init(owner);
    }
}
