use starknet::ContractAddress;
// use super::member_structs::MemberConfig;
// use super::organization::{OrganizationConfig, OwnerInit};
// use super::voting::PollConfigParams;

// do not use this..
#[derive(Drop, Copy, PartialEq, Serde, Default)]
pub struct CoreConfigParams { // is promotion automatic? pass in the available algorithms, based on what?
}

#[starknet::storage_node]
pub struct CoreConfig {}

#[derive(Drop, Copy, Serde, PartialEq, Default)]
pub enum Visibility {
    #[default]
    Public,
    Private,
}

#[derive(Drop, Copy, Serde, PartialEq, Default)]
pub struct PaymentConfig {
    pub broker: Option<ContractAddress>,
    pub payment_type: Option<PaymentType>,
}

// There might be other payment types available for this Config
#[derive(Drop, Copy, Serde, Default, PartialEq)]
pub enum PaymentType {
    #[default]
    Basic,
    Stream,
}

// Only if Stream, retrieve the stream details
#[derive(Drop, Copy, Serde, Default)]
pub struct StreamDetails { // init stream details
}

pub fn get_default_stream_details() -> StreamDetails {
    Default::default()
}

#[starknet::storage_node]
pub struct CoreConfigNode { // params: CoreConfigParams,
}

