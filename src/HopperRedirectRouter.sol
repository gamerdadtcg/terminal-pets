// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITermSwapRouter} from "./interfaces/ITermSwapRouter.sol";

/// @title HopperRedirectRouter
/// @notice Drop-in `ITermSwapRouter` that wraps the real DEX adapter and, when the
/// caller asks for ETH to be delivered to the legacy (V1) Hopper, delivers it to
/// HopperV2 instead.
///
/// Why this works: `IgniteModule._swapTermToHopper` and `TermMarket._routeTerm`
/// call `swapRouter.swapExactTokenForETH(term, amount, address(hopper))` where the
/// destination is their immutable V1 Hopper address, but the `swapRouter` itself is
/// owner-settable (`setSwapRouter`). Point both at this contract and the Ignite
/// 25% `$TERM`→ETH slice and the TermMarket `$TERM`-side skim fund HopperV2.
///
/// It does NOT cover the paths that call `hopper.deposit{value}` directly
/// (Ignite's 50% ETH slice, TermMarket's ETH-side skim) or royalties; those are
/// hard-wired to the V1 Hopper. See docs/PULSE_V2_DESIGN.md.
///
/// Soft-fail for Ignite only: if the underlying DEX swap reverts (pool moved past the adapter's slippage, empty
/// pool, ...), a swap requested by `softFailCaller` (the IgniteModule) returns the `$TERM` to the caller and
/// returns 0 instead of reverting. Ignite then still completes: the 250 `$TERM` simply stays in Ignite's escrow.
/// Without this, anyone who nudges the (tiny) pool price could make every `ignite()` revert. Any other caller
/// (TermMarket) still reverts on a failed swap.
///
/// No owner, no storage beyond immutables, holds no funds between calls.
contract HopperRedirectRouter is ITermSwapRouter {
    using SafeERC20 for IERC20;

    ITermSwapRouter public immutable inner;
    address public immutable legacyHopper;
    address public immutable hopperV2;
    address public immutable softFailCaller;

    event SwapSkipped(address indexed caller, uint256 amountIn);

    error ZeroAddress();
    error TransferFailed();
    error SwapFailed();

    constructor(address inner_, address legacyHopper_, address hopperV2_, address softFailCaller_) {
        if (inner_ == address(0) || legacyHopper_ == address(0) || hopperV2_ == address(0)) revert ZeroAddress();
        inner = ITermSwapRouter(inner_);
        legacyHopper = legacyHopper_;
        hopperV2 = hopperV2_;
        softFailCaller = softFailCaller_;
    }

    receive() external payable {}

    function swapExactETHForToken(address token, address to) external payable returns (uint256 amountOut) {
        return inner.swapExactETHForToken{value: msg.value}(token, to);
    }

    function swapExactTokenForETH(address token, uint256 amountIn, address to) external returns (uint256 ethOut) {
        IERC20 t = IERC20(token);
        t.safeTransferFrom(msg.sender, address(this), amountIn);
        t.forceApprove(address(inner), amountIn);
        uint256 before = address(this).balance;
        try inner.swapExactTokenForETH(token, amountIn, address(this)) returns (uint256) {}
        catch {
            if (msg.sender != softFailCaller) revert SwapFailed();
            t.forceApprove(address(inner), 0);
            t.safeTransfer(msg.sender, amountIn);
            emit SwapSkipped(msg.sender, amountIn);
            return 0;
        }
        t.forceApprove(address(inner), 0);
        ethOut = address(this).balance - before;
        address dest = to == legacyHopper ? hopperV2 : to;
        if (dest == address(0)) revert ZeroAddress();
        (bool ok,) = dest.call{value: ethOut}("");
        if (!ok) revert TransferFailed();
    }
}
