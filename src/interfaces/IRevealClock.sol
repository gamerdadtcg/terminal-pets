// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Anything that exposes the CollectionNFT reveal timestamp. The live (V1) Hopper does.
interface IRevealClock {
    function revealedAt() external view returns (uint64);
}
