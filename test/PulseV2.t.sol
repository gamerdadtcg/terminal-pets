// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {Hopper} from "../src/Hopper.sol";
import {HopperV2} from "../src/HopperV2.sol";
import {HopperRedirectRouter} from "../src/HopperRedirectRouter.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {PulseDistributorV2} from "../src/PulseDistributorV2.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";
import {MockPulseRouter, MockStockToken} from "./mocks/MockPulseRouter.sol";
import {MockTermSwapRouter} from "./mocks/MockTermSwapRouter.sol";
import {MockSelectiveRouter, RejectEth} from "./mocks/MockV2Routers.sol";

/// @notice PulseDistributorV2 + HopperV2 against the real V1 stack (Ignite, CollectionNFT, V1 Hopper
/// as reveal clock). Models the mainnet migration: 3 pets lit under V1 before V2 is wired.
contract PulseV2Test is Test {
    uint256 internal constant SUPPLY = 40;
    uint256 internal constant TEAM = 2;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopperV1;
    HopperV2 internal hopper;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    PulseDistributor internal pulseV1;
    PulseDistributorV2 internal pulse;
    TermToken internal term;
    MockStockToken[8] internal stocks;
    MockSelectiveRouter internal router;

    function setUp() public {
        vm.startPrank(owner);
        hopperV1 = new Hopper(owner, 0);
        RoyaltySplitter splitter = new RoyaltySplitter(address(hopperV1), treasury, owner);
        nft = new CollectionNFT(
            CollectionConfig.NAME,
            CollectionConfig.SYMBOL,
            SUPPLY,
            TEAM,
            address(hopperV1),
            address(splitter),
            owner,
            CollectionConfig.ROYALTY_BPS,
            new address[](0)
        );
        term = new TermToken(owner);
        TermFund fund = new TermFund(owner, address(term), treasury);
        ignite = new IgniteModule(address(nft), address(term), address(hopperV1), owner, FEE, address(fund), ETH_FEE);
        fund.lockIgnite(address(ignite));
        nft.setIgniteModule(address(ignite));
        splitter.arm(address(fund), address(nft));
        term.setLauncher(address(nft));
        term.setTransferExempt(address(ignite), true);
        nft.setTermToken(address(term));
        nft.reveal();
        term.mint(address(ignite), SUPPLY * FEE);
        nft.setMintOpen(true);

        // V1 stack as deployed on mainnet.
        pulseV1 = new PulseDistributor(address(hopperV1), address(nft), address(ignite), SUPPLY, owner, 0, 0, 0);
        ignite.setPulseDistributor(address(pulseV1));
        hopperV1.lockDistributor(address(pulseV1));
        vm.stopPrank();

        vm.warp(hopperV1.hopperUnlockTime());
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);

        // Three pets lit under V1 (mainnet: 3 lit, 0 epochs).
        vm.prank(alice);
        nft.mint(2); // 1,2
        vm.prank(bob);
        nft.mint(2); // 3,4
        vm.prank(carol);
        nft.mint(2); // 5,6
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        vm.prank(bob);
        ignite.ignite{value: ETH_FEE}(3);
        vm.prank(carol);
        ignite.ignite{value: ETH_FEE}(5);

        // Migration: deploy V2, wire Ignite's Dial hook to it. NOTE: nothing registered yet.
        vm.startPrank(owner);
        hopper = new HopperV2(owner, 0, address(hopperV1));
        pulse = new PulseDistributorV2(address(hopper), address(nft), address(ignite), SUPPLY, owner, 0, 0, 0);
        for (uint8 i = 1; i < 8; ++i) {
            stocks[i] = new MockStockToken("S", "S");
        }
        address[8] memory pool;
        for (uint8 i = 1; i < 8; ++i) {
            pool[i] = address(stocks[i]);
        }
        pulse.setStockTokens(pool);
        pulse.setTerm(address(term));
        router = new MockSelectiveRouter();
        pulse.setRouter(address(router));
        hopper.lockDistributor(address(pulse));
        ignite.setPulseDistributor(address(pulse));
        vm.stopPrank();
        // (MockSelectiveRouter mints stock tokens; `$TERM` is minted by the owner below.)
        vm.prank(owner);
        term.mint(address(this), 0);
    }

    // ------------------------------------------------------------- helpers

    function _register123() internal {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 3;
        ids[2] = 5;
        pulse.registerLit(ids);
    }

    function _fund(uint256 need) internal {
        uint256 avail = hopper.available();
        if (avail < need) {
            (bool ok,) = address(hopper).call{value: need - avail}("");
            assertTrue(ok);
        }
    }

    function _useEthOnly() internal {
        vm.prank(owner);
        pulse.setRouter(address(0));
    }

    // ------------------------------------------------------------- economics

    function test_productionEconomicsUnchanged() public view {
        assertEq(CollectionConfig.IGNITE_FEE_ETH, 0.002 ether);
        assertEq(CollectionConfig.HOPPER_LOCK, 7 days);
        assertEq(hopper.payoutLock(), 7 days);
        assertEq(hopper.hopperUnlockTime(), uint256(hopperV1.revealedAt()) + 7 days);
        assertEq(pulse.bootstrapStart(), 0.1 ether);
        assertEq(pulse.cycleStart(), 0.5 ether);
        assertEq(pulse.ladderStep(), 0.1 ether);
        assertEq(pulse.pulseThreshold(), 0.1 ether);
    }

    function test_hopperV2_lockFollowsRevealClock() public {
        uint256 unlock = hopperV1.hopperUnlockTime();
        _register123();
        _fund(0.1 ether);
        vm.warp(unlock - 1);
        assertFalse(hopper.hopperUnlocked());
        assertFalse(pulse.canPulse());
        vm.expectRevert(abi.encodeWithSelector(HopperV2.HopperLocked.selector, unlock));
        pulse.pulse();
        vm.warp(unlock);
        assertTrue(pulse.canPulse());
        pulse.pulse();
    }

    // ------------------------------------------------------------- registration / migration

    function test_unregisteredLitBlocksPulseUntilBackfilled() public {
        _fund(0.1 ether);
        assertEq(ignite.litCount(), 3);
        assertEq(pulse.registeredCount(), 0);
        assertFalse(pulse.canPulse());
        vm.expectRevert(abi.encodeWithSelector(PulseDistributorV2.UnregisteredLit.selector, 0, 3));
        pulse.pulse();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 3;
        pulse.registerLit(ids);
        vm.expectRevert(abi.encodeWithSelector(PulseDistributorV2.UnregisteredLit.selector, 2, 3));
        pulse.pulse();

        pulse.assignDial(5);
        assertTrue(pulse.canPulse());
        pulse.pulse();
        assertEq(pulse.epochCount(), 1);
    }

    function test_registerLit_revertsForUnlitAndIsIdempotent() public {
        vm.expectRevert(PulseDistributorV2.NotLit.selector);
        pulse.assignDial(2);
        vm.expectRevert(PulseDistributorV2.BadTokenId.selector);
        pulse.assignDial(0);
        vm.expectRevert(PulseDistributorV2.BadTokenId.selector);
        pulse.assignDial(SUPPLY + 1);
        pulse.assignDial(1);
        pulse.assignDial(1);
        assertEq(pulse.registeredCount(), 1);
    }

    function test_igniteHookRegistersNewPets() public {
        _register123();
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);
        assertEq(pulse.registeredCount(), 4);
        assertEq(pulse.litFromEpoch(2), 0);
        PulseDistributorV2.Dial memory d = pulse.getDial(2);
        assertGt(d.nLegs, 0);
    }

    function test_dialMatchesV1Assignment() public {
        _register123();
        PulseDistributorV2.Dial memory v2 = pulse.getDial(1);
        PulseDistributor.Dial memory v1 = pulseV1.getDial(1);
        assertEq(v2.nLegs, v1.nLegs);
        assertEq(v2.shellClass, v1.shellClass);
        assertEq(v2.slot0, v1.slot0);
        assertEq(v2.weight0, v1.weight0);
    }

    // ------------------------------------------------------------- ladder

    function test_ladder_bootstrap_0_1_to_1_0_then_0_5_cycle_never_0_1() public {
        _register123();
        for (uint256 i = 1; i <= 10; ++i) {
            assertFalse(pulse.bootstrapComplete());
            assertEq(pulse.pulseThreshold(), i * 0.1 ether, "bootstrap rung");
            _fund(i * 0.1 ether);
            pulse.pulse();
        }
        assertTrue(pulse.bootstrapComplete());
        assertEq(pulse.pulseThreshold(), 0.5 ether);

        _fund(0.1 ether);
        // reserved ETH from prior epochs is excluded from available()
        vm.expectRevert(PulseDistributorV2.HopperNotFull.selector);
        pulse.pulse();

        for (uint256 round; round < 2; ++round) {
            for (uint256 i; i < 6; ++i) {
                assertEq(pulse.pulseThreshold(), 0.5 ether + i * 0.1 ether, "cycle rung");
                _fund(0.5 ether + i * 0.1 ether);
                pulse.pulse();
            }
            assertEq(pulse.pulseThreshold(), 0.5 ether, "wraps to 0.5");
        }
        assertEq(pulse.epochCount(), 22);
    }

    function test_belowFirstRung_cannotPulse() public {
        _register123();
        _fund(0.09 ether);
        assertFalse(pulse.canPulse());
        vm.expectRevert(PulseDistributorV2.HopperNotFull.selector);
        pulse.pulse();
    }

    // ------------------------------------------------------------- claims

    function test_claim_paysShareAcrossManyEpochsInOneCall() public {
        _useEthOnly();
        _register123();
        for (uint256 i; i < 12; ++i) {
            _fund(pulse.pulseThreshold());
            pulse.pulse();
        }
        uint256 expected = pulse.pending(1);
        assertGt(expected, 0);
        uint256 before = alice.balance;
        pulse.claim(1);
        assertEq(alice.balance - before, expected);
        assertEq(pulse.pending(1), 0);
        vm.expectRevert(PulseDistributorV2.NothingToClaim.selector);
        pulse.claim(1);
        // Sum of all three pets' claims == sum of per-epoch shares * 3 (no ETH created or lost).
        pulse.claim(3);
        pulse.claim(5);
        assertLe(hopper.reserved(), 0);
    }

    function test_claimUpTo_isEpochRangeClaim() public {
        _useEthOnly();
        _register123();
        for (uint256 i; i < 4; ++i) {
            _fund(pulse.pulseThreshold());
            pulse.pulse();
        }
        (uint128 s0,,,) = pulse.epochs(0);
        (uint128 s1,,,) = pulse.epochs(1);
        uint256 before = alice.balance;
        pulse.claimUpTo(1, 2);
        assertEq(alice.balance - before, uint256(s0) + s1);
        assertEq(pulse.claimedThrough(1), 2);
        assertTrue(pulse.isClaimed(1, 1));
        assertFalse(pulse.isClaimed(2, 1));
        assertEq(pulse.pending(1), pulse.pendingUpTo(1, 4));
        // clamp beyond epochCount
        pulse.claimUpTo(1, 999);
        assertEq(pulse.pending(1), 0);
        vm.expectRevert(PulseDistributorV2.NothingToClaim.selector);
        pulse.claimUpTo(1, 1); // already past
    }

    function test_petLitLaterDoesNotShareEarlierEpochs() public {
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse(); // epoch 0: 3 lit
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2); // token 2 registers at epoch 1
        assertEq(pulse.litFromEpoch(2), 1);
        assertEq(pulse.pending(2), 0);
        assertFalse(pulse.wasLitInEpoch(0, 2));
        assertTrue(pulse.wasLitInEpoch(0, 1));
        _fund(pulse.pulseThreshold());
        pulse.pulse(); // epoch 1: 4 lit
        (uint128 share1, uint128 lit1,,) = pulse.epochs(1);
        assertEq(lit1, 4);
        assertEq(pulse.pending(2), share1);
        (uint128 share0, uint128 lit0,,) = pulse.epochs(0);
        assertEq(lit0, 3);
        assertEq(pulse.pending(1), uint256(share0) + share1);
        assertTrue(pulse.wasLitInEpoch(1, 2));
    }

    function test_notLitPetNeverEarns() public {
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        assertEq(pulse.pending(2), 0);
        vm.expectRevert(PulseDistributorV2.NothingToClaim.selector);
        pulse.claim(2);
    }

    function test_noRouter_paysPlainEth() public {
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        uint256 p = pulse.pending(3);
        uint256 before = bob.balance;
        pulse.claim(3);
        assertEq(bob.balance - before, p);
    }

    function test_routerPaysStocksForDialed() public {
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        uint256 p = pulse.pending(1);
        uint256 ethBefore = alice.balance;
        pulse.claim(1);
        assertEq(alice.balance, ethBefore, "dialed pet gets stocks, not ETH");
        uint256 total;
        for (uint8 i = 1; i < 8; ++i) {
            total += stocks[i].balanceOf(alice);
        }
        assertEq(total, p, "1:1 mock router: tokens == ETH spent");
    }

    function test_undialedPaysTerm_whenNoStockAddressSet() public {
        address[8] memory empty;
        vm.startPrank(owner);
        pulse.setStockTokens(empty);
        MockPulseRouter termRouter = new MockPulseRouter(1);
        term.mint(address(termRouter), 10 ether);
        pulse.setRouter(address(termRouter));
        vm.stopPrank();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        uint256 p = pulse.pending(1);
        pulse.claim(1);
        assertEq(term.balanceOf(alice), p);
    }

    function test_failedSwap_doesNotRevertClaim_paysEthInstead() public {
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        router.setFailAll(true);
        uint256 p = pulse.pending(1);
        uint256 before = alice.balance;
        vm.expectEmit(false, false, false, false);
        emit PulseDistributorV2.SwapSkipped(1, address(0), 0);
        pulse.claim(1);
        assertEq(alice.balance - before, p, "all legs fell back to ETH");
        assertEq(pulse.pending(1), 0);
    }

    function test_oneFailingLeg_otherLegsStillSwap() public {
        // Pin pet 1 to OMEGA (4 legs; at most one lands on the unused slot 0) so >= 3 legs resolve.
        vm.prank(owner);
        pulse.setShellClassOverride(1, 4);
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();

        (address[4] memory tokens, uint16[4] memory weights, uint8 n,) = pulse.resolvedLegs(1);
        assertEq(n, 4);
        uint256 failIdx = type(uint256).max;
        for (uint256 i; i < n; ++i) {
            if (tokens[i] != address(0) && failIdx == type(uint256).max) failIdx = i;
        }
        assertLt(failIdx, 4);
        router.setFailFor(tokens[failIdx], true);
        uint256 p = pulse.pending(1);
        uint256 owedLeg = (p * weights[failIdx]) / 10_000;
        uint256 before = alice.balance;
        pulse.claim(1);
        assertEq(alice.balance - before, owedLeg, "failed leg paid as ETH");
        uint256 tokenTotal;
        for (uint8 i = 1; i < 8; ++i) {
            tokenTotal += stocks[i].balanceOf(alice);
        }
        assertEq(tokenTotal + owedLeg, p, "other legs swapped");
        assertGt(tokenTotal, 0);
    }

    function test_oneBadPetDoesNotBlockBatch() public {
        // Alice's pet 1 swap fails and her owner cannot take ETH; bob's pet 3 must still be paid.
        RejectEth rejector = new RejectEth();
        vm.prank(alice);
        nft.transferFrom(alice, address(rejector), 1);
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        router.setFailAll(true);
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 3;
        ids[2] = 5;
        uint256 bobBefore = bob.balance;
        uint256 owed1 = pulse.pending(1);
        pulse.claimMany(ids);
        assertGt(bob.balance, bobBefore);
        assertEq(pulse.creditOf(1), owed1, "unreceivable ETH credited, not lost");
        assertEq(pulse.pending(1), 0);
    }

    function test_creditWithdraw_onlyPetOwner() public {
        RejectEth rejector = new RejectEth();
        vm.prank(alice);
        nft.transferFrom(alice, address(rejector), 1);
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        pulse.claim(1);
        uint256 credit = pulse.creditOf(1);
        assertGt(credit, 0);

        vm.prank(bob);
        vm.expectRevert(PulseDistributorV2.NotTokenOwner.selector);
        pulse.withdrawCredit(1, bob);

        // Owner contract cannot call; move the pet to a normal wallet and withdraw.
        vm.prank(address(rejector));
        nft.transferFrom(address(rejector), carol, 1);
        uint256 before = carol.balance;
        vm.prank(carol);
        pulse.withdrawCredit(1, carol);
        assertEq(carol.balance - before, credit);
        assertEq(pulse.creditOf(1), 0);
        vm.prank(carol);
        vm.expectRevert(PulseDistributorV2.NoCredit.selector);
        pulse.withdrawCredit(1, carol);
    }

    function test_claimManyBounded_stopsAndResumes() public {
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        uint256[] memory ids = new uint256[](3);
        ids[0] = 1;
        ids[1] = 3;
        ids[2] = 5;
        // Impossible gas floor → processes nothing, does not revert.
        uint256 done = pulse.claimManyBounded(ids, type(uint256).max);
        assertEq(done, 0);
        done = pulse.claimManyBounded(ids, 100_000);
        assertEq(done, 3);
        assertEq(pulse.pending(1) + pulse.pending(3) + pulse.pending(5), 0);
    }

    function test_claimMany_revertsIfNothingPaid() public {
        _register123();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.expectRevert(PulseDistributorV2.NothingToClaim.selector);
        pulse.claimMany(ids);
    }

    function test_deliverToTba() public {
        // Registry/implementation reuse: any non-zero config; use a mock registry returning a fixed address.
        MockRegistry reg = new MockRegistry();
        vm.startPrank(owner);
        pulse.setTbaConfig(address(reg), address(0x1234), bytes32(0));
        pulse.setDeliverToTba(true);
        vm.stopPrank();
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        uint256 p = pulse.pending(1);
        pulse.claim(1);
        assertEq(reg.ACCOUNT().balance, p);
    }

    function test_setDeliverToTba_requiresRegistry() public {
        vm.prank(owner);
        vm.expectRevert(PulseDistributorV2.TbaNotConfigured.selector);
        pulse.setDeliverToTba(true);
    }

    function test_dust_staysInHopper() public {
        _useEthOnly();
        _register123();
        (bool ok,) = address(hopper).call{value: 0.1 ether + 1 wei}("");
        assertTrue(ok);
        pulse.pulse();
        (uint128 share,, uint128 amount,) = pulse.epochs(0);
        assertEq(uint256(share) * 3, amount);
        assertEq(hopper.available(), 2 wei);
    }

    // ------------------------------------------------------------- hopper V2 safety

    function test_pause_blocksPulseAndClaims() public {
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        _fund(pulse.pulseThreshold());

        vm.prank(owner);
        hopper.pause();
        assertFalse(pulse.canPulse());
        vm.expectRevert(HopperV2.IsPaused.selector);
        pulse.pulse();
        vm.expectRevert(HopperV2.IsPaused.selector);
        pulse.claim(1);

        vm.prank(owner);
        hopper.unpause();
        pulse.claim(1);
        pulse.pulse();
    }

    function test_pause_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        hopper.pause();
    }

    function test_distributorOnly() public {
        vm.expectRevert(HopperV2.NotDistributor.selector);
        hopper.reserve(1);
        vm.expectRevert(HopperV2.NotDistributor.selector);
        hopper.release(alice, 1);
    }

    function test_distributorLockedOnce() public {
        vm.prank(owner);
        vm.expectRevert(HopperV2.AlreadyLocked.selector);
        hopper.lockDistributor(address(1));
    }

    function test_emergencyWithdraw_requiresPause() public {
        vm.prank(owner);
        vm.expectRevert(HopperV2.NotPaused.selector);
        hopper.proposeEmergencyWithdraw(treasury, 1);
    }

    function test_emergencyWithdraw_timelocked() public {
        _fund(1 ether);
        vm.startPrank(owner);
        hopper.pause();
        hopper.proposeEmergencyWithdraw(treasury, 0.6 ether);
        (address to, uint256 amount, uint64 readyAt) = hopper.emergency();
        assertEq(to, treasury);
        assertEq(amount, 0.6 ether);
        assertEq(readyAt, block.timestamp + 7 days);

        vm.expectRevert(abi.encodeWithSelector(HopperV2.NotReady.selector, uint256(readyAt)));
        hopper.executeEmergencyWithdraw();
        vm.warp(readyAt - 1);
        vm.expectRevert(abi.encodeWithSelector(HopperV2.NotReady.selector, uint256(readyAt)));
        hopper.executeEmergencyWithdraw();

        vm.expectRevert(HopperV2.ProposalPending.selector);
        hopper.proposeEmergencyWithdraw(treasury, 1);

        vm.warp(readyAt);
        hopper.executeEmergencyWithdraw();
        vm.stopPrank();
        assertEq(treasury.balance, 0.6 ether);
        assertEq(address(hopper).balance, 0.4 ether);
        (,, uint64 after_) = hopper.emergency();
        assertEq(after_, 0);
    }

    function test_emergencyWithdraw_unpauseCancels_andNeedsPauseToExecute() public {
        _fund(1 ether);
        vm.startPrank(owner);
        hopper.pause();
        hopper.proposeEmergencyWithdraw(treasury, 1 ether);
        hopper.unpause();
        (,, uint64 readyAt) = hopper.emergency();
        assertEq(readyAt, 0);
        vm.expectRevert(HopperV2.NoProposal.selector);
        hopper.executeEmergencyWithdraw();

        hopper.pause();
        hopper.proposeEmergencyWithdraw(treasury, 1 ether);
        (,, uint64 ready2) = hopper.emergency();
        vm.warp(ready2);
        // Cancel path
        hopper.cancelEmergencyWithdraw();
        vm.expectRevert(HopperV2.NoProposal.selector);
        hopper.cancelEmergencyWithdraw();
        vm.stopPrank();
    }

    function test_emergencyWithdraw_cannotExceedBalance_andOnlyOwner() public {
        _fund(1 ether);
        vm.startPrank(owner);
        hopper.pause();
        hopper.proposeEmergencyWithdraw(treasury, 2 ether);
        vm.warp(block.timestamp + 7 days);
        vm.expectRevert(HopperV2.AmountTooLarge.selector);
        hopper.executeEmergencyWithdraw();
        vm.stopPrank();

        vm.prank(alice);
        vm.expectRevert();
        hopper.executeEmergencyWithdraw();
        vm.prank(alice);
        vm.expectRevert();
        hopper.proposeEmergencyWithdraw(alice, 1);
    }

    function test_emergencyWithdraw_shrinksReserved() public {
        _useEthOnly();
        _register123();
        _fund(pulse.pulseThreshold());
        pulse.pulse();
        uint256 bal = address(hopper).balance;
        assertGt(hopper.reserved(), 0);
        vm.startPrank(owner);
        hopper.pause();
        hopper.proposeEmergencyWithdraw(treasury, bal);
        vm.warp(block.timestamp + 7 days);
        hopper.executeEmergencyWithdraw();
        vm.stopPrank();
        assertEq(hopper.reserved(), 0);
        assertEq(address(hopper).balance, 0);
    }

    // ------------------------------------------------------------- funding redirect

    function test_redirectRouter_sendsIgniteTermSliceToHopperV2() public {
        MockTermSwapRouter inner = new MockTermSwapRouter();
        vm.deal(address(inner), 1_000 ether);
        vm.startPrank(owner);
        term.mint(address(inner), 100_000 ether);
        HopperRedirectRouter redirect = new HopperRedirectRouter(address(inner), address(hopperV1), address(hopper));
        ignite.setSwapRouter(address(redirect));
        vm.stopPrank();

        uint256 v1Before = address(hopperV1).balance;
        uint256 v2Before = address(hopper).balance;
        _register123();
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);
        // 25% of 1,000 $TERM => 250 ETH-wei at the 1:1 mock => V2. The ETH half (0.001) still hits V1.
        assertEq(address(hopper).balance - v2Before, 250 ether);
        assertEq(address(hopperV1).balance - v1Before, ETH_FEE / 2);
    }

    function test_redirectRouter_passesThroughOtherDestinations() public {
        MockTermSwapRouter inner = new MockTermSwapRouter();
        vm.deal(address(inner), 1 ether);
        HopperRedirectRouter redirect = new HopperRedirectRouter(address(inner), address(hopperV1), address(hopper));
        vm.prank(owner);
        term.mint(address(this), 10 ether);
        term.approve(address(redirect), 10 ether);
        // `this` needs exemption pre-trading? reveal enabled trading already.
        uint256 before = bob.balance;
        redirect.swapExactTokenForETH(address(term), 1 ether, bob);
        assertEq(bob.balance - before, 1 ether);
    }

    function test_redirectRouter_zeroAddressReverts() public {
        vm.expectRevert(HopperRedirectRouter.ZeroAddress.selector);
        new HopperRedirectRouter(address(0), address(1), address(2));
    }

    // ------------------------------------------------------------- V1 keeps working

    function test_v1StillPaysItsThreeLitPets() public {
        (bool ok,) = address(hopperV1).call{value: 0.2 ether}("");
        assertTrue(ok);
        vm.startPrank(owner);
        MockPulseRouter r1 = new MockPulseRouter(1);
        term.mint(address(r1), 10 ether);
        pulseV1.setTerm(address(term));
        pulseV1.setRouter(address(r1));
        vm.stopPrank();
        pulseV1.pulse();
        uint256 p = pulseV1.pending(1);
        assertGt(p, 0);
        pulseV1.claim(1);
        assertEq(term.balanceOf(alice), p);
    }
}

contract MockRegistry {
    address public constant ACCOUNT = address(0xA11CE);

    function account(address, bytes32, uint256, address, uint256) external pure returns (address) {
        return ACCOUNT;
    }
}
