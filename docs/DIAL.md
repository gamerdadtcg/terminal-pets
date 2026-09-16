# Dial

Lit pets do **not** pick Stock Tokens. Dial is assigned on Ignite from the on-chain 8-slot allowlist, by **shell class**. Slot 0 is unused. The **live pool** collectors see is seven Robinhood Chain Stock Tokens.

## Stock pool (hub + contract allowlist)

Order is fixed. Slot 0 used to reserve HOOD; the official Robinhood Chain registry (`/rhj/assets`, chainId `4663`) has **no HOOD stock token**. Leave slot 0 `address(0)`. Do **not** invent a HOOD ERC-20. Hub copy lists only the seven live symbols.

| Slot | Symbol | Mainnet ERC-20 (`4663`) | Testnet sample |
| --- | --- | --- | --- |
| 0 | *unused* | `address(0)` — no HOOD token | — |
| 1 | AAPL | `0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9` | — |
| 2 | MSFT | `0xe93237C50D904957Cf27E7B1133b510C669c2e74` | — |
| 3 | GOOGL | `0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3` | — |
| 4 | AMZN | `0x12f190a9F9d7D37a250758b26824B97CE941bF54` | `0x5884aD2f920c162CFBbACc88C9C51AA75eC09E02` |
| 5 | META | `0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35` | — |
| 6 | NVDA | `0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC` | — |
| 7 | TSLA | `0x322F0929c4625eD5bAd873c95208D54E1c003b2d` | `0xC9f9c86933092BbbfFF3CCb4b105A4A94bf3Bd4E` |

Live pool (hub + collector copy): **AAPL, MSFT, GOOGL, AMZN, META, NVDA, TSLA**.

Mainnet addresses are verified from Robinhood `/rhj/assets` on chain `4663`. These are **Robinhood Chain Stock Tokens**, not equity. Owner calls `PulseDistributor.setStockToken(slot, token)` / `setStockTokens` to wire slots 1–7. Leave slot 0 unset. Testnet AMZN/TSLA come from [Robinhood Chain contract docs](https://docs.robinhood.com/chain/contracts/) and are **not** wired as deploy defaults. Wiring those two slots on RH testnet (`46630`): [`TESTNET_DEPLOY.md`](TESTNET_DEPLOY.md). Mainnet checklist: [`MAINNET_PREP.md`](MAINNET_PREP.md).

`DialMath` still draws unique slots from the fixed 8-slot bag. A pick of unused slot 0 stays `address(0)` and that Pulse leg buys `$TERM`.

## Assignment by shell class

From `art/schema/rarity.json` / `art/schema/traits.json` `shell_class`:

| Class | Art rarity | Weight | Dial stocks |
| --- | --- | --- | --- |
| ALPHA | Common | 60 | 1 |
| BETA | Rare | 25 | 2 |
| DELTA | Epic | 10 | 3 |
| OMEGA | Legendary | 5 | 4 |

Stocks are drawn **randomly without replacement** from the 8-slot array. Weights split equally across legs so bps sum to `10_000` (remainder on the last leg: 3 stocks → `3333 / 3333 / 3334`).

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
