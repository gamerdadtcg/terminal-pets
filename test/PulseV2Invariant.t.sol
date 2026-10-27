// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PulseV2Base} from "./PulseV2.t.sol";
import {HopperV2} from "../src/HopperV2.sol";
import {PulseDistributorV2} from "../src/PulseDistributorV2.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";

/// @notice Stateful invariants for HopperV2 + PulseDistributorV2 against the real V1 stack. The test contract is
/// its own handler (see `targetSelector` in setUp).
contract PulseV2InvariantTest is PulseV2Base {
    address[] internal actors;
    uint256 internal nextToMint = 7;
    uint256 internal constant MAX_TOKEN = 24;
    uint256 internal ghostPulsedAmount;
    uint256 internal ghostPaidOut; // ETH that left the Hopper to the distributor
    uint256 internal ghostDonated;
    bool internal doubleClaimPaid;
    bool internal pausedClaimSucceeded;
    bool internal earlyEmergencyExecuted;

    function setUp() public override {
        super.setUp();
        actors.push(alice);
        actors.push(bob);
        actors.push(carol);
        for (uint256 i; i < actors.length; ++i) {
            vm.prank(actors[i]);
            nft.mint(6);
        } // ids 7..24 (3 x 6)
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 3;
        ids[2] = 5;
        pulse.registerLit(ids);

        bytes4[] memory sel = new bytes4[](8);
        sel[0] = this.h_ignite.selector;
        sel[1] = this.h_fund.selector;
        sel[2] = this.h_pulse.selector;
        sel[3] = this.h_claim.selector;
        sel[4] = this.h_claimMany.selector;
        sel[5] = this.h_doubleClaim.selector;
        sel[6] = this.h_pauseToggle.selector;
        sel[7] = this.h_emergency.selector;
        targetSelector(FuzzSelector({addr: address(this), selectors: sel}));
        targetContract(address(this));
    }

    function _owner(uint256 id) internal view returns (address) {
        return nft.ownerOf(id);
    }

    // ------------------------------------------------------------- handlers

    function h_ignite(uint256 seed) external {
        uint256 id = 1 + (seed % MAX_TOKEN);
        if (ignite.isLit(id) || !ignite.igniteEnabled()) return;
        address o = _owner(id);
        vm.deal(o, o.balance + ETH_FEE);
        vm.prank(o);
        try ignite.ignite{value: ETH_FEE}(id) {} catch {}
    }

    function h_fund(uint256 amt) external {
        amt = bound(amt, 0, 3 ether);
        vm.deal(address(this), address(this).balance + amt);
        (bool ok,) = address(hopper).call{value: amt}("");
        ok;
        ghostDonated += amt;
    }

    function h_pulse(uint256 warpBy) external {
        vm.warp(block.timestamp + bound(warpBy, 0, 3 days));
        uint256 r = hopper.reserved();
        uint256 epochBefore = pulse.epochCount();
        try pulse.pulse() {
            (, , uint128 amount,) = pulse.epochs(epochBefore);
            ghostPulsedAmount += amount;
            assertEq(hopper.reserved(), r + amount, "reserve == epoch amount");
        } catch {}
    }

    function h_claim(uint256 seed) external {
        uint256 id = 1 + (seed % MAX_TOKEN);
        uint256 before_ = address(hopper).balance;
        try pulse.claim(id) {} catch {}
        ghostPaidOut += before_ - address(hopper).balance;
    }

    function h_claimMany(uint256 seed) external {
        uint256[] memory ids = new uint256[](4);
        for (uint256 i; i < 4; ++i) {
            ids[i] = 1 + ((seed >> (i * 8)) % MAX_TOKEN);
        }
        uint256 before_ = address(hopper).balance;
        try pulse.claimMany(ids) {} catch {}
        ghostPaidOut += before_ - address(hopper).balance;
    }

    /// @dev Claim twice in a row: the second must pay nothing.
    function h_doubleClaim(uint256 seed) external {
        uint256 id = 1 + (seed % MAX_TOKEN);
        uint256 before_ = address(hopper).balance;
        try pulse.claim(id) {} catch {}
        ghostPaidOut += before_ - address(hopper).balance;
        uint256 mid = address(hopper).balance;
        try pulse.claim(id) {
            doubleClaimPaid = true;
        } catch {}
        if (address(hopper).balance != mid) doubleClaimPaid = true;
    }

    function h_pauseToggle(bool on) external {
        vm.startPrank(owner);
        if (on && !hopper.paused()) {
            hopper.pause();
            // While paused nothing may be paid or reserved.
            uint256 bal = address(hopper).balance;
            try pulse.pulse() {
                pausedClaimSucceeded = true;
            } catch {}
            for (uint256 id = 1; id <= MAX_TOKEN; ++id) {
                if (pulse.pending(id) == 0) continue;
                try pulse.claim(id) {
                    pausedClaimSucceeded = true;
                } catch {}
            }
            if (address(hopper).balance != bal) pausedClaimSucceeded = true;
        } else if (!on && hopper.paused()) {
            hopper.unpause();
        }
        vm.stopPrank();
    }

    /// @dev Emergency withdraw must never succeed before the delay. (Never actually executes after it.)
    function h_emergency(uint256 amt) external {
        vm.startPrank(owner);
        if (hopper.paused()) {
            try hopper.proposeEmergencyWithdraw(owner, amt % 1 ether) {} catch {}
            (, , uint64 readyAt) = hopper.emergency();
            if (readyAt != 0 && block.timestamp < readyAt) {
                try hopper.executeEmergencyWithdraw() {
                    earlyEmergencyExecuted = true;
                } catch {}
            }
        }
        vm.stopPrank();
    }

    // ------------------------------------------------------------- invariants

    function _sumPending() internal view returns (uint256 s) {
        for (uint256 id = 1; id <= MAX_TOKEN; ++id) {
            s += pulse.pending(id);
        }
    }

    /// @notice Hopper never owes more than it holds.
    function invariant_reservedBackedByBalance() public view {
        assertLe(hopper.reserved(), address(hopper).balance);
    }

    /// @notice What pets can still claim == what the Hopper has reserved. Exact: no over- or under-reservation.
    function invariant_totalClaimableEqualsReserved() public view {
        assertEq(_sumPending(), hopper.reserved());
        assertLe(_sumPending(), address(hopper).balance);
    }

    /// @notice Conservation of the pulsed amount: reserved + already released == sum of epoch amounts.
    function invariant_pulsedEqualsReservedPlusPaid() public view {
        assertEq(ghostPulsedAmount, hopper.reserved() + ghostPaidOut);
    }

    function invariant_noDoubleClaim() public view {
        assertFalse(doubleClaimPaid);
    }

    function invariant_pauseBlocksPayoutsAndPulses() public view {
        assertFalse(pausedClaimSucceeded);
    }

    function invariant_emergencyWithdrawOnlyAfterDelay() public view {
        assertFalse(earlyEmergencyExecuted);
    }

    /// @notice A pet never has a claim cursor past the epoch count, and registered <= lit.
    function invariant_registrationSane() public view {
        assertLe(pulse.registeredCount(), ignite.litCount());
        for (uint256 id = 1; id <= MAX_TOKEN; ++id) {
            assertLe(pulse.claimedThrough(id), pulse.epochCount());
        }
    }

    /// @notice The distributor itself holds no ETH between calls (everything is paid or credited).
    function invariant_distributorHoldsOnlyCredit() public view {
        uint256 credit;
        for (uint256 id = 1; id <= MAX_TOKEN; ++id) {
            credit += pulse.creditOf(id);
        }
        assertEq(address(pulse).balance, credit);
    }
}
