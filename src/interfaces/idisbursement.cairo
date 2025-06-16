use littlefinger::structs::disbursement_structs::{DisbursementSchedule, ScheduleType};
use littlefinger::structs::member_structs::{Member, MemberResponse};
use starknet::ContractAddress;

// TODO: The component should store failed disbursements, and everytime it disburses, after writing
// to the storage make it retry

#[starknet::interface]
pub trait IDisbursement<T> {
    // disbursement schedule handling
    fn create_disbursement_schedule(
        ref self: T,
        schedule_type: u8, //schedule_id: felt252,
        start: u64, //timestamp
        end: u64,
        interval: u64,
    );
    fn pause_disbursement_schedule(ref self: T, schedule_id: u64);
    fn resume_schedule(ref self: T, schedule_id: u64);
    fn delete_schedule(ref self: T, schedule_id: u64);
    fn get_current_schedule(self: @T) -> DisbursementSchedule;
    fn get_disbursement_schedules(self: @T) -> Array<DisbursementSchedule>;

    fn retry_failed_disbursement(ref self: T, schedule_id: u64);
    fn get_pending_failed_disbursements(self: @T);
    fn add_failed_disbursement(
        ref self: T, member: Member, disbursement_id: u256, timestamp: u64, caller: ContractAddress,
    ) -> bool;
    fn update_current_schedule_last_execution(ref self: T, timestamp: u64);
    fn set_current_schedule(ref self: T, schedule_id: u64);

    // Total members' weight is calculated by adding the weight of all members.
    // It can be a storage variable in the member module to make it easier to handle, concerning gas
    // for loop transactions
    fn compute_renumeration(
        ref self: T, member: MemberResponse, total_bonus_available: u256, total_members_weight: u16,
        // total_funds_available: u256,
    ) -> u256;

    // fn disburse(ref self: T, recipients: Array<Member>, token: ContractAddress);
    fn update_schedule_interval(ref self: T, schedule_id: u64, new_interval: u64);
    fn update_schedule_type(ref self: T, schedule_id: u64, schedule_type: ScheduleType);
    fn get_last_disburse_time(self: @T) -> u64;
    fn get_next_disburse_time(self: @T) -> u64;
}
