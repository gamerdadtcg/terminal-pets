# Rarity — Terminal Pets

One-pager for Travis. Tier weights drive weighted rolls; each selectable option carries `rarity` + `weight`.

## Tiers (most → least common)

| Tier | Weight | Label | Order |
|------|--------|-------|-------|
| common | 60 | Common | 0 |
| rare | 25 | Rare | 1 |
| epic | 10 | Epic | 2 |
| legendary | 5 | Legendary | 3 |

Sum = 100. An option's `weight` defaults to its tier weight and may be overridden later without changing the tier label.

## Category mix targets

When category size allows: **55–65% Common · 20–25% Rare · 10–15% Epic · 5–10% Legendary** (by option count, not by roll odds).

## Special rules

- **Eggs** — all Common (1:1 with pet).
- **Pets** — all equal Common.
- **Shell class** — ALPHA Common, BETA Rare, DELTA Epic, OMEGA Legendary.
- **Accessory `none`** — always Common.
- Flashier traits lean rarer (gold chrome / jeweled / neon screens, crown / orb antennas, glitch / lightning FX, collector H10, bright BG04, etc.).

## Helpers

- `generator/rarity.py` — `pick_weighted(options)`, `expected_odds(options)`, `option_id`, summary builders.
- `schema/rarity-summary.json` — machine-readable per-category odds.
- `schema/rarity.json` — tier mirror + guidelines.

## Proofs

- `previews/gallery/rarity-overview.png` — tier legend
- `previews/gallery/rarity-by-category.png` — id / badge / weight / % per category
