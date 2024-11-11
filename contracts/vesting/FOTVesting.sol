// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IFOTDistributor} from "../distributor/IFOTDistributor.sol";
import {IAccessRestriction} from "../access/IAccessRestriction.sol";
import {IFOTVesting} from "../vesting/IFOTVesting.sol";
import {IFOT} from "../token/IFOT.sol";
import "hardhat/console.sol";

/**
 * @title FOTVesting
 * @dev Manages vesting plans and FOT distributions
 */

contract FOTVesting is ReentrancyGuard, IFOTVesting {
    /// @dev Role identifier for vesting manager
    bytes32 public constant VESTING_MANAGER_ROLE =
        keccak256("VESTING_MANAGER_ROLE");

    /// @dev Role identifier for approved contracts
    bytes32 public constant APPROVED_CONTRACT_ROLE =
        keccak256("APPROVED_CONTRACT_ROLE");

    // FOT distributor reference
    IFOTDistributor public immutable FOTDistributor;

    // Access control reference
    IAccessRestriction public immutable accessRestriction;

    // Counter for vesting plan IDs
    uint256 private _planId;

    // Vesting plan details by plan ID
    mapping(uint256 => VestingPlan) public override vestingPlans;

    // User vesting schedules by user and plan ID
    mapping(address => mapping(uint256 => UserVesting))
        public
        override userVestings;

    // Vesting stats by user
    mapping(address => HolderStat) public override holdersStat;

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
     * @dev Reverts if caller is not vesting manager
     */
    modifier onlyVestingManager() {
        if (!accessRestriction.hasRole(VESTING_MANAGER_ROLE, msg.sender))
            revert NotVestingManager();
        _;
    }

    /**
     * @dev FOTVesting Constructor
     */
    constructor(address _FOTDistributor, address _accessRestrictionAddress) {
        FOTDistributor = IFOTDistributor(_FOTDistributor);
        accessRestriction = IAccessRestriction(_accessRestrictionAddress);
    }

    /**
     * @inheritdoc IFOTVesting
     */
    function createVestingPlan(
        uint64 _startDate,
        uint64 _cliff,
        uint64 _duration,
        uint16 _initialReleasePercentage,
        bytes32 _poolName
    ) external override onlyVestingManager {
        if (_cliff > _duration) revert InvalidCliffPeriod();
        if (_duration <= 0) revert InvalidDuration();
        if (_startDate < uint64(block.timestamp)) revert InvalidStartDate();

        // Create vesting plan
        VestingPlan memory plan = VestingPlan(
            _startDate,
            _cliff,
            _duration,
            _initialReleasePercentage,
            _poolName
        );

        // Store plan by next plan ID
        vestingPlans[_planId] = plan;

        // Emit event
        emit VestingPlanCreated(
            _planId,
            _startDate,
            _cliff,
            _duration,
            _initialReleasePercentage,
            _poolName
        );

        // Increment plan ID counter
        _planId += 1;
    }

    /**
     * @inheritdoc IFOTVesting
     */
    function setVestingPlanTGE(
        uint256 _planID,
        uint64 _tgeDate
    ) external override onlyVestingManager {
        if (_planID > _planId) revert PlanDoesNotExist();
        VestingPlan storage vestingPlan = vestingPlans[_planID];

        if (_tgeDate > vestingPlan.startDate) revert TGENotValid();

        vestingPlan.startDate = _tgeDate;
        emit VestingTGEUpdated(_planID, _tgeDate);
    }

    /**
     * @inheritdoc IFOTVesting
     */
    function createVesting(
        address _beneficiary,
        uint256 _amount,
        uint256 _planID
    )
        external
        override
        onlyApprovedContract
        validAddress(_beneficiary)
        returns (bool)
    {
        // Validate plan and amount
        if (_planID > _planId) revert PlanDoesNotExist();
        if (_amount <= 0) revert InvalidAmount();

        // Get plan details
        VestingPlan memory vestingPlan = vestingPlans[_planID];

        // Create user vesting schedule

        UserVesting storage userVesting = userVestings[_beneficiary][_planID];
        userVesting.vestedAmount += _amount;

        // Update beneficiary stats
        HolderStat storage holderStat = holdersStat[_beneficiary];
        holderStat.vestingAmount += _amount;

        // Emit event
        emit VestingCreated(
            _planID,
            _beneficiary,
            vestingPlan.startDate,
            _amount
        );

        return true;
    }

    /**
     * @inheritdoc IFOTVesting
     */
    function claim(uint256 _planID) external override nonReentrant {
        // Get claimable amount
        uint256 claimableAmount = _calculateClaimableTokens(
            msg.sender,
            _planID
        );

        // Validate amount
        if (claimableAmount <= 0) revert NotEnoughVestedTokens();

        // Get vesting plan
        VestingPlan memory vestingPlan = vestingPlans[_planID];
        UserVesting storage userVesting = userVestings[msg.sender][_planID];
        userVesting.claimedAmount += claimableAmount;

        // Update beneficiary stats
        HolderStat storage holderStat = holdersStat[msg.sender];
        holderStat.claimedAmount += claimableAmount;

        // Distribute tokens
        bool success = FOTDistributor.distribute(
            vestingPlan.poolName,
            claimableAmount,
            msg.sender
        );

        // Require success
        if (!success) revert TokenTransferFailed();

        // Emit event
        emit Claimed(_planID, claimableAmount, msg.sender);
    }

    /**
     * @inheritdoc IFOTVesting
     */
    function setDebt(
        address _beneficiary,
        uint256 _debtAmount
    ) external override onlyApprovedContract validAddress(_beneficiary) {
        // Get beneficiary stats
        HolderStat storage holderStat = holdersStat[_beneficiary];

        // Validate debt amount
        if (holderStat.vestingAmount < (_debtAmount + holderStat.claimedAmount))
            revert DebtLimitExceeded();

        // Loop through vesting schedules
        uint256 remainingDebt = _debtAmount;
        uint256 availableAmount = 0;
        uint256 debtToClaim = 0;
        for (uint16 i = 0; i < _planId && remainingDebt > 0; i++) {
            UserVesting storage currentVesting = userVestings[_beneficiary][i];

            // Get available vesting amount
            availableAmount =
                currentVesting.vestedAmount -
                currentVesting.claimedAmount;

            // Calculate debt to claim from this vesting
            debtToClaim = Math.min(remainingDebt, availableAmount);

            // Update claimed amount
            currentVesting.claimedAmount += debtToClaim;

            // Update remaining debt
            remainingDebt -= debtToClaim;

            emit DebtCreatedInPlan(i, debtToClaim, _beneficiary);
        }

        // Update total claimed
        holderStat.claimedAmount += _debtAmount;

        // Emit event
        emit DebtCreated(_debtAmount, _beneficiary);
    }

    // /*
    //  * @dev Releases vested tokens to beneficiary
    //  * @param _beneficiary Beneficiary address
    //  * @param _planID Plan ID
    //  * @param __releaseAmount release amount
    //  */
    // function _release(
    //     uint256 _planID,
    //     address _beneficiary,
    //     uint256 _releaseAmount
    // ) private {
    //     // Validate amount
    //     if (_releaseAmount <= 0) revert NotEnoughVestedTokens();

    //     // Get vesting plan
    //     VestingPlan memory vestingPlan = vestingPlans[_planID];

    //     // Update beneficiary stats
    //     HolderStat storage holderStat = holdersStat[_beneficiary];
    //     holderStat.claimedAmount += _releaseAmount;

    //     // Distribute tokens
    //     bool success = FOTDistributor.distribute(
    //         vestingPlan.poolName,
    //         _releaseAmount,
    //         _beneficiary
    //     );

    //     // Require success
    //     if (!success) revert TokenTransferFailed();
    // }

    /**
     * @inheritdoc IFOTVesting
     */
    function getClaimableTokens(
        address _beneficiary,
        uint256 _planID
    ) external view returns (uint256) {
        return _calculateClaimableTokens(_beneficiary, _planID);
    }

    /**
     * @notice Calculates the amount of tokens claimable by a beneficiary for a specific vesting plan
     * @dev This function determines the difference between released tokens and already claimed tokens
     * @param _beneficiary The address of the beneficiary
     * @param _planID The ID of the vesting plan
     * @return claimableAmount The amount of tokens that can be claimed
     */
    function _calculateClaimableTokens(
        address _beneficiary,
        uint256 _planID
    ) internal view returns (uint256 claimableAmount) {
        uint256 releasedTokens = _calculateReleasedTokensAtTimestamp(
            _beneficiary,
            _planID,
            uint64(block.timestamp)
        );
        UserVesting memory userVesting = userVestings[_beneficiary][_planID];
        claimableAmount = releasedTokens > userVesting.claimedAmount
            ? releasedTokens - userVesting.claimedAmount
            : 0;
    }

    /**
     * @notice Calculates the number of tokens released at a specific timestamp for a beneficiary's vesting plan
     * @dev This function handles various scenarios: before start, during cliff, linear vesting, and after end
     * @param _beneficiary The address of the beneficiary
     * @param _planID The ID of the vesting plan
     * @param _timestamp The timestamp at which to calculate released tokens
     * @return The amount of tokens released at the given timestamp
     */
    function _calculateReleasedTokensAtTimestamp(
        address _beneficiary,
        uint256 _planID,
        uint64 _timestamp
    ) private view returns (uint256) {
        UserVesting memory userVesting = userVestings[_beneficiary][_planID];
        VestingPlan memory vestingPlan = vestingPlans[_planID];

        if (_timestamp < vestingPlan.startDate) {
            return 0;
        }

        uint256 vestedAmount = userVesting.vestedAmount;
        uint64 unlockDate = vestingPlan.startDate + vestingPlan.cliff;
        uint64 endDate = vestingPlan.startDate + vestingPlan.duration;

        if (_timestamp >= endDate) {
            return vestedAmount;
        }

        uint256 initialRelease = (vestedAmount *
            vestingPlan.initialReleasePercentage) / 10000;

        if (_timestamp <= unlockDate) {
            return initialRelease;
        }

        uint256 remainingTokens = vestedAmount - initialRelease;
        uint64 vestingPeriod = endDate - unlockDate;
        uint64 elapsedTime = _timestamp - unlockDate;

        return initialRelease + (remainingTokens * elapsedTime) / vestingPeriod;
    }

    // /**
    //  * @dev Calculates currently claimable tokens
    //  * @param _beneficiary Beneficiary address
    //  * @param _planID Plan ID
    //  */
    // function _getClaimableToken(
    //     address _beneficiary,
    //     uint256 _planID
    // ) private returns (uint256) {
    //     // Get vesting schedules
    //     UserVesting storage currentVesting = userVestings[_beneficiary][
    //         _planID
    //     ];

    //     // Get plan details
    //     VestingPlan memory vestingPlan = vestingPlans[_planID];

    //     // require(tge > 0 && tge > vestingPlan.startDate, "FOTVesting::TGE is not valid");
    //     uint64 tge = vestingPlan.startDate;
    //     uint64 endDate = tge + vestingPlan.duration;
    //     uint64 cliffDate = tge + vestingPlan.cliff;

    //     // Get current time
    //     uint64 currentTime = uint64(block.timestamp);

    //     // Initialize claimable amount
    //     uint256 claimableAmount = 0;
    //     uint256 availableAmount = 0;
    //     uint256 releaseAmount = 0;
    //     uint64 elapsedTime = 0;
    //     uint64 unlockDuration = 0;
    //     uint256 remainingAfterInitial = 0;

    //     // Ensure correct beneficiary

    //     if (currentVesting.claimedAmount == currentVesting.vestedAmount) {
    //         return 0; // Skip fully claimed schedules
    //     }

    //     // Check if fully vested
    //     if (currentTime >= endDate) {
    //         releaseAmount = currentVesting.vestedAmount;
    //     } else if (currentTime > cliffDate) {
    //         // Calculate partial vesting amount
    //         elapsedTime = currentTime - cliffDate;
    //         unlockDuration = endDate - cliffDate;

    //         releaseAmount =
    //             (currentVesting.vestedAmount *
    //                 vestingPlan.initialReleasePercentage) /
    //             10000;

    //         remainingAfterInitial = currentVesting.vestedAmount - releaseAmount;

    //         releaseAmount +=
    //             (remainingAfterInitial * elapsedTime) /
    //             unlockDuration;
    //     } else if (currentTime >= tge) {
    //         releaseAmount =
    //             (currentVesting.vestedAmount *
    //                 vestingPlan.initialReleasePercentage) /
    //             10000;
    //     }

    //     // Calculate available amount
    //     availableAmount = releaseAmount > currentVesting.claimedAmount
    //         ? releaseAmount - currentVesting.claimedAmount
    //         : 0;

    //     // Add to claimable amount
    //     claimableAmount += availableAmount;

    //     // Update claimed
    //     currentVesting.claimedAmount += availableAmount;
    //     // }
    //     return claimableAmount;
    // }
}
