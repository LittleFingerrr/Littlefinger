/// ## A Starknet contract for managing an organization's financial vault.
///
/// This contract is responsible for:
/// - Securely holding a single type of ERC20 token.
/// - Processing deposits and withdrawals from authorized addresses.
/// - Executing payments to organization members.
/// - Allocating funds for bonuses.
/// - Recording all transactions for auditing purposes.
/// - Providing security features like an emergency freeze.
///
/// It leverages OpenZeppelin's `OwnableComponent` for access control and `UpgradeableComponent`
/// for future contract upgrades.
#[starknet::contract]
pub mod Vault {
    use core::num::traits::Zero;
    use littlefinger::interfaces::ivault::IVault;
    use littlefinger::structs::vault_structs::{Transaction, TransactionType, VaultStatus};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::storage::{
        Map, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
    };
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, get_contract_address, get_tx_info,
    };
    // use openzeppelin::upgrades::interface::IUpgradeable;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    /// Defines the storage layout for the `Vault` contract.
    #[storage]
    struct Storage {
        /// Maps a contract address to a boolean indicating if it's permitted to interact with the
        /// vault.
        permitted_addresses: Map<ContractAddress, bool>,
        /// The total balance of the managed token held by the vault.
        available_funds: u256,
        /// The portion of the total balance allocated for bonus payments.
        total_bonus: u256,
        /// Maps a transaction ID (`u64`) to a `Transaction` struct, storing a history of all vault
        /// operations.
        transaction_history: Map<
            u64, Transaction,
        >, // No 1. Transaction x, no 2, transaction y etc for history, and it begins with 1
        /// A counter for the total number of transactions processed.
        transactions_count: u64,
        /// The current operational status of the vault (e.g., VAULTACTIVE, VAULTFROZEN).
        vault_status: VaultStatus,
        /// The contract address of the single ERC20 token this vault manages.
        token: ContractAddress,
        /// Substorage for the Ownable component.
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        /// Substorage for the Upgradeable component.
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    /// Events emitted by the `Vault` contract.
    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        /// Emitted when a deposit is successfully made.
        DepositSuccessful: DepositSuccessful,
        /// Emitted when a withdrawal is successfully processed.
        WithdrawalSuccessful: WithdrawalSuccessful,
        /// Emitted when the vault's operations are frozen.
        VaultFrozen: VaultFrozen,
        /// Emitted when the vault's operations are resumed from a frozen state.
        VaultResumed: VaultResumed,
        /// Emitted each time a new transaction is recorded.
        TransactionRecorded: TransactionRecorded,
        /// Emitted when funds are allocated to the bonus pool.
        BonusAllocation: BonusAllocation,
        /// Flat event for Ownable component events.
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        /// Flat event for Upgradeable component events.
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        // TODO:
    // Add an event here that gets emitted if the money goes below a certain threshold
    // Threshold Will be decided.
    }

    /// Event data for a successful deposit.
    #[derive(Copy, Drop, starknet::Event)]
    pub struct DepositSuccessful {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    /// Event data for a successful withdrawal.
    #[derive(Copy, Drop, starknet::Event)]
    pub struct WithdrawalSuccessful {
        pub caller: ContractAddress,
        pub token: ContractAddress,
        pub amount: u256,
        pub timestamp: u64,
    }

    /// Event data for a vault freeze.
    #[derive(Copy, Drop, starknet::Event)]
    pub struct VaultFrozen {
        pub caller: ContractAddress,
        pub timestamp: u64,
    }

    /// Event data for unfreezing the vault.
    #[derive(Copy, Drop, starknet::Event)]
    pub struct VaultResumed {
        pub caller: ContractAddress,
        pub timestamp: u64,
    }

    /// Event data for a recorded transaction.
    #[derive(Drop, starknet::Event)]
    pub struct TransactionRecorded {
        pub transaction_type: TransactionType,
        pub caller: ContractAddress,
        pub transaction_details: Transaction,
        pub token: ContractAddress,
    }

    /// Event data for a bonus allocation.
    #[derive(Drop, starknet::Event)]
    pub struct BonusAllocation {
        pub amount: u256,
        pub timestamp: u64,
    }

    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // TODO:
    // Add to this constructor, a way to add addresses and store them as permitted addresses here
    /// Initializes the Vault contract.
    ///
    /// ### Parameters
    /// - `token`: The contract address of the ERC20 token to be managed.
    /// - `owner`: The address that will have initial ownership and permissions.
    #[constructor]
    fn constructor(
        ref self: ContractState,
        token: ContractAddress, // available_funds: u256,
        // bonus_allocation: u256,
        owner: ContractAddress,
    ) {
        self.token.write(token);
        self.total_bonus.write(0);
        self.permitted_addresses.entry(owner).write(true);

        self._sync_available_funds();
    }

    // TODO:
    // From the ivault, add functions in the interfaces for subtracting from and adding to bonus
    // IMPLEMENT HERE

    // TODO:
    // Implement a storage variable, that will be in the constructor, for the token address to be
    // supplied at deployment For now, we want a single-token implementation

    /// # VaultImpl
    ///
    /// Public-facing implementation of the `IVault` interface.
    #[abi(embed_v0)]
    pub impl VaultImpl of IVault<ContractState> {
        /// Accepts a deposit of the managed token.
        ///
        /// ### Parameters
        /// - `amount`: The amount to deposit.
        /// - `address`: The address from which the funds are being sent.
        ///
        /// ### Panics
        /// - If `amount` or `address` is zero.
        /// - If the direct caller or the source `address` is not permitted.
        /// - If the vault is frozen.
        fn deposit_funds(ref self: ContractState, amount: u256, address: ContractAddress) {
            assert(amount.is_non_zero(), 'Invalid Amount');
            assert(address.is_non_zero(), 'Invalid Address');
            let caller = get_caller_address();
            let permitted = self.permitted_addresses.entry(caller).read();
            assert(permitted, 'Direct Caller not permitted');
            assert(self.permitted_addresses.entry(address).read(), 'Deep Caller Not Permitted');
            let current_vault_status = self.vault_status.read();
            assert(
                current_vault_status != VaultStatus::VAULTFROZEN, 'Vault Frozen for Transactions',
            );

            self._sync_available_funds();

            let timestamp = get_block_timestamp();
            let this_contract = get_contract_address();
            let token = self.token.read();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };

            token_dispatcher.transfer_from(address, this_contract, amount);

            self._record_transaction(token, amount, TransactionType::DEPOSIT, address);

            self._sync_available_funds();

            self.emit(DepositSuccessful { caller: address, token, timestamp, amount })
        }

        /// Withdraws the managed token to a specified address.
        ///
        /// ### Parameters
        /// - `amount`: The amount to withdraw.
        /// - `address`: The address to receive the funds.
        ///
        /// ### Panics
        /// - If `amount` or `address` is zero.
        /// - If the direct caller or the destination `address` is not permitted.
        /// - If the vault is frozen.
        /// - If the requested amount exceeds the vault's balance.
        fn withdraw_funds(ref self: ContractState, amount: u256, address: ContractAddress) {
            assert(amount.is_non_zero(), 'Invalid Amount');
            assert(address.is_non_zero(), 'Invalid Address');
            let caller = get_caller_address();
            let permitted = self.permitted_addresses.entry(caller).read();
            assert(permitted, 'Direct Caller not permitted');
            assert(self.permitted_addresses.entry(address).read(), 'Deep Caller Not Permitted');

            let current_vault_status = self.vault_status.read();
            assert(
                current_vault_status != VaultStatus::VAULTFROZEN, 'Vault Frozen for Transactions',
            );

            self._sync_available_funds();

            let timestamp = get_block_timestamp();

            let token = self.token.read();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let vault_balance = token_dispatcher.balance_of(get_contract_address());
            assert(amount <= vault_balance, 'Insufficient Balance');

            token_dispatcher.transfer(address, amount);
            self._record_transaction(token, amount, TransactionType::WITHDRAWAL, address);

            self._sync_available_funds();

            self.emit(WithdrawalSuccessful { caller: address, token, amount, timestamp })
        }

        /// Allocates a portion of the vault's funds to the bonus pool.
        ///
        /// ### Parameters
        /// - `amount`: The amount to allocate for bonuses.
        /// - `address`: The address initiating the allocation.
        ///
        /// ### Panics
        /// - If `amount` or `address` is zero.
        /// - If the direct caller or the source `address` is not permitted.
        fn add_to_bonus_allocation(
            ref self: ContractState, amount: u256, address: ContractAddress,
        ) {
            assert(amount.is_non_zero(), 'Invalid Amount');
            assert(address.is_non_zero(), 'Invalid Address');
            let caller = get_caller_address();
            let permitted = self.permitted_addresses.entry(caller).read();
            assert(permitted, 'Direct Caller not permitted');
            assert(self.permitted_addresses.entry(address).read(), 'Deep Caller Not Permitted');

            self._sync_available_funds();

            self.total_bonus.write(self.total_bonus.read() + amount);
            self
                ._record_transaction(
                    self.token.read(), amount, TransactionType::BONUS_ALLOCATION, address,
                );
        }

        /// Freezes all vault operations as a security measure.
        ///
        /// ### Panics
        /// - If the caller is not a permitted address.
        /// - If the vault is already frozen.
        fn emergency_freeze(ref self: ContractState) {
            let caller = get_caller_address();
            let permitted = self.permitted_addresses.entry(caller).read();
            assert(permitted, 'Caller not permitted');
            assert(self.vault_status.read() != VaultStatus::VAULTFROZEN, 'Vault Already Frozen');

            self.vault_status.write(VaultStatus::VAULTFROZEN);
        }

        /// Resumes vault operations after a freeze.
        ///
        /// ### Panics
        /// - If the caller is not a permitted address.
        /// - If the vault is not currently frozen.
        fn unfreeze_vault(ref self: ContractState) {
            let caller = get_caller_address();
            let permitted = self.permitted_addresses.entry(caller).read();
            assert(permitted, 'Caller not permitted');
            assert(self.vault_status.read() != VaultStatus::VAULTRESUMED, 'Vault Not Frozen');

            self.vault_status.write(VaultStatus::VAULTRESUMED);
        }

        // fn bulk_transfer(ref self: ContractState, recipients: Span<ContractAddress>) {}

        /// Returns the vault's total balance of the managed token.
        ///
        /// ### Returns
        /// - `u256`: The total balance.
        fn get_balance(self: @ContractState) -> u256 {
            // let caller = get_caller_address();
            // assert(self.permitted_addresses.entry(caller).read(), 'Caller Not Permitted');
            let token_address = self.token.read();
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let vault_address = get_contract_address();
            let balance = token_dispatcher.balance_of(vault_address);
            balance
        }

        /// Returns the funds currently available for use.
        ///
        /// ### Returns
        /// - `u256`: The available fund balance.
        fn get_available_funds(self: @ContractState) -> u256 {
            self.available_funds.read()
        }

        /// Returns the total amount allocated for bonuses.
        ///
        /// ### Returns
        /// - `u256`: The bonus allocation amount.
        fn get_bonus_allocation(self: @ContractState) -> u256 {
            // let caller = get_caller_address();
            // assert(self.permitted_addresses.entry(caller).read(), 'Caller Not Permitted');
            self.total_bonus.read()
        }

        /// Pays a member from the vault's funds.
        ///
        /// ### Parameters
        /// - `recipient`: The address of the member to pay.
        /// - `amount`: The amount of the payment.
        ///
        /// ### Panics
        /// - If `recipient` or `amount` is zero.
        /// - If the caller is not a permitted address.
        /// - If the payment amount exceeds the vault's balance.
        /// - If the token transfer fails.
        fn pay_member(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            assert(recipient.is_non_zero(), 'Invalid Address');
            assert(amount.is_non_zero(), 'Invalid Amount');
            let caller = get_caller_address();
            assert(self.permitted_addresses.entry(caller).read(), 'Caller Not Permitted');

            self._sync_available_funds();

            let token_address = self.token.read();
            let token = IERC20Dispatcher { contract_address: token_address };
            let token_balance = token.balance_of(get_contract_address());
            assert(amount <= token_balance, 'Amount Overflow');
            let transfer = token.transfer(recipient, amount);
            assert(transfer, 'Transfer failed');
            self._record_transaction(token_address, amount, TransactionType::PAYMENT, caller);

            self._sync_available_funds();
        }

        /// Returns the current status of the vault.
        ///
        /// ### Returns
        /// - `VaultStatus`: The vault's current status enum.
        fn get_vault_status(self: @ContractState) -> VaultStatus {
            self.vault_status.read()
        }

        /// Returns the entire transaction history of the vault.
        ///
        /// ### Returns
        /// - `Array<Transaction>`: A list of all recorded transactions.
        fn get_transaction_history(self: @ContractState) -> Array<Transaction> {
            let mut transaction_history = array![];

            for i in 1..self.transactions_count.read() + 1 {
                let current_transaction = self.transaction_history.entry(i).read();
                transaction_history.append(current_transaction);
            }

            transaction_history
        }

        /// Grants another contract permission to call functions on this vault.
        ///
        /// ### Parameters
        /// - `org_address`: The contract address to be granted permission.
        ///
        /// ### Panics
        /// - If `org_address` is zero.
        fn allow_org_core_address(ref self: ContractState, org_address: ContractAddress) {
            assert(org_address.is_non_zero(), 'Invalid Address');
            self.permitted_addresses.entry(org_address).write(true);
        }
    }

    /// # InternalFunctions
    ///
    /// Internal helper functions for privileged operations within the vault.
    #[generate_trait]
    impl InternalFunctions of InternalTrait {
        /// Adds a new transaction to the history.
        ///
        /// ### Parameters
        /// - `transaction`: The `Transaction` struct to record.
        ///
        /// ### Panics
        /// - If the caller is not a permitted address.
        fn _add_transaction(ref self: ContractState, transaction: Transaction) {
            let caller = get_caller_address();
            assert(self.permitted_addresses.entry(caller).read(), 'Caller not permitted');
            let current_transaction_count = self.transactions_count.read();
            self.transaction_history.entry(current_transaction_count + 1).write(transaction);
            self.transactions_count.write(current_transaction_count + 1);
        }

        /// Creates and stores a transaction record, and emits an event.
        ///
        /// ### Parameters
        /// - `token_address`: The address of the token involved.
        /// - `amount`: The transaction amount.
        /// - `transaction_type`: The type of transaction (e.g., DEPOSIT, WITHDRAWAL).
        /// - `caller`: The original initiator of the transaction.
        ///
        /// ### Panics
        /// - If the function's direct caller is not a permitted address.
        fn _record_transaction(
            ref self: ContractState,
            token_address: ContractAddress,
            amount: u256,
            transaction_type: TransactionType,
            caller: ContractAddress,
        ) {
            let actual_caller = get_caller_address();
            assert(self.permitted_addresses.entry(actual_caller).read(), 'Caller Not Permitted');
            let timestamp = get_block_timestamp();
            let tx_info = get_tx_info();
            let transaction = Transaction {
                transaction_type,
                token: token_address,
                amount,
                timestamp,
                tx_hash: tx_info.transaction_hash,
                caller,
            };
            self._add_transaction(transaction);
            self
                .emit(
                    TransactionRecorded {
                        transaction_type,
                        caller: actual_caller,
                        transaction_details: transaction,
                        token: token_address,
                    },
                );
        }

        /// Updates the `available_funds` storage variable to match the contract's actual token
        /// balance.
        fn _sync_available_funds(ref self: ContractState) {
            let token_address = self.token.read();
            let token_dispatcher = IERC20Dispatcher { contract_address: token_address };
            let vault_address = get_contract_address();
            let actual_balance = token_dispatcher.balance_of(vault_address);
            self.available_funds.write(actual_balance);
        }
    }
}
