use littlefinger::interfaces::icore::{ICoreDispatcher, ICoreDispatcherTrait};
use littlefinger::interfaces::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
use littlefinger::interfaces::imember_manager::{IMemberManagerDispatcher, IMemberManagerDispatcherTrait};
use littlefinger::interfaces::ivault::{IVaultDispatcher, IVaultDispatcherTrait};
use littlefinger::interfaces::idisbursement::{IDisbursementDispatcher, IDisbursementDispatcherTrait};
use littlefinger::structs::disbursement_structs::{ScheduleStatus, ScheduleType};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address, start_cheat_block_timestamp, stop_cheat_block_timestamp,
};
#[feature("deprecated-starknet-consts")]
use starknet::{ContractAddress, contract_address_const};


// Mock ERC20 token
#[starknet::interface]
trait IMockERC20<TContractState> {
    fn transfer(ref self: TContractState, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, amount: u256,
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn mint(ref self: TContractState, to: ContractAddress, amount: u256);
}


#[starknet::contract]
mod MockERC20 {
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address};


    #[storage]
    struct Storage {
        balances: Map<ContractAddress, u256>,
        allowances: Map<(ContractAddress, ContractAddress), u256>,
    }


    #[abi(embed_v0)]
    impl MockERC20Impl of super::IMockERC20<ContractState> {
        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            let caller_balance = self.balances.read(caller);
            assert(caller_balance >= amount, 'Insufficient balance');


            self.balances.write(caller, caller_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);
            true
        }


        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256,
        ) -> bool {
            let caller = get_caller_address();
            let allowance = self.allowances.read((from, caller));
            let from_balance = self.balances.read(from);


            assert(allowance >= amount, 'Insufficient allowance');
            assert(from_balance >= amount, 'Insufficient balance');


            self.allowances.write((from, caller), allowance - amount);
            self.balances.write(from, from_balance - amount);
            let to_balance = self.balances.read(to);
            self.balances.write(to, to_balance + amount);
            true
        }


        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.allowances.write((caller, spender), amount);
            true
        }


        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.read(account)
        }


        fn mint(ref self: ContractState, to: ContractAddress, amount: u256) {
            let current_balance = self.balances.read(to);
            self.balances.write(to, current_balance + amount);
        }
    }
}


// Helper functions for test addresses
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}


fn admin() -> ContractAddress {
    contract_address_const::<'admin'>()
}


fn employee1() -> ContractAddress {
    contract_address_const::<'employee1'>()
}


fn employee2() -> ContractAddress {
    contract_address_const::<'employee2'>()
}


fn contractor1() -> ContractAddress {
    contract_address_const::<'contractor1'>()
}


// Helper function to generate member addresses for test_schedule_payout_large_member_set
fn get_member_address(index: u32) -> ContractAddress {
    match index {
        0 => contract_address_const::<'member1'>(),
        1 => contract_address_const::<'member2'>(),
        2 => contract_address_const::<'member3'>(),
        3 => contract_address_const::<'member4'>(),
        4 => contract_address_const::<'member5'>(),
        5 => contract_address_const::<'member6'>(),
        6 => contract_address_const::<'member7'>(),
        7 => contract_address_const::<'member8'>(),
        8 => contract_address_const::<'member9'>(),
        9 => contract_address_const::<'member10'>(),
        _ => contract_address_const::<0>(), // Fallback, should not be reached
    }
}


fn deploy_mock_erc20() -> (IMockERC20Dispatcher, ContractAddress) {
    let contract = declare("MockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IMockERC20Dispatcher { contract_address };


    // Mint tokens for testing
    dispatcher.mint(owner(), 10000000000000000000000); 
    dispatcher.mint(admin(), 5000000000000000000000); 
    dispatcher.mint(employee1(), 1000000000000000000000); 
    dispatcher.mint(employee2(), 1000000000000000000000); 
    dispatcher.mint(contractor1(), 1000000000000000000000); 


    (dispatcher, contract_address)
}


fn setup_full_organization() -> (
    ICoreDispatcher,
    ContractAddress,
    IVaultDispatcher,
    ContractAddress,
    IMockERC20Dispatcher,
    ContractAddress,
    ContractAddress
) {
    let (token_dispatcher, token_address) = deploy_mock_erc20();


    let factory_contract = declare("Factory").unwrap().contract_class();
    let core_class_hash = declare("Core").unwrap().contract_class().class_hash;
    let vault_class_hash = declare("Vault").unwrap().contract_class().class_hash;


    let mut factory_calldata: Array<felt252> = array![owner().into()];
    core_class_hash.serialize(ref factory_calldata);
    vault_class_hash.serialize(ref factory_calldata);


    let (factory_address, _) = factory_contract.deploy(@factory_calldata).unwrap();
    let factory_dispatcher = IFactoryDispatcher { contract_address: factory_address };

    let owner = owner();

    let (core_address, vault_address) = factory_dispatcher
        .setup_org(
            token: token_address,
            salt: 'test_salt',
            owner: owner,
            name: "Test Organization",
            ipfs_url: "test_ipfs_url",
            first_admin_fname: 'Admin',
            first_admin_lname: 'User',
            first_admin_alias: 'admin',
            organization_type: 0,
        );


    let core_dispatcher = ICoreDispatcher { contract_address: core_address };
    let vault_dispatcher = IVaultDispatcher { contract_address: vault_address };


    // Setup token approvals
    start_cheat_caller_address(token_address, owner);
    token_dispatcher.approve(vault_address, 10000000000000000000000);
    stop_cheat_caller_address(token_address);


    start_cheat_caller_address(token_address, admin());
    token_dispatcher.approve(vault_address, 5000000000000000000000);
    stop_cheat_caller_address(token_address);


    // Fund the vault
    start_cheat_caller_address(vault_address, owner);
    vault_dispatcher.deposit_funds(5000000000000000000000, owner); 
    vault_dispatcher.add_to_bonus_allocation(1000000000000000000000, owner); 
    stop_cheat_caller_address(vault_address);


    (core_dispatcher, core_address, vault_dispatcher, vault_address, token_dispatcher, token_address, owner)
}


fn setup_organization_no_bonus() -> (
    ICoreDispatcher,
    ContractAddress,
    IVaultDispatcher,
    ContractAddress,
    IMockERC20Dispatcher,
    ContractAddress,
) {
    let (token_dispatcher, token_address) = deploy_mock_erc20();


    let factory_contract = declare("Factory").unwrap().contract_class();
    let core_class_hash = declare("Core").unwrap().contract_class().class_hash;
    let vault_class_hash = declare("Vault").unwrap().contract_class().class_hash;


    let mut factory_calldata: Array<felt252> = array![owner().into()];
    core_class_hash.serialize(ref factory_calldata);
    vault_class_hash.serialize(ref factory_calldata);


    let (factory_address, _) = factory_contract.deploy(@factory_calldata).unwrap();
    let factory_dispatcher = IFactoryDispatcher { contract_address: factory_address };


    let (core_address, vault_address) = factory_dispatcher
        .setup_org(
            token: token_address,
            salt: 'test_salt',
            owner: owner(),
            name: "Test Organization",
            ipfs_url: "test_ipfs_url",
            first_admin_fname: 'Admin',
            first_admin_lname: 'User',
            first_admin_alias: 'admin',
            organization_type: 0,
        );


    let core_dispatcher = ICoreDispatcher { contract_address: core_address };
    let vault_dispatcher = IVaultDispatcher { contract_address: vault_address };


    // Setup token approvals
    start_cheat_caller_address(token_address, owner());
    token_dispatcher.approve(vault_address, 10000000000000000000000);
    stop_cheat_caller_address(token_address);


    start_cheat_caller_address(token_address, admin());
    token_dispatcher.approve(vault_address, 5000000000000000000000);
    stop_cheat_caller_address(token_address);


    // Fund the vault without bonus allocation
    start_cheat_caller_address(vault_address, owner());
    vault_dispatcher.deposit_funds(5000000000000000000000, owner()); // 5,000 tokens
    // Skip add_to_bonus_allocation to keep bonus at 0
    stop_cheat_caller_address(vault_address);


    (core_dispatcher, core_address, vault_dispatcher, vault_address, token_dispatcher, token_address)
}


fn add_test_members(core_dispatcher: ICoreDispatcher, core_address: ContractAddress) {
    let member_dispatcher = IMemberManagerDispatcher { contract_address: core_address };


    // Add employees
    start_cheat_caller_address(core_address, owner());
    member_dispatcher.invite_member(1, employee1(), 1000000000000000000000); 
    member_dispatcher.invite_member(1, employee2(), 800000000000000000000); 
    member_dispatcher.invite_member(0, contractor1(), 500000000000000000000); 
    stop_cheat_caller_address(core_address);


    // Accept invitations
    start_cheat_caller_address(core_address, employee1());
    member_dispatcher.accept_invite('John', 'Doe', 'johndoe');
    stop_cheat_caller_address(core_address);


    start_cheat_caller_address(core_address, employee2());
    member_dispatcher.accept_invite('Jane', 'Smith', 'janesmith');
    stop_cheat_caller_address(core_address);


    start_cheat_caller_address(core_address, contractor1());
    member_dispatcher.accept_invite('Bob', 'Wilson', 'bobwilson');
    stop_cheat_caller_address(core_address);
}


// Test initialize_disbursement_schedule
#[test]
fn test_initialize_disbursement_schedule_success() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400; 


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval); 
    stop_cheat_caller_address(core_address);


    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    let current_schedule = disbursement_dispatcher.get_current_schedule();
    
    assert(current_schedule.status == ScheduleStatus::ACTIVE, 'Schedule active');
    assert(current_schedule.schedule_type == ScheduleType::RECURRING, 'Should be recurring');
    assert(current_schedule.start_timestamp == start_time, 'Wrong start time');
    assert(current_schedule.end_timestamp == end_time, 'Wrong end time');
    assert(current_schedule.interval == interval, 'Wrong interval');
}


#[test]
fn test_initialize_disbursement_schedule_onetime() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 0; 


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.initialize_disbursement_schedule(1, start_time, end_time, interval); 
    stop_cheat_caller_address(core_address);


    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    let current_schedule = disbursement_dispatcher.get_current_schedule();
    
    assert(current_schedule.schedule_type == ScheduleType::ONETIME, 'Should be one-time');
}


// Test schedule_payout
#[test]
#[should_panic(expected: 'Payout has not started')]
fn test_schedule_payout_before_start_time() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);


    let start_time = 2000000;
    let end_time = 3000000;
    let interval = 86400;


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);


    start_cheat_block_timestamp(core_address, start_time - 100);


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);


    stop_cheat_block_timestamp(core_address);
}


#[test]
#[should_panic(expected: 'Payout period ended')]
fn test_schedule_payout_after_end_time() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);


    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);


    start_cheat_block_timestamp(core_address, end_time + 100);


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);


    stop_cheat_block_timestamp(core_address);
}


#[test]
#[should_panic(expected: 'Schedule not active')]
fn test_schedule_payout_with_paused_schedule() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);


    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    
    let disbursement_dispatcher = IDisbursementDispatcher { contract_address: core_address };
    disbursement_dispatcher.pause_disbursement();
    stop_cheat_caller_address(core_address);


    start_cheat_block_timestamp(core_address, start_time + 100);


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);


    stop_cheat_block_timestamp(core_address);
}


#[test]
#[should_panic(expected: 'Payout period ended')]
fn test_schedule_payout_at_end_timestamp() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);
    let start_time = 1000000;
    let end_time = 2000000;
    let interval = 86400;
    start_cheat_caller_address(core_address, owner);
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    start_cheat_block_timestamp(core_address, end_time); 
    start_cheat_caller_address(core_address, owner);
    core_dispatcher.schedule_payout(); 
    stop_cheat_caller_address(core_address);
    stop_cheat_block_timestamp(core_address);
}

#[test]
#[should_panic(expected: 'No schedule set')]
fn test_schedule_payout_inactive_schedule() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    add_test_members(core_dispatcher, core_address);


    start_cheat_caller_address(core_address, owner);
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);
}

#[test]
fn test_schedule_payout_successful() {
    let (core_dispatcher, core_address, _vault_dispatcher, _vault_address, _token_dispatcher, _token_address, owner) = setup_full_organization();
    let member_dispatcher = IMemberManagerDispatcher { contract_address: core_address };
    add_test_members(core_dispatcher, core_address);

    start_cheat_caller_address(core_address, owner);
    member_dispatcher.update_member_base_pay(1, 3000);
    member_dispatcher.update_member_base_pay(2, 2000);
    member_dispatcher.update_member_base_pay(3, 2000);
    member_dispatcher.update_member_base_pay(4, 2000);
    stop_cheat_caller_address(core_address);

    let start_time = 2000000;
    let end_time = 3000000;
    let interval = 86400;
    
    
    start_cheat_caller_address(core_address, owner);
    core_dispatcher.initialize_disbursement_schedule(0, start_time, end_time, interval);
    stop_cheat_caller_address(core_address);
    
    
    start_cheat_block_timestamp(core_address, start_time);
    
    let owner_balance = _token_dispatcher.balance_of(owner);
    let employee1_balance = _token_dispatcher.balance_of(employee1());

    start_cheat_caller_address(core_address, owner);
    core_dispatcher.schedule_payout();
    stop_cheat_caller_address(core_address);

    let new_employee1_balance = _token_dispatcher.balance_of(employee1());
    let new_owner_balance = _token_dispatcher.balance_of(owner);

    assert(new_employee1_balance > employee1_balance, 'Employee 1 payout unsuccessful');
    assert(new_owner_balance > owner_balance, 'Owner is not paid out');

    stop_cheat_block_timestamp(core_address);
}