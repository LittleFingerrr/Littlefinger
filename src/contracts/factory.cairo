#[starknet::contract]
pub mod Factory {
    use littlefinger::interfaces::ifactory::IFactory;
    use littlefinger::structs::member_structs::MemberInvite;
    // use littlefinger::structs::organization::{OrganizationInfo};
    use littlefinger::interfaces::ivault::{IVaultDispatcher, IVaultDispatcherTrait};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::class_hash::ClassHash;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::syscalls::deploy_syscall;
    use starknet::{
        ContractAddress, SyscallResultTrait, get_block_timestamp, get_caller_address,
        get_contract_address,
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[storage]
    pub struct Storage {
        deployed_orgs: Map<u256, ContractAddress>, //org_id should be the same with vault_id
        deployed_vaults: Map<u256, ContractAddress>,
        vault_org_pairs: Map<ContractAddress, Vec<(ContractAddress, ContractAddress)>>,
        member_of: Map<ContractAddress, Vec<ContractAddress>>,
        org_invites: Map<ContractAddress, (ContractAddress, MemberInvite)>,
        orgs_count: u64,
        vaults_count: u64, //Open to the possibility of an organization somehow having more than one vault
        vault_class_hash: ClassHash,
        org_core_class_hash: ClassHash,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // I actually
    // const ORG_CORE_CLASS_HASH: felt252 =
    // 0x012a413fb811681055cf9fa3eccddb7e20e6bc08a476442da2743fb660c45945;
    // const VAULT_CLASS_HASH: felt252 =
    // 0x017195343b9bf99c3933a7a998bcba8244d14a95ec35d26afbbfa6bbe4cded8d;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        VaultDeployed: VaultDeployed,
        OrgCoreDeployed: OrgCoreDeployed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct VaultDeployed {
        address: ContractAddress,
        deployed_at: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct OrgCoreDeployed {
        address: ContractAddress,
        deployed_at: u64,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        org_core_class_hash: felt252,
        vault_class_hash: felt252,
    ) {
        self.orgs_count.write(0);
        self.vaults_count.write(0);
        let vault_class_hash: ClassHash = vault_class_hash.try_into().unwrap();
        let org_core_class_hash: ClassHash = org_core_class_hash.try_into().unwrap();
        self.vault_class_hash.write(vault_class_hash);
        self.org_core_class_hash.write(org_core_class_hash);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // This might be upgraded from the factory
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[abi(embed_v0)]
    pub impl FactoryImpl of IFactory<ContractState> {
        fn setup_org(
            ref self: ContractState,
            token: ContractAddress,
            salt: felt252,
            // class_hash: felt252,
            // Needed to initialize the organization component
            owner: ContractAddress,
            name: ByteArray,
            ipfs_url: ByteArray,
            // vault_address: ContractAddress,
            // Needed to initialize the member component
            first_admin_fname: felt252,
            first_admin_lname: felt252,
            first_admin_alias: felt252,
            organization_type: u8,
            // salt: felt252,
        ) -> (ContractAddress, ContractAddress) {
            // let deployer = get_caller_address();
            let vault_address = self.deploy_vault(token, salt, owner);
            let factory = get_contract_address();
            let org_core_address = self
                .deploy_org_core(
                    owner,
                    name,
                    ipfs_url,
                    vault_address,
                    first_admin_fname,
                    first_admin_lname,
                    first_admin_alias,
                    salt + 1,
                    organization_type,
                    factory,
                );
            self.vault_org_pairs.entry(owner).push((org_core_address, vault_address));
            let vault_dispatcher = IVaultDispatcher { contract_address: vault_address };
            vault_dispatcher.allow_org_core_address(org_core_address);

            (org_core_address, vault_address)
        }

        fn get_deployed_vaults(self: @ContractState) -> Array<ContractAddress> {
            let mut vaults = array![];
            let vaults_count: u256 = (self.vaults_count.read()).try_into().unwrap();

            for i in 1..(vaults_count + 1) {
                let current_vault = self.deployed_vaults.entry(i).read();
                vaults.append(current_vault);
            }
            vaults
        }
        fn get_deployed_org_cores(self: @ContractState) -> Array<ContractAddress> {
            let mut orgs = array![];
            let orgs_count: u256 = (self.orgs_count.read()).try_into().unwrap();

            for i in 1..(orgs_count + 1) {
                let current_org_core = self.deployed_orgs.entry(i).read();
                orgs.append(current_org_core);
            }
            orgs
        }

        fn update_vault_hash(ref self: ContractState, vault_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.vault_class_hash.write(vault_hash);
        }

        fn update_core_hash(ref self: ContractState, core_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.org_core_class_hash.write(core_hash);
        }

        fn get_vault_org_pairs(
            self: @ContractState, caller: ContractAddress,
        ) -> Array<(ContractAddress, ContractAddress)> {
            let mut vault_org_pairs = ArrayTrait::new();
            let storage_vault_org_pairs = self.vault_org_pairs.entry(caller);
            let mut i: u64 = 0;

            while i != storage_vault_org_pairs.len() {
                vault_org_pairs.append(storage_vault_org_pairs.at(i).read());

                i += 1;
            }

            vault_org_pairs
        }

        fn get_member_orgs(
            self: @ContractState, caller: ContractAddress,
        ) -> Array<ContractAddress> {
            let mut orgs = ArrayTrait::new();
            let storage_orgs = self.member_of.entry(caller);
            let mut i: u64 = 0;

            while i != storage_orgs.len() {
                orgs.append(storage_orgs.at(i).read());

                i += 1;
            }

            orgs
        }

        fn update_member_of(
            ref self: ContractState, member: ContractAddress, org_core: ContractAddress,
        ) {
            self.member_of.entry(member).push(org_core);
        }

        fn create_invite(ref self: ContractState, invitee: ContractAddress, invite_details: MemberInvite, core_org: ContractAddress) {
            self.org_invites.entry(invitee).write((core_org, invite_details));
        }
    }

    #[generate_trait]
    pub impl InternalImpl of InternalTrait {
        fn deploy_vault(
            ref self: ContractState, // class_hash: felt252, //unwrap it into class has using into, and it will be removed
            // once I declare the vault
            token: ContractAddress,
            salt: felt252,
            owner: ContractAddress,
        ) -> ContractAddress {
            let vault_count = self.vaults_count.read();
            let vault_id: u256 = vault_count.into();
            let mut constructor_calldata = array![];
            token.serialize(ref constructor_calldata);
            // available_funds.serialize(ref constructor_calldata);
            // starting_bonus_allocation.serialize(ref constructor_calldata);
            owner.serialize(ref constructor_calldata);

            // Deploy the Vault
            let processed_class_hash: ClassHash = self.vault_class_hash.read();
            let result = deploy_syscall(
                processed_class_hash,
                salt,
                constructor_calldata.span(),
                false //Have to recheck if this is the right value, and why
            );
            let (vault_address, _) = result.unwrap_syscall();

            // Update state of storage
            self.vaults_count.write(self.vaults_count.read() + 1);
            self.deployed_vaults.entry(vault_id).write(vault_address);

            self.emit(VaultDeployed { address: vault_address, deployed_at: get_block_timestamp() });

            vault_address
        }

        // Initialize organization
        // Initialize member
        // If custom owner is not supplied at deployment, deployer is used as owner, and becomes the
        // first admin
        fn deploy_org_core(
            ref self: ContractState,
            // class_hash: felt252,
            // Needed to initialize the organization component
            owner: ContractAddress,
            name: ByteArray,
            ipfs_url: ByteArray,
            vault_address: ContractAddress,
            // Needed to initialize the member component
            first_admin_fname: felt252,
            first_admin_lname: felt252,
            first_admin_alias: felt252,
            salt: felt252,
            organization_type: u8,
            factory: ContractAddress,
        ) -> ContractAddress {
            let deployer = get_caller_address();
            let org_count = self.orgs_count.read();
            let org_id: u256 = org_count.try_into().unwrap();
            // let mut viable_owner = deployer;
            // if owner.is_some() {
            //     viable_owner = owner.unwrap()
            // }
            // let current_time = get_block_timestamp();
            // let organization_info = OrganizationInfo {
            //     org_id,
            // let felt_org_id: felt252 = org_id.into();
            // let felt_name: felt252 = name.into();
            //     name,
            //     deployer,
            //     owner: viable_owner,
            //     ipfs_url,
            //     vault_address,
            //     created_at: current_time
            // };
            let mut constructor_calldata = array![];
            org_id.serialize(ref constructor_calldata);
            name.serialize(ref constructor_calldata);
            owner.serialize(ref constructor_calldata);
            ipfs_url.serialize(ref constructor_calldata);
            vault_address.serialize(ref constructor_calldata);
            first_admin_fname.serialize(ref constructor_calldata);
            first_admin_lname.serialize(ref constructor_calldata);
            first_admin_alias.serialize(ref constructor_calldata);
            deployer.serialize(ref constructor_calldata);
            organization_type.serialize(ref constructor_calldata);
            factory.serialize(ref constructor_calldata);

            let processed_class_hash: ClassHash = self.org_core_class_hash.read();

            // Deploy contract
            let (org_address, _) = deploy_syscall(
                processed_class_hash, salt, constructor_calldata.span(), false,
            )
                .unwrap_syscall();

            self.deployed_orgs.entry(org_id).write(org_address);
            self.orgs_count.write(self.orgs_count.read() + 1);

            self.emit(OrgCoreDeployed { address: org_address, deployed_at: get_block_timestamp() });

            org_address
        }
    }
}
