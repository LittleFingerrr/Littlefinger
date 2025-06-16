use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, Debug, PartialEq, starknet::Store)]
pub struct Transaction {
    pub transaction_type: TransactionType,
    pub token: ContractAddress,
    pub amount: u256,
    pub timestamp: u64,
    pub tx_hash: felt252,
    pub caller: ContractAddress,
}

#[derive(Copy, Drop, Serde, Debug, PartialEq, starknet::Store)]
pub enum TransactionType {
    #[default]
    DEPOSIT,
    WITHDRAWAL,
    PAYMENT,
    BONUS_ALLOCATION,
    // VAULTFREEZE,
// VAULTRESUME
// The intention is to put the Vault freeze and vault resume as transactions, but plan changed
}

#[derive(Copy, Drop, Serde, Debug, PartialEq, starknet::Store)]
pub enum VaultStatus {
    #[default]
    VAULTRESUMED,
    VAULTFROZEN,
}
