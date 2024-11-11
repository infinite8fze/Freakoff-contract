// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/**
 * @title IFOTVesting Interface
 * @dev Interface for FOT vesting contract
 */
interface IFOTVesting {
    /**
     * @dev User vesting schedule details
     */
    struct UserVesting {
        uint256 vestedAmount; // Total amount vested for the beneficiary.
        uint256 claimedAmount; // Amount already claimed by the beneficiary.
    }

    /**
     * @dev Vesting plan details
     */
    struct VestingPlan {
        uint64 startDate; // Start timestamp
        uint64 cliff; // Cliff period
        uint64 duration; // Total duration
        uint16 initialReleasePercentage; // Initial release percentage
        bytes32 poolName; // Liquidity pool name
    }

    /**
     * @dev Holder vesting stats
     */
    struct HolderStat {
        uint256 vestingAmount; // Total vesting amount
        uint256 claimedAmount; // Total claimed
    }

    // Custom errors
    /// @dev Thrown when an invalid (zero) address is provided
    error InvalidAddress();

    /// @dev Thrown when the cliff period is greater than the total vesting duration
    error InvalidCliffPeriod();

    /// @dev Thrown when the vesting duration is set to zero
    error InvalidDuration();

    /// @dev Thrown when the start date is set to a past timestamp
    error InvalidStartDate();

    /// @dev Thrown when trying to interact with a non-existent vesting plan
    error PlanDoesNotExist();

    /// @dev Thrown when an invalid (zero) amount is provided for vesting
    error InvalidAmount();

    /// @dev Thrown when trying to create debt that exceeds the available vesting balance
    error DebtLimitExceeded();

    /// @dev Thrown when trying to release tokens but the vested amount is zero
    error NotEnoughVestedTokens();

    /// @dev Thrown when the token transfer fails during the release process
    error TokenTransferFailed();

    /// @dev Thrown when trying to set an invalid TGE (Token Generation Event) date
    error TGENotValid();

    /// @dev Error thrown when a non-approved contract tries to perform a restricted action
    error NotApprovedContract();

    /// @dev Error thrown when a non-vesting manager tries to perform a restricted action
    error NotVestingManager();

    /**
     * @dev Emitted when vesting is claimed
     * @param amount Claimed amount
     * @param beneficiary Beneficiary address
     * @param planId Plan ID

     */
    event Claimed(uint256 planId, uint256 amount, address indexed beneficiary);

    /**
     * @dev Emitted when vesting plan created
     * @param planId Plan ID
     * @param _startDate Start timestamp
     * @param _cliff Cliff duration
     * @param _duration Total duration
     * @param _initialReleasePercentage Initial release percentage
     * @param poolName Liquidity pool name
     */
    event VestingPlanCreated(
        uint256 planId,
        uint64 _startDate,
        uint64 _cliff,
        uint64 _duration,
        uint16 _initialReleasePercentage,
        bytes32 poolName
    );

    /**
     * @dev Emitted when debt is created
     * @param amount debt amount
     * @param dest Beneficiary
     */
    event DebtCreated(uint256 amount, address indexed dest);

    /**
     * @dev Emitted when debt is created
     * @param planId Plan ID
     * @param amount debt amount
     * @param dest Beneficiary
     */
    event DebtCreatedInPlan(
        uint256 planId,
        uint256 amount,
        address indexed dest
    );

    /**
     * @dev Emitted when vesting created
     * @param planId Plan ID
     * @param beneficiary Beneficiary
     * @param start Start timestamp
     * @param vestedAmount Total vesting amount
     */
    event VestingCreated(
        uint256 planId,
        address indexed beneficiary,
        uint64 start,
        uint256 vestedAmount
    );

    /**
     * Emitted when tge seted
     * @param planId Plan Id
     * @param tgeDate TGE Date
     */
    event VestingTGEUpdated(uint256 planId, uint256 tgeDate);

    // External functions

    /**
     * @dev Creates new vesting plan
     * @param _startDate Start timestamp
     * @param _cliff Cliff duration
     * @param _duration Total duration
     * @param _initialReleasePercentage Initial release percentage
     * @param _poolName Liquidity pool name
     */
    function createVestingPlan(
        uint64 _startDate,
        uint64 _cliff,
        uint64 _duration,
        uint16 _initialReleasePercentage,
        bytes32 _poolName
    ) external;

    /**
     * @dev Add tge time to vesting plan
     * @param _planID plan id
     * @param tgeTime tge time
     */
    function setVestingPlanTGE(uint256 _planID, uint64 tgeTime) external;

    /**
     * @dev Creates new vesting schedule
     * @param _beneficiary Beneficiary address
     * @param _amount Total vesting amount
     * @param _planID Plan ID
     * @return Success status
     */
    function createVesting(
        address _beneficiary,
        uint256 _amount,
        uint256 _planID
    ) external returns (bool);

    /**
     * @dev Claims vested tokens
     * @param _planID Plan ID
     */
    function claim(uint256 _planID) external;

    /**
     * @dev Creates vesting debt
     * @param _beneficiary Beneficiary address
     * @param _debtAmount Debt amount
     */
    function setDebt(address _beneficiary, uint256 _debtAmount) external;

    /**
     * @notice get the amount of tokens claimable by a beneficiary for a specific vesting plan
     * @dev This function determines the difference between released tokens and already claimed tokens
     * @param _beneficiary The address of the beneficiary
     * @param _planID The ID of the vesting plan
     * @return claimableAmount The amount of tokens that can be claimed
     */
    function getClaimableTokens(
        address _beneficiary,
        uint256 _planID
    ) external view returns (uint256);

    /**
     * @dev Gets vesting plan details
     * @param planId Plan ID
     * return Vesting plan details
     */
    function vestingPlans(
        uint256 planId
    )
        external
        view
        returns (
            uint64 startDate,
            uint64 cliff,
            uint64 duration,
            uint16 initialReleasePercentage,
            bytes32 poolName
        );

    /*
     * @dev Gets user vesting details
     * @param _beneficiary Beneficiary address
     * @param planID Plan ID
     * @param index Vesting index
     * @return User vesting details
     */
    function userVestings(
        address _beneficiary,
        uint256 planID
    ) external view returns (uint256 vestedAmount, uint256 claimedAmount);

    /*
     * @dev Gets holder vesting stats
     * @param _beneficiary Holder address
     * @return Holder vesting stats
     */
    function holdersStat(
        address _beneficiary
    ) external view returns (uint256 vestingAmount, uint256 claimedAmount);
}
