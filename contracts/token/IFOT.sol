// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;


import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFOT is IERC20{
    // Custom errors
    /// @dev Thrown when the provided access restriction address is invalid (i.e., the zero address)
    error InvalidAccessRestrictionAddress();

    /// @dev Thrown when attempting to transfer tokens to the zero address
    /// @param invalidAddress The invalid (zero) address provided
    error InvalidRecipient(address invalidAddress);

    /// @dev Thrown when the amount in a token transfer is zero
    error InsufficientAmount();

    /// @dev Thrown when attempting to transfer tokens to an address with the OWNER_ROLE
    error TransferToOwnerNotAllowed();

    /// @dev Thrown when a function restricted to distributors is called by a non-distributor address
    error NotDistributor();

    /**
     * @dev Transfers tokens from the contract to a specified address.
     * @notice This function allows authorized distributors to transfer tokens to users.
     * @param _to The address of the recipient receiving the tokens.
     * @param _amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transferToken(address _to, uint256 _amount) external returns (bool);
}