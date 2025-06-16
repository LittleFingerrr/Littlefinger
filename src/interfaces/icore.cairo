#[starknet::interface]
pub trait ICore<T> {
    // fn add_admin(ref self: T, member_id: u256);
    fn schedule_payout(ref self: T);
    fn initialize_disbursement_schedule(
        ref self: T,
        schedule_type: u8, //schedule_id: felt252,
        start: u64, //timestamp
        end: u64,
        interval: u64,
    );
}
