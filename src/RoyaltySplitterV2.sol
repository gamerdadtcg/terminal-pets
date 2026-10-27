// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWETH {
    function withdraw(uint256 amount) external;
}

/// @title RoyaltySplitterV2
/// @notice Payout address for OpenSea creator earnings (set by the collection owner in OpenSea Studio).
/// Replaces the V1 RoyaltySplitter, whose Hopper address is immutable and points at the V1 Hopper.
///
/// Split (identical to V1): 2/3 -> HopperV2, 1/3 -> treasury. Any remainder from integer division goes to the treasury.
///
/// Design
///  - `receive()` only accepts ETH (one tiny event, no storage write), so it works with a 2300 gas stipend
///    (`transfer`/WETH9 `withdraw`) and costs a marketplace almost nothing. Nothing is pushed from `receive()`.
///  - `distribute()` is permissionless. It accounts every ETH wei not yet owed (balance - owed), splits it, and pushes
///    each share with a gas cap and no returndata copy. A recipient that reverts or burns gas only strands its own
///    share as `owedHopper` / `owedTreasury`; the other share is still delivered, and anyone can retry.
///  - WETH (accepted-offer sales are paid in WETH): `unwrapWeth()` is permissionless, withdraws all WETH to ETH and runs
///    the normal split. So WETH royalties are split exactly like ETH.
///  - Any other ERC20: `sweepToken(token)` is permissionless and sends the whole balance to the treasury (HopperV2 only
///    holds ETH, and the contract cannot pick a price to swap at). WETH cannot be swept, only unwrapped.
///  - NFTs / ERC1155 sent here are not supported and cannot be recovered.
///
/// Powers: there is NO owner, no upgrade path, no pause. HopperV2 and WETH are immutable. The only mutable value is
/// `treasury`, and only the current treasury may change it (`setTreasury`), because it only ever affects the treasury's own
/// 1/3. Nobody can redirect the Hopper's 2/3.
contract RoyaltySplitterV2 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant HOPPER_SHARES = 2;
    uint256 public constant TOTAL_SHARES = 3;
    /// @dev Gas forwarded to each recipient. Enough for HopperV2 (one event) and a Safe/EOA, bounded against gas bombs.
    uint256 public constant PUSH_GAS = 100_000;

    address public immutable hopperV2;
    address public immutable weth;
    address public treasury;

    uint256 public owedHopper;
    uint256 public owedTreasury;

    error ZeroAddress();
    error NotTreasury();
    error CannotSweepWeth();

    event Received(uint256 amount);
    event Distributed(uint256 toHopper, uint256 toTreasury);
    event PushFailed(address indexed to, uint256 amount);
    event WethUnwrapped(uint256 amount);
    event TokenSwept(address indexed token, uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    constructor(address hopperV2_, address treasury_, address weth_) {
        if (hopperV2_ == address(0) || treasury_ == address(0) || weth_ == address(0)) revert ZeroAddress();
        hopperV2 = hopperV2_;
        treasury = treasury_;
        weth = weth_;
    }

    /// @dev Must stay trivially cheap: 2300 gas stipend callers (WETH9.withdraw, `transfer`) have to succeed.
    receive() external payable {
        emit Received(msg.value);
    }

    /// @notice Split and deliver all ETH not yet owed. Permissionless.
    function distribute() external nonReentrant {
        _distribute();
    }

    /// @notice Unwrap all WETH held, then split like ETH. Permissionless.
    function unwrapWeth() external nonReentrant {
        uint256 bal = IERC20(weth).balanceOf(address(this));
        if (bal > 0) {
            IWETH(weth).withdraw(bal); // ETH comes back through `receive()`
            emit WethUnwrapped(bal);
        }
        _distribute();
    }

    /// @notice Send the whole balance of a non-WETH ERC20 to the treasury. Permissionless.
    function sweepToken(address token) external nonReentrant {
        if (token == weth) revert CannotSweepWeth();
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) {
            IERC20(token).safeTransfer(treasury, bal);
            emit TokenSwept(token, bal);
        }
    }

    /// @notice Treasury-only: replace the treasury address (affects only the treasury's own 1/3).
    function setTreasury(address newTreasury) external {
        if (msg.sender != treasury) revert NotTreasury();
        if (newTreasury == address(0)) revert ZeroAddress();
        emit TreasuryUpdated(treasury, newTreasury);
        treasury = newTreasury;
    }

    /// @notice ETH that would be split by the next `distribute()` (excludes already-owed amounts).
    function pending() public view returns (uint256) {
        uint256 accounted = owedHopper + owedTreasury;
        uint256 bal = address(this).balance;
        return bal > accounted ? bal - accounted : 0;
    }

    function preview(uint256 amount) external pure returns (uint256 hopperAmount, uint256 treasuryAmount) {
        hopperAmount = (amount * HOPPER_SHARES) / TOTAL_SHARES;
        treasuryAmount = amount - hopperAmount;
    }

    function _distribute() internal {
        uint256 fresh = pending();
        if (fresh > 0) {
            uint256 h = (fresh * HOPPER_SHARES) / TOTAL_SHARES;
            owedHopper += h;
            owedTreasury += fresh - h;
        }
        uint256 h2 = owedHopper;
        uint256 t2 = owedTreasury;
        if (h2 > 0) {
            owedHopper = 0;
            (bool ok,) = hopperV2.call{value: h2, gas: PUSH_GAS}("");
            if (!ok) {
                owedHopper = h2;
                emit PushFailed(hopperV2, h2);
                h2 = 0;
            }
        }
        if (t2 > 0) {
            owedTreasury = 0;
            (bool ok,) = treasury.call{value: t2, gas: PUSH_GAS}("");
            if (!ok) {
                owedTreasury = t2;
                emit PushFailed(treasury, t2);
                t2 = 0;
            }
        }
        if (h2 > 0 || t2 > 0) emit Distributed(h2, t2);
    }
}
