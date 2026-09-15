# Terminal Pets — main art lock

The **morning archive** (`faces3/` + `traits/`, pre-GitHub) is canonical Terminal Pets art until the user **explicitly** changes direction.

Do **not** overwrite these stills with fill-only hub dumps, Look A, pixel pets, or approximate regenerations unless the user asks.

- Accessories: `ACC_N = 6` (None, Bow, Cap, Star, Glasses, Halo). Scarf and Pack stay gone.
- Seed: `AWAKEN_PET_V2` (unchanged).
- On-chain SVG: `src/TerminalRenderer.sol` from git `3a194a4` (`TerminalRenderer_GOOD.sol`).
- Hub stills: `web/public/art-pass/` and `artifacts/art-pass/` (byte-identical to the archive).

## Canonical md5

| file | md5 |
| --- | --- |
| `Dino-id12-lit.png` | `d336377f763300fd9df68108e592e2ed` |
| `BirdGlasses-id29-lit.png` | `2f0af10007679423a7a6f80e9d8390f8` |
| `species-lit-sheet.png` | `6e141bc25989a2bb0d576e5740ad8c70` |
| `traits/traits-index.png` | `3feb20ea3e384d67f5737a9fc6b96da1` |
| `traits/traits-species.png` | `9741f5548f9b0c7197dc73b3e1c9dc2b` |

Verify with `md5sum` on `web/public/art-pass/` (same hashes in `artifacts/art-pass/`).

If `ExportArtPass` / `rasterize_art_pass.py` / trait catalog export would rewrite these PNGs, skip regen for them or re-copy the archive bytes on top so the committed files stay identical.
