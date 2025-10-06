// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockToken
 * @dev A simple ERC20 mock token for testing purposes
 * @notice This contract provides a basic ERC20 token with initial supply
 */
contract MockToken is ERC20 {
    /**
     * @dev Constructor that creates the initial supply
     * @notice Mints 1,000,000 MTK tokens to the deployer
     */
    constructor() ERC20("MockToken", "MTK") {
        // Mint 1,000,000 tokens with 18 decimals to the deployer
        _mint(msg.sender, 1000000 * 10 ** 18);
    }

    /**
     * @dev Mint additional tokens (for testing purposes)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev Get the number of decimals for this token
     * @return The number of decimals (18)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
