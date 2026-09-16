/** Robinhood Chain Stock Token Dial pool. Addresses live on PulseDistributor. */

/**
 * On-chain `PulseDistributor.stockPool` is a fixed 8-slot array. Slot 0 used
 * to reserve HOOD. Official Robinhood Chain `/rhj/assets` (chainId 4663) has
 * no HOOD stock token — leave slot 0 `address(0)`. Collectors never see it.
 */
export const UNUSED_STOCK_SLOT = {
  slot: 0,
  status: "unused",
  reason:
    "Official Robinhood Chain registry has no HOOD stock token. Leave address(0).",
} as const;

/** Live Dial pool (slots 1–7). Hub UI and copy list only these symbols. */
export const STOCK_POOL = [
  {
    slot: 1,
    symbol: "AAPL",
    name: "Apple",
    address: "0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9",
  },
  {
    slot: 2,
    symbol: "MSFT",
    name: "Microsoft",
    address: "0xe93237C50D904957Cf27E7B1133b510C669c2e74",
  },
  {
    slot: 3,
    symbol: "GOOGL",
    name: "Alphabet",
    address: "0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3",
  },
  {
    slot: 4,
    symbol: "AMZN",
    name: "Amazon",
    address: "0x12f190a9F9d7D37a250758b26824B97CE941bF54",
  },
  {
    slot: 5,
    symbol: "META",
    name: "Meta",
    address: "0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35",
  },
  {
    slot: 6,
    symbol: "NVDA",
    name: "NVIDIA",
    address: "0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC",
  },
  {
    slot: 7,
    symbol: "TSLA",
    name: "Tesla",
    address: "0x322F0929c4625eD5bAd873c95208D54E1c003b2d",
  },
] as const;

export const SHELL_DIAL = [
  {
    className: "ALPHA",
    rarity: "Common",
    weight: 60,
    stocks: 1,
  },
  {
    className: "BETA",
    rarity: "Rare",
    weight: 25,
    stocks: 2,
  },
  {
    className: "DELTA",
    rarity: "Epic",
    weight: 10,
    stocks: 3,
  },
  {
    className: "OMEGA",
    rarity: "Legendary",
    weight: 5,
    stocks: 4,
  },
] as const;

export const DIAL_COPY = {
  poolLine: STOCK_POOL.map((s) => s.symbol).join(", "),
  classLine: SHELL_DIAL.map(
    (row) => `${row.className} ${row.rarity} → ${row.stocks}`,
  ).join(" · "),
} as const;
