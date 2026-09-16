// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title DialMath
/// @notice Pure Dial assignment: shell class from tokenId, then 1–4 unique
/// stock slots with equal weights. Salts are fixed so hub clients can preview
/// the same picks as the chain without a picker.
///
/// Shell class is **not** a replay of `art/generator` Python `random` DNA.
/// That RNG is sequential + reject-until-unique across every trait, so it
/// cannot be mirrored in Solidity. On-chain Dial uses the **same rarity
/// weights** as `art/schema/traits.json` `shell_class` (ALPHA 60 / BETA 25 /
/// DELTA 10 / OMEGA 5). Owner may override per token from generative metadata
/// before Ignite so the PFP class and Dial count match. See `docs/DIAL.md`.
library DialMath {
    bytes32 internal constant SHELL_CLASS_SALT = keccak256("TERMINAL_PETS.SHELL_CLASS.v1");
    bytes32 internal constant DIAL_SALT = keccak256("TERMINAL_PETS.DIAL.v1");

    uint16 internal constant BPS = 10_000;
    uint8 internal constant POOL_SIZE = 8;

    uint8 internal constant ALPHA = 1;
    uint8 internal constant BETA = 2;
    uint8 internal constant DELTA = 3;
    uint8 internal constant OMEGA = 4;

    uint8 internal constant ALPHA_WEIGHT = 60;
    uint8 internal constant BETA_WEIGHT = 25;
    uint8 internal constant DELTA_WEIGHT = 10;
    uint8 internal constant OMEGA_WEIGHT = 5;

    error BadShellClass();
    error BadLegCount();

    /// @notice ALPHA Common → 1, BETA Rare → 2, DELTA Epic → 3, OMEGA Legendary → 4.
    function legCount(uint8 shellClass) internal pure returns (uint8) {
        if (shellClass == ALPHA) return 1;
        if (shellClass == BETA) return 2;
        if (shellClass == DELTA) return 3;
        if (shellClass == OMEGA) return 4;
        revert BadShellClass();
    }

    /// @notice Weighted roll 0–99: [0,60) ALPHA, [60,85) BETA, [85,95) DELTA, [95,100) OMEGA.
    function deriveShellClass(uint256 tokenId) internal pure returns (uint8) {
        uint256 roll = uint256(keccak256(abi.encodePacked(SHELL_CLASS_SALT, tokenId))) % 100;
        if (roll < ALPHA_WEIGHT) return ALPHA;
        if (roll < ALPHA_WEIGHT + BETA_WEIGHT) return BETA;
        if (roll < ALPHA_WEIGHT + BETA_WEIGHT + DELTA_WEIGHT) return DELTA;
        return OMEGA;
    }

    /// @notice `n` unique slots in `[0, POOL_SIZE)` drawn without replacement.
    function pickSlots(uint256 tokenId, uint8 n) internal pure returns (uint8[4] memory picked) {
        if (n == 0 || n > 4) revert BadLegCount();
        uint8[8] memory bag;
        for (uint8 i; i < POOL_SIZE; ++i) {
            bag[i] = i;
        }
        bytes32 seed = keccak256(abi.encodePacked(DIAL_SALT, tokenId));
        uint8 remaining = POOL_SIZE;
        for (uint8 k; k < n; ++k) {
            uint256 draw = uint256(keccak256(abi.encodePacked(seed, k))) % remaining;
            picked[k] = bag[draw];
            bag[draw] = bag[remaining - 1];
            unchecked {
                remaining -= 1;
            }
        }
    }

    /// @notice Equal bps across `n` legs; remainder on the last so the sum is 10_000.
    function splitWeights(uint8 n) internal pure returns (uint16[4] memory weights) {
        if (n == 0 || n > 4) revert BadLegCount();
        uint16 base = uint16(uint256(BPS) / n);
        uint16 rem = uint16(uint256(BPS) - uint256(base) * n);
        for (uint8 i; i < n; ++i) {
            weights[i] = base;
        }
        weights[n - 1] += rem;
    }
}
