import { ethers, run, network } from "hardhat"; // Import `run` for verification and `network`
import { Contract, ContractFactory, Signer, BaseContract } from "ethers"; // For type annotations
import { PropertyToken, PropertyToken__factory } from "../typechain";

async function main() {
  const [deployer]: Signer[] = await ethers.getSigners(); // Get the deployer account

  let contract: BaseContract; // Using BaseContract for broader compatibility initially
  // let contractFactory: ContractFactory;

  const deployerAddress = await deployer.getAddress();

  // Deploy the PropertyToken ERC20
  const propertyTokenName: string = "Ocean View Villa Shares"; // Your desired name
  const propertyTokenSymbol: string = "OVVS";            // Your desired symbol
  // For total supply, ethers.parseUnits is useful for handling decimals.
  // e.g., 1,000,000 tokens with 18 decimals
  const initialTotalSupply = ethers.parseUnits("1000000", 18);

  console.log(`Deploying PropertyToken with the account: ${deployerAddress}`);
  console.log(
    "Account balance:",
    (await ethers.provider.getBalance(deployer)).toString()
  );

  const PropertyTokenFactory: PropertyToken__factory = await ethers.getContractFactory("PropertyToken");
  const propertyToken: PropertyToken = (await PropertyTokenFactory.connect(deployer).deploy(
      deployerAddress,   // initialOwner (deployer acts as SPV manager for MVP)
      propertyTokenName,
      propertyTokenSymbol,
      initialTotalSupply
  )) as PropertyToken; // Type assertion if using TypeChain

  await propertyToken.waitForDeployment(); // Wait for the deployment transaction to be mined

  const contractAddress = await propertyToken.getAddress();
  console.log(`PropertyToken deployed to: ${contractAddress}`);

  // You can also call the view functions to confirm
  const deployedName: string = await propertyToken.name();
  const deployedSymbol: string = await propertyToken.symbol();
  const owner: string = await propertyToken.owner(); // Example of using an Ownable function

  console.log(`Deployed Token Name: ${deployedName}`);
  console.log(`Deployed Token Symbol: ${deployedSymbol}`);
  console.log(`Contract Owner: ${owner}`);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
