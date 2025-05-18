// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleDAO
 * @author SRN
 * @notice A basic DAO contract with supermajority and quorum voting for PropertyToken holders to create and vote on proposals.
 * @dev Voting power is based on token balance at the time of voting.
 * Proposal execution is intended to be determined off-chain based on vote outcomes for this MVP.
 */
contract SimpleDAO {
    IERC20 public immutable propertyToken; // The ERC20 token used for governance

    struct Proposal {
        uint256 id;                 // Unique ID of the proposal
        address proposer;           // Address of the account that created the proposal
        string description;         // Textual description of the proposal
        uint256 voteStartTimestamp; // Timestamp when the proposal was created / voting starts
        uint256 voteEndTimestamp;   // Timestamp when voting for the proposal ends
        uint256 votesFor;           // Accumulated vote weight in favor
        uint256 votesAgainst;       // Accumulated vote weight against
        bool executed;              // Flag indicating if the proposal has been (off-chain) acted upon
        mapping(address => bool) hasVoted; // Tracks if an address has voted on this proposal
        mapping(address => uint256) voteWeightCast; // Tracks the weight of the vote cast by an address
    }

    Proposal[] public proposals; // Array to store all proposals
    // nextProposalId will also serve as proposals.length before a new push

    uint256 public immutable MINIMUM_TOKENS_TO_PROPOSE; // Minimum tokens required to create a proposal
    uint256 public immutable votingPeriodSeconds;       // Duration of the voting period
    uint8 public immutable SUPERMAJORITY_PERCENTAGE_OF_VOTES_CAST; // e.g., 75 for 75%
    uint8 public immutable QUORUM_PERCENTAGE_OF_TOTAL_SUPPLY;   // e.g., 10 for 10% of total supply must vote

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description,
        uint256 voteStartTimestamp,
        uint256 voteEndTimestamp
    );
    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool inFavor,
        uint256 voteWeight
    );
    event ProposalMarkedExecuted(uint256 indexed proposalId, bool passed);

    /**
     * @param _propertyTokenAddress Address of the ERC20 PropertyToken.
     * @param _minTokensToPropose Minimum tokens required to create a proposal.
     * @param _votingPeriodInSeconds Duration for voting.
     * @param _supermajorityVotePercentage Required percentage of 'For' votes out of total votes cast (e.g., 66 for 66%).
     * @param _quorumPercentage Minimum percentage of total token supply that must participate in voting (e.g., 10 for 10%). Set to 0 to disable quorum.
     */
    constructor(
        address _propertyTokenAddress,
        uint256 _minTokensToPropose,
        uint256 _votingPeriodInSeconds,
        uint8 _supermajorityVotePercentage,
        uint8 _quorumPercentage
    ) {
        require(_propertyTokenAddress != address(0), "DAO: PropertyToken address cannot be zero");
        require(_minTokensToPropose > 0, "DAO: Min tokens to propose must be > 0");
        require(_votingPeriodInSeconds > 0, "DAO: Voting period must be > 0");
        require(_supermajorityVotePercentage > 50 && _supermajorityVotePercentage <= 100, "DAO: Supermajority must be > 50 and <= 100");
        require(_quorumPercentage <= 100, "DAO: Quorum percentage cannot exceed 100");


        propertyToken = IERC20(_propertyTokenAddress);
        MINIMUM_TOKENS_TO_PROPOSE = _minTokensToPropose;
        votingPeriodSeconds = _votingPeriodInSeconds;
        SUPERMAJORITY_PERCENTAGE_OF_VOTES_CAST = _supermajorityVotePercentage;
        QUORUM_PERCENTAGE_OF_TOTAL_SUPPLY = _quorumPercentage;
    }

    /**
     * @notice Allows a PropertyToken holder with sufficient balance to create a new proposal.
     * @param _description A textual description of what is being proposed.
     * @return proposalId The ID of the newly created proposal.
     */
    function createProposal(string memory _description) public returns (uint256 proposalId) {
        require(bytes(_description).length > 0, "DAO: Description cannot be empty");
        uint256 proposerBalance = propertyToken.balanceOf(msg.sender);
        require(proposerBalance >= MINIMUM_TOKENS_TO_PROPOSE, "DAO: Insufficient tokens to create proposal");

        proposalId = proposals.length;
        uint256 voteStart = block.timestamp;
        uint256 voteEnd = block.timestamp + votingPeriodSeconds;

        proposals.push(
            Proposal({
                id: proposalId,
                proposer: msg.sender,
                description: _description,
                voteStartTimestamp: voteStart,
                voteEndTimestamp: voteEnd,
                votesFor: 0,
                votesAgainst: 0,
                executed: false
                // Mappings inside structs (hasVoted, voteWeightCast) are automatically initialized.
            })
        );

        emit ProposalCreated(proposalId, msg.sender, _description, voteStart, voteEnd);
        return proposalId;
    }

    /**
     * @notice Allows a PropertyToken holder to cast their vote on an active proposal.
     * Voting power is determined by their token balance at the time of voting.
     * @param _proposalId The ID of the proposal to vote on.
     * @param _inFavor True to vote in favor, false to vote against.
     */
    function vote(uint256 _proposalId, bool _inFavor) public {
        require(_proposalId < proposals.length, "DAO: Proposal does not exist");
        Proposal storage currentProposal = proposals[_proposalId];

        require(block.timestamp >= currentProposal.voteStartTimestamp, "DAO: Voting has not started");
        require(block.timestamp <= currentProposal.voteEndTimestamp, "DAO: Voting period has ended");
        require(!currentProposal.hasVoted[msg.sender], "DAO: Already voted on this proposal");

        uint256 voterBalance = propertyToken.balanceOf(msg.sender);
        require(voterBalance > 0, "DAO: Must hold tokens to vote");

        currentProposal.hasVoted[msg.sender] = true;
        currentProposal.voteWeightCast[msg.sender] = voterBalance;

        if (_inFavor) {
            currentProposal.votesFor += voterBalance;
        } else {
            currentProposal.votesAgainst += voterBalance;
        }

        emit Voted(_proposalId, msg.sender, _inFavor, voterBalance);
    }

    /**
     * @notice Retrieves the details of a specific proposal.
     * @param _proposalId The ID of the proposal.
     */
    function getProposal(uint256 _proposalId)
        public
        view
        returns (
            uint256 id,
            address proposer,
            string memory description,
            uint256 voteStartTimestamp,
            uint256 voteEndTimestamp,
            uint256 votesFor,
            uint256 votesAgainst,
            bool executed
        )
    {
        require(_proposalId < proposals.length, "DAO: Proposal does not exist");
        Proposal storage p = proposals[_proposalId];
        return (
            p.id,
            p.proposer,
            p.description,
            p.voteStartTimestamp,
            p.voteEndTimestamp,
            p.votesFor,
            p.votesAgainst,
            p.executed
        );
    }

    function getProposalOutcome(uint256 _proposalId) public view returns (bool passed, uint256 totalVotesCast, uint256 requiredQuorum) {
        require(_proposalId < proposals.length, "DAO: Proposal does not exist");
        Proposal storage p = proposals[_proposalId];

        if (block.timestamp <= p.voteEndTimestamp) {
            return (false, p.votesFor + p.votesAgainst, 0); // Voting not ended, quorum not yet relevant for pass state
        }

        totalVotesCast = p.votesFor + p.votesAgainst;

        if (QUORUM_PERCENTAGE_OF_TOTAL_SUPPLY > 0) {
            uint256 tokenTotalSupply = propertyToken.totalSupply();
            if (tokenTotalSupply == 0) return (false, totalVotesCast, 0); // Avoid division by zero
            requiredQuorum = (tokenTotalSupply * QUORUM_PERCENTAGE_OF_TOTAL_SUPPLY) / 100;
            if (totalVotesCast < requiredQuorum) {
                return (false, totalVotesCast, requiredQuorum); // Quorum not met
            }
        } else {
            requiredQuorum = 0; // Quorum disabled
        }

        if (totalVotesCast == 0) { // No votes, cannot pass supermajority
             return (false, totalVotesCast, requiredQuorum);
        }

        // Supermajority check: (votesFor * 100) / totalVotesCast >= SUPERMAJORITY_PERCENTAGE_OF_VOTES_CAST
        // To avoid issues with percentages that are not whole numbers and to ensure precision:
        // votesFor * 100 >= SUPERMAJORITY_PERCENTAGE_OF_VOTES_CAST * totalVotesCast
        bool supermajorityMet = (p.votesFor * 100) >= (SUPERMAJORITY_PERCENTAGE_OF_VOTES_CAST * totalVotesCast);
        passed = supermajorityMet && p.votesFor > 0; // Must have at least some 'for' votes and meet supermajority

        return (passed, totalVotesCast, requiredQuorum);
    }

    /**
     * @notice Marks a proposal as executed.
     * For PoC, this is a manual step to signify off-chain action was taken.
     * It requires the proposal to have passed according to `isProposalPassed` logic.
     * @param _proposalId The ID of the proposal to mark as executed.
     * @dev In a more advanced system, this might be restricted or trigger on-chain actions.
     */
    function markAsExecuted(uint256 _proposalId) public {
        require(_proposalId < proposals.length, "DAO: Proposal does not exist");
        Proposal storage currentProposal = proposals[_proposalId];

        require(!currentProposal.executed, "DAO: Proposal already marked as executed");

        (bool passed, , ) = getProposalOutcome(_proposalId); // Use the outcome function
        require(passed, "DAO: Proposal must have passed to be marked executed");

        currentProposal.executed = true;
        emit ProposalMarkedExecuted(_proposalId, passed);
    }

    /**
     * @notice Returns the total number of proposals created.
     */
    function getProposalCount() public view returns (uint256) {
        return proposals.length;
    }
}
