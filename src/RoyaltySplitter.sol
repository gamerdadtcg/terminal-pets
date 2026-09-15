// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title RoyaltySplitter
/// @notice ERC-2981 / OpenSea royalty receiver for Terminal Pets.
///
/// Pre-reveal: 100% of incoming ETH (the 7.5% creator royalty) → TermFund for `$TERM` LP.
/// Nothing to Hopper or treasury from this stream until reveal.
///
/// Post-reveal (`setLive`, same tx as metadata reveal): split 2/3 Hopper / 1/3 treasury
/// (5% and 2.5% of sale).
///
/// Recipients are set at arm. There is no owner withdraw.
contract RoyaltySplitter is Ownable, ReentrancyGuard {
    address public immutable hopper;
    address public immutable treasury;

    address public termFund;
    address public launcher;
    bool public armed;
    bool public live;

    uint256 public constant HOPPER_SHARES = 2;
    uint256 public constant TREASURY_SHARES = 1;
    uint256 public constant TOTAL_SHARES = 3;

    error ZeroAddress();
    error TransferFailed();
    error AlreadyArmed();
    error NotArmed();
    error NotLauncher();
    error AlreadyLive();

    event Armed(address indexed termFund, address indexed launcher);
    event Live(uint256 timestamp);
    event Split(uint256 hopperAmount, uint256 treasuryAmount, uint256 remainder);
    event TermFunded(uint256 amount);

    constructor(address hopper_, address treasury_, address initialOwner) Ownable(initialOwner) {
        if (hopper_ == address(0) || treasury_ == address(0) || initialOwner == address(0)) revert ZeroAddress();
        hopper = hopper_;
        treasury = treasury_;
    }

    /// @notice Bind TermFund + CollectionNFT (launcher) once, before mint.
    function arm(address termFund_, address launcher_) external onlyOwner {
        if (armed) revert AlreadyArmed();
        if (termFund_ == address(0) || launcher_ == address(0)) revert ZeroAddress();
        termFund = termFund_;
        launcher = launcher_;
        armed = true;
        emit Armed(termFund_, launcher_);
    }

    /// @notice Flip to Hopper/treasury split. Called from CollectionNFT.reveal().
    function setLive() external {
        if (msg.sender != owner() && msg.sender != launcher) revert NotLauncher();
        if (live) revert AlreadyLive();
        live = true;
        emit Live(block.timestamp);
        uint256 bal = address(this).balance;
        if (bal > 0) _split(bal);
    }

    receive() external payable nonReentrant {
        _split(address(this).balance);
    }

    function split() external nonReentrant {
        _split(address(this).balance);
    }

    function preview(uint256 amount) external view returns (uint256 hopperAmount, uint256 treasuryAmount) {
        if (!live) return (0, 0);
        hopperAmount = (amount * HOPPER_SHARES) / TOTAL_SHARES;
        treasuryAmount = (amount * TREASURY_SHARES) / TOTAL_SHARES;
    }

    function _split(uint256 amount) internal {
        if (amount == 0) return;
        if (!live) {
            if (!armed) revert NotArmed();
            (bool ok,) = termFund.call{value: amount}("");
            if (!ok) revert TransferFailed();
            emit TermFunded(amount);
            return;
        }
        uint256 hopperAmount = (amount * HOPPER_SHARES) / TOTAL_SHARES;
        uint256 treasuryAmount = (amount * TREASURY_SHARES) / TOTAL_SHARES;
        if (hopperAmount > 0) {
            (bool okH,) = hopper.call{value: hopperAmount}("");
            if (!okH) revert TransferFailed();
        }
        if (treasuryAmount > 0) {
            (bool okT,) = treasury.call{value: treasuryAmount}("");
            if (!okT) revert TransferFailed();
        }
        emit Split(hopperAmount, treasuryAmount, amount - hopperAmount - treasuryAmount);
    }
}
