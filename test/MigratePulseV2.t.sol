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
        vm.stopPrank();
    }

    function _cfg(bool redirect) internal view returns (PulseV2Config memory c) {
        c.deployer = owner;
        c.owner = multisig;
        c.v1Hopper = address(hopperV1);
        c.v1Pulse = address(pulseV1);
        c.collection = address(nft);
        c.ignite = address(ignite);
        c.maxSupply = SUPPLY;
        c.redirectTermSlices = redirect;
    }

    function test_migration_copiesConfigAndWiresIgnite() public {
        PulseV2Config memory c = _cfg(true);
        vm.startPrank(owner);
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = PulseV2Migration.deployAndWire(c);
        vm.stopPrank();

        // Ownership handed to the multisig.
        assertEq(p.owner(), multisig);
        assertEq(h.owner(), multisig);
        // Production economics preserved.
        assertEq(h.payoutLock(), 7 days);
        assertEq(h.hopperUnlockTime(), uint256(hopperV1.revealedAt()) + 7 days);
        assertEq(p.bootstrapStart(), 0.1 ether);
        assertEq(p.cycleStart(), 0.5 ether);
        assertEq(p.ladderStep(), 0.1 ether);
        assertEq(ignite.igniteFeeEth(), 0.002 ether);
        // Config copied from V1.
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
        // Hooks.
        assertEq(address(ignite.pulseDistributor()), address(p));
        assertEq(h.distributor(), address(p));
        assertTrue(h.distributorLocked());
        assertEq(address(ignite.swapRouter()), address(r));
        assertEq(address(r.inner()), address(termRouter));
        // V1 untouched.
        assertEq(hopperV1.distributor(), address(pulseV1));
        assertEq(pulseV1.epochCount(), 0);
    }

    function test_migration_registerAllLit_thenPulseAndClaim() public {
        PulseV2Config memory c = _cfg(false);
        vm.startPrank(owner);
        (HopperV2 h, PulseDistributorV2 p,) = PulseV2Migration.deployAndWire(c);
        vm.stopPrank();

        assertEq(ignite.litCount(), 3);
        vm.deal(address(this), 0.1 ether);
        (bool ok,) = address(h).call{value: 0.1 ether}("");
        assertTrue(ok);
        vm.expectRevert(abi.encodeWithSelector(PulseDistributorV2.UnregisteredLit.selector, 0, 3));
        p.pulse();

        uint256 n = PulseV2Migration.registerAllLit(c, p);
        assertEq(n, 3);
        assertEq(p.registeredCount(), 3);
        p.pulse();
        assertEq(p.epochCount(), 1);
        p.claim(1);
        assertEq(p.pending(1), 0);
        assertEq(p.litFromEpoch(1), 0);
    }

    function test_migration_redirectOff_leavesIgniteRouter() public {
        PulseV2Config memory c = _cfg(false);
        vm.startPrank(owner);
        (,, HopperRedirectRouter r) = PulseV2Migration.deployAndWire(c);
        vm.stopPrank();
        assertEq(address(r), address(0));
        assertEq(address(ignite.swapRouter()), address(termRouter));
    }

    function test_migration_afterwards_newIgniteLandsOnV2_andTermSliceFundsV2() public {
        PulseV2Config memory c = _cfg(true);
        vm.startPrank(owner);
        (HopperV2 h, PulseDistributorV2 p,) = PulseV2Migration.deployAndWire(c);
        vm.stopPrank();
        PulseV2Migration.registerAllLit(c, p);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(4);
        assertEq(p.registeredCount(), 4);
        // 25% of the 1,000 $TERM fee converted 1:1 by the mock and delivered to HopperV2, not V1.
        assertEq(address(h).balance, 250 ether);
    }
}
