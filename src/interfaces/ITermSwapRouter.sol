// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice DEX adapter used by TermMarket to convert skimmed swap fees.
/// Unset → canonical trading fees stay inactive (no skim).
interface ITermSwapRouter {
    function swapExactETHForToken(address token, address to) external payable returns (uint256 amountOut);

    function swapExactTokenForETH(address token, uint256 amountIn, address to) external returns (uint256 ethOut);
}
