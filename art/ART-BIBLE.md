# Pocket Critter — Art Bible

Original generative NFT PFP system. Tamagotchi-*inspired* only — do not copy Tamagotchi characters or device designs. All assets are procedural code under `generator/`.

## Master canvas
- **2048 × 2048 px**, RGBA PNG layers, exact alignment
- Handheld centered; screen centered in handheld; pet inside screen
- Nothing important clipped

## Split identity (critical)

### Smooth (vector-like)
Handheld shell, buttons, antenna, shell class mark, pet ID plate, screen bezel:
- Clean rounded plastic toy; polished simple surfaces
- Draw at 4× then LANCZOS downscale (or supersampled ellipses)
- No pixelated outer edges; strong readable silhouette
- No realistic materials / heavy gradients / unnecessary detail

### Pixel (screen contents)
Pets, eggs, screen effects, hatch / egg-rock frames, screen wallpaper pixels:
- Designed on a **64 × 64** grid inside the screen inner rect
- Scale with **NEAREST** only, **uniform** integer pixel size: `ps = min(screen.w, screen.h) // 64` → always a square `(ps*64)×(ps*64)` bitmap
- Tall/wide screen wells **letterbox / pillarbox** (center the square); they do **not** squash pets or stretch axes independently
- Hard edges, limited palettes (~6 colors/body incl. outline), tight dark outline
- Must stay readable at PFP size

## Layer order (bottom → top)
See `schema/layer-order.json`. Summary:
1. background  
2. handheld_shape (neutral gray shaded; tinted at compose)  
3. shell_color (multiply/tint of `H##_mask.png`)  
4. shell_class (ALPHA / BETA / DELTA / OMEGA)  
5. pet_id (dynamic `PET #NNNN` — never baked into handheld)  
6. screen (bezel + inner well)  
   - Bezel sits **inside** the screen rect (outer = exact rect; well inset by pad); screen/FX/pet content is clipped to the handheld shell mask so nothing paints past the silhouette.  
7. screen_effect (pixel, **behind** pet)  
8–12. pet_body / pet_color / pet_eyes / pet_mouth / pet_accessory  
13. buttons  
14. antenna  

**Dormant:** replace pet layers with egg (+ optional rock anim).  
**Awaken:** may temporarily override `screen_effect`.

## Handheld family (10)
H01 Classic · H02 Rounded square · H03 Wide · H04 Tall · H05 Egg-shaped · H06 Capsule · H07 Compact · H08 Large rounded · H09 Retro toy (chunky trapezoid) · H10 Collector (asymmetry + top ridge).

Shared language: 3 circular buttons under screen, antenna nub on top, recessed screen well. Different *models* of one fictional device family.

Screen wells may be square or non-square; content uses `pixel_size = min(w,h)//64` (uniform square scale + letterbox). Anchors in `schema/anchors.json`.

## Shell colors (14 + optional neon)
white, black, light_gray, dark_gray, cream, pink, red, orange, yellow, purple, lavender, blue, light_blue, mint · optional neon_green `#39FF14`.

## Shell class (4)
ALPHA, BETA, DELTA, OMEGA — same retro-tech printed label language.

## Pet ID
Format `PET #NNNN`. `compose.py --pet-id`. Per-handheld anchor. Never baked into shell art.

## Buttons (8) / Antennas (10) / Screens (8) / FX (12) / Eggs (8) / Backgrounds (14)
Catalogued in `schema/traits.json`. Backgrounds use Robinhood-chain-inspired greens only: `#0B3D2E`, `#156B4A`, `#2FA36B`, `#7CFFB2` (+ mixes). No logos/trademarks.


## Buttons / anchors (placement rule)
- Each handheld has **3 circular buttons** under the screen, drawn at compose from `chip_*.png` using per-model centers in `schema/anchors.json`.
- **Hard rule:** every button disk (center + radius) must sit fully inside the opaque shell mask (`H##_mask.png`), below the screen well, with ≥~20px margin from the shell edge.
- Placement is model-aware: even spacing on rectangular shells; slightly tighter / lightly arched on egg (H05) and capsule (H06); H10 may be slightly off-center for asymmetry.
- **2026-09-15 fix:** H02 had no chin (perfect-square draw put buttons in empty space). H02 is now a squarish rounded rect with chin; button anchors recalculated for **all H01–H10** against live masks. Regenerate handhelds/buttons via `build_shell.py` after editing anchors.

## 12 pets
| ID | Name | Silhouette notes |
|----|------|------------------|
| P01 | PUDD | Round blob, stub feet; eyes high-center; acc on top |
| P02 | SNAG | Small dino ¾ left; eye on head; acc on crest |
| P03 | MEOWLET | Cat, triangle ears; wide eyes; acc between ears |
| P04 | PUPPO | ¾-front chubby puppy: matching floppy ears, clear projecting snout+nose in silhouette, short legs+paws, curled tail, collar ring; eyes above muzzle; mouth on muzzle; acc between ears |
| P05 | HOPLIT | Bunny, tall ears; acc clears ears |
| P06 | ZORP | Alien teardrop + stalks; huge eyes; acc on stalks |
| P07 | DRAKELET | Dragon ¾-left: elongated snout, horn, bat wing, curling tail, 4 stubby legs; eye on head; mouth on snout; neck acc clears horn |
| P08 | BLOP | Frog, eyes on top, wide low mouth |
| P09 | BRUMBLE | Bear, round ears |
| P10 | PIP | Bird: round head (no beak baked), flat L face, teardrop wings, crest, stick legs; mouth layer = beak; eye beside beak; acc on crest |
| P11 | GILLI | Axolotl: soft oval + 3 feathery branching gill fronds/side; wide eyes; crown acc keeps gills visible |
| P12 | BOLT | Cute virtual-pet robot (was NIB monster): square/rounded head, antenna LED, visor face, jointed arms, boot feet, chest bolt; eyes on visor; mouth on faceplate; acc on antenna/head. Folder remains `P12_nib` for path stability. |

Each: 8 species colors, 10 eyes, 10 mouths, accessories starting with **none** (no layer). Default set (10): none, hat, crown, bow, bandana, headphones, glasses, flower, bowtie, party_hat. Exceptions: P02/P10/P11 omit headphones (9); P07 DRAKELET is none+glasses only (2). Pet-specific coordinates (see anchors). Body without face/acc layers.

## Animations
- **Egg rock:** 8 frames, ~1.2s loop, tilt L/C/R a few px — `anim/egg_rock/`
- **Hatch:** 13 modular frames — `anim/hatch/` (no pet baked except preview GIF)

## Incompatibilities
Documented in `traits.json`:
- S03 wide vs H04/H06/H07
- S04 tall vs H03/H07
- S07 thick vs H07

## Generator
From the **repository root** (art vendored at `art/`). Box notes: live `/workspace/nft-pfp-art-system/`, lock `/home/box/terminal-pets-generative-art-lock/current/`.

```bash
pip install -r art/requirements.txt
python art/generator/build_assets.py    # regenerate all layers
python art/generator/compose.py --preview-sheet
python art/generator/compose.py --bg BG03 --handheld H01 --color cream --class ALPHA \
  --pet-id 421 --buttons yellow --antenna star --screen S01 --fx scanlines \
  --pet P02 --pet-color green --eyes happy --mouth smile --acc crown --out out.png
python art/generator/compose.py --dormant --egg E03 --rock --out egg.gif
```

## Provenance
100% original procedural art. **Zero** Terminal Pets / third-party stills used as sources or style references.
