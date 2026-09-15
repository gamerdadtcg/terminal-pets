// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {Hopper} from "../src/Hopper.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";

contract LaunchRevealTest is Test {
    uint256 internal constant SUPPLY = 8;
    uint256 internal constant TEAM = 1;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopper;
    RoyaltySplitter internal splitter;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    TermToken internal term;
    TermFund internal fund;

    function setUp() public {
        vm.startPrank(owner);
        hopper = new Hopper(owner);
        splitter = new RoyaltySplitter(address(hopper), treasury, owner);
        nft = new CollectionNFT(
            CollectionConfig.NAME,
            CollectionConfig.SYMBOL,
            SUPPLY,
            TEAM,
            address(hopper),
            address(splitter),
            owner,
            CollectionConfig.ROYALTY_BPS
        );
        term = new TermToken(owner);
        fund = new TermFund(owner, address(term), treasury);
        ignite = new IgniteModule(address(nft), address(term), address(hopper), owner, FEE, address(fund), ETH_FEE);
        fund.lockIgnite(address(ignite));
        nft.setIgniteModule(address(ignite));
        splitter.arm(address(fund), address(nft));
        term.setLauncher(address(nft));
        term.setTransferExempt(address(ignite), true);
        term.setTransferExempt(address(fund), true);
        nft.setTermToken(address(term));
        term.mint(address(ignite), SUPPLY * FEE);
        term.mint(alice, 1_000 ether);
        nft.setMintOpen(true);
        vm.stopPrank();

        vm.deal(alice, 10 ether);
        vm.prank(alice);
        term.approve(address(ignite), type(uint256).max);
    }

    function test_revealAfter_is24hFromDeploy() public view {
        assertEq(nft.revealAfter(), uint64(block.timestamp + 24 hours));
        assertFalse(nft.revealed());
        assertFalse(nft.revealDue());
        assertFalse(splitter.live());
        assertFalse(ignite.igniteEnabled());
        assertFalse(term.tradingEnabled());
    }

    function test_preReveal_metadataSealed() public {
        vm.prank(alice);
        nft.mint(1);
        TerminalRenderer.Traits memory t = nft.tokenTraits(1);
        assertEq(t.state, "Sealed");
        assertEq(t.species, "Sealed");
        assertEq(nft.tokenURI(1), TerminalRenderer.hiddenTokenURI(1));
    }

    function test_preReveal_igniteOff() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.IgniteClosed.selector);
        ignite.ignite{value: ETH_FEE}(1);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.IgniteClosed.selector);
        ignite.claimIgniteAllotment(1);
    }

    function test_preReveal_tradingOff() public {
        vm.prank(alice);
        vm.expectRevert(TermToken.TradingClosed.selector);
        term.transfer(bob, 1 ether);
        // Mint from zero is always allowed (allotment / treasury float).
        assertEq(term.balanceOf(alice), 1_000 ether);
    }

    function test_preReveal_royaltyAllToTermFund() public {
        uint256 royalty = 0.75 ether;
        uint256 hopperBefore = hopper.available();
        uint256 treasuryBefore = treasury.balance;
        uint256 fundBefore = fund.available();

        (bool ok,) = address(splitter).call{value: royalty}("");
        assertTrue(ok);

        assertEq(hopper.available(), hopperBefore);
        assertEq(treasury.balance, treasuryBefore);
        assertEq(fund.available(), fundBefore + royalty);
        assertEq(address(splitter).balance, 0);
        (uint256 hop, uint256 tre) = splitter.preview(royalty);
        assertEq(hop, 0);
        assertEq(tre, 0);
    }

    function test_preReveal_hopperUnchangedWithExistingEth() public {
        vm.deal(address(hopper), 1 ether);
        uint256 hopperBefore = hopper.available();
        assertEq(hopperBefore, 1 ether);

        (bool ok,) = address(splitter).call{value: 0.75 ether}("");
        assertTrue(ok);

        assertEq(hopper.available(), hopperBefore);
        assertEq(fund.available(), 0.75 ether);
        assertEq(treasury.balance, 0);
    }

    function test_strangerCannotRevealEarly() public {
        vm.prank(alice);
        vm.expectRevert(CollectionNFT.RevealLocked.selector);
        nft.reveal();
    }

    function test_ownerReveal_enablesArtIgniteTradingRoyalties() public {
        vm.prank(alice);
        nft.mint(1);
        string memory sealedUri = nft.tokenURI(1);

        vm.prank(owner);
        nft.reveal();

        assertTrue(nft.revealed());
        assertTrue(splitter.live());
        assertTrue(ignite.igniteEnabled());
        assertTrue(term.tradingEnabled());

        TerminalRenderer.Traits memory t = nft.tokenTraits(1);
        assertEq(t.state, "Dormant");
        string memory liveUri = nft.tokenURI(1);
        assertTrue(keccak256(bytes(sealedUri)) != keccak256(bytes(liveUri)));

        vm.prank(alice);
        term.transfer(bob, 1 ether);
        assertEq(term.balanceOf(bob), 1 ether);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertTrue(ignite.isLit(1));
        assertEq(fund.available(), 0);
        assertEq(hopper.available(), ETH_FEE / 2);
        assertEq(ignite.pendingIgniteEthBurn(), ETH_FEE / 2);

        uint256 hopperBefore = hopper.available();
        uint256 treasuryBefore = treasury.balance;
        uint256 fundBefore = fund.available();
        uint256 royalty = 0.75 ether;
        (bool ok,) = address(splitter).call{value: royalty}("");
        assertTrue(ok);
        assertEq(hopper.available() - hopperBefore, 0.5 ether);
        assertEq(treasury.balance - treasuryBefore, 0.25 ether);
        assertEq(fund.available(), fundBefore);
    }

    function test_anyoneCanRevealAfter24h() public {
        vm.warp(block.timestamp + 24 hours);
        assertTrue(nft.revealDue());
        vm.prank(alice);
        nft.reveal();
        assertTrue(nft.revealed());
        assertTrue(ignite.igniteEnabled());
        assertTrue(term.tradingEnabled());
        assertTrue(splitter.live());
    }

    function test_revealTwiceReverts() public {
        vm.prank(owner);
        nft.reveal();
        vm.prank(owner);
        vm.expectRevert(CollectionNFT.AlreadyRevealed.selector);
        nft.reveal();
    }
}
