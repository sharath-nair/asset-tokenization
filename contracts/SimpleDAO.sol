// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleDAO
 * @author SRN
 * @notice A basic DAO contract for PropertyToken holders to create and vote on proposals.
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

    event ProposalMarkedExecuted(uint256 indexed proposalId);

    /**
     * @notice Constructor initializes the DAO with the governance token and voting parameters.
     * @param _propertyTokenAddress The address of the ERC20 PropertyToken.
     * @param _minTokensToPropose Minimum token balance required to create a proposal (in smallest unit, e.g., wei).
     * @param _votingPeriodInSeconds The duration for which voting on a new proposal will be open.
     */
    constructor(
        address _propertyTokenAddress,
        uint256 _minTokensToPropose,
        uint256 _votingPeriodInSeconds
    ) {
        require(_propertyTokenAddress != address(0), "SimpleDAO: PropertyToken address cannot be zero");
        require(_minTokensToPropose > 0, "SimpleDAO: Minimum tokens to propose must be positive");
        require(_votingPeriodInSeconds > 0, "SimpleDAO: Voting period must be positive");

        propertyToken = IERC20(_propertyTokenAddress);
        MINIMUM_TOKENS_TO_PROPOSE = _minTokensToPropose;
        votingPeriodSeconds = _votingPeriodInSeconds;
    }

    /**
     * @notice Allows a PropertyToken holder with sufficient balance to create a new proposal.
     * @param _description A textual description of what is being proposed.
     * @return proposalId The ID of the newly created proposal.
     */
    function createProposal(string memory _description) public returns (uint256 proposalId) {
        require(bytes(_description).length > 0, "SimpleDAO: Description cannot be empty");
        uint256 proposerBalance = propertyToken.balanceOf(msg.sender);
        require(proposerBalance >= MINIMUM_TOKENS_TO_PROPOSE, "SimpleDAO: Insufficient tokens to create proposal");

        proposalId = proposals.length;
        uint256 voteStart = block.timestamp;
        uint256 voteEnd = block.timestamp + votingPeriodSeconds;

        // Note: Mappings inside structs (hasVoted, voteWeightCast) are automatically initialized.
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
                // Mappings 'hasVoted' and 'voteWeightCast' are part of the struct type
                // and will be default initialized for this new proposal instance.
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
        require(_proposalId < proposals.length, "SimpleDAO: Proposal does not exist");
        Proposal storage currentProposal = proposals[_proposalId]; // Use storage pointer

        require(block.timestamp >= currentProposal.voteStartTimestamp, "SimpleDAO: Voting has not started yet"); // Though start is immediate
        require(block.timestamp <= currentProposal.voteEndTimestamp, "SimpleDAO: Voting period has ended");
        require(!currentProposal.hasVoted[msg.sender], "SimpleDAO: Already voted on this proposal");

        uint256 voterBalance = propertyToken.balanceOf(msg.sender);
        require(voterBalance > 0, "SimpleDAO: Must hold tokens to vote");

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
        require(_proposalId < proposals.length, "SimpleDAO: Proposal does not exist");
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

    /**
     * @notice Checks if a proposal is considered passed based on a simple majority
     * after the voting period has ended.
     * @param _proposalId The ID of the proposal.
     * @return True if the proposal passed (votesFor > votesAgainst and voting has ended).
     * @dev Does not consider quorum for this MVP.
     */
    function isProposalPassed(uint256 _proposalId) public view returns (bool) {
        require(_proposalId < proposals.length, "SimpleDAO: Proposal does not exist");
        Proposal storage p = proposals[_proposalId];

        if (block.timestamp <= p.voteEndTimestamp) {
            return false; // Voting period not yet over
        }
        return p.votesFor > p.votesAgainst;
    }

    /**
     * @notice Marks a proposal as executed.
     * For MVP, this is a manual step to signify off-chain action was taken.
     * It requires the proposal to have passed according to `isProposalPassed` logic.
     * @param _proposalId The ID of the proposal to mark as executed.
     * @dev In a more advanced system, this might be restricted or trigger on-chain actions.
     */
    function markAsExecuted(uint256 _proposalId) public {
        require(_proposalId < proposals.length, "SimpleDAO: Proposal does not exist");
        Proposal storage currentProposal = proposals[_proposalId];

        require(!currentProposal.executed, "SimpleDAO: Proposal already marked as executed");
        // Ensure voting has ended before checking pass status for execution marking
        require(block.timestamp > currentProposal.voteEndTimestamp, "SimpleDAO: Voting period not yet ended");
        require(currentProposal.votesFor > currentProposal.votesAgainst, "SimpleDAO: Proposal must have passed to be marked executed");

        currentProposal.executed = true;
        emit ProposalMarkedExecuted(_proposalId);
    }

    /**
     * @notice Returns the total number of proposals created.
     */
    function getProposalCount() public view returns (uint256) {
        return proposals.length;
    }
}
