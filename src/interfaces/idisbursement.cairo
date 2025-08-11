use littlefinger::structs::disbursement_structs::{DisbursementSchedule, ScheduleType};
use littlefinger::structs::member_structs::MemberResponse;

// TODO: The component should store failed disbursements, and everytime it disburses, after writing
// to the storage make it retry

/// # IDisbursement
///
/// This trait defines the public interface for a disbursement component. It outlines the
/// core functionalities for managing payment schedules for an organization, including their
/// creation, modification, and lifecycle management (pausing, resuming). It also specifies
/// how to calculate member remuneration based on their role and available bonuses. This interface
/// is designed to be implemented by a Starknet component that handles all payroll and
/// disbursement logic.
#[starknet::interface]
pub trait IDisbursement<T> {
    // disbursement schedule handling

    /// # create_disbursement_schedule
    ///
    /// Creates a new disbursement schedule for the organization.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `schedule_type`: A numerical value representing the schedule type (0: Recurring, 1:
    /// One-Time).
    /// - `start`: The Unix timestamp when the schedule becomes active.
    /// - `end`: The Unix timestamp when the schedule expires.
    /// - `interval`: The duration in seconds between each payout execution.
    fn create_disbursement_schedule(
        ref self: T,
        schedule_type: u8, //schedule_id: felt252,
        start: u64, //timestamp
        end: u64,
        interval: u64,
    );

    /// # pause_disbursement
    ///
    /// Temporarily pauses the currently active disbursement schedule.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    fn pause_disbursement(ref self: T);

    /// # resume_schedule
    ///
    /// Resumes a previously paused disbursement schedule.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    fn resume_schedule(ref self: T);
    // fn delete_schedule(ref self: T,);

    /// # get_current_schedule
    ///
    /// Retrieves the details of the currently active disbursement schedule.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// A `DisbursementSchedule` struct with the active schedule's details.
    fn get_current_schedule(self: @T) -> DisbursementSchedule;

    /// # get_disbursement_schedules
    ///
    /// Retrieves a list of all non-deleted disbursement schedules, including the active one.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// An `Array<DisbursementSchedule>` containing all relevant schedules.
    fn get_disbursement_schedules(self: @T) -> Array<DisbursementSchedule>;

    // fn retry_failed_disbursement(ref self: T, schedule_id: u64);
    // fn get_pending_failed_disbursements(self: @T);
    // fn add_failed_disbursement(
    //     ref self: T, member: Member, disbursement_id: u256, timestamp: u64, caller:
    //     ContractAddress,
    // ) -> bool;

    /// # update_current_schedule_last_execution
    ///
    /// Updates the last execution timestamp of the active schedule.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `timestamp`: The Unix timestamp of the last execution.
    fn update_current_schedule_last_execution(ref self: T, timestamp: u64);

    /// # set_current_schedule
    ///
    /// Sets a previously created schedule from the archives as the new active schedule.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `schedule_id`: The ID of the schedule to make active.
    fn set_current_schedule(ref self: T, schedule_id: u64);

    // Total members' weight is calculated by adding the weight of all members.
    // It can be a storage variable in the member module to make it easier to handle, concerning gas
    // for loop transactions

    /// # compute_renumeration
    ///
    /// Calculates a single member's total pay for a cycle.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `member`: The `MemberResponse` struct of the member.
    /// - `total_bonus_available`: The total amount in the bonus pool for the cycle.
    /// - `total_members_weight`: The sum of the role weights of all members.
    ///
    /// ## Returns
    ///
    /// The total remuneration amount for the member as a `u256`.
    fn compute_renumeration(
        ref self: T, member: MemberResponse, total_bonus_available: u256, total_members_weight: u16,
        // total_funds_available: u256,
    ) -> u256;

    // fn disburse(ref self: T, recipients: Array<Member>, token: ContractAddress);

    /// # update_schedule_interval
    ///
    /// Modifies the payment interval of a specific, existing schedule.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `schedule_id`: The ID of the schedule to update.
    /// - `new_interval`: The new interval duration in seconds.
    fn update_schedule_interval(ref self: T, schedule_id: u64, new_interval: u64);

    /// # update_schedule_type
    ///
    /// Modifies the type of a specific, existing schedule.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `schedule_id`: The ID of the schedule to update.
    /// - `schedule_type`: The new `ScheduleType` enum.
    fn update_schedule_type(ref self: T, schedule_id: u64, schedule_type: ScheduleType);

    /// # get_last_disburse_time
    ///
    /// Retrieves the timestamp of the last successful disbursement for the active schedule.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The Unix timestamp of the last execution as a `u64`.
    fn get_last_disburse_time(self: @T) -> u64;

    /// # get_next_disburse_time
    ///
    /// Calculates and returns the timestamp for the next scheduled disbursement.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The Unix timestamp of the next expected execution as a `u64`.
    fn get_next_disburse_time(self: @T) -> u64;
}
