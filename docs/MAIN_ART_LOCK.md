# Terminal Pets — main art lock

Canonical art is commit **`3a194a4`** (`Drop Scarf/Pack accessories and redraw the Dino silhouette.`), **not** the morning `faces3` archive.

Hub stills in `web/public/art-pass/` and `artifacts/art-pass/` (including `traits/`) must stay **byte-identical** to that commit. Do not restore morning-archive faces3, fill-only hub dumps, Look A, pixel pets, or approximate regenerations unless the user asks.

- Accessories: `ACC_N = 6` (None, Bow, Cap, Star, Glasses, Halo). Scarf and Pack stay gone.
- Seed: `AWAKEN_PET_V2` (unchanged).
- On-chain SVG: `src/TerminalRenderer.sol` blob `e1a358c4dd37b3a9400c63ad92976d6ccc35e8af` (git `3a194a4` / `TerminalRenderer_GOOD.sol`). Do not swap the renderer.

## Canonical md5

| file | md5 |
| --- | --- |
| `species-lit-sheet.png` | `79f242dc116332615c8f64cf10bd4c3f` |
| `Dino-id12-lit.png` | `1f5feaa4d00abdd42dc0b589ad27d497` |
| `BirdGlasses-id29-lit.png` | `402d79812daf6b002bd8e3b6ca08ecef` |
| `traits/traits-species.png` | `4d85188375dee2df45779faff5d68d1a` |
| `traits/traits-index.png` | `469b997d24873afa9c1657e9a27ed7bb` |
| `traits/traits-accessory.png` | `e512481c94c648807a55007b893280f3` |

Verify with `md5sum` on `web/public/art-pass/` (same hashes in `artifacts/art-pass/`).

If `ExportArtPass` / `rasterize_art_pass.py` / trait catalog export would rewrite these PNGs, skip regen for them or restore from `3a194a4` so the committed files stay identical.
