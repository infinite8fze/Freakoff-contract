// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.24;

interface IPause {
    // Events
    event Paused(bytes32 indexed contractName, bytes32 indexed functionName);
    event Unpaused(bytes32 indexed contractName, bytes32 indexed functionName);
    event GeneralPaused();
    event GeneralUnpaused();

    event PauserRoleSet(
        bytes32 indexed contractName,
        bytes32[] functionNames,
        bytes32 indexed role
    );
    event PauserRoleRemoved(
        bytes32 indexed contractName,
        bytes32[] functionNames,
        bytes32 indexed role
    );
}
