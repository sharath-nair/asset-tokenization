// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PropertyToken
 * @author SRN
 * @notice ERC20 token representing fractional ownership of a specific real estate property.
 * @dev This contract mints the total supply to an initial owner (typically the deployer,
 * representing the SPV or platform manager for the MVP) upon deployment.
 * It leverages OpenZeppelin's battle-tested ERC20 and Ownable implementations.
 */
contract PropertyToken is ERC20, Ownable {
    /**
     * @notice Constructs the PropertyToken contract.
     * @param initialOwner The address that will be granted ownership of this contract and
     * receive the initial total supply of tokens. This simulates the
     * SPV or platform manager holding all tokens before distribution.
     * @param tokenName The name of the token (e.g., "Ocean View Villa Shares").
     * @param tokenSymbol The symbol for the token (e.g., "OVVS").
     * @param totalTokenSupply The total number of indivisible token units to be created.
     * For example, if you want 1,000,000 property shares and the token
     * uses 18 decimals (standard), this value should be
     * 1_000_000 * (10**18).
     */
    constructor(
        address initialOwner,
        string memory tokenName,
        string memory tokenSymbol,
        uint256 totalTokenSupply
    ) ERC20(tokenName, tokenSymbol) Ownable(initialOwner) {
        require(totalTokenSupply > 0, "PropertyToken: Total supply must be greater than zero");
        require(initialOwner != address(0), "PropertyToken: Initial owner cannot be the zero address");

        // Mint the entire supply to the initialOwner (deployer/SPV manager for MVP)
        _mint(initialOwner, totalTokenSupply);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes minting
     * (where `from` is `address(0)`) and burning (where `to` is `address(0)`).
     *
     * In this MVP version, no additional restrictions are implemented here beyond
     * standard ERC20 behavior. This function can be overridden in future versions
     * to add custom logic like transfer restrictions based on an allowlist (for KYC),
     * a trading pause mechanism (if combined with Pausable), or other rules.
     *
     * For example, to implement a basic allowlist check:
     * require(isAllowListed[from] || from == address(this) || from == owner(), "ERC20: sender not allowlisted"); // Allow contract/owner
     * require(isAllowListed[to] || to == address(this) || to == owner(), "ERC20: receiver not allowlisted");
     */
    function _update(address from, address to, uint256 amount)
        internal
        override
    {
        super._update(from, to, amount);
        // MVP: No custom transfer restrictions implemented in this hook.
        // This is a placeholder for potential future enhancements like KYC allowlisting.
    }

    // --- Optional Owner-Only Functions (Illustrative for MVP) ---

    // If, for any reason, the SPV manager needed to mint more tokens (e.g., for a property extension
    // and further fundraising – though this complicates fixed supply tokenomics),
    // an owner-only mint function could be added.
    // For MVP with fixed supply at construction, this is NOT typically needed.
    /*
    function mintShares(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }
    */

    // If tokens were to be burned by the SPV manager (e.g., a buy-back program).
    // For MVP, this is out of scope.
    /*
    function burnShares(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount); // Or burn from a specific account if needed
    }
    */

    // Note:
    // - Standard ERC20 functions (transfer, approve, transferFrom, balanceOf, totalSupply, decimals, name, symbol)
    //   are inherited from OpenZeppelin's ERC20.sol.
    // - The `decimals()` function defaults to 18, which is standard for most ERC20 tokens.
    //   If you need a different precision, you can override it:
    //   function decimals() public view virtual override returns (uint8) {
    //       return YOUR_DESIRED_DECIMALS; // e.g., 6 or 0
    //   }
    //   However, for simplicity and compatibility, 18 is recommended unless there's a strong reason.
}
