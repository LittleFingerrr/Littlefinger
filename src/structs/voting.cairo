use littlefinger::structs::disbursement_structs::{DisbursementSchedule, ScheduleStatus};
use littlefinger::structs::member_structs::{MemberInvite, MemberStatus};
use littlefinger::structs::organization::OrganizationType;
use starknet::ContractAddress;
use super::base::ContractAddressDefault;

#[derive(Drop, Clone, Serde, PartialEq, Default, starknet::Store)]
pub struct Poll {
    pub proposer: u256, // the proposer is a member with an id
    pub poll_id: u256,
    // pub name: ByteArray,
    // pub desc: ByteArray, // Let's stick to a streamlined structure instead of giving users
    // freedom
    pub reason: PollReason,
    pub up_votes: u256,
    pub down_votes: u256,
    pub status: PollStatus,
    pub created_at: u64,
}

#[derive(Copy, Drop, Serde, Default, PartialEq, starknet::Store)]
pub enum PollReason {
    #[default]
    ADDMEMBER: ADDMEMBER,
    UPDATEMEMBERBASEPAY: UPDATEMEMBERBASEPAY,
    CHANGEMEMBERSTATUS: CHANGEMEMBERSTATUS,
    SETCURRENTDISBURSEMENTSCHEDULE: SETCURRENTDISBURSEMENTSCHEDULE,
    CHANGESCHEDULESTATUS: CHANGESCHEDULESTATUS,
    CHANGEORGANIZATIONTYPE: CHANGEORGANIZATIONTYPE,
}

#[derive(Copy, Drop, PartialEq, Default, Serde, starknet::Store)]
pub struct ADDMEMBER {
    pub member: MemberInvite,
    pub member_address: ContractAddress,
}

#[derive(Copy, Drop, PartialEq, Serde, starknet::Store)]
pub struct UPDATEMEMBERBASEPAY {
    pub member_id: u256,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct CHANGEMEMBERSTATUS {
    pub member_id: u256,
    pub current_status: MemberStatus,
    pub proposed_status: MemberStatus,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct SETCURRENTDISBURSEMENTSCHEDULE {
    pub schedule_id: u64,
    pub previous_schedule: DisbursementSchedule,
    pub new_schedule: DisbursementSchedule,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct CHANGESCHEDULESTATUS {
    pub schedule_id: u64,
    pub previous_status: ScheduleStatus,
    pub new_status: ScheduleStatus,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub struct CHANGEORGANIZATIONTYPE {
    pub current_config: OrganizationType,
    pub new_config: OrganizationType,
}

#[generate_trait]
pub impl PollImpl of PollTrait {
    fn resolve(ref self: Poll) -> bool {
        assert(self.up_votes + self.down_votes >= DEFAULT_THRESHOLD, 'COULD NOT RESOLVE');
        let mut status = false;
        if self.up_votes > self.down_votes {
            status = true;
        }
        self.status = PollStatus::FINISHED(status);

        status
    }

    fn stop(ref self: Poll) {
        self.status = PollStatus::FINISHED(false);
    }
}

#[derive(Drop, Copy, Default, Serde, PartialEq, starknet::Store)]
pub enum PollStatus {
    // Pending,
    #[default]
    ACTIVE,
    FINISHED: bool,
}

#[derive(Drop, starknet::Event)]
pub struct PollCreated {
    #[key]
    pub id: u256,
    #[key]
    pub proposer: ContractAddress,
    pub reason: PollReason,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct PollStopped {
    #[key]
    pub id: u256,
    #[key]
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct ThresholdChanged {
    pub previous_threshold: u256,
    pub new_threshold: u256,
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct Voted {
    #[key]
    pub id: u256,
    #[key]
    pub voter: ContractAddress, //using member_id
    pub timestamp: u64,
}

#[derive(Drop, starknet::Event)]
pub struct PollResolved {
    #[key]
    pub id: u256,
    pub outcome: bool,
    pub timestamp: u64,
}

pub const DEFAULT_THRESHOLD: u256 = 10;
pub type Power = u16;

#[derive(Drop, Serde, Copy, Default)]
pub struct VotingConfig {
    private: bool,
    threshold: u256,
    weighted: bool,
    weighted_with: ContractAddress // weight with this token, else, use rank.
}

// For the default
#[starknet::storage_node]
pub struct VotingConfigNode {
    private: bool,
    threshold: u256,
    weighted: bool,
}

// In the case the deployer wishes to use a default value, and maybe
// change the value later on
pub fn default_voting_config_init() -> VotingConfig {
    // for now
    Default::default()
}
