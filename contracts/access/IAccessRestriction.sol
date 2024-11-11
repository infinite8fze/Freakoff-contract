// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

/**
 * @title AccessRestriction interface
 * @dev Interface for the AccessRestriction contract which manages roles and permissions
 */
interface IAccessRestriction {
    // Events
    /**
     * @dev Emitted when a new role is created
     * @param role The identifier of the new role
     * @param creator The address that created the role
     * @param adminRole The admin role for this new role
     */
    event RoleCreated(
        bytes32 indexed role,
        address indexed creator,
        bytes32 indexed adminRole
    );

    /**
     * @dev Emitted when a role is updated
     * @param role The identifier of the updated role
     * @param accountLimit The new account limit for the role
     * @param adminRole The new admin role
     * @param isCreator Whether the role can create other roles
     * @param forContracts Whether the role is for contracts
     * @param notContracts Whether the role is not for contracts
     */
    event RoleUpdated(
        bytes32 indexed role,
        uint32 accountLimit,
        bytes32 indexed adminRole,
        bool isCreator,
        bool forContracts,
        bool notContracts
    );

    /**
     * @dev Emitted when a role is deactivated
     * @param role The identifier of the deactivated role
     */
    event RoleDeactivated(bytes32 indexed role);

    /**
     * @dev Emitted when a role is activated
     * @param role The identifier of the activated role
     */
    event RoleActivated(bytes32 indexed role);

    /**
     * @dev Emitted when a role is assigned to an account
     * @param role The identifier of the assigned role
     * @param account The address of the account assigned the role
     */
    event RoleAssigned(bytes32 role, address account);

    /**
     * @dev Emitted when a role is removed from an account
     * @param role The identifier of the removed role
     * @param account The address of the account from which the role was removed
     */
    event RoleRemoved(bytes32 role, address account);

    /**
     * @dev Emitted when an account renounces a role
     * @param role The identifier of the renounced role
     * @param account The address of the account renouncing the role
     */
    event RoleRenounced(bytes32 role, address account);

    // Errors
    /// @dev Thrown when a function is called by an account that is not the role admin or owner
    error OnlyRoleAdminOrOwner();
    /// @dev Thrown when a function is called by an account that is not the creator
    error OnlyCreator();
    /// @dev Thrown when a function is called by an account that does not have the pauser role
    error NotPauserRole();
    /// @dev Thrown when access to a function is restricted
    error AccessRestricted(address account, bytes32 role);
    /// @dev Thrown when trying to assign a role that has reached its account limit
    error RoleAccountLimitReached();
    /// @dev Thrown when the message sender does not have the required role
    error MsgsenderRoleError();
    /// @dev Thrown when trying to interact with a non-existent role
    error RoleDoesNotExist();
    /// @dev Thrown when an invalid role is provided
    error InvalidRole();
    /// @dev Thrown when a function is called by an account that is not the admin or owner
    error OnlyAdminOrOwner();
    /// @dev Thrown when an account is not a contract but is required to be
    error AccountNotContract();
    /// @dev Thrown when an account is a contract but is required not to be
    error AccountIsContract();
    /// @dev Thrown when an invalid role configuration is provided
    error InvalidRoleConfiguration();
    /// @dev Thrown when there's an error related to the message sender
    error MsgsenderError();

    error AccountMustBeContract();
error AccountMustNotBeContract();

    /**
     * @dev Struct containing data for a role
     * @param isCreator Whether the role can create other roles
     * @param isActive Whether the role is currently active
     * @param forContracts Whether the role is for contracts
     * @param notContracts Whether the role is not for contracts
     * @param accountLimit The maximum number of accounts that can have this role
     * @param usedCount The number of accounts currently assigned this role
     * @param creatorAddress The address that created this role
     * @param creatorRole The role of the creator
     * @param adminRole The admin role for this role
     */
    struct roleData {
        bool isCreator;
        bool isActive;
        bool forContracts;
        bool notContracts;
        uint32 accountLimit;
        uint32 usedCount;
        address creatorAddress;
        bytes32 creatorRole;
        bytes32 adminRole;
    }

    /**
     * @dev Checks if an account has a specific role
     * @param account The address to check
     * @param role The role to check for
     */
    function ifRole(address account, bytes32 role) external;

    /**
     * @dev Creates a new role
     * @param role The identifier for the new role
     * @param accountLimit The maximum number of accounts that can have this role
     * @param creatorRole The role of the creator
     * @param adminRole The admin role for this new role
     * @param isCreator Whether this role can create other roles
     * @param forContracts Whether this role is for contracts
     * @param notContracts Whether this role is not for contracts
     */
    function createRole(
        bytes32 role,
        uint32 accountLimit,
        bytes32 creatorRole,
        bytes32 adminRole,
        bool isCreator,
        bool forContracts,
        bool notContracts
    ) external;

    /**
     * @dev Updates an existing role
     * @param role The identifier of the role to update
     * @param accountLimit The new account limit for the role
     * @param adminRole The new admin role
     * @param isCreator Whether the role can create other roles
     * @param forContracts Whether the role is for contracts
     * @param notContracts Whether the role is not for contracts
     */
    function updateRole(
        bytes32 role,
        uint32 accountLimit,
        bytes32 adminRole,
        bool isCreator,
        bool forContracts,
        bool notContracts
    ) external;

    /**
     * @dev Deactivates a role
     * @param role The identifier of the role to deactivate
     */
    function deactivateRole(bytes32 role) external;

    /**
     * @dev Activates a role
     * @param role The identifier of the role to activate
     */
    function activateRole(bytes32 role) external;

    /**
     * @dev Pauses a specific function in a contract
     * @param contractName The name of the contract
     * @param functionName The name of the function to pause
     */
    function pause(bytes32 contractName, bytes32 functionName) external;

    /**
     * @dev Unpauses a specific function in a contract
     * @param contractName The name of the contract
     * @param functionName The name of the function to unpause
     */
    function unpause(bytes32 contractName, bytes32 functionName) external;

    /**
     * @dev Pauses all functions
     */
    function generalPause() external;

    /**
     * @dev Unpauses all functions
     */
    function generalUnpause() external;

    /**
     * @dev Grants a role to an account
     * @param role The role to grant
     * @param account The account to receive the role
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes a role from an account
     * @param role The role to revoke
     * @param account The account to revoke the role from
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Allows an account to renounce a role
     * @param role The role to renounce
     * @param account The account renouncing the role
     */
    function renounceRole(bytes32 role, address account) external;

    /**
     * @dev Checks if an account has a specific role
     * @param role The role to check
     * @param account The account to check
     * @return bool indicating whether the account has the role
     */
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    /**
     * @dev Gets the admin role for a specific role
     * @param role The role to get the admin for
     * @return bytes32 The admin role
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Checks the pause status of a specific function in a contract
     * @param contractName The name of the contract
     * @param functionName The name of the function
     * @return bool indicating whether the function is paused
     */
    function checkStatus(
        bytes32 contractName,
        bytes32 functionName
    ) external view returns (bool);

    /**
     * @dev Sets the pauser role for specific functions in a contract
     * @param contractName The name of the contract
     * @param functionNames An array of function names
     * @param role The role to set as pauser
     */
    function setPauserRole(
        bytes32 contractName,
        bytes32[] memory functionNames,
        bytes32 role
    ) external;

    /**
     * @dev Removes the pauser role for specific functions in a contract
     * @param contractName The name of the contract
     * @param functionNames An array of function names
     * @param role The role to remove as pauser
     */
    function removePauserRole(
        bytes32 contractName,
        bytes32[] memory functionNames,
        bytes32 role
    ) external;
}