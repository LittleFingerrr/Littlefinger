# Littlefinger 🏦

> **A decentralized payroll and treasury management system built on Starknet**

Littlefinger is a comprehensive DeFi protocol that enables organizations to manage their membership/manpower, manage their treasury, handle member payroll, and automate disbursements on the Starknet blockchain. Named after the master of coin from Game of Thrones, this project brings sophisticated financial management to the decentralized world.

## 🎯 Project Overview

Littlefinger addresses the growing need for decentralized organizations (DAOs, Web3 companies, etc.) to have robust treasury and payroll management systems. It provides:

- **Automated Payroll Management**: Streamlined member compensation with role-based remuneration
- **Treasury Management**: Secure vault system for fund storage and management
- **Disbursement Automation**: Scheduled and recurring payment distributions
- **Member Management**: Comprehensive member onboarding, role management, and status tracking
- **Multi-Organization Support**: Factory pattern for deploying multiple organization instances

## 🏗️ Architecture

### Core Components

The project is built using a modular component-based architecture with the following key components:

#### 📋 **Member Manager Component**
- Member registration and onboarding
- Role-based access control (Contractor, Employee, Admin)
- Member status management (Active, Suspended, etc.)
- Invitation system with acceptance workflows
- Base pay and remuneration tracking

#### 💰 **Disbursement Component**
- Automated payroll scheduling (one-time and recurring)
- Role-weighted bonus distribution
- Failed disbursement tracking and retry mechanisms
- Payment interval management
- Disbursement history and analytics

#### 🏢 **Organization Component**
- Organization registration and configuration
- Metadata management (name, IPFS URL, organization type)
- Vault integration and fund allocation
- Organization-wide settings and policies

#### 🏦 **Vault Contract**
- Secure fund storage and management
- Deposit and withdrawal operations
- Emergency freeze/unfreeze capabilities
- Transaction history and audit trails
- Bonus allocation management

### Contract Structure

```
Littlefinger/
├── Factory Contract          # Deploys and manages organizations
├── Core Contract            # Main organization logic and coordination
├── Vault Contract           # Treasury and fund management
└── Components               # Modular functionality blocks
    ├── Member Manager       # Member lifecycle management
    ├── Disbursement         # Payroll automation
    ├── Organization         # Organization configuration
    └── DAO Controller       # Governance integration
```

## 🚀 Key Features

### 🔐 **Secure Treasury Management**
- Multi-signature vault operations
- Emergency freeze capabilities
- Comprehensive transaction logging
- Role-based access controls

### 👥 **Flexible Member Management**
- Multiple member roles (Contractor, Employee, Admin)
- Invitation-based onboarding
- Member status tracking
- Configurable remuneration structures

### 💸 **Automated Payroll System**
- Scheduled disbursements (one-time and recurring)
- Role-weighted bonus distribution
- Failed payment retry mechanisms
- Payment interval customization

### 🏭 **Factory Deployment Pattern**
- One-click organization deployment
- Standardized contract templates
- Upgradeable contract architecture
- Multi-organization support

### 🔄 **Upgradeable Architecture**
- OpenZeppelin upgradeable components
- Backward-compatible updates
- Governance-controlled upgrades

## 🛠️ Technology Stack

- **Blockchain**: Starknet (Layer 2 scaling solution)
- **Language**: Cairo (Starknet's native language)
- **Framework**: Scarb (Cairo package manager)
- **Testing**: Forge (Starknet testing framework)
- **Components**: OpenZeppelin Cairo contracts
- **Architecture**: Component-based modular design

## 📦 Installation & Setup

### Prerequisites

- [Scarb](https://docs.swmansion.com/scarb/docs/installing-scarb.html) - Cairo package manager
- [Starknet Foundry](https://foundry-rs.github.io/starknet-foundry/) - Testing framework

### Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/LittleFingerrr/Littlefinger
   cd Littlefinger
   ```

2. **Install dependencies**
   ```bash
   scarb build
   ```

3. **Run tests**
   ```bash
   scarb test
   ```

### Development Setup

1. **Build the project**
   ```bash
   scarb build
   ```

2. **Run specific tests**
   ```bash
   scarb test --package littlefinger
   ```

3. **Check for linting issues**
   ```bash
   scarb check
   ```

## 🧪 Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
scarb test

# Run specific test files
scarb test --package littlefinger test_factory
scarb test --package littlefinger test_vault

# Run with coverage
scarb test --coverage
```

### Test Structure

- **Factory Tests**: Organization deployment and management
- **Vault Tests**: Treasury operations and security
- **Component Tests**: Individual component functionality
- **Integration Tests**: End-to-end workflows

## 📚 Usage Examples

### Deploying an Organization

```cairo
// Setup new organization
let (org_address, vault_address) = factory.setup_org(
    available_funds: 1000000000000000000,
    starting_bonus_allocation: 500000000000000000,
    token: token_address,
    salt: 'org_salt',
    owner: org_owner,
    name: "My DAO",
    ipfs_url: "ipfs://metadata",
    first_admin_fname: 'John',
    first_admin_lname: 'Doe',
    first_admin_alias: 'johndoe',
    organization_type: 1
);
```

### Managing Members

```cairo
// Add a new member
core.add_member(
    fname: 'Alice',
    lname: 'Smith',
    alias: 'alice',
    role: 5, // Employee role
    address: alice_address
);

// Invite a member
let invite_id = core.invite_member(
    role: 1, // Contractor role
    address: bob_address,
    remuneration: 100000000000000000
);
```

### Setting Up Disbursements

```cairo
// Create a recurring disbursement schedule
core.initialize_disbursement_schedule(
    schedule_type: 0, // Recurring
    start: 1640995200, // Unix timestamp
    end: 1672531200,
    interval: 2592000 // 30 days in seconds
);

// Execute scheduled payout
core.schedule_payout();
```

## 🔧 Configuration

Setup configuration in the `snfoundry.toml` file

### Scarb Configuration

The project uses Scarb for dependency management. Key dependencies include:

- `starknet = "2.11.2"` - Starknet contract framework
- `openzeppelin = "1.0.0"` - Security components
- `snforge_std = "0.40.0"` - Testing framework

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit your changes** (`git commit -m 'Add amazing feature'`)
4. **Push to the branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

### Development Guidelines

- Follow Cairo coding standards
- Write comprehensive tests for new features
- Update documentation for API changes
- Ensure all tests pass before submitting PRs

## 📋 Project Status

### ✅ Completed Features

- [x] Core contract architecture
- [x] Member management system
- [x] Disbursement automation
- [x] Vault treasury management
- [x] Factory deployment pattern
- [x] Basic testing framework
- [x] Upgradeable contract support

### 🚧 In Progress

- [ ] Frontend dashboard development
- [ ] Advanced governance features
- [ ] Multi-token support
- [ ] Analytics and reporting
- [ ] Mobile application

### 📅 Roadmap

- [ ] **Q1 2024**: Beta testing and security audits
- [ ] **Q2 2024**: Mainnet deployment
- [ ] **Q3 2024**: Frontend launch and user onboarding
- [ ] **Q4 2024**: Advanced features and integrations

## 🔒 Security

### Audits

- Security audits are planned before mainnet deployment
- All contracts use OpenZeppelin security components
- Comprehensive test coverage for edge cases

### Best Practices

- Role-based access controls
- Emergency pause mechanisms
- Comprehensive event logging
- Upgradeable architecture for security patches

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- **Starknet Foundation** for the Cairo language and ecosystem
- **OpenZeppelin** for security components and best practices
- **Starknet Foundry** for the testing framework
- **Community contributors** for feedback and improvements

## 📞 Support

- **Documentation**: [Project Wiki](link-to-wiki)
- **Discord**: [Community Server](link-to-discord)
- **Twitter**: [@LittlefingerDAO](link-to-twitter)
- **Email**: support@littlefinger.xyz

---

**Built with ❤️ for the decentralized future**

*"A Lannister always pays his debts, but with Littlefinger, everyone gets paid on time."*
