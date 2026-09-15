// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Canonical TERM/ETH pool companion. Not a fee-on-transfer token.
/// The pool calls `onSwap` with the trader's input amount; TermMarket pulls the
/// configured fee (default 3%) and routes Hopper / burn / treasury cuts.
interface ITermMarket {
    function onSwap(address tokenIn, uint256 amountIn) external payable;

    function quote(uint256 amountIn)
        external
        view
        returns (uint256 hopperCut, uint256 burnCut, uint256 treasuryCut, uint256 totalFee);

    function isActive() external view returns (bool);
}
