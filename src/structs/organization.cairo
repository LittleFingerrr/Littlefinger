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
#[allow(starknet::store_no_default_variant)]
#[derive(Copy, Drop, Serde, starknet::Store)]
pub enum ContractType {
    EMPLOYMEE_AGREEMENT,
    NON_DISCLOSURE_AGREEMENT,
    CONTRACTOR_AGREEMENT,
    EQUITY_AGREEMENT,
    EXIT_CONTRACT,
}

#[derive(Copy, Drop, Serde, Default, starknet::Store)]
pub enum ContractStatus {
    #[default]
    PROPOSED,
    ACTIVE,
    TERMINATED,
    REVOKED,
    SUSPENDED,
    EXPIRED,
}

// If third party for company_member is going to be added, it will be here
#[derive(Copy, Drop, Serde, Default, starknet::Store)]
pub enum ContractParties {
    #[default]
    COMPANY_MEMBER: u256, // member id
    COMPANY_COMPANY: ContractAddress, // address of fellow org
    ORG_ORG_THIRD_PARTY: (ContractAddress, ContractAddress),
}

#[derive(Copy, Drop, Serde, Default, starknet::Store)]
pub struct Contract {
    pub id: u256,
    pub hash: felt252,
    pub version: u64,
    pub signed_time: u64,
    pub contract_parties: ContractParties,
    pub status: ContractStatus,
    pub expiry_time: Option<u64>,
}

#[generate_trait]
impl ContractImpl of ContractTrait {
    fn default(ref self: Contract) -> Contract {
        let default_contract = Contract {
            id: 0,
            hash: 0,
            version: 0,
            signed_time: 0,
            contract_parties: ContractParties::COMPANY_MEMBER(0),
            status: ContractStatus::PROPOSED,
            expiry_time: Option::None,
        };

        default_contract
    }
}