// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title TermToken
/// @notice Terminal Pets `$TERM` ERC-20 on Robinhood Chain. Not AGENT / freights.one.
/// Owner mints the initial float (treasury / LP) plus the Ignite allotment escrow.
/// Ignite burns 37.5%, refills allotment escrow 37.5%, and converts 25% to ETH for Hopper.
/// Not fee-on-transfer — trading skim lives in TermMarket.
/// Public transfers are off until CollectionNFT.reveal() enables trading.
contract TermToken is ERC20, ERC20Burnable, Ownable {
    error ZeroAddress();
    error TradingClosed();
    error AlreadySet();
    error NotLauncher();

    bool public tradingEnabled;
    address public launcher;
    mapping(address => bool) public transferExempt;

    event TradingEnabled(uint256 timestamp);
    event LauncherSet(address indexed launcher);
    event TransferExemptSet(address indexed account, bool exempt);

    constructor(address initialOwner) ERC20("Terminal $TERM", "$TERM") Ownable(initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    function setLauncher(address launcher_) external onlyOwner {
        if (launcher != address(0)) revert AlreadySet();
        if (launcher_ == address(0)) revert ZeroAddress();
        launcher = launcher_;
        emit LauncherSet(launcher_);
    }

    function setTransferExempt(address account, bool exempt) external onlyOwner {
        if (account == address(0)) revert ZeroAddress();
        transferExempt[account] = exempt;
        emit TransferExemptSet(account, exempt);
    }

    /// @notice Turn on public `$TERM` transfers. Owner or CollectionNFT.reveal().
    function enableTrading() external {
        if (msg.sender != owner() && msg.sender != launcher) revert NotLauncher();
        if (tradingEnabled) return;
        tradingEnabled = true;
        emit TradingEnabled(block.timestamp);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (!tradingEnabled && from != address(0) && to != address(0)) {
            if (!transferExempt[from] && !transferExempt[to]) revert TradingClosed();
        }
        super._update(from, to, value);
    }
}
