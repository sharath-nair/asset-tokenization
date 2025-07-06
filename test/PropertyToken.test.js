const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PropertyToken", function () {
  let PropertyToken, propertyToken, owner, addr1, addr2, addrs;
  const TOTAL_SUPPLY = ethers.parseUnits("1000000", 18); // 1 Million tokens
  const OWNERSHIP_CAP = ethers.parseUnits("100000", 18); // 10% cap
  const LOCKUP_PERIOD_SECONDS = 60 * 60 * 24 * 365; // 1 year

  // Before each test, we deploy a new instance of the contract
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    PropertyToken = await ethers.getContractFactory("PropertyToken");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    // Deploy the contract with constructor arguments
    propertyToken = await PropertyToken.deploy(
      "Real Estate Token",
      "RET",
      TOTAL_SUPPLY,
      OWNERSHIP_CAP,
      LOCKUP_PERIOD_SECONDS
    );
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await propertyToken.owner()).to.equal(owner.address);
    });

    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await propertyToken.balanceOf(owner.address);
      expect(await propertyToken.totalSupply()).to.equal(ownerBalance);
    });

    it("Should set the correct name and symbol", async function () {
      expect(await propertyToken.name()).to.equal("Real Estate Token");
      expect(await propertyToken.symbol()).to.equal("RET");
    });

    it("Should set the correct ownership cap and lockup period", async function () {
      expect(await propertyToken.ownershipCap()).to.equal(OWNERSHIP_CAP);
      expect(await propertyToken.lockupPeriod()).to.equal(
        LOCKUP_PERIOD_SECONDS
      );
    });
  });

  describe("Allowlisting", function () {
    it("Should allow the owner to add an address to the allowlist", async function () {
      await propertyToken.connect(owner).addToAllowlist(addr1.address);
      expect(await propertyToken.isAllowlisted(addr1.address)).to.be.true;
    });

    it("Should prevent non-owners from adding to the allowlist", async function () {
      await expect(
        propertyToken.connect(addr1).addToAllowlist(addr2.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should allow the owner to remove an address from the allowlist", async function () {
      await propertyToken.connect(owner).addToAllowlist(addr1.address);
      expect(await propertyToken.isAllowlisted(addr1.address)).to.be.true;

      await propertyToken.connect(owner).removeFromAllowlist(addr1.address);
      expect(await propertyToken.isAllowlisted(addr1.address)).to.be.false;
    });
  });

  describe("Transactions with Safeguards", function () {
    beforeEach(async function () {
      // Pre-allowlist addresses for transfer tests
      await propertyToken.connect(owner).addToAllowlist(owner.address);
      await propertyToken.connect(owner).addToAllowlist(addr1.address);
      await propertyToken.connect(owner).addToAllowlist(addr2.address);
    });

    it("Should fail to transfer tokens if recipient is not allowlisted", async function () {
      // addr3 is not on the allowlist
      const addr3 = addrs[0];
      await expect(
        propertyToken
          .connect(owner)
          .transfer(addr3.address, ethers.parseUnits("100", 18))
      ).to.be.revertedWith("Recipient is not allowlisted");
    });

    it("Should fail to transfer tokens if sender is not allowlisted (and not owner)", async function () {
      // Transfer some tokens to addr1 first
      await propertyToken
        .connect(owner)
        .transfer(addr1.address, ethers.parseUnits("1000", 18));

      // Now remove addr1 from allowlist and try to transfer
      await propertyToken.connect(owner).removeFromAllowlist(addr1.address);

      await expect(
        propertyToken
          .connect(addr1)
          .transfer(addr2.address, ethers.parseUnits("100", 18))
      ).to.be.revertedWith("Sender is not allowlisted");
    });

    it("Should fail if a transfer exceeds the ownership cap", async function () {
      const amountOverCap = OWNERSHIP_CAP + ethers.parseUnits("1", 18);
      await expect(
        propertyToken.connect(owner).transfer(addr1.address, amountOverCap)
      ).to.be.revertedWith("Transfer exceeds ownership cap for recipient");
    });

    it("Should succeed if a transfer is exactly at the ownership cap", async function () {
      await propertyToken.connect(owner).transfer(addr1.address, OWNERSHIP_CAP);
      const addr1Balance = await propertyToken.balanceOf(addr1.address);
      expect(addr1Balance).to.equal(OWNERSHIP_CAP);
    });

    it("Should fail if a non-owner tries to transfer within the lockup period", async function () {
      // Transfer tokens to addr1
      await propertyToken
        .connect(owner)
        .transfer(addr1.address, ethers.parseUnits("1000", 18));

      // Attempt transfer from addr1 to addr2
      await expect(
        propertyToken
          .connect(addr1)
          .transfer(addr2.address, ethers.parseUnits("100", 18))
      ).to.be.revertedWith("Tokens are locked");
    });

    it("Should allow the owner to transfer tokens during the lockup period (for initial distribution)", async function () {
      // Owner can transfer to addr1
      await expect(
        propertyToken
          .connect(owner)
          .transfer(addr1.address, ethers.parseUnits("1000", 18))
      ).to.not.be.reverted;
    });

    it("Should allow transfers by non-owners after the lockup period", async function () {
      // Transfer tokens to addr1
      await propertyToken
        .connect(owner)
        .transfer(addr1.address, ethers.parseUnits("1000", 18));

      // Fast-forward time beyond the lockup period
      await ethers.provider.send("evm_increaseTime", [
        LOCKUP_PERIOD_SECONDS + 1,
      ]);
      await ethers.provider.send("evm_mine");

      // Now addr1 should be able to transfer
      await propertyToken
        .connect(addr1)
        .transfer(addr2.address, ethers.parseUnits("100", 18));
      const addr2Balance = await propertyToken.balanceOf(addr2.address);
      expect(addr2Balance).to.equal(ethers.parseUnits("100", 18));
    });
  });
});
