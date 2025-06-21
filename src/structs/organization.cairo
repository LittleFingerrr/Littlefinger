use starknet::ContractAddress;
use starknet::storage::Vec;
use crate::structs::base::ContractAddressDefault;

#[derive(Drop, Serde, Clone, PartialEq, starknet::Store)]
pub struct OrganizationInfo {
    pub org_id: u256,
    pub name: ByteArray,
    pub deployer: ContractAddress,
    pub owner: ContractAddress,
    // pub additional_data: Array<felt252>,
    pub ipfs_url: ByteArray,
    pub vault_address: ContractAddress,
    pub created_at: u64,
    pub organization_type: OrganizationType,
}

#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
pub enum OrganizationType {
    #[default]
    CENTRALIZED,
    DECENTRALIZED,
}


#[derive(Drop, Copy, Serde, PartialEq)]
pub struct OwnerInit {
    pub address: ContractAddress,
    pub fname: felt252,
    pub lastname: felt252,
}

#[derive(Drop, Serde, PartialEq)]
pub struct OrganizationConfig {
    pub name: Option<ByteArray>,
    pub admins: Array<ContractAddress>,
}

#[starknet::storage_node]
pub struct OrganizationConfigNode {
    pub additional_data: Vec<felt252>,
}
