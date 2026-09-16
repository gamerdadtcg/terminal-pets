// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CollectionConfig} from "./CollectionConfig.sol";
import {IHopper} from "./interfaces/IHopper.sol";

/// @title Hopper
/// @notice ETH-only accumulator. Half of each Ignite ETH fee (0.002) lands here;
/// the other half buys `$TERM` and burns. The 25% Ignite `$TERM` cut is also
/// converted to ETH and deposited once a swap router is set.
///
/// After CollectionNFT.reveal(), outbound Hopper actions stay locked for
/// `payoutLock` from the reveal timestamp. Constructor `payoutLock_ == 0`
/// uses `CollectionConfig.HOPPER_LOCK` (7 days). Ignite during the lock
/// still deposits ETH here; Pulse / claim cannot spend it until `hopperUnlocked()`.
///
/// Trust model
/// -----------
/// ETH in the Hopper is holder money. There is no owner withdraw, rescue, or
/// privileged sweep. The only outbound path is the locked PulseDistributor,
/// which pays Lit terminals pro-rata during Pulse / claim (ETH, or Stock Tokens
/// via a settable router). TermMarket (when the canonical TERM/ETH pool is
/// wired) also deposits the Hopper slice of swap volume here.
///
/// The owner may assign the distributor exactly once (`lockDistributor`).
/// After that, no admin can redirect Hopper ETH to themselves.
///
/// Inbound paths: `receive()` / `deposit()`, optional paid-mint proceeds, and
/// **post-reveal** Hopper share of ERC-2981 / OpenSea royalties forwarded by
/// RoyaltySplitter (2/3 of the 7.5% pot = 5% of sale). Pre-reveal, the full
/// 7.5% royalty stream goes to TermFund — Hopper is unchanged by that window.
/// After reveal, treasury's 2.5% never enters the Hopper. 50% of each Ignite
/// ETH fee (0.002) deposits here; the other 50% buys `$TERM` and burns (never
/// TermFund, never treasury). 25% of each Ignite `$TERM` fee is swapped to ETH
/// and deposited here when IgniteModule has a swap router (else it parks as
/// pendingHopperTerm). When the canonical `$TERM` market is live, TermMarket
/// also deposits a 1.5% swap skim (ETH) here.
contract Hopper is Ownable, IHopper {
    address public distributor;
    bool public distributorLocked;
    uint256 public reserved;
    /// @notice CollectionNFT that may call `notifyReveal`. Bound once from its constructor.
    address public collection;
    /// @notice Reveal timestamp. 0 until `CollectionNFT.reveal()`.
    uint64 public revealedAt;
    /// @notice Payout lock duration after reveal. Immutable. 0 constructor arg → `CollectionConfig.HOPPER_LOCK`.
    uint256 public immutable payoutLock;

    error ZeroAddress();
    error AlreadyLocked();
    error AlreadySet();
    error AlreadyRevealed();
    error NotCollection();
    error NotDistributor();
    error InsufficientAvailable();
    error TransferFailed();
    error HopperLocked(uint256 unlockTime);

    event Deposited(address indexed from, uint256 amount);
    event DistributorLocked(address indexed distributor);
    event CollectionBound(address indexed collection);
    event RevealClockStarted(uint256 revealedAt, uint256 unlockTime);
    event Reserved(uint256 amount, uint256 reservedTotal);
    event Released(address indexed to, uint256 amount);

    constructor(address initialOwner, uint256 payoutLock_) Ownable(initialOwner) {
        payoutLock = payoutLock_ == 0 ? CollectionConfig.HOPPER_LOCK : payoutLock_;
    }

    /// @notice CollectionNFT constructor binds itself. First caller wins.
    function bindCollection() external {
        if (collection != address(0)) revert AlreadySet();
        if (msg.sender == address(0)) revert ZeroAddress();
        collection = msg.sender;
        emit CollectionBound(msg.sender);
    }

    /// @notice Starts the payout lock. Only the bound collection, once.
    function notifyReveal() external {
        if (msg.sender != collection) revert NotCollection();
        if (revealedAt != 0) revert AlreadyRevealed();
        revealedAt = uint64(block.timestamp);
        emit RevealClockStarted(revealedAt, hopperUnlockTime());
    }

    /// @notice 0 before reveal. After reveal: `revealedAt + payoutLock`.
    function hopperUnlockTime() public view returns (uint256) {
        if (revealedAt == 0) return 0;
        return uint256(revealedAt) + payoutLock;
    }

    /// @notice False until reveal and the payout lock have both elapsed.
    function hopperUnlocked() public view returns (bool) {
        uint256 unlock = hopperUnlockTime();
        return unlock != 0 && block.timestamp >= unlock;
    }

    /// @notice Assign PulseDistributor once. Irreversible.
    function lockDistributor(address distributor_) external onlyOwner {
        if (distributorLocked) revert AlreadyLocked();
        if (distributor_ == address(0)) revert ZeroAddress();
        distributor = distributor_;
        distributorLocked = true;
        emit DistributorLocked(distributor_);
    }

    function deposit() external payable {
        if (msg.value > 0) emit Deposited(msg.sender, msg.value);
    }

    receive() external payable {
        if (msg.value > 0) emit Deposited(msg.sender, msg.value);
    }

    function available() public view returns (uint256) {
        uint256 bal = address(this).balance;
        return bal > reserved ? bal - reserved : 0;
    }

    function reserve(uint256 amount) external {
        if (msg.sender != distributor) revert NotDistributor();
        _requireUnlocked();
        if (amount > available()) revert InsufficientAvailable();
        reserved += amount;
        emit Reserved(amount, reserved);
    }

    function release(address to, uint256 amount) external {
        if (msg.sender != distributor) revert NotDistributor();
        _requireUnlocked();
        if (to == address(0)) revert ZeroAddress();
        if (amount > reserved) revert InsufficientAvailable();
        reserved -= amount;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Released(to, amount);
    }

    function _requireUnlocked() internal view {
        if (!hopperUnlocked()) revert HopperLocked(hopperUnlockTime());
    }
}
