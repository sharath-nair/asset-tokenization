import { ethers, run, network } from "hardhat"; // Import `run` for verification and `network`
import { Contract, ContractFactory, Signer, BaseContract } from "ethers"; // For type annotations

// Choose which contract example to deploy by uncommenting one
const CONTRACT_TO_DEPLOY: "Greeter" | "Lock" = "Greeter"; // Or "Lock"

async function main() {
  const [deployer]: Signer[] = await ethers.getSigners(); // Get the deployer account

  console.log(
    `Deploying ${CONTRACT_TO_DEPLOY} contract with the account:`,
    await deployer.getAddress()
  );
  console.log(
    "Account balance:",
    (await ethers.provider.getBalance(deployer)).toString()
  );

  let contract: BaseContract; // Using BaseContract for broader compatibility initially
  let contractFactory: ContractFactory;
  let constructorArgs: any[] = []; // Array to hold constructor arguments

  // --- Contract Specific Deployment Logic ---
  if (CONTRACT_TO_DEPLOY === "Greeter") {
    const initialGreeting: string = "Hello, Hardhat Developer!";
    constructorArgs = [initialGreeting];
    contractFactory = await ethers.getContractFactory("Greeter");
    console.log(`Deploying Greeter with greeting: "${initialGreeting}"`);
    contract = await contractFactory.deploy(...constructorArgs);
  } else if (CONTRACT_TO_DEPLOY === "Lock") {
    // For Lock.sol, which takes an unlockTime and an ETH value
    const currentTimestampInSeconds: number = Math.round(Date.now() / 1000);
    const ONE_YEAR_IN_SECS: number = 365 * 24 * 60 * 60;
    const unlockTime: number = currentTimestampInSeconds + ONE_YEAR_IN_SECS;
    const lockedAmount = ethers.parseEther("0.0001"); // Deploy with 0.0001 ETH

    constructorArgs = [unlockTime];
    contractFactory = await ethers.getContractFactory("Lock");
    console.log(`Deploying Lock contract, unlocking at ${new Date(unlockTime * 1000).toISOString()} with ${ethers.formatEther(lockedAmount)} ETH`);
    contract = await contractFactory.deploy(...constructorArgs, { value: lockedAmount });
  } else {
    console.error("Invalid CONTRACT_TO_DEPLOY value. Please choose 'Greeter' or 'Lock'.");
    process.exit(1);
  }
  // --- End Contract Specific Deployment Logic ---

  await contract.waitForDeployment(); // Wait for the deployment transaction to be mined

  const contractAddress: string = await contract.getAddress();
  console.log(`${CONTRACT_TO_DEPLOY} contract deployed to address: ${contractAddress}`);

  // --- Verification on Etherscan/Block Explorer (Optional) ---
  // Only verify on live testnets or mainnet, not on local Hardhat network
  if (network.config.chainId && network.config.chainId !== 31337 && process.env.ETHERSCAN_API_KEY) {
    console.log("Waiting for block confirmations before verification...");
    // Wait for a few blocks to be mined to ensure Etherscan has indexed the contract
    // The actual number of confirmations needed can vary.
    // For `waitForDeployment`, the transaction is already mined.
    // However, Etherscan might need a bit more time.
    // Directly calling `deploymentTransaction()` and `wait()` might be redundant
    // if `waitForDeployment()` already sufficiently waits.
    // Let's explicitly wait for a few confirmations on the transaction receipt.
    const deploymentReceipt = await contract.deploymentTransaction()?.wait(5); // Wait for 5 confirmations
    if (deploymentReceipt) {
        console.log(`Confirmed in block ${deploymentReceipt.blockNumber}`);
    } else {
        console.warn("Could not get deployment receipt for additional confirmations.");
    }


    console.log("Attempting to verify contract on Etherscan...");
    try {
      await run("verify:verify", {
        address: contractAddress,
        constructorArguments: constructorArgs,
        // If your contract is in a subdirectory, e.g., contracts/tokens/MyToken.sol
        // contract: "contracts/tokens/MyToken.sol:MyToken",
      });
      console.log("Contract verified successfully!");
    } catch (error: any) {
      if (error.message.toLowerCase().includes("already verified")) {
        console.log("Contract is already verified!");
      } else {
        console.error("Verification failed:", error);
      }
    }
  } else if (network.config.chainId === 31337) {
    console.log("Skipping verification for local Hardhat network.");
  } else if (!process.env.ETHERSCAN_API_KEY) {
    console.log("Skipping verification: ETHERSCAN_API_KEY not set in .env file.");
  }
  // --- End Verification ---
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
