// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CollectionConfig} from "../src/CollectionConfig.sol";
import {Hopper} from "../src/Hopper.sol";
import {TermToken} from "../src/TermToken.sol";
import {TermMarket} from "../src/TermMarket.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {TermFund} from "../src/TermFund.sol";
import {CollectionNFT} from "../src/CollectionNFT.sol";
import {RoyaltySplitter} from "../src/RoyaltySplitter.sol";
import {MockTermSwapRouter} from "./mocks/MockTermSwapRouter.sol";
import {MockTermPool} from "./mocks/MockTermPool.sol";

contract TermMarketTest is Test {
    uint256 internal constant AMOUNT = 100 ether;

    address internal owner = makeAddr("owner");
    address internal trader = makeAddr("trader");
    address internal treasury = makeAddr("treasury");

    Hopper internal hopper;
    TermToken internal term;
    TermMarket internal market;
    MockTermSwapRouter internal router;
    MockTermPool internal pool;

    function setUp() public {
        vm.startPrank(owner);
        hopper = new Hopper(owner);
        term = new TermToken(owner);
        market = new TermMarket(owner, address(term), address(hopper), treasury);
        router = new MockTermSwapRouter();
        pool = new MockTermPool(address(market), address(term));

        market.setSwapRouter(address(router));
        market.setCanonicalPool(address(pool));
        term.enableTrading();

        term.mint(address(pool), 1_000 ether);
        term.mint(address(router), 1_000 ether);
        term.mint(trader, 500 ether);
        vm.stopPrank();

        vm.deal(address(pool), 1_000 ether);
        vm.deal(address(router), 1_000 ether);
        vm.deal(trader, 500 ether);

        vm.prank(trader);
        term.approve(address(pool), type(uint256).max);
    }

    function test_quote_3pctSplit() public view {
        (uint256 hopperCut, uint256 burnCut, uint256 treCut, uint256 totalFee) = market.quote(AMOUNT);
        assertEq(totalFee, 3 ether);
        assertEq(hopperCut, 1.5 ether);
        assertEq(burnCut, 1 ether);
        assertEq(treCut, 0.5 ether);
        assertEq(CollectionConfig.TRADE_FEE_BPS, 300);
        assertEq(CollectionConfig.TRADE_HOPPER_BPS, 150);
        assertEq(CollectionConfig.TRADE_BURN_BPS, 100);
        assertEq(CollectionConfig.TRADE_TREASURY_BPS, 50);
        assertEq(
            uint256(CollectionConfig.TRADE_HOPPER_BPS) + CollectionConfig.TRADE_BURN_BPS
                + CollectionConfig.TRADE_TREASURY_BPS,
            CollectionConfig.TRADE_FEE_BPS
        );
    }

    function test_inactiveUntilPoolAndRouter() public {
        TermMarket fresh = new TermMarket(owner, address(term), address(hopper), treasury);
        assertFalse(fresh.isActive());
        vm.prank(address(pool));
        vm.expectRevert(TermMarket.MarketInactive.selector);
        fresh.onSwap{value: 0}(address(0), AMOUNT);

        vm.prank(owner);
        fresh.setCanonicalPool(address(pool));
        assertFalse(fresh.isActive());

        vm.prank(owner);
        fresh.setSwapRouter(address(router));
        assertTrue(fresh.isActive());
    }

    function test_onlyCanonicalPool() public {
        vm.prank(trader);
        vm.expectRevert(TermMarket.NotPool.selector);
        market.onSwap{value: 3 ether}(address(0), AMOUNT);
    }

    function test_ethBuy_skimsHopperBurnTreasury() public {
        uint256 hopperBefore = hopper.available();
        uint256 supplyBefore = term.totalSupply();
        uint256 treasuryEth = treasury.balance;
        uint256 traderTerm = term.balanceOf(trader);

        vm.prank(trader);
        pool.swapExactETHForTerm{value: AMOUNT}();

        assertEq(hopper.available() - hopperBefore, 1.5 ether);
        assertEq(term.totalSupply(), supplyBefore - 1 ether);
        assertEq(treasury.balance - treasuryEth, 0.5 ether);
        assertEq(term.balanceOf(trader), traderTerm + 97 ether);
        assertEq(address(market).balance, 0);
    }

    function test_termSell_skimsHopperBurnTreasury() public {
        uint256 hopperBefore = hopper.available();
        uint256 supplyBefore = term.totalSupply();
        uint256 treasuryTerm = term.balanceOf(treasury);
        uint256 traderEth = trader.balance;

        vm.prank(trader);
        pool.swapExactTermForETH(AMOUNT);

        assertEq(hopper.available() - hopperBefore, 1.5 ether);
        assertEq(term.totalSupply(), supplyBefore - 1 ether);
        assertEq(term.balanceOf(treasury) - treasuryTerm, 0.5 ether);
        assertEq(trader.balance, traderEth + 97 ether);
    }

    function test_termToken_isNotFeeOnTransfer() public {
        uint256 supply = term.totalSupply();
        vm.prank(trader);
        term.transfer(treasury, 10 ether);
        assertEq(term.balanceOf(treasury), 10 ether);
        assertEq(term.totalSupply(), supply);
        assertEq(hopper.available(), 0);
    }

    function test_setFeeBps_mustSumToTradeFee() public {
        vm.prank(owner);
        vm.expectRevert(TermMarket.BadBps.selector);
        market.setFeeBps(200, 100, 50);

        vm.prank(owner);
        market.setFeeBps(200, 50, 50);
        (uint256 hopperCut, uint256 burnCut, uint256 treCut, uint256 totalFee) = market.quote(AMOUNT);
        assertEq(totalFee, 3 ether);
        assertEq(hopperCut, 2 ether);
        assertEq(burnCut, 0.5 ether);
        assertEq(treCut, 0.5 ether);
    }

    function test_igniteEth_halfHopper_notTermFund() public {
        vm.startPrank(owner);
        RoyaltySplitter splitter = new RoyaltySplitter(address(hopper), treasury, owner);
        CollectionNFT nft = new CollectionNFT(
            CollectionConfig.NAME,
            CollectionConfig.SYMBOL,
            8,
            1,
            address(hopper),
            address(splitter),
            owner,
            CollectionConfig.ROYALTY_BPS
        );
        TermFund fund = new TermFund(owner, address(term), treasury);
        IgniteModule ignite = new IgniteModule(
            address(nft),
            address(term),
            address(hopper),
            owner,
            CollectionConfig.IGNITE_FEE_TERM,
            address(fund),
            CollectionConfig.IGNITE_FEE_ETH
        );
        fund.lockIgnite(address(ignite));
        nft.setIgniteModule(address(ignite));
        splitter.arm(address(fund), address(nft));
        term.setLauncher(address(nft));
        nft.setTermToken(address(term));
        nft.reveal();
        nft.setMintOpen(true);
        term.mint(address(ignite), 8 * CollectionConfig.IGNITE_FEE_TERM);
        vm.stopPrank();

        uint256 hopperBefore = hopper.available();
        vm.prank(trader);
        nft.mint(1);
        vm.prank(trader);
        ignite.ignite{value: CollectionConfig.IGNITE_FEE_ETH}(1);

        uint256 ethHopper = CollectionConfig.IGNITE_FEE_ETH / 2;
        assertEq(hopper.available(), hopperBefore + ethHopper);
        assertEq(fund.available(), 0);
        assertEq(fund.termAvailable(), 0);
        assertEq(ignite.pendingHopperTerm(), 250 ether);
        assertEq(ignite.pendingIgniteEthBurn(), ethHopper);
        assertTrue(ignite.isLit(1));
    }
}
