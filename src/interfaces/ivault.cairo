use littlefinger::structs::vault_structs::{Transaction, VaultStatus};
use starknet::ContractAddress;

/// # IVault
///
/// This trait defines the public interface for a vault component. It outlines the core
/// functionalities for managing an organization's funds, including deposits, withdrawals,
/// member payments, and security measures like emergency freezes. The interface is designed
/// to be implemented by a Starknet component responsible for the secure handling and
/// tracking of financial assets.
#[starknet::interface]
pub trait IVault<TContractState> {
    /// # deposit_funds
    ///
    /// Deposits a specified amount of a given token into the vault.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `amount`: The amount of funds to deposit as a `u256`.
    /// - `address`: The `ContractAddress` of the token being deposited.
    fn deposit_funds(ref self: TContractState, amount: u256, address: ContractAddress);

    /// # withdraw_funds
    ///
    /// Withdraws a specified amount of a given token from the vault. This is a privileged action.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `amount`: The amount of funds to withdraw as a `u256`.
    /// - `address`: The `ContractAddress` of the token being withdrawn.
    fn withdraw_funds(ref self: TContractState, amount: u256, address: ContractAddress);

    /// # emergency_freeze
    ///
    /// Halts all outbound transactions from the vault. This function serves as a security
    /// measure to prevent unauthorized fund movements in case of a compromise.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    fn emergency_freeze(ref self: TContractState);

    /// # unfreeze_vault
    ///
    /// Lifts the emergency freeze, restoring normal vault operations. This is a privileged action.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    fn unfreeze_vault(ref self: TContractState);

    // fn bulk_transfer(ref self: TContractState, recipients: Span<ContractAddress>);

    /// # pay_member
    ///
    /// Executes a payment from the vault to a specific member's address.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `recipient`: The `ContractAddress` of the member to receive the payment.
    /// - `amount`: The payment amount as a `u256`.
    fn pay_member(ref self: TContractState, recipient: ContractAddress, amount: u256);

    /// # add_to_bonus_allocation
    ///
    /// Allocates a certain amount of funds for bonus payments. These funds are tracked
    /// separately from the main available balance.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `amount`: The amount to allocate for bonuses.
    /// - `address`: The `ContractAddress` of the token for the bonus allocation.
    fn add_to_bonus_allocation(ref self: TContractState, amount: u256, address: ContractAddress);

    /// # get_balance
    ///
    /// Retrieves the total balance of the vault for all managed assets.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The total balance as a `u256`.
    fn get_balance(self: @TContractState) -> u256;

    /// # get_available_funds
    ///
    /// Retrieves the amount of funds available for general use, excluding any earmarked
    /// allocations like bonuses.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The available funds as a `u256`.
    fn get_available_funds(self: @TContractState) -> u256;

    /// # get_vault_status
    ///
    /// Returns the current operational status of the vault (e.g., Active, Frozen).
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The current `VaultStatus` enum.
    fn get_vault_status(self: @TContractState) -> VaultStatus;

    /// # get_bonus_allocation
    ///
    /// Retrieves the current total amount allocated for bonuses.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// The total bonus allocation as a `u256`.
    fn get_bonus_allocation(self: @TContractState) -> u256;

    /// # get_transaction_history
    ///
    /// Retrieves a log of all transactions processed by the vault.
    ///
    /// ## Parameters
    ///
    /// - `self: @TContractState`: A snapshot of the contract's state.
    ///
    /// ## Returns
    ///
    /// An `Array<Transaction>` containing the vault's transaction history.
    fn get_transaction_history(self: @TContractState) -> Array<Transaction>;

    /// # allow_org_core_address
    ///
    /// Grants permission to a core organization contract to interact with the vault.
    /// This is necessary for enabling automated payments and other coordinated actions.
    ///
    /// ## Parameters
    ///
    /// - `ref self: TContractState`: The current state of the contract.
    /// - `org_address`: The `ContractAddress` of the core organization contract to authorize.
    fn allow_org_core_address(ref self: TContractState, org_address: ContractAddress);
}
