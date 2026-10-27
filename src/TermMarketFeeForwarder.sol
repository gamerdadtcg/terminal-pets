// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITermSwapRouter} from "./interfaces/ITermSwapRouter.sol";

/// @title TermMarketFeeForwarder
/// @notice Set as `TermMarket.treasury`. TermMarket's Hopper cut is hard-wired to the V1 Hopper, so the owner
/// moves that share into the treasury cut (`setFeeBps(0, burn, hopper + treasury)`, same total and same burn)
/// and this contract splits the treasury stream back out:
///
///   hopperPart / totalPart  -> HopperV2   (e.g. 150 / 200 = 75%)
///   the rest                -> real treasury (e.g. 50 / 200 = 25%)
///
/// ETH arrives through `receive()` and is split and pushed immediately. `receive()` never reverts and never
/// forwards more than `PUSH_GAS`, so a bad recipient cannot block canonical-pool trades; an undeliverable
/// share is kept as `owedHopper` / `owedTreasury` and anyone can `retry()`.
///
/// `$TERM` arrives by plain transfer (no hook). A keeper (or the owner) calls `flushTerm(minEthOut)`: the treasury
/// share of the `$TERM` goes to the treasury as `$TERM`, the Hopper share is swapped to ETH for HopperV2.
/// Because the router interface has no min-out argument, the keeper passes `minEthOut` and the call reverts below it.
/// It is NOT permissionless on purpose: a public caller could pass 0 and sandwich it.
contract TermMarketFeeForwarder is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant PUSH_GAS = 100_000;

    address public immutable hopperV2;
    IERC20 public immutable term;
    uint16 public immutable hopperPart;
    uint16 public immutable totalPart;

    address public treasury;
    ITermSwapRouter public swapRouter;
    address public keeper;

    uint256 public owedHopper;
    uint256 public owedTreasury;
    bool private _swapping;

    error ZeroAddress();
    error BadParts();
    error NotKeeper();
    error Slippage(uint256 got, uint256 minOut);
    error RouterUnset();

    event Forwarded(uint256 toHopper, uint256 toTreasury);
    event PushFailed(address indexed to, uint256 amount);
    event TermFlushed(uint256 termSwapped, uint256 ethOut, uint256 termToTreasury);
    event TreasuryUpdated(address indexed treasury);
    event RouterUpdated(address indexed router);
    event KeeperUpdated(address indexed keeper);

    constructor(
        address owner_,
        address hopperV2_,
        address treasury_,
        address term_,
        address router_,
        uint16 hopperPart_,
        uint16 totalPart_
    ) Ownable(owner_) {
        if (hopperV2_ == address(0) || treasury_ == address(0) || term_ == address(0)) revert ZeroAddress();
        if (hopperPart_ == 0 || hopperPart_ > totalPart_) revert BadParts();
        hopperV2 = hopperV2_;
        treasury = treasury_;
        term = IERC20(term_);
        swapRouter = ITermSwapRouter(router_);
        hopperPart = hopperPart_;
        totalPart = totalPart_;
    }

    // ------------------------------------------------------------------ ETH

    receive() external payable {
        if (_swapping || msg.value == 0) return; // swap proceeds are accounted in `flushTerm`
        uint256 h = (msg.value * hopperPart) / totalPart;
        owedHopper += h;
        owedTreasury += msg.value - h;
        _flush();
    }

    /// @notice Retry any undelivered ETH share. Permissionless, moves funds only to the fixed recipients.
    function retry() external nonReentrant {
        _flush();
    }

    /// @notice Account ETH that reached this contract without going through `receive()` (e.g. a forced
    /// selfdestruct send) and deliver it with the normal split. Permissionless, funds only reach the fixed recipients.
    function sync() external nonReentrant {
        uint256 accounted = owedHopper + owedTreasury;
        uint256 bal = address(this).balance;
        if (bal > accounted) {
            uint256 extra = bal - accounted;
            uint256 h = (extra * hopperPart) / totalPart;
            owedHopper += h;
            owedTreasury += extra - h;
        }
        _flush();
    }

    function _flush() internal {
        uint256 h = owedHopper;
        uint256 t = owedTreasury;
        if (h > 0) {
            owedHopper = 0;
            (bool ok,) = hopperV2.call{value: h, gas: PUSH_GAS}("");
            if (!ok) {
                owedHopper += h;
                emit PushFailed(hopperV2, h);
                h = 0;
            }
        }
        if (t > 0) {
            owedTreasury = 0;
            (bool ok,) = treasury.call{value: t, gas: PUSH_GAS}("");
            if (!ok) {
                owedTreasury += t;
                emit PushFailed(treasury, t);
                t = 0;
            }
        }
        if (h > 0 || t > 0) emit Forwarded(h, t);
    }

    // ----------------------------------------------------------------- $TERM

    /// @notice Keeper/owner only. Pays the treasury share of held `$TERM` to the treasury and swaps the Hopper
    /// share to ETH for HopperV2. Reverts if the swap returns less than `minEthOut`.
    function flushTerm(uint256 minEthOut) external nonReentrant {
        if (msg.sender != keeper && msg.sender != owner()) revert NotKeeper();
        if (address(swapRouter) == address(0)) revert RouterUnset();
        uint256 bal = term.balanceOf(address(this));
        uint256 toSwap = (bal * hopperPart) / totalPart;
        uint256 toTreasury = bal - toSwap;
        if (toTreasury > 0) term.safeTransfer(treasury, toTreasury);

        uint256 ethOut;
        if (toSwap > 0) {
            uint256 before = address(this).balance;
            _swapping = true;
            term.forceApprove(address(swapRouter), toSwap);
            swapRouter.swapExactTokenForETH(address(term), toSwap, address(this));
            term.forceApprove(address(swapRouter), 0);
            _swapping = false;
            ethOut = address(this).balance - before;
            if (ethOut < minEthOut) revert Slippage(ethOut, minEthOut);
            owedHopper += ethOut;
        } else if (minEthOut > 0) {
            revert Slippage(0, minEthOut);
        }
        emit TermFlushed(toSwap, ethOut, toTreasury);
        _flush();
    }

    // ----------------------------------------------------------------- admin

    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setSwapRouter(address router_) external onlyOwner {
        swapRouter = ITermSwapRouter(router_);
        emit RouterUpdated(router_);
    }

    function setKeeper(address keeper_) external onlyOwner {
        keeper = keeper_;
        emit KeeperUpdated(keeper_);
    }
}
