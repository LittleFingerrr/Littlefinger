use littlefinger::interfaces::iadmin_permission_manager::{
    IAdminPermissionManagerDispatcher, IAdminPermissionManagerDispatcherTrait,
};
use littlefinger::interfaces::ivault::{IVaultDispatcher, IVaultDispatcherTrait};
use littlefinger::structs::admin_permissions::AdminPermission;
use littlefinger::structs::vault_structs::{TransactionType, VaultStatus};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare, start_cheat_caller_address,
    stop_cheat_caller_address,
};
#[feature("deprecated-starknet-consts")]
use starknet::{ContractAddress, contract_address_const};

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

// Helper functions
fn owner() -> ContractAddress {
    contract_address_const::<'owner'>()
}

fn permitted_caller() -> ContractAddress {
    contract_address_const::<'permitted_caller'>()
}

fn non_permitted_caller() -> ContractAddress {
    contract_address_const::<'non_permitted_caller'>()
}

fn recipient() -> ContractAddress {
    contract_address_const::<'recipient'>()
}

fn zero_addr() -> ContractAddress {
    contract_address_const::<0>()
}

fn deploy_mock_erc20() -> (IMockERC20Dispatcher, ContractAddress) {
    let contract = declare("MockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IMockERC20Dispatcher { contract_address };

    // Mint some tokens for testing
    dispatcher.mint(owner(), 1000000000000000000000); // 1000 tokens
    dispatcher.mint(permitted_caller(), 1000000000000000000000);
    dispatcher.mint(recipient(), 1000000000000000000000);

    (dispatcher, contract_address)
}

fn deploy_another_mock_erc20() -> (IMockERC20Dispatcher, ContractAddress) {
    let contract = declare("AnotherMockERC20").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@array![]).unwrap();
    let dispatcher = IMockERC20Dispatcher { contract_address };

    (dispatcher, contract_address)
}

fn deploy_vault() -> (IVaultDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    let (token1_dispatcher, token1_address) = deploy_mock_erc20();
    let (token2_dispatcher, token2_address) = deploy_mock_erc20();

    let vault_contract = declare("Vault").unwrap().contract_class();
    let owner_address = owner();
    let token_addresses = array![token1_address, token2_address];

    // Use array! macro with explicit typing for deployment
    let mut constructor_calldata = array![owner_address.into()];
    token_addresses.serialize(ref constructor_calldata);

    let (vault_address, _) = vault_contract.deploy(@constructor_calldata).unwrap();
    let vault_dispatcher = IVaultDispatcher { contract_address: vault_address };

    // Setup permissions - the owner should have been set during construction
    // Add permitted_caller as an allowed address and recipient for deep caller validation
    start_cheat_caller_address(vault_address, owner_address);
    vault_dispatcher.allow_org_core_address(permitted_caller());
    vault_dispatcher.allow_org_core_address(owner_address);
    vault_dispatcher.allow_org_core_address(recipient());

    // Grant admin permissions to permitted_caller for testing
    let admin_permission_manager = IAdminPermissionManagerDispatcher {
        contract_address: vault_address,
    };
    admin_permission_manager
        .grant_admin_permission(permitted_caller(), AdminPermission::VAULT_FUNCTIONS);
    admin_permission_manager
        .grant_admin_permission(permitted_caller(), AdminPermission::ADD_VAULT_TOKENS);

    stop_cheat_caller_address(vault_address);

    // Setup token1 approvals for all addresses
    start_cheat_caller_address(token1_address, owner_address);
    token1_dispatcher.approve(vault_address, 1000000000000000000000);
    stop_cheat_caller_address(token1_address);

    start_cheat_caller_address(token1_address, permitted_caller());
    token1_dispatcher.approve(vault_address, 1000000000000000000000);
    stop_cheat_caller_address(token1_address);

    start_cheat_caller_address(token1_address, recipient());
    token1_dispatcher.approve(vault_address, 1000000000000000000000);
    stop_cheat_caller_address(token1_address);

    // Transfer some tokens to the vault for payment operations
    start_cheat_caller_address(token1_address, owner_address);
    token1_dispatcher.transfer(vault_address, 100000000000000000000); // 100 tokens
    stop_cheat_caller_address(token1_address);

    // Setup token2 approvals for all addresses
    start_cheat_caller_address(token2_address, owner_address);
    token2_dispatcher.approve(vault_address, 2000000000000000000000);
    stop_cheat_caller_address(token2_address);

    start_cheat_caller_address(token2_address, permitted_caller());
    token2_dispatcher.approve(vault_address, 2000000000000000000000);
    stop_cheat_caller_address(token2_address);

    start_cheat_caller_address(token2_address, recipient());
    token2_dispatcher.approve(vault_address, 2000000000000000000000);
    stop_cheat_caller_address(token2_address);

    // Transfer some tokens to the vault for payment operations
    start_cheat_caller_address(token2_address, owner_address);
    token2_dispatcher.transfer(vault_address, 200000000000000000000); // 200 tokens
    stop_cheat_caller_address(token2_address);

    (vault_dispatcher, vault_address, token1_address, token2_address)
}

// Constructor Tests
#[test]
fn test_constructor_initializes_correctly() {
    let (vault, _vault_address, _token1_address, _token2_address) = deploy_vault();
    assert(
        vault.get_token_balance(_token1_address) == 100000000000000000000,
        'Incorrect initial balance',
    );
    assert(vault.get_bonus_allocation(_token1_address) == 0, 'Incorrect bonus allocation');
    assert(
        vault.get_token_balance(_token2_address) == 200000000000000000000,
        'Incorrect initial balance',
    );
    assert(vault.get_bonus_allocation(_token2_address) == 0, 'Incorrect bonus allocation');
    assert(vault.get_vault_status() == VaultStatus::VAULTRESUMED, 'Vault should be resumed');
}

// Deposit Tests
#[test]
fn test_deposit_funds_success() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();
    let deposit_amount = 100000000000000000; // 0.1 ETH

    start_cheat_caller_address(vault_address, permitted_caller());
    let first_vault_balance = vault.get_token_balance(_token1_address);
    vault.deposit_funds(_token1_address, deposit_amount, owner());
    stop_cheat_caller_address(vault_address);

    // Check balance updated
    let expected_balance = first_vault_balance + deposit_amount;
    assert(
        vault.get_token_balance(_token1_address) == expected_balance,
        'Balance not updated correctly',
    );
}

#[test]
#[should_panic(expected: 'Direct Caller not permitted')]
fn test_deposit_funds_unauthorized_caller() {
    let (vault, vault_address, _token1_address, _) = deploy_vault();

    start_cheat_caller_address(vault_address, non_permitted_caller());
    vault.deposit_funds(_token1_address, 100000000000000000, owner());
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Deep Caller Not Permitted')]
fn test_deposit_funds_unauthorized_deep_caller() {
    let (vault, vault_address, _token1_address, _) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.deposit_funds(_token1_address, 100000000000000000, non_permitted_caller());
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Vault Frozen for Transactions')]
fn test_deposit_funds_when_vault_frozen() {
    let (vault, vault_address, _token1_address, _) = deploy_vault();

    // Freeze vault first
    start_cheat_caller_address(vault_address, permitted_caller());
    vault.emergency_freeze();

    // Try to deposit - should fail
    vault.deposit_funds(_token1_address, 100000000000000000, owner());
    stop_cheat_caller_address(vault_address);
}

// Withdrawal Tests
#[test]
fn test_withdraw_funds_success() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();
    let withdraw_amount = 1000000000000000; // 0.1 ETH

    start_cheat_caller_address(vault_address, owner());
    vault.deposit_funds(_token1_address, withdraw_amount + 1000, owner());
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, permitted_caller());
    let first_vault_balance = vault.get_token_balance(_token1_address);
    vault.withdraw_funds(_token1_address, withdraw_amount, recipient());
    stop_cheat_caller_address(vault_address);

    // Check balance updated
    let expected_balance = first_vault_balance - withdraw_amount;
    assert(
        vault.get_token_balance(_token1_address) == expected_balance,
        'Balance not updated correctly',
    );
}

#[test]
#[should_panic(expected: 'Insufficient admin permissions')]
fn test_withdraw_funds_unauthorized_caller() {
    let (vault, vault_address, _token1_address, _) = deploy_vault();

    start_cheat_caller_address(vault_address, non_permitted_caller());
    vault.withdraw_funds(_token1_address, 100000000000000000, recipient());
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Deep Caller Not Permitted')]
fn test_withdraw_funds_unauthorized_deep_caller() {
    let (vault, vault_address, _token1_address, _) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.withdraw_funds(_token1_address, 100000000000000000, non_permitted_caller());
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Insufficient Balance')]
fn test_withdraw_funds_insufficient_balance() {
    let (vault, vault_address, _token1_address, _) = deploy_vault();
    let excessive_amount = 300000000000000000000; // 2 ETH (more than available)

    start_cheat_caller_address(vault_address, owner());
    vault.deposit_funds(_token1_address, excessive_amount / 1000, owner());
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.withdraw_funds(_token1_address, excessive_amount, recipient());
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Vault Frozen for Transactions')]
fn test_withdraw_funds_when_vault_frozen() {
    let (vault, vault_address, _token1_address, _) = deploy_vault();

    // Freeze vault first
    start_cheat_caller_address(vault_address, permitted_caller());
    vault.emergency_freeze();

    // Try to withdraw - should fail
    vault.withdraw_funds(_token1_address, 100000000000000000, recipient());
    stop_cheat_caller_address(vault_address);
}

// Freeze/Unfreeze Tests
#[test]
fn test_emergency_freeze_success() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.emergency_freeze();
    stop_cheat_caller_address(vault_address);

    // Check status updated
    assert(vault.get_vault_status() == VaultStatus::VAULTFROZEN, 'Vault not frozen');
}

#[test]
#[should_panic(expected: 'Insufficient admin permissions')]
fn test_emergency_freeze_unauthorized() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, non_permitted_caller());
    vault.emergency_freeze();
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Vault Already Frozen')]
fn test_emergency_freeze_already_frozen() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.emergency_freeze();
    vault.emergency_freeze(); // Should fail
    stop_cheat_caller_address(vault_address);
}

#[test]
fn test_unfreeze_vault_success() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());

    // Freeze first
    vault.emergency_freeze();
    vault.unfreeze_vault();
    stop_cheat_caller_address(vault_address);

    // Check status updated
    assert(vault.get_vault_status() == VaultStatus::VAULTRESUMED, 'Vault not unfrozen');
}

#[test]
#[should_panic(expected: 'Insufficient admin permissions')]
fn test_unfreeze_vault_unauthorized() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    // Freeze first
    start_cheat_caller_address(vault_address, permitted_caller());
    vault.emergency_freeze();
    stop_cheat_caller_address(vault_address);

    // Try to unfreeze with unauthorized caller
    start_cheat_caller_address(vault_address, non_permitted_caller());
    vault.unfreeze_vault();
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Vault Not Frozen')]
fn test_unfreeze_vault_not_frozen() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.unfreeze_vault(); // Should fail - vault is not frozen
    stop_cheat_caller_address(vault_address);
}

// Pay Member Tests
#[test]
fn test_pay_member_success() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();
    let payment_amount = 100000000000000; // 0.1 ETH

    start_cheat_caller_address(vault_address, owner());
    vault.deposit_funds(_token1_address, payment_amount + 1000, owner());
    stop_cheat_caller_address(vault_address);

    start_cheat_caller_address(vault_address, permitted_caller());
    let first_vault_balance = vault.get_token_balance(_token1_address);
    vault.pay_member(_token1_address, recipient(), payment_amount);
    stop_cheat_caller_address(vault_address);

    // Check balance updated
    let expected_balance = first_vault_balance - payment_amount;
    assert(
        vault.get_token_balance(_token1_address) == expected_balance,
        'Balance not updated correctly',
    );
}

#[test]
#[should_panic(expected: 'Insufficient admin permissions')]
fn test_pay_member_unauthorized() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, non_permitted_caller());
    vault.pay_member(_token1_address, recipient(), 100000000000000000);
    stop_cheat_caller_address(vault_address);
}

// Bonus Allocation Tests
#[test]
fn test_add_to_bonus_allocation_success() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();
    let bonus_amount = 100000000000000000; // 0.1 ETH

    start_cheat_caller_address(vault_address, permitted_caller());
    let starting_bonus_allocation = vault.get_bonus_allocation(_token1_address);
    vault.add_to_bonus_allocation(_token1_address, bonus_amount, owner());
    stop_cheat_caller_address(vault_address);

    // Check bonus updated
    let expected_bonus = starting_bonus_allocation + bonus_amount;
    assert(
        vault.get_bonus_allocation(_token1_address) == expected_bonus,
        'Bonus not updated correctly',
    );
}

#[test]
#[should_panic(expected: 'Insufficient admin permissions')]
fn test_add_to_bonus_allocation_unauthorized() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, non_permitted_caller());
    vault.add_to_bonus_allocation(_token1_address, 100000000000000000, owner());
    stop_cheat_caller_address(vault_address);
}

#[test]
#[should_panic(expected: 'Deep Caller Not Permitted')]
fn test_add_to_bonus_allocation_unauthorized_deep_caller() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.add_to_bonus_allocation(_token1_address, 100000000000000000, non_permitted_caller());
    stop_cheat_caller_address(vault_address);
}

// Transaction History Tests
#[test]
fn test_transaction_history_records_correctly() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();
    let deposit_amount = 100000000000000000;
    let withdraw_amount = 50000000000000000;

    start_cheat_caller_address(vault_address, permitted_caller());

    // Perform some transactions
    vault.deposit_funds(_token1_address, deposit_amount, owner());
    vault.withdraw_funds(_token1_address, withdraw_amount, recipient());
    vault.add_to_bonus_allocation(_token1_address, 25000000000000000, owner());

    stop_cheat_caller_address(vault_address);

    // Check transaction history
    let history = vault.get_transaction_history();
    println!("history: {:?}", history);
    assert(history.len() == 3, 'Should have 3 transactions');

    // Check first transaction (deposit)
    let first_tx = *history.at(0);
    assert(first_tx.transaction_type == TransactionType::DEPOSIT, 'Incorrect transaction type');
    assert(first_tx.amount == deposit_amount, 'Incorrect deposit amount');
    assert(first_tx.caller == owner(), 'Incorrect caller');

    // Check second transaction (withdrawal)
    let second_tx = *history.at(1);
    assert(second_tx.transaction_type == TransactionType::WITHDRAWAL, 'Incorrect transaction type');
    assert(second_tx.amount == withdraw_amount, 'Incorrect withdraw amount');
    assert(second_tx.caller == recipient(), 'Incorrect caller');

    // Check third transaction (bonus allocation)
    let third_tx = *history.at(2);
    assert(
        third_tx.transaction_type == TransactionType::BONUS_ALLOCATION,
        'Incorrect transaction type',
    );
    assert(third_tx.amount == 25000000000000000, 'Incorrect bonus amount');
    assert(third_tx.caller == owner(), 'Incorrect caller');
}

// Access Control Tests
#[test]
fn test_allow_org_core_address() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();
    let new_org_address = contract_address_const::<'new_org'>();

    vault.allow_org_core_address(new_org_address);

    // Test that the new address can now call functions
    start_cheat_caller_address(vault_address, new_org_address);
    vault.deposit_funds(_token1_address, 100000000000000000, owner());
    stop_cheat_caller_address(vault_address);
}

// View Function Tests
#[test]
#[ignore]
fn test_get_balance() {
    let (vault, _, _token1_address, _token2_address) = deploy_vault();
    let balance = vault.get_token_balance(_token1_address);
    assert(balance == 1000000000000000000, 'Incorrect balance');
}

#[test]
#[ignore]
fn test_get_bonus_allocation() {
    let (vault, _, _token1_address, _token2_address) = deploy_vault();
    let bonus = vault.get_bonus_allocation(_token1_address);
    assert(bonus == 0, 'Incorrect bonus allocation');
}

#[test]
fn test_get_vault_status() {
    let (vault, _, _token1_address, _token2_address) = deploy_vault();
    let status = vault.get_vault_status();
    assert(status == VaultStatus::VAULTRESUMED, 'Incorrect vault status');
}

// Edge Case Tests
#[test]
#[should_panic(expected: 'Invalid Amount')]
fn test_zero_amount_deposit() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    let first_vault_balance = vault.get_token_balance(_token1_address);
    let first_bonus_allocation = vault.get_bonus_allocation(_token1_address);
    // Test zero deposit
    vault.deposit_funds(_token1_address, 0, owner());
}

#[test]
#[should_panic(expected: 'Invalid Address')]
fn test_zero_address_deposit() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    let first_vault_balance = vault.get_token_balance(_token1_address);
    let first_bonus_allocation = vault.get_bonus_allocation(_token1_address);
    // Test zero deposit
    vault.deposit_funds(_token1_address, 250, zero_addr());
}

// Integration Tests
#[test]
fn test_complete_vault_workflow() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    let mut vault_balance = vault.get_token_balance(_token1_address);
    let mut bonus_allocation = vault.get_bonus_allocation(_token1_address);
    // 1. Deposit funds
    let deposit_amount = 200000000000000000; // 0.2 ETH
    vault.deposit_funds(_token1_address, deposit_amount, owner());
    println!("Did not fail before deposit");

    let expected_balance = vault_balance + deposit_amount;
    vault_balance += deposit_amount;
    assert(vault.get_token_balance(_token1_address) == expected_balance, 'Deposit failed');

    // 2. Add bonus allocation
    let bonus_amount = 100000000000000000; // 0.1 ETH
    vault.add_to_bonus_allocation(_token1_address, bonus_amount, owner());

    let expected_bonus = bonus_allocation + bonus_amount;
    bonus_allocation += bonus_amount;
    assert(
        vault.get_bonus_allocation(_token1_address) == expected_bonus, 'Bonus allocation failed',
    );

    // 3. Pay member
    let payment_amount = 150000000000000; // 0.15 ETH
    vault.pay_member(_token1_address, recipient(), payment_amount);
    println!("I didn't fail after pay_member");

    let expected_balance_after_payment = expected_balance - payment_amount;
    assert(
        vault.get_token_balance(_token1_address) == expected_balance_after_payment,
        'Payment failed',
    );

    // 4. Withdraw funds
    let withdraw_amount = 100000000000000000; // 0.1 ETH
    vault.withdraw_funds(_token1_address, withdraw_amount, recipient());
    println!("I didn't fail after withdrawal");

    let final_expected_balance = expected_balance_after_payment - withdraw_amount;
    assert(vault.get_token_balance(_token1_address) == final_expected_balance, 'Withdrawal failed');

    // 5. Check transaction history
    let history = vault.get_transaction_history();
    assert(history.len() == 4, 'Incorrect transaction count');

    // 6. Test freeze/unfreeze
    vault.emergency_freeze();
    assert(vault.get_vault_status() == VaultStatus::VAULTFROZEN, 'Freeze failed');

    vault.unfreeze_vault();
    assert(vault.get_vault_status() == VaultStatus::VAULTRESUMED, 'Unfreeze failed');

    stop_cheat_caller_address(vault_address);
}

#[test]
fn test_add_accepted_token() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    let accepted_tokens_before = vault.get_accepted_tokens();

    assert!(accepted_tokens_before.len() == 2, "Incorrect number of accepted tokens");
    assert(accepted_tokens_before.at(0) == @_token1_address, 'Incorrect accepted token');
    assert(accepted_tokens_before.at(1) == @_token2_address, 'Incorrect accepted token');

    let new_token_address = contract_address_const::<'new_token'>();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.add_accepted_token(new_token_address);
    stop_cheat_caller_address(vault_address);

    let accepted_tokens_after = vault.get_accepted_tokens();

    assert!(accepted_tokens_after.len() == 3, "Incorrect number of accepted tokens");
    assert(accepted_tokens_after.at(0) == @_token1_address, 'Incorrect accepted token');
    assert(accepted_tokens_after.at(1) == @_token2_address, 'Incorrect accepted token');
    assert(accepted_tokens_after.at(2) == @new_token_address, 'Incorrect accepted token');
}

#[test]
#[should_panic(expected: 'Token already accepted')]
fn test_add_accepted_token_already_accepted() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.add_accepted_token(_token1_address);
    stop_cheat_caller_address(vault_address);
}

#[test]
fn test_remove_accepted_token() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    let accepted_tokens_before = vault.get_accepted_tokens();

    assert!(accepted_tokens_before.len() == 2, "Incorrect number of accepted tokens");
    assert(accepted_tokens_before.at(0) == @_token1_address, 'Incorrect accepted token');
    assert(accepted_tokens_before.at(1) == @_token2_address, 'Incorrect accepted token');

    start_cheat_caller_address(vault_address, permitted_caller());
    vault.remove_accepted_token(_token1_address);
    stop_cheat_caller_address(vault_address);

    let accepted_tokens_after = vault.get_accepted_tokens();
    println!("accepted_tokens_after: {:?}", accepted_tokens_after);

    assert!(accepted_tokens_after.len() == 1, "Incorrect number of accepted tokens");
    assert(accepted_tokens_after.at(0) == @_token2_address, 'Incorrect accepted token');
}

#[test]
#[should_panic(expected: 'Insufficient admin permissions')]
fn test_remove_accepted_token_unauthorized() {
    let (vault, vault_address, _token1_address, _token2_address) = deploy_vault();

    start_cheat_caller_address(vault_address, non_permitted_caller());
    vault.remove_accepted_token(_token1_address);
    stop_cheat_caller_address(vault_address);
}
