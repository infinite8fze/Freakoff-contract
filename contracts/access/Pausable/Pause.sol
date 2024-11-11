// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

import {IPause} from "./IPause.sol";

contract Pause is IPause {
    bool public generalPaused;
    mapping(bytes32 => bool) public paused;
    mapping(bytes32 => bytes32) public pauserRole;

    function _generalPause() internal {
        generalPaused = true;
        emit GeneralPaused();
    }

    function _generalUnpause() internal {
        generalPaused = false;
        emit GeneralUnpaused();
    }

    function _pause(bytes32 contractName, bytes32 functionName) internal {
        bytes32 key = _generateKey(contractName, functionName);
        paused[key] = true;
        emit Paused(contractName, functionName);
    }

    function _unpause(bytes32 contractName, bytes32 functionName) internal {
        bytes32 key = _generateKey(contractName, functionName);
        paused[key] = false;
        emit Unpaused(contractName, functionName);
    }

    function _setPauserRole(
        bytes32 contractName,
        bytes32[] memory functionNames,
        bytes32 role
    ) internal {
        for (uint256 i = 0; i < functionNames.length; i++) {
            bytes32 key = _generateKey(contractName, functionNames[i]);
            pauserRole[key] = role;
        }
        emit PauserRoleSet(contractName, functionNames, role);
    }

    function _removePauserRole(
        bytes32 contractName,
        bytes32[] memory functionNames,
        bytes32 role
    ) internal {
        for (uint256 i = 0; i < functionNames.length; i++) {
            bytes32 key = _generateKey(contractName, functionNames[i]);
            if (pauserRole[key] == role) {
                pauserRole[key] = bytes32(0);
            }
        }
        emit PauserRoleRemoved(contractName, functionNames, role);
    }

    function _checkStatus(
        bytes32 contractName,
        bytes32 functionName
    ) internal view returns (bool) {
        bytes32 key = _generateKey(contractName, functionName);
        return paused[key] || generalPaused;
    }

    function _generateKey(
        bytes32 contractName,
        bytes32 functionName
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(contractName, functionName));
    }
}
