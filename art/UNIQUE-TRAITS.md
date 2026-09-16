# Unique Traits Audit — Eyes / Mouths / Accessories

Date: 2026-09-15 (PT). Bodies locked (P04 PUPPO, P12 BOLT untouched). Zero Terminal Pets assets.

## Before — near-duplicate findings

### Eyes (critical)
Pixel-identical or near-identical pairs across most pets:

| Failure | Pets | Cause |
|---|---|---|
| `normal` ≡ `excited` | P01–P05, P07–P11 | At small sizes `s//3` == `s//2-1` → same pupil |
| `normal` ≈ `sparkly` | most | Sparkly only added 1–2 glint pixels |
| `sleepy` ≡ `wink` | P02 SNAG, P07 DRAKELET, P10 PIP | Single-eye path always `left=True`, wink drew same flat line |
| `sleepy` ≈ `tiny` | all | Sparse black-on-clear; tiny = 1px, sleepy = thin dash |
| `angry` ≈ `normal` | organic | Brow was a 1px top bar only |
| BOLT blues | P12 | Circles of similar size/color read as same LED |

### Mouths
| Failure | Pets |
|---|---|
| `frown` ≡ `sad` | P02, P07 snout; P08 BLOP |
| `funny` ≡ `open_smile` | P02, P07 snout; P08 BLOP |
| `angry`/`frown`/`sad` shared one beak | P10 PIP |
| `open_smile`/`surprised`/`laugh` shared one open beak | P10 PIP |

### Accessories
No near-duplicates found (phash). Left as-is.

## After — how each eye variant differs

IDs/filenames unchanged: `normal happy sleepy angry excited sparkly hearts wink tiny surprised`.

### Organic front pets (P01 PUDD, P03 MEOWLET, P04 PUPPO, P05 HOPLIT, P06 ZORP, P08 BLOP, P09 BRUMBLE, P11 GILLI)
Two eyes. BLOP still seats on top bulges; ZORP keeps huge ovals.

| Variant | Shape language |
|---|---|
| **normal** | Medium white sclera + medium pupil + corner glint |
| **happy** | Upward crescent `^` (closed smile) |
| **sleepy** | Heavy flat double-line lid |
| **angry** | Squinted sclera + thick inward brows (`\` `/`) |
| **excited** | Huge pupils filling the eye + raised brow ticks |
| **sparkly** | Medium open eye + external cyan/white star sparkles |
| **hearts** | Pink heart glyphs (scaled to eye size) |
| **wink** | Left downward-closed bump; right open (normal) |
| **tiny** | Single black pixel per eye |
| **surprised** | Oversized white circles + tiny pupil, no glint |

### Profile single-eye (P02 SNAG, P07 DRAKELET, P10 PIP)
One visible eye; wink must not equal sleepy.

| Variant | Shape language |
|---|---|
| **normal / excited / sparkly / surprised / hearts / tiny / angry / happy / sleepy** | Same organic language as front |
| **wink** | `>` chevron (not flat dash, not happy arc) |

### P12 BOLT — visor LED glyphs (paired)
| Variant | Glyph |
|---|---|
| **normal** | Solid 3×3 cyan squares + center white |
| **happy** | Upward cyan arcs |
| **sleepy** | Dim double-dash lids |
| **angry** | Red **X** |
| **excited** | Tall vertical cyan bars |
| **sparkly** | Cyan plus/star + corner highlights |
| **hearts** | Red LED hearts |
| **wink** | Left dash + right square |
| **tiny** | Single cyan pixel each |
| **surprised** | Hollow cyan square rings |

## Mouths fixed
- **Snout (P02/P07):** frown tip-down vs sad droop+tick; funny = zig-zag + pink (≠ open_smile rect).
- **BLOP (P08):** each variant own curve/aperture (smile curve, open box, zig-zag funny, sad dip+ticks, etc.).
- **PIP beak (P10):** smile / open_smile / laugh(+tongue) / surprised (taller O) / funny (lopsided open + pink tip) / tongue / frown (tip down) / sad (long droop) / angry (short dark wedge) / tiny — all distinct.
- Front mouths: `funny` now asymmetric zig-grin (≠ open oval).


## Mouths after-fix (2026-09-15 PT)

### Audit findings (before this pass)
- **P12 BOLT critical:** `smile` / `frown` / `sad` were 1px-deep cyan arcs on a cyan faceplate highlight → read as the same flat LED line in galleries.
- Organic front pets: `smile` ≈ `sad` (only ~4px XOR). Snout/PIP `open_smile` ≈ `laugh` (tongue-only delta, intentional but weak).

### Fixes
- **P12 `draw_robot_mouth`:** dark grill backing under every variant so LED glyphs punch through the locked faceplate; then distinct glyphs:
  - smile = 3-row U arc · frown = two separated dots + ticks · sad = gapped long dash + downturns
  - open_smile = toothy cyan columns · laugh = open rails + pink tongue · tiny = 1px
  - surprised = hollow O · tongue = dashed line + pink · angry = red notched bar
  - funny = jagged cyan + yellow spark
- **Organic front:** clearer U smile / inverted frown / deeper sad hang-ticks; tiny = 1px.
- **Snout (P02/P07):** smile tip-up vs frown tip-down vs sad double tear; larger laugh tongue.
- **BLOP / PIP:** larger laugh tongues so ≠ open_smile.

### Verification
- Zero exact-MD5 or near-identical mouths within each of 12 pets.
- Eye PNG MD5s unchanged (spot P01/P04/P12). Bodies P04/P12 unchanged.
- Galleries: `previews/gallery/P##_mouths.png`; fit-audit mouth rows refreshed.
- Zero Terminal Pets art.

## Mouths labeling pass (2026-09-15 PT)

### Fixes
- **P12 BOLT:** swapped visual content of `tongue` ↔ `laugh` (filenames unchanged). `tongue` = open rails + pink fill; `laugh` = dashed cyan + pink under.
- **P08 BLOP:** swapped visual content of `smile` ↔ `frown` so upturned = smile, downturned = frown. Redesigned `sad` as deep open droop (top corners high, bottom bowl, dark fill, hanging ticks + blue tear) — distinct from smile/frown/angry/open_smile.
- **P10 PIP:** reworked `draw_beak` so each mouth id is primarily a **distinct beak color** (tip still LEFT at flat L face):
  - smile = classic orange/yellow · open_smile = brighter yellow · frown = muted gray-brown
  - tiny = pale cream · surprised = pinkish · tongue = orange + pink accent
  - angry = deep crimson · laugh = warm coral + tongue · sad = blue-gray · funny = lime

### Verification
- P08/P10/P12: all 10 mouths unique MD5s each.
- Eyes unchanged (spot-check P08/P10/P12 eye MD5s). Bodies unchanged including locked P04 `20ddaaab…` / P12 `d2be3a74…`.
- Galleries: `previews/gallery/P08_mouths.png`, `P10_mouths.png`, `P12_mouths.png`; fit-audit mouth rows refreshed.
- Zero Terminal Pets art.


## Mouth refine pass — BLOP sad + PIP laugh (2026-09-15 PT)

### P08 BLOP `sad`
Redesigned as a **closed** deep frown line (no open black fill, no tear). Wider/deeper downturn than `frown` (lower center, steeper outer drop, longer hanging end ticks). MD5-distinct from frown/smile/angry/all other BLOP mouths.

### P10 PIP `laugh`
Reworked as a **wider open** coral beak with a clear dark gap (open_smile-like upper/lower split) plus a small pink tongue in the gap. Stays coral/warm-pink family; tip still LEFT at flat L face. Distinct from bright-yellow `open_smile`.

### Verification
- Only `layers/pets/P08_blop/mouths/sad.png` and `layers/pets/P10_pip/mouths/laugh.png` changed among mouth files.
- P08 and P10: all 10 mouths unique MD5s each.
- Eyes and bodies for P08/P10 unchanged.
- Galleries: `previews/gallery/P08_mouths.png`, `P10_mouths.png`
- Reviews: `previews/gallery/review_P08_sad.png`, `review_P10_laugh.png`
- Zero Terminal Pets art.

## Regeneration
- `build_traits_only()` → 120 eyes, 120 mouths, 108 accessories (9×12; backpack removed); **0 bodies**.
- Galleries refreshed: `previews/gallery/P##_eyes.png` (primary), mouths, accessories.
- Fit audit: `previews/gallery/fit-audit/P##_fit_after.png` (eyes/mouths/acc rows).

## Body MD5 (unchanged)
| File | MD5 |
|---|---|
| `layers/pets/P04_puppo/body.png` | `20ddaaab3fd438985e94e1efafef327d` |
| `layers/pets/P04_puppo/body_tintable.png` | `54e812bab252a3b68755ba8ea5169260` |
| `layers/pets/P12_nib/body.png` | `d2be3a7468ef0f7f9ea088ec6c7b8882` |
| `layers/pets/P12_nib/body_tintable.png` | `f19ed0fd3096fec2ad66035de0b9f778` |

## Biggest eye overhauls
1. **Profile pets P02/P07/P10** — wink was pixel-identical to sleepy; now chevron.
2. **All organic** — normal≡excited eliminated; sparkly/surprised/angry given strong shape diffs.
3. **P12 BOLT** — LED glyph set (squares / arcs / dashes / X / bars / plus / hearts / rings / dots).

## Zero TP
No Terminal Pets art introduced or referenced.

## Accessories pass (2026-09-15 PT) — backpack removed + flower/bowtie redesign

### Removed
- **backpack** deleted from all 12 pets: PNG files, `schema/traits.json` lists, `ACC_COLORS` / `ACC_SEAT` / draw branches (organic + BOLT).
- Result: **9 accessories** per pet — `hat, crown, bow, bandana, headphones, glasses, flower, bowtie, party_hat`.

### Global redesign
- **flower:** five discrete petal lobes + small yellow center (+ stem tip). Not a vague blob.
- **bowtie:** classic two-triangle wings + dark center knot on chest/neck.

### Per-pet reseat + redraw (flagged items)
| Pet | Fixed accessories |
|---|---|
| P01 PUDD | bandana, headphones, bowtie, flower |
| P02 SNAG | headphones |
| P03 MEOWLET | bandana, headphones, bowtie, flower |
| P04 PUPPO | bandana, headphones, bowtie, flower |
| P05 HOPLIT | bandana, bowtie, flower |
| P06 ZORP | bandana, bowtie, flower |
| P07 DRAKELET | hat, crown, bow, bandana, headphones, flower, party_hat (¾ crest seats; not torso) |
| P08 BLOP | bandana, bowtie, flower |
| P09 BRUMBLE | bandana, bowtie, flower |
| P10 PIP | bandana, headphones, bowtie, flower, party_hat |
| P11 GILLI | bandana, headphones, bowtie, flower |
| P12 BOLT | bow, bandana, flower, party_hat (robot glyphs OK; still read as items) |

Flower + bowtie redesigned for **all 12** (including unflagged).

### Galleries
- `previews/gallery/P01_accessories.png` … `P12_accessories.png` (9 cells each, no backpack)
- Fit-audit accessory rows: `previews/gallery/fit-audit/P##_fit_after.png`

### Verification
- No `backpack.png` under `layers/pets/`
- 9 unique MD5 accessories per pet
- Bodies / eyes / mouths / colors unchanged; locked P04 `20ddaaab…` / P12 `d2be3a74…` intact

## Accessories pass (2026-09-15 PT) — `none` + headphones removals + DRAKELET slim

### Schema (`schema/traits.json`)
- **`none` first** on every pet (P01–P12).
- Final lists:
  - **P01, P03, P04, P05, P06, P08, P09, P12:** none, hat, crown, bow, bandana, headphones, glasses, flower, bowtie, party_hat (**10**)
  - **P02 SNAG, P10 PIP, P11 GILLI:** none, hat, crown, bow, bandana, glasses, flower, bowtie, party_hat (**9**, no headphones)
  - **P07 DRAKELET:** none, glasses (**2**)

### Build / compose
- `build_pets.py`: `kind == "none"` → transparent 64×64 `none.png` (never calls `draw_accessory`).
- `ACC_SEAT`: headphones seats removed for P02/P10/P11; P07 unused crown seats cleared.
- `compose.py`: skips accessory layer when `acc == "none"` or accessory PNG is fully transparent.

### Removals
- Deleted `headphones.png` under P02 / P10 / P11.
- P07 accessories folder: only `none.png` + `glasses.png`.

### Galleries
- `previews/gallery/P01_accessories.png` … `P12_accessories.png` (labeled **none** cell first; DRAKELET sheet = none + glasses only).

### Verification
- Bodies / eyes / mouths unchanged; locked P04 / P12 bodies intact.

