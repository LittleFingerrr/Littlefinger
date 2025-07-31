use core::num::traits::Zero;
use littlefinger::interfaces::ifactory::{IFactoryDispatcher, IFactoryDispatcherTrait};
use snforge_std::{ContractClassTrait, DeclareResultTrait, declare};
use starknet::ContractAddress;

fn owner() -> ContractAddress {
    1.try_into().unwrap()
}

// Mock ERC20 token for testing
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

fn deploy_mock_erc20() -> (IMockERC20Dispatcher, ContractAddress) {
    let contract = declare("MockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IMockERC20Dispatcher { contract_address };

    // Mint some tokens for testing
    dispatcher.mint(owner(), 1000000000000000000000); // 1000 tokens
    (dispatcher, contract_address)
}


fn setup_factory() -> ContractAddress {
    let declare_result = declare("Factory");
    let core_class_hash = declare("Core").unwrap().contract_class().class_hash;
    let vault_class_hash = declare("Vault").unwrap().contract_class().class_hash;

    assert(declare_result.is_ok(), 'factory declaration failed');

    let contract_class = declare_result.unwrap().contract_class();

    let mut calldata: Array<felt252> = array![owner().into()];

    core_class_hash.serialize(ref calldata);
    vault_class_hash.serialize(ref calldata);

    let deploy_result = contract_class.deploy(@calldata);

    assert(deploy_result.is_ok(), 'contract deployment failed');
    println!("I passed this point");

    let (contract_address, _) = deploy_result.unwrap();
    contract_address
}

pub fn setup_factory_and_org_helper() -> (
    ContractAddress, IFactoryDispatcher, ContractAddress, ContractAddress,
) {
    let contract_address = setup_factory();
    let (_, token_address) = deploy_mock_erc20();
    let dispatcher = IFactoryDispatcher { contract_address };
    let (org_address, vault_address) = dispatcher
        .setup_org(
            token: token_address,
            salt: 'test_salt',
            owner: owner(),
            name: "test_name",
            ipfs_url: "test_ipfs_url",
            first_admin_fname: 'test_fname',
            first_admin_lname: 'test_lname',
            first_admin_alias: 'test_alias',
            organization_type: 0,
        );
    if !org_address.is_zero() {
        println!("org_address successfully deployed")
    }
    (contract_address, dispatcher, org_address, vault_address)
}
