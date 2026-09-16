#!/usr/bin/env python3
"""Compose Pocket Critter NFT PFPs from modular layers. CLI entrypoint."""
from __future__ import annotations
import argparse
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    ROOT, LAYERS, SCHEMA, ANIM, PREVIEWS, CANVAS, new_canvas, load_json,
    hex_to_rgb, hex_to_rgba, multiply_mask, scale_pixel_to_screen,
    paste_at, paste_center, get_font
)

HANDHELD_FILES = {
    "H01": "H01_classic.png", "H02": "H02_rounded_square.png", "H03": "H03_wide.png",
    "H04": "H04_tall.png", "H05": "H05_egg.png", "H06": "H06_capsule.png",
    "H07": "H07_compact.png", "H08": "H08_large.png", "H09": "H09_retro.png",
    "H10": "H10_collector.png",
}
SCREEN_FILES = {s["id"]: s["file"] for s in load_json("traits.json")["screens"]}
FX_MAP = {
    "static": "FX01_static.png", "scanlines": "FX02_scanlines.png",
    "sparkles": "FX03_sparkles.png", "stars": "FX04_stars.png",
    "bubbles": "FX05_bubbles.png", "lightning": "FX06_lightning.png",
    "pixel_rain": "FX07_pixel_rain.png", "glitch": "FX08_glitch.png",
    "clouds": "FX09_clouds.png", "fire": "FX10_fire.png",
    "leaves": "FX11_leaves.png", "digital_grid": "FX12_digital_grid.png",
}
ANTENNA_MAP = {
    "classic": "A01_classic.png", "star": "A02_star.png", "heart": "A03_heart.png",
    "lightning": "A04_lightning.png", "flower": "A05_flower.png", "spiral": "A06_spiral.png",
    "double": "A07_double.png", "mushroom": "A08_mushroom.png", "crown": "A09_crown.png",
    "orb": "A10_orb.png",
}
CLASS_MAP = {"ALPHA": "alpha.png", "BETA": "beta.png", "DELTA": "delta.png", "OMEGA": "omega.png"}
# Baked shell_class art is authored for this default anchor (H01 content top=1487).
# Do NOT use the live H01 shell_class y — it may move for layout clearance.
DEFAULT_SHELL_CLASS_XY = (1024, 1555)
BG_MAP = {b["id"]: b["file"] for b in load_json("traits.json")["backgrounds"]}
EGG_MAP = {e["id"]: e["file"] for e in load_json("traits.json")["eggs"]}
PET_FOLDERS = {pid: m["folder"] for pid, m in load_json("traits.json")["pets"].items()}

def check_compat(handheld, screen, traits):
    for rule in traits.get("incompatibilities", []):
        if rule.get("screen") == screen or rule.get("screen", "").startswith(screen):
            # allow S03 or S03_wide style
            sid = rule["screen"].split("_")[0] if "_" in rule["screen"] else rule["screen"]
            if screen == sid or screen == rule["screen"]:
                if handheld in rule.get("handheld", []):
                    return rule["reason"]
        # also match by id prefix
        rs = rule.get("screen", "")
        if screen in rs or rs.startswith(screen):
            if handheld in rule.get("handheld", []):
                return rule["reason"]
    # normalize: traits use S03_wide etc
    for rule in traits.get("incompatibilities", []):
        rs = rule["screen"]
        if rs.startswith(screen) or screen.startswith(rs.split("_")[0]):
            if handheld in rule["handheld"]:
                return rule["reason"]
    return None

def render_pet_id(text: str, anchor: dict) -> Image.Image:
    layer = new_canvas()
    d = ImageDraw.Draw(layer)
    font = get_font(22)
    label = f"PET #{text.zfill(4)}"
    x, y = anchor["x"], anchor["y"]
    # plate
    bbox = d.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    d.rounded_rectangle([x - tw//2 - 10, y - th//2 - 6, x + tw//2 + 10, y + th//2 + 6],
                        radius=6, fill=(35, 38, 45, 220))
    d.text((x, y), label, font=font, fill=(180, 255, 200, 255), anchor="mm")
    return layer

def _truncate_pet_name(name: str, max_len: int = 14) -> str:
    name = (name or "").strip()
    if not name:
        return ""
    if len(name) <= max_len:
        return name
    return name[: max_len - 3] + "..."


def render_pet_name(name: str, well_rect: dict) -> Image.Image:
    """Pixel-readable custom name inside the screen well, lower-left corner.

    Dark plate + light text (with outline) so it reads on dark or light wells.
    Clipped by caller to the same well mask as FX/pet. Not the shell Pet ID plate.
    """
    label = _truncate_pet_name(name)
    layer = new_canvas()
    if not label:
        return layer
    d = ImageDraw.Draw(layer)
    # Scale font to well size — keep small/readable on 2048 canvas
    well_h = max(64, int(well_rect.get("h", 400)))
    # Readable at full 2048 and after gallery downscale (~0.2x)
    font_size = max(24, min(48, well_h // 15))
    font = get_font(font_size)
    bbox = d.textbbox((0, 0), label, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    inset = max(6, well_h // 40)
    # lower-left inside well
    x0 = int(well_rect["x"]) + inset
    y1 = int(well_rect["y"]) + int(well_rect["h"]) - inset
    y0 = y1 - th
    pad_x, pad_y = 6, 4
    # dark plate
    d.rounded_rectangle(
        [x0 - pad_x, y0 - pad_y, x0 + tw + pad_x, y0 + th + pad_y],
        radius=4,
        fill=(20, 22, 28, 200),
    )
    # outline then fill for readability
    tx, ty = x0, y0 - bbox[1]  # compensate textbbox top offset
    for ox, oy in ((-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)):
        d.text((tx + ox, ty + oy), label, font=font, fill=(10, 12, 16, 255))
    d.text((tx, ty), label, font=font, fill=(220, 255, 230, 255))
    return layer



def draw_buttons_at(color_id: str, buttons: list) -> Image.Image:
    traits = load_json("traits.json")
    hexcol = next(b["hex"] for b in traits["buttons"] if b["id"] == color_id)
    chip_path = LAYERS / "buttons" / f"chip_{color_id}.png"
    layer = new_canvas()
    if chip_path.exists():
        chip = Image.open(chip_path).convert("RGBA")
        for b in buttons:
            # scale chip to 2*r
            r = b["r"]
            sized = chip.resize((r*2, r*2), Image.Resampling.LANCZOS)
            paste_center(layer, sized, b["x"], b["y"])
    else:
        d = ImageDraw.Draw(layer)
        rgb = hex_to_rgb(hexcol)
        for b in buttons:
            cx, cy, r = b["x"], b["y"], b["r"]
            d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(*rgb, 255), outline=(40,40,45,255), width=3)
    return layer

def reposition_from_default(src: Image.Image, default_xy, target_xy) -> Image.Image:
    """Translate layer so content at default anchor moves to target."""
    dx = target_xy[0] - default_xy[0]
    dy = target_xy[1] - default_xy[1]
    out = new_canvas()
    out.alpha_composite(src, (dx, dy))
    return out

def place_pixel_in_screen(px64: Image.Image, screen: dict) -> Image.Image:
    """Uniform-scale pixel art then center (letterbox/pillarbox) in screen rect."""
    layer = new_canvas()
    scaled = scale_pixel_to_screen(px64, screen)
    x = screen["x"] + (screen["w"] - scaled.width) // 2
    y = screen["y"] + (screen["h"] - scaled.height) // 2
    paste_at(layer, scaled, x, y)
    return layer


def clip_to_handheld_mask(layer: Image.Image, handheld_id: str) -> Image.Image:
    """Multiply layer alpha by handheld mask so nothing paints past the shell silhouette."""
    mask = Image.open(LAYERS / "handhelds" / f"{handheld_id}_mask.png").convert("L")
    r, g, b, a = layer.split()
    a = ImageChops.multiply(a, mask)
    out = Image.merge("RGBA", (r, g, b, a))
    return out


# Pad / radius must match build_screen_for styles (before clamp).
_SCREEN_PAD = {
    "S01": 30, "S02": 30, "S03": 28, "S04": 26,
    "S05": 40, "S06": 28, "S07": 52, "S08": 7,
}
_SCREEN_RAD = {
    "S01": 8, "S02": 52, "S03": 18, "S04": 14,
    "S05": 14, "S06": 20, "S07": 22, "S08": 8,
}


def _screen_outer_box(ha, screen_id):
    """Outer bezel box {x,y,w,h} centered in the handheld screen rect (S03/S04 aspect)."""
    scr = ha["screen"]
    sx, sy, sw, sh = scr["x"], scr["y"], scr["w"], scr["h"]
    if screen_id == "S03":
        bw, bh = sw, max(64, round(sw * 826 / 906))
    elif screen_id == "S04":
        bw, bh = max(64, round(sh * 826 / 906)), sh
    else:
        bw, bh = sw, sh
    return {
        "x": sx + (sw - bw) // 2,
        "y": sy + (sh - bh) // 2,
        "w": bw,
        "h": bh,
    }


def _clamped_screen_pad(bw: int, bh: int, screen_id: str) -> int:
    """Same pad clamp as build_screen_for."""
    pad = _SCREEN_PAD.get(screen_id, 28)
    pad = min(pad, bw // 4, bh // 4)
    if bw > 64 and bh > 64:
        pad = min(pad, (bw - 64) // 2, (bh - 64) // 2)
    return max(4, pad)


def screen_well_rect(ha, screen_id, traits=None) -> dict:
    """Inner well {x,y,w,h,rad} matching build_screen_for geometry.

    traits is accepted for API symmetry but geometry comes from screen_id styles.
    S08 minimal uses the hairline gap inset (not the thick pad).
    """
    box = _screen_outer_box(ha, screen_id)
    x, y, bw, bh = box["x"], box["y"], box["w"], box["h"]
    pad = _clamped_screen_pad(bw, bh, screen_id)
    rad = _SCREEN_RAD.get(screen_id, 8)
    if screen_id == "S08":
        gap = max(2, pad // 3)
        outer_rad = min(rad + 6, bw // 2, bh // 2)
        return {
            "x": x + gap,
            "y": y + gap,
            "w": bw - 2 * gap,
            "h": bh - 2 * gap,
            "rad": max(2, outer_rad - gap),
        }
    inner_w = bw - 2 * pad
    inner_h = bh - 2 * pad
    inner_rad = min(rad, max(4, inner_w // 2), max(4, inner_h // 2))
    return {"x": x + pad, "y": y + pad, "w": inner_w, "h": inner_h, "rad": inner_rad}


def screen_well_mask(ha, screen_id, traits=None) -> Image.Image:
    """Full-canvas L mask: 255 inside the rounded inner well, 0 elsewhere."""
    well = screen_well_rect(ha, screen_id, traits)
    mask = Image.new("L", (CANVAS, CANVAS), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(
        [well["x"], well["y"], well["x"] + well["w"] - 1, well["y"] + well["h"] - 1],
        radius=well["rad"],
        fill=255,
    )
    return mask


def clip_to_screen_well(layer: Image.Image, ha, screen_id, traits=None) -> Image.Image:
    """Multiply layer alpha by the rounded well mask so FX/pets never paint the bezel."""
    mask = screen_well_mask(ha, screen_id, traits)
    r, g, b, a = layer.split()
    a = ImageChops.multiply(a, mask)
    return Image.merge("RGBA", (r, g, b, a))


def place_pixel_clipped_to_well(px64: Image.Image, screen: dict, ha, screen_id, traits=None) -> Image.Image:
    """Place 64px art into the full screen rect, then clip to the rounded well.

    Prefer for FX / full-well coverage. Pet stack should use place_pixel_fit_in_well.
    """
    return clip_to_screen_well(place_pixel_in_screen(px64, screen), ha, screen_id, traits)


def _well_content_inset(well: dict, inset=None) -> int:
    """Safety inset so rounded corners / bezel never shave pet tips."""
    mw = min(int(well["w"]), int(well["h"]))
    if inset is not None:
        return max(0, int(inset))
    # ~3% of well, clamped 8–16px, plus ~30% of corner radius for round-rect bite
    pct = max(8, min(16, round(mw * 0.03)))
    corner = max(0, int(round(well.get("rad", 0) * 0.30)))
    return max(pct, corner, 8)


def place_pixel_fit_in_well(
    px64: Image.Image, ha, screen_id, traits=None, inset=None
) -> Image.Image:
    """Uniform-scale 64px art to fit entirely inside the inner well (letterbox/pillarbox).

    Same scale for any 64×64 layer (body/eyes/mouth/acc/egg) so they stay aligned.
    A small safety inset keeps tips clear of rounded corners; well mask still applied
    as a belt-and-suspenders clip (should be ~0 crop when inset is enough).
    """
    well = screen_well_rect(ha, screen_id, traits)
    ins = _well_content_inset(well, inset)
    # Ensure at least 64px of target room; shrink inset if well is tiny
    max_ins_w = max(0, (int(well["w"]) - 64) // 2)
    max_ins_h = max(0, (int(well["h"]) - 64) // 2)
    ins = min(ins, max_ins_w, max_ins_h) if (max_ins_w > 0 and max_ins_h > 0) else 0
    tw = int(well["w"]) - 2 * ins
    th = int(well["h"]) - 2 * ins
    ps = min(tw // 64, th // 64)
    if ps < 1:
        ps = 1
    side = ps * 64
    scaled = px64.resize((side, side), Image.Resampling.NEAREST)
    layer = new_canvas()
    x = int(well["x"]) + (int(well["w"]) - side) // 2
    y = int(well["y"]) + (int(well["h"]) - side) // 2
    paste_at(layer, scaled, x, y)
    return clip_to_screen_well(layer, ha, screen_id, traits)

def compose_one(args) -> Image.Image:
    anchors = load_json("anchors.json")
    traits = load_json("traits.json")
    ha = anchors["handhelds"][args.handheld]
    screen = ha["screen"]

    # incompatibility warning (still compose unless --strict)
    reason = check_compat(args.handheld, args.screen, traits)
    if reason and getattr(args, "strict", False):
        raise SystemExit(f"Incompatible: {reason}")

    canvas = new_canvas()

    # 1 background
    bg = Image.open(LAYERS / "backgrounds" / BG_MAP[args.bg]).convert("RGBA")
    canvas.alpha_composite(bg)

    # 2 handheld shape
    hh = Image.open(LAYERS / "handhelds" / HANDHELD_FILES[args.handheld]).convert("RGBA")
    canvas.alpha_composite(hh)

    # 3 shell color tint via mask
    color_hex = next(c["hex"] for c in traits["shell_colors"] if c["id"] == args.color)
    mask = Image.open(LAYERS / "handhelds" / f"{args.handheld}_mask.png").convert("RGBA")
    tint = multiply_mask(mask, color_hex)
    # multiply-ish: blend tint over handheld with soft light using mask alpha
    # Use Image.composite approach: tinted shell at 55% over existing
    tinted_soft = Image.blend(Image.new("RGBA", (CANVAS, CANVAS), (0,0,0,0)), tint, 0.55)
    canvas.alpha_composite(tinted_soft)

    # Better: replace shell body color by compositing tint under shading details
    # Rebuild: bg + tinted mask + shaded handheld with multiply feel
    # Simpler approach used: colorize mask fully then overlay handheld shading with alpha from luminance
    shell_colored = multiply_mask(mask, color_hex)
    # extract shading from handheld (darken)
    shade_layer = hh.copy()
    # composite: colored shell then shading on top with multiply simulation
    base = new_canvas()
    base.alpha_composite(bg)
    base.alpha_composite(shell_colored)
    # use handheld as overlay — keep edges/recess; multiply RGB where opaque
    hpx = hh.load()
    bpx = base.load()
    for y in range(0, CANVAS, 1):
        # optimize: only bbox region
        pass
    # Faster multiply using PIL
    # Put colored shell, then multiply handheld gray shading onto it via ImageChops
    from PIL import ImageChops, ImageEnhance
    canvas = new_canvas()
    canvas.alpha_composite(bg)
    canvas.alpha_composite(shell_colored)
    # Multiply handheld onto canvas where handheld has alpha
    hh_rgb = hh.convert("RGB")
    # Create a multiply blend only on shell pixels
    canvas_rgb = canvas.convert("RGB")
    mult = ImageChops.multiply(canvas_rgb, hh_rgb)
    # mix: use handheld alpha to blend mult with canvas
    alpha = hh.split()[-1]
    mult_rgba = mult.convert("RGBA")
    mult_rgba.putalpha(alpha)
    # darken multiply a bit then composite
    canvas.alpha_composite(Image.blend(shell_colored, mult_rgba, 0.65))
    # re-composite handheld edge details lightly
    edge = hh.copy()
    ep = edge.load()
    for yy in range(CANVAS):
        for xx in range(0, CANVAS):
            break  # too slow — skip pixel loop
        break

    # Practical approach: colored mask + handheld shading at 0.75 opacity
    canvas = new_canvas()
    canvas.alpha_composite(bg)
    canvas.alpha_composite(shell_colored)
    # reduce handheld opacity for shading overlay
    hh_shade = hh.copy()
    bands = list(hh_shade.split())
    bands[3] = bands[3].point(lambda a: int(a * 0.55))
    hh_shade = Image.merge("RGBA", bands)
    canvas.alpha_composite(hh_shade)

    # 4–10 screen + FX + pet/egg — build on a content layer, clip to shell silhouette
    content = new_canvas()
    content.alpha_composite(build_screen_for(ha, args.screen, traits))

    # 7 screen effect (behind pet) — place in screen rect, then well-mask (no bezel spill)
    if getattr(args, "fx_image", None) is not None:
        fx = args.fx_image.convert("RGBA")
    else:
        fx_name = FX_MAP.get(args.fx, FX_MAP["scanlines"])
        fx = Image.open(LAYERS / "screen_effects" / fx_name).convert("RGBA")
    content.alpha_composite(place_pixel_clipped_to_well(fx, screen, ha, args.screen, traits))

    # 8-12 pet or egg — fit entirely inside well (no bezel crop)
    if args.dormant:
        egg_file = EGG_MAP.get(args.egg, "E01_pudd_cream.png")
        egg = Image.open(LAYERS / "eggs" / egg_file).convert("RGBA")
        # Rock the matching egg (same offsets as build_egg_rock) so every pet egg rocks.
        if args.rock_frame is not None:
            offsets = [0, -2, -3, -1, 0, 2, 3, 1]
            ox = offsets[int(args.rock_frame) % len(offsets)]
            rocked = Image.new("RGBA", egg.size, (0, 0, 0, 0))
            rocked.paste(egg, (ox, 0), egg)
            egg = rocked
        content.alpha_composite(place_pixel_fit_in_well(egg, ha, args.screen, traits))
    else:
        folder = LAYERS / "pets" / PET_FOLDERS[args.pet]
        # body color
        col_path = folder / "colors" / f"{args.pet_color}.png"
        if col_path.exists():
            body = Image.open(col_path).convert("RGBA")
        else:
            body = Image.open(folder / "body.png").convert("RGBA")
        content.alpha_composite(place_pixel_fit_in_well(body, ha, args.screen, traits))
        eyes = Image.open(folder / "eyes" / f"{args.eyes}.png").convert("RGBA")
        content.alpha_composite(place_pixel_fit_in_well(eyes, ha, args.screen, traits))
        mouth = Image.open(folder / "mouths" / f"{args.mouth}.png").convert("RGBA")
        content.alpha_composite(place_pixel_fit_in_well(mouth, ha, args.screen, traits))
        # acc="none" (or missing/empty transparent layer) => no accessory composite
        if args.acc and args.acc != "none":
            acc_path = folder / "accessories" / f"{args.acc}.png"
            if acc_path.exists():
                acc = Image.open(acc_path).convert("RGBA")
                # skip fully empty / transparent accessory files
                if acc.getbbox() is not None:
                    content.alpha_composite(place_pixel_fit_in_well(acc, ha, args.screen, traits))

        # Custom owner name — inside screen well, lower-left (woken pets only)
        pet_name = getattr(args, "pet_name", None) or ""
        if pet_name:
            well = screen_well_rect(ha, args.screen, traits)
            name_layer = render_pet_name(pet_name, well)
            content.alpha_composite(clip_to_screen_well(name_layer, ha, args.screen, traits))

    content = clip_to_handheld_mask(content, args.handheld)
    canvas.alpha_composite(content)

    # 11 buttons (under labels so chips never cover shell_class / pet_id)
    canvas.alpha_composite(draw_buttons_at(args.buttons, ha["buttons"]))

    # 12 shell class (after buttons)
    cls = Image.open(LAYERS / "shell_class" / CLASS_MAP[args.class_name.upper()]).convert("RGBA")
    cls = reposition_from_default(cls, DEFAULT_SHELL_CLASS_XY,
                                  (ha["shell_class"]["x"], ha["shell_class"]["y"]))
    canvas.alpha_composite(cls)

    # 13 pet id (after buttons / class)
    canvas.alpha_composite(render_pet_id(str(args.pet_id), ha["pet_id"]))

    # 14 antenna
    ant = Image.open(LAYERS / "antennas" / ANTENNA_MAP[args.antenna]).convert("RGBA")
    def_ant = anchors["handhelds"]["H01"]["antenna"]
    ant = reposition_from_default(ant, (def_ant["x"], def_ant["y"]),
                                  (ha["antenna"]["x"], ha["antenna"]["y"]))
    canvas.alpha_composite(ant)

    return canvas

def _shade_rgba(rgba, factor):
    r, g, b, a = rgba
    return (
        max(0, min(255, int(r * factor))),
        max(0, min(255, int(g * factor))),
        max(0, min(255, int(b * factor))),
        a,
    )


def _draw_gem(d, cx, cy, r, fill, highlight=None, outline=None):
    """Small gem/rivet/LED on the bezel band (never into the well)."""
    fill = fill if len(fill) == 4 else (*fill, 255)
    hi = highlight or _shade_rgba(fill, 1.35)
    ol = outline or _shade_rgba(fill, 0.45)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=ol, width=max(1, r // 4))
    hr = max(1, r // 3)
    d.ellipse(
        [cx - r // 2 - 1, cy - r // 2 - 1, cx - r // 2 - 1 + hr * 2, cy - r // 2 - 1 + hr * 2],
        fill=hi,
    )


def _bezel_midpoints(x, y, bw, bh, pad):
    """Centers along each bezel side, midway through the pad band."""
    mid = pad // 2
    return [
        (x + bw // 2, y + mid),
        (x + bw // 2, y + bh - mid),
        (x + mid, y + bh // 2),
        (x + bw - mid, y + bh // 2),
    ]


def _bezel_corners(x, y, bw, bh, pad, inset=None):
    """Corner centers on the bezel band."""
    if inset is None:
        inset = max(pad // 2, 8)
    if pad > 4:
        inset = min(inset, pad - 2)
    inset = max(4, inset)
    return [
        (x + inset, y + inset),
        (x + bw - inset, y + inset),
        (x + inset, y + bh - inset),
        (x + bw - inset, y + bh - inset),
    ]


def build_screen_for(ha, screen_id, traits):
    """Draw a screen bezel and well fitted inside the handheld screen rect.

    Each S01–S08 has a clearly distinct color / decoration language so traits
    read apart at a glance. Wide/tall keep authored proportions; everything
    stays wholly inside the live screen anchor. Decorations sit on the bezel
    band only — never covering the inner well where the pet sits.
    """
    meta = next(s for s in traits["screens"] if s["id"] == screen_id)
    img = new_canvas()
    d = ImageDraw.Draw(img)
    scr = ha["screen"]
    sx, sy, sw, sh = scr["x"], scr["y"], scr["w"], scr["h"]

    # Wide/tall stay centered inside the live anchor (no spill past screen rect).
    if screen_id == "S03":
        bw, bh = sw, max(64, round(sw * 826 / 906))
    elif screen_id == "S04":
        bw, bh = max(64, round(sh * 826 / 906)), sh
    else:
        bw, bh = sw, sh
    x = sx + (sw - bw) // 2
    y = sy + (sh - bh) // 2
    # PIL rounded_rectangle coords are inclusive; use right/bottom = last pixel inside.
    R = x + bw - 1
    B = y + bh - 1

    styles = {
        "S01": {  # Classic — warm vintage plastic (olive/khaki), square-ish, 3D inset
            "pad": 30, "rad": 8,
            "bezel": (158, 138, 78, 255),   # warm olive / khaki — not cool charcoal
            "well": (22, 20, 16, 255),
            "look": "classic3d",
        },
        "S02": {  # Rounded — soft pastel lavender, very round
            "pad": 30, "rad": 52,
            "bezel": (186, 160, 220, 255),
            "well": (22, 20, 32, 255),
            "look": "lavender",
        },
        "S03": {  # Wide — gold / chrome metallic + corner gems
            "pad": 28, "rad": 18,
            "bezel": (196, 148, 48, 255),
            "well": (18, 22, 28, 255),
            "look": "gold",
        },
        "S04": {  # Tall — neon cyan/teal cyber
            "pad": 26, "rad": 14,
            "bezel": (0, 200, 190, 255),
            "well": (8, 18, 24, 255),
            "look": "cyber",
        },
        "S05": {  # Dark Well — near-black matte + deepest well + obvious LEDs + glow rim
            "pad": 40, "rad": 14,
            "bezel": (10, 10, 12, 255),
            "well": (1, 1, 3, 255),
            "look": "dark_led",
        },
        "S06": {  # Light Well — pearl/cream bezel + light well
            "pad": 28, "rad": 20,
            "bezel": (232, 220, 200, 255),
            "well": (210, 220, 215, 255),
            "look": "pearl",
        },
        "S07": {  # Thick — chunky rose-gold/magenta + gems/rivets
            "pad": 52, "rad": 22,
            "bezel": (186, 72, 118, 255),
            "well": (18, 22, 28, 255),
            "look": "jeweled",
        },
        "S08": {  # Minimal — vivid ice-blue hairline, almost no fill mass
            "pad": 7, "rad": 8,
            "bezel": (100, 235, 255, 255),  # ice-blue — leaves gray/black family
            "well": (14, 18, 24, 255),
            "look": "minimal",
        },
    }
    st = dict(styles.get(screen_id, styles["S01"]))
    if meta["well"] == "light" and screen_id != "S05":
        st["well"] = (210, 220, 215, 255)

    pad = st["pad"]
    pad = min(pad, bw // 4, bh // 4)
    if bw > 64 and bh > 64:
        pad = min(pad, (bw - 64) // 2, (bh - 64) // 2)
    pad = max(4, pad)

    bezel = st["bezel"]
    well = st["well"]
    rad = st["rad"]
    outer_rad = min(rad + 6, bw // 2, bh // 2)
    inner_w = bw - 2 * pad
    inner_h = bh - 2 * pad
    inner_rad = min(rad, max(4, inner_w // 2), max(4, inner_h // 2))
    look = st["look"]

    ix0, iy0 = x + pad, y + pad
    ix1, iy1 = R - pad, B - pad  # inclusive well corners

    if look == "minimal":
        # Tiny outer gap (shell shows through) + vivid ice-blue hairline; almost no fill mass.
        gap = max(2, pad // 3)
        wx0, wy0 = x + gap, y + gap
        wx1, wy1 = R - gap, B - gap
        gap_rad = max(2, outer_rad - gap)
        d.rounded_rectangle([wx0, wy0, wx1, wy1], radius=gap_rad, fill=well)
        # Soft outer halo so the line pops at gallery size
        halo = (*bezel[:3], 90)
        d.rounded_rectangle(
            [wx0 - 1, wy0 - 1, wx1 + 1, wy1 + 1],
            radius=max(2, gap_rad + 1),
            outline=halo,
            width=2,
        )
        line_w = max(2, pad // 2 + 1)
        d.rounded_rectangle(
            [wx0, wy0, wx1, wy1],
            radius=gap_rad,
            outline=bezel,
            width=line_w,
        )
        # Bright inner edge for extra pop
        hi = (230, 250, 255, 255)
        d.rounded_rectangle(
            [wx0 + line_w, wy0 + line_w, wx1 - line_w, wy1 - line_w],
            radius=max(2, gap_rad - line_w),
            outline=hi,
            width=1,
        )
        return img

    d.rounded_rectangle([x, y, R, B], radius=outer_rad, fill=bezel)

    if look == "classic3d":
        # Warm vintage plastic 3D inset: light top-left, dark bottom-right lip.
        hi = (210, 195, 150, 255)       # warm highlight
        mid = (170, 155, 110, 255)
        shd = (70, 58, 36, 255)         # deep warm shadow
        lip = max(3, pad // 5)
        # Outer soft rim
        d.rounded_rectangle(
            [x + 1, y + 1, R - 1, B - 1],
            radius=max(2, outer_rad - 1),
            outline=mid,
            width=2,
        )
        # Strong TL highlight band
        d.line([(x + lip, y + lip), (R - lip, y + lip)], fill=hi, width=lip)
        d.line([(x + lip, y + lip), (x + lip, B - lip)], fill=hi, width=lip)
        # Strong BR shadow band
        d.line([(x + lip, B - lip), (R - lip, B - lip)], fill=shd, width=lip)
        d.line([(R - lip, y + lip), (R - lip, B - lip)], fill=shd, width=lip)
        # Inner inset ring just outside the well (on bezel band)
        d.rounded_rectangle(
            [ix0 - 3, iy0 - 3, ix1 + 3, iy1 + 3],
            radius=min(inner_rad + 4, max(4, (inner_w + 6) // 2)),
            outline=shd,
            width=2,
        )
        d.rounded_rectangle(
            [ix0 - 5, iy0 - 5, ix1 + 5, iy1 + 5],
            radius=min(inner_rad + 6, max(4, (inner_w + 10) // 2)),
            outline=hi,
            width=2,
        )

    elif look == "lavender":
        hi = (230, 214, 245, 255)
        soft = _shade_rgba(bezel, 0.78)
        d.rounded_rectangle([x + 3, y + 3, R - 3, B - 3], radius=max(4, outer_rad - 4), outline=hi, width=4)
        d.rounded_rectangle(
            [ix0 - 4, iy0 - 4, ix1 + 4, iy1 + 4],
            radius=min(inner_rad + 6, max(4, (inner_w + 8) // 2)),
            outline=soft,
            width=3,
        )

    elif look == "gold":
        hi = (255, 230, 150, 255)
        lo = (120, 80, 20, 255)
        d.rounded_rectangle([x + 1, y + 1, R - 1, B - 1], radius=max(2, outer_rad - 1), outline=lo, width=3)
        d.rounded_rectangle([x + 4, y + 4, R - 4, B - 4], radius=max(2, outer_rad - 3), outline=hi, width=3)
        gem_r = max(5, min(pad // 3, 12))
        gem_colors = [
            (80, 180, 255, 255),
            (255, 90, 120, 255),
            (120, 255, 160, 255),
            (255, 210, 80, 255),
        ]
        for (cx, cy), gc in zip(_bezel_corners(x, y, bw, bh, pad), gem_colors):
            _draw_gem(d, cx, cy, gem_r, gc)

    elif look == "cyber":
        hi = (180, 255, 250, 255)
        lo = (0, 90, 100, 255)
        neon = (0, 255, 230, 255)
        d.rounded_rectangle([x + 1, y + 1, R - 1, B - 1], radius=max(2, outer_rad - 1), outline=hi, width=4)
        d.rounded_rectangle(
            [ix0 - 3, iy0 - 3, ix1 + 3, iy1 + 3],
            radius=min(inner_rad + 4, max(4, (inner_w + 6) // 2)),
            outline=lo,
            width=2,
        )
        tick = max(8, pad - 4)
        thick = max(2, pad // 6)
        for cx, cy in _bezel_corners(x, y, bw, bh, pad, inset=pad // 2):
            d.rectangle([cx - tick // 2, cy - thick // 2, cx + tick // 2, cy + thick // 2], fill=neon)
            d.rectangle([cx - thick // 2, cy - tick // 2, cx + thick // 2, cy + tick // 2], fill=neon)

    elif look == "dark_led":
        # Near-black matte frame edge
        d.rounded_rectangle(
            [x + 1, y + 1, R - 1, B - 1],
            radius=max(2, outer_rad - 1),
            outline=(36, 36, 42, 255),
            width=2,
        )
        # Thin glowing inner rim just outside the well (screams gaming screen)
        # Keep rim fully on the bezel band (pad >= 5px clearance).
        glow_outer = (80, 0, 20, 200)
        glow_mid = (200, 20, 40, 230)
        glow_hi = (255, 70, 90, 255)
        rim_out = min(6, max(3, pad // 7))
        rim_r = min(inner_rad + rim_out, max(4, (inner_w + 2 * rim_out) // 2))
        d.rounded_rectangle(
            [ix0 - rim_out, iy0 - rim_out, ix1 + rim_out, iy1 + rim_out],
            radius=rim_r,
            outline=glow_outer,
            width=4,
        )
        d.rounded_rectangle(
            [ix0 - max(2, rim_out - 2), iy0 - max(2, rim_out - 2),
             ix1 + max(2, rim_out - 2), iy1 + max(2, rim_out - 2)],
            radius=min(inner_rad + 3, max(4, (inner_w + 6) // 2)),
            outline=glow_mid,
            width=3,
        )
        d.rounded_rectangle(
            [ix0 - 1, iy0 - 1, ix1 + 1, iy1 + 1],
            radius=min(inner_rad + 1, max(4, (inner_w + 2) // 2)),
            outline=glow_hi,
            width=2,
        )
        # Large bright corner LEDs (RGB + amber) with glow — clamped inside screen rect
        # Sized to stay glanceable after gallery downscale (~0.2x).
        halo_extra = 4
        led_r = max(12, min(pad // 2 - halo_extra - 1, 18))
        # Push centers inward so LED + halo never leave [x,y]–[R,B]
        led_inset = led_r + halo_extra + 1
        led_palette = [
            ((255, 30, 40, 255), (255, 160, 160, 255)),   # red
            ((40, 220, 80, 255), (180, 255, 200, 255)),    # green
            ((40, 140, 255, 255), (160, 210, 255, 255)),   # blue
            ((255, 180, 30, 255), (255, 230, 140, 255)),   # amber
        ]
        for (cx, cy), (led, led_hi) in zip(
            _bezel_corners(x, y, bw, bh, pad, inset=led_inset), led_palette
        ):
            hr = led_r + halo_extra
            d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=(*led[:3], 70))
            hr2 = led_r + 1
            d.ellipse([cx - hr2, cy - hr2, cx + hr2, cy + hr2], fill=(*led[:3], 140))
            _draw_gem(d, cx, cy, led_r, led, highlight=led_hi, outline=_shade_rgba(led, 0.35))

    elif look == "pearl":
        hi = (255, 250, 240, 255)
        shd = (180, 160, 140, 255)
        d.rounded_rectangle([x + 2, y + 2, R - 2, B - 2], radius=max(2, outer_rad - 2), outline=hi, width=3)
        d.rounded_rectangle(
            [ix0 - 3, iy0 - 3, ix1 + 3, iy1 + 3],
            radius=min(inner_rad + 4, max(4, (inner_w + 6) // 2)),
            outline=shd,
            width=2,
        )

    elif look == "jeweled":
        lo = (110, 30, 70, 255)
        hi = (255, 170, 200, 255)
        d.rounded_rectangle([x + 1, y + 1, R - 1, B - 1], radius=max(2, outer_rad - 1), outline=lo, width=4)
        d.rounded_rectangle([x + 5, y + 5, R - 5, B - 5], radius=max(2, outer_rad - 4), outline=hi, width=3)
        gem_r = max(6, min(pad // 4, 14))
        gem_palette = [
            (255, 220, 100, 255),
            (180, 230, 255, 255),
            (255, 140, 200, 255),
            (160, 255, 190, 255),
            (255, 200, 140, 255),
            (200, 160, 255, 255),
            (255, 120, 120, 255),
            (140, 200, 255, 255),
        ]
        spots = _bezel_corners(x, y, bw, bh, pad) + _bezel_midpoints(x, y, bw, bh, pad)
        for i, (cx, cy) in enumerate(spots):
            _draw_gem(d, cx, cy, gem_r, gem_palette[i % len(gem_palette)])

    # Punch inner well last so decorations never cover the pet area.
    d.rounded_rectangle([ix0, iy0, ix1, iy1], radius=inner_rad, fill=well)

    if look == "classic3d":
        # Deep inset shadow into the well edge
        d.rounded_rectangle([ix0, iy0, ix1, iy1], radius=inner_rad, outline=(40, 32, 18, 200), width=3)
        d.line([(ix0 + 4, iy0 + 2), (ix1 - 4, iy0 + 2)], fill=(0, 0, 0, 100), width=2)
        d.line([(ix0 + 2, iy0 + 4), (ix0 + 2, iy1 - 4)], fill=(0, 0, 0, 80), width=2)
    elif look == "pearl":
        d.rounded_rectangle(
            [ix0 + 1, iy0 + 1, ix1 - 1, iy1 - 1],
            radius=max(2, inner_rad - 1),
            outline=(255, 255, 255, 80),
            width=2,
        )
    elif look == "dark_led":
        # Deepest well lip — keeps LEDs/glow on the bezel, well stays pure black
        d.rounded_rectangle([ix0, iy0, ix1, iy1], radius=inner_rad, outline=(0, 0, 0, 220), width=4)

    return img


def egg_id_for_pet(pet: str, traits=None) -> str:
    """Resolve egg id for a pet (traits eggs have pet_id; E0N ↔ P0N fallback)."""
    traits = traits or load_json("traits.json")
    for e in traits.get("eggs", []):
        if e.get("pet_id") == pet:
            return e["id"]
    if isinstance(pet, str) and pet.startswith("P") and len(pet) >= 2:
        return "E" + pet[1:]
    return "E01"


def build_hatch_frame(egg: Image.Image, frame_index: int, seed: int = 99) -> Image.Image:
    """One 64×64 hatch beat from a given egg — same timeline as build_hatch().

    Indices 0–12: normal, shake, cracks, split, pieces, flash, silhouette,
    shell halves + glow, flash fade, idle. Egg body is never a baked E01 asset;
    crack/flash marks are drawn as overlays on this copy.
    """
    import random
    egg = egg.convert("RGBA")
    i = int(frame_index) % 13
    # Match build_hatch Random(99) walk for shake offsets (frames 1 then 4 → both 1).
    rng = random.Random(seed)
    shake_ox = {}
    for j in (1, 4):
        shake_ox[j] = rng.choice([-2, 2, -1, 1])
    fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    ox = shake_ox.get(i, 0)

    if i < 8:
        fr.paste(egg, (ox, 0), egg)
    if 2 <= i < 8:
        d = ImageDraw.Draw(fr)
        crack = (40, 30, 40, 255)
        d.line([(32, 20), (28, 32), (34, 40)], fill=crack, width=1)
        if i >= 3:
            d.line([(32, 18), (38, 30), (36, 44)], fill=crack, width=1)
        if i >= 5:
            d.line([(24, 28), (32, 34), (40, 28)], fill=crack, width=1)
        if i >= 6:
            left = fr.crop((0, 0, 32, 64))
            right = fr.crop((32, 0, 64, 64))
            fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            fr.paste(left, (-(i - 5), 0), left)
            fr.paste(right, (32 + (i - 5), 0), right)
        if i == 7:
            left = egg.crop((0, 0, 32, 64))
            right = egg.crop((32, 0, 64, 64))
            fr = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            fr.paste(left, (-4, 2), left)
            fr.paste(right, (36, -2), right)
    if i == 8:
        d = ImageDraw.Draw(fr)
        d.rectangle([8, 8, 55, 55], fill=(255, 255, 255, 200))
        rng8 = random.Random(seed + 8)
        px = fr.load()
        for _ in range(20):
            x, y = rng8.randint(10, 54), rng8.randint(10, 54)
            px[x, y] = (255, 255, 200, 255)
    if i == 9:
        d = ImageDraw.Draw(fr)
        d.ellipse([20, 18, 44, 50], fill=(20, 20, 30, 180))
    if i == 10:
        left = egg.crop((0, 0, 32, 64))
        right = egg.crop((32, 0, 64, 64))
        fr.paste(left, (-6, 4), left)
        fr.paste(right, (38, 4), right)
        d = ImageDraw.Draw(fr)
        d.ellipse([22, 20, 42, 48], fill=(255, 255, 200, 60))
    if i == 11:
        d = ImageDraw.Draw(fr)
        d.rectangle([12, 12, 51, 51], fill=(255, 255, 255, 80))
    # i == 12: idle empty
    return fr


def compose_rock_gif(args, out_path: Path):
    frames = []
    for i in range(8):
        args.rock_frame = i
        args.dormant = True
        fr = compose_one(args)
        # scale down for gif size? keep 512 for manageable gif
        fr_small = fr.resize((512, 512), Image.Resampling.NEAREST)
        frames.append(fr_small.convert("P", palette=Image.ADAPTIVE, colors=128))
    frames[0].save(out_path, save_all=True, append_images=frames[1:], duration=150, loop=0, disposal=2)

def compose_hatch_gif(args, out_path: Path, pet="P02", pet_color="green", pet_name=None):
    """Hatch GIF: matching pet egg early, matching pet late (runtime frames).

    Egg id comes from traits.json (eggs[].pet_id) or E0N↔P0N. Crack/flash are
    overlays on that egg — no baked single-egg hatch PNG dependency for the body.
    """
    anchors = load_json("anchors.json")
    traits = load_json("traits.json")
    ha = anchors["handhelds"][args.handheld]
    screen = ha["screen"]
    egg_id = egg_id_for_pet(pet, traits)
    egg_file = EGG_MAP.get(egg_id, "E01_pudd_cream.png")
    egg = Image.open(LAYERS / "eggs" / egg_file).convert("RGBA")
    # Keep args.egg in sync for any dormant paths / debugging
    args.egg = egg_id

    folder = LAYERS / "pets" / PET_FOLDERS[pet]
    body = Image.open(folder / "colors" / f"{pet_color}.png").convert("RGBA")
    eyes = Image.open(folder / "eyes" / "happy.png").convert("RGBA")
    mouth = Image.open(folder / "mouths" / "smile.png").convert("RGBA")

    name_overlay = (pet_name if pet_name is not None else getattr(args, "pet_name", None)) or ""

    frames = []
    for idx in range(13):
        canvas = compose_device_shell(args)
        content = new_canvas()
        fx = Image.open(LAYERS / "screen_effects" / FX_MAP[args.fx]).convert("RGBA")
        content.alpha_composite(place_pixel_clipped_to_well(fx, screen, ha, args.screen, traits))

        hatch_fr = build_hatch_frame(egg, idx)

        if idx >= 10:
            # Late frames: reveal matching pet; frame 10 also shows shell pieces
            content.alpha_composite(place_pixel_fit_in_well(body, ha, args.screen, traits))
            content.alpha_composite(place_pixel_fit_in_well(eyes, ha, args.screen, traits))
            content.alpha_composite(place_pixel_fit_in_well(mouth, ha, args.screen, traits))
            if idx == 10:
                content.alpha_composite(place_pixel_fit_in_well(hatch_fr, ha, args.screen, traits))
            elif idx == 11 and hatch_fr.getbbox() is not None:
                content.alpha_composite(place_pixel_fit_in_well(hatch_fr, ha, args.screen, traits))
            if idx == 12 and name_overlay:
                well = screen_well_rect(ha, args.screen, traits)
                name_layer = render_pet_name(name_overlay, well)
                content.alpha_composite(clip_to_screen_well(name_layer, ha, args.screen, traits))
        else:
            # Early / mid: egg body + cracks / flash / silhouette from this pet's egg
            content.alpha_composite(place_pixel_fit_in_well(hatch_fr, ha, args.screen, traits))

        # Optional disk flash overlays (additive FX, egg-agnostic)
        if idx in (8, 11):
            ov_name = "08_flash_overlay.png" if idx == 8 else "11_flash_fade_overlay.png"
            ov_path = ANIM / "hatch" / ov_name
            if ov_path.exists():
                ov = Image.open(ov_path).convert("RGBA")
                content.alpha_composite(place_pixel_clipped_to_well(ov, screen, ha, args.screen, traits))

        canvas.alpha_composite(clip_to_handheld_mask(content, args.handheld))
        fr_small = canvas.resize((512, 512), Image.Resampling.BILINEAR)
        frames.append(fr_small.convert("P", palette=Image.ADAPTIVE, colors=128))

    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(out_path, save_all=True, append_images=frames[1:], duration=120, loop=0, disposal=2)


def compose_device_shell(args) -> Image.Image:
    """Layers 1-6 + 13-14 without pet/egg/fx."""
    anchors = load_json("anchors.json")
    traits = load_json("traits.json")
    ha = anchors["handhelds"][args.handheld]
    from PIL import Image as PILImage
    bg = PILImage.open(LAYERS / "backgrounds" / BG_MAP[args.bg]).convert("RGBA")
    color_hex = next(c["hex"] for c in traits["shell_colors"] if c["id"] == args.color)
    mask = PILImage.open(LAYERS / "handhelds" / f"{args.handheld}_mask.png").convert("RGBA")
    shell_colored = multiply_mask(mask, color_hex)
    hh = PILImage.open(LAYERS / "handhelds" / HANDHELD_FILES[args.handheld]).convert("RGBA")
    canvas = new_canvas()
    canvas.alpha_composite(bg)
    canvas.alpha_composite(shell_colored)
    bands = list(hh.split())
    bands[3] = bands[3].point(lambda a: int(a * 0.55))
    canvas.alpha_composite(PILImage.merge("RGBA", bands))
    scr = clip_to_handheld_mask(build_screen_for(ha, args.screen, traits), args.handheld)
    canvas.alpha_composite(scr)
    canvas.alpha_composite(draw_buttons_at(args.buttons, ha["buttons"]))
    # Labels after buttons so chips never cover shell_class / pet_id
    cls = PILImage.open(LAYERS / "shell_class" / CLASS_MAP[args.class_name.upper()]).convert("RGBA")
    cls = reposition_from_default(cls, DEFAULT_SHELL_CLASS_XY,
                                  (ha["shell_class"]["x"], ha["shell_class"]["y"]))
    canvas.alpha_composite(cls)
    canvas.alpha_composite(render_pet_id(str(args.pet_id), ha["pet_id"]))
    ant = PILImage.open(LAYERS / "antennas" / ANTENNA_MAP[args.antenna]).convert("RGBA")
    def_ant = anchors["handhelds"]["H01"]["antenna"]
    ant = reposition_from_default(ant, (def_ant["x"], def_ant["y"]),
                                  (ha["antenna"]["x"], ha["antenna"]["y"]))
    canvas.alpha_composite(ant)
    return canvas

def preview_sheets():
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    anchors = load_json("anchors.json")
    traits = load_json("traits.json")

    # handheld family
    thumbs = []
    for hid in anchors["handhelds"]:
        args = argparse.Namespace(
            bg="BG02", handheld=hid, color="cream", class_name="ALPHA", pet_id="1",
            buttons="gray", antenna="classic", screen="S01", fx="scanlines",
            pet="P01", pet_color="pink", eyes="normal", mouth="smile", acc="hat",
            dormant=False, egg="E01", rock_frame=None, strict=False
        )
        img = compose_one(args).resize((384, 384), Image.Resampling.LANCZOS)
        thumbs.append(img)
    sheet = Image.new("RGBA", (384*5, 384*2), hex_to_rgba("#0B3D2E"))
    for i, t in enumerate(thumbs):
        sheet.paste(t, ((i % 5) * 384, (i // 5) * 384))
    sheet.save(PREVIEWS / "handheld-family.png")

    # pet roster
    pets = list(traits["pets"].keys())
    thumbs = []
    for pid in pets:
        meta = traits["pets"][pid]
        col = meta["colors"][0]["id"]
        args = argparse.Namespace(
            bg="BG03", handheld="H01", color="mint", class_name="BETA", pet_id="42",
            buttons="blue", antenna="star", screen="S02", fx="sparkles",
            pet=pid, pet_color=col, eyes="happy", mouth="smile", acc="bow",
            dormant=False, egg="E01", rock_frame=None, strict=False
        )
        img = compose_one(args).resize((340, 340), Image.Resampling.LANCZOS)
        thumbs.append(img)
    sheet = Image.new("RGBA", (340*4, 340*3), hex_to_rgba("#156B4A"))
    for i, t in enumerate(thumbs):
        sheet.paste(t, ((i % 4) * 340, (i // 4) * 340))
    sheet.save(PREVIEWS / "pet-roster.png")

    # trait sheets quick
    for cat, files_glob, cols in [
        ("backgrounds", "backgrounds/*.png", 7),
        ("antennas", "antennas/A*.png", 5),
        ("eggs", "eggs/*.png", 4),
        ("screen_effects", "screen_effects/*.png", 6),
    ]:
        paths = sorted((LAYERS).glob(files_glob if "/" in files_glob else f"{cat}/*.png"))
        if cat == "backgrounds":
            paths = sorted((LAYERS / "backgrounds").glob("*.png"))
        elif cat == "antennas":
            paths = sorted((LAYERS / "antennas").glob("A*.png"))
        elif cat == "eggs":
            paths = sorted((LAYERS / "eggs").glob("*.png"))
        elif cat == "screen_effects":
            paths = sorted((LAYERS / "screen_effects").glob("*.png"))
        if not paths:
            continue
        tw = 256
        n = len(paths)
        rows = (n + cols - 1) // cols
        sheet = Image.new("RGBA", (tw*cols, tw*rows), (20, 20, 30, 255))
        for i, p in enumerate(paths):
            im = Image.open(p).convert("RGBA")
            im = im.resize((tw-8, tw-8), Image.Resampling.NEAREST if cat in ("eggs","screen_effects") else Image.Resampling.LANCZOS)
            sheet.paste(im, ((i%cols)*tw+4, (i//cols)*tw+4), im)
        sheet.save(PREVIEWS / f"traits-{cat}.png")

    # sample awakened
    samples = [
        dict(bg="BG01", handheld="H01", color="cream", class_name="ALPHA", pet_id="421",
             buttons="yellow", antenna="star", screen="S01", fx="scanlines",
             pet="P02", pet_color="green", eyes="happy", mouth="smile", acc="crown"),
        dict(bg="BG04", handheld="H03", color="pink", class_name="BETA", pet_id="7",
             buttons="pink", antenna="heart", screen="S02", fx="sparkles",
             pet="P03", pet_color="orange", eyes="sparkly", mouth="tongue", acc="bow"),
        dict(bg="BG05", handheld="H05", color="mint", class_name="DELTA", pet_id="99",
             buttons="green", antenna="flower", screen="S06", fx="bubbles",
             pet="P01", pet_color="lavender", eyes="hearts", mouth="laugh", acc="flower"),
        dict(bg="BG09", handheld="H08", color="purple", class_name="OMEGA", pet_id="1337",
             buttons="orange", antenna="lightning", screen="S05", fx="glitch",
             pet="P12", pet_color="toxic", eyes="excited", mouth="funny", acc="party_hat"),
        dict(bg="BG07", handheld="H09", color="yellow", class_name="ALPHA", pet_id="55",
             buttons="black", antenna="crown", screen="S01", fx="stars",
             pet="P07", pet_color="crimson", eyes="angry", mouth="angry", acc="bandana"),
        dict(bg="BG14", handheld="H02", color="light_blue", class_name="BETA", pet_id="888",
             buttons="blue", antenna="orb", screen="S02", fx="clouds",
             pet="P11", pet_color="pink", eyes="wink", mouth="smile", acc="headphones"),
    ]
    for i, s in enumerate(samples, 1):
        args = argparse.Namespace(dormant=False, egg="E01", rock_frame=None, strict=False, **s)
        compose_one(args).save(PREVIEWS / f"sample-awakened-{i:02d}.png")

    # dormant samples
    dormants = [
        dict(bg="BG02", handheld="H01", color="white", class_name="ALPHA", pet_id="1",
             buttons="white", antenna="classic", screen="S01", fx="static", egg="E03"),
        dict(bg="BG08", handheld="H06", color="lavender", class_name="DELTA", pet_id="12",
             buttons="pink", antenna="mushroom", screen="S05", fx="digital_grid", egg="E05"),
        dict(bg="BG11", handheld="H10", color="black", class_name="OMEGA", pet_id="9999",
             buttons="gray", antenna="double", screen="S08", fx="scanlines", egg="E08"),
    ]
    for i, s in enumerate(dormants, 1):
        args = argparse.Namespace(
            dormant=True, rock_frame=None, strict=False,
            pet="P01", pet_color="pink", eyes="normal", mouth="smile", acc="none", **s
        )
        compose_one(args).save(PREVIEWS / f"sample-dormant-{i:02d}.png")

    # egg-rock gif
    args = argparse.Namespace(
        bg="BG03", handheld="H01", color="cream", class_name="BETA", pet_id="42",
        buttons="yellow", antenna="star", screen="S01", fx="scanlines",
        pet="P01", pet_color="pink", eyes="normal", mouth="smile", acc="none",
        dormant=True, egg="E03", rock_frame=None, strict=False
    )
    compose_rock_gif(args, PREVIEWS / "egg-rock.gif")

    # hatch gif revealing P02
    args = argparse.Namespace(
        bg="BG01", handheld="H01", color="mint", class_name="ALPHA", pet_id="2",
        buttons="green", antenna="classic", screen="S02", fx="sparkles",
        pet="P02", pet_color="green", eyes="happy", mouth="smile", acc="none",
        dormant=True, egg="E01", rock_frame=None, strict=False
    )
    compose_hatch_gif(args, PREVIEWS / "hatch.gif", pet="P02", pet_color="green")
    print("Previews written to", PREVIEWS)

def main():
    p = argparse.ArgumentParser(description="Compose Pocket Critter NFT")
    p.add_argument("--bg", default="BG03")
    p.add_argument("--handheld", default="H01")
    p.add_argument("--color", default="cream")
    p.add_argument("--class", dest="class_name", default="ALPHA")
    p.add_argument("--pet-id", default="1")
    p.add_argument("--buttons", default="yellow")
    p.add_argument("--antenna", default="star")
    p.add_argument("--screen", default="S01")
    p.add_argument("--fx", default="scanlines")
    p.add_argument("--pet", default="P01")
    p.add_argument("--pet-color", default="pink")
    p.add_argument("--eyes", default="happy")
    p.add_argument("--mouth", default="smile")
    p.add_argument("--acc", default="hat")
    p.add_argument("--dormant", action="store_true")
    p.add_argument("--pet-name", default="", help="Custom name overlay (woken pets; empty = none)")
    p.add_argument("--egg", default="E01")
    p.add_argument("--rock", action="store_true", help="Export rocking egg GIF")
    p.add_argument("--out", default="out.png")
    p.add_argument("--preview-sheet", action="store_true")
    p.add_argument("--strict", action="store_true")
    args = p.parse_args()
    args.rock_frame = None

    if args.preview_sheet:
        preview_sheets()
        return

    out = Path(args.out)
    if args.rock:
        args.dormant = True
        compose_rock_gif(args, out)
        print("Wrote", out)
        return

    img = compose_one(args)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print("Wrote", out)

if __name__ == "__main__":
    main()
