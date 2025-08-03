// SPDX-License-Identifier: ISC
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC20Extended
 * @notice Extended interface for ERC20 tokens with additional metadata
 * @dev Extends standard IERC20 with name, symbol, and decimals functions
 */
interface IERC20Extended is IERC20 {
    /**
     * @notice Returns the name of the token
     * @return The token name
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token
     * @return The token symbol
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the number of decimals used to get its user representation
     * @dev For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`)
     * @return The number of decimals
     */
    function decimals() external view returns (uint8);

    /**
     * @notice Returns the total amount of tokens in existence
     * @return The total supply
     */
    function totalSupply() external view override returns (uint256);

    /**
     * @notice Returns the amount of tokens owned by `account`
     * @param account The address to query the balance of
     * @return The balance of the account
     */
    function balanceOf(address account) external view override returns (uint256);

    /**
     * @notice Moves `amount` tokens from the caller's account to `to`
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transfer(address to, uint256 amount) external override returns (bool);

    /**
     * @notice Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}
     * @param owner The address of the token owner
     * @param spender The address of the token spender
     * @return The remaining allowance
     */
    function allowance(address owner, address spender) external view override returns (uint256);

    /**
     * @notice Sets `amount` as the allowance of `spender` over the caller's tokens
     * @param spender The address to approve
     * @param amount The amount to approve
     * @return True if the approval was successful
     */
    function approve(address spender, uint256 amount) external override returns (bool);

    /**
     * @notice Moves `amount` tokens from `from` to `to` using the allowance mechanism
     * @param from The address to transfer tokens from
     * @param to The address to transfer tokens to
     * @param amount The amount of tokens to transfer
     * @return True if the transfer was successful
     */
    function transferFrom(address from, address to, uint256 amount) external override returns (bool);
}