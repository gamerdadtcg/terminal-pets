# Trait fit pass (eyes / mouths / accessories)

Date: 2026-09-15 (PT)

## Pipeline note
Compose pastes full **64×64** trait PNGs into the screen via `place_pixel_in_screen` (NEAREST). Anchors in `schema/anchors.json` (`*_64`) document seating and drive procedural draw in `generator/build_pets.py`. Traits are **not** cropped to the rect at compose time — pixels must already sit in the correct place on the 64 grid.

## Locked bodies
- **P04 PUPPO** and **P12 BOLT**: body / body_tintable / colors **unchanged** (MD5 verified). Only eyes, mouths, accessories + anchors updated.
- Rebuild used `build_traits_only()` so no body rewrite for any pet this pass.

## What changed

### Anchor changes (`*_64` + derived H01 2048 fields) — all 12 pets
| Pet | Eyes | Mouth | Accessory |
|-----|------|-------|-----------|
| P01 PUDD | higher/closer | raised under eyes | brim sits on blob crown |
| P02 SNAG | head-side single | snout-aligned | crest toppers; side/neck seats for bag/bandana/bowtie |
| P03 MEOWLET | mid-wide | raised | between pointed ears |
| P04 PUPPO | above muzzle | on muzzle | between floppy ears on crown |
| P05 HOPLIT | lower (clear of tall ears) | lower | narrow toppers between ears |
| P06 ZORP | huge upper | tinier/lower | on stalks |
| P07 DRAKELET | head-side | snout | neck (clears horn/wing); side seats for bag/etc. |
| P08 BLOP | on top bulges | wider/lower | between eye bumps |
| P09 BRUMBLE | slightly higher | on snout oval | between round ears |
| P10 PIP | beside beak | beak attach rect | head toppers clear of beak; side/neck seats |
| P11 GILLI | wide | raised | narrow crown (gills stay visible) |
| P12 BOLT | centered in visor | faceplate grill | robotic antenna/head toppers |

### Trait redraws (procedural PNGs regenerated)
- **All 12** pets: full eyes (10), mouths (10); accessories now include **none** (see UNIQUE-TRAITS.md for per-pet counts).
- Special drawers: `draw_snout_mouth` (P02/P07), improved `draw_beak` (P10), BLOP top-bump eyes, seat-based hats (brim at box bottom), `ACC_SEAT` overrides for bandana/bowtie/headphones/flower (+ DRAKELET/PIP head toppers); BOLT `draw_robot_accessory` (hard-hat, circuit crown, ribbon bow, neck bandana, sensors, LED flower, chest bowtie, party cone). **Backpack removed.**

## Review artifacts
- Fit before: `previews/gallery/fit-audit/P##_fit_before.png`
- Fit after (primary): `previews/gallery/fit-audit/P##_fit_after.png`
- Gallery refreshes: `previews/gallery/P##_eyes.png`, `P##_mouths.png`, `P##_accessories.png`
- Samples: `previews/gallery/sample-fit-P01.png` … `sample-fit-P12.png`

## Remaining known quirks
1. **Glasses** are outlines over eyes — intentional; they can slightly thicken the eye silhouette at PFP size.
2. **Bandana** on front-facing pets covers lower face/mouth by design (mask wrap); ¾ pets use neck seat.
3. **P07 DRAKELET** head toppers (hat/crown/bow/party_hat/flower) now seat on the **crest/horn** via `ACC_SEAT`; bandana/bowtie stay on neck/chest.
4. **P12 hard-hat** punches a small antenna slot so the LED stalk remains readable; party cone / flower / bow attach to the antenna tip; bandana + bowtie on neck.
5. **P10 beak** attaches at the flat L face plate — tiny 1px seam possible at some beak variants when scaled.
6. **Headphones** cups are approximate side ovals; may not grip every silhouette equally (esp. BLOP bumps / HOPLIT ears).

## Zero Terminal Pets
No Terminal Pets (TP) art assets in this project.

## Regenerate traits only
```bash
python3 -c "import sys; sys.path.insert(0,'generator'); from build_pets import build_traits_only; print(build_traits_only())"
```

## Accessories cleanup (same day)
- Backpack removed everywhere (9 acc/pet).
- Flower = 5-petal bloom + yellow center; bowtie = two triangles + knot.
- Galleries: `P##_accessories.png` (none first; per-pet counts vary); fit-audit after refreshed.
