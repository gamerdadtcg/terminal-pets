// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {Hopper} from "../src/Hopper.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";
import {MockPulseRouter} from "./mocks/MockPulseRouter.sol";

/// @notice Pulse ladder: bootstrap 0.1→1.0 once, then cycle 0.5→1.0 forever (never 0.1 again).
contract PulseLadderTest is Test {
    uint256 internal constant SUPPLY = 8;
    uint256 internal constant TEAM = 1;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopper;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    PulseDistributor internal pulse;
    TermToken internal term;

    function setUp() public {
        vm.startPrank(owner);
        hopper = new Hopper(owner, 0);
        RoyaltySplitter splitter = new RoyaltySplitter(address(hopper), treasury, owner);
        nft = new CollectionNFT(
            CollectionConfig.NAME,
            CollectionConfig.SYMBOL,
            SUPPLY,
            TEAM,
            address(hopper),
            address(splitter),
            owner,
            CollectionConfig.ROYALTY_BPS,
            new address[](0)
        );
        term = new TermToken(owner);
        TermFund fund = new TermFund(owner, address(term), treasury);
        ignite = new IgniteModule(address(nft), address(term), address(hopper), owner, FEE, address(fund), ETH_FEE);
        fund.lockIgnite(address(ignite));
        nft.setIgniteModule(address(ignite));
        splitter.arm(address(fund), address(nft));
        term.setLauncher(address(nft));
        nft.setTermToken(address(term));
        nft.reveal();
        term.mint(address(ignite), SUPPLY * FEE);
        nft.setMintOpen(true);
        pulse = new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner, 0, 0, 0);
        pulse.setTerm(address(term));
        MockPulseRouter pulseTermRouter = new MockPulseRouter(1);
        term.mint(address(pulseTermRouter), 40 ether);
        pulse.setRouter(address(pulseTermRouter));
        hopper.lockDistributor(address(pulse));
        vm.stopPrank();

        vm.warp(hopper.hopperUnlockTime());

        vm.deal(alice, 1 ether);
        vm.deal(address(this), 40 ether);

        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
    }

    function test_bootstrapSequence_0_1_to_1_0_then_0_5_not_0_1() public {
        uint256[10] memory bootstrap = [
            uint256(0.1 ether),
            0.2 ether,
            0.3 ether,
            0.4 ether,
            0.5 ether,
            0.6 ether,
            0.7 ether,
            0.8 ether,
            0.9 ether,
            1.0 ether
        ];

        assertFalse(pulse.bootstrapComplete());
        for (uint256 i; i < bootstrap.length; ++i) {
            assertEq(pulse.pulseThreshold(), bootstrap[i], "bootstrap rung");
            assertFalse(pulse.bootstrapComplete());
            _fundExact(bootstrap[i]);
            pulse.pulse();
            _claimDust();
        }

        assertTrue(pulse.bootstrapComplete());
        assertEq(pulse.ladderIndex(), 0);
        assertEq(pulse.pulseThreshold(), 0.5 ether, "after 1.0 bootstrap next is 0.5 not 0.1");

        _fundExact(0.1 ether);
        vm.expectRevert(PulseDistributor.HopperNotFull.selector);
        pulse.pulse();
        assertEq(pulse.pulseThreshold(), 0.5 ether);
    }

    function test_cycle_0_5_to_1_0_then_back_to_0_5() public {
        _runBootstrap();

        uint256[6] memory cycle = [uint256(0.5 ether), 0.6 ether, 0.7 ether, 0.8 ether, 0.9 ether, 1.0 ether];

        for (uint256 round; round < 2; ++round) {
            for (uint256 i; i < cycle.length; ++i) {
                assertTrue(pulse.bootstrapComplete());
                assertEq(pulse.pulseThreshold(), cycle[i], "cycle rung");
                _fundExact(cycle[i]);
                pulse.pulse();
                _claimDust();
            }
            assertEq(pulse.pulseThreshold(), 0.5 ether, "wrap to 0.5");
            assertTrue(pulse.bootstrapComplete());
        }
    }

    function test_belowFirstRung_cannotPulse() public {
        assertEq(pulse.pulseThreshold(), 0.1 ether);
        (bool ok,) = address(hopper).call{value: 0.09 ether}("");
        assertTrue(ok);
        assertFalse(pulse.canPulse());
        vm.expectRevert(PulseDistributor.HopperNotFull.selector);
        pulse.pulse();
    }

    function test_zeroLadderArgsUseCollectionConfigDefaults() public {
        PulseDistributor p =
            new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner, 0, 0, 0);
        assertEq(p.bootstrapStart(), CollectionConfig.PULSE_BOOTSTRAP_START_WEI);
        assertEq(p.cycleStart(), CollectionConfig.PULSE_CYCLE_START_WEI);
        assertEq(p.ladderStep(), CollectionConfig.PULSE_LADDER_STEP_WEI);
        assertEq(p.pulseThreshold(), 0.1 ether);
        assertEq(CollectionConfig.PULSE_BOOTSTRAP_START_WEI, 0.1 ether);
        assertEq(CollectionConfig.PULSE_CYCLE_START_WEI, 0.5 ether);
        assertEq(CollectionConfig.PULSE_LADDER_STEP_WEI, 0.1 ether);
    }

    function test_customLadder_pulseThresholdUsesConstructorValues() public {
        uint256 bootstrap = 0.0001 ether;
        uint256 cycle = 0.0001 ether;
        uint256 step = 0.00001 ether;
        PulseDistributor p =
            new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner, bootstrap, cycle, step);
        assertEq(p.bootstrapStart(), bootstrap);
        assertEq(p.cycleStart(), cycle);
        assertEq(p.ladderStep(), step);
        assertEq(p.pulseThreshold(), bootstrap);
    }

    function test_customLadder_zeroCycleAndStepFallBackIndependently() public {
        uint256 bootstrap = 0.0001 ether;
        PulseDistributor p =
            new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner, bootstrap, 0, 0);
        assertEq(p.bootstrapStart(), bootstrap);
        assertEq(p.cycleStart(), CollectionConfig.PULSE_CYCLE_START_WEI);
        assertEq(p.ladderStep(), CollectionConfig.PULSE_LADDER_STEP_WEI);
        assertEq(p.pulseThreshold(), bootstrap);
    }

    function test_customLadder_canPulseAtMicroBootstrapStart() public {
        uint256 bootstrap = 0.0001 ether;
        uint256 cycle = 0.0001 ether;
        uint256 step = 0.00001 ether;
        uint256 microEthFee = 0.00005 ether;

        vm.startPrank(owner);
        Hopper h = new Hopper(owner, 0);
        RoyaltySplitter splitter = new RoyaltySplitter(address(h), treasury, owner);
        CollectionNFT n = new CollectionNFT(
            CollectionConfig.NAME,
            CollectionConfig.SYMBOL,
            SUPPLY,
            TEAM,
            address(h),
            address(splitter),
            owner,
            CollectionConfig.ROYALTY_BPS,
            new address[](0)
        );
        TermToken t = new TermToken(owner);
        TermFund fund = new TermFund(owner, address(t), treasury);
        IgniteModule ig = new IgniteModule(address(n), address(t), address(h), owner, FEE, address(fund), microEthFee);
        fund.lockIgnite(address(ig));
        n.setIgniteModule(address(ig));
        splitter.arm(address(fund), address(n));
        t.setLauncher(address(n));
        n.setTermToken(address(t));
        n.reveal();
        t.mint(address(ig), SUPPLY * FEE);
        n.setMintOpen(true);
        PulseDistributor p =
            new PulseDistributor(address(h), address(n), address(ig), SUPPLY, owner, bootstrap, cycle, step);
        p.setTerm(address(t));
        MockPulseRouter r = new MockPulseRouter(1);
        t.mint(address(r), 40 ether);
        p.setRouter(address(r));
        h.lockDistributor(address(p));
        vm.stopPrank();

        vm.warp(h.hopperUnlockTime());

        address smoker = makeAddr("smoker");
        vm.deal(smoker, 1 ether);
        vm.prank(smoker);
        n.mint(1);
        vm.prank(smoker);
        ig.ignite{value: microEthFee}(1);

        assertEq(p.pulseThreshold(), bootstrap);
        assertLt(h.available(), bootstrap);
        assertFalse(p.canPulse());
        vm.expectRevert(PulseDistributor.HopperNotFull.selector);
        p.pulse();

        uint256 avail = h.available();
        (bool ok,) = address(h).call{value: bootstrap - avail}("");
        assertTrue(ok);
        assertTrue(p.canPulse());
        p.pulse();
        assertEq(p.ladderIndex(), 1);
        assertFalse(p.bootstrapComplete());
        assertEq(p.pulseThreshold(), bootstrap + step);

        vm.prank(smoker);
        p.claim(1);
        assertEq(h.available(), 0);
    }

    function _runBootstrap() internal {
        for (uint256 i = 1; i <= 10; ++i) {
            uint256 need = i * 0.1 ether;
            _fundExact(need);
            pulse.pulse();
            _claimDust();
        }
        assertTrue(pulse.bootstrapComplete());
        assertEq(pulse.pulseThreshold(), 0.5 ether);
    }

    function _fundExact(uint256 need) internal {
        uint256 avail = hopper.available();
        if (avail < need) {
            (bool ok,) = address(hopper).call{value: need - avail}("");
            assertTrue(ok);
        }
        assertGe(hopper.available(), need);
    }

    function _claimDust() internal {
        // One Lit token: Pulse reserves 100% of available, leftover is 0.
        assertEq(hopper.available(), 0);
        vm.prank(alice);
        pulse.claim(1);
    }
}
