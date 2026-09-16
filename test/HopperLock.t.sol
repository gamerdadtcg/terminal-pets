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

contract HopperLockTest is Test {
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
        term.mint(address(ignite), SUPPLY * FEE);
        nft.setMintOpen(true);
        pulse = new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner);
        pulse.setTerm(address(term));
        MockPulseRouter router = new MockPulseRouter(1);
        term.mint(address(router), 10_000 ether);
        pulse.setRouter(address(router));
        hopper.lockDistributor(address(pulse));
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        term.approve(address(ignite), type(uint256).max);
    }

    function test_lockedBeforeReveal_andAfterRevealUntil7Days() public {
        assertFalse(hopper.hopperUnlocked());
        assertEq(hopper.hopperUnlockTime(), 0);
        assertEq(hopper.collection(), address(nft));

        vm.prank(owner);
        nft.reveal();

        uint256 unlock = hopper.hopperUnlockTime();
        assertEq(unlock, block.timestamp + 7 days);
        assertFalse(hopper.hopperUnlocked());
        assertEq(uint256(hopper.revealedAt()), block.timestamp);

        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertEq(hopper.available(), ETH_FEE / 2);

        (bool ok,) = address(hopper).call{value: 0.1 ether}("");
        assertTrue(ok);
        assertEq(hopper.available(), ETH_FEE / 2 + 0.1 ether);

        assertFalse(pulse.canPulse());
        vm.expectRevert(abi.encodeWithSelector(Hopper.HopperLocked.selector, unlock));
        pulse.pulse();

        vm.warp(unlock - 1);
        assertFalse(hopper.hopperUnlocked());
        vm.expectRevert(abi.encodeWithSelector(Hopper.HopperLocked.selector, unlock));
        pulse.pulse();
    }

    function test_igniteDoesNotUnlockEarly() public {
        vm.prank(owner);
        nft.reveal();
        uint256 unlock = hopper.hopperUnlockTime();

        vm.prank(alice);
        nft.mint(3);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(3);

        assertEq(hopper.available(), 3 * (ETH_FEE / 2));
        assertFalse(hopper.hopperUnlocked());
        assertEq(hopper.hopperUnlockTime(), unlock);
        assertTrue(ignite.isLit(1));
        assertTrue(ignite.igniteEnabled());
    }

    function test_unlockAfter7Days_pulseCanSpendAccruedEth() public {
        vm.prank(owner);
        nft.reveal();
        uint256 unlock = hopper.hopperUnlockTime();

        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        uint256 accrued = hopper.available();
        assertEq(accrued, ETH_FEE / 2);

        (bool ok,) = address(hopper).call{value: 0.1 ether}("");
        assertTrue(ok);

        vm.warp(unlock);
        assertTrue(hopper.hopperUnlocked());
        assertTrue(pulse.canPulse());
        pulse.pulse();
        assertGt(pulse.pending(1), 0);
        vm.prank(alice);
        pulse.claim(1);
        assertEq(hopper.reserved(), 0);
    }

    function test_distributorReleaseBlockedUntilUnlock() public {
        vm.prank(owner);
        nft.reveal();
        vm.deal(address(hopper), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(Hopper.HopperLocked.selector, hopper.hopperUnlockTime()));
        vm.prank(address(pulse));
        hopper.reserve(0.1 ether);
    }

    function test_zeroPayoutLockUsesCollectionConfigDefault() public {
        Hopper h = new Hopper(owner, 0);
        assertEq(h.payoutLock(), CollectionConfig.HOPPER_LOCK);
        assertEq(CollectionConfig.HOPPER_LOCK, 7 days);
    }

    function test_customPayoutLock_unlocksAfterConfiguredDuration() public {
        uint256 lock = 15 minutes;
        Hopper h = new Hopper(owner, lock);
        assertEq(h.payoutLock(), lock);

        h.bindCollection();
        h.notifyReveal();

        uint256 unlock = h.hopperUnlockTime();
        assertEq(unlock, block.timestamp + lock);
        assertFalse(h.hopperUnlocked());

        vm.warp(unlock - 1);
        assertFalse(h.hopperUnlocked());
        vm.warp(unlock);
        assertTrue(h.hopperUnlocked());
    }
}
