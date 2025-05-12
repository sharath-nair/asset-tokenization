import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config"; // Loads environment variables from .env file

const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "ethereum-sepolia-rpc.publicnode.com"; // Fallback or default
const PRIVATE_KEY = process.env.PRIVATE_KEY || "your-private-key"; // Fallback or default
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "your-etherscan-api-key"; // Fallback or default

const config: HardhatUserConfig = {
  solidity: "0.8.28", // Solidity compiler version
  defaultNetwork: "hardhat", // Optional: set default network
  networks: {
    hardhat: {
      // Configuration for the local Hardhat Network
    },
    sepolia: {
      url: SEPOLIA_RPC_URL,
      accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
      chainId: 11155111, // Sepolia's chain ID
      // gasPrice: 20000000000, // Optional
      // gas: 6000000, // Optional
    },
  },
  etherscan: {
    apiKey: {
      sepolia: ETHERSCAN_API_KEY,
      // mainnet: process.env.ETHERSCAN_API_KEY_MAINNET || ""
    }
  },
  sourcify: {
    enabled: true,
  },
  // paths: {
  //   sources: "./contracts",
  //   tests: "./test",
  //   cache: "./cache",
  //   artifacts: "./artifacts"
  // },
  // mocha: {
  //   timeout: 40000
  // }
};

export default config;
