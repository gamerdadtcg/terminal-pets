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
import {TermMarket} from "../src/TermMarket.sol";
import {TermMarketFeeForwarder} from "../src/TermMarketFeeForwarder.sol";
import {ISeaDropTokenContractMetadata} from "../src/interfaces/seadrop/ISeaDropTokenContractMetadata.sol";
import {RoyaltySplitterV2} from "../src/RoyaltySplitterV2.sol";
import {WETH9Mock} from "./RoyaltySplitterV2.t.sol";
import {MockPulseRouter, MockStockToken} from "./mocks/MockPulseRouter.sol";
import {MockTermSwapRouter} from "./mocks/MockTermSwapRouter.sol";
import {PulseV2Config, PulseV2Migration} from "../script/MigratePulseV2.s.sol";

/// @notice Runs the migration library (the same code the script broadcasts) against an in-memory copy
/// of the live V1 stack. Nothing is sent to any chain.
contract MigratePulseV2Test is Test {
    uint256 internal constant SUPPLY = 40;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;

    address internal owner = makeAddr("owner");
    address internal multisig = makeAddr("multisig");
    address internal alice = makeAddr("alice");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopperV1;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    PulseDistributor internal pulseV1;
    TermToken internal term;
    MockPulseRouter internal v1Router;
    MockTermSwapRouter internal termRouter;
    TermMarket internal market;
    TermMarketFeeForwarder internal fwd;
    address internal dexPool = makeAddr("dexPool");
    address[8] internal pool;

    function setUp() public {
        vm.startPrank(owner);
        hopperV1 = new Hopper(owner, 0);
        RoyaltySplitter splitter = new RoyaltySplitter(address(hopperV1), treasury, owner);
        nft = new CollectionNFT(
            CollectionConfig.NAME,
            CollectionConfig.SYMBOL,
            SUPPLY,
            2,
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

        pulseV1 = new PulseDistributor(address(hopperV1), address(nft), address(ignite), SUPPLY, owner, 0, 0, 0);
        for (uint8 i = 1; i < 8; ++i) {
            pool[i] = address(new MockStockToken("S", "S"));
        }
        pulseV1.setStockTokens(pool);
        pulseV1.setTerm(address(term));
        v1Router = new MockPulseRouter(1);
        pulseV1.setRouter(address(v1Router));
        pulseV1.setTbaConfig(address(0xAAA1), address(0xAAA2), bytes32(uint256(7)));
        ignite.setPulseDistributor(address(pulseV1));
        hopperV1.lockDistributor(address(pulseV1));
        termRouter = new MockTermSwapRouter();
        ignite.setSwapRouter(address(termRouter));
        market = new TermMarket(owner, address(term), address(hopperV1), treasury);
        market.setCanonicalPool(dexPool);
        market.setSwapRouter(address(termRouter));
        term.setTransferExempt(address(market), true);
        term.setTransferExempt(dexPool, true);
        term.mint(dexPool, 1_000_000 ether);
        term.mint(address(termRouter), 100_000 ether);
        vm.stopPrank();
        vm.deal(address(termRouter), 1_000 ether);

        vm.warp(hopperV1.hopperUnlockTime());
        vm.deal(alice, 10 ether);
        vm.startPrank(alice);
        nft.mint(8);
        ignite.ignite{value: ETH_FEE}(1);
        ignite.ignite{value: ETH_FEE}(2);
        ignite.ignite{value: ETH_FEE}(3);
        vm.stopPrank();
        vm.startPrank(owner);
        pulseV1.setShellClassOverride(2, 4);
        pulseV1.setShellClassOverride(7, 2);
        ignite.setIgniteEnabled(false); // live state: Ignite paused, 3 lit, 0 epochs
        vm.stopPrank();
    }

    function _cfg() internal view returns (PulseV2Config memory c) {
        c.deployer = owner;
        c.owner = multisig;
        c.v1Hopper = address(hopperV1);
        c.v1Pulse = address(pulseV1);
        c.collection = address(nft);
        c.ignite = address(ignite);
        c.termMarket = address(market);
        c.maxSupply = SUPPLY;
    }

    /// Runs steps 1-6 (each as the owner), leaving Ignite paused. Step 7 is separate.
    function _migrateB() internal returns (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) {
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (h, p, r) = PulseV2Migration.step1_deploy(c);
        fwd = PulseV2Migration.step1b_deployForwarder(c, h);
        vm.stopPrank();
        PulseV2Migration.step2_registerLit(c, p); // any wallet
        vm.startPrank(owner);
        PulseV2Migration.step3_pointDialHook(c, p);
        PulseV2Migration.step4_igniteRouter(c, r);
        PulseV2Migration.step5_marketRouter(c, r);
        PulseV2Migration.step6_zeroIgniteEthFee(c);
        PulseV2Migration.step7_marketTreasury(c, fwd);
        PulseV2Migration.step8_marketFeeBps(c, fwd);
        vm.stopPrank();
    }

    function test_B_step1_changesNoLiveState_andCopiesConfig() public {
        PulseV2Config memory c = _cfg();
        uint256 feeEth = ignite.igniteFeeEth();
        vm.startPrank(owner);
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = PulseV2Migration.step1_deploy(c);
        vm.stopPrank();

        // Live contracts untouched by step 1.
        assertEq(address(ignite.pulseDistributor()), address(pulseV1));
        assertEq(address(ignite.swapRouter()), address(termRouter));
        assertEq(address(market.swapRouter()), address(termRouter));
        assertEq(ignite.igniteFeeEth(), feeEth);
        assertFalse(ignite.igniteEnabled());
        assertEq(hopperV1.distributor(), address(pulseV1));

        // New contracts.
        assertEq(p.owner(), multisig);
        assertEq(h.owner(), multisig);
        assertEq(h.payoutLock(), 7 days);
        assertEq(h.hopperUnlockTime(), uint256(hopperV1.revealedAt()) + 7 days);
        assertEq(p.bootstrapStart(), 0.1 ether);
        assertEq(p.cycleStart(), 0.5 ether);
        assertEq(p.ladderStep(), 0.1 ether);
        for (uint8 i; i < 8; ++i) {
            assertEq(p.stockPool(i), pool[i]);
        }
        assertEq(p.term(), address(term));
        assertEq(address(p.router()), address(v1Router));
        assertEq(address(p.tbaRegistry()), address(0xAAA1));
        assertEq(p.tbaImplementation(), address(0xAAA2));
        assertEq(p.shellClassOverride(2), 4);
        assertEq(p.shellClassOverride(7), 2);
        assertEq(p.shellClassOverride(3), 0);
        assertEq(h.distributor(), address(p));
        assertTrue(h.distributorLocked());
        assertEq(address(r.inner()), address(termRouter));
        assertEq(r.legacyHopper(), address(hopperV1));
        assertEq(r.hopperV2(), address(h));
    }

    function test_B_step1_revertsIfMarketRouterDiffersFromIgniteRouter() public {
        PulseV2Config memory c = _cfg();
        address other = makeAddr("otherRouter");
        vm.prank(owner);
        market.setSwapRouter(other);
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.MarketRouterMismatch.selector, address(termRouter), other));
        this.callStep1(c);
    }

    function callStep1(PulseV2Config memory c) external {
        PulseV2Migration.step1_deploy(c);
    }

    function test_B_steps1to6_verifyPasses_igniteStaysPaused_economicsUnchanged() public {
        uint16 hb = ignite.hopperBps();
        uint16 bb = ignite.burnBps();
        uint16 ab = ignite.allotmentBps();
        (uint16 mh, uint16 mb, uint16 mt) = (market.hopperBps(), market.burnBps(), market.treasuryBps());
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = _migrateB();

        PulseV2Migration.verify(_cfg(), h, p, r, fwd, false);
        assertFalse(ignite.igniteEnabled());
        assertEq(ignite.igniteFeeEth(), 0);
        assertEq(ignite.igniteFee(), 1_000 ether);
        assertEq(ignite.pendingHopperTerm(), 0);
        assertEq(ignite.hopperBps(), hb);
        assertEq(ignite.burnBps(), bb);
        assertEq(ignite.allotmentBps(), ab);
        // TermMarket: total (3%) and burn (1%) preserved; the hopper cut moved into the treasury cut.
        assertEq(mh, 150);
        assertEq(market.hopperBps(), 0);
        assertEq(market.burnBps(), mb);
        assertEq(uint256(market.hopperBps()) + market.burnBps() + market.treasuryBps(), uint256(mh) + mb + mt);
        assertEq(market.treasuryBps(), mh + mt);
        assertEq(address(ignite.swapRouter()), address(r));
        assertEq(address(market.swapRouter()), address(r));
        // V1 untouched.
        assertEq(hopperV1.distributor(), address(pulseV1));
        assertEq(pulseV1.epochCount(), 0);
    }

    function test_B_verifyFailsUntilEveryStepIsDone() public {
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = PulseV2Migration.step1_deploy(c);
        fwd = PulseV2Migration.step1b_deployForwarder(c, h);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "ignite dial hook != PulseV2"));
        this.callVerify(c, h, p, r, false);

        vm.prank(owner);
        PulseV2Migration.step3_pointDialHook(c, p);
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "ignite swapRouter != redirect"));
        this.callVerify(c, h, p, r, false);

        vm.prank(owner);
        PulseV2Migration.step4_igniteRouter(c, r);
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "market swapRouter != redirect"));
        this.callVerify(c, h, p, r, false);

        vm.prank(owner);
        PulseV2Migration.step5_marketRouter(c, r);
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "igniteFeeEth != 0"));
        this.callVerify(c, h, p, r, false);

        vm.prank(owner);
        PulseV2Migration.step6_zeroIgniteEthFee(c);
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "registeredCount != litCount"));
        this.callVerify(c, h, p, r, false);

        PulseV2Migration.step2_registerLit(c, p);
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "market treasury != forwarder"));
        this.callVerify(c, h, p, r, false);

        vm.startPrank(owner);
        PulseV2Migration.step7_marketTreasury(c, fwd);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "market hopperBps != 0"));
        this.callVerify(c, h, p, r, false);

        vm.startPrank(owner);
        PulseV2Migration.step8_marketFeeBps(c, fwd);
        vm.stopPrank();
        this.callVerify(c, h, p, r, false); // passes
    }

    function callVerify(
        PulseV2Config memory c,
        HopperV2 h,
        PulseDistributorV2 p,
        HopperRedirectRouter r,
        bool en
    ) external view {
        PulseV2Migration.verify(c, h, p, r, fwd, en);
    }

    function test_B_registerAllLit_thenPulseAndClaim() public {
        (HopperV2 h, PulseDistributorV2 p,) = _migrateB();
        assertEq(ignite.litCount(), 3);
        assertEq(p.registeredCount(), 3);
        vm.deal(address(this), 0.1 ether);
        (bool ok,) = address(h).call{value: 0.1 ether}("");
        assertTrue(ok);
        p.pulse();
        assertEq(p.epochCount(), 1);
        p.claim(1);
        assertEq(p.pending(1), 0);
    }

    function test_B_pulseBeforeRegistration_reverts() public {
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (HopperV2 h, PulseDistributorV2 p,) = PulseV2Migration.step1_deploy(c);
        vm.stopPrank();
        vm.deal(address(this), 0.1 ether);
        (bool ok,) = address(h).call{value: 0.1 ether}("");
        assertTrue(ok);
        vm.expectRevert(abi.encodeWithSelector(PulseDistributorV2.UnregisteredLit.selector, 0, 3));
        p.pulse();
    }

    function test_B_step7_enable_thenIgniteWithZeroEth_termCutLandsInHopperV2() public {
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = _migrateB();
        PulseV2Migration.verify(_cfg(), h, p, r, fwd, false);

        // Separate final step.
        vm.prank(owner);
        PulseV2Migration.step9_enableIgnite(_cfg());
        PulseV2Migration.verify(_cfg(), h, p, r, fwd, true);

        uint256 v1Before = address(hopperV1).balance;
        uint256 v2Before = address(h).balance;
        uint256 igniteTermBefore = term.balanceOf(address(ignite));
        uint256 supplyBefore = term.totalSupply();

        // Holder with an unspent first-wake allotment ignites with NO ETH and NO $TERM approval.
        vm.prank(alice);
        ignite.ignite(4);

        assertTrue(ignite.isLit(4));
        assertEq(ignite.litCount(), 4);
        assertEq(p.registeredCount(), 4);
        assertEq(p.litFromEpoch(4), 0);

        (uint256 hopperCut, uint256 burnCut, uint256 allotmentCut) = ignite.quote(1_000 ether);
        assertEq(hopperCut, 250 ether);
        // 25% of the $TERM fee, swapped to ETH (mock: 1:1), lands in HopperV2, not the V1 Hopper.
        assertEq(address(h).balance - v2Before, hopperCut);
        assertEq(address(hopperV1).balance, v1Before);
        // 37.5% burned, 37.5% stays in the module (escrow refill); the 25% left via the router.
        assertEq(supplyBefore - term.totalSupply(), burnCut);
        assertEq(igniteTermBefore - term.balanceOf(address(ignite)), hopperCut + burnCut);
        assertEq(allotmentCut, 375 ether);
        // Nothing stuck in the router or on Ignite.
        assertEq(address(r).balance, 0);
        assertEq(address(ignite).balance, 0);
        assertEq(term.balanceOf(address(r)), 0);

        // The new dial pays out of HopperV2.
        vm.deal(address(this), 0.1 ether);
        p.pulse();
        assertEq(p.epochCount(), 1);
    }

    function test_B_igniteRejectsAnyEth_afterStep6() public {
        _migrateB();
        vm.prank(owner);
        ignite.setIgniteEnabled(true);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.WrongEthFee.selector);
        ignite.ignite{value: 0.002 ether}(4);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.WrongEthFee.selector);
        ignite.ignite{value: 1}(4);
    }

    function test_B_beforeStep6_stillNeedsEth_noMigrationHalfWay() public {
        // Without step 6 the old ETH fee applies: protects against enabling early by mistake.
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = PulseV2Migration.step1_deploy(c);
        PulseV2Migration.step3_pointDialHook(c, p);
        PulseV2Migration.step4_igniteRouter(c, r);
        PulseV2Migration.step5_marketRouter(c, r);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "igniteFeeEth != 0"));
        this.callVerify(c, h, p, r, false);
    }

    function test_B_marketFees_afterSteps7and8_totalAndBurnPreserved_hopperGoesToV2() public {
        (HopperV2 h,,) = _migrateB();
        // Same 3% total, same 1% burn; the 1.5% hopper cut is now part of the treasury cut (2%).
        assertEq(market.hopperBps(), 0);
        assertEq(market.burnBps(), 100);
        assertEq(market.treasuryBps(), 200);
        assertEq(market.treasury(), address(fwd));
        assertEq(fwd.hopperPart(), 150);
        assertEq(fwd.totalPart(), 200);
        assertEq(fwd.treasury(), treasury);
        assertEq(fwd.hopperV2(), address(h));
        assertEq(fwd.owner(), multisig);

        // ETH-side skim, 10 ETH in: 3% = 0.3 ETH => burn 0.1, forwarder 0.2 => 0.15 V2 / 0.05 treasury.
        uint256 amountIn = 10 ether;
        (uint256 hopperCut, uint256 burnCut, uint256 treCut, uint256 totalFee) = market.quote(amountIn);
        assertEq(hopperCut, 0);
        assertEq(totalFee, 0.3 ether);
        vm.deal(dexPool, totalFee);
        uint256 v1Before = address(hopperV1).balance;
        uint256 v2Before = address(h).balance;
        uint256 treBefore = treasury.balance;
        uint256 supplyBefore = term.totalSupply();
        vm.prank(dexPool);
        market.onSwap{value: totalFee}(address(0), amountIn);

        assertEq(address(hopperV1).balance, v1Before, "V1 hopper must get nothing");
        assertEq(address(h).balance - v2Before, 0.15 ether);
        assertEq(treasury.balance - treBefore, 0.05 ether);
        assertEq(treCut, 0.2 ether);
        assertGt(supplyBefore - term.totalSupply(), 0); // burn leg still ran (ETH -> TERM -> burn)
        assertEq(burnCut, 0.1 ether);
        assertEq(address(fwd).balance, 0);
    }

    function test_B_marketTermSkim_toForwarder_thenKeeperFlushFundsHopperV2() public {
        (HopperV2 h,,) = _migrateB();
        uint256 amountIn = 10_000 ether;
        (, uint256 burnCut, uint256 treCut, uint256 totalFee) = market.quote(amountIn);
        uint256 v1Before = address(hopperV1).balance;
        uint256 supplyBefore = term.totalSupply();

        vm.startPrank(dexPool);
        term.approve(address(market), totalFee);
        market.onSwap(address(term), amountIn);
        vm.stopPrank();

        // No swap inside onSwap any more (hopper cut is 0): the 2% treasury cut sits in the forwarder as $TERM.
        assertEq(term.balanceOf(address(fwd)), treCut);
        assertEq(supplyBefore - term.totalSupply(), burnCut);
        assertEq(address(hopperV1).balance, v1Before);

        uint256 v2Before = address(h).balance;
        uint256 treTermBefore = term.balanceOf(treasury);
        vm.prank(multisig); // owner may flush; keeper optional
        fwd.flushTerm(0);
        uint256 toSwap = (treCut * 150) / 200;
        assertEq(address(h).balance - v2Before, toSwap); // mock router swaps 1:1
        assertEq(term.balanceOf(treasury) - treTermBefore, treCut - toSwap);
        assertEq(term.balanceOf(address(fwd)), 0);
        assertEq(address(fwd).balance, 0);
    }

    function test_B_step8_revertsIfBpsChangedUnderneath() public {
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (HopperV2 h,,) = PulseV2Migration.step1_deploy(c);
        fwd = PulseV2Migration.step1b_deployForwarder(c, h);
        market.setFeeBps(100, 100, 100);
        vm.stopPrank();
        vm.expectRevert(PulseV2Migration.MarketBpsMismatch.selector);
        this.callStep8(c);
    }

    function callStep8(PulseV2Config memory c) external {
        PulseV2Migration.step8_marketFeeBps(c, fwd);
    }

    function test_B_redirect_nonHopperRecipientUnchanged() public {
        (, , HopperRedirectRouter r) = _migrateB();
        address someone = makeAddr("someone");
        vm.prank(owner);
        term.mint(address(this), 10 ether);
        term.approve(address(r), 10 ether);
        uint256 before = someone.balance;
        r.swapExactTokenForETH(address(term), 10 ether, someone);
        assertEq(someone.balance - before, 10 ether);
    }

    // ------------------------------------------------- royalties: steps 1c and 10

    function _weth() internal returns (WETH9Mock w) {
        w = new WETH9Mock();
    }

    function test_R_step1c_deploysSplitter_changesNoLiveState_matchesV1Treasury() public {
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (HopperV2 h,,) = PulseV2Migration.step1_deploy(c);
        WETH9Mock w = _weth();
        (address recvBefore, uint256 bpsBefore) = nft.royaltyInfo(1, 10_000);
        RoyaltySplitterV2 rs = PulseV2Migration.step1c_deployRoyaltySplitter(c, h, address(w));
        vm.stopPrank();
        assertEq(rs.hopperV2(), address(h));
        assertEq(rs.treasury(), treasury); // same treasury the live V1 splitter pays
        assertEq(rs.weth(), address(w));
        (address recvAfter, uint256 bpsAfter) = nft.royaltyInfo(1, 10_000);
        assertEq(recvAfter, recvBefore);
        assertEq(bpsAfter, bpsBefore);
        assertEq(bpsAfter, 750);
        PulseV2Migration.verifyRoyalty(c, h, rs, false);
    }

    function test_R_step1c_revertsIfWethHasNoCode() public {
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (HopperV2 h,,) = PulseV2Migration.step1_deploy(c);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "weth has no code"));
        this.callStep1c(c, h, makeAddr("eoa"));
    }

    function callStep1c(PulseV2Config memory c, HopperV2 h, address w) external {
        PulseV2Migration.step1c_deployRoyaltySplitter(c, h, w);
    }

    function callVerifyRoyalty(PulseV2Config memory c, HopperV2 h, RoyaltySplitterV2 rs, bool z) external view {
        PulseV2Migration.verifyRoyalty(c, h, rs, z);
    }

    function test_R_step10_zeroesOnchainRoyalty_receiverStaysLocked_reversible() public {
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        (HopperV2 h,,) = PulseV2Migration.step1_deploy(c);
        RoyaltySplitterV2 rs = PulseV2Migration.step1c_deployRoyaltySplitter(c, h, address(_weth()));
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(PulseV2Migration.Check.selector, "onchain royalty bps unexpected"));
        this.callVerifyRoyalty(c, h, rs, true); // not done yet
        vm.startPrank(owner);
        (address recvBefore0,) = nft.royaltyInfo(1, 10_000);
        PulseV2Migration.step10_zeroOnchainRoyalty(c);
        vm.stopPrank();
        (, uint256 amt) = nft.royaltyInfo(1, 10_000);
        assertEq(amt, 0);
        PulseV2Migration.verifyRoyalty(c, h, rs, true);
        // receiver is still the locked V1 splitter; no lever points it anywhere else
        assertEq(nft.royaltyReceiver(), recvBefore0);
        vm.prank(owner);
        vm.expectRevert(CollectionNFT.RoyaltyReceiverLocked.selector);
        nft.setRoyaltyInfo(ISeaDropTokenContractMetadata.RoyaltyInfo(address(rs), 750));
        // reversible
        vm.prank(owner);
        nft.setRoyaltyBps(750);
        (, amt) = nft.royaltyInfo(1, 10_000);
        assertEq(amt, 750);
    }

    function test_R_step10_onlyCollectionOwner() public {
        PulseV2Config memory c = _cfg();
        vm.expectRevert();
        this.callStep10(c);
    }

    function callStep10(PulseV2Config memory c) external {
        PulseV2Migration.step10_zeroOnchainRoyalty(c);
    }

    function test_R_royaltiesThroughSplitterV2_fundHopperV2_thenPulseAndClaim() public {
        (HopperV2 h, PulseDistributorV2 p,) = _migrateB();
        PulseV2Config memory c = _cfg();
        vm.startPrank(owner);
        WETH9Mock w = _weth();
        RoyaltySplitterV2 rs = PulseV2Migration.step1c_deployRoyaltySplitter(c, h, address(w));
        vm.stopPrank();

        uint256 v1Before = address(hopperV1).balance;
        // an ETH royalty (plain transfer) and a WETH royalty (accepted-offer sale), 0.15 ETH each
        vm.deal(address(this), 0.3 ether);
        (bool ok,) = address(rs).call{value: 0.15 ether}("");
        assertTrue(ok);
        w.deposit{value: 0.15 ether}();
        w.transfer(address(rs), 0.15 ether);
        rs.unwrapWeth();

        assertEq(address(h).balance, 0.2 ether); // 2/3 of 0.3
        assertEq(treasury.balance, 0.1 ether);
        assertEq(address(hopperV1).balance, v1Before); // nothing reaches the V1 Hopper
        assertEq(h.available(), 0.2 ether);
        assertGe(h.available(), 0.1 ether); // above the 0.1 ETH first-pulse threshold

        p.pulse();
        assertEq(p.epochCount(), 1);
    }
}
