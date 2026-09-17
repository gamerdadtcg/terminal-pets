# Pocket Critter — Terminal Pets generative PFP

Live product art for **Terminal Pets**. Modular off-chain PNG/GIF PFPs (2048 compose, 512 GIF export). This is **not** the historical on-chain SVG Track A (`scarfpack-3a194a4` / `TerminalRenderer` lit pets).

Vendored in this repo at `art/`.

## Paths

| Role | Path |
| --- | --- |
| **In-repo (this checkout)** | `art/` |
| Live box working copy (notes) | `/workspace/nft-pfp-art-system/` |
| Lock mirror | `/home/box/terminal-pets-generative-art-lock/current/` |
| Historical Track A archive — **do not overwrite** | `/home/box/terminal-pets-main-art/` |

The generator resolves the art root from this package (`art/generator/common.py`). Override with `TERMINAL_PETS_ART_ROOT` if you are running a box checkout of the same tree.

## Dependencies

Python **3.10+** and Pillow:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r art/requirements.txt
```

## Quick start

```bash
# optional: rebuild procedural layers (already committed under layers/)
python art/generator/build_assets.py

# one-off compose (2048 PNG)
python art/generator/compose.py --preview-sheet
python art/generator/compose.py \
  --bg BG03 --handheld H01 --color cream --class ALPHA --pet-id 421 \
  --buttons yellow --antenna star --screen S01 --fx scanlines \
  --pet P02 --pet-color green --eyes happy --mouth smile --acc crown \
  --out art/previews/custom.png

# dormant egg rock GIF
python art/generator/compose.py --dormant --egg E03 --rock --out art/previews/egg-rock.gif
```

## Collection GIFs (awake + matching egg)

See `generator/README-generate.md`. Sample 3-token export (seed 42) is already under `export/gif-test/`.

```bash
# smoke test (tokens 1–3)
python art/generator/generate_collection.py \
  --count 4444 --start 1 --limit 3 \
  --out-art art/export/gif-test/art \
  --out-metadata art/export/gif-test/metadata \
  --out-egg art/export/gif-test/egg \
  --out-egg-metadata art/export/gif-test/egg-metadata \
  --seed 42

# full 4444 (hours; ~0.5–0.8 GB) — do not commit gif-full/
python art/generator/generate_collection.py \
  --count 4444 --start 1 \
  --out-art art/export/gif-full/art \
  --out-metadata art/export/gif-full/metadata \
  --out-egg art/export/gif-full/egg \
  --out-egg-metadata art/export/gif-full/egg-metadata \
  --seed 42 \
  --progress-every 25
```

After pinning GIFs to IPFS/HTTP, prefix metadata `image` fields:

```bash
python art/generator/generate_collection.py ... \
  --art-image-base ipfs://bafyArtCid/ \
  --egg-image-base ipfs://bafyEggCid/

# or rewrite an existing export
python art/generator/rewrite_image_uris.py \
  --dir art/export/gif-full/metadata --base ipfs://bafyArtCid/
python art/generator/rewrite_image_uris.py \
  --dir art/export/gif-full/egg-metadata --base ipfs://bafyEggCid/
```

Then owner-set `CollectionNFT.setMetadataURIs(hiddenURI, dormantBaseURI, litBaseURI)`:

- `hiddenURI` — single sealed JSON (no trailing slash), e.g. `ipfs://…/hidden.json`
- `dormantBaseURI` — trailing slash, e.g. `ipfs://…/egg-metadata/` → `{id}.json`
- `litBaseURI` — trailing slash, e.g. `ipfs://…/metadata/` → `{id}.json`

### Demo hosting (not mint supply)

The Vercel hub hosts ~25 **example** GIFs at `/art/examples/` (labeled examples / not mint supply). Public collection metadata is **only** sealed `hidden.json` until after `reveal()`:

| Arg | HTTPS |
| --- | --- |
| `hiddenURI` | `https://terminalpets.xyz/metadata/hidden.json` (`https://terminal-pets.vercel.app/metadata/hidden.json` still resolves until DNS cutover) |
| `dormantBaseURI` / `litBaseURI` | **Do not** point at this hub before reveal |

Files: `web/public/art/examples/awake/{n}.gif`, `web/public/art/examples/egg/{n}.gif`. See `docs/MAIN_ART_LOCK.md`. Do not commit 4444 JSON to `web/public/metadata/{lit,dormant}`.

Ignite already emits ERC-4906 `MetadataUpdate`. Reveal emits `BatchMetadataUpdate`.

## Layout

- `ART-BIBLE.md` — canvas, layer order, pets P01–P12
- `TRAIT-FIT.md` / `UNIQUE-TRAITS.md` — eye/mouth/acc pass
- `schema/` — `traits.json`, `anchors.json`, `layer-order.json`, rarity
- `generator/` — `compose.py`, `generate_collection.py`, `build_*.py`
- `layers/` — 12 pets, eggs E01–E12, handhelds, shells, buttons, antennas, screens, FX, Robinhood-green BGs
- `anim/` — egg_rock, hatch
- `previews/` — family sheets + samples
- `export/gif-test/` — 3-token GIF + JSON sample
- `export/sealed/hidden.json` — pre-reveal metadata stub

Product traits live in `schema/traits.json`. The old on-chain `ACC_N = 6` accessory table (Bow/Cap/Star/Glasses/Halo) is **obsolete** for product art.
