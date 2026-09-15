// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal TBA implementation that can receive Pulse ETH.
/// Swap for a full ERC-6551 account on production if you need execution.
contract ReceivableAccount {
    receive() external payable {}

    fallback() external payable {}
}
