/// ## A Starknet contract for managing an organization's financial vault for multiple tokens.
///
/// This contract is responsible for:
/// - Securely holding multiple types of ERC20 tokens.
/// - Processing deposits and withdrawals from authorized addresses.
/// - Executing payments to organization members.
/// - Allocating funds for bonuses on a per-token basis.
/// - Recording all transactions for auditing purposes.
/// - Providing security features like an emergency freeze.
///
/// It leverages OpenZeppelin's `OwnableComponent` for access control and `UpgradeableComponent`
/// for future contract upgrades.
#[starknet::contract]
pub mod Vault {
    use AdminPermissionManagerComponent::AdminPermissionManagerInternalTrait;
    use core::num::traits::Zero;
    use littlefinger::components::admin_permission_manager::AdminPermissionManagerComponent;
    use littlefinger::interfaces::ivault::IVault;
    use littlefinger::structs::admin_permissions::AdminPermission;
    use littlefinger::structs::vault_structs::{Transaction, TransactionType, VaultStatus};
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::storage::{
        Map, MutableVecTrait, StoragePathEntry, StoragePointerReadAccess, StoragePointerWriteAccess,
        Vec, VecTrait,
    };
    use starknet::{
        ContractAddress, get_block_timestamp, get_caller_address, get_contract_address, get_tx_info,
    };
    // use openzeppelin::upgrades::interface::IUpgradeable;

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(
        path: AdminPermissionManagerComponent,
        storage: admin_permission_manager,
        event: AdminPermissionManagerEvent,
    );

    #[abi(embed_v0)]
    impl AdminPermissionManagerImpl =
        AdminPermissionManagerComponent::AdminPermissionManagerImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    /// Defines the storage layout for the `Vault` contract.
    #[storage]
    struct Storage {
        /// Maps a contract address to a boolean indicating if it's permitted to interact with the
        /// vault.
        permitted_addresses: Map<ContractAddress, bool>,
        /// Maps a token address to its portion of the total balance allocated for bonus payments.
        bonus_allocations: Map<ContractAddress, u256>,
        /// Maps a transaction ID to a `Transaction` struct, storing a history of all vault
        /// operations.
        transaction_history: Map<u64, Transaction>,
        /// A counter for the total number of transactions processed.
        transactions_count: u64,
        /// The current operational status of the vault (e.g., VAULTACTIVE, VAULTFROZEN).
        vault_status: VaultStatus,
        /// Maps a token address to a boolean, indicating if it's an accepted asset for the vault.
        accepted_tokens: Map<ContractAddress, bool>,
        /// A list of all accepted token addresses for easy retrieval.
        accepted_tokens_list: Vec<ContractAddress>,
        /// Substorage for the Ownable component.
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        /// Substorage for the Upgradeable component.
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        /// Substorage for the AdminPermissionManager component.
        #[substorage(v0)]
        admin_permission_manager: AdminPermissionManagerComponent::Storage,
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
        /// Emitted when a new token is accepted by the vault.
        TokenAccepted: TokenAccepted,
        /// Emitted when a token is removed from the list of accepted tokens.
        TokenRemoved: TokenRemoved,
        /// Flat event for Ownable component events.
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        /// Flat event for Upgradeable component events.
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        /// Flat event for AdminPermissionManager component events.
        #[flat]
        AdminPermissionManagerEvent: AdminPermissionManagerComponent::Event,
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

    /// Event data for when a new token is accepted.
    #[derive(Drop, starknet::Event)]
    pub struct TokenAccepted {
        pub added_by: ContractAddress,
        pub token: ContractAddress,
    }

    /// Event data for when a token is removed.
    #[derive(Drop, starknet::Event)]
    pub struct TokenRemoved {
        pub removed_by: ContractAddress,
        pub token: ContractAddress,
    }

    /// Initializes the Vault contract.
    ///
    /// ### Parameters
    /// - `owner`: The address that will have initial ownership and permissions.
    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, tokens: Array<ContractAddress>,
    ) {
        self.permitted_addresses.entry(owner).write(true);
        self.admin_permission_manager.initialize_admin_permissions(owner);

        let mut i = 0;
        while i != tokens.len() {
            self.accepted_tokens.entry(*tokens.at(i)).write(true);
            self.accepted_tokens_list.push(*tokens.at(i));

            i += 1;
        }
    }

    /// # VaultImpl
    ///
    /// Public-facing implementation of the `IVault` interface.
    #[abi(embed_v0)]
    pub impl VaultImpl of IVault<ContractState> {
        /// Deposits a specified amount of an accepted token into the vault.
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token being deposited.
        /// - `amount`: The amount of funds to deposit as a `u256`.
        /// - `from_address`: The `ContractAddress` from which the funds are being sent.
        ///
        /// ### Panics
        /// - If `amount` or `from_address` is zero.
        /// - If the `token` is not on the accepted list.
        /// - If the direct caller or the source `from_address` is not permitted.
        /// - If the vault is frozen.
        fn deposit_funds(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            from_address: ContractAddress,
        ) {
            assert(amount.is_non_zero(), 'Invalid Amount');
            assert(from_address.is_non_zero(), 'Invalid Address');
            assert(self.is_token_acceptable(token), 'Token not accepted');

            let caller = get_caller_address();
            assert(self.permitted_addresses.entry(caller).read(), 'Direct Caller not permitted');
            assert(
                self.permitted_addresses.entry(from_address).read(), 'Deep Caller Not Permitted',
            );
            assert(
                self.vault_status.read() != VaultStatus::VAULTFROZEN,
                'Vault Frozen for Transactions',
            );

            let timestamp = get_block_timestamp();
            let this_contract = get_contract_address();
            let token_dispatcher = IERC20Dispatcher { contract_address: token };

            token_dispatcher.transfer_from(from_address, this_contract, amount);

            self._record_transaction(token, amount, TransactionType::DEPOSIT, from_address);

            self.emit(DepositSuccessful { caller: from_address, token, timestamp, amount });
        }

        /// Withdraws a specified amount of an accepted token from the vault.
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token being withdrawn.
        /// - `amount`: The amount of funds to withdraw as a `u256`.
        /// - `to_address`: The `ContractAddress` to receive the funds.
        ///
        /// ### Panics
        /// - If `amount` or `to_address` is zero.
        /// - If the `token` is not on the accepted list.
        /// - If the caller is not a permitted address.
        /// - If the vault is frozen.
        /// - If the requested `amount` exceeds the vault's balance for that token.
        fn withdraw_funds(
            ref self: ContractState,
            token: ContractAddress,
            amount: u256,
            to_address: ContractAddress,
        ) {
            self
                .admin_permission_manager
                .require_admin_permission(get_caller_address(), AdminPermission::VAULT_FUNCTIONS);

            assert(amount.is_non_zero(), 'Invalid Amount');
            assert(to_address.is_non_zero(), 'Invalid Address');
            assert(self.is_token_acceptable(token), 'Token not accepted');

            let caller = get_caller_address();
            assert(self.permitted_addresses.entry(caller).read(), 'Direct Caller not permitted');
            assert(self.permitted_addresses.entry(to_address).read(), 'Deep Caller Not Permitted');
            assert(
                self.vault_status.read() != VaultStatus::VAULTFROZEN,
                'Vault Frozen for Transactions',
            );

            let token_balance = self.get_token_balance(token);
            assert(amount <= token_balance, 'Insufficient Balance');

            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.transfer(to_address, amount);

            self._record_transaction(token, amount, TransactionType::WITHDRAWAL, to_address);

            let timestamp = get_block_timestamp();
            self.emit(WithdrawalSuccessful { caller: to_address, token, amount, timestamp });
        }

        /// Allocates a portion of a token's funds to the bonus pool.
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token for the bonus allocation.
        /// - `amount`: The amount to allocate for bonuses.
        /// - `address`: The address initiating the allocation.
        ///
        /// ### Panics
        /// - If the caller is not a permitted address.
        /// - If the `token` is not on the accepted list.
        /// - If the `amount` exceeds the available, non-bonus portion of the token's balance.
        fn add_to_bonus_allocation(
            ref self: ContractState, token: ContractAddress, amount: u256, address: ContractAddress,
        ) {
            self
                .admin_permission_manager
                .require_admin_permission(get_caller_address(), AdminPermission::VAULT_FUNCTIONS);

            let caller = get_caller_address();
            assert(self.permitted_addresses.entry(caller).read(), 'Direct Caller not permitted');
            assert(self.permitted_addresses.entry(address).read(), 'Deep Caller Not Permitted');
            assert(self.is_token_acceptable(token), 'Token not accepted');

            let current_token_balance = self.get_token_balance(token);
            let current_token_bonus = self.bonus_allocations.entry(token).read();
            assert(
                amount <= current_token_balance - current_token_bonus, 'Bonus exceeds available',
            );

            self.bonus_allocations.entry(token).write(current_token_bonus + amount);
            self._record_transaction(token, amount, TransactionType::BONUS_ALLOCATION, address);
        }

        /// Freezes all vault operations as a security measure.
        ///
        /// ### Panics
        /// - If the caller is not a permitted address.
        /// - If the vault is already frozen.
        fn emergency_freeze(ref self: ContractState) {
            self
                .admin_permission_manager
                .require_admin_permission(get_caller_address(), AdminPermission::VAULT_FUNCTIONS);

            let caller = get_caller_address();
            let permitted = self.permitted_addresses.entry(caller).read();
            assert(permitted, 'Direct Caller not permitted');
            assert(self.vault_status.read() != VaultStatus::VAULTFROZEN, 'Vault Already Frozen');

            self.vault_status.write(VaultStatus::VAULTFROZEN);
        }

        /// Resumes vault operations after a freeze.
        ///
        /// ### Panics
        /// - If the caller is not a permitted address.
        /// - If the vault is not currently frozen.
        fn unfreeze_vault(ref self: ContractState) {
            self
                .admin_permission_manager
                .require_admin_permission(get_caller_address(), AdminPermission::VAULT_FUNCTIONS);

            let caller = get_caller_address();
            let permitted = self.permitted_addresses.entry(caller).read();
            assert(permitted, 'Direct Caller not permitted');
            assert(self.vault_status.read() != VaultStatus::VAULTRESUMED, 'Vault Not Frozen');

            self.vault_status.write(VaultStatus::VAULTRESUMED);
        }

        /// Executes a payment from the vault to a specific address using a specified token.
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token for the payment.
        /// - `recipient`: The `ContractAddress` of the member to receive the payment.
        /// - `amount`: The payment amount as a `u256`.
        ///
        /// ### Panics
        /// - If `recipient` or `amount` is zero.
        /// - If the `token` is not on the accepted list.
        /// - If the caller is not a permitted address.
        /// - If the payment `amount` exceeds the vault's balance for that token.
        /// - If the token transfer fails.
        fn pay_member(
            ref self: ContractState,
            token: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            self
                .admin_permission_manager
                .require_admin_permission(get_caller_address(), AdminPermission::VAULT_FUNCTIONS);

            assert(recipient.is_non_zero(), 'Invalid Address');
            assert(amount.is_non_zero(), 'Invalid Amount');
            assert(self.is_token_acceptable(token), 'Token not accepted');

            let caller = get_caller_address();
            assert(self.permitted_addresses.entry(caller).read(), 'Direct Caller not permitted');

            let token_balance = self.get_token_balance(token);
            assert(amount <= token_balance, 'Amount exceeds balance');

            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            let transfered = token_dispatcher.transfer(recipient, amount);
            assert(transfered, 'Transfer failed');

            self._record_transaction(token, amount, TransactionType::PAYMENT, caller);
        }

        /// Adds a new ERC20 token to the list of accepted tokens for the vault. (Owner only)
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token to be accepted.
        ///
        /// ### Panics
        /// - If the caller is not the contract owner.
        /// - If the `token` address is zero.
        /// - If the `token` has already been accepted.
        fn add_accepted_token(ref self: ContractState, token: ContractAddress) {
            self
                .admin_permission_manager
                .require_admin_permission(get_caller_address(), AdminPermission::ADD_VAULT_TOKENS);

            let caller = get_caller_address();
            assert(token.is_non_zero(), 'Invalid token address');
            assert(!self.is_token_acceptable(token), 'Token already accepted');
            assert(self.permitted_addresses.entry(caller).read(), 'Direct Caller not permitted');

            self.accepted_tokens.entry(token).write(true);
            self.accepted_tokens_list.push(token);
            self.emit(TokenAccepted { added_by: get_caller_address(), token });
        }

        /// Removes an ERC20 token from the list of accepted tokens for the vault. (Owner only)
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token to be removed.
        fn remove_accepted_token(ref self: ContractState, token: ContractAddress) {
            self
                .admin_permission_manager
                .require_admin_permission(get_caller_address(), AdminPermission::ADD_VAULT_TOKENS);

            let caller = get_caller_address();
            assert(self.is_token_acceptable(token), 'Token not accepted');
            assert(self.permitted_addresses.entry(caller).read(), 'Direct Caller not permitted');

            self.accepted_tokens.entry(token).write(false);
            self.emit(TokenRemoved { removed_by: get_caller_address(), token });
        }

        /// Retrieves the total balance of a specific token held by the vault.
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token to query.
        ///
        /// ### Returns
        /// - `u256`: The total balance of the specified token.
        fn get_token_balance(self: @ContractState, token: ContractAddress) -> u256 {
            let token_dispatcher = IERC20Dispatcher { contract_address: token };
            token_dispatcher.balance_of(get_contract_address())
        }

        /// Retrieves a list of all tokens the vault is authorized to manage.
        ///
        /// ### Returns
        /// - `Array<ContractAddress>`: A list of accepted token contract addresses.
        fn get_accepted_tokens(self: @ContractState) -> Array<ContractAddress> {
            let mut accepted_tokens: Array<ContractAddress> = array![];
            let mut i = 0;

            while i != self.accepted_tokens_list.len() {
                let token_addr = self.accepted_tokens_list.at(i).read();

                if self.is_token_acceptable(token_addr) {
                    accepted_tokens.append(token_addr);
                }

                i += 1;
            }

            accepted_tokens
        }

        /// Retrieves the vault's balance for every accepted token.
        ///
        /// ### Returns
        /// - `Array<(ContractAddress, u256)>`: A list of tuples, each containing a token address
        /// and its corresponding balance.
        fn get_all_token_balances(self: @ContractState) -> Array<(ContractAddress, u256)> {
            let mut all_balances = array![];
            let mut i = 0;
            let this_contract = get_contract_address();

            while i != self.accepted_tokens_list.len() {
                let token_addr = self.accepted_tokens_list.at(i).read();

                if self.is_token_acceptable(token_addr) {
                    let token_dispatcher = IERC20Dispatcher { contract_address: token_addr };
                    let balance = token_dispatcher.balance_of(this_contract);

                    all_balances.append((token_addr, balance));
                }

                i += 1;
            }

            all_balances
        }

        /// Retrieves the current total amount allocated for bonuses for a specific token.
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token to query.
        ///
        /// ### Returns
        /// - `u256`: The bonus allocation for the specified token.
        fn get_bonus_allocation(self: @ContractState, token: ContractAddress) -> u256 {
            self.bonus_allocations.entry(token).read()
        }

        /// Returns the current operational status of the vault.
        ///
        /// ### Returns
        /// - `VaultStatus`: The vault's current status enum (e.g., `VAULTACTIVE`, `VAULTFROZEN`).
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

        /// Checks whether a specific token is accepted by the vault for transactions.
        ///
        /// ### Parameters
        /// - `token`: The `ContractAddress` of the token to check.
        ///
        /// ### Returns
        /// - `bool`: `true` if the token is accepted, `false` otherwise.
        fn is_token_acceptable(self: @ContractState, token: ContractAddress) -> bool {
            self.accepted_tokens.entry(token).read()
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
            assert(self.permitted_addresses.entry(caller).read(), 'Direct Caller not permitted');
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
            assert(
                self.permitted_addresses.entry(actual_caller).read(), 'Direct Caller not permitted',
            );
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
    }
}
