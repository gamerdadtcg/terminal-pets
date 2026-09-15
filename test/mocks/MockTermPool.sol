// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITermMarket} from "../../src/interfaces/ITermMarket.sol";

/// @dev 1:1 canonical TERM/ETH pool that pays TermMarket's quoted fee, then fills the net.
contract MockTermPool {
    ITermMarket public immutable market;
    IERC20 public immutable term;

    constructor(address market_, address term_) {
        market = ITermMarket(market_);
        term = IERC20(term_);
    }

    receive() external payable {}

    function swapExactETHForTerm() external payable {
        uint256 amountIn = msg.value;
        (,,, uint256 fee) = market.quote(amountIn);
        uint256 net = amountIn - fee;
        market.onSwap{value: fee}(address(0), amountIn);
        require(term.transfer(msg.sender, net), "term out");
    }

    function swapExactTermForETH(uint256 amountIn) external {
        require(term.transferFrom(msg.sender, address(this), amountIn), "term in");
        (,,, uint256 fee) = market.quote(amountIn);
        uint256 net = amountIn - fee;
        term.approve(address(market), fee);
        market.onSwap(address(term), amountIn);
        (bool ok,) = msg.sender.call{value: net}("");
        require(ok, "eth out");
    }
}
