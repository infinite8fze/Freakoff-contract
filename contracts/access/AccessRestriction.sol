// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IAccessRestriction} from "./IAccessRestriction.sol";
import {Pause} from "./Pausable/Pause.sol";

/** @title AccessRestriction contract */

contract AccessRestriction is Pause, IAccessRestriction {
    mapping(bytes32 => roleData) public roles;
    mapping(bytes32 => mapping(address => bool)) public assignRole;

    modifier onlyRoleAdminOrOwner(bytes32 role) {
        if (
            !(hasRole(roles[role].adminRole, msg.sender) ||
                hasRole(keccak256("OWNER_ROLE"), msg.sender))
        ) {
            revert OnlyRoleAdminOrOwner();
        }
        _;
    }

    modifier onlyCreator(bytes32 creatorRole) {
        if (
            !(roles[creatorRole].isCreator &&
                assignRole[creatorRole][msg.sender])
        ) {
            revert OnlyCreator();
        }
        _;
    }

    modifier onlyOwnerOrAdmin(address msgsender) {
        if (
            !(hasRole(keccak256("OWNER_ROLE"), msgsender) ||
                hasRole(keccak256("ADMIN_ROLE"), msgsender))
        ) {
            revert OnlyAdminOrOwner();
        }
        _;
    }

    modifier onlyPauser(bytes32 contractName, bytes32 functionName) {
        bytes32 key = _generateKey(contractName, functionName);
        ifRole(msg.sender, pauserRole[key]);
        _;
    }

    constructor(address _owner) {
        roles[keccak256("OWNER_ROLE")] = roleData({
            isCreator: true,
            isActive: true,
            forContracts: false,
            notContracts: false,
            accountLimit: 1,
            usedCount: 1,
            creatorAddress: _owner,
            creatorRole: keccak256("OWNER_ROLE"),
            adminRole: keccak256("OWNER_ROLE")
        });

        roles[keccak256("ADMIN_ROLE")] = roleData({
            isCreator: true,
            isActive: true,
            forContracts: false,
            notContracts: false,
            accountLimit: 5,
            usedCount: 1,
            creatorAddress: _owner,
            creatorRole: keccak256("OWNER_ROLE"),
            adminRole: keccak256("OWNER_ROLE")
        });
        assignRole[keccak256("OWNER_ROLE")][_owner] = true;
        assignRole[keccak256("ADMIN_ROLE")][_owner] = true;
    }

    function createRole(
        bytes32 role,
        uint32 accountLimit,
        bytes32 creatorRole,
        bytes32 adminRole,
        bool isCreator,
        bool forContracts,
        bool notContracts
    ) external override onlyCreator(creatorRole) {
        if (role == bytes32(0)) {
            revert InvalidRole();
        }
        if (forContracts && notContracts) {
            revert InvalidRoleConfiguration();
        }
        roles[role] = roleData({
            isCreator: isCreator,
            forContracts: forContracts,
            notContracts: notContracts,
            isActive: true,
            accountLimit: accountLimit,
            usedCount: 0,
            creatorAddress: msg.sender,
            creatorRole: creatorRole,
            adminRole: adminRole
        });
        emit RoleCreated(role, msg.sender, adminRole);
    }

    function updateRole(
        bytes32 role,
        uint32 accountLimit,
        bytes32 adminRole,
        bool isCreator,
        bool forContracts,
        bool notContracts
    ) external override onlyRoleAdminOrOwner(role) {
        if (forContracts && notContracts) {
            revert InvalidRoleConfiguration();
        }
        roles[role].accountLimit = accountLimit;
        roles[role].adminRole = adminRole;
        roles[role].isCreator = isCreator;
        roles[role].forContracts = forContracts;
        roles[role].notContracts = notContracts;
        emit RoleUpdated(
            role,
            accountLimit,
            adminRole,
            isCreator,
            forContracts,
            notContracts
        );
    }

    function deactivateRole(
        bytes32 role
    ) external override onlyRoleAdminOrOwner(role) {
        roles[role].isActive = false;
        emit RoleDeactivated(role);
    }

    function activateRole(
        bytes32 role
    ) external override onlyRoleAdminOrOwner(role) {
        roles[role].isActive = true;
        emit RoleActivated(role);
    }

    function pause(
        bytes32 contractName,
        bytes32 functionName
    ) external override onlyPauser(contractName, functionName) {
        _pause(contractName, functionName);
    }

    function unpause(
        bytes32 contractName,
        bytes32 functionName
    ) external override onlyPauser(contractName, functionName) {
        _unpause(contractName, functionName);
    }

    function generalPause() external override onlyOwnerOrAdmin(msg.sender) {
        _generalPause();
    }

    function generalUnpause() external override onlyOwnerOrAdmin(msg.sender) {
        _generalUnpause();
    }

    function setPauserRole(
        bytes32 contractName,
        bytes32[] memory functionNames,
        bytes32 role
    ) external override onlyOwnerOrAdmin(msg.sender) {
        _setPauserRole(contractName, functionNames, role);
    }

    function removePauserRole(
        bytes32 contractName,
        bytes32[] memory functionNames,
        bytes32 role
    ) external override onlyOwnerOrAdmin(msg.sender) {
        _removePauserRole(contractName, functionNames, role);
    }

    function grantRole(
        bytes32 role,
        address account
    ) external override onlyRoleAdminOrOwner(role) {
        if (!roles[role].isActive) {
            revert RoleDoesNotExist();
        }
        if (roles[role].usedCount >= roles[role].accountLimit) {
            revert RoleAccountLimitReached();
        }

        if (roles[role].forContracts) {
            uint256 size;
            assembly {
                size := extcodesize(account)
            }
            if (size == 0) {
                revert AccountMustBeContract();
            }
        }

        if (roles[role].notContracts) {
            uint256 size;
            assembly {
                size := extcodesize(account)
            }
            if (size > 0) {
                revert AccountMustNotBeContract();
            }
        }
        assignRole[role][account] = true;
        roles[role].usedCount++;
        emit RoleAssigned(role, account);
    }

    function revokeRole(
        bytes32 role,
        address account
    ) external override onlyRoleAdminOrOwner(role) {
        assignRole[role][account] = false;
        roles[role].usedCount--;
        emit RoleRemoved(role, account);
    }

    function renounceRole(bytes32 role, address account) external override {
        if (account != msg.sender) {
            revert MsgsenderError();
        }

        if (!(assignRole[role][account])) {
            revert MsgsenderRoleError();
        }
        assignRole[role][account] = false;
        roles[role].usedCount--;
        emit RoleRenounced(role, account);
    }

    function ifRole(address account, bytes32 role) public view override {
        if (!hasRole(role, account)) {
            revert AccessRestricted(account,role);
        }
    }

    function hasRole(
        bytes32 role,
        address account
    ) public view override returns (bool) {
        return assignRole[role][account] && roles[role].isActive;
    }

    function getRoleAdmin(
        bytes32 role
    ) external view override returns (bytes32) {
        return roles[role].adminRole;
    }

    function checkStatus(
        bytes32 contractName,
        bytes32 functionName
    ) external view returns (bool) {
        return _checkStatus(contractName, functionName);
    }
}
