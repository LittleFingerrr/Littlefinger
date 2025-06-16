## Project Structure

(Leave this for Maintainers to change)

Components in the project are as follows:
- Disbursement Component
- Member Manager Component
- Organization Component
<!-- - The Voting Component are not really needed for this  -->

Contracts in the Project are as follows:
- Organization Core Contract
- Organization Vault Contract
- Contract Factory

### Flow
### Member Manager Component:
This is embedded directly as ABI, as we need its functions to use directly when registering members, according to the contract.
The abilities it gives us are as follows:

- It gives the ability for orgs to invite members and have members accept their invites
- It gives the ability for member state/status to be tracked and changed across the project
- It gives the ability to read members also from the storage

### Organization Component:
This is the component that handles registration of the organization on the dApp, and changes that can be made to the organization.
In truth, the organization will be registered through the action of the organization core contract constructor, and the necessary
arguments required for this will be supplied during deployment. 


### DIsbursement Component:
This handles things that have to do with disbursement such as creating disbursement schedules, starting and ending them, etc. It will be
embedded as ABI directly, and also be used within the core contract.
It gives the options to:
- crud disbursement schedules
- compute single member renumeration
- retry failed disbursement


### Vault Contract:
This contract holds and manages the organization's funds. Interactions with it are going to be through cross-contract interactions i.e from the core to it. The abilities it has are:
- Deposit and withdraw funds
- Freeze vault and unfreeze vault
- Read vault balance
- Pay single member

The pay single member ability will be used with the compute renumeration to pay members of the org


### Org Core Contract
This will help to call all the functions (when necessary), and do things we might need to do walahi. I don't really know for now


### Factory Contract
This is where we will deploy cases of the contract, using the class hash and stuff. We will also record the organizations registered on our dApp (using our protocol). For very important uses:
- This has to be optimized later also for the member dashboard, but it will be looked at when the core is complete


### Things done during deployment
- Register the organization by supplying the necessary arguments, which will initialize the organization component
- Initialize the member component - its initializer is writing the first admin. This means one of the steps on the frontend required in
filling the form will be to register the first member of the organization.
- No need to initialize the disburse component anyway, connect the vault with the organization