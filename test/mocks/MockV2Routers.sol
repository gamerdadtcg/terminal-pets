// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPulseRouter} from "../../src/interfaces/IPulseRouter.sol";
import {MockStockToken} from "./MockPulseRouter.sol";

/// @dev Reverts for tokens in `failFor` (or every token when `failAll`), otherwise mints 1:1.
contract MockSelectiveRouter is IPulseRouter {
    bool public failAll;
    mapping(address => bool) public failFor;

    function setFailAll(bool v) external {
        failAll = v;
    }

    function setFailFor(address token, bool v) external {
        failFor[token] = v;
    }

    function swapExactETHForToken(address token, address to) external payable returns (uint256 amountOut) {
        require(!failAll && !failFor[token], "swap fail");
        amountOut = msg.value;
        MockStockToken(token).mint(to, amountOut);
    }
}

/// @dev Burns roughly what a Uniswap-V2-style swap costs (~100k+ gas): 3 fresh SSTOREs + mint.
contract MockHeavyRouter is IPulseRouter {
    uint256 internal _nonce;
    mapping(uint256 => uint256) internal _scratch;

    function swapExactETHForToken(address token, address to) external payable returns (uint256 amountOut) {
        uint256 n = _nonce;
        _scratch[n] = msg.value;
        _scratch[n + 1] = msg.value + 1;
        _scratch[n + 2] = msg.value + 2;
        _nonce = n + 3;
        amountOut = msg.value;
        MockStockToken(token).mint(to, amountOut);
    }
}

/// @dev A pet owner that cannot receive ETH.
contract RejectEth {}
