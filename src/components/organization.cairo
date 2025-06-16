#[starknet::component]
pub mod OrganizationComponent {
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};
    // use crate::interfaces::icore::IConfig;
    use crate::interfaces::iorganization::IOrganization;
    // use crate::structs::member_structs::MemberTrait;
    use crate::structs::organization::{
        OrganizationConfig, OrganizationConfigNode, OrganizationInfo,
    };
    use super::super::member_manager::MemberManagerComponent;


    #[storage]
    pub struct Storage {
        pub deployer: ContractAddress,
        pub commitee: Map<ContractAddress, u16>, // address -> level of power
        pub config: OrganizationConfigNode, // refactor to OrganizationConfig
        pub org_info: OrganizationInfo,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {}

    #[embeddable_as(OrganizationManager)]
    pub impl Organization<
        TContractState,
        +HasComponent<TContractState>,
        +Drop<TContractState>,
        impl Member: MemberManagerComponent::HasComponent<TContractState>,
    > of IOrganization<ComponentState<TContractState>> {
        fn transfer_organization_claim(
            ref self: ComponentState<TContractState>, to: ContractAddress,
        ) {}
        fn adjust_committee(
            ref self: ComponentState<TContractState>,
            add: Array<ContractAddress>,
            subtract: Array<ContractAddress>,
        ) { // any one subtracted, power would be taken down to zero.
        }

        fn update_organization_config(
            ref self: ComponentState<TContractState>, config: OrganizationConfig,
        ) {}
        fn get_organization_details(self: @ComponentState<TContractState>) -> OrganizationInfo {
            self.org_info.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>,
        // +Drop<TContractState>,
    // impl Member: MemberManagerComponent::HasComponent<TContractState>,
    > of OrganizationInternalTrait<TContractState> {
        fn _init(
            ref self: ComponentState<TContractState>,
            owner: Option<ContractAddress>,
            name: ByteArray,
            ipfs_url: ByteArray,
            vault_address: ContractAddress,
            org_id: u256,
            // organization_info: OrganizationInfo,
            deployer: ContractAddress,
        ) {
            let caller = get_caller_address();
            let mut ascribed_owner = caller;
            if owner.is_some() {
                ascribed_owner = owner.unwrap();
            }
            let current_timestamp = get_block_timestamp();
            let organization_info = OrganizationInfo {
                org_id,
                name,
                deployer: caller,
                owner: ascribed_owner,
                ipfs_url,
                vault_address,
                created_at: current_timestamp,
            };
            self.org_info.write(organization_info);
            self.deployer.write(deployer);
        }
    }
}
