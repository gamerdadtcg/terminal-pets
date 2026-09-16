# Dial

Lit pets do **not** pick Stock Tokens. Dial is assigned on Ignite from an 8-token allowlist, by **shell class**.

## Stock pool (hub + contract allowlist)

Order is fixed:

| Slot | Symbol | Mainnet ERC-20 | Testnet sample |
| --- | --- | --- | --- |
| 0 | HOOD | *unset (`address(0)`)* | — |
| 1 | AAPL | *unset* | — |
| 2 | MSFT | *unset* | — |
| 3 | GOOGL | *unset* | — |
| 4 | AMZN | *unset* | `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02` |
| 5 | META | *unset* | — |
| 6 | NVDA | *unset* | — |
| 7 | TSLA | *unset* | `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E` |

These are **Robinhood Chain Stock Tokens**, not equity. Owner calls `PulseDistributor.setStockToken(slot, token)` / `setStockTokens` when real addresses are known. **Do not invent mainnet addresses.** Testnet AMZN/TSLA come from [Robinhood Chain contract docs](https://docs.robinhood.com/chain/contracts/) and are **not** wired as deploy defaults.

## Assignment by shell class

From `art/schema/rarity.json` / `art/schema/traits.json` `shell_class`:

| Class | Art rarity | Weight | Dial stocks |
| --- | --- | --- | --- |
| ALPHA | Common | 60 | 1 |
| BETA | Rare | 25 | 2 |
| DELTA | Epic | 10 | 3 |
| OMEGA | Legendary | 5 | 4 |

Stocks are drawn **randomly without replacement** from the 8-slot pool. Weights split equally across legs so bps sum to `10_000` (remainder on the last leg: 3 stocks → `3333 / 3333 / 3334`).

## When

`IgniteModule.ignite` calls `PulseDistributor.assignDial(tokenId)` after the pet becomes Lit. Anyone may call `assignDial` later for a Lit pet that missed the hook (same deterministic result — not a picker). `setDial` / holder weight pickers are removed.

Pulse still snapshots Dial at `pulse()`. If every assigned slot is still `address(0)`, that Lit share buys `$TERM` (undialed fallback). Dormant earn nothing.

## Shell class on-chain (why not the Python DNA roll)

Product art rolls `shell_class` inside `art/generator/generate_collection.py` via Python `random.Random` as one step in a long weighted DNA stream, then **reject-until-unique**. That stream cannot be replayed in Solidity, and it would not match across clients.

**What the chain does instead**

1. **Default:** `keccak256(abi.encodePacked(keccak256("TERMINAL_PETS.SHELL_CLASS.v1"), tokenId)) % 100` with the same 60/25/10/5 buckets. Stock picks use `keccak256("TERMINAL_PETS.DIAL.v1")` plus the token id. Pure `tokenId` + fixed salts — hub and other clients can preview the same Dial.
2. **Override (art match):** Owner `setShellClassOverride(tokenId, class)` from generative metadata (`1=ALPHA … 4=OMEGA`) **before Ignite**. That is the clean way to make Dial count match the PFP `Shell Class` trait. `0` clears the override.

Dial **stock picks** are always the keccak stream (not the Python DNA). Only the **count** follows shell class.

See `src/DialMath.sol` and `PulseDistributor.previewDial`.
