use littlefinger::structs::member_structs::Member;
use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub struct DisbursementSchedule {
    pub schedule_id: u64,
    // is_active: bool,
    pub status: ScheduleStatus,
    pub schedule_type: ScheduleType,
    pub start_timestamp: u64,
    pub end_timestamp: u64,
    pub interval: u64,
    pub last_execution: Option<u64>,
}

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub struct Disbursement {
    caller: ContractAddress,
    timestamp: u64,
    total_disbursed: u256,
    no_of_recipients: u64,
    // disbursement_status: DisbursementStatus
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct UnitDisbursement {
    pub caller: ContractAddress,
    pub timestamp: u64,
    pub member: Member,
}

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub enum DisbursementStatus {
    #[default]
    SUCCESSFUL,
    FAILED,
}

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub enum ScheduleType {
    RECURRING, //1
    #[default]
    ONETIME //1
    // TODO:
// We have to come up with how to implement this conditional. Off the top of my head, it could
// be other people validating your work, meaning it should be for the more decentralized scheme
// CONDITIONAL,
}

#[derive(Copy, Drop, Serde, PartialEq, Debug, starknet::Store)]
pub enum ScheduleStatus {
    #[default]
    ACTIVE,
    PAUSED,
    DELETED,
}

