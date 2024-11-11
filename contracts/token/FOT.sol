// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IFOT} from "./IFOT.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IAccessRestriction} from "../access/IAccessRestriction.sol";

contract FOT is ERC20, IFOT {
    /// @dev EIP-20 token name for this token
    string public constant NAME = "FreakOff";

    /// @dev EIP-20 token symbol for this token
    string public constant SYMBOL = "FOT";

    /// @dev EIP-20 token decimals for this token
    uint8 public constant DECIMALS = 18;

    /// @dev EIP-20 token supply for this token
    uint256 public constant SUPPLY = 1e11 * (10 ** DECIMALS);

    /// @dev Distributor role hash
    bytes32 private constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");

    /// @dev Owner role hash
    bytes32 private constant OWNER_ROLE = keccak256("OWNER_ROLE");

    /// @dev Reference to the access restriction contract
    IAccessRestriction public immutable accessRestriction;

    /// @dev Modifier: Only accessible by distributors
    modifier onlyDistributor() {
        if (!accessRestriction.hasRole(DISTRIBUTOR_ROLE, msg.sender))
            revert NotDistributor();

        _;
    }

    constructor(address _accessRestrictionAddress) ERC20(NAME, SYMBOL) {
        if (_accessRestrictionAddress == address(0)) {
            revert InvalidAccessRestrictionAddress();
        }
        accessRestriction = IAccessRestriction(_accessRestrictionAddress);
        _mint(address(this), SUPPLY);
    }

    function transferToken(
        address _to,
        uint256 _amount
    ) external onlyDistributor returns (bool) {
        if (_to == address(0)) {
            revert InvalidRecipient(_to);
        }
        if (_amount <= 0) {
            revert InsufficientAmount();
        }
        if (accessRestriction.hasRole(OWNER_ROLE, _to)) {
            revert TransferToOwnerNotAllowed();
        }

        _transfer(address(this), _to, _amount);

        return true;
    }
}
