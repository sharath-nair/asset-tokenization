# Blockchain-Based Framework for Fractional Ownership of Real Estate

This repository contains the source code for a blockchain-based framework designed to enable the fractional ownership and efficient management of real estate assets. The project demonstrates how tokenization, smart contracts, and Decentralized Autonomous Organizations (DAOs) can be leveraged to democratize access to real estate investment, enhance liquidity, and improve transparency in governance. This work was developed as part of a Master's thesis research project.

## Framework Overview

The proposed framework integrates three critical layers to create a cohesive and compliant tokenization ecosystem:

1. Legal Layer (Conceptual): The framework operates on the premise of a legal Special Purpose Vehicle (SPV) or trust. The SPV legally holds the title to the real estate asset, ensuring that the tokens have a direct, legally-enforceable claim to the underlying property.
2. Technical Layer (Smart Contracts): This is the core on-chain layer implemented in this repository. It consists of a suite of smart contracts that manage the tokenization of ownership, distribution of income, and governance processes.
3. Governance Layer (DAO): Token holders are granted governance rights through a Decentralized Autonomous Organization (DAO). This allows them to collectively vote on important decisions regarding the property, such as major repairs, management changes, or the eventual sale of the asset.

## Smart Contracts

The core logic of the framework is encapsulated in the following Solidity smart contracts:

- PropertyToken.sol: An ERC-20 token contract that represents fractional ownership of the property held in the SPV. It includes several crucial safeguards:Allowlisting: Only KYC/AML verified addresses can hold and transfer tokens.Ownership Caps: Prevents any single entity from accumulating an excessive share of tokens.Lock-up Periods: A configurable period during which tokens cannot be transferred by investors, ensuring market stability post-initial offering.
- IncomeDistribution.sol: A contract designed to automate the distribution of income (e.g., rental revenue) to token holders. The property manager deposits funds into the contract, and token holders can withdraw their proportional share at any time.
- SimpleDAO.sol: A governance contract that allows token holders to create and vote on proposals. It enforces rules such as Quorum (a minimum percentage of tokens must participate) and Supermajority (a high percentage of votes must be in favor) to ensure decisions are well-supported.

## Technology Stack

- Blockchain: Ethereum Virtual Machine (EVM) compatible (e.g., Ethereum, Polygon)
- Smart Contract Language: Solidity (^0.8.20)
- Development Environment: Hardhat
- Testing: Mocha, Chai
- Ethereum Interaction: Ethers.js

## Setup and Installation

Follow these steps to set up a local development environment.

1. Clone the Repository
   `git clone <your-repository-url>`
   `cd <your-project-directory>`

2. Install Node.js and npmEnsure you have a recent version of Node.js (v18 or later) and npm installed.

3. Install Project DependenciesInstall Hardhat and all other required libraries listed in package.json.
   `npm install`

## Usage

### Compiling Contracts

To compile the smart contracts and check for any errors, run:npx hardhat compile
This will generate ABI and bytecode artifacts in the artifacts/ directory.

### Running Tests

This project includes a comprehensive test suite to verify the functionality of all smart contracts. The tests cover deployment, function calls, and all implemented safeguards.
To run the entire test suite:
`npx hardhat test`

To run tests for a specific contract:
`npx hardhat test ./test/PropertyToken.test.js`

## Deploying Contracts

Deployment scripts are located in the `scripts/` directory. You will need to configure your `hardhat.config.js` with network details (e.g., for Ethereum Sepolia testnet or a local network) and a private key (use environment variables for security).
A typical deployment script (`scripts/deploy.js`) would look something like this:

```
async function main() {
// Deployment logic for PropertyToken, IncomeDistribution, and SimpleDAO...
}

main().catch((error) => {
console.error(error);
process.exitCode = 1;
});
```

To run the deployment script on a specific network:
`npx hardhat run scripts/deploy.js --network <your-network-name>`

License
This project is licensed under the MIT License.
