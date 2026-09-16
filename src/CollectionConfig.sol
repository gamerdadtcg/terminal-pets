// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CollectionConfig
/// @notice Single place for collection, `$TERM` Ignite, TermMarket skim, Hopper, and Pulse defaults.
/// Deploy scripts read these; constructor arguments can still override them.
library CollectionConfig {
    string internal constant NAME = "Terminal Pets";
    string internal constant SYMBOL = "TERM";
    uint256 internal constant MAX_SUPPLY = 4444;
    uint256 internal constant TEAM_RESERVE = 200;
    uint256 internal constant PUBLIC_SUPPLY = 4244; // MAX_SUPPLY - TEAM_RESERVE

    uint256 internal constant MINT_PRICE_WEI = 0;

    /// @notice Placeholder Ignite price in `$TERM` (18 decimals). 1,000 $TERM.
    /// Change here before broadcast.
    uint256 internal constant IGNITE_FEE_TERM = 1_000 ether;

    /// @notice Hybrid Ignite ETH fee. Split 50% Hopper / 50% buy `$TERM` and burn.
    /// Not TermFund. Not treasury. Collectors do not earn this leg.
    /// Full-supply wake: 4444 × 0.002 = 8.888 ETH total; 200 wakes = 0.4 ETH.
    uint256 internal constant IGNITE_FEE_ETH = 0.002 ether;
    /// @dev 50% of `IGNITE_FEE_ETH` → Hopper (ETH).
    uint16 internal constant IGNITE_ETH_HOPPER_BPS = 5_000;
    /// @dev 50% of `IGNITE_FEE_ETH` → router buy `$TERM` → burn. Production needs `swapRouter`.
    uint16 internal constant IGNITE_ETH_BURN_BPS = 5_000;

    /// @dev 25% of each Ignite `$TERM` fee → ETH → Hopper (Pulse fuel).
    uint16 internal constant IGNITE_HOPPER_BPS = 2_500;
    /// @dev 37.5% of each Ignite `$TERM` fee is burned.
    uint16 internal constant IGNITE_BURN_BPS = 3_750;
    /// @dev 37.5% of each Ignite `$TERM` fee returns to first-wake allotment escrow.
    /// Not treasury. Not TermFund. The same tokenId cannot spend allotment twice.
    uint16 internal constant IGNITE_ALLOTMENT_REFILL_BPS = 3_750;

    /// @notice Initial `$TERM` mint to treasury at deploy (later LP / Phase B). Placeholder.
    uint256 internal constant TERM_INITIAL_SUPPLY = 1_000_000_000 ether;

    /// @notice Per-token Ignite allotment funded from `$TERM` supply (not ETH).
    /// Equals one `IGNITE_FEE_TERM` so the `$TERM` half of the first wake needs no DEX.
    uint256 internal constant IGNITE_ALLOTMENT_PER_TOKEN = IGNITE_FEE_TERM;

    /// @notice Escrow float minted to IgniteModule at deploy: 4444 × 1,000 $TERM.
    uint256 internal constant IGNITE_ALLOTMENT_SUPPLY = MAX_SUPPLY * IGNITE_FEE_TERM;

    /// @dev Pulse ladder step. Bootstrap: 0.1 → 1.0. After that: 0.5 → 1.0 forever.
    uint256 internal constant PULSE_LADDER_STEP_WEI = 0.1 ether;
    uint256 internal constant PULSE_BOOTSTRAP_START_WEI = 0.1 ether;
    uint256 internal constant PULSE_CYCLE_START_WEI = 0.5 ether;
    uint256 internal constant PULSE_LADDER_CAP_WEI = 1 ether;

    /// @dev Total ERC-2981 / OpenSea creator earnings (7.5% of sale) paid to RoyaltySplitter.
    uint96 internal constant ROYALTY_BPS = 750;
    /// @dev Post-reveal Hopper share of the sale (5%). Equals 2/3 of the 750 bps pot.
    /// Pre-reveal: the full 7.5% goes to TermFund instead (RoyaltySplitter.live = false).
    uint96 internal constant ROYALTY_HOPPER_BPS = 500;
    /// @dev Post-reveal treasury share of the sale (2.5%). Equals 1/3 of the 750 bps pot.
    /// Pre-reveal: treasury gets nothing from this stream.
    uint96 internal constant ROYALTY_TREASURY_BPS = 250;

    uint256 internal constant CHAIN_ID = 4663;

    /// @notice Canonical SeaDrop 1.0 (OpenSea). Same CREATE2 address on every
    /// chain OpenSea has deployed it to. Authorize this (or Studio's SeaDrop)
    /// via `CollectionNFT` constructor / `updateAllowedSeaDrop`.
    /// See https://github.com/ProjectOpenSea/seadrop and docs/OPENSEA_STUDIO_SEADROP.md.
    address internal constant SEADROP = 0x00005EA00Ac477B1030CE78506496e8C2dE24bf5;

    /// @notice Robinhood Chain Stock Token Dial pool (PulseDistributor allowlist).
    /// Symbols (hub order): HOOD, AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA.
    /// Mainnet ERC-20s are **not** hardcoded — owner `setStockToken` when known.
    uint8 internal constant STOCK_POOL_SIZE = 8;
    uint8 internal constant MAX_DIAL_LEGS = 4;

    /// @dev Shell class rarity weights — same as `art/schema/traits.json` `shell_class`.
    uint8 internal constant SHELL_ALPHA_WEIGHT = 60;
    uint8 internal constant SHELL_BETA_WEIGHT = 25;
    uint8 internal constant SHELL_DELTA_WEIGHT = 10;
    uint8 internal constant SHELL_OMEGA_WEIGHT = 5;

    /// @notice Mint → reveal delay. Owner may reveal early; anyone may reveal after this elapses.
    uint256 internal constant REVEAL_DELAY = 24 hours;

    /// @notice After `reveal()`, Hopper payouts (`reserve` / `release` / Pulse claim)
    /// stay locked for this long. Timer starts at the reveal timestamp — Ignite does
    /// not unlock early. Deposits still accrue.
    uint256 internal constant HOPPER_LOCK = 7 days;

    /// @notice Canonical TERM/ETH swap skim (not a token tax). 3.00% of input.
    uint16 internal constant TRADE_FEE_BPS = 300;
    /// @dev 1.5% of volume → ETH to Hopper.
    uint16 internal constant TRADE_HOPPER_BPS = 150;
    /// @dev 1.0% of volume → `$TERM` then burn.
    uint16 internal constant TRADE_BURN_BPS = 100;
    /// @dev 0.5% of volume → treasury.
    uint16 internal constant TRADE_TREASURY_BPS = 50;
}
