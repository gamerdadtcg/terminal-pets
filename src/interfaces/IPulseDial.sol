// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Ignite hook: assign a Lit pet’s Dial (1–4 stock slots, no holder pick).
interface IPulseDial {
    function assignDial(uint256 tokenId) external;
}
