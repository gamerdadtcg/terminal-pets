# Terminal Pets — Collection Generator (Animated GIFs)

Generates **animated GIF** PFPs + ERC-721 metadata for the Terminal Pets collection.

- **Awake pet** (`art/N.gif`): pet on device with animated screen FX (`make_fx_frame`, 10 frames @ 120 ms).
- **Matching egg** (`egg/N.gif`): same device traits, dormant egg-rock (8 rock offsets @ 150 ms).
- Same token id for pet ↔ egg. Egg always matches pet species (`E0N` ↔ `P0N`).

This is the **live product art**. Do not restore Track A on-chain SVG pets. Do **not** modify `/home/box/terminal-pets-main-art/` (historical archive).

## Output size

GIFs are **512×512**, downscaled from the 2048 compose canvas with **NEAREST** (keeps pixel look, smaller files). Override with `--gif-size` if needed.

## Prerequisites

- Python 3.10+ with Pillow (`pip install -r art/requirements.txt`)
- Art root: this package (`art/`, auto-detected). Optional override: `TERMINAL_PETS_ART_ROOT`.
- Box notes: live `/workspace/nft-pfp-art-system/`, lock mirror `/home/box/terminal-pets-generative-art-lock/current/`.

## Quick test (tokens 1–3)

From the **repository root**:

```bash
python art/generator/generate_collection.py \
  --count 4444 --start 1 --limit 3 \
  --out-art art/export/gif-test/art \
  --out-metadata art/export/gif-test/metadata \
  --out-egg art/export/gif-test/egg \
  --out-egg-metadata art/export/gif-test/egg-metadata \
  --seed 42
```

Outputs per token `N`:

| Path | Content |
|------|---------|
| `art/N.gif` | Awake pet + animated FX |
| `metadata/N.json` | Pet metadata (`image`: `N.gif` or prefixed URI) |
| `egg/N.gif` | Matching egg rock GIF |
| `egg-metadata/N.json` | Egg metadata (`image`: `N.gif`; `pet_id` / `egg_id` / `linked_pet_id`; `State: Dormant`) |

Also writes `manifest.json` and `_dna.json` beside the metadata dir.

## Full collection (4444 × 2 GIFs)

```bash
python art/generator/generate_collection.py \
  --count 4444 --start 1 \
  --out-art art/export/gif-full/art \
  --out-metadata art/export/gif-full/metadata \
  --out-egg art/export/gif-full/egg \
  --out-egg-metadata art/export/gif-full/egg-metadata \
  --seed 42 \
  --progress-every 25
```

Resume after interrupt: same args + `--resume` (skips tokens that already have all four files). **Do not commit** `art/export/gif-full/` (gitignored).

## Hosting (IPFS / HTTP)

Metadata `image` fields default to a relative `N.gif`. After pinning the GIF folders, either generate with prefixes or rewrite:

```bash
python art/generator/generate_collection.py ... \
  --art-image-base ipfs://bafyArtCid/ \
  --egg-image-base ipfs://bafyEggCid/

python art/generator/rewrite_image_uris.py \
  --dir art/export/gif-full/metadata --base ipfs://bafyArtCid/
python art/generator/rewrite_image_uris.py \
  --dir art/export/gif-full/egg-metadata --base ipfs://bafyEggCid/
```

Pin `metadata/` and `egg-metadata/` as well. Then:

```text
CollectionNFT.setMetadataURIs(
  "ipfs://…/hidden.json",          // sealed, no trailing slash
  "ipfs://…/egg-metadata/",        // dormant, trailing slash → {id}.json
  "ipfs://…/metadata/"             // lit, trailing slash → {id}.json
)
```

Hub examples (~25 GIFs, **not mint supply**): `web/public/art/examples/{awake,egg}/`. Public collection metadata on the hub is **only** `web/public/metadata/hidden.json` until after reveal. Do not commit 4444 JSON to `web/public/metadata/{lit,dormant}/`. Featured stills also live under `web/public/art/{awake,dormant}/`.

## CLI flags

| Flag | Default | Meaning |
| --- | --- | --- |
| `--count` | 4444 | Number of tokens in the intended range |
| `--start` | 1 | First token ID (1-indexed) |
| `--limit N` | none | Generate at most N tokens this run (tests) |
| `--out-art DIR` | required | Awake `{id}.gif` |
| `--out-metadata DIR` | required | Pet `{id}.json` |
| `--out-egg DIR` | required | Egg rock `{id}.gif` |
| `--out-egg-metadata DIR` | required | Egg `{id}.json` |
| `--seed SEED` | random | Reproducible rolls |
| `--resume` | off | Skip existing tokens; keep DNA uniqueness |
| `--gif-size` | 512 | GIF edge (NEAREST from 2048) |
| `--art-image-base` | empty | Prefix for awake `image` |
| `--egg-image-base` | empty | Prefix for egg `image` |
| `--progress-every N` | 25 | Progress log cadence |

## Animation specs

| Asset | Frames | Duration | Notes |
| --- | --- | --- | --- |
| Pet (awake) | 10 | 120 ms | `make_fx_frame(fx, frame=i)` — same loop as gallery `fx-anim/` |
| Egg (dormant) | 8 | 150 ms | `rock_frame` offsets `[0,-2,-3,-1,0,2,3,1]` |

## Trait roll order

Weighted via `rarity.pick_weighted` + `traits.json`:

1. **pet** → **egg** locked to that pet (`egg_id_for_pet`, E0N for P0N)
2. pet_color, eyes, mouth, accessory (per-pet lists, includes `none`)
3. background, handheld, shell_color, shell_class, buttons, antenna
4. screen (filtered for handheld incompatibilities), fx

## Notes

- Unique DNA: full trait combo rejected until unique (or `--max-retries`).
- PNG export path removed — generator writes `.gif` only (leftover `*.png` in art/egg dirs are deleted on run).
- Rough timing: ~2–2.5 s/token (pet+egg) → full 4444 ≈ **2.5–3.5 hours**; ~50–90 KiB per GIF → ~0.5–0.8 GB for both sets.
