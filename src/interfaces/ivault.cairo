use littlefinger::structs::vault_structs::{Transaction, VaultStatus};
use starknet::ContractAddress;

/// # IVault
///
/// This trait defines the public interface for a multi-token vault component. It outlines the core
/// functionalities for managing an organization's funds across various ERC20 tokens, including
/// deposits, withdrawals, member payments, and security measures.
#[starknet::interface]
pub trait IVault<TContractState> {
    /// # deposit_funds
    ///
    /// Deposits a specified amount of an accepted token into the vault.
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `token`: The `ContractAddress` of the token being deposited.
    /// - `amount`: The amount of funds to deposit as a `u256`.
    /// - `from_address`: The `ContractAddress` from which the funds are being sent.
    fn deposit_funds(
        ref self: TContractState,
        token: ContractAddress,
        amount: u256,
        from_address: ContractAddress,
    );

    /// # withdraw_funds
    ///
    /// Withdraws a specified amount of an accepted token from the vault.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `token`: The `ContractAddress` of the token being withdrawn.
    /// - `amount`: The amount of funds to withdraw as a `u256`.
    /// - `to_address`: The `ContractAddress` to receive the funds.
    fn withdraw_funds(
        ref self: TContractState, token: ContractAddress, amount: u256, to_address: ContractAddress,
    );

    /// # emergency_freeze
    ///
    /// Halts all outbound transactions from the vault as a global security measure.
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    fn emergency_freeze(ref self: TContractState);

    /// # unfreeze_vault
    ///
    /// Lifts the emergency freeze, restoring normal vault operations.
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    fn unfreeze_vault(ref self: TContractState);

    /// # pay_member
    ///
    /// Executes a payment from the vault to a specific member's address using a specified token.
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `token`: The `ContractAddress` of the token for the payment.
    /// - `recipient`: The `ContractAddress` of the member to receive the payment.
    /// - `amount`: The payment amount as a `u256`.
    fn pay_member(
        ref self: TContractState, token: ContractAddress, recipient: ContractAddress, amount: u256,
    );

    /// # add_to_bonus_allocation
    ///
    /// Allocates funds of a specific token for bonus payments.
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `token`: The `ContractAddress` of the token for the bonus allocation.
    /// - `amount`: The amount to allocate for bonuses.
    /// - `address`: The address initiating the allocation.
    fn add_to_bonus_allocation(
        ref self: TContractState, token: ContractAddress, amount: u256, address: ContractAddress,
    );

    /// # add_accepted_token
    ///
    /// Adds a new ERC20 token to the list of accepted tokens for the vault. (Owner only)
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `token`: The `ContractAddress` of the token to be accepted.
    fn add_accepted_token(ref self: TContractState, token: ContractAddress);

    /// # remove_accepted_token
    ///
    /// Removes an ERC20 token from the list of accepted tokens for the vault. (Owner only)
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `token`: The `ContractAddress` of the token to be removed.
    fn remove_accepted_token(ref self: TContractState, token: ContractAddress);

    /// # get_token_balance
    ///
    /// Retrieves the total balance of a specific token held by the vault.
    ///
    /// ## Parameters
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `token`: The `ContractAddress` of the token to query.
    ///
    /// ## Returns
    /// The total balance of the specified token as a `u256`.
    fn get_token_balance(self: @TContractState, token: ContractAddress) -> u256;

    /// # get_all_token_balances
    ///
    /// Retrieves the vault's balance for every accepted token.
    ///
    /// ## Parameters
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    /// An `Array` of (`ContractAddress`, `u256`) tuples representing each token and its balance.
    fn get_all_token_balances(self: @TContractState) -> Array<(ContractAddress, u256)>;


    /// # get_accepted_tokens
    ///
    /// Retrieves a list of all tokens the vault is authorized to manage.
    ///
    /// ## Parameters
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    /// An `Array<ContractAddress>` of accepted tokens.
    fn get_accepted_tokens(self: @TContractState) -> Array<ContractAddress>;

    /// # get_vault_status
    ///
    /// Returns the current operational status of the vault (e.g., Active, Frozen).
    ///
    /// ## Parameters
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    /// The current `VaultStatus` enum.
    fn get_vault_status(self: @TContractState) -> VaultStatus;

    /// # get_bonus_allocation
    ///
    /// Retrieves the current total amount allocated for bonuses for a specific token.
    ///
    /// ## Parameters
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `token`: The `ContractAddress` of the token to query.
    ///
    /// ## Returns
    /// The bonus allocation for the specified token as a `u256`.
    fn get_bonus_allocation(self: @TContractState, token: ContractAddress) -> u256;

    /// # is_token_acceptable
    ///
    /// Checks whether a specific token is accepted by the vault for transactions.
    ///
    /// ## Parameters
    /// - `self: @TContractState`: A snapshot of the contract's state.
    /// - `token`: The `ContractAddress` of the token to check.
    ///
    /// ## Returns
    /// A boolean value: `true` if the token is accepted, `false` otherwise.
    fn is_token_acceptable(self: @TContractState, token: ContractAddress) -> bool;

    /// # get_transaction_history
    ///
    /// Retrieves a log of all transactions processed by the vault.
    ///
    /// ## Parameters
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    /// An `Array<Transaction>` containing the vault's transaction history.
    fn get_transaction_history(self: @TContractState) -> Array<Transaction>;

    /// # allow_org_core_address
    ///
    /// Grants permission to a contract to interact with the vault.
    ///
    /// ## Parameters
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `org_address`: The `ContractAddress` of the contract to authorize.
    fn allow_org_core_address(ref self: TContractState, org_address: ContractAddress);
}
