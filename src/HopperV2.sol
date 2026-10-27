// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CollectionConfig} from "./CollectionConfig.sol";
import {IHopperV2} from "./interfaces/IHopperV2.sol";
import {IRevealClock} from "./interfaces/IRevealClock.sol";

/// @title HopperV2
/// @notice ETH accumulator for PulseDistributorV2. Same trust model as `Hopper`
/// (only the locked distributor can move ETH out in the normal path) with the
/// escape hatches the V1 Hopper lacks:
///
///   * `pause()` / `unpause()` (owner). While paused, `reserve` and `release`
///     revert, so a misbehaving distributor cannot pay out or snapshot.
///   * Timelocked emergency withdraw. Only while paused, the owner proposes
///     `(to, amount)`, waits `EMERGENCY_DELAY` (7 days), then executes. The
///     proposal is public (event + view), cancellable, and auto-cancelled by
///     `unpause()`. This is the only owner path to ETH. Use a multisig owner.
///
/// Reveal clock: V2 does not need its own `CollectionNFT` binding. It reads
/// `revealedAt` from the live V1 Hopper (`revealClock`), so the payout lock is
/// still `payoutLock` (7 days) after the reveal that already happened.
/// Constructor `payoutLock_ == 0` uses `CollectionConfig.HOPPER_LOCK`.
///
/// Inbound: `receive()` / `deposit()` from any source (new fee routes, the
/// redirect router, direct top-ups).
contract HopperV2 is Ownable, IHopperV2 {
    uint256 public constant EMERGENCY_DELAY = 7 days;

    IRevealClock public immutable revealClock;
    uint256 public immutable payoutLock;

    address public distributor;
    bool public distributorLocked;
    uint256 public reserved;
    bool public paused;

    struct EmergencyProposal {
        address to;
        uint256 amount;
        uint64 readyAt;
    }

    EmergencyProposal public emergency;

    error ZeroAddress();
    error AlreadyLocked();
    error NotDistributor();
    error InsufficientAvailable();
    error TransferFailed();
    error HopperLocked(uint256 unlockTime);
    error IsPaused();
    error NotPaused();
    error NoProposal();
    error ProposalPending();
    error NotReady(uint256 readyAt);
    error AmountTooLarge();

    event Deposited(address indexed from, uint256 amount);
    event DistributorLocked(address indexed distributor);
    event Reserved(uint256 amount, uint256 reservedTotal);
    event Released(address indexed to, uint256 amount);
    event PausedSet(bool paused);
    event EmergencyWithdrawProposed(address indexed to, uint256 amount, uint256 readyAt);
    event EmergencyWithdrawCancelled();
    event EmergencyWithdrawExecuted(address indexed to, uint256 amount);

    constructor(address initialOwner, uint256 payoutLock_, address revealClock_) Ownable(initialOwner) {
        if (revealClock_ == address(0)) revert ZeroAddress();
        revealClock = IRevealClock(revealClock_);
        payoutLock = payoutLock_ == 0 ? CollectionConfig.HOPPER_LOCK : payoutLock_;
    }

    /// @notice Assign PulseDistributorV2 once. Irreversible.
    function lockDistributor(address distributor_) external onlyOwner {
        if (distributorLocked) revert AlreadyLocked();
        if (distributor_ == address(0)) revert ZeroAddress();
        distributor = distributor_;
        distributorLocked = true;
        emit DistributorLocked(distributor_);
    }

    // --------------------------------------------------------------------- views

    function revealedAt() public view returns (uint64) {
        return revealClock.revealedAt();
    }

    /// @notice 0 before reveal. After reveal: `revealedAt + payoutLock`.
    function hopperUnlockTime() public view returns (uint256) {
        uint256 r = revealedAt();
        if (r == 0) return 0;
        return r + payoutLock;
    }

    function hopperUnlocked() public view returns (bool) {
        uint256 unlock = hopperUnlockTime();
        return unlock != 0 && block.timestamp >= unlock;
    }

    function available() public view returns (uint256) {
        uint256 bal = address(this).balance;
        return bal > reserved ? bal - reserved : 0;
    }

    // ------------------------------------------------------------------- inbound

    function deposit() external payable {
        if (msg.value > 0) emit Deposited(msg.sender, msg.value);
    }

    receive() external payable {
        if (msg.value > 0) emit Deposited(msg.sender, msg.value);
    }

    // ----------------------------------------------------------------- distributor

    function reserve(uint256 amount) external {
        if (msg.sender != distributor) revert NotDistributor();
        if (paused) revert IsPaused();
        _requireUnlocked();
        if (amount > available()) revert InsufficientAvailable();
        reserved += amount;
        emit Reserved(amount, reserved);
    }

    function release(address to, uint256 amount) external {
        if (msg.sender != distributor) revert NotDistributor();
        if (paused) revert IsPaused();
        _requireUnlocked();
        if (to == address(0)) revert ZeroAddress();
        if (amount > reserved) revert InsufficientAvailable();
        reserved -= amount;
        (bool ok,) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Released(to, amount);
    }

    // ------------------------------------------------------------- pause / rescue

    function pause() external onlyOwner {
        if (paused) revert IsPaused();
        paused = true;
        emit PausedSet(true);
    }

    /// @notice Resume. Cancels any pending emergency withdraw.
    function unpause() external onlyOwner {
        if (!paused) revert NotPaused();
        paused = false;
        if (emergency.readyAt != 0) {
            delete emergency;
            emit EmergencyWithdrawCancelled();
        }
        emit PausedSet(false);
    }

    /// @notice Step 1 of the emergency withdraw. Requires `paused`. One proposal at a time.
    function proposeEmergencyWithdraw(address to, uint256 amount) external onlyOwner {
        if (!paused) revert NotPaused();
        if (to == address(0)) revert ZeroAddress();
        if (emergency.readyAt != 0) revert ProposalPending();
        uint64 readyAt = uint64(block.timestamp + EMERGENCY_DELAY);
        emergency = EmergencyProposal({to: to, amount: amount, readyAt: readyAt});
        emit EmergencyWithdrawProposed(to, amount, readyAt);
    }

    function cancelEmergencyWithdraw() external onlyOwner {
        if (emergency.readyAt == 0) revert NoProposal();
        delete emergency;
        emit EmergencyWithdrawCancelled();
    }

    /// @notice Step 2. Callable by the owner once the delay elapsed and the Hopper is still paused.
    function executeEmergencyWithdraw() external onlyOwner {
        EmergencyProposal memory p = emergency;
        if (p.readyAt == 0) revert NoProposal();
        if (!paused) revert NotPaused();
        if (block.timestamp < p.readyAt) revert NotReady(p.readyAt);
        if (p.amount > address(this).balance) revert AmountTooLarge();
        delete emergency;
        // Withdrawn ETH is no longer backing reservations.
        uint256 balAfter = address(this).balance - p.amount;
        if (reserved > balAfter) reserved = balAfter;
        (bool ok,) = p.to.call{value: p.amount}("");
        if (!ok) revert TransferFailed();
        emit EmergencyWithdrawExecuted(p.to, p.amount);
    }

    function _requireUnlocked() internal view {
        if (!hopperUnlocked()) revert HopperLocked(hopperUnlockTime());
    }
}
