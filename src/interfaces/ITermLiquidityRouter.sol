// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice DEX adapter that pairs ETH with `$TERM`. Unset on TermFund → ETH stays in custody.
interface ITermLiquidityRouter {
    /// @dev Caller has approved `tokenAmount` of `token`. Spends `msg.value` ETH.
    /// LP tokens go to `lpTo`.
    function addLiquidityETH(address token, uint256 tokenAmount, address lpTo)
        external
        payable
        returns (uint256 liquidity);
}
