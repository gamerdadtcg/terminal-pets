// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Settable Robinhood Chain DEX adapter. Buys Stock Tokens (Dial) or `$TERM` (no Dial).
interface IPulseRouter {
    /// @dev Spends `msg.value` ETH and sends `token` to `to`.
    function swapExactETHForToken(address token, address to) external payable returns (uint256 amountOut);
}
