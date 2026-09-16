/** Robinhood Chain Stock Token Dial pool. Addresses live on PulseDistributor. */
export const STOCK_POOL = [
  { slot: 0, symbol: "HOOD", name: "Robinhood" },
  { slot: 1, symbol: "AAPL", name: "Apple" },
  { slot: 2, symbol: "MSFT", name: "Microsoft" },
  { slot: 3, symbol: "GOOGL", name: "Alphabet" },
  { slot: 4, symbol: "AMZN", name: "Amazon" },
  { slot: 5, symbol: "META", name: "Meta" },
  { slot: 6, symbol: "NVDA", name: "NVIDIA" },
  { slot: 7, symbol: "TSLA", name: "Tesla" },
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
