// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ITermFund} from "./interfaces/ITermFund.sol";
import {ITermLiquidityRouter} from "./interfaces/ITermLiquidityRouter.sol";

/// @title TermFund
/// @notice Custodies **pre-reveal** royalty ETH to seed `$TERM` liquidity. Not the Hopper.
/// Not allotment escrow — Ignite `$TERM` refill stays on IgniteModule.
/// Ignite's 0.002 ETH fee does **not** land here (50% Hopper / 50% buy-and-burn).
///
/// ETH here is **pre-reveal secondary royalties** (full 7.5% of sale via
/// RoyaltySplitter). Post-reveal royalties go Hopper/treasury instead. Optional
/// `depositTerm` can still receive `$TERM` for later pairing.
///
/// If no DEX router is set, ETH sits here safely. There is no owner withdraw.
/// Later: `setRouter`, then owner calls `seedLiquidity(termAmount, ethAmount)`.
contract TermFund is Ownable, ReentrancyGuard, ITermFund {
    using SafeERC20 for IERC20;

    IERC20 public immutable term;

    address public igniteModule;
    bool public igniteLocked;
    address public termSource;
    address public lpRecipient;
    ITermLiquidityRouter public router;

    error ZeroAddress();
    error ZeroAmount();
    error AlreadyLocked();
    error NotIgnite();
    error RouterUnset();
    error InsufficientEth();
    error SeedFailed();

    event IgniteLocked(address indexed ignite);
    event RouterUpdated(address indexed router);
    event TermSourceUpdated(address indexed termSource);
    event LpRecipientUpdated(address indexed lpRecipient);
    event Deposited(address indexed from, uint256 amount);
    event TermDeposited(address indexed from, uint256 amount);
    event LiquiditySeeded(uint256 ethAmount, uint256 termAmount, uint256 liquidity, address indexed lpTo);

    constructor(address initialOwner, address term_, address termSource_) Ownable(initialOwner) {
        if (term_ == address(0) || termSource_ == address(0)) revert ZeroAddress();
        term = IERC20(term_);
        termSource = termSource_;
        lpRecipient = termSource_;
    }

    /// @notice Bind the IgniteModule once. After this, only it may `deposit` ETH.
    function lockIgnite(address ignite_) external onlyOwner {
        if (igniteLocked) revert AlreadyLocked();
        if (ignite_ == address(0)) revert ZeroAddress();
        igniteModule = ignite_;
        igniteLocked = true;
        emit IgniteLocked(ignite_);
    }

    function setRouter(address router_) external onlyOwner {
        router = ITermLiquidityRouter(router_);
        emit RouterUpdated(router_);
    }

    function setTermSource(address termSource_) external onlyOwner {
        if (termSource_ == address(0)) revert ZeroAddress();
        termSource = termSource_;
        emit TermSourceUpdated(termSource_);
    }

    function setLpRecipient(address lpRecipient_) external onlyOwner {
        if (lpRecipient_ == address(0)) revert ZeroAddress();
        lpRecipient = lpRecipient_;
        emit LpRecipientUpdated(lpRecipient_);
    }

    /// @notice Optional ETH deposit from IgniteModule. Unused by current Ignite
    /// routing (0.002 ETH is 50% Hopper / 50% buy-and-burn, not TermFund).
    function deposit() external payable {
        if (msg.sender != igniteModule) revert NotIgnite();
        if (msg.value == 0) revert ZeroAmount();
        emit Deposited(msg.sender, msg.value);
    }

    /// @notice Pre-reveal royalties (and optional donations) land here for `$TERM` LP.
    receive() external payable {
        if (msg.value > 0) emit Deposited(msg.sender, msg.value);
    }

    /// @notice Optional `$TERM` inventory for later LP. Ignite allotment refill does not use this.
    function depositTerm(uint256 amount) external {
        if (msg.sender != igniteModule) revert NotIgnite();
        if (amount == 0) revert ZeroAmount();
        term.safeTransferFrom(msg.sender, address(this), amount);
        emit TermDeposited(msg.sender, amount);
    }

    function available() public view returns (uint256) {
        return address(this).balance;
    }

    function termAvailable() public view returns (uint256) {
        return term.balanceOf(address(this));
    }

    /// @notice Pair custodied ETH with `$TERM` already in this fund, pulling any
    /// shortfall from `termSource` (must have approved this fund).
    /// Reverts if no router is set. No ETH / `$TERM` sweep to owner.
    function seedLiquidity(uint256 termAmount, uint256 ethAmount) external onlyOwner nonReentrant {
        if (address(router) == address(0)) revert RouterUnset();
        if (termAmount == 0 || ethAmount == 0) revert ZeroAmount();
        if (ethAmount > address(this).balance) revert InsufficientEth();

        IERC20 token = term;
        uint256 held = token.balanceOf(address(this));
        if (held < termAmount) {
            token.safeTransferFrom(termSource, address(this), termAmount - held);
        }
        token.forceApprove(address(router), termAmount);

        uint256 liquidity;
        try router.addLiquidityETH{value: ethAmount}(address(token), termAmount, lpRecipient) returns (uint256 lp) {
            liquidity = lp;
        } catch {
            revert SeedFailed();
        }

        token.forceApprove(address(router), 0);
        emit LiquiditySeeded(ethAmount, termAmount, liquidity, lpRecipient);
    }
}
