// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {IAccessRestriction} from "../access/IAccessRestriction.sol";
import {IFOT} from "../token/IFOT.sol";
import {IFOTDistributor} from "./IFOTDistributor.sol";

/**
 * @title FOT Token Distributor Contract
 * @dev Distributes FOT tokens from various pools with access controls
 */
contract FOTDistributor is IFOTDistributor {
    /// @dev Role identifier for approved contracts
    bytes32 public constant APPROVED_CONTRACT_ROLE =
        keccak256("APPROVED_CONTRACT_ROLE");

    /**
     * @dev Mapping to store available liquidity for each pool
     */
    mapping(bytes32 => uint256) public override poolLiquidity;

    /**
     * @dev Mapping to track used liquidity for each pool
     */
    mapping(bytes32 => uint256) public override usedLiquidity;

    /**
     * @dev Reference to the access restriction contract
     */
    IAccessRestriction public immutable accessRestriction;

    /**
     * @dev Reference to the FOT token contract
     */
    IFOT public immutable token;

    /**
     * @dev Reverts if address is invalid
     */
    modifier validAddress(address _addr) {
        if (_addr == address(0)) revert InvalidAddress();
        _;
    }

    /// @dev Modifier: Only accessible by approved contracts
    modifier onlyApprovedContract() {
        if (!accessRestriction.hasRole(APPROVED_CONTRACT_ROLE, msg.sender))
            revert NotApprovedContract();
        _;
    }

    /**
     * @dev Constructor to initialize the FOTDistributor contract
     * @param _accessRestrictionAddress Address of the access restriction contract
     * @param _fotAddress Address of the FOT token contract
     */
    constructor(address _accessRestrictionAddress, address _fotAddress) {
        accessRestriction = IAccessRestriction(_accessRestrictionAddress);
        token = IFOT(_fotAddress);

        // Initialize pool liquidity values
        poolLiquidity[bytes32("Seed")] = 5e9 * (10 ** 18);
        poolLiquidity[bytes32("Sale")] = 13e9 * (10 ** 18);
        poolLiquidity[bytes32("P2E")] = 40e9 * (10 ** 18);
        poolLiquidity[bytes32("GameTreasury")] = 11e9 * (10 ** 18);
        poolLiquidity[bytes32("Marketing")] = 7e9 * (10 ** 18);
        poolLiquidity[bytes32("Airdrop")] = 5e9 * (10 ** 18);
        poolLiquidity[bytes32("Liquidity")] = 9e9 * (10 ** 18);
        poolLiquidity[bytes32("Team")] = 1e10 * (10 ** 18);
    }

    /**
     * @dev Distribute FOT tokens from a specified pool
     * @param _poolName Name of distribution pool
     * @param _amount Amount of tokens to distribute
     * @param _to Recipient address
     * @return Success status
     */
    function distribute(
        bytes32 _poolName,
        uint256 _amount,
        address _to
    ) external override onlyApprovedContract validAddress(_to) returns (bool) {
        if (_amount + usedLiquidity[_poolName] > poolLiquidity[_poolName]) {
            revert InsufficientPoolBalance();
        }

        if (_to == address(this)) {
            revert TransferToDistributorForbidden();
        }

        usedLiquidity[_poolName] += _amount;
        emit TokenDistributed(_poolName, _amount, _to);

        // Transfer tokens
        bool success = token.transferToken(_to, _amount);
        if (!success) revert TokenTransferFailed();

        return true;
    }
}
