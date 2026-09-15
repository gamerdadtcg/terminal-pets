// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPulseRouter} from "../../src/interfaces/IPulseRouter.sol";

contract MockStockToken is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev 1 wei ETH → `rate` token units. Used only in tests.
contract MockPulseRouter is IPulseRouter {
    uint256 public immutable rate;

    constructor(uint256 rate_) {
        rate = rate_ == 0 ? 1 : rate_;
    }

    function swapExactETHForToken(address token, address to) external payable returns (uint256 amountOut) {
        amountOut = msg.value * rate;
        (bool minted,) = token.call(abi.encodeWithSignature("mint(address,uint256)", to, amountOut));
        if (minted) return amountOut;
        IERC20(token).transfer(to, amountOut);
    }
}
