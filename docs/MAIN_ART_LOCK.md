# Terminal Pets — live art lock

**Confirmed 2026-09-16 (Travis): live product art is the generative modular PFP package (Pocket Critter system).**

Not the old on-chain SVG Track A (`scarfpack-3a194a4` / `TerminalRenderer` lit pets). Track A stays historical archive only. Do not restore it as live art. Do not overwrite `/home/box/terminal-pets-main-art/`.

## Canonical paths

| Role | Path |
| --- | --- |
| **This repo (vendored)** | `art/` |
| Live box working copy | `/workspace/nft-pfp-art-system/` |
| Generative lock mirror | `/home/box/terminal-pets-generative-art-lock/current/` |
| Historical Track A / stills archive | `/home/box/terminal-pets-main-art/` (**do not overwrite**) |

## What is live

Off-chain composed **PNG/GIF** PFPs:

- Compose canvas **2048×2048**
- Collection export **512×512 GIF** (NEAREST)
- Awake: pet on handheld + animated screen FX (10×120 ms)
- Dormant: matching species egg rock (8×150 ms)
- 12 pets P01–P12, eggs E01–E12, handhelds, shells, buttons, antennas, screens, FX, Robinhood-green backgrounds

Traits, rarity, and layer order: `art/schema/` (`traits.json`, `anchors.json`, `layer-order.json`, rarity files). Art bible: `art/ART-BIBLE.md`.

The old on-chain `ACC_N = 6` accessory list (None, Bow, Cap, Star, Glasses, Halo) and `AWAKEN_PET_V2` SVG pets are **obsolete for product art**. `CollectionNFT.tokenTraits()` still returns that historical table for tests; marketplaces should read Pocket Critter JSON attributes.

## tokenURI / metadata

Product metadata is **off-chain** JSON + GIF. `CollectionNFT` switches URI by lifecycle:

| State | When | `tokenURI` |
| --- | --- | --- |
| Sealed | mint → `reveal()` | `hiddenURI` (typical single `hidden.json`) |
| Dormant | revealed, not Ignited | `{dormantBaseURI}{id}.json` → egg rock GIF |
| Lit | after Ignite | `{litBaseURI}{id}.json` → awake pet GIF |

Owner call: `setMetadataURIs(hiddenURI, dormantBaseURI, litBaseURI)`.

- No trailing slash → use `base` as-is (sealed JSON).
- Trailing slash → `{base}{tokenId}.json` (matches `generate_collection.py`).

ERC-4906: `reveal()` emits `BatchMetadataUpdate`; Ignite already calls `notifyMetadataUpdate`. Setting URIs after mint also batch-updates.

Until bases are set, `tokenURI` falls back to `TerminalRenderer` data-URI JSON (plain rectangle stub labeled `OFF-CHAIN ART`). That stub is **not** product art.

Host on IPFS or HTTP. After pinning GIF folders, prefix `image` fields with `--art-image-base` / `--egg-image-base` or `art/generator/rewrite_image_uris.py`. Stub sample: `art/export/sealed/hidden.json` and `art/export/gif-test/`.

Hub demo: featured **examples / not mint supply** (~25 GIFs under `web/public/art/examples/`). Public collection metadata on this hub is **only** `web/public/metadata/hidden.json` until after reveal. Do **not** commit 4444 lit/dormant JSON to `web/public/metadata/{lit,dormant}`.

## Demo hosting (not mint supply)

~25 labeled **example** GIFs (GIF89a only — do not convert to PNG). These are **not** CollectionNFT tokenIds and **not** the 4444 mint files:

| Path | What |
| --- | --- |
| `web/public/art/examples/awake/{n}.gif` | Example awake / lit pet GIF |
| `web/public/art/examples/egg/{n}.gif` | Example dormant egg-rock GIF |
| `web/public/art/sealed.png` | Generic sealed image (no traits) |
| `web/public/metadata/hidden.json` | **Only** public collection metadata until after reveal |

Until `CollectionNFT.reveal()`, every `tokenURI` is `hidden.json`. Collectors cannot see traits. Do **not** restore `web/public/metadata/lit/` or `web/public/metadata/dormant/` (gitignored) before reveal policy — enumerable `{id}.json` is a snipe vector even while on-chain URI is sealed.

After Vercel deploy, owner-set **hiddenURI now**. Set dormant/lit bases from a **private 4444 pin at reveal**, not this hub:

```text
CollectionNFT.setMetadataURIs(
  hiddenURI,       // https://terminalpets.xyz/metadata/hidden.json (vercel.app still resolves)
  dormantBaseURI,  // private pin after reveal (trailing slash → {id}.json)
  litBaseURI       // private pin after reveal (trailing slash → {id}.json)
)
```

| Arg | Friday mint |
| --- | --- |
| `hiddenURI` | `https://terminalpets.xyz/metadata/hidden.json` (`https://terminal-pets.vercel.app/metadata/hidden.json` still resolves until DNS cutover) |
| `dormantBaseURI` | unset / private pin — **not** hub `/metadata/dormant/` |
| `litBaseURI` | unset / private pin — **not** hub `/metadata/lit/` |

Old `/art/test/` and `/art/test-egg/` GIF URLs redirect to `/art/examples/`. Studio dry-run and mainnet must not treat demo GIFs as collection metadata — [`MAINNET_PREP.md`](MAINNET_PREP.md) §4.

## Regenerate collection GIFs

Python 3.10+ and Pillow (`pip install -r art/requirements.txt`). From repo root:

```bash
# smoke (already committed under art/export/gif-test/, seed 42)
python art/generator/generate_collection.py \
  --count 4444 --start 1 --limit 3 \
  --out-art art/export/gif-test/art \
  --out-metadata art/export/gif-test/metadata \
  --out-egg art/export/gif-test/egg \
  --out-egg-metadata art/export/gif-test/egg-metadata \
  --seed 42

# full 4444 — hours; gitignored at art/export/gif-full/
python art/generator/generate_collection.py \
  --count 4444 --start 1 \
  --out-art art/export/gif-full/art \
  --out-metadata art/export/gif-full/metadata \
  --out-egg art/export/gif-full/egg \
  --out-egg-metadata art/export/gif-full/egg-metadata \
  --seed 42 \
  --progress-every 25
```

One-off compose: `python art/generator/compose.py --preview-sheet`. Rebuild layers: `python art/generator/build_assets.py`. Details: `art/README.md` and `art/generator/README-generate.md`.

## Historical (do not ship)

- Track A on-chain SVG (`scarfpack-3a194a4`, TerminalRenderer lit pets)
- Art-pass stills / trait-catalog SVG wording
- `/home/box/terminal-pets-main-art/` archive
