const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SimpleDAO", function () {
  let PropertyToken, propertyToken, SimpleDAO, simpleDAO;
  let owner, addr1, addr2, addr3;
  const QUORUM_PERCENT = 40; // 40%
  const SUPERMAJORITY_PERCENT = 60; // 60%

  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // Deploy PropertyToken
    PropertyToken = await ethers.getContractFactory("PropertyToken");
    propertyToken = await PropertyToken.deploy(
      "Test Token",
      "TT",
      ethers.parseUnits("1000", 18),
      ethers.parseUnits("1000", 18),
      0
    );

    // Deploy SimpleDAO
    SimpleDAO = await ethers.getContractFactory("SimpleDAO");
    simpleDAO = await SimpleDAO.deploy(
      await propertyToken.getAddress(),
      QUORUM_PERCENT,
      SUPERMAJORITY_PERCENT
    );

    // Distribute tokens for voting power
    // Allowlist first
    await propertyToken.addToAllowlist(owner.address);
    await propertyToken.addToAllowlist(addr1.address);
    await propertyToken.addToAllowlist(addr2.address);
    await propertyToken.addToAllowlist(addr3.address);

    // owner: 400 tokens (40%)
    // addr1: 300 tokens (30%)
    // addr2: 200 tokens (20%)
    // addr3: 100 tokens (10%)
    await propertyToken.transfer(addr1.address, ethers.parseUnits("300", 18));
    await propertyToken.transfer(addr2.address, ethers.parseUnits("200", 18));
    await propertyToken.transfer(addr3.address, ethers.parseUnits("100", 18));
  });

  describe("Proposal Creation", function () {
    it("Should allow a token holder to create a proposal", async function () {
      await expect(simpleDAO.connect(addr1).createProposal("Sell the property"))
        .to.emit(simpleDAO, "ProposalCreated")
        .withArgs(0, addr1.address, "Sell the property");

      const proposal = await simpleDAO.proposals(0);
      expect(proposal.description).to.equal("Sell the property");
      expect(proposal.proposer).to.equal(addr1.address);
    });

    it("Should prevent non-token holders from creating a proposal", async function () {
      const nonHolder = addrs[0];
      await expect(
        simpleDAO.connect(nonHolder).createProposal("This should fail")
      ).to.be.revertedWith("Must hold tokens to create a proposal");
    });
  });

  describe("Voting", function () {
    beforeEach(async function () {
      // Create a proposal to vote on
      await simpleDAO.connect(owner).createProposal("Replace the roof");
    });

    it("Should allow token holders to vote 'For'", async function () {
      await simpleDAO.connect(addr1).vote(0, true);
      const proposal = await simpleDAO.proposals(0);
      expect(proposal.forVotes).to.equal(ethers.parseUnits("300", 18));
    });

    it("Should allow token holders to vote 'Against'", async function () {
      await simpleDAO.connect(addr2).vote(0, false);
      const proposal = await simpleDAO.proposals(0);
      expect(proposal.againstVotes).to.equal(ethers.parseUnits("200", 18));
    });

    it("Should prevent a user from voting twice on the same proposal", async function () {
      await simpleDAO.connect(addr1).vote(0, true);
      await expect(simpleDAO.connect(addr1).vote(0, false)).to.be.revertedWith(
        "Already voted"
      );
    });

    it("Should prevent voting on a non-existent proposal", async function () {
      await expect(simpleDAO.connect(addr1).vote(1, true)).to.be.revertedWith(
        "Proposal does not exist"
      );
    });
  });

  describe("Proposal Execution", function () {
    beforeEach(async function () {
      await simpleDAO.connect(owner).createProposal("Execute this");
    });

    it("Should fail to execute if quorum is not met", async function () {
      // Total votes: addr1 (300) = 30% of total supply. Quorum is 40%.
      await simpleDAO.connect(addr1).vote(0, true);
      await expect(
        simpleDAO.connect(owner).executeProposal(0)
      ).to.be.revertedWith("Quorum not reached");
    });

    it("Should fail to execute if supermajority is not met", async function () {
      // Quorum met: owner (400) + addr1 (300) = 700 votes (70% > 40%)
      await simpleDAO.connect(owner).vote(0, true); // For: 400
      await simpleDAO.connect(addr1).vote(0, false); // Against: 300
      // For votes percentage: 400 / (400 + 300) = 57.14%. Supermajority is 60%.
      await expect(
        simpleDAO.connect(owner).executeProposal(0)
      ).to.be.revertedWith("Supermajority not reached");
    });

    it("Should execute successfully if quorum and supermajority are met", async function () {
      // Quorum met: owner (400) + addr1 (300) + addr2 (200) = 900 votes (90% > 40%)
      await simpleDAO.connect(owner).vote(0, true); // For: 400
      await simpleDAO.connect(addr1).vote(0, true); // For: 300 (Total For: 700)
      await simpleDAO.connect(addr2).vote(0, false); // Against: 200
      // For votes percentage: 700 / (700 + 200) = 77.77% > 60%

      await expect(simpleDAO.connect(owner).executeProposal(0))
        .to.emit(simpleDAO, "ProposalExecuted")
        .withArgs(0);

      const proposal = await simpleDAO.proposals(0);
      expect(proposal.executed).to.be.true;
    });

    it("Should prevent a proposal from being executed twice", async function () {
      // Pass and execute the proposal
      await simpleDAO.connect(owner).vote(0, true);
      await simpleDAO.connect(addr1).vote(0, true);
      await simpleDAO.connect(owner).executeProposal(0);

      // Attempt to execute again
      await expect(
        simpleDAO.connect(owner).executeProposal(0)
      ).to.be.revertedWith("Proposal already executed");
    });
  });
});
