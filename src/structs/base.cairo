use core::num::traits::Zero;
use starknet::ContractAddress;

pub impl ContractAddressDefault of Default<ContractAddress> {
    #[inline(always)]
    fn default() -> ContractAddress {
        Zero::zero()
    }
}
