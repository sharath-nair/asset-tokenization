// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title IncomeDistribution
 * @author SRN
 * @notice Manages and distributes income (as native currency like ETH) to PropertyToken holders.
 * @dev Income is deposited by the contract owner (PropertyManager). Token holders can then claim
 * their proportional share. This MVP implementation calculates shares based on current token
 * holdings against all historically deposited income via `depositIncome()`.
 */
contract IncomeDistribution is Ownable, ReentrancyGuard {
    IERC20 public immutable propertyToken; // Interface for the PropertyToken contract

    uint256 public totalIncomeDeposited; // Total native currency ever deposited via depositIncome()
    mapping(address => uint256) public shareholderClaimedAmounts; // Tracks total amount claimed by each shareholder

    event IncomeDeposited(address indexed depositor, uint256 amount, uint256 newTotalIncomeDeposited);
    event IncomeClaimed(address indexed shareholder, uint256 amountClaimed, uint256 newTotalClaimedByShareholder);
    event SurplusFundsWithdrawn(address indexed to, uint256 amount);

    /**
     * @notice Constructor sets the PropertyToken address and the initial owner.
     * @param _propertyTokenAddress The address of the deployed PropertyToken ERC20 contract.
     * @param _initialOwner The address of the PropertyManager who will own this contract.
     */
    constructor(address _propertyTokenAddress, address _initialOwner) Ownable(_initialOwner) {
        require(_propertyTokenAddress != address(0), "IncomeDistribution: PropertyToken address cannot be zero");
        propertyToken = IERC20(_propertyTokenAddress);
    }

    /**
     * @notice Allows the owner (PropertyManager) to deposit native currency (e.g., ETH)
     * as income to be distributed.
     * @dev Only callable by the owner. msg.value is the amount of native currency sent.
     */
    function depositIncome() public payable onlyOwner {
        require(msg.value > 0, "IncomeDistribution: Deposit amount must be greater than zero");
        totalIncomeDeposited += msg.value;
        emit IncomeDeposited(msg.sender, msg.value, totalIncomeDeposited);
    }

    /**
     * @notice Calculates the amount of income a shareholder is currently entitled to claim.
     * It's based on their current share of tokens applied to the total income ever deposited,
     * minus what they've already claimed.
     * @param _shareholder The address of the token holder.
     * @return claimableNow The amount of native currency the shareholder can currently claim.
     */
    function getClaimableAmount(address _shareholder) public view returns (uint256 claimableNow) {
        uint256 shareholderTokenBalance = propertyToken.balanceOf(_shareholder);
        uint256 totalTokenSupply = propertyToken.totalSupply();

        if (totalTokenSupply == 0 || shareholderTokenBalance == 0) {
            return 0; // No tokens or no total supply means no basis for a claim.
        }

        // Calculate the shareholder's total entitlement based on all income ever deposited
        // (shareholderTokenBalance * totalIncomeDeposited) / totalTokenSupply
        // To avoid potential intermediate overflow if shareholderTokenBalance * totalIncomeDeposited is very large,
        // but maintain precision, ensure order of operations. Solidity handles large numbers well with uint256.
        uint256 totalEntitlement = (shareholderTokenBalance * totalIncomeDeposited) / totalTokenSupply;

        uint256 alreadyClaimed = shareholderClaimedAmounts[_shareholder];

        if (totalEntitlement <= alreadyClaimed) {
            return 0; // Already claimed their full share or more (should not be more if logic is sound)
        }

        claimableNow = totalEntitlement - alreadyClaimed;
        return claimableNow;
    }

    /**
     * @notice Allows a shareholder to claim their due share of the deposited income.
     * @dev Uses ReentrancyGuard to prevent re-entrancy attacks during the native currency transfer.
     */
    function claimIncome() public nonReentrant {
        uint256 amountToClaim = getClaimableAmount(msg.sender);

        require(amountToClaim > 0, "IncomeDistribution: No income to claim or already fully claimed");

        // Ensure the contract has enough balance to pay out this specific claim.
        // This check is important because getClaimableAmount is based on totalIncomeDeposited,
        // not necessarily the current live balance if funds were handled unexpectedly.
        require(address(this).balance >= amountToClaim, "IncomeDistribution: Insufficient contract balance for this claim");

        shareholderClaimedAmounts[msg.sender] += amountToClaim;

        // Transfer the native currency to the shareholder
        (bool success, ) = msg.sender.call{value: amountToClaim}("");
        require(success, "IncomeDistribution: Native currency transfer failed");

        emit IncomeClaimed(msg.sender, amountToClaim, shareholderClaimedAmounts[msg.sender]);
    }

    /**
     * @notice Fallback function to receive native currency.
     * @dev For this MVP, direct sends are allowed but DO NOT update `totalIncomeDeposited`.
     * The owner should always use `depositIncome()` to ensure funds are accounted for distribution.
     * If stricter control is needed, this function could revert direct sends.
     */
    receive() external payable {
        // Intentionally left simple for MVP. Funds sent here are not automatically part of
        // `totalIncomeDeposited` for claim calculations unless `depositIncome` is used.
    }

    /**
     * @notice Allows the owner to withdraw any surplus native currency from this contract.
     * This could be funds accidentally sent directly (not via depositIncome),
     * or funds remaining if some shareholders never claim their full entitlement.
     * @dev Use with transparency and caution. Only callable by the owner.
     * @param _to The address to which the surplus funds will be sent.
     * @param _amount The amount of native currency to withdraw.
     */
    function withdrawSurplusFunds(address payable _to, uint256 _amount) public onlyOwner nonReentrant {
        require(_to != address(0), "IncomeDistribution: Withdraw address cannot be zero");
        uint256 contractBalance = address(this).balance;
        require(_amount > 0, "IncomeDistribution: Withdraw amount must be positive");
        require(_amount <= contractBalance, "IncomeDistribution: Withdraw amount exceeds contract balance");

        // In a real-world scenario, this function might be subject to DAO approval or stricter controls.
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "IncomeDistribution: Surplus funds withdrawal failed");

        emit SurplusFundsWithdrawn(_to, _amount);
    }
}
