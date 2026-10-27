// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {PulseV2Config, PulseV2Migration} from "../../script/MigratePulseV2.s.sol";
import {HopperV2} from "../../src/HopperV2.sol";
import {HopperRedirectRouter} from "../../src/HopperRedirectRouter.sol";
import {PulseDistributorV2} from "../../src/PulseDistributorV2.sol";
import {PulseDistributor} from "../../src/PulseDistributor.sol";
import {IgniteModule} from "../../src/IgniteModule.sol";
import {TermMarket} from "../../src/TermMarket.sol";
import {TermMarketFeeForwarder} from "../../src/TermMarketFeeForwarder.sol";
import {Hopper} from "../../src/Hopper.sol";
import {ITermSwapRouter} from "../../src/interfaces/ITermSwapRouter.sol";

/// @notice Mainnet-fork rehearsal of the whole Option B migration against the LIVE Robinhood Chain (4663)
/// contracts. Nothing is broadcast: the owner is impersonated on a local fork.
///
///   FORK_RPC=https://rpc.mainnet.chain.robinhood.com forge test --match-path test/fork/MainnetFork.t.sol -vv
///
/// Skipped when FORK_RPC is unset so the normal suite stays offline.
contract MainnetForkTest is Test {
    address constant OWNER = 0xA71c8cAC3bc8bc1085f87885fD2898f970edDc37;
    address constant V1_HOPPER = 0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2;
    address constant V1_PULSE = 0x7326F7D277610288FBeA373712c89E47AF9AC61E;
    address constant COLLECTION = 0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166;
    address constant IGNITE = 0x29e8dB2073583720C3CBf741d278d942B65cb92B;
    address constant MARKET = 0x78f2c0577321053722Daa1f5eE31E5071a7D9F30;
    address constant TERM = 0xCa75Bc5eD48Bd9B8D1a939253e40e7AE3e61DAA6;
    address constant REAL_ROUTER = 0xDe6dF0527608A20121ecD6aA009C198Ca1cba28F;

    PulseV2Config internal c;
    HopperV2 internal hopper;
    PulseDistributorV2 internal pulse;
    HopperRedirectRouter internal redirect;
    TermMarketFeeForwarder internal fwd;

    IgniteModule internal ignite = IgniteModule(IGNITE);
    TermMarket internal market = TermMarket(payable(MARKET));
    IERC20 internal term = IERC20(TERM);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) vm.skip(true);
        uint256 blk = vm.envOr("FORK_BLOCK", uint256(0));
        if (blk == 0) vm.createSelectFork(rpc);
        else vm.createSelectFork(rpc, blk);
        require(block.chainid == 4663, "wrong chain");
        c = PulseV2Config({
            deployer: OWNER,
            owner: OWNER,
            v1Hopper: V1_HOPPER,
            v1Pulse: V1_PULSE,
            collection: COLLECTION,
            ignite: IGNITE,
            termMarket: MARKET,
            maxSupply: 4444
        });
    }

    function _litIds() internal view returns (uint256[] memory ids) {
        uint256 n = ignite.litCount();
        ids = new uint256[](n);
        uint256 k;
        for (uint256 w; w <= 17 && k < n; ++w) {
            uint256 bm = ignite.litBitmap(w);
            for (uint256 b; b < 256 && bm != 0; ++b) {
                if ((bm >> b) & 1 == 1) {
                    ids[k++] = w * 256 + b;
                    bm &= ~(uint256(1) << b);
                }
            }
        }
        require(k == n, "lit scan mismatch");
    }

    function _migrate() internal {
        vm.startPrank(OWNER);
        (hopper, pulse, redirect) = PulseV2Migration.step1_deploy(c);
        fwd = PulseV2Migration.step1b_deployForwarder(c, hopper);
        PulseV2Migration.step2_registerLit(c, pulse);
        PulseV2Migration.step3_pointDialHook(c, pulse);
        PulseV2Migration.step4_igniteRouter(c, redirect);
        PulseV2Migration.step5_marketRouter(c, redirect);
        PulseV2Migration.step6_zeroIgniteEthFee(c);
        PulseV2Migration.step7_marketTreasury(c, fwd);
        PulseV2Migration.step8_marketFeeBps(c, fwd);
        vm.stopPrank();
        PulseV2Migration.verify(c, hopper, pulse, redirect, fwd, false);
    }

    function test_fork_liveStateAssumptions() public view {
        console.log("block", block.number, "ts", block.timestamp);
        assertEq(Hopper(payable(V1_HOPPER)).distributor(), V1_PULSE);
        assertEq(ignite.owner(), OWNER);
        assertEq(market.owner(), OWNER);
        assertEq(address(ignite.swapRouter()), REAL_ROUTER);
        assertEq(ignite.igniteFee(), 1_000 ether);
        assertEq(ignite.pendingHopperTerm(), 0);
        console.log("litCount", ignite.litCount());
        console.log("igniteEnabled", ignite.igniteEnabled());
        console.log("igniteFeeEth", ignite.igniteFeeEth());
        console.log("market hopper/burn/treasury bps", market.hopperBps(), market.burnBps(), market.treasuryBps());
        console.log("market treasury", market.treasury());
        console.log("market active", market.isActive());
        console.log("treasury codesize", market.treasury().code.length);
        console.log("V1 hopper ETH", V1_HOPPER.balance);
    }

    /// @dev The full user journey on the fork: migrate, enable, ignite with 0 ETH, trade, pulse, claim.
    function test_fork_fullMigrationAndJourney() public {
        uint256 v1HopperBefore = V1_HOPPER.balance;
        _migrate();

        // Everything registered, verify() passed with Ignite still paused.
        assertEq(pulse.registeredCount(), ignite.litCount());
        assertFalse(ignite.igniteEnabled());

        // STEP 9 (owner) then a real Ignite with ZERO ETH, funded by the allotment escrow.
        vm.prank(OWNER);
        PulseV2Migration.step9_enableIgnite(c);
        PulseV2Migration.verify(c, hopper, pulse, redirect, fwd, true);

        uint256 tokenId = _firstDormantToken();
        address holder = IERC721(COLLECTION).ownerOf(tokenId);
        uint256 v2Before = address(hopper).balance;
        uint256 termInIgniteBefore = term.balanceOf(IGNITE);
        uint256 lit0 = ignite.litCount();

        vm.prank(holder);
        uint256 g = gasleft();
        ignite.ignite(tokenId);
        console.log("ignite() gas (0 ETH)", g - gasleft());

        assertEq(ignite.litCount(), lit0 + 1);
        assertEq(pulse.registeredCount(), lit0 + 1, "ignite hook registered the pet in V2");
        assertEq(V1_HOPPER.balance, v1HopperBefore, "V1 Hopper untouched by ignite");
        uint256 ethToHopperV2 = address(hopper).balance - v2Before;
        uint256 termSwapped = termInIgniteBefore - term.balanceOf(IGNITE);
        console.log("TERM leaving Ignite (burn+swap)", termSwapped);
        console.log("ETH into HopperV2 from 250 TERM swap (wei)", ethToHopperV2);
        assertGt(ethToHopperV2, 0, "250 TERM swap produced ETH for HopperV2");

        // ------------------------------------------------------------ TermMarket trade (simulated pool)
        // TermMarket is inactive live (no canonical pool). Impersonate the pool to exercise the fee routing
        // with the real router, the real treasury and the real $TERM.
        address pool = makeAddr("canonicalPool");
        vm.prank(OWNER);
        market.setCanonicalPool(pool);
        assertTrue(market.isActive());
        assertEq(market.hopperBps(), 0);
        assertEq(uint256(market.burnBps()) + market.treasuryBps(), 300, "total fee 3% preserved");
        assertEq(market.burnBps(), 100, "burn 1% preserved");

        address realTreasury = fwd.treasury();
        uint256 treBefore = realTreasury.balance;
        uint256 v2b = address(hopper).balance;
        uint256 v1b = V1_HOPPER.balance;
        uint256 amountIn = 0.5 ether; // trader swaps 0.5 ETH
        (, uint256 burnCut,, uint256 totalFee) = market.quote(amountIn);
        vm.deal(pool, totalFee);
        vm.prank(pool);
        market.onSwap{value: totalFee}(address(0), amountIn);
        console.log("ETH trade: total fee", totalFee, "burnCut", burnCut);
        console.log("-> HopperV2", address(hopper).balance - v2b);
        console.log("-> treasury", realTreasury.balance - treBefore);
        assertEq(V1_HOPPER.balance, v1b, "V1 Hopper gets nothing from market ETH skim");
        assertEq(address(hopper).balance - v2b + realTreasury.balance - treBefore, totalFee - burnCut, "fee conserved");
        assertEq(address(fwd).balance, 0);

        // TERM-side trade, then keeper flush via the real router.
        uint256 termIn = 100_000 ether;
        (,,, uint256 termFee) = market.quote(termIn);
        vm.prank(IGNITE); // Ignite holds the escrow; use it as a TERM source for the simulated pool
        term.transfer(pool, termFee);
        vm.startPrank(pool);
        term.approve(MARKET, termFee);
        market.onSwap(TERM, termIn);
        vm.stopPrank();
        uint256 fwdTerm = term.balanceOf(address(fwd));
        console.log("TERM held by forwarder after trade", fwdTerm);
        assertGt(fwdTerm, 0);
        uint256 v2c = address(hopper).balance;
        vm.prank(OWNER);
        fwd.flushTerm(0);
        console.log("flushTerm: ETH into HopperV2 (wei)", address(hopper).balance - v2c);
        assertEq(term.balanceOf(address(fwd)), 0);
        assertEq(address(fwd).balance, 0);
        assertEq(V1_HOPPER.balance, v1b);

        // ------------------------------------------------------------ Pulse + claim
        uint256 need = pulse.pulseThreshold();
        vm.warp(hopper.hopperUnlockTime() + 1);
        vm.deal(address(this), need + 1 ether);
        (bool ok,) = address(hopper).call{value: need + 1 ether}("");
        assertTrue(ok);
        assertTrue(pulse.canPulse());
        g = gasleft();
        pulse.pulse();
        console.log("pulse() gas", g - gasleft());

        uint256 hopperBeforePulse = address(hopper).balance;
        uint256[] memory ids = _litIds();
        uint256 totalPaid;
        for (uint256 i; i < ids.length; ++i) {
            uint256 pend = pulse.pending(ids[i]);
            address o = IERC721(COLLECTION).ownerOf(ids[i]);
            uint256 balBefore = o.balance;
            uint256 stockBefore = _stockBalance(o);
            g = gasleft();
            pulse.claim(ids[i]);
            uint256 used = g - gasleft();
            assertTrue(o.balance > balBefore || _stockBalance(o) > stockBefore, "owner received ETH or stock tokens");
            totalPaid += pend;
            console.log("claim token", ids[i]);
            console.log("  gas", used);
            console.log("  pending wei", pend);
            console.log("  owner ETH delta (0 if swapped to stock)", o.balance - balBefore);
            assertEq(pulse.pending(ids[i]), 0);
        }
        assertEq(hopper.reserved(), 0, "all epochs claimed => nothing reserved");
        assertLe(totalPaid, hopperBeforePulse);
        assertGe(totalPaid + ids.length, hopperBeforePulse - ids.length, "pulse distributed the whole Hopper (dust only left)");
    }

    /// @dev Price impact + sandwich exposure of the 250 TERM swap on the real pool.
    function test_fork_swap250_priceImpact_and_sandwich() public {
        vm.startPrank(OWNER);
        (hopper, pulse, redirect) = PulseV2Migration.step1_deploy(c);
        vm.stopPrank();
        ITermSwapRouter real = ITermSwapRouter(REAL_ROUTER);

        // Baseline: 250 TERM -> ETH
        uint256 e0 = _sellTerm(real, 250 ether);
        console.log("250 TERM -> ETH wei (baseline)", e0);
        uint256 e1 = _sellTerm(real, 250 ether);
        console.log("250 TERM -> ETH wei (second, after own impact)", e1);
        // Marginal price per TERM after 250 sold twice. impact ~ (e0 - e1) / e0
        console.log("impact of selling 250 TERM (bps of output)", ((e0 - e1) * 10_000) / e0);

        // Sandwich: attacker dumps TERM first, victim sells 250 via the redirect router (as Ignite), attacker buys back.
        uint256 snap = vm.snapshotState();
        uint256 cleanOut = _sellViaRedirect(250 ether);
        vm.revertToState(snap);

        uint256 attackerTerm = 200_000 ether;
        vm.startPrank(IGNITE);
        term.transfer(address(this), attackerTerm);
        vm.stopPrank();
        uint256 atkEth = _sellTermBig(real, attackerTerm);
        console.log("attacker front-run: sold TERM for ETH wei", atkEth);
        uint256 sandwichedOut = _sellViaRedirect(250 ether);
        console.log("victim swap output clean vs sandwiched (wei)", cleanOut, sandwichedOut);
        if (cleanOut > sandwichedOut) console.log("MEV loss on 250 TERM swap (wei)", cleanOut - sandwichedOut);
        // Attacker back-run: buy TERM back with the ETH from the front-run. Net result in TERM:
        uint256 termBack = real.swapExactETHForToken{value: atkEth}(TERM, address(this));
        console.log("attacker TERM sold / bought back", attackerTerm, termBack);
        if (termBack < attackerTerm) console.log("attacker net TERM loss", attackerTerm - termBack);
        assertLt(termBack, attackerTerm, "sandwich is not profitable for the attacker");
    }

    // ---------------------------------------------------------------- helpers

    function _firstDormantToken() internal view returns (uint256) {
        for (uint256 t = 1; t <= 4444; ++t) {
            if (!ignite.isLit(t) && !ignite.allotmentConsumed(t)) return t;
        }
        revert("no dormant token");
    }

    function _stockBalance(address o) internal view returns (uint256 s) {
        for (uint8 i = 1; i < 8; ++i) {
            address t = pulse.stockPool(i);
            if (t != address(0)) s += IERC20(t).balanceOf(o);
        }
    }

    function _sellTerm(ITermSwapRouter r, uint256 amt) internal returns (uint256 out) {
        vm.prank(IGNITE);
        term.transfer(address(this), amt);
        term.approve(address(r), amt);
        uint256 b = address(this).balance;
        r.swapExactTokenForETH(TERM, amt, address(this));
        out = address(this).balance - b;
    }

    function _sellTermBig(ITermSwapRouter r, uint256 amt) internal returns (uint256 out) {
        term.approve(address(r), amt);
        uint256 b = address(this).balance;
        r.swapExactTokenForETH(TERM, amt, address(this));
        out = address(this).balance - b;
    }

    /// @dev Mimic Ignite: tokens come from Ignite, the swap goes through the redirect router (soft-fail for Ignite).
    function _sellViaRedirect(uint256 amt) internal returns (uint256 out) {
        // Redirect router was deployed with Ignite as soft-fail caller; call as Ignite.
        uint256 b = address(hopper).balance;
        vm.startPrank(IGNITE);
        term.approve(address(redirect), amt);
        redirect.swapExactTokenForETH(TERM, amt, V1_HOPPER);
        vm.stopPrank();
        out = address(hopper).balance - b;
    }

    receive() external payable {}
}
