// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HopperV2} from "../src/HopperV2.sol";
import {HopperRedirectRouter} from "../src/HopperRedirectRouter.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {PulseDistributorV2} from "../src/PulseDistributorV2.sol";
import {IgniteModule} from "../src/IgniteModule.sol";
import {TermMarket} from "../src/TermMarket.sol";

/// @notice Inputs for the V1 -> V2 Pulse migration (Option B). All addresses are the LIVE contracts.
struct PulseV2Config {
    address deployer; // the account that signs (must own Ignite and TermMarket); transient owner of new contracts
    address owner; // final owner of Hopper V2 + Pulse V2 (use a multisig on mainnet)
    address v1Hopper; // 0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2
    address v1Pulse; // 0x7326F7D277610288FBeA373712c89E47AF9AC61E
    address collection; // 0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166
    address ignite; // 0x29e8dB2073583720C3CBf741d278d942B65cb92B
    address termMarket; // 0x78f2c0577321053722Daa1f5eE31E5071a7D9F30
    uint256 maxSupply; // 4444
}

/// @dev Option B migration, one internal function per on-chain step, so the script can broadcast each
/// step on its own (owner approval per step) and a test can run them under `vm.prank(owner)`.
/// V1 contracts and their funds are never touched. Ignite is never enabled except by `step7_enableIgnite`.
library PulseV2Migration {
    uint256 internal constant IGNITE_FEE_TERM = 1_000 ether; // 1e21, unchanged by this migration

    error SwapRouterUnset();
    error MarketRouterMismatch(address igniteRouter, address marketRouter);
    error Check(string what);

    /// @notice STEP 1. Deploys HopperV2, PulseDistributorV2, HopperRedirectRouter. Copies V1 config and
    /// shell overrides, locks the HopperV2 distributor, hands ownership to `c.owner`.
    /// Changes NO live contract state: Ignite, TermMarket, V1 Hopper/Pulse are untouched.
    function step1_deploy(PulseV2Config memory c)
        internal
        returns (HopperV2 hopper, PulseDistributorV2 pulse, HopperRedirectRouter redirect)
    {
        // Fail fast. Wrap the DEX adapter Ignite and TermMarket both use today
        // (live Ignite router: 0xDe6dF0527608A20121ecD6aA009C198Ca1cba28F).
        address inner = address(IgniteModule(c.ignite).swapRouter());
        if (inner == address(0)) revert SwapRouterUnset();
        address marketRouter = address(TermMarket(payable(c.termMarket)).swapRouter());
        if (marketRouter != address(0) && marketRouter != inner) revert MarketRouterMismatch(inner, marketRouter);

        PulseDistributor v1 = PulseDistributor(payable(c.v1Pulse));

        hopper = new HopperV2(c.deployer, 0, c.v1Hopper); // payoutLock 0 => 7 days after the existing reveal
        // Same ladder as V1: copy V1's actual immutables (0.1 / 0.5 / 0.1).
        pulse = new PulseDistributorV2(
            address(hopper),
            c.collection,
            c.ignite,
            c.maxSupply,
            c.deployer, // deployer owns it during setup, ownership handed to c.owner at the end
            v1.bootstrapStart(),
            v1.cycleStart(),
            v1.ladderStep()
        );

        address[8] memory pool;
        for (uint8 i; i < 8; ++i) {
            pool[i] = v1.stockPool(i);
        }
        pulse.setStockTokens(pool);
        if (v1.term() != address(0)) pulse.setTerm(v1.term());
        if (address(v1.router()) != address(0)) pulse.setRouter(address(v1.router()));
        if (address(v1.tbaRegistry()) != address(0)) {
            pulse.setTbaConfig(address(v1.tbaRegistry()), v1.tbaImplementation(), v1.tbaSalt());
            if (v1.deliverToTba()) pulse.setDeliverToTba(true);
        }
        hopper.lockDistributor(address(pulse));
        copyShellOverrides(c, pulse, 1, c.maxSupply); // must precede the ownership hand-over

        redirect = new HopperRedirectRouter(inner, c.v1Hopper, address(hopper));

        if (c.owner != c.deployer) {
            pulse.transferOwnership(c.owner);
            hopper.transferOwnership(c.owner);
        }
    }

    /// @notice STEP 2 (any wallet; only touches PulseV2). Register every currently-Lit pet with V2.
    /// Must complete before PulseV2 can pulse (`registeredCount == ignite.litCount()`).
    function step2_registerLit(PulseV2Config memory c, PulseDistributorV2 pulse) internal returns (uint256) {
        return registerAllLit(c, pulse);
    }

    /// @notice STEP 3 (Ignite owner). Ignite.setPulseDistributor(PulseV2): new Ignites register with V2.
    function step3_pointDialHook(PulseV2Config memory c, PulseDistributorV2 pulse) internal {
        IgniteModule(c.ignite).setPulseDistributor(address(pulse));
    }

    /// @notice STEP 4 (Ignite owner). Ignite.setSwapRouter(redirect): the 25% `$TERM` slice, swapped to ETH,
    /// lands in HopperV2. The ETH->TERM buy-and-burn path passes through to the same DEX adapter.
    function step4_igniteRouter(PulseV2Config memory c, HopperRedirectRouter redirect) internal {
        IgniteModule(c.ignite).setSwapRouter(address(redirect));
    }

    /// @notice STEP 5 (TermMarket owner). TermMarket.setSwapRouter(redirect): the `$TERM`-side skim,
    /// swapped to ETH, lands in HopperV2. Existing bps unchanged.
    function step5_marketRouter(PulseV2Config memory c, HopperRedirectRouter redirect) internal {
        TermMarket(payable(c.termMarket)).setSwapRouter(address(redirect));
    }

    /// @notice STEP 6 (Ignite owner). Ignite.setIgniteFeeEth(0). `igniteFee` stays 1000 `$TERM`, bps unchanged.
    /// After this, `ignite()` takes msg.value == 0: the Ignite ETH half (hardwired to the V1 Hopper) is gone.
    function step6_zeroIgniteEthFee(PulseV2Config memory c) internal {
        IgniteModule(c.ignite).setIgniteFeeEth(0);
    }

    /// @notice STEP 7 (Ignite owner). SEPARATE FINAL DECISION. Ignite.setIgniteEnabled(true).
    /// Run `verify` first; it must pass.
    function step7_enableIgnite(PulseV2Config memory c) internal {
        IgniteModule(c.ignite).setIgniteEnabled(true);
    }

    /// @notice Read-only post-condition check for steps 1-6. Reverts with `Check(what)` on the first failure.
    /// `expectIgniteEnabled` is false before step 7 and true after.
    function verify(
        PulseV2Config memory c,
        HopperV2 hopper,
        PulseDistributorV2 pulse,
        HopperRedirectRouter redirect,
        bool expectIgniteEnabled
    ) internal view {
        IgniteModule ig = IgniteModule(c.ignite);
        TermMarket tm = TermMarket(payable(c.termMarket));
        if (address(ig.pulseDistributor()) != address(pulse)) revert Check("ignite dial hook != PulseV2");
        if (address(ig.swapRouter()) != address(redirect)) revert Check("ignite swapRouter != redirect");
        if (address(tm.swapRouter()) != address(redirect)) revert Check("market swapRouter != redirect");
        if (redirect.hopperV2() != address(hopper) || redirect.legacyHopper() != c.v1Hopper) revert Check("redirect dests");
        if (hopper.distributor() != address(pulse) || !hopper.distributorLocked()) revert Check("hopperV2 distributor");
        if (ig.igniteFeeEth() != 0) revert Check("igniteFeeEth != 0");
        if (ig.igniteFee() != IGNITE_FEE_TERM) revert Check("igniteFee != 1000 TERM");
        if (ig.pendingHopperTerm() != 0) revert Check("pendingHopperTerm != 0");
        if (pulse.registeredCount() != ig.litCount()) revert Check("registeredCount != litCount");
        if (hopper.paused()) revert Check("hopperV2 paused");
        if (ig.igniteEnabled() != expectIgniteEnabled) revert Check("igniteEnabled unexpected");
    }

    /// @notice Copy V1 `shellClassOverride` for ids in `[from, to]` (read-only on V1).
    function copyShellOverrides(PulseV2Config memory c, PulseDistributorV2 pulse, uint256 from, uint256 to) internal {
        PulseDistributor v1 = PulseDistributor(payable(c.v1Pulse));
        uint256 n;
        uint256[] memory ids = new uint256[](to - from + 1);
        uint8[] memory cls = new uint8[](to - from + 1);
        for (uint256 id = from; id <= to; ++id) {
            uint8 o = v1.shellClassOverride(id);
            if (o != 0) {
                ids[n] = id;
                cls[n] = o;
                ++n;
            }
        }
        if (n == 0) return;
        assembly {
            mstore(ids, n)
            mstore(cls, n)
        }
        pulse.setShellClassOverrides(ids, cls);
    }

    /// @notice Step 3 (any wallet). Register every currently-Lit pet with V2 by scanning Ignite's bitmap.
    /// MUST complete before Pulse V2 can pulse (`registeredCount == ignite.litCount()`).
    function registerAllLit(PulseV2Config memory c, PulseDistributorV2 pulse) internal returns (uint256 registered) {
        IgniteModule ig = IgniteModule(c.ignite);
        uint256 lit = ig.litCount();
        uint256[] memory ids = new uint256[](lit);
        uint256 words = (c.maxSupply >> 8) + 1;
        for (uint256 w; w < words && registered < lit; ++w) {
            uint256 bits = ig.litBitmap(w);
            if (bits == 0) continue;
            for (uint256 b; b < 256; ++b) {
                if ((bits & (1 << b)) == 0) continue;
                uint256 id = (w << 8) | b;
                if (id == 0 || id > c.maxSupply) continue;
                ids[registered++] = id;
            }
        }
        // One tx per 100 ids (measured ~5.7M gas per 100 in test; far under 15M).
        for (uint256 i; i < registered; i += 100) {
            uint256 len = registered - i < 100 ? registered - i : 100;
            uint256[] memory chunk = new uint256[](len);
            for (uint256 j; j < len; ++j) {
                chunk[j] = ids[i + j];
            }
            pulse.registerLit(chunk);
        }
    }
}

/// @notice Pulse V2 migration, Option B. **NOT EXECUTED. Do not broadcast any step until the owner approves it.**
///
/// Every step is its own entrypoint and its own transaction(s), so each can be approved on its own:
///   1 deploy      (new contracts only; no live state changes)
///   2 register    (new PulseV2 only)
///   3 dialHook    Ignite.setPulseDistributor(PulseV2)
///   4 igniteRouter Ignite.setSwapRouter(redirect)
///   5 marketRouter TermMarket.setSwapRouter(redirect)
///   6 zeroEthFee  Ignite.setIgniteFeeEth(0)
///   (verify, read-only)
///   7 enableIgnite Ignite.setIgniteEnabled(true)   <- separate final decision
///
/// Env (all steps): PRIVATE_KEY, V1_HOPPER, V1_PULSE, COLLECTION, IGNITE, TERM_MARKET; optional MAX_SUPPLY (4444),
///                  OWNER (final owner of V2 contracts; default signer). Steps 2-7 also take PULSE_V2, HOPPER_V2,
///                  REDIRECT (addresses printed by step 1) as env vars.
///
/// Simulate everything with no broadcast (steps 1-6, never 7):
///   forge script script/MigratePulseV2.s.sol --sig "dryRun()" --rpc-url robinhood
/// Broadcast one step (owner approval required), e.g.:
///   forge script script/MigratePulseV2.s.sol --sig "step1Deploy()" --rpc-url robinhood --broadcast
contract MigratePulseV2 is Script {
    function _cfg(address deployer) internal view returns (PulseV2Config memory c) {
        c.deployer = deployer;
        c.owner = vm.envOr("OWNER", deployer);
        c.v1Hopper = vm.envAddress("V1_HOPPER");
        c.v1Pulse = vm.envAddress("V1_PULSE");
        c.collection = vm.envAddress("COLLECTION");
        c.ignite = vm.envAddress("IGNITE");
        c.termMarket = vm.envAddress("TERM_MARKET");
        c.maxSupply = vm.envOr("MAX_SUPPLY", uint256(4444));
    }

    function _signerCfg() internal view returns (uint256 pk, PulseV2Config memory c) {
        pk = vm.envUint("PRIVATE_KEY");
        c = _cfg(vm.addr(pk));
    }

    function _v2() internal view returns (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) {
        h = HopperV2(payable(vm.envAddress("HOPPER_V2")));
        p = PulseDistributorV2(payable(vm.envAddress("PULSE_V2")));
        r = HopperRedirectRouter(payable(vm.envAddress("REDIRECT")));
    }

    /// @notice Simulation only (prank, no broadcast): steps 1-6 then verify. Never runs step 7.
    function dryRun() external {
        address igniteOwner = IgniteModule(vm.envAddress("IGNITE")).owner();
        PulseV2Config memory c = _cfg(igniteOwner);
        vm.startPrank(igniteOwner);
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = PulseV2Migration.step1_deploy(c);
        PulseV2Migration.step2_registerLit(c, p);
        PulseV2Migration.step3_pointDialHook(c, p);
        PulseV2Migration.step4_igniteRouter(c, r);
        PulseV2Migration.step5_marketRouter(c, r);
        PulseV2Migration.step6_zeroIgniteEthFee(c);
        vm.stopPrank();
        PulseV2Migration.verify(c, h, p, r, false);
        console.log("DRY RUN OK. HopperV2", address(h));
        console.log("PulseDistributorV2", address(p));
        console.log("HopperRedirectRouter", address(r));
    }

    function step1Deploy() external {
        (uint256 pk, PulseV2Config memory c) = _signerCfg();
        vm.startBroadcast(pk);
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = PulseV2Migration.step1_deploy(c);
        vm.stopBroadcast();
        console.log("HOPPER_V2", address(h));
        console.log("PULSE_V2", address(p));
        console.log("REDIRECT", address(r));
    }

    function step2Register() external {
        (uint256 pk, PulseV2Config memory c) = _signerCfg();
        (, PulseDistributorV2 p,) = _v2();
        vm.startBroadcast(pk);
        uint256 n = PulseV2Migration.step2_registerLit(c, p);
        vm.stopBroadcast();
        console.log("registered", n);
    }

    function step3DialHook() external {
        (uint256 pk, PulseV2Config memory c) = _signerCfg();
        (, PulseDistributorV2 p,) = _v2();
        vm.startBroadcast(pk);
        PulseV2Migration.step3_pointDialHook(c, p);
        vm.stopBroadcast();
    }

    function step4IgniteRouter() external {
        (uint256 pk, PulseV2Config memory c) = _signerCfg();
        (,, HopperRedirectRouter r) = _v2();
        vm.startBroadcast(pk);
        PulseV2Migration.step4_igniteRouter(c, r);
        vm.stopBroadcast();
    }

    function step5MarketRouter() external {
        (uint256 pk, PulseV2Config memory c) = _signerCfg();
        (,, HopperRedirectRouter r) = _v2();
        vm.startBroadcast(pk);
        PulseV2Migration.step5_marketRouter(c, r);
        vm.stopBroadcast();
    }

    function step6ZeroEthFee() external {
        (uint256 pk, PulseV2Config memory c) = _signerCfg();
        vm.startBroadcast(pk);
        PulseV2Migration.step6_zeroIgniteEthFee(c);
        vm.stopBroadcast();
    }

    /// @notice Read-only. Pass `true` after step 7. Run before step 7 (with false); it must pass.
    function verifyState(bool expectIgniteEnabled) external view {
        PulseV2Config memory c = _cfg(address(0));
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = _v2();
        PulseV2Migration.verify(c, h, p, r, expectIgniteEnabled);
    }

    /// @notice Final, separate decision. Not part of `dryRun`.
    function step7EnableIgnite() external {
        (uint256 pk, PulseV2Config memory c) = _signerCfg();
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = _v2();
        PulseV2Migration.verify(c, h, p, r, false); // refuse to enable unless steps 1-6 hold
        vm.startBroadcast(pk);
        PulseV2Migration.step7_enableIgnite(c);
        vm.stopBroadcast();
    }
}
