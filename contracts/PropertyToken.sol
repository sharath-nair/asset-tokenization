// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PropertyToken
 * @author SRN
 * @notice ERC20 token for fractional real-estate ownership with safeguards.
 * @dev Includes allowlisting (KYC simulation), ownership cap, and a token lock-up period.
 * The owner (PropertyManager/SPV) has administrative privileges for these features.
 */
contract PropertyToken is ERC20, Ownable {
    mapping(address => bool) public isAllowListed;
    uint256 public ownershipCapPercentage; // e.g., 10 for 10%
    uint256 public maxTokensPerHolder;     // Calculated from ownershipCapPercentage
    uint256 public unlockTimestamp;        // Timestamp after which general transfers are allowed

    event AllowListedAddressAdded(address indexed account);
    event AllowListedAddressRemoved(address indexed account);
    event OwnershipCapSet(uint256 percentage, uint256 maxTokens);
    event LockupPeriodSet(uint256 timestamp);

    /**
     * @notice Constructs the PropertyToken contract.
     * @param _initialOwner The PropertyManager/SPV address.
     * @param _tokenName The name of the token.
     * @param _tokenSymbol The symbol for the token.
     * @param _totalTokenSupply Total indivisible units (considering decimals).
     */
    constructor(
        address _initialOwner,
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalTokenSupply
    ) ERC20(tokenName, tokenSymbol) Ownable(_initialOwner) {
        require(_totalTokenSupply > 0, "PropertyToken: Total supply must be > 0");
        require(_initialOwner != address(0), "PropertyToken: Initial owner is zero address");

        // The initial owner is automatically allowlisted to manage distributions.
        isAllowListed[_initialOwner] = true;
        emit AllowListedAddressAdded(_initialOwner);

        _mint(_initialOwner, _totalTokenSupply);
    }

    // --- Allowlist Functions ---
    function addToAllowlist(address _account) public onlyOwner {
        require(_account != address(0), "PropertyToken: Cannot allowlist zero address");
        require(!isAllowListed[_account], "PropertyToken: Account already allowlisted");
        isAllowListed[_account] = true;
        emit AllowListedAddressAdded(_account);
    }

    function addManyToAllowlist(address[] memory _accounts) public onlyOwner {
        for (uint i = 0; i < _accounts.length; i++) {
            require(_accounts[i] != address(0), "PropertyToken: Cannot allowlist zero address");
            if (!isAllowListed[_accounts[i]]) {
                isAllowListed[_accounts[i]] = true;
                emit AllowListedAddressAdded(_accounts[i]);
            }
        }
    }

    function removeFromAllowlist(address _account) public onlyOwner {
        require(isAllowListed[_account], "PropertyToken: Account not on allowlist");
        isAllowListed[_account] = false;
        emit AllowListedAddressRemoved(_account);
    }

    // --- Ownership Cap Functions ---
    /**
     * @notice Sets the ownership cap as a percentage of total supply.
     * @param _percentage Cap percentage (e.g., 10 for 10%). 0 means no cap.
     */
    function setOwnershipCapPercentage(uint256 _percentage) public onlyOwner {
        require(_percentage <= 100, "PropertyToken: Percentage cannot exceed 100");
        ownershipCapPercentage = _percentage;
        if (_percentage == 0) {
            maxTokensPerHolder = type(uint256).max; // Effectively no cap
        } else {
            maxTokensPerHolder = (totalSupply() * _percentage) / 100;
        }
        emit OwnershipCapSet(_percentage, maxTokensPerHolder);
    }

    // --- Lock-up Period Functions ---
    /**
     * @notice Sets the timestamp after which general token transfers are allowed.
     * @param _timestamp The Unix timestamp for unlocking.
     */
    function setLockupPeriod(uint256 _timestamp) public onlyOwner {
        require(_timestamp > block.timestamp, "Lock-up must be in future");
        unlockTimestamp = _timestamp;
        emit LockupPeriodSet(_timestamp);
    }

    // --- ERC20 Override ---
    /**
     * @dev Hook called before any token transfer, including mint and burn.
     * Implements allowlisting, ownership cap, and lock-up period checks.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // Minting: Only the 'to' address needs to be checked for allowlist and cap
            // The initial owner (recipient of mint in constructor) is pre-allowlisted.
            // If minting to other addresses later (e.g., via a special function), they need to be allowlisted.
            require(isAllowListed[to] || to == owner(), "PropertyToken: Mint recipient not allowlisted"); // Owner exempt for initial mint
            if (ownershipCapPercentage > 0 && to != owner()) { // Cap applies to non-owners
                require(balanceOf(to) + amount <= maxTokensPerHolder, "PropertyToken: Recipient exceeds ownership cap");
            }
        } else if (to == address(0)) {
            // Burning: Only 'from' address needs to be allowlisted if it's not the owner.
            // Standard ERC20 burn requires 'from' to have an allowance or be the msg.sender.
            require(isAllowListed[from] || from == owner(), "PropertyToken: Burner not allowlisted");
        } else {
            // Regular Transfer
            // 1. Lock-up Period Check
            if (unlockTimestamp > 0) { // Only apply lock-up if it's set
                require(block.timestamp >= unlockTimestamp || from == owner(), "PropertyToken: Tokens are locked");
                // The owner can transfer during lock-up (e.g., initial distribution).
                // Or make it stricter: require(block.timestamp >= unlockTimestamp || from == owner());
                // If owner distributes, `to` is the investor. If owner receives, `from` is investor.
            }

            // 2. Allowlist Check for both parties
            require(isAllowListed[from] || from == owner(), "PropertyToken: Sender not allowlisted"); // Owner is always allowed to send
            require(isAllowListed[to] || to == owner(), "PropertyToken: Recipient not allowlisted");   // Owner is always allowed to receive

            // 3. Ownership Cap Check for recipient (if not the owner)
            if (ownershipCapPercentage > 0 && to != owner()) {
                 require(balanceOf(to) + amount <= maxTokensPerHolder, "PropertyToken: Recipient exceeds ownership cap");
            }
        }
    }
}
