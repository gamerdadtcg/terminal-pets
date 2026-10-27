// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {HopperV2} from "../src/HopperV2.sol";
import {PulseDistributorV2} from "../src/PulseDistributorV2.sol";
import {MockStockToken} from "./mocks/MockPulseRouter.sol";
import {MockHeavyRouter} from "./mocks/MockV2Routers.sol";

contract GasIgnite {
    uint256 public litCount;
    mapping(uint256 => uint256) internal _w;

    function light(uint256 n) external {
        for (uint256 t = 1; t <= n; ++t) {
            _w[t >> 8] |= 1 << (t & 0xff);
        }
        litCount = n;
    }

    function isLit(uint256 t) external view returns (bool) {
        return t != 0 && t <= litCount;
    }

    function litBitmap(uint256 w) external view returns (uint256) {
        return _w[w];
    }
}

contract GasCollection {
    /// @dev Every pet has its own fresh, code-less owner (worst case for the ETH fallback path).
    function ownerOf(uint256 id) external pure returns (address) {
        return address(uint160(0x100000 + id));
    }
}

contract GasRevealClock {
    function revealedAt() external pure returns (uint64) {
        return 1;
    }
}

/// @notice Gas at the full 4,444 Lit pets. Every transaction a keeper/holder must send is asserted
/// under BATCH_LIMIT (15M gas); V1 `pulse()` at this size measured ~418M (impossible under a ~32M cap).
contract PulseV2GasTest is Test {
    uint256 internal constant N = 4444;
    uint256 internal constant BATCH_LIMIT = 15_000_000;

    GasIgnite internal ig;
    HopperV2 internal hopper;
    PulseDistributorV2 internal pulse;
    MockHeavyRouter internal router;
    MockStockToken internal termTok;
    MockStockToken[8] internal stocks;

    function setUp() public {
        vm.warp(100 days);
        ig = new GasIgnite();
        hopper = new HopperV2(address(this), 0, address(new GasRevealClock()));
        pulse = new PulseDistributorV2(address(hopper), address(new GasCollection()), address(ig), N, address(this), 0, 0, 0);
        hopper.lockDistributor(address(pulse));
        address[8] memory pool;
        for (uint8 i = 1; i < 8; ++i) {
            stocks[i] = new MockStockToken("S", "S");
            pool[i] = address(stocks[i]);
        }
        pulse.setStockTokens(pool);
        termTok = new MockStockToken("T", "T");
        pulse.setTerm(address(termTok));
        router = new MockHeavyRouter();
        pulse.setRouter(address(router));
        ig.light(N);
    }

    function _registerAll(uint256 batch) internal returns (uint256 maxGas) {
        for (uint256 start = 1; start <= N; start += batch) {
            uint256 end = start + batch - 1;
            if (end > N) end = N;
            uint256[] memory ids = new uint256[](end - start + 1);
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = start + i;
            }
            uint256 g = gasleft();
            pulse.registerLit(ids);
            g -= gasleft();
            if (g > maxGas) maxGas = g;
        }
    }

    function _pinOmega() internal {
        // Worst case for claims: every pet has 4 legs.
        for (uint256 start = 1; start <= N; start += 500) {
            uint256 end = start + 499 > N ? N : start + 499;
            uint256[] memory ids = new uint256[](end - start + 1);
            uint8[] memory cls = new uint8[](ids.length);
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = start + i;
                cls[i] = 4;
            }
            pulse.setShellClassOverrides(ids, cls);
        }
    }

    function _fundAndPulse() internal returns (uint256 g) {
        uint256 need = pulse.pulseThreshold();
        vm.deal(address(this), need);
        (bool ok,) = address(hopper).call{value: need}("");
        assertTrue(ok);
        g = gasleft();
        pulse.pulse();
        g -= gasleft();
    }

    function test_gas_registration_batchOf100_under15M() public {
        uint256 maxGas = _registerAll(100);
        console.log("registerLit batch=100 max gas:", maxGas);
        console.log("registerLit per pet:", maxGas / 100);
        assertLt(maxGas, BATCH_LIMIT);
        assertEq(pulse.registeredCount(), N);
    }

    function test_gas_pulse_at4444_isConstant() public {
        _registerAll(100);
        uint256 g0 = _fundAndPulse();
        console.log("pulse() with 4444 Lit, first epoch gas:", g0);
        assertLt(g0, 1_000_000);
        uint256 gMax;
        for (uint256 i; i < 9; ++i) {
            uint256 g = _fundAndPulse();
            if (g > gMax) gMax = g;
        }
        console.log("pulse() with 4444 Lit, max over next 9 epochs:", gMax);
        assertLt(gMax, 1_000_000);
        assertEq(pulse.epochCount(), 10);
    }

    function test_gas_claimBatches_worstCaseFourLegs_under15M() public {
        _pinOmega();
        _registerAll(100);
        for (uint256 i; i < 3; ++i) {
            _fundAndPulse();
        }
        uint256 batch = 25;
        uint256 maxGas;
        uint256 total;
        uint256 batches;
        for (uint256 start = 1; start <= N; start += batch) {
            uint256 end = start + batch - 1 > N ? N : start + batch - 1;
            uint256[] memory ids = new uint256[](end - start + 1);
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = start + i;
            }
            uint256 g = gasleft();
            pulse.claimMany(ids);
            g -= gasleft();
            total += g;
            batches++;
            if (g > maxGas) maxGas = g;
            assertLt(g, BATCH_LIMIT, "claim batch over limit");
        }
        console.log("claimMany batch=25, 4 legs/pet (heavy ~100k swap), 3 epochs: max batch gas:", maxGas);
        console.log("claimMany per pet (4 legs):", total / N);
        console.log("claimMany batches to pay all 4444:", batches);
        assertEq(hopper.reserved(), 0, "every reserved wei paid out");
    }

    function test_gas_claimBatches_mixedDials_batchOf60_under15M() public {
        _registerAll(100);
        for (uint256 i; i < 3; ++i) {
            _fundAndPulse();
        }
        uint256 batch = 60;
        uint256 maxGas;
        uint256 total;
        for (uint256 start = 1; start <= N; start += batch) {
            uint256 end = start + batch - 1 > N ? N : start + batch - 1;
            uint256[] memory ids = new uint256[](end - start + 1);
            for (uint256 i; i < ids.length; ++i) {
                ids[i] = start + i;
            }
            uint256 g = gasleft();
            pulse.claimMany(ids);
            g -= gasleft();
            total += g;
            if (g > maxGas) maxGas = g;
            assertLt(g, BATCH_LIMIT, "claim batch over limit");
        }
        console.log("claimMany batch=60, natural dial mix: max batch gas:", maxGas);
        console.log("claimMany per pet (natural mix):", total / N);
        assertEq(hopper.reserved(), 0);
    }

    function test_gas_claimManyBounded_respectsGasFloor() public {
        _pinOmega();
        _registerAll(100);
        _fundAndPulse();
        uint256[] memory ids = new uint256[](200);
        for (uint256 i; i < ids.length; ++i) {
            ids[i] = i + 1;
        }
        // Give the call ~12M and ask it to stop with 2M left.
        uint256 g = gasleft();
        uint256 done = pulse.claimManyBounded{gas: 12_000_000}(ids, 2_000_000);
        g -= gasleft();
        console.log("claimManyBounded processed:", done);
        console.log("claimManyBounded gas used:", g);
        assertGt(done, 0);
        assertLt(done, 200);
        assertLt(g, 12_000_000);
        // Resume from where it stopped.
        uint256[] memory rest = new uint256[](200 - done);
        for (uint256 i; i < rest.length; ++i) {
            rest[i] = ids[done + i];
        }
        uint256 g2 = gasleft();
        uint256 done2 = pulse.claimManyBounded{gas: 14_900_000}(rest, 1_000_000);
        g2 -= gasleft();
        assertLt(g2, BATCH_LIMIT);
        assertGt(done2, 0);
    }

    function test_gas_singlePetClaim_isFlatInEpochs() public {
        _registerAll(100);
        pulse.setRouter(address(0)); // isolate the epoch loop cost: plain ETH
        _fundAndPulse();
        uint256 g1 = gasleft();
        pulse.claim(1);
        g1 -= gasleft();

        for (uint256 i; i < 200; ++i) {
            _fundAndPulse();
        }
        uint256 g200 = gasleft();
        pulse.claim(2); // 201 unpaid epochs
        g200 -= gasleft();
        console.log("claim, 1 unpaid epoch:", g1);
        console.log("claim, 201 unpaid epochs:", g200);
        // V1 measured ~156k for 1 epoch and ~9.8M for 200 unpaid epochs.
        assertLt(g200, g1 + 20_000);
        assertLt(g200, 500_000);
    }
}
