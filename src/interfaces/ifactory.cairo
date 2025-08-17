use littlefinger::structs::member_structs::MemberInvite;
use starknet::{ClassHash, ContractAddress};

/// # IFactory
///
/// This trait defines the public interface for a factory contract. The factory is responsible
/// for deploying and managing entire organizations, which consist of a `Core` contract and a
/// corresponding `Vault` contract. It simplifies the creation process, maintains a registry
/// of all deployed instances, and facilitates cross-organization interactions like member
/// invitations and lookups.
#[starknet::interface]
pub trait IFactory<T> {
    // fn deploy_vault(
    //     ref self: T,
    //     // class_hash: felt252, //unwrap it into class has using into, and it will be removed
    //     once I declare the vault available_funds: u256,
    //     starting_bonus_allocation: u256,
    //     token: ContractAddress,
    //     salt: felt252,
    // ) -> ContractAddress;
    // // Initialize organization
    // // Initialize member
    // // If custom owner is not supplied at deployment, deployer is used as owner, and becomes the
    // first admin fn deploy_org_core(
    //     ref self: T,
    //     // class_hash: felt252,
    //     // Needed to initialize the organization component
    //     owner: Option<ContractAddress>,
    //     name: ByteArray,
    //     ipfs_url: ByteArray,
    //     vault_address: ContractAddress,
    //     // Needed to initialize the member component
    //     first_admin_fname: felt252,
    //     first_admin_lname: felt252,
    //     first_admin_alias: felt252,
    //     salt: felt252,
    // ) -> ContractAddress;

    /// # setup_org
    ///
    /// Deploys and configures a new organization, including its `Core` contract and `Vault`.
    /// This is the main entry point for creating a new, fully functional organization.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `token`: The `ContractAddress` of the ERC20 token the organization's vault will manage.
    /// - `salt`: A unique value (`felt252`) to ensure deterministic yet unique contract addresses.
    /// - `owner`: The `ContractAddress` of the user who will own the new organization.
    /// - `name`: The name of the organization.
    /// - `ipfs_url`: A URL (e.g., on IPFS) pointing to organization metadata.
    /// - `first_admin_fname`: First name of the initial administrator (the owner).
    /// - `first_admin_lname`: Last name of the initial administrator.
    /// - `first_admin_alias`: Alias of the initial administrator.
    /// - `organization_type`: A numerical identifier for the type of organization.
    ///
    /// ## Returns
    ///
    /// A tuple `(ContractAddress, ContractAddress)` containing the addresses of the newly
    /// deployed `Core` contract and `Vault` contract, respectively.
    fn setup_org(
        ref self: T,
        // class_hash: felt252, //unwrap it into class has using into, and it will be removed once I
        // declare the vault
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
    ) -> (ContractAddress, ContractAddress);

    /// # get_deployed_vaults
    ///
    /// Retrieves a list of all `Vault` contracts deployed by this factory.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// An `Array<ContractAddress>` of all deployed vault addresses.
    fn get_deployed_vaults(self: @T) -> Array<ContractAddress>;

    /// # get_deployed_org_cores
    ///
    /// Retrieves a list of all `Core` contracts deployed by this factory.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// An `Array<ContractAddress>` of all deployed core organization addresses.
    fn get_deployed_org_cores(self: @T) -> Array<ContractAddress>;

    /// # get_vault_org_pairs
    ///
    /// For a given owner, retrieves all associated pairs of (Core, Vault) contracts.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    /// - `caller`: The address of the owner.
    ///
    /// ## Returns
    ///
    /// An `Array<(ContractAddress, ContractAddress)>` of associated contract pairs.
    fn get_vault_org_pairs(
        self: @T, caller: ContractAddress,
    ) -> Array<(ContractAddress, ContractAddress)>;

    /// # get_member_orgs
    ///
    /// For a given user, retrieves all organizations they are a member of.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    /// - `caller`: The address of the member.
    ///
    /// ## Returns
    ///
    /// An `Array<ContractAddress>` of `Core` contracts the user is a member of.
    fn get_member_orgs(self: @T, caller: ContractAddress) -> Array<ContractAddress>;

    /// # update_vault_hash
    ///
    /// Updates the class hash for the `Vault` contract. New deployments will use this updated hash.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `vault_hash`: The new `ClassHash` for the vault contract.
    fn update_vault_hash(ref self: T, vault_hash: ClassHash);

    /// # update_core_hash
    ///
    /// Updates the class hash for the `Core` contract. New deployments will use this updated hash.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `core_hash`: The new `ClassHash` for the core contract.
    fn update_core_hash(ref self: T, core_hash: ClassHash);

    /// # update_member_of
    ///
    /// Records a user's membership in a specific organization.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `member`: The `ContractAddress` of the user who became a member.
    /// - `org_core`: The `ContractAddress` of the organization they joined.
    fn update_member_of(ref self: T, member: ContractAddress, org_core: ContractAddress);

    /// # create_invite
    ///
    /// Stores the details of an invitation sent from an organization to a user.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `invitee`: The `ContractAddress` of the user being invited.
    /// - `invite_details`: A `MemberInvite` struct containing the invitation details.
    /// - `core_org`: The `ContractAddress` of the inviting organization.
    fn create_invite(
        ref self: T,
        invitee: ContractAddress,
        invite_details: MemberInvite,
        core_org: ContractAddress,
    );

    /// # accpet_invite
    ///
    /// Marks an existing invitation as accepted in the factory's records.
    ///
    /// ## Parameters
    ///
    /// - `ref self: T`: The current state of the contract.
    /// - `invitee`: The `ContractAddress` of the user who accepted the invite.
    fn accpet_invite(ref self: T, invitee: ContractAddress);

    /// # get_invite_details
    ///
    /// Retrieves the stored details of an invitation for a specific user.
    ///
    /// ## Parameters
    ///
    /// - `self: @T`: A snapshot of the contract's state.
    /// - `invitee`: The `ContractAddress` of the user whose invitation is being queried.
    ///
    /// ## Returns
    ///
    /// A `MemberInvite` struct with the invitation details.
    fn get_invite_details(self: @T, invitee: ContractAddress) -> MemberInvite;
    // fn get_vault_org_pairs(self: @T) -> Array<(ContractAddress, ContractAddress)>;

    // in the future, you can upgrade a deployed org core from here
// fn initialize_upgrade(ref self: T, vaults: Array<ContractAddress>, cores:
// Array<ContractAddress>);
// this function would pick the updated class hash from the storage, if the class hash has been
// updated at present, it can only pick the latest...
// in the future, it can pick a specific class hash version
}
