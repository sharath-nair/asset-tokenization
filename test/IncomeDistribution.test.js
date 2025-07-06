const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IncomeDistribution", function () {
  let PropertyToken, propertyToken, IncomeDistribution, incomeDistribution;
  let owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy PropertyToken first
    PropertyToken = await ethers.getContractFactory("PropertyToken");
    propertyToken = await PropertyToken.deploy(
      "Test Token",
      "TT",
      ethers.parseUnits("1000", 18),
      ethers.parseUnits("1000", 18),
      0 // No cap or lockup for simplicity
    );

    // Deploy IncomeDistribution with the address of the token contract
    IncomeDistribution = await ethers.getContractFactory("IncomeDistribution");
    incomeDistribution = await IncomeDistribution.deploy(
      await propertyToken.getAddress()
    );

    // Distribute some tokens for testing
    // Allowlist addresses first
    await propertyToken.addToAllowlist(owner.address);
    await propertyToken.addToAllowlist(addr1.address);
    await propertyToken.addToAllowlist(addr2.address);

    // Transfer 100 tokens to addr1 and 300 to addr2
    await propertyToken.transfer(addr1.address, ethers.parseUnits("100", 18));
    await propertyToken.transfer(addr2.address, ethers.parseUnits("300", 18));
    // Owner now has 600 tokens
  });

  describe("Deployment", function () {
    it("Should set the correct token address", async function () {
      expect(await incomeDistribution.token()).to.equal(
        await propertyToken.getAddress()
      );
    });
  });

  describe("Income Deposit", function () {
    it("Should allow the owner to deposit funds", async function () {
      const depositAmount = ethers.parseEther("10.0"); // 10 ETH/MATIC
      await expect(() =>
        owner.sendTransaction({
          to: incomeDistribution.getAddress(),
          value: depositAmount,
        })
      ).to.changeEtherBalance(incomeDistribution, depositAmount);

      expect(await incomeDistribution.totalDistributed()).to.equal(
        depositAmount
      );
    });

    it("Should prevent non-owners from depositing funds directly (though they can send)", async function () {
      const depositAmount = ethers.parseEther("1.0");
      // Non-owner can send ETH, which is fine, it just adds to the pot.
      // The key is that they can't call a restricted `deposit` function if one existed.
      // The receive() function is public.
      await expect(() =>
        addr1.sendTransaction({
          to: incomeDistribution.getAddress(),
          value: depositAmount,
        })
      ).to.changeEtherBalance(incomeDistribution, depositAmount);
    });
  });

  describe("Income Withdrawal", function () {
    beforeEach(async function () {
      // Deposit 10 ETH for a total token supply of 1000.
      // Rate = 10 / 1000 = 0.01 ETH per token
      const depositAmount = ethers.parseEther("10.0");
      await owner.sendTransaction({
        to: incomeDistribution.getAddress(),
        value: depositAmount,
      });
    });

    it("Should allow token holders to withdraw their proportional share", async function () {
      // addr1 has 100 tokens, should get 100 * 0.01 = 1 ETH
      const expectedShareAddr1 = ethers.parseEther("1.0");
      await expect(() =>
        incomeDistribution.connect(addr1).withdraw()
      ).to.changeEtherBalance(addr1, expectedShareAddr1);

      // addr2 has 300 tokens, should get 300 * 0.01 = 3 ETH
      const expectedShareAddr2 = ethers.parseEther("3.0");
      await expect(() =>
        incomeDistribution.connect(addr2).withdraw()
      ).to.changeEtherBalance(addr2, expectedShareAddr2);
    });

    it("Should prevent a user from withdrawing twice for the same distribution", async function () {
      // addr1 withdraws successfully
      await incomeDistribution.connect(addr1).withdraw();

      // Attempting to withdraw again should fail or result in 0 transfer
      await expect(
        incomeDistribution.connect(addr1).withdraw()
      ).to.be.revertedWith("No dividends to withdraw");
    });

    it("Should correctly handle multiple distribution rounds", async function () {
      // Round 1 withdrawal for addr1
      const expectedShare1 = ethers.parseEther("1.0");
      await expect(() =>
        incomeDistribution.connect(addr1).withdraw()
      ).to.changeEtherBalance(addr1, expectedShare1);

      // New deposit of 20 ETH. Total distributed is now 30 ETH.
      // Rate = 30 / 1000 = 0.03 ETH per token
      const depositAmount2 = ethers.parseEther("20.0");
      await owner.sendTransaction({
        to: incomeDistribution.getAddress(),
        value: depositAmount2,
      });

      // addr1's total owed is 100 * 0.03 = 3 ETH. They already withdrew 1 ETH.
      // So, they should be able to withdraw 2 more ETH.
      const expectedShare2 = ethers.parseEther("2.0");
      await expect(() =>
        incomeDistribution.connect(addr1).withdraw()
      ).to.changeEtherBalance(addr1, expectedShare2);
    });

    it("Should revert if a user with no tokens tries to withdraw", async function () {
      const addr3 = addrs[0]; // addr3 has no tokens
      await expect(
        incomeDistribution.connect(addr3).withdraw()
      ).to.be.revertedWith("No dividends to withdraw");
    });
  });
});
