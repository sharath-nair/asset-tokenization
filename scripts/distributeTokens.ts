import { ethers } from "hardhat";
import { Signer } from "ethers";
import { PropertyToken, PropertyToken__factory } from "../typechain";

// --- CONFIGURATION ---
// !!! REPLACE WITH THE DEPLOYED PropertyToken CONTRACT ADDRESS ON CHAIN !!!
const PROPERTY_TOKEN_CONTRACT_ADDRESS = "0xPropertyTokenContractAddressHere";

// Define the test investor addresses and the amount of tokens they should receive
// Amounts are in the smallest unit (like wei for ETH).
// If the token has 18 decimals, 1 token = 1 * 10^18 units.
const investorsData = [
    {
        address: "0xInvestorAddress1Here", // Replace with actual test investor address
        amount: ethers.parseUnits("10000", 18), // e.g., 10,000 tokens with 18 decimals
    },
    {
        address: "0xInvestorAddress2Here", // Replace with actual test investor address
        amount: ethers.parseUnits("5000", 18), // e.g., 5,000 tokens
    },
    {
        address: "0xInvestorAddress3Here", // Replace with actual test investor address
        amount: ethers.parseUnits("25000", 18), // e.g., 25,000 tokens
    },
];
// --- END CONFIGURATION ---

async function main(): Promise<void> {
    console.log("Starting token distribution script...");

    if (PROPERTY_TOKEN_CONTRACT_ADDRESS === "0xPropertyTokenContractAddressHere") {
        console.error(
            "Please replace '0xPropertyTokenContractAddressHere' with the actual PropertyToken contract address in the script."
        );
        process.exit(1);
    }

    let propertyManager: Signer; // This will be the deployer of PropertyToken
    [propertyManager] = await ethers.getSigners();
    const propertyManagerAddress = await propertyManager.getAddress();

    console.log(`Property Manager (Distributor) Address: ${propertyManagerAddress}`);

    // Get an instance of the PropertyToken contract
    // We use PropertyToken__factory.connect to get an instance attached to the propertyManager signer
    const propertyToken: PropertyToken = PropertyToken__factory.connect(
        PROPERTY_TOKEN_CONTRACT_ADDRESS,
        propertyManager
    );
    const propertyTokenDecimals = await propertyToken.decimals();
    const propertyTokenSymbol: string = await propertyToken.symbol();

    console.log(`Attached to PropertyToken contract at: ${await propertyToken.getAddress()}`);

    // Check Property Manager's initial balance (should hold all tokens)
    const managerInitialBalance = await propertyToken.balanceOf(propertyManagerAddress);
    console.log(
        `Property Manager initial token balance: ${ethers.formatUnits(
            managerInitialBalance,
            propertyTokenDecimals // Dynamically get decimals
        )} ${propertyTokenSymbol}`
    );

    let totalAmountToDistribute = 0n; // Using BigInt for sums
    for (const investor of investorsData) {
        totalAmountToDistribute += investor.amount;
    }

    if (managerInitialBalance < totalAmountToDistribute) {
        console.error(
            `Error: Property Manager balance (${ethers.formatUnits(
                managerInitialBalance,
                18
            )}) is less than total amount to distribute (${ethers.formatUnits(
                totalAmountToDistribute,
                18
            )}).`
        );
        return; // Exit if not enough balance
    }


    for (const investor of investorsData) {
        console.log(
            `\nDistributing ${ethers.formatUnits(
                investor.amount,
                propertyTokenDecimals
            )} ${propertyTokenSymbol} to ${investor.address}...`
        );

        try {
            // Perform the transfer
            const tx = await propertyToken.transfer(investor.address, investor.amount);
            console.log(`  Transaction sent: ${tx.hash}`);
            await tx.wait(); // Wait for the transaction to be mined
            console.log(`  Successfully transferred tokens to ${investor.address}`);

            // Verify new balance (optional, good for confirmation)
            const investorBalance = await propertyToken.balanceOf(investor.address);
            console.log(
                `  ${investor.address} new balance: ${ethers.formatUnits(
                    investorBalance,
                    propertyTokenDecimals
                )} ${propertyTokenSymbol}`
            );
        } catch (error) {
            console.error(`  Failed to transfer tokens to ${investor.address}:`, error);
        }
    }

    // Check Property Manager's final balance
    const managerFinalBalance = await propertyToken.balanceOf(propertyManagerAddress);
    console.log(
        `\nProperty Manager final token balance: ${ethers.formatUnits(
            managerFinalBalance,
            propertyTokenDecimals
        )} ${propertyTokenSymbol}`
    );

    console.log("\nToken distribution script finished.");
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
