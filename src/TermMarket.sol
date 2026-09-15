// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CollectionConfig} from "./CollectionConfig.sol";
import {IHopper} from "./interfaces/IHopper.sol";
import {IERC20Burnable} from "./interfaces/IERC20Burnable.sol";
import {ITermMarket} from "./interfaces/ITermMarket.sol";
import {ITermSwapRouter} from "./interfaces/ITermSwapRouter.sol";

/// @title TermMarket
/// @notice Skims canonical TERM/ETH swap volume. `$TERM` itself is a normal ERC-20
/// (no fee-on-transfer). Only the bound pool may call `onSwap`.
///
/// Default 3% of input (tunable bps):
///   1.5% → ETH to Hopper (Pulse fuel)
///   1.0% → `$TERM` buy (if needed) then burn
///   0.5% → treasury
///
/// Inactive until owner sets both `canonicalPool` and `swapRouter`
/// (`TERM_POOL` / `TERM_SWAP_ROUTER` at deploy, or later). Ignite ETH is 50%
/// Hopper / 50% buy-and-burn `$TERM`, not this contract.
contract TermMarket is Ownable, ReentrancyGuard, ITermMarket {
    using SafeERC20 for IERC20;

    uint16 public constant BPS = 10_000;

    IERC20 public immutable term;
    IHopper public immutable hopper;

    address public treasury;
    address public canonicalPool;
    ITermSwapRouter public swapRouter;

    uint16 public hopperBps;
    uint16 public burnBps;
    uint16 public treasuryBps;

    error ZeroAddress();
    error BadToken();
    error BadBps();
    error WrongFee();
    error NotPool();
    error MarketInactive();
    error SwapFailed();
    error TransferFailed();

    event CanonicalPoolUpdated(address indexed pool);
    event SwapRouterUpdated(address indexed router);
    event TreasuryUpdated(address indexed treasury);
    event FeeBpsUpdated(uint16 hopperBps, uint16 burnBps, uint16 treasuryBps);
    event Skimmed(
        address indexed tokenIn,
        uint256 amountIn,
        uint256 hopperCut,
        uint256 burnCut,
        uint256 treasuryCut,
        uint256 burnedTerm
    );

    constructor(address initialOwner, address term_, address hopper_, address treasury_) Ownable(initialOwner) {
        if (term_ == address(0) || hopper_ == address(0) || treasury_ == address(0)) revert ZeroAddress();
        term = IERC20(term_);
        hopper = IHopper(hopper_);
        treasury = treasury_;
        hopperBps = CollectionConfig.TRADE_HOPPER_BPS;
        burnBps = CollectionConfig.TRADE_BURN_BPS;
        treasuryBps = CollectionConfig.TRADE_TREASURY_BPS;
    }

    receive() external payable {}

    function setCanonicalPool(address pool) external onlyOwner {
        canonicalPool = pool;
        emit CanonicalPoolUpdated(pool);
    }

    function setSwapRouter(address router_) external onlyOwner {
        swapRouter = ITermSwapRouter(router_);
        emit SwapRouterUpdated(router_);
    }

    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    /// @notice Replace Hopper / burn / treasury cuts. Sum must equal `TRADE_FEE_BPS` (3%).
    function setFeeBps(uint16 hopperBps_, uint16 burnBps_, uint16 treasuryBps_) external onlyOwner {
        if (uint256(hopperBps_) + burnBps_ + treasuryBps_ != CollectionConfig.TRADE_FEE_BPS) revert BadBps();
        hopperBps = hopperBps_;
        burnBps = burnBps_;
        treasuryBps = treasuryBps_;
        emit FeeBpsUpdated(hopperBps_, burnBps_, treasuryBps_);
    }

    function isActive() public view returns (bool) {
        return canonicalPool != address(0) && address(swapRouter) != address(0);
    }

    function totalFeeBps() public view returns (uint16) {
        return hopperBps + burnBps + treasuryBps;
    }

    function quote(uint256 amountIn)
        public
        view
        returns (uint256 hopperCut, uint256 burnCut, uint256 treasuryCut, uint256 totalFee)
    {
        uint16 total = totalFeeBps();
        if (amountIn == 0 || total == 0) return (0, 0, 0, 0);
        totalFee = (amountIn * total) / BPS;
        hopperCut = (totalFee * hopperBps) / total;
        burnCut = (totalFee * burnBps) / total;
        treasuryCut = totalFee - hopperCut - burnCut;
    }

    /// @notice Canonical pool: `tokenIn` is `address(0)` for ETH, or `$TERM`.
    /// `amountIn` is the trader's full input. Caller pays / approves `totalFee`.
    function onSwap(address tokenIn, uint256 amountIn) external payable nonReentrant {
        if (!isActive()) revert MarketInactive();
        if (msg.sender != canonicalPool) revert NotPool();

        (uint256 hopperCut, uint256 burnCut, uint256 treCut, uint256 totalFee) = quote(amountIn);
        if (totalFee == 0) revert WrongFee();

        if (tokenIn == address(0)) {
            if (msg.value != totalFee) revert WrongFee();
            uint256 burned = _routeEth(hopperCut, burnCut, treCut);
            emit Skimmed(tokenIn, amountIn, hopperCut, burnCut, treCut, burned);
        } else if (tokenIn == address(term)) {
            if (msg.value != 0) revert WrongFee();
            term.safeTransferFrom(msg.sender, address(this), totalFee);
            uint256 burned = _routeTerm(hopperCut, burnCut, treCut);
            emit Skimmed(tokenIn, amountIn, hopperCut, burnCut, treCut, burned);
        } else {
            revert BadToken();
        }
    }

    function _routeEth(uint256 hopperCut, uint256 burnCut, uint256 treCut) internal returns (uint256 burned) {
        if (hopperCut > 0) {
            hopper.deposit{value: hopperCut}();
        }
        if (burnCut > 0) {
            uint256 before = term.balanceOf(address(this));
            try swapRouter.swapExactETHForToken{value: burnCut}(address(term), address(this)) returns (uint256) {}
            catch {
                revert SwapFailed();
            }
            burned = term.balanceOf(address(this)) - before;
            if (burned > 0) {
                IERC20Burnable(address(term)).burn(burned);
            }
        }
        if (treCut > 0) {
            (bool ok,) = treasury.call{value: treCut}("");
            if (!ok) revert TransferFailed();
        }
    }

    function _routeTerm(uint256 hopperCut, uint256 burnCut, uint256 treCut) internal returns (uint256 burned) {
        if (hopperCut > 0) {
            term.forceApprove(address(swapRouter), hopperCut);
            try swapRouter.swapExactTokenForETH(address(term), hopperCut, address(hopper)) returns (uint256) {}
            catch {
                revert SwapFailed();
            }
            term.forceApprove(address(swapRouter), 0);
        }
        if (burnCut > 0) {
            IERC20Burnable(address(term)).burn(burnCut);
            burned = burnCut;
        }
        if (treCut > 0) {
            term.safeTransfer(treasury, treCut);
        }
    }
}
