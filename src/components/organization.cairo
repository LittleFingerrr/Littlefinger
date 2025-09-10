/// ## A Starknet component responsible for managing the core details of an organization.
///
/// This component handles:
/// - Storing fundamental organization information (name, ID, owner, etc.).
/// - Managing a committee of privileged addresses.
/// - Handling organization-level configuration.
/// - Ownership transfers.
#[starknet::component]
pub mod OrganizationComponent {
    use starknet::storage::{Map, StoragePathEntry,StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    // use crate::interfaces::icore::IConfig;
    use crate::interfaces::iorganization::IOrganization;
    // use crate::structs::member_structs::MemberTrait;
    use crate::structs::organization::{
        Contract, ContractParties, ContractStatus, ContractType,OrganizationConfig, OrganizationConfigNode, OrganizationInfo, OrganizationType,
    };
    use super::super::member_manager::MemberManagerComponent;

    /// Defines the storage layout for the `OrganizationComponent`.
    #[storage]
    pub struct Storage {
        /// The address of the contract deployer.
        pub deployer: ContractAddress,
        /// Maps a committee member's address to their power level or rank.
        pub commitee: Map<ContractAddress, u16>, // address -> level of power
        /// The configuration node for the organization.
        pub config: OrganizationConfigNode, // refactor to OrganizationConfig
        /// Struct containing the core information of the organization.
        pub org_info: OrganizationInfo,
        /// Maps an id to a contract
        pub contracts: Map<u256, Contract>,
        /// Contract counter
        pub contract_counter: u64,
    }

    /// Events emitted by the `OrganizationComponent`.
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    /// # OrganizationManager
    ///
    /// Public-facing implementation of the `IOrganization` interface.
    #[embeddable_as(OrganizationManager)]
    pub impl Organization<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Member: MemberManagerComponent::HasComponent<TContractState>,
    > of IOrganization<ComponentState<TContractState>> {
        /// Transfers the claim of the organization to a new address.
        ///
        /// ### Note
        /// This function is not yet implemented.
        ///
        /// ### Parameters
        /// - `to`: The address of the new owner.
        fn transfer_organization_claim(
            ref self: ComponentState<TContractState>, to: ContractAddress,
        ) {}

        /// Adjusts the organization's committee by adding or removing members.
        ///
        /// ### Note
        /// This function is not yet implemented. Any subtracted member would have their power level
        /// set to zero.
        ///
        /// ### Parameters
        /// - `add`: An array of addresses to add to the committee.
        /// - `subtract`: An array of addresses to remove from the committee.
        fn adjust_committee(
            ref self: ComponentState<TContractState>,
            add: Array<ContractAddress>,
            subtract: Array<ContractAddress>,
        ) { // any one subtracted, power would be taken down to zero.
            

        }

        /// Updates the organization's configuration.
        ///
        /// ### Note
        /// This function is not yet implemented.
        ///
        /// ### Parameters
        /// - `config`: The new organization configuration.
        fn update_organization_config(
            ref self: ComponentState<TContractState>, config: OrganizationConfig,
        ) {}

        /// Retrieves the core details of the organization.
        ///
        /// ### Returns
        /// - `OrganizationInfo`: A struct containing the organization's details.
        fn get_organization_details(self: @ComponentState<TContractState>) -> OrganizationInfo {
            self.org_info.read()
        }
         /// Creates an employee contract, to be given at hiring, or updated during employment
        /// Show to employee at hiring
        fn create_company_to_member_contract(
            ref self: ComponentState<TContractState>,
            contract_type: ContractType,
            member_id: u256,
            ipfs_hash: felt252,
            expiry: Option<u64>,
        ) {
            let member_component = get_dep_component!(@self, Member);
            let caller = get_caller_address();
            let is_admin = member_component.admin_ca.entry(caller).read();
            assert(is_admin, 'Caller Not Permitted');

            let contract = Contract {
                id: self.contract_counter.read().into(),
                hash: ipfs_hash,
                version: 1,
                signed_time: 0,
                contract_parties: ContractParties::COMPANY_MEMBER(member_id),
                status: ContractStatus::PROPOSED,
                expiry_time: Option::None,
            };

            self.contracts.entry(self.contract_counter.read().into()).write(contract);
            self.contract_counter.write(self.contract_counter.read() + 1);
        }

        /// Creates a contract between two companies using Littlefinger. Advanced features
        /// Show to both companies
        fn create_company_to_partner_contract(
            ref self: ComponentState<TContractState>,
            contract_type: ContractType,
            partner_address: ContractAddress,
            ipfs_hash: felt252,
            expiry: Option<u64>,
        ) {
            let member_component = get_dep_component!(@self, Member);
            let caller = get_caller_address();
            let is_admin = member_component.admin_ca.entry(caller).read();
            assert(is_admin, 'Caller Not Permitted');

            let contract = Contract {
                id: self.contract_counter.read().into(),
                hash: ipfs_hash,
                version: 1,
                signed_time: 0,
                contract_parties: ContractParties::COMPANY_COMPANY(partner_address),
                status: ContractStatus::PROPOSED,
                expiry_time: Option::None,
            };

            self.contracts.entry(self.contract_counter.read().into()).write(contract);
            self.contract_counter.write(self.contract_counter.read() + 1);
        }

        /// Used to accept a contract, by whoever is on the other side of the contract (recipeint)
        /// Will implement Starknet message signing soon
        fn sign_contract(
            ref self: ComponentState<TContractState>, contract_id: u256, signature: Array<felt252>,
        ) {
            // ecdsa::check_ecdsa_signature()
            let mut contract = self.contracts.entry(contract_id).read();
            contract.status = ContractStatus::ACTIVE;
            contract.signed_time = get_block_timestamp();

            self.contracts.entry(contract_id).write(contract);
        }

        /// Updates a contract ipfs hash and version
        /// Show to employee at hiring
        fn update_contract(
            ref self: ComponentState<TContractState>,
            contract_id: u256,
            new_ipfs_hash: felt252,
            expiry: Option<u64>,
        ) {
            let mut contract = self.contracts.entry(contract_id).read();
            contract.hash = new_ipfs_hash;

            if expiry.is_some() {
                contract.expiry_time = Option::Some(expiry.unwrap());
            }
            contract.version += 1;

            self.contracts.entry(contract_id).write(contract);
        }

        /// Termminates a contract, can be used by employees or fellow companies
        /// Mutual agreement between company and employee
        fn terminate_contract(
            ref self: ComponentState<TContractState>, contract_id: u256, signature: Array<felt252>,
        ) {
            let mut contract = self.contracts.entry(contract_id).read();
            contract.status = ContractStatus::TERMINATED;
        }

        /// Used to get a contract ipfs hash for access purpose
        /// ### Returns 
        /// - Contract: all the important info of the contract suitable for storage onchain.
        /// - The rest goes to IPFS
        fn get_contract(self: @ComponentState<TContractState>, contract_id: u256) -> Contract {
            self.contracts.entry(contract_id).read()
        }
    }
    

    /// # InternalImpl
    ///
    /// Internal functions for initialization and privileged operations.
    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
        // +Drop<TContractState>,
    // impl Member: MemberManagerComponent::HasComponent<TContractState>,
    > of OrganizationInternalTrait<TContractState> {
        /// Initializes the organization component with its essential data.
        ///
        /// ### Parameters
        /// - `owner`: An optional address for the organization's owner. If `None`, the caller
        /// becomes the owner.
        /// - `name`: The name of the organization.
        /// - `ipfs_url`: A URL pointing to more detailed organization metadata (e.g., on IPFS).
        /// - `vault_address`: The address of the organization's treasury or vault contract.
        /// - `org_id`: A unique identifier for the organization.
        /// - `deployer`: The address of the account or contract that deployed this component.
        /// - `organization_type`: A numeric code for the organization type (0 for Centralized, 1
        /// for Decentralized).
        fn _init(
            ref self: ComponentState<TContractState>,
            owner: Option<ContractAddress>,
            name: ByteArray,
            ipfs_url: ByteArray,
            vault_address: ContractAddress,
            org_id: u256,
            // organization_info: OrganizationInfo,
            deployer: ContractAddress,
            organization_type: u8,
        ) {
            let caller = get_caller_address();
            let mut ascribed_owner = caller;
            if owner.is_some() {
                ascribed_owner = owner.unwrap();
            }
            let current_timestamp = get_block_timestamp();

            let mut processed_org_type = OrganizationType::CENTRALIZED;

            match organization_type {
                1 => processed_org_type = OrganizationType::DECENTRALIZED,
                0 | _ => processed_org_type = OrganizationType::CENTRALIZED,
            }

            let organization_info = OrganizationInfo {
                org_id,
                name,
                deployer: caller,
                owner: ascribed_owner,
                ipfs_url,
                vault_address,
                created_at: current_timestamp,
                organization_type: processed_org_type,
            };
            self.org_info.write(organization_info);
            self.deployer.write(deployer);
        }
    }
}
