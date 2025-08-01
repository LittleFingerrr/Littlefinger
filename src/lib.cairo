pub mod contracts {
    pub mod core;
    pub mod factory;
    pub mod vault;
}
pub mod interfaces {
    pub mod dao_controller;
    pub mod icore;
    pub mod idisbursement;
    pub mod ifactory;
    pub mod imember_manager;
    pub mod iorganization;
    pub mod ivault;
}

pub mod components {
    pub mod dao_controller;
    pub mod disbursement;
    pub mod member_manager;
    pub mod organization;
}

pub mod structs {
    pub mod base;
    pub mod core;
    pub mod dao_controller;
    pub mod disbursement_structs;
    pub mod member_structs;
    pub mod organization;
    pub mod vault_structs;
}

#[cfg(test)]
pub mod tests {
    pub mod test_dao_controller;
    pub mod test_disbursement;
    pub mod test_member_manager;
    pub mod mocks {
        pub mod mock_dao_controller;
        pub mod mock_disbursement;
        pub mod mock_member_manager;
    }
    pub mod utils {
        pub mod factory;
    }
}
