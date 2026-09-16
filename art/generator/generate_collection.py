#!/usr/bin/env python3
"""Generate Terminal Pets NFT collection — animated GIFs + ERC-721 metadata.

Weighted rolls via rarity.pick_weighted + schema/traits.json.
Awake pet GIF: animated screen FX (make_fx_frame loop, 10×120ms @ 512).
Matching egg GIF: same device traits, dormant egg-rock (rock_frame offsets).
Token IDs are 1-indexed. Unique DNA via reject-until-unique (max retries).

Outputs per token N:
  art/N.gif, metadata/N.json, egg/N.gif, egg-metadata/N.json
"""
from __future__ import annotations

import argparse
import json
import random
import sys
import time
from pathlib import Path
from typing import Any

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import LAYERS, load_json, new_canvas  # noqa: E402
from rarity import (  # noqa: E402
    TIER_WEIGHTS,
    as_option,
    option_id,
    option_rarity,
    pick_weighted,
)
from compose import (  # noqa: E402
    EGG_MAP,
    FX_MAP,
    PET_FOLDERS,
    clip_to_handheld_mask,
    compose_device_shell,
    egg_id_for_pet,
    place_pixel_clipped_to_well,
    place_pixel_fit_in_well,
)
from build_pets import make_fx_frame  # noqa: E402

COLLECTION_NAME = "Terminal Pet"
EGG_COLLECTION_NAME = "Terminal Pet Egg"
DEFAULT_DESCRIPTION = (
    "A Terminal Pet generative PFP — awake critter on a handheld device with "
    "animated screen FX. Egg trait records the matching hatch egg for this pet species."
)
EGG_DESCRIPTION = (
    "A dormant Terminal Pet egg on a matching handheld device, gently rocking. "
    "Same token id as the awakened pet NFT."
)
MAX_DNA_RETRIES = 500
PROGRESS_EVERY_DEFAULT = 25

# GIF export (pixel look, manageable size)
GIF_SIZE = 512  # NEAREST downscale from 2048 canvas
PET_GIF_FRAMES = 10
PET_GIF_DURATION_MS = 120
EGG_ROCK_OFFSETS = [0, -2, -3, -1, 0, 2, 3, 1]  # same as compose_one / build_egg_rock
EGG_GIF_DURATION_MS = 150
GIF_COLORS = 128

# DNA / metadata trait keys in stable order (egg follows pet, not independently rolled)
DNA_KEYS = (
    "pet",
    "egg",
    "pet_color",
    "eyes",
    "mouth",
    "accessory",
    "background",
    "handheld",
    "shell_color",
    "shell_class",
    "buttons",
    "antenna",
    "screen",
    "fx",
)


def _pet_options(traits: dict) -> list[dict]:
    opts = []
    for pid, meta in (traits.get("pets") or {}).items():
        opts.append(
            {
                "id": pid,
                "name": meta.get("name"),
                "rarity": meta.get("rarity", "common"),
                "weight": meta.get("weight", TIER_WEIGHTS["common"]),
            }
        )
    return opts


def _display_name(opt: Any, fallback_id: str | None = None) -> str:
    o = as_option(opt) if not isinstance(opt, str) else {"id": opt}
    return o.get("name") or o.get("id") or (fallback_id or "")


def _find_by_id(options: list, oid: str) -> dict | None:
    for opt in options:
        if option_id(opt) == oid:
            return as_option(opt)
    return None


def handheld_screen_incompatible(handheld: str, screen: str, traits: dict) -> str | None:
    """Return reason string if incompatible, else None."""
    for rule in traits.get("incompatibilities", []):
        rs = rule.get("screen", "")
        rs_prefix = rs.split("_")[0] if "_" in rs else rs
        if screen == rs or screen == rs_prefix or rs.startswith(screen) or screen.startswith(rs_prefix):
            if handheld in rule.get("handheld", []):
                return rule.get("reason") or "incompatible"
    return None


def compatible_screens(handheld: str, screens: list, traits: dict) -> list:
    ok = []
    for s in screens:
        sid = option_id(s)
        if handheld_screen_incompatible(handheld, sid, traits) is None:
            ok.append(s)
    return ok or list(screens)


def roll_traits(traits: dict, rng: random.Random) -> dict[str, Any]:
    """Weighted trait roll in required order. Egg locked to pet."""
    pets = _pet_options(traits)
    pet_opt = pick_weighted(pets, rng)
    pet_id = option_id(pet_opt)
    pet_meta = traits["pets"][pet_id]

    egg_id = egg_id_for_pet(pet_id, traits)
    egg_opt = _find_by_id(traits.get("eggs", []), egg_id) or {"id": egg_id}

    pet_color_opt = as_option(pick_weighted(pet_meta.get("colors", []), rng))
    eyes_opt = as_option(pick_weighted(pet_meta.get("eyes", []), rng))
    mouth_opt = as_option(pick_weighted(pet_meta.get("mouths", []), rng))
    acc_opt = as_option(pick_weighted(pet_meta.get("accessories", []), rng))

    bg_opt = as_option(pick_weighted(traits["backgrounds"], rng))
    hh_opt = as_option(pick_weighted(traits["handhelds"], rng))
    shell_color_opt = as_option(pick_weighted(traits["shell_colors"], rng))
    shell_class_opt = as_option(pick_weighted(traits["shell_class"], rng))
    buttons_opt = as_option(pick_weighted(traits["buttons"], rng))
    antenna_opt = as_option(pick_weighted(traits["antennas"], rng))

    screens = compatible_screens(option_id(hh_opt), traits["screens"], traits)
    screen_opt = as_option(pick_weighted(screens, rng))
    fx_opt = as_option(pick_weighted(traits["screen_effects"], rng))

    return {
        "pet": pet_id,
        "pet_name_species": pet_meta.get("name", pet_id),
        "pet_rarity": option_rarity(pet_opt) or pet_meta.get("rarity"),
        "egg": egg_id,
        "egg_name": egg_opt.get("name", egg_id),
        "egg_rarity": egg_opt.get("rarity"),
        "pet_color": option_id(pet_color_opt),
        "pet_color_rarity": pet_color_opt.get("rarity"),
        "eyes": option_id(eyes_opt),
        "eyes_rarity": eyes_opt.get("rarity"),
        "mouth": option_id(mouth_opt),
        "mouth_rarity": mouth_opt.get("rarity"),
        "accessory": option_id(acc_opt),
        "accessory_rarity": acc_opt.get("rarity"),
        "background": option_id(bg_opt),
        "background_name": bg_opt.get("name", option_id(bg_opt)),
        "background_rarity": bg_opt.get("rarity"),
        "handheld": option_id(hh_opt),
        "handheld_name": hh_opt.get("name", option_id(hh_opt)),
        "handheld_rarity": hh_opt.get("rarity"),
        "shell_color": option_id(shell_color_opt),
        "shell_color_rarity": shell_color_opt.get("rarity"),
        "shell_class": option_id(shell_class_opt),
        "shell_class_rarity": shell_class_opt.get("rarity"),
        "buttons": option_id(buttons_opt),
        "buttons_rarity": buttons_opt.get("rarity"),
        "antenna": option_id(antenna_opt),
        "antenna_rarity": antenna_opt.get("rarity"),
        "screen": option_id(screen_opt),
        "screen_name": screen_opt.get("name", option_id(screen_opt)),
        "screen_rarity": screen_opt.get("rarity"),
        "fx": option_id(fx_opt),
        "fx_rarity": fx_opt.get("rarity"),
    }


def dna_string(rolled: dict) -> str:
    return "|".join(f"{k}:{rolled[k]}" for k in DNA_KEYS)


def _common_attrs(rolled: dict) -> list[dict]:
    return [
        {"trait_type": "Pet", "value": rolled["pet_name_species"]},
        {"trait_type": "Pet ID", "value": rolled["pet"]},
        {"trait_type": "Pet Rarity", "value": (rolled.get("pet_rarity") or "common").title()},
        {"trait_type": "Egg", "value": rolled.get("egg_name") or rolled["egg"]},
        {"trait_type": "Egg ID", "value": rolled["egg"]},
        {"trait_type": "Egg Rarity", "value": (rolled.get("egg_rarity") or "common").title()},
        {"trait_type": "Pet Color", "value": rolled["pet_color"]},
        {"trait_type": "Eyes", "value": rolled["eyes"]},
        {"trait_type": "Mouth", "value": rolled["mouth"]},
        {"trait_type": "Accessory", "value": rolled["accessory"]},
        {"trait_type": "Background", "value": rolled.get("background_name") or rolled["background"]},
        {"trait_type": "Handheld", "value": rolled.get("handheld_name") or rolled["handheld"]},
        {"trait_type": "Shell Color", "value": rolled["shell_color"]},
        {"trait_type": "Shell Class", "value": rolled["shell_class"]},
        {"trait_type": "Buttons", "value": rolled["buttons"]},
        {"trait_type": "Antenna", "value": rolled["antenna"]},
        {"trait_type": "Screen", "value": rolled.get("screen_name") or rolled["screen"]},
        {"trait_type": "FX", "value": rolled["fx"]},
    ]


def _rarity_block(rolled: dict) -> dict:
    return {
        "pet": rolled.get("pet_rarity"),
        "egg": rolled.get("egg_rarity"),
        "pet_color": rolled.get("pet_color_rarity"),
        "eyes": rolled.get("eyes_rarity"),
        "mouth": rolled.get("mouth_rarity"),
        "accessory": rolled.get("accessory_rarity"),
        "background": rolled.get("background_rarity"),
        "handheld": rolled.get("handheld_rarity"),
        "shell_color": rolled.get("shell_color_rarity"),
        "shell_class": rolled.get("shell_class_rarity"),
        "buttons": rolled.get("buttons_rarity"),
        "antenna": rolled.get("antenna_rarity"),
        "screen": rolled.get("screen_rarity"),
        "fx": rolled.get("fx_rarity"),
    }


def build_metadata(token_id: int, rolled: dict, image_filename: str) -> dict:
    """ERC-721 style pet metadata (awake GIF)."""
    return {
        "name": f"{COLLECTION_NAME} #{token_id}",
        "description": DEFAULT_DESCRIPTION,
        "image": image_filename,
        "pet_id": str(token_id),
        "egg_id": str(token_id),
        "dna": dna_string(rolled),
        "animation": {
            "type": "fx",
            "frames": PET_GIF_FRAMES,
            "duration_ms": PET_GIF_DURATION_MS,
            "size": GIF_SIZE,
        },
        "attributes": _common_attrs(rolled)
        + [{"trait_type": "State", "value": "Lit"}],
        "rarity": _rarity_block(rolled),
        "traits": {k: rolled[k] for k in DNA_KEYS},
    }


def build_egg_metadata(token_id: int, rolled: dict, image_filename: str) -> dict:
    """ERC-721 style egg metadata; same token id as matching pet."""
    return {
        "name": f"{EGG_COLLECTION_NAME} #{token_id}",
        "description": EGG_DESCRIPTION,
        "image": image_filename,
        "egg_id": str(token_id),
        "pet_id": str(token_id),
        "linked_pet_id": str(token_id),
        "dna": dna_string(rolled),
        "animation": {
            "type": "egg_rock",
            "frames": len(EGG_ROCK_OFFSETS),
            "duration_ms": EGG_GIF_DURATION_MS,
            "size": GIF_SIZE,
        },
        "attributes": _common_attrs(rolled)
        + [{"trait_type": "State", "value": "Dormant"}],
        "rarity": _rarity_block(rolled),
        "traits": {k: rolled[k] for k in DNA_KEYS},
    }


def make_compose_args(token_id: int, rolled: dict):
    return argparse.Namespace(
        bg=rolled["background"],
        handheld=rolled["handheld"],
        color=rolled["shell_color"],
        class_name=rolled["shell_class"],
        pet_id=str(token_id),
        buttons=rolled["buttons"],
        antenna=rolled["antenna"],
        screen=rolled["screen"],
        fx=rolled["fx"],
        pet=rolled["pet"],
        pet_color=rolled["pet_color"],
        eyes=rolled["eyes"],
        mouth=rolled["mouth"],
        acc=rolled["accessory"],
        dormant=False,
        pet_name="",
        egg=rolled["egg"],
        rock_frame=None,
        strict=False,
        fx_image=None,
    )


def _save_gif(frames: list[Image.Image], out_path: Path, duration_ms: int) -> None:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    quantized = [
        fr.convert("P", palette=Image.ADAPTIVE, colors=GIF_COLORS) for fr in frames
    ]
    quantized[0].save(
        out_path,
        save_all=True,
        append_images=quantized[1:],
        duration=duration_ms,
        loop=0,
        disposal=2,
    )


def _build_pet_layer(args, ha, traits) -> Image.Image:
    """64→well placed awake pet stack (body/eyes/mouth/acc)."""
    folder = LAYERS / "pets" / PET_FOLDERS[args.pet]
    col_path = folder / "colors" / f"{args.pet_color}.png"
    if col_path.exists():
        body = Image.open(col_path).convert("RGBA")
    else:
        body = Image.open(folder / "body.png").convert("RGBA")
    layer = new_canvas()
    layer.alpha_composite(place_pixel_fit_in_well(body, ha, args.screen, traits))
    eyes = Image.open(folder / "eyes" / f"{args.eyes}.png").convert("RGBA")
    layer.alpha_composite(place_pixel_fit_in_well(eyes, ha, args.screen, traits))
    mouth = Image.open(folder / "mouths" / f"{args.mouth}.png").convert("RGBA")
    layer.alpha_composite(place_pixel_fit_in_well(mouth, ha, args.screen, traits))
    if args.acc and args.acc != "none":
        acc_path = folder / "accessories" / f"{args.acc}.png"
        if acc_path.exists():
            acc = Image.open(acc_path).convert("RGBA")
            if acc.getbbox() is not None:
                layer.alpha_composite(
                    place_pixel_fit_in_well(acc, ha, args.screen, traits)
                )
    return layer


def compose_pet_gif(
    args,
    out_path: Path,
    *,
    n_frames: int = PET_GIF_FRAMES,
    duration_ms: int = PET_GIF_DURATION_MS,
    size: int = GIF_SIZE,
) -> Path:
    """Awake pet on device with animated screen FX (make_fx_frame loop).

    Device shell composed once; FX regenerated per frame. Output 512×512 NEAREST.
    """
    anchors = load_json("anchors.json")
    traits = load_json("traits.json")
    ha = anchors["handhelds"][args.handheld]
    screen = ha["screen"]

    shell = compose_device_shell(args)
    pet_layer = _build_pet_layer(args, ha, traits)

    frames: list[Image.Image] = []
    for i in range(n_frames):
        canvas = shell.copy()
        content = new_canvas()
        fx = make_fx_frame(args.fx, frame=i)
        content.alpha_composite(
            place_pixel_clipped_to_well(fx, screen, ha, args.screen, traits)
        )
        content.alpha_composite(pet_layer)
        canvas.alpha_composite(clip_to_handheld_mask(content, args.handheld))
        fr_small = canvas.resize((size, size), Image.Resampling.NEAREST)
        frames.append(fr_small)

    out_path = Path(out_path)
    _save_gif(frames, out_path, duration_ms)
    return out_path


def compose_egg_rock_gif(
    args,
    out_path: Path,
    *,
    duration_ms: int = EGG_GIF_DURATION_MS,
    size: int = GIF_SIZE,
) -> Path:
    """Dormant matching egg on same device traits, rocking via rock_frame offsets.

    Static FX (dormant look); 8 rock offsets matching compose_one / build_egg_rock.
    """
    anchors = load_json("anchors.json")
    traits = load_json("traits.json")
    ha = anchors["handhelds"][args.handheld]
    screen = ha["screen"]

    shell = compose_device_shell(args)
    egg_file = EGG_MAP.get(args.egg, "E01_pudd_cream.png")
    egg = Image.open(LAYERS / "eggs" / egg_file).convert("RGBA")
    fx_name = FX_MAP.get(args.fx, FX_MAP["scanlines"])
    fx_static = Image.open(LAYERS / "screen_effects" / fx_name).convert("RGBA")
    fx_placed = place_pixel_clipped_to_well(fx_static, screen, ha, args.screen, traits)

    frames: list[Image.Image] = []
    for i, ox in enumerate(EGG_ROCK_OFFSETS):
        canvas = shell.copy()
        content = new_canvas()
        content.alpha_composite(fx_placed)
        rocked = Image.new("RGBA", egg.size, (0, 0, 0, 0))
        rocked.paste(egg, (ox, 0), egg)
        content.alpha_composite(
            place_pixel_fit_in_well(rocked, ha, args.screen, traits)
        )
        canvas.alpha_composite(clip_to_handheld_mask(content, args.handheld))
        fr_small = canvas.resize((size, size), Image.Resampling.NEAREST)
        frames.append(fr_small)

    out_path = Path(out_path)
    _save_gif(frames, out_path, duration_ms)
    return out_path


def load_manifest(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return {"version": 1, "tokens": {}, "dna": {}}


def save_manifest(path: Path, manifest: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2) + "\n")


def save_dna_index(path: Path, dna_map: dict[str, int]) -> None:
    """dna -> token_id for resume / uniqueness."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(dna_map, indent=2) + "\n")


def roll_unique(
    traits: dict,
    rng: random.Random,
    seen_dna: set[str],
    max_retries: int = MAX_DNA_RETRIES,
) -> tuple[dict, str]:
    for attempt in range(1, max_retries + 1):
        rolled = roll_traits(traits, rng)
        dna = dna_string(rolled)
        if dna not in seen_dna:
            return rolled, dna
    raise RuntimeError(
        f"Could not find unique DNA after {max_retries} retries "
        f"(seen={len(seen_dna)})"
    )


def join_asset_uri(base: str, filename: str) -> str:
    """Prefix a GIF filename with an IPFS/HTTP base, or return the bare filename."""
    if not base:
        return filename
    if base.endswith("/"):
        return base + filename
    return f"{base}/{filename}"


def generate_token(
    token_id: int,
    traits: dict,
    rng: random.Random,
    seen_dna: set[str],
    out_art: Path,
    out_metadata: Path,
    out_egg: Path,
    out_egg_metadata: Path,
    art_image_base: str = "",
    egg_image_base: str = "",
) -> dict:
    rolled, dna = roll_unique(traits, rng, seen_dna)
    seen_dna.add(dna)

    img_name = f"{token_id}.gif"
    meta_name = f"{token_id}.json"
    art_path = out_art / img_name
    meta_path = out_metadata / meta_name
    egg_path = out_egg / img_name
    egg_meta_path = out_egg_metadata / meta_name

    for d in (out_art, out_metadata, out_egg, out_egg_metadata):
        d.mkdir(parents=True, exist_ok=True)

    args = make_compose_args(token_id, rolled)
    compose_pet_gif(args, art_path)
    compose_egg_rock_gif(args, egg_path)

    meta = build_metadata(token_id, rolled, join_asset_uri(art_image_base, img_name))
    egg_meta = build_egg_metadata(token_id, rolled, join_asset_uri(egg_image_base, img_name))
    meta_path.write_text(json.dumps(meta, indent=2) + "\n")
    egg_meta_path.write_text(json.dumps(egg_meta, indent=2) + "\n")

    return {
        "token_id": token_id,
        "dna": dna,
        "image": str(art_path),
        "metadata": str(meta_path),
        "egg": str(egg_path),
        "egg_metadata": str(egg_meta_path),
        "traits": {k: rolled[k] for k in DNA_KEYS},
        "bytes": art_path.stat().st_size + egg_path.stat().st_size,
        "art_bytes": art_path.stat().st_size,
        "egg_bytes": egg_path.stat().st_size,
    }


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Generate Terminal Pets NFT collection (animated GIFs + metadata)"
    )
    p.add_argument("--count", type=int, default=4444, help="How many tokens to generate")
    p.add_argument("--start", type=int, default=1, help="Starting token ID (1-indexed)")
    p.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Cap tokens generated this run (test runs); overrides effective end",
    )
    p.add_argument(
        "--out-art",
        type=Path,
        required=True,
        help="Directory for awake pet {id}.gif",
    )
    p.add_argument(
        "--out-metadata", type=Path, required=True, help="Directory for pet {id}.json"
    )
    p.add_argument(
        "--out-egg",
        type=Path,
        required=True,
        help="Directory for egg rock {id}.gif",
    )
    p.add_argument(
        "--out-egg-metadata",
        type=Path,
        required=True,
        help="Directory for egg {id}.json",
    )
    p.add_argument("--seed", type=int, default=None, help="RNG seed for reproducibility")
    p.add_argument(
        "--resume",
        action="store_true",
        help="Skip tokens already fully exported; continue DNA set",
    )
    p.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="Path to manifest.json (default: sibling of out-metadata)",
    )
    p.add_argument(
        "--dna-file",
        type=Path,
        default=None,
        help="Path to _dna.json (default: sibling of out-metadata)",
    )
    p.add_argument(
        "--progress-every",
        type=int,
        default=PROGRESS_EVERY_DEFAULT,
        help="Log progress every N tokens",
    )
    p.add_argument(
        "--max-retries",
        type=int,
        default=MAX_DNA_RETRIES,
        help="Max DNA collision retries per token",
    )
    p.add_argument(
        "--gif-size",
        type=int,
        default=GIF_SIZE,
        help=f"GIF edge length (default {GIF_SIZE}; NEAREST from 2048)",
    )
    p.add_argument(
        "--art-image-base",
        default="",
        help="Prefix for awake metadata image (e.g. ipfs://CID/ or https://host/art/)",
    )
    p.add_argument(
        "--egg-image-base",
        default="",
        help="Prefix for egg metadata image (e.g. ipfs://CID/ or https://host/egg/)",
    )
    return p.parse_args(argv)


def _token_complete(
    tid: int,
    out_art: Path,
    out_metadata: Path,
    out_egg: Path,
    out_egg_metadata: Path,
) -> bool:
    return (
        (out_art / f"{tid}.gif").exists()
        and (out_metadata / f"{tid}.json").exists()
        and (out_egg / f"{tid}.gif").exists()
        and (out_egg_metadata / f"{tid}.json").exists()
    )


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    global GIF_SIZE
    if args.gif_size != GIF_SIZE:
        GIF_SIZE = args.gif_size

    traits = load_json("traits.json")

    out_art = args.out_art
    out_metadata = args.out_metadata
    out_egg = args.out_egg
    out_egg_metadata = args.out_egg_metadata
    for d in (out_art, out_metadata, out_egg, out_egg_metadata):
        d.mkdir(parents=True, exist_ok=True)

    # Clear leftover PNGs in these export dirs (old PNG path)
    for d in (out_art, out_egg):
        for png in d.glob("*.png"):
            png.unlink()
            print(f"  removed leftover PNG {png}")

    manifest_path = args.manifest or (out_metadata.parent / "manifest.json")
    dna_path = args.dna_file or (out_metadata.parent / "_dna.json")

    start = args.start
    end_exclusive = start + args.count
    if args.limit is not None:
        end_exclusive = min(end_exclusive, start + args.limit)
    token_ids = list(range(start, end_exclusive))

    rng = random.Random(args.seed)

    manifest = (
        load_manifest(manifest_path)
        if args.resume
        else {"version": 1, "tokens": {}, "dna": {}, "format": "gif"}
    )
    if args.resume and dna_path.exists():
        dna_index = {k: int(v) for k, v in json.loads(dna_path.read_text()).items()}
    else:
        dna_index = {d: int(tid) for d, tid in (manifest.get("dna") or {}).items()}
        for tid_s, entry in (manifest.get("tokens") or {}).items():
            d = entry.get("dna")
            if d:
                dna_index[d] = int(tid_s)

    seen_dna: set[str] = set(dna_index.keys())

    pending = []
    for tid in token_ids:
        if args.resume and _token_complete(
            tid, out_art, out_metadata, out_egg, out_egg_metadata
        ):
            if str(tid) not in (manifest.get("tokens") or {}):
                try:
                    meta = json.loads((out_metadata / f"{tid}.json").read_text())
                    d = meta.get("dna")
                    if d:
                        seen_dna.add(d)
                        dna_index[d] = tid
                        manifest.setdefault("tokens", {})[str(tid)] = {
                            "dna": d,
                            "traits": meta.get("traits"),
                        }
                except Exception:
                    pass
            continue
        pending.append(tid)

    seed_info = args.seed if args.seed is not None else "(random)"
    print(
        f"Terminal Pets GIF collection export: tokens {start}..{end_exclusive - 1} "
        f"({len(token_ids)} requested, {len(pending)} to generate), "
        f"seed={seed_info}, resume={args.resume}"
    )
    print(
        f"  GIFs: pet {PET_GIF_FRAMES}f×{PET_GIF_DURATION_MS}ms, "
        f"egg {len(EGG_ROCK_OFFSETS)}f×{EGG_GIF_DURATION_MS}ms, "
        f"size={GIF_SIZE}×{GIF_SIZE} NEAREST"
    )
    print(f"  art          → {out_art}")
    print(f"  metadata     → {out_metadata}")
    print(f"  egg          → {out_egg}")
    print(f"  egg-metadata → {out_egg_metadata}")
    print(f"  manifest     → {manifest_path}")
    print(f"  dna          → {dna_path}")

    t0 = time.time()
    generated = 0
    total_bytes = 0
    errors: list[str] = []

    for i, tid in enumerate(pending, 1):
        try:
            result = generate_token(
                tid,
                traits,
                rng,
                seen_dna,
                out_art,
                out_metadata,
                out_egg,
                out_egg_metadata,
                art_image_base=args.art_image_base,
                egg_image_base=args.egg_image_base,
            )
        except Exception as e:
            msg = f"token {tid}: {e}"
            errors.append(msg)
            print(f"ERROR {msg}", file=sys.stderr)
            continue

        dna_index[result["dna"]] = tid
        manifest.setdefault("tokens", {})[str(tid)] = {
            "dna": result["dna"],
            "traits": result["traits"],
            "bytes": result["bytes"],
            "art_bytes": result["art_bytes"],
            "egg_bytes": result["egg_bytes"],
        }
        manifest.setdefault("dna", {})[result["dna"]] = tid
        generated += 1
        total_bytes += result["bytes"]

        if i % max(1, args.progress_every) == 0 or i == len(pending):
            elapsed = time.time() - t0
            rate = generated / elapsed if elapsed > 0 else 0
            eta = (len(pending) - i) / rate if rate > 0 else 0
            print(
                f"  [{i}/{len(pending)}] token #{tid}  "
                f"art={result['art_bytes']/1024:.1f} KiB "
                f"egg={result['egg_bytes']/1024:.1f} KiB  "
                f"{rate:.2f} tok/s  ETA {eta/60:.1f}m  "
                f"unique_dna={len(seen_dna)}"
            )
            manifest["seed"] = args.seed
            manifest["count"] = args.count
            manifest["start"] = start
            manifest["generated"] = len(manifest.get("tokens") or {})
            manifest["format"] = "gif"
            manifest["gif"] = {
                "size": GIF_SIZE,
                "pet_frames": PET_GIF_FRAMES,
                "pet_duration_ms": PET_GIF_DURATION_MS,
                "egg_frames": len(EGG_ROCK_OFFSETS),
                "egg_duration_ms": EGG_GIF_DURATION_MS,
            }
            save_manifest(manifest_path, manifest)
            save_dna_index(dna_path, dna_index)

    elapsed = time.time() - t0
    manifest["seed"] = args.seed
    manifest["count"] = args.count
    manifest["start"] = start
    manifest["generated"] = len(manifest.get("tokens") or {})
    manifest["format"] = "gif"
    manifest["gif"] = {
        "size": GIF_SIZE,
        "pet_frames": PET_GIF_FRAMES,
        "pet_duration_ms": PET_GIF_DURATION_MS,
        "egg_frames": len(EGG_ROCK_OFFSETS),
        "egg_duration_ms": EGG_GIF_DURATION_MS,
    }
    manifest["last_run"] = {
        "generated_this_run": generated,
        "elapsed_sec": round(elapsed, 2),
        "errors": errors,
    }
    save_manifest(manifest_path, manifest)
    save_dna_index(dna_path, dna_index)

    print(
        f"Done. generated={generated} errors={len(errors)} "
        f"elapsed={elapsed:.1f}s avg={elapsed/max(generated,1):.2f}s/tok "
        f"gif_bytes≈{total_bytes/1e6:.2f} MB"
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
