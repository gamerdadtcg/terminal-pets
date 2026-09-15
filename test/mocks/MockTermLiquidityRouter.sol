// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITermLiquidityRouter} from "../../src/interfaces/ITermLiquidityRouter.sol";

/// @notice Test DEX adapter: pulls `$TERM` from TermFund and keeps ETH.
contract MockTermLiquidityRouter is ITermLiquidityRouter {
    uint256 public lastEth;
    uint256 public lastTerm;
    address public lastToken;
    address public lastLpTo;

    function addLiquidityETH(address token, uint256 tokenAmount, address lpTo)
        external
        payable
        returns (uint256 liquidity)
    {
        lastEth = msg.value;
        lastTerm = tokenAmount;
        lastToken = token;
        lastLpTo = lpTo;
        if (tokenAmount > 0) {
            IERC20(token).transferFrom(msg.sender, address(this), tokenAmount);
        }
        liquidity = msg.value + tokenAmount;
    }
}
