/// # ICore
///
/// This trait defines the public interface for the central core contract of an organization.
/// It orchestrates high-level functions that involve multiple components, such as scheduling
/// and executing payroll for all members. This interface is designed to be implemented by a
/// contract that acts as the main hub, coordinating the actions of member management,
/// disbursement, and vault components.
#[starknet::interface]
pub trait ICore<T> {
    // fn add_admin(ref self: T, member_id: u256);

    /// # schedule_payout
    ///
    /// Triggers the disbursement process for all eligible members based on the active
    /// payment schedule. It calculates each member's share and initiates the payment
    /// from the organization's vault.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    fn schedule_payout(ref self: T);

    /// # initialize_disbursement_schedule
    ///
    /// Sets up a new disbursement schedule for the organization.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `schedule_type`: A numerical value representing the type of schedule (e.g., weekly,
    /// monthly).
    /// - `start`: The Unix timestamp when the schedule becomes active.
    /// - `end`: The Unix timestamp when the schedule expires.
    /// - `interval`: The duration in seconds between each payout execution.
    fn initialize_disbursement_schedule(
        ref self: T,
        schedule_type: u8, //schedule_id: felt252,
        start: u64, //timestamp
        end: u64,
        interval: u64,
    );
}
