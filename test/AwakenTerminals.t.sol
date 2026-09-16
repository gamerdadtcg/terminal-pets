// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {TerminalRenderer} from "../src/TerminalRenderer.sol";
import {Hopper} from "../src/Hopper.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermFund} from "../src/TermFund.sol";
import {MockTermLiquidityRouter} from "./mocks/MockTermLiquidityRouter.sol";
import {MockTermSwapRouter} from "./mocks/MockTermSwapRouter.sol";
import {ERC6551Registry} from "../src/tba/ERC6551Registry.sol";
import {ReceivableAccount} from "../src/tba/ReceivableAccount.sol";
import {MockERC6551Registry} from "../src/tba/MockERC6551Registry.sol";
import {MockPulseRouter, MockStockToken} from "./mocks/MockPulseRouter.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract AwakenTerminalsTest is Test {
    uint256 internal constant SUPPLY = 20;
    uint256 internal constant TEAM = 2;
    uint256 internal constant PUBLIC = 18;
    uint256 internal constant FEE = 1_000 ether;
    uint256 internal constant ETH_FEE = 0.002 ether;
    uint256 internal constant ETH_HOPPER = 0.001 ether;
    uint256 internal constant THRESHOLD = 0.1 ether;

    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal stranger = makeAddr("stranger");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopper;
    RoyaltySplitter internal splitter;
    CollectionNFT internal nft;
    IgniteModule internal ignite;
    PulseDistributor internal pulse;
    TermToken internal term;
    TermFund internal termFund;
    ERC6551Registry internal registry;
    ReceivableAccount internal tbaImpl;

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
        termFund = new TermFund(owner, address(term), treasury);
        ignite = new IgniteModule(address(nft), address(term), address(hopper), owner, FEE, address(termFund), ETH_FEE);
        termFund.lockIgnite(address(ignite));
        nft.setIgniteModule(address(ignite));
        splitter.arm(address(termFund), address(nft));
        term.setLauncher(address(nft));
        term.setTransferExempt(address(ignite), true);
        term.setTransferExempt(address(termFund), true);
        nft.setTermToken(address(term));
        nft.reveal();
        term.mint(address(ignite), SUPPLY * FEE);
        term.mint(alice, 1_000_000 ether);
        term.mint(bob, 1_000_000 ether);
        nft.setMintOpen(true);

        registry = new ERC6551Registry();
        tbaImpl = new ReceivableAccount();

        pulse = new PulseDistributor(address(hopper), address(nft), address(ignite), SUPPLY, owner);
        pulse.setTbaConfig(address(registry), address(tbaImpl), bytes32(0));
        pulse.setTerm(address(term));
        MockPulseRouter pulseTermRouter = new MockPulseRouter(1);
        term.mint(address(pulseTermRouter), 10_000 ether);
        pulse.setRouter(address(pulseTermRouter));
        ignite.setPulseDistributor(address(pulse));
        hopper.lockDistributor(address(pulse));
        vm.stopPrank();

        vm.warp(hopper.hopperUnlockTime());

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(stranger, 10 ether);
        vm.deal(address(this), 10 ether);

        vm.prank(alice);
        term.approve(address(ignite), type(uint256).max);
        vm.prank(bob);
        term.approve(address(ignite), type(uint256).max);
    }

    function _ignite(address who, uint256 tokenId) internal {
        vm.prank(who);
        ignite.ignite{value: ETH_FEE}(tokenId);
    }

    function test_configDefaults() public pure {
        assertEq(CollectionConfig.MAX_SUPPLY, 4444);
        assertEq(CollectionConfig.TEAM_RESERVE, 200);
        assertEq(CollectionConfig.PUBLIC_SUPPLY, 4244);
        assertEq(CollectionConfig.TEAM_RESERVE + CollectionConfig.PUBLIC_SUPPLY, CollectionConfig.MAX_SUPPLY);
        assertEq(CollectionConfig.REVEAL_DELAY, 24 hours);
        assertEq(keccak256(bytes(CollectionConfig.NAME)), keccak256(bytes("Terminal Pets")));
        assertEq(keccak256(bytes(CollectionConfig.SYMBOL)), keccak256(bytes("TERM")));
        assertEq(CollectionConfig.IGNITE_FEE_TERM, 1_000 ether);
        assertEq(CollectionConfig.IGNITE_FEE_ETH, 0.002 ether);
        assertEq(CollectionConfig.HOPPER_LOCK, 7 days);
        assertEq(CollectionConfig.TRADE_FEE_BPS, 300);
        assertEq(CollectionConfig.TRADE_HOPPER_BPS, 150);
        assertEq(CollectionConfig.TRADE_BURN_BPS, 100);
        assertEq(CollectionConfig.TRADE_TREASURY_BPS, 50);
        assertEq(CollectionConfig.IGNITE_ALLOTMENT_PER_TOKEN, CollectionConfig.IGNITE_FEE_TERM);
        assertEq(
            CollectionConfig.IGNITE_ALLOTMENT_SUPPLY, CollectionConfig.MAX_SUPPLY * CollectionConfig.IGNITE_FEE_TERM
        );
        assertEq(CollectionConfig.IGNITE_HOPPER_BPS, 2_500);
        assertEq(CollectionConfig.IGNITE_BURN_BPS, 3_750);
        assertEq(CollectionConfig.IGNITE_ALLOTMENT_REFILL_BPS, 3_750);
        assertEq(CollectionConfig.IGNITE_ETH_HOPPER_BPS, 5_000);
        assertEq(CollectionConfig.IGNITE_ETH_BURN_BPS, 5_000);
        assertEq(
            uint256(CollectionConfig.IGNITE_HOPPER_BPS) + CollectionConfig.IGNITE_BURN_BPS
                + CollectionConfig.IGNITE_ALLOTMENT_REFILL_BPS,
            10_000
        );
        assertEq(uint256(CollectionConfig.IGNITE_ETH_HOPPER_BPS) + CollectionConfig.IGNITE_ETH_BURN_BPS, 10_000);
        assertEq(CollectionConfig.PULSE_BOOTSTRAP_START_WEI, 0.1 ether);
        assertEq(CollectionConfig.PULSE_CYCLE_START_WEI, 0.5 ether);
        assertEq(CollectionConfig.PULSE_LADDER_CAP_WEI, 1 ether);
        assertEq(CollectionConfig.PULSE_LADDER_STEP_WEI, 0.1 ether);
        assertEq(CollectionConfig.ROYALTY_BPS, 750);
        assertEq(CollectionConfig.ROYALTY_HOPPER_BPS, 500);
        assertEq(CollectionConfig.ROYALTY_TREASURY_BPS, 250);
        assertEq(
            uint256(CollectionConfig.ROYALTY_HOPPER_BPS) + CollectionConfig.ROYALTY_TREASURY_BPS,
            CollectionConfig.ROYALTY_BPS
        );
    }

    function test_mintTo_openSeaPath() public {
        vm.prank(alice);
        uint256 first = nft.mintTo{value: 0}(bob, 2);
        assertEq(first, 1);
        assertEq(nft.ownerOf(1), bob);
        assertEq(nft.ownerOf(2), bob);
        assertEq(nft.totalSupply(), 2);
    }

    function test_mint_toCallerAndAddressOverload() public {
        vm.prank(alice);
        nft.mint{value: 0}(3);
        assertEq(nft.balanceOf(alice), 3);

        vm.prank(alice);
        uint256 id = nft.mint{value: 0}(bob);
        assertEq(nft.ownerOf(id), bob);
    }

    function test_mint_revertsWhenClosed() public {
        vm.prank(owner);
        nft.setMintOpen(false);
        vm.prank(alice);
        vm.expectRevert(CollectionNFT.MintClosed.selector);
        nft.mint(1);
    }

    function test_mint_requiresPayment() public {
        vm.prank(owner);
        nft.setMintPrice(0.1 ether);
        vm.prank(alice);
        vm.expectRevert(CollectionNFT.InsufficientPayment.selector);
        nft.mint{value: 0.05 ether}(1);

        vm.prank(alice);
        nft.mint{value: 0.1 ether}(1);
        assertEq(hopper.available(), 0.1 ether);
    }

    function test_maxSupply() public {
        vm.prank(alice);
        nft.mint(PUBLIC);
        vm.prank(alice);
        vm.expectRevert(CollectionNFT.PublicSupplyReached.selector);
        nft.mint(1);
        assertEq(nft.publicMinted(), PUBLIC);
        assertEq(nft.totalSupply(), PUBLIC);
    }

    function test_ownerMint_whenClosed() public {
        vm.prank(owner);
        nft.setMintOpen(false);
        vm.prank(owner);
        nft.ownerMint(alice, 2);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.teamMinted(), 2);
    }

    function test_teamMint_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        nft.teamMint(alice, 1);
    }

    function test_teamMint_toTreasury_capsAtReserve() public {
        vm.prank(owner);
        nft.teamMint(treasury, TEAM);
        assertEq(nft.balanceOf(treasury), TEAM);
        assertEq(nft.teamMintRemaining(), 0);
        vm.prank(owner);
        vm.expectRevert(CollectionNFT.TeamReserveExceeded.selector);
        nft.teamMint(treasury, 1);
    }

    function test_publicCannotEatTeamReserve() public {
        vm.prank(alice);
        nft.mint(PUBLIC);
        vm.prank(alice);
        vm.expectRevert(CollectionNFT.PublicSupplyReached.selector);
        nft.mint(1);

        vm.prank(owner);
        nft.teamMint(treasury, TEAM);
        assertEq(nft.totalSupply(), SUPPLY);
        assertEq(nft.publicMinted() + nft.teamMinted(), SUPPLY);

        vm.prank(owner);
        vm.expectRevert(CollectionNFT.TeamReserveExceeded.selector);
        nft.teamMint(treasury, 1);
    }

    function test_royaltyInfo_pointsToSplitter() public view {
        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10_000);
        assertEq(receiver, address(splitter));
        assertEq(amount, 750);
        assertEq(nft.royaltyReceiver(), address(splitter));
    }

    function test_royaltySplitter_twoThirdsHopper_oneThirdTreasury() public {
        uint256 sale = 10 ether;
        uint256 royalty = (sale * CollectionConfig.ROYALTY_BPS) / 10_000;
        assertEq(royalty, 0.75 ether);

        uint256 hopperBefore = hopper.available();
        uint256 treasuryBefore = treasury.balance;

        (bool ok,) = address(splitter).call{value: royalty}("");
        assertTrue(ok);

        assertEq(hopper.available() - hopperBefore, 0.5 ether);
        assertEq(treasury.balance - treasuryBefore, 0.25 ether);
        assertEq(address(splitter).balance, 0);

        (uint256 hopShare, uint256 treShare) = splitter.preview(royalty);
        assertEq(hopShare, 0.5 ether);
        assertEq(treShare, 0.25 ether);
    }

    function test_royaltySplitter_rejectsZeroTreasury() public {
        vm.expectRevert(RoyaltySplitter.ZeroAddress.selector);
        new RoyaltySplitter(address(hopper), address(0), owner);
    }

    function _setIgniteSwapRouter() internal returns (MockTermSwapRouter mock) {
        mock = new MockTermSwapRouter();
        vm.deal(address(mock), 10_000 ether);
        vm.prank(owner);
        term.mint(address(mock), 10_000 ether);
        vm.prank(owner);
        ignite.setSwapRouter(address(mock));
    }

    function _fundTermFund(uint256 amount) internal {
        (bool ok,) = address(termFund).call{value: amount}("");
        assertTrue(ok);
    }

    function test_ignite_splitsTerm_hopperEthBurnAllotmentRefill() public {
        _setIgniteSwapRouter();
        vm.prank(alice);
        nft.mint(1);
        uint256 hopperBefore = hopper.available();
        uint256 treasuryTerm = term.balanceOf(treasury);
        uint256 aliceTerm = term.balanceOf(alice);
        uint256 allotmentBefore = ignite.allotmentBalance();
        uint256 supplyBefore = term.totalSupply();
        uint256 fundEthBefore = termFund.available();
        uint256 fundTermBefore = termFund.termAvailable();
        (uint256 hopperCut, uint256 burnCut, uint256 allotmentCut) = ignite.quote(FEE);
        (uint256 ethHopper, uint256 ethBurn) = ignite.quoteEth(ETH_FEE);
        assertEq(hopperCut, 250 ether);
        assertEq(burnCut, 375 ether);
        assertEq(allotmentCut, 375 ether);
        assertEq(ethHopper, ETH_HOPPER);
        assertEq(ethBurn, ETH_HOPPER);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        assertEq(hopper.available() - hopperBefore, hopperCut + ETH_HOPPER);
        assertEq(ignite.pendingHopperTerm(), 0);
        assertEq(ignite.pendingIgniteEthBurn(), 0);
        assertEq(term.balanceOf(alice), aliceTerm);
        assertEq(ignite.allotmentBalance(), allotmentBefore - hopperCut - burnCut);
        assertEq(ignite.allotmentBalance(), allotmentBefore - FEE + allotmentCut);
        assertEq(term.balanceOf(treasury), treasuryTerm);
        assertEq(termFund.termAvailable(), fundTermBefore);
        assertEq(term.totalSupply(), supplyBefore - burnCut - ethBurn);
        assertTrue(ignite.allotmentConsumed(1));
        assertEq(termFund.available(), fundEthBefore);
        assertEq(address(ignite).balance, 0);
        assertEq(treasury.balance, 0);
    }

    function test_ignite_refillsAllotmentEscrow() public {
        vm.prank(alice);
        nft.mint(2);
        uint256 allotmentBefore = ignite.allotmentBalance();
        (uint256 hopperCut, uint256 burnCut, uint256 allotmentCut) = ignite.quote(FEE);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        assertEq(ignite.allotmentBalance(), allotmentBefore - hopperCut - burnCut);
        assertEq(termFund.termAvailable(), 0);
        assertEq(termFund.available(), 0);
        assertEq(ignite.pendingHopperTerm(), hopperCut);
        assertEq(ignite.pendingIgniteEthBurn(), ETH_HOPPER);
        assertEq(hopper.available(), ETH_HOPPER);
        assertEq(allotmentCut, 375 ether);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);
        assertTrue(ignite.isLit(2));
        assertEq(ignite.allotmentBalance(), allotmentBefore - 2 * (hopperCut + burnCut));
        assertEq(hopper.available(), 2 * ETH_HOPPER);
        assertEq(ignite.pendingIgniteEthBurn(), 2 * ETH_HOPPER);
    }

    function test_ignite_zeroEth_reverts() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.WrongEthFee.selector);
        ignite.ignite{value: 0}(1);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.WrongEthFee.selector);
        ignite.ignite{value: ETH_FEE - 1}(1);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.WrongEthFee.selector);
        ignite.ignite{value: ETH_FEE + 1}(1);
        assertFalse(ignite.isLit(1));
        assertEq(termFund.available(), 0);
        assertEq(hopper.available(), 0);
        assertEq(ignite.pendingIgniteEthBurn(), 0);
    }

    function test_termFund_seedLiquidity_afterRouter() public {
        _fundTermFund(ETH_FEE);
        assertEq(termFund.available(), ETH_FEE);
        assertEq(termFund.termAvailable(), 0);

        vm.prank(owner);
        vm.expectRevert(TermFund.RouterUnset.selector);
        termFund.seedLiquidity(1_000 ether, ETH_FEE);

        MockTermLiquidityRouter mock = new MockTermLiquidityRouter();
        vm.prank(owner);
        termFund.setRouter(address(mock));

        vm.prank(owner);
        term.mint(treasury, 5_000 ether);
        vm.prank(treasury);
        term.approve(address(termFund), 5_000 ether);

        vm.prank(owner);
        termFund.seedLiquidity(1_000 ether, ETH_FEE);

        assertEq(termFund.available(), 0);
        assertEq(mock.lastEth(), ETH_FEE);
        assertEq(mock.lastTerm(), 1_000 ether);
        assertEq(mock.lastToken(), address(term));
        assertEq(mock.lastLpTo(), treasury);
        assertEq(term.balanceOf(address(mock)), 1_000 ether);
        assertEq(termFund.termAvailable(), 0);
    }

    function test_termFund_seedLiquidity_doesNotSpendAllotment() public {
        vm.prank(alice);
        nft.mint(1);
        uint256 allotmentAfterMint = ignite.allotmentBalance();
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertEq(termFund.termAvailable(), 0);
        assertEq(termFund.available(), 0);
        assertEq(ignite.allotmentBalance(), allotmentAfterMint - 625 ether);

        _fundTermFund(ETH_FEE);

        vm.prank(owner);
        term.mint(treasury, 5_000 ether);
        vm.prank(treasury);
        term.approve(address(termFund), 5_000 ether);

        MockTermLiquidityRouter mock = new MockTermLiquidityRouter();
        vm.prank(owner);
        termFund.setRouter(address(mock));
        vm.prank(owner);
        termFund.seedLiquidity(1_000 ether, ETH_FEE);

        assertEq(termFund.termAvailable(), 0);
        assertEq(mock.lastTerm(), 1_000 ether);
        assertEq(ignite.allotmentBalance(), allotmentAfterMint - 625 ether);
        assertEq(ignite.pendingHopperTerm(), 250 ether);
    }

    function test_termFund_noOwnerEthWithdraw() public {
        _fundTermFund(ETH_FEE);

        vm.prank(owner);
        (bool ok,) = address(termFund).call(abi.encodeWithSignature("withdraw()"));
        assertFalse(ok);
        vm.prank(owner);
        (bool ok2,) = address(termFund).call(abi.encodeWithSignature("withdraw(uint256)", ETH_FEE));
        assertFalse(ok2);
        vm.prank(owner);
        (bool ok3,) = address(termFund).call(abi.encodeWithSignature("sweep(address)", owner));
        assertFalse(ok3);
        assertEq(termFund.available(), ETH_FEE);
    }

    function test_ignite_allotment_noUserTerm() public {
        vm.prank(alice);
        nft.mint(1);

        uint256 aliceTerm = term.balanceOf(alice);
        vm.prank(alice);
        term.transfer(bob, aliceTerm);
        vm.prank(alice);
        term.approve(address(ignite), 0);

        assertEq(term.balanceOf(alice), 0);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertTrue(nft.isLit(1));
        assertEq(term.balanceOf(alice), 0);
        assertTrue(ignite.allotmentConsumed(1));
    }

    function test_claimIgniteAllotment_thenIgniteFromWallet() public {
        vm.prank(alice);
        nft.mint(1);

        uint256 aliceBefore = term.balanceOf(alice);
        uint256 allotmentBefore = ignite.allotmentBalance();
        vm.prank(alice);
        ignite.claimIgniteAllotment(1);
        assertEq(term.balanceOf(alice), aliceBefore + FEE);
        assertEq(ignite.allotmentBalance(), allotmentBefore - FEE);
        assertTrue(ignite.allotmentConsumed(1));
        assertFalse(ignite.isLit(1));

        vm.prank(alice);
        vm.expectRevert(IgniteModule.AllotmentConsumed.selector);
        ignite.claimIgniteAllotment(1);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertTrue(ignite.isLit(1));
        assertEq(term.balanceOf(alice), aliceBefore);
        assertEq(ignite.allotmentBalance(), allotmentBefore - FEE + 375 ether);
        assertEq(termFund.available(), 0);
        assertEq(hopper.available(), ETH_HOPPER);
        assertEq(ignite.pendingIgniteEthBurn(), ETH_HOPPER);
    }

    function test_claimIgniteAllotment_onlyOwnerDormant() public {
        vm.prank(alice);
        nft.mint(1);

        vm.prank(bob);
        vm.expectRevert(IgniteModule.NotTokenOwner.selector);
        ignite.claimIgniteAllotment(1);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        vm.prank(alice);
        vm.expectRevert(IgniteModule.AlreadyLit.selector);
        ignite.claimIgniteAllotment(1);
    }

    function test_supportsInterfaces() public view {
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC721Enumerable).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC2981).interfaceId));
        assertTrue(nft.supportsInterface(0x49064906));
    }

    function test_ignite_oneWay_ethHalfHopper_parksBurnHalf() public {
        vm.prank(alice);
        nft.mint(1);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        assertTrue(ignite.isLit(1));
        assertTrue(nft.isLit(1));
        assertEq(ignite.litCount(), 1);
        assertEq(hopper.available(), ETH_HOPPER);
        assertEq(termFund.available(), 0);
        assertEq(termFund.termAvailable(), 0);
        assertEq(ignite.pendingHopperTerm(), 250 ether);
        assertEq(ignite.pendingIgniteEthBurn(), ETH_HOPPER);
        assertEq(treasury.balance, 0);

        vm.prank(alice);
        vm.expectRevert(IgniteModule.AlreadyLit.selector);
        ignite.ignite{value: ETH_FEE}(1);
    }

    function test_flushHopperTerm_swapsToHopperEth() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertEq(ignite.pendingHopperTerm(), 250 ether);
        assertEq(ignite.pendingIgniteEthBurn(), ETH_HOPPER);
        assertEq(hopper.available(), ETH_HOPPER);

        MockTermSwapRouter mock = new MockTermSwapRouter();
        vm.deal(address(mock), 1_000 ether);
        vm.prank(owner);
        term.mint(address(mock), 1_000 ether);
        vm.prank(owner);
        ignite.setSwapRouter(address(mock));

        ignite.flushHopperTerm();
        assertEq(ignite.pendingHopperTerm(), 0);
        assertEq(hopper.available(), 250 ether + ETH_HOPPER);
        assertEq(termFund.available(), 0);
        assertEq(ignite.pendingIgniteEthBurn(), ETH_HOPPER);
    }

    function test_ignite_ethFee_halfHopper_halfBuyBurn() public {
        MockTermSwapRouter mock = _setIgniteSwapRouter();
        vm.prank(alice);
        nft.mint(1);
        uint256 hopperBefore = hopper.available();
        uint256 supplyBefore = term.totalSupply();
        uint256 mockTermBefore = term.balanceOf(address(mock));
        uint256 treasuryBefore = treasury.balance;

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        assertEq(hopper.available() - hopperBefore, 250 ether + ETH_HOPPER);
        assertEq(termFund.available(), 0);
        assertEq(treasury.balance, treasuryBefore);
        assertEq(ignite.pendingIgniteEthBurn(), 0);
        assertEq(term.totalSupply(), supplyBefore - 375 ether - ETH_HOPPER);
        assertEq(term.balanceOf(address(mock)), mockTermBefore + 250 ether - ETH_HOPPER);
        assertEq(address(ignite).balance, 0);
    }

    function test_flushIgniteEthBurn_buysAndBurns() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        assertEq(ignite.pendingIgniteEthBurn(), ETH_HOPPER);

        MockTermSwapRouter mock = new MockTermSwapRouter();
        vm.deal(address(mock), 1_000 ether);
        vm.prank(owner);
        term.mint(address(mock), 1_000 ether);
        vm.prank(owner);
        ignite.setSwapRouter(address(mock));

        uint256 supplyBefore = term.totalSupply();
        ignite.flushIgniteEthBurn();
        assertEq(ignite.pendingIgniteEthBurn(), 0);
        assertEq(term.totalSupply(), supplyBefore - ETH_HOPPER);
        assertEq(termFund.available(), 0);
        assertEq(address(ignite).balance, 0);
    }

    function test_ignite_onlyTokenOwner() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(bob);
        vm.expectRevert(IgniteModule.NotTokenOwner.selector);
        ignite.ignite{value: ETH_FEE}(1);
    }

    function test_ignite_insufficientFee() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.claimIgniteAllotment(1);
        uint256 aliceTerm = term.balanceOf(alice);
        vm.prank(alice);
        term.transfer(bob, aliceTerm);
        vm.prank(alice);
        term.approve(address(ignite), FEE - 1);
        vm.prank(alice);
        vm.expectRevert();
        ignite.ignite{value: ETH_FEE}(1);
    }

    function test_pulse_startsAtBootstrapFirstRung() public view {
        assertEq(pulse.pulseThreshold(), 0.1 ether);
        assertFalse(pulse.bootstrapComplete());
        assertEq(pulse.ladderIndex(), 0);
    }

    function test_hopper_noAdminWithdraw() public {
        vm.deal(address(hopper), 1 ether);

        vm.prank(owner);
        (bool ok,) = address(hopper).call(abi.encodeWithSignature("withdraw()"));
        assertFalse(ok);

        vm.prank(owner);
        (bool ok2,) = address(hopper).call(abi.encodeWithSignature("withdraw(uint256)", 1 ether));
        assertFalse(ok2);

        vm.prank(owner);
        (bool ok3,) = address(hopper).call(abi.encodeWithSignature("sweep(address)", owner));
        assertFalse(ok3);

        vm.prank(owner);
        vm.expectRevert(Hopper.NotDistributor.selector);
        hopper.release(owner, 1 ether);

        assertEq(address(hopper).balance, 1 ether);
    }

    function test_distributor_lockOnce() public {
        vm.prank(owner);
        vm.expectRevert(Hopper.AlreadyLocked.selector);
        hopper.lockDistributor(address(pulse));
    }

    function test_pulse_belowThreshold_reverts() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        vm.prank(stranger);
        vm.expectRevert(PulseDistributor.HopperNotFull.selector);
        pulse.pulse();
    }

    function test_pulse_noLit_reverts() public {
        vm.deal(address(this), 1 ether);
        (bool ok,) = address(hopper).call{value: 1 ether}("");
        assertTrue(ok);

        vm.prank(stranger);
        vm.expectRevert(PulseDistributor.NoLitTerminals.selector);
        pulse.pulse();
    }

    function test_pulse_proRata_onlyLit() public {
        vm.prank(alice);
        nft.mint(3);
        vm.prank(bob);
        nft.mint(1);

        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);
        vm.prank(bob);
        ignite.ignite{value: ETH_FEE}(4);
        // token 3 stays Dormant

        vm.deal(address(this), 1 ether);
        (bool ok,) = address(hopper).call{value: 0.27 ether}("");
        assertTrue(ok);

        uint256 before = hopper.available();
        assertEq(before, 0.27 ether + 3 * ETH_HOPPER);

        vm.prank(stranger);
        pulse.pulse();

        uint256 lit = 3;
        uint256 share = before / lit;
        assertEq(pulse.pending(1), share);
        assertEq(pulse.pending(2), share);
        assertEq(pulse.pending(3), 0);
        assertEq(pulse.pending(4), share);
        assertFalse(nft.isLit(3));

        uint256 aliceTerm = term.balanceOf(alice);
        uint256 aliceEth = alice.balance;
        vm.prank(alice);
        pulse.claim(1);
        vm.prank(stranger);
        pulse.claim(2);
        assertEq(alice.balance, aliceEth);
        assertEq(term.balanceOf(alice), aliceTerm + 2 * share);

        uint256 bobTerm = term.balanceOf(bob);
        uint256 bobEth = bob.balance;
        vm.prank(bob);
        pulse.claim(4);
        assertEq(bob.balance, bobEth);
        assertEq(term.balanceOf(bob), bobTerm + share);

        vm.prank(alice);
        vm.expectRevert(PulseDistributor.NothingToClaim.selector);
        pulse.claim(3);
    }

    function test_doubleClaim_reverts() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);

        pulse.pulse();
        vm.prank(alice);
        pulse.claim(1);
        vm.prank(alice);
        vm.expectRevert(PulseDistributor.NothingToClaim.selector);
        pulse.claim(1);
    }

    function test_anyoneCanPulse() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);

        assertTrue(pulse.canPulse());
        vm.prank(stranger);
        pulse.pulse();
        assertEq(pulse.epochCount(), 1);
        assertFalse(pulse.canPulse());
    }

    function test_claim_toTba() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);

        address tba = pulse.tbaAddress(1);
        registry.createAccount(address(tbaImpl), bytes32(0), block.chainid, address(nft), 1);
        assertEq(pulse.tbaAddress(1), tba);

        vm.prank(owner);
        pulse.setDeliverToTba(true);

        pulse.pulse();
        uint256 share = pulse.pending(1);

        uint256 aliceBefore = alice.balance;
        uint256 aliceTerm = term.balanceOf(alice);
        pulse.claim(1);
        assertEq(alice.balance, aliceBefore);
        assertEq(tba.balance, 0);
        assertEq(term.balanceOf(alice), aliceTerm);
        assertEq(term.balanceOf(tba), share);
    }

    function test_mockTbaRegistry() public {
        MockERC6551Registry mock = new MockERC6551Registry();
        address predicted = mock.account(address(tbaImpl), bytes32(0), block.chainid, address(nft), 7);
        address created = mock.createAccount(address(tbaImpl), bytes32(0), block.chainid, address(nft), 7);
        assertTrue(created != address(0));
        assertEq(mock.account(address(tbaImpl), bytes32(0), block.chainid, address(nft), 7), created);
        assertTrue(predicted != address(0));
    }

    function test_metadata_changesOnIgnite() public {
        vm.prank(alice);
        nft.mint(1);
        TerminalRenderer.Traits memory t0 = nft.tokenTraits(1);
        string memory dormant = nft.tokenURI(1);
        vm.expectEmit(false, false, false, true, address(nft));
        emit CollectionNFT.MetadataUpdate(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        TerminalRenderer.Traits memory t1 = nft.tokenTraits(1);
        string memory lit = nft.tokenURI(1);
        assertEq(t0.state, "Dormant");
        assertEq(t1.state, "Lit");
        assertEq(t0.shell, t1.shell);
        assertEq(t0.shellColor, t1.shellColor);
        assertEq(t0.species, t1.species);
        assertEq(t0.bodyColor, t1.bodyColor);
        assertEq(t0.generation, t1.generation);
        assertTrue(keccak256(bytes(dormant)) != keccak256(bytes(lit)));
        assertTrue(bytes(nft.contractURI()).length > 200);
    }

    function test_notifyMetadataUpdate_onlyIgnite() public {
        vm.prank(alice);
        nft.mint(1);
        vm.prank(alice);
        vm.expectRevert(CollectionNFT.NotIgniteModule.selector);
        nft.notifyMetadataUpdate(1);
    }

    function test_tokensOfOwner() public {
        vm.prank(alice);
        nft.mint(3);
        uint256[] memory ids = nft.tokensOfOwner(alice);
        assertEq(ids.length, 3);
        assertEq(ids[0], 1);
        assertEq(ids[2], 3);
    }

    function test_royaltyBps_receiverStaysSplitter() public {
        vm.prank(owner);
        nft.setRoyaltyBps(250);
        (address receiver, uint256 amount) = nft.royaltyInfo(1, 10_000);
        assertEq(receiver, address(splitter));
        assertEq(amount, 250);
    }

    function test_claimMany() public {
        vm.prank(alice);
        nft.mint(2);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256 pendingTotal = pulse.pending(1) + pulse.pending(2);
        uint256 beforeEth = alice.balance;
        uint256 beforeTerm = term.balanceOf(alice);
        vm.prank(alice);
        pulse.claimMany(ids);
        assertEq(alice.balance, beforeEth);
        assertEq(term.balanceOf(alice), beforeTerm + pendingTotal);
    }

    function test_dial_assignsOnIgnite_noHolderPick() public {
        vm.prank(alice);
        nft.mint(1);

        vm.prank(alice);
        vm.expectRevert(PulseDistributor.NotLit.selector);
        pulse.assignDial(1);

        PulseDistributor.Dial memory preview = pulse.previewDial(1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        PulseDistributor.Dial memory d = pulse.getDial(1);
        assertEq(d.nLegs, preview.nLegs);
        assertEq(d.shellClass, preview.shellClass);
        assertEq(d.slot0, preview.slot0);
        // Empty allowlist: slots assigned, addresses still zero until owner fills.
        assertEq(d.token0, address(0));
        assertGt(d.weight0, 0);
    }

    function test_pulse_routerUnset_dialedPaysEth_undialedReverts() public {
        vm.prank(owner);
        pulse.setRouter(address(0));

        MockStockToken stock = new MockStockToken("Stock A", "STKA");
        address[8] memory pool;
        pool[0] = address(stock);
        for (uint8 i = 1; i < 8; ++i) {
            pool[i] = address(uint160(uint256(0xBEEF00) + i));
        }
        vm.prank(owner);
        pulse.setStockTokens(pool);

        vm.prank(owner);
        ignite.setPulseDistributor(address(0));

        vm.prank(alice);
        nft.mint(2);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);

        vm.prank(owner);
        ignite.setPulseDistributor(address(pulse));
        vm.prank(owner);
        pulse.setShellClassOverride(1, 1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();

        uint256 share = pulse.pending(1);
        uint256 before = alice.balance;
        vm.prank(alice);
        pulse.claim(1);
        assertEq(alice.balance, before + share);

        vm.prank(alice);
        vm.expectRevert(PulseDistributor.TermRouterRequired.selector);
        pulse.claim(2);
    }

    function test_pulse_dialedStocks_undialedBuysTerm() public {
        MockStockToken stock = new MockStockToken("Stock A", "STKA");
        MockPulseRouter mockRouter = new MockPulseRouter(2);
        vm.prank(owner);
        term.mint(address(mockRouter), 10_000 ether);
        vm.prank(owner);
        pulse.setRouter(address(mockRouter));

        address[8] memory pool;
        pool[0] = address(stock);
        vm.prank(owner);
        pulse.setStockTokens(pool);

        vm.prank(owner);
        ignite.setPulseDistributor(address(0));
        vm.prank(alice);
        nft.mint(2);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(2);

        vm.prank(owner);
        ignite.setPulseDistributor(address(pulse));
        vm.prank(owner);
        pulse.setShellClassOverride(1, 1);
        vm.prank(alice);
        ignite.ignite{value: ETH_FEE}(1);

        // ALPHA 1 stock — only slot 0 is guaranteed in-pool if pick lands on empty
        // slots. Fill the whole allowlist with the same mock? duplicates revert.
        // Re-fill remaining slots with extra mocks so any ALPHA slot resolves.
        MockStockToken[7] memory extra;
        vm.startPrank(owner);
        for (uint8 i = 1; i < 8; ++i) {
            extra[i - 1] = new MockStockToken("S", "S");
            pulse.setStockToken(i, address(extra[i - 1]));
        }
        vm.stopPrank();

        uint256 hopperBefore = hopper.available();
        (bool ok,) = address(hopper).call{value: THRESHOLD}("");
        assertTrue(ok);
        pulse.pulse();
        assertLt(hopper.available(), hopperBefore + THRESHOLD);

        uint256 share = pulse.pending(1);
        uint256 aliceEth = alice.balance;
        uint256 aliceTerm = term.balanceOf(alice);
        PulseDistributor.Dial memory d = pulse.getDial(1);
        vm.prank(alice);
        pulse.claim(1);
        assertEq(alice.balance, aliceEth);
        assertEq(term.balanceOf(alice), aliceTerm);
        address paidStock = pulse.stockPool(d.slot0);
        assertEq(MockStockToken(paidStock).balanceOf(alice), share * 2);

        vm.prank(alice);
        pulse.claim(2);
        assertEq(alice.balance, aliceEth);
        assertEq(MockStockToken(paidStock).balanceOf(alice), share * 2);
        assertEq(term.balanceOf(alice), aliceTerm + share * 2);
    }
}
