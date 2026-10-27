// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {HopperV2} from "../src/HopperV2.sol";
import {HopperRedirectRouter} from "../src/HopperRedirectRouter.sol";
import {PulseDistributor} from "../src/PulseDistributor.sol";
import {PulseDistributorV2} from "../src/PulseDistributorV2.sol";
import {IgniteModule} from "../src/IgniteModule.sol";

/// @notice Inputs for the V1 -> V2 Pulse migration. All addresses are the LIVE contracts.
struct PulseV2Config {
    address deployer; // the account that signs (must own Ignite); transient owner of the new contracts
    address owner; // owner of Hopper V2 + Pulse V2 (use a multisig on mainnet)
    address v1Hopper; // 0x8Cd9A113dc8147D5163486e81D3bA64E2137dBf2
    address v1Pulse; // 0x7326F7D277610288FBeA373712c89E47AF9AC61E
    address collection; // 0x85e3f98b76b0a6c9166BA7aaB05BEc4ef17B7166
    address ignite; // 0x29e8dB2073583720C3CBf741d278d942B65cb92B
    uint256 maxSupply; // 4444
    bool redirectTermSlices; // deploy HopperRedirectRouter and point Ignite's swap router at it
}

/// @dev Migration steps as internal functions so a test can run them under `vm.prank(owner)` and the
/// script can run them under `vm.startBroadcast`. Nothing here moves holder funds; V1 is untouched.
library PulseV2Migration {
    /// @notice Step 1 (owner key). Deploys V2, copies V1 config, wires Ignite's Dial hook to V2.
    /// Does NOT touch Ignite's enabled flag, fee bps, or any V1 contract's funds.
    function deployAndWire(PulseV2Config memory c)
        internal
        returns (HopperV2 hopper, PulseDistributorV2 pulse, HopperRedirectRouter redirect)
    {
        PulseDistributor v1 = PulseDistributor(payable(c.v1Pulse));

        hopper = new HopperV2(c.deployer, 0, c.v1Hopper); // payoutLock 0 => 7 days after the existing reveal
        // Same ladder as V1: 0 => CollectionConfig defaults (0.1 / 0.5 / 0.1). Copy V1's actual immutables.
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
        IgniteModule(c.ignite).setPulseDistributor(address(pulse));

        if (c.redirectTermSlices) {
            address inner = address(IgniteModule(c.ignite).swapRouter());
            if (inner != address(0)) {
                redirect = new HopperRedirectRouter(inner, c.v1Hopper, address(hopper));
                IgniteModule(c.ignite).setSwapRouter(address(redirect));
            }
        }

        copyShellOverrides(c, pulse, 1, c.maxSupply); // must precede the ownership hand-over

        if (c.owner != c.deployer) {
            pulse.transferOwnership(c.owner);
            hopper.transferOwnership(c.owner);
        }
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

/// @notice Pulse V2 migration. **NOT EXECUTED. Do not broadcast until the owner says go.**
///
/// Required env:  PRIVATE_KEY (must be the IgniteModule owner; it deploys V2 and hands ownership to OWNER),
///                V1_HOPPER, V1_PULSE, COLLECTION, IGNITE
/// Optional env:  MAX_SUPPLY (4444), OWNER (final owner; default deployer), REDIRECT_TERM_SLICES (false)
///
/// Dry run (no broadcast, simulates against the RPC):
///   forge script script/MigratePulseV2.s.sol --sig "dryRun()" --rpc-url robinhood
/// Broadcast (owner approval required):
///   forge script script/MigratePulseV2.s.sol --sig "deploy()" --rpc-url robinhood --broadcast
///   forge script script/MigratePulseV2.s.sol --sig "register(address)" <PULSE_V2> --rpc-url robinhood --broadcast
///
/// Before `deploy()`: Ignite should remain PAUSED. After `register()` and the checks in
/// docs/PULSE_V2_DESIGN.md, a separate owner decision re-enables Ignite.
contract MigratePulseV2 is Script {
    function _cfg(address deployer) internal view returns (PulseV2Config memory c) {
        c.deployer = deployer;
        c.owner = vm.envOr("OWNER", deployer);
        c.v1Hopper = vm.envAddress("V1_HOPPER");
        c.v1Pulse = vm.envAddress("V1_PULSE");
        c.collection = vm.envAddress("COLLECTION");
        c.ignite = vm.envAddress("IGNITE");
        c.maxSupply = vm.envOr("MAX_SUPPLY", uint256(4444));
        c.redirectTermSlices = vm.envOr("REDIRECT_TERM_SLICES", false);
    }

    /// @notice Simulation only: no broadcast, no key needed beyond `--sender`.
    function dryRun() external {
        address igniteOwner = IgniteModule(vm.envAddress("IGNITE")).owner();
        PulseV2Config memory c = _cfg(igniteOwner);
        vm.startPrank(igniteOwner);
        (HopperV2 h, PulseDistributorV2 p,) = PulseV2Migration.deployAndWire(c);
        vm.stopPrank();
        console.log("DRY RUN HopperV2", address(h));
        console.log("DRY RUN PulseDistributorV2", address(p));
    }

    function deploy() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        PulseV2Config memory c = _cfg(vm.addr(pk));
        vm.startBroadcast(pk);
        (HopperV2 h, PulseDistributorV2 p, HopperRedirectRouter r) = PulseV2Migration.deployAndWire(c);
        vm.stopBroadcast();
        console.log("HopperV2", address(h));
        console.log("PulseDistributorV2", address(p));
        console.log("HopperRedirectRouter", address(r));
        console.log("NEXT: register(PulseV2) so registeredCount == ignite.litCount(); Ignite stays paused.");
    }

    function register(address pulseV2) external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        PulseV2Config memory c = _cfg(vm.addr(pk));
        vm.startBroadcast(pk);
        uint256 n = PulseV2Migration.registerAllLit(c, PulseDistributorV2(payable(pulseV2)));
        vm.stopBroadcast();
        console.log("registered", n);
    }
}
