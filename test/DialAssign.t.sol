// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {Hopper} from "../src/Hopper.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {DialMath} from "../src/DialMath.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";
import {MockPulseRouter, MockStockToken} from "./mocks/MockPulseRouter.sol";

contract DialAssignTest is Test {
    uint256 internal constant SUPPLY = 20;
    uint256 internal constant TEAM = 2;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;
    uint256 internal constant THRESHOLD = 0.1 ether;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopper;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    PulseDistributor internal pulse;
    TermToken internal term;
    MockStockToken[8] internal stocks;

    function setUp() public {
        vm.startPrank(owner);
        hopper = new Hopper(owner);
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
        term.setTransferExempt(address(ignite), true);
        nft.setTermToken(address(term));
        nft.reveal();
        term.mint(address(ignite), SUPPLY * FEE);
        nft.setMintOpen(true);

        pulse = new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner);
        pulse.setTerm(address(term));
        MockPulseRouter router = new MockPulseRouter(2);
        pulse.setRouter(address(router));
        ignite.setPulseDistributor(address(pulse));
        hopper.lockDistributor(address(pulse));

        address[8] memory pool;
        for (uint8 i; i < 8; ++i) {
            stocks[i] = new MockStockToken(string.concat("S", vm.toString(i)), string.concat("S", vm.toString(i)));
            pool[i] = address(stocks[i]);
        }
        pulse.setStockTokens(pool);
        vm.stopPrank();

        vm.warp(hopper.hopperUnlockTime());
        vm.deal(alice, 10 ether);
        vm.deal(address(this), 10 ether);
    }

    function _mintIgnite(uint256 tokenId, uint8 shellClass) internal {
        vm.prank(alice);
        nft.mint(1);
        if (shellClass != 0) {
            vm.prank(owner);
            pulse.setShellClassOverride(tokenId, shellClass);
        }
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(tokenId);
    }

    function test_config_stockPoolSize() public pure {
        assertEq(CollectionConfig.STOCK_POOL_SIZE, 8);
        assertEq(CollectionConfig.MAX_DIAL_LEGS, 4);
        assertEq(
            uint256(CollectionConfig.SHELL_ALPHA_WEIGHT) + CollectionConfig.SHELL_BETA_WEIGHT
                + CollectionConfig.SHELL_DELTA_WEIGHT + CollectionConfig.SHELL_OMEGA_WEIGHT,
            100
        );
    }

    function test_assign_alpha_oneStock() public {
        _mintIgnite(1, DialMath.ALPHA);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(d.shellClass, DialMath.ALPHA);
        assertEq(d.nLegs, 1);
        assertEq(d.weight0, 10_000);
        assertEq(d.weight1, 0);
        assertEq(d.token0, address(stocks[d.slot0]));
        assertTrue(d.token0 != address(0));
        assertEq(d.token1, address(0));
    }

    function test_assign_beta_twoStocks() public {
        _mintIgnite(1, DialMath.BETA);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(d.nLegs, 2);
        assertEq(d.shellClass, DialMath.BETA);
        assertEq(uint256(d.weight0) + d.weight1, 10_000);
        assertEq(d.weight0, 5_000);
        assertEq(d.weight1, 5_000);
        assertTrue(d.slot0 != d.slot1);
        assertEq(d.token0, address(stocks[d.slot0]));
        assertEq(d.token1, address(stocks[d.slot1]));
    }

    function test_assign_delta_threeStocks_remainderOnLast() public {
        _mintIgnite(1, DialMath.DELTA);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(d.nLegs, 3);
        assertEq(d.weight0, 3_333);
        assertEq(d.weight1, 3_333);
        assertEq(d.weight2, 3_334);
        assertEq(uint256(d.weight0) + d.weight1 + d.weight2, 10_000);
        assertTrue(d.slot0 != d.slot1 && d.slot0 != d.slot2 && d.slot1 != d.slot2);
    }

    function test_assign_omega_fourStocks() public {
        _mintIgnite(1, DialMath.OMEGA);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(d.nLegs, 4);
        assertEq(d.weight0, 2_500);
        assertEq(d.weight1, 2_500);
        assertEq(d.weight2, 2_500);
        assertEq(d.weight3, 2_500);
        assertTrue(d.slot0 != d.slot1 && d.slot0 != d.slot2 && d.slot0 != d.slot3);
        assertTrue(d.slot1 != d.slot2 && d.slot1 != d.slot3 && d.slot2 != d.slot3);
    }

    function test_holder_cannot_choose_matches_preview() public {
        vm.prank(alice);
        nft.mint(1);
        PulseDistributor.Dial memory preview = pulse.previewDial(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        PulseDistributor.Dial memory assigned = pulse.getDial(1);
        assertEq(assigned.nLegs, preview.nLegs);
        assertEq(assigned.shellClass, preview.shellClass);
        assertEq(assigned.slot0, preview.slot0);
        assertEq(assigned.slot1, preview.slot1);
        assertEq(assigned.slot2, preview.slot2);
        assertEq(assigned.slot3, preview.slot3);
        vm.prank(alice);
        pulse.assignDial(1); // idempotent; still no picker
        PulseDistributor.Dial memory again = pulse.getDial(1);
        assertEq(again.slot0, assigned.slot0);
        assertEq(again.nLegs, assigned.nLegs);
    }

    function test_assignDial_revertsIfNotLit() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        vm.expectRevert(PulseDistributor.NotLit.selector);
        pulse.assignDial(1);
    }

    function test_deriveShellClass_weights() public view {
        uint256[5] memory counts;
        for (uint256 id = 1; id <= 400; ++id) {
            counts[pulse.shellClassOf(id)] += 1;
        }
        // keccak roll % 100 with 60/25/10/5 should land near those shares over 400 ids.
        assertGt(counts[DialMath.ALPHA], counts[DialMath.BETA]);
        assertGt(counts[DialMath.BETA], counts[DialMath.DELTA]);
        assertGt(counts[DialMath.DELTA], 0);
        assertGt(counts[DialMath.OMEGA], 0);
        assertEq(counts[DialMath.ALPHA] + counts[DialMath.BETA] + counts[DialMath.DELTA] + counts[DialMath.OMEGA], 400);
    }

    function test_stockAllowlist_rejectsDuplicates() public {
        vm.prank(owner);
        vm.expectRevert(PulseDistributor.DuplicateStock.selector);
        pulse.setStockToken(1, address(stocks[0]));
    }

    function test_stockAllowlist_zeroOk() public {
        vm.prank(owner);
        pulse.setStockToken(0, address(0));
        assertEq(pulse.stockPool(0), address(0));
    }

    function test_pulse_multileg_omega_claim() public {
        _mintIgnite(1, DialMath.OMEGA);
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();

        PulseDistributor.Dial memory d = pulse.getDial(1);
        uint256 share = pulse.pending(1);
        vm.prank(alice);
        pulse.claim(1);

        uint256 received;
        uint256 nonzero;
        for (uint8 i; i < 8; ++i) {
            uint256 bal = stocks[i].balanceOf(alice);
            if (bal > 0) {
                unchecked {
                    nonzero += 1;
                    received += bal;
                }
            }
        }
        assertEq(nonzero, 4);
        // Mock router rate 2: total stock units = 2 * ETH spent.
        assertEq(received, share * 2);
        assertEq(stocks[d.slot0].balanceOf(alice) > 0, true);
        assertEq(stocks[d.slot1].balanceOf(alice) > 0, true);
        assertEq(stocks[d.slot2].balanceOf(alice) > 0, true);
        assertEq(stocks[d.slot3].balanceOf(alice) > 0, true);
    }

    function test_pulse_delta_threeLeg_claim() public {
        _mintIgnite(1, DialMath.DELTA);
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();
        uint256 share = pulse.pending(1);
        vm.prank(alice);
        pulse.claim(1);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(
            stocks[d.slot0].balanceOf(alice) + stocks[d.slot1].balanceOf(alice) + stocks[d.slot2].balanceOf(alice),
            share * 2
        );
    }

    function test_emptyPool_claimBuysTerm() public {
        vm.startPrank(owner);
        address[8] memory empty;
        pulse.setStockTokens(empty);
        vm.stopPrank();

        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertGt(d.nLegs, 0);
        assertEq(d.token0, address(0));

        MockPulseRouter termRouter = new MockPulseRouter(2);
        vm.prank(owner);
        term.mint(address(termRouter), 10_000 ether);
        vm.prank(owner);
        pulse.setRouter(address(termRouter));

        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();

        uint256 share = pulse.pending(1);
        uint256 before = term.balanceOf(alice);
        vm.prank(alice);
        pulse.claim(1);
        assertEq(term.balanceOf(alice), before + share * 2);
        for (uint8 i; i < 8; ++i) {
            assertEq(stocks[i].balanceOf(alice), 0);
        }
    }

    function test_fillPoolAfterIgnite_stillDialsAtPulse() public {
        vm.startPrank(owner);
        address[8] memory empty;
        pulse.setStockTokens(empty);
        vm.stopPrank();

        _mintIgnite(1, DialMath.BETA);
        PulseDistributor.Dial memory beforeFill = pulse.getDial(1);
        assertEq(beforeFill.token0, address(0));

        address[8] memory pool;
        for (uint8 i; i < 8; ++i) {
            pool[i] = address(stocks[i]);
        }
        vm.prank(owner);
        pulse.setStockTokens(pool);

        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();

        uint256 share = pulse.pending(1);
        vm.prank(alice);
        pulse.claim(1);
        assertGt(stocks[beforeFill.slot0].balanceOf(alice), 0);
        assertGt(stocks[beforeFill.slot1].balanceOf(alice), 0);
        assertEq(stocks[beforeFill.slot0].balanceOf(alice) + stocks[beforeFill.slot1].balanceOf(alice), share * 2);
    }

    function test_routerUnset_dialedPaysEth() public {
        vm.prank(owner);
        pulse.setRouter(address(0));
        _mintIgnite(1, DialMath.ALPHA);
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();
        uint256 share = pulse.pending(1);
        uint256 before = alice.balance;
        vm.prank(alice);
        pulse.claim(1);
        assertEq(alice.balance, before + share);
    }

    function test_noDial_missedHook_buysTerm() public {
        vm.prank(owner);
        ignite.setPulseDistributor(address(0));
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(d.nLegs, 0);

        MockPulseRouter termRouter = new MockPulseRouter(2);
        vm.prank(owner);
        term.mint(address(termRouter), 10_000 ether);
        vm.prank(owner);
        pulse.setRouter(address(termRouter));

        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();
        uint256 share = pulse.pending(1);
        uint256 before = term.balanceOf(alice);
        vm.prank(alice);
        pulse.claim(1);
        assertEq(term.balanceOf(alice), before + share * 2);
    }
}
