// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITermSwapRouter} from "../../src/interfaces/ITermSwapRouter.sol";

/// @dev 1:1 ETH ↔ `$TERM`. Tests pre-fund this contract with both sides.
contract MockTermSwapRouter is ITermSwapRouter {
    receive() external payable {}

    function swapExactETHForToken(address token, address to) external payable returns (uint256 amountOut) {
        amountOut = msg.value;
        IERC20(token).transfer(to, amountOut);
    }

    function swapExactTokenForETH(address token, uint256 amountIn, address to) external returns (uint256 ethOut) {
        IERC20(token).transferFrom(msg.sender, address(this), amountIn);
        ethOut = amountIn;
        (bool ok,) = to.call{value: ethOut}("");
        require(ok, "eth out");
    }
}
