"""Procedural smooth handheld shells, buttons, antennas, screens, backgrounds, classes."""
from __future__ import annotations
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
from common import (
    ROOT, LAYERS, CANVAS, SS, ss_canvas, downscale_ss, new_canvas,
    hex_to_rgb, hex_to_rgba, load_json, shade, get_font, paste_center
)

ANCHORS = None
TRAITS = None

def init():
    global ANCHORS, TRAITS
    ANCHORS = load_json("anchors.json")
    TRAITS = load_json("traits.json")

# ---------- Backgrounds ----------
GREENS = {
    "dark": "#007A03",   # deeper Robinhood green
    "core": "#00C805",   # Robinhood brand green
    "light": "#5CFF60",  # bright mint of same hue
}

def build_backgrounds():
    """14 backgrounds using only GREENS dark / core / light."""
    out = LAYERS / "backgrounds"
    out.mkdir(parents=True, exist_ok=True)
    dark, core, light = GREENS["dark"], GREENS["core"], GREENS["light"]
    dark_rgb = hex_to_rgb(dark)
    specs = [
        ("BG01_solid_dark.png", "solid_dark", None),
        ("BG02_solid_mdark.png", "solid_core", None),
        ("BG03_solid_medium.png", "solid_light", None),
        ("BG04_solid_bright.png", "core_vignette", None),
        ("BG05_split_v.png", "split_v", None),
        ("BG06_split_h.png", "split_h", None),
        ("BG07_diagonal.png", "diag", None),
        ("BG08_vignette.png", "vignette", None),
        ("BG09_dots.png", "dots", None),
        ("BG10_chevrons.png", "chevrons", None),
        ("BG11_soft_pixels.png", "soft_px", None),
        ("BG12_triband.png", "triband", None),
        ("BG13_corners.png", "corners", None),
        ("BG14_radial.png", "radial", None),
    ]
    for fname, kind, _ in specs:
        if kind == "solid_dark":
            img = new_canvas(color=hex_to_rgba(dark))
        elif kind == "solid_core":
            img = new_canvas(color=hex_to_rgba(core))
        elif kind == "solid_light":
            img = new_canvas(color=hex_to_rgba(light))
        elif kind == "core_vignette":
            # BG04: core fill with soft dark vignette edge (still only 3 greens)
            img = new_canvas(color=hex_to_rgba(core))
            overlay = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            od = ImageDraw.Draw(overlay)
            for i in range(32):
                a = int(3 + i * 1.4)
                m = i * 28
                od.ellipse([m, m, CANVAS - 1 - m, CANVAS - 1 - m],
                           outline=(*dark_rgb, a), width=30)
            img = Image.alpha_composite(img, overlay)
        elif kind == "split_v":
            img = new_canvas(color=hex_to_rgba(core))
            d = ImageDraw.Draw(img)
            d.rectangle([0, 0, 1023, 2047], fill=hex_to_rgba(dark))
            d.rectangle([1024, 0, 2047, 2047], fill=hex_to_rgba(light))
        elif kind == "split_h":
            img = new_canvas(color=hex_to_rgba(core))
            d = ImageDraw.Draw(img)
            d.rectangle([0, 0, 2047, 1023], fill=hex_to_rgba(dark))
            d.rectangle([0, 1024, 2047, 2047], fill=hex_to_rgba(light))
        elif kind == "diag":
            img = new_canvas(color=hex_to_rgba(core))
            d = ImageDraw.Draw(img)
            d.polygon([(0, 0), (2048, 0), (0, 2048)], fill=hex_to_rgba(dark))
        elif kind == "vignette":
            img = new_canvas(color=hex_to_rgba(core))
            overlay = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
            od = ImageDraw.Draw(overlay)
            for i in range(28):
                a = int(4 + i * 1.2)
                m = i * 32
                od.ellipse([m, m, CANVAS - 1 - m, CANVAS - 1 - m],
                           outline=(*dark_rgb, a), width=28)
            img = Image.alpha_composite(img, overlay)
        elif kind == "dots":
            img = new_canvas(color=hex_to_rgba(dark))
            d = ImageDraw.Draw(img)
            step = 64
            for y in range(32, CANVAS, step):
                for x in range(32, CANVAS, step):
                    d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=hex_to_rgba(light, 180))
        elif kind == "chevrons":
            img = new_canvas(color=hex_to_rgba(dark))
            d = ImageDraw.Draw(img)
            for i in range(-20, 40):
                y0 = i * 80
                pts = [(0, y0), (1024, y0 + 120), (2048, y0), (2048, y0 + 40),
                       (1024, y0 + 160), (0, y0 + 40)]
                col = light if i % 2 == 0 else core
                d.polygon(pts, fill=hex_to_rgba(col, 200))
        elif kind == "soft_px":
            img = new_canvas(color=hex_to_rgba(dark))
            d = ImageDraw.Draw(img)
            cell = 48
            cols = [dark, core, light]
            for y in range(0, CANVAS, cell):
                for x in range(0, CANVAS, cell):
                    c = cols[(x // cell + y // cell) % 3]
                    d.rectangle([x, y, x + cell - 4, y + cell - 4], fill=hex_to_rgba(c))
        elif kind == "triband":
            img = new_canvas()
            d = ImageDraw.Draw(img)
            d.rectangle([0, 0, 2047, 682], fill=hex_to_rgba(dark))
            d.rectangle([0, 683, 2047, 1365], fill=hex_to_rgba(core))
            d.rectangle([0, 1366, 2047, 2047], fill=hex_to_rgba(light))
        elif kind == "corners":
            img = new_canvas(color=hex_to_rgba(core))
            d = ImageDraw.Draw(img)
            d.polygon([(0, 0), (600, 0), (0, 600)], fill=hex_to_rgba(light))
            d.polygon([(2048, 2048), (1448, 2048), (2048, 1448)], fill=hex_to_rgba(dark))
            d.polygon([(2048, 0), (1448, 0), (2048, 600)], fill=hex_to_rgba(dark))
            d.polygon([(0, 2048), (600, 2048), (0, 1448)], fill=hex_to_rgba(light, 200))
        elif kind == "radial":
            # 3 concentric rings: dark outer -> core mid -> light center
            img = new_canvas(color=hex_to_rgba(dark))
            d = ImageDraw.Draw(img)
            rings = [(1000, dark), (700, core), (400, light)]
            for m, c in rings:
                d.ellipse([1024 - m, 1024 - m, 1024 + m, 1024 + m], fill=hex_to_rgba(c))
        else:
            raise ValueError(f"unknown bg kind {kind}")
        img.save(out / fname)
    return len(specs)

# ---------- Handheld shapes ----------
def _body_rect_ss(ha):
    bb = ha["body_bbox"]
    return [bb["x"]*SS, bb["y"]*SS, (bb["x"]+bb["w"])*SS, (bb["y"]+bb["h"])*SS]

def draw_handheld_shape(hid: str, ha: dict) -> tuple[Image.Image, Image.Image]:
    """Return (shaded shell layer, opaque fill mask) at 2048."""
    ss = ss_canvas()
    mask_ss = ss_canvas()
    d = ImageDraw.Draw(ss)
    dm = ImageDraw.Draw(mask_ss)
    bb = ha["body_bbox"]
    x0, y0 = bb["x"] * SS, bb["y"] * SS
    x1, y1 = (bb["x"] + bb["w"]) * SS, (bb["y"] + bb["h"]) * SS
    cx = (x0 + x1) // 2
    # Neutral gray palette for shade layer (tint applied at compose)
    base = (180, 180, 185, 255)
    mid = (150, 150, 155, 255)
    dark = (110, 110, 118, 255)
    hi = (220, 220, 225, 255)
    edge = (70, 70, 78, 255)

    def rounded_rect(draw, box, r, fill):
        draw.rounded_rectangle(box, radius=r, fill=fill)

    if hid == "H01":  # classic rounded rect
        r = 180 * SS // 4
        rounded_rect(dm, [x0, y0, x1, y1], r, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], r, mid)
        # top highlight band
        rounded_rect(d, [x0+20*SS, y0+20*SS, x1-20*SS, y0+120*SS], r//2, hi)
        # bottom shade
        d.rectangle([x0+40*SS, y1-160*SS, x1-40*SS, y1-40*SS], fill=dark)
        # rim
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=edge, width=6*SS)
    elif hid == "H02":  # rounded square (squarish rect with chin for buttons)
        r = 220 * SS // 4
        rounded_rect(dm, [x0, y0, x1, y1], r, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], r, mid)
        rounded_rect(d, [x0+24*SS, y0+24*SS, x1-24*SS, y0+100*SS], r//2, hi)
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=edge, width=6*SS)
    elif hid == "H03":  # wide
        r = 160 * SS // 4
        rounded_rect(dm, [x0, y0, x1, y1], r, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], r, mid)
        rounded_rect(d, [x0+30*SS, y0+20*SS, x1-30*SS, y0+90*SS], r//2, hi)
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=edge, width=6*SS)
    elif hid == "H04":  # tall
        r = 200 * SS // 4
        rounded_rect(dm, [x0, y0, x1, y1], r, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], r, mid)
        rounded_rect(d, [x0+24*SS, y0+24*SS, x1-24*SS, y0+110*SS], r//2, hi)
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=edge, width=6*SS)
    elif hid == "H05":  # egg-shaped
        dm.ellipse([x0, y0, x1, y1], fill=(255,255,255,255))
        d.ellipse([x0, y0, x1, y1], fill=mid)
        # soft upper shine — deep insets so ellipse stays inside egg taper
        d.ellipse([x0+110*SS, y0+90*SS, x1-110*SS, y0+210*SS], fill=hi)
        d.ellipse([x0, y0, x1, y1], outline=edge, width=6*SS)
    elif hid == "H06":  # capsule (stadium)
        r = (x1 - x0) // 2
        rounded_rect(dm, [x0, y0, x1, y1], r, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], r, mid)
        # shallow highlight band fully inside stadium curve (heavy side inset)
        side, top = 160 * SS, 100 * SS
        hy0, hy1 = y0 + top, y0 + top + 70 * SS
        hi_r = (hy1 - hy0) // 2
        rounded_rect(d, [x0 + side, hy0, x1 - side, hy1], hi_r, hi)
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=edge, width=6*SS)
    elif hid == "H07":  # compact
        r = 140 * SS // 4
        rounded_rect(dm, [x0, y0, x1, y1], r, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], r, mid)
        rounded_rect(d, [x0+20*SS, y0+16*SS, x1-20*SS, y0+80*SS], r//2, hi)
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=edge, width=5*SS)
    elif hid == "H08":  # large rounded
        r = 240 * SS // 4
        rounded_rect(dm, [x0, y0, x1, y1], r, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], r, mid)
        rounded_rect(d, [x0+40*SS, y0+30*SS, x1-40*SS, y0+140*SS], r//2, hi)
        d.rounded_rectangle([x0, y0, x1, y1], radius=r, outline=edge, width=7*SS)
    elif hid == "H09":  # retro toy — slightly trapezoid / beveled
        # trapezoid body
        inset = 40 * SS
        pts = [(x0+inset, y0), (x1-inset, y0), (x1, y1), (x0, y1)]
        dm.polygon(pts, fill=(255,255,255,255))
        d.polygon(pts, fill=mid)
        # bevel top
        d.polygon([(x0+inset, y0), (x1-inset, y0), (x1-inset-30*SS, y0+80*SS), (x0+inset+30*SS, y0+80*SS)], fill=hi)
        # chunky side bevels
        d.polygon([(x0, y1), (x0+inset, y0), (x0+inset+20*SS, y0), (x0+30*SS, y1)], fill=dark)
        d.polygon([(x1, y1), (x1-inset, y0), (x1-inset-20*SS, y0), (x1-30*SS, y1)], fill=dark)
        d.line([pts[0], pts[1], pts[2], pts[3], pts[0]], fill=edge, width=6*SS)
    elif hid == "H10":  # collector — slight asymmetry; highlight flush on upper body
        r = 170 * SS // 4
        # asymmetric: right side a bit wider feel via offset
        ox = 16 * SS
        body = [x0, y0 + 40 * SS, x1 + ox, y1]
        rounded_rect(dm, body, r, (255,255,255,255))
        rounded_rect(d, body, r, mid)
        # highlight band on upper body — same silhouette continuity, not a floating bar
        inset_x, inset_top, band_h = 48 * SS, 28 * SS, 64 * SS
        hi_box = [body[0] + inset_x, body[1] + inset_top,
                  body[2] - inset_x, body[1] + inset_top + band_h]
        rounded_rect(d, hi_box, min(r // 2, band_h // 2), hi)
        d.rounded_rectangle(body, radius=r, outline=edge, width=6*SS)
    else:
        rounded_rect(dm, [x0, y0, x1, y1], 100*SS, (255,255,255,255))
        rounded_rect(d, [x0, y0, x1, y1], 100*SS, mid)

    # Screen well cutout (dark inset) — visual recess on shell shading (not hole in mask)
    scr = ha["screen"]
    sx0 = (scr["x"] - 24) * SS
    sy0 = (scr["y"] - 24) * SS
    sx1 = (scr["x"] + scr["w"] + 24) * SS
    sy1 = (scr["y"] + scr["h"] + 24) * SS
    d.rounded_rectangle([sx0, sy0, sx1, sy1], radius=40*SS, fill=(90, 90, 98, 255))
    d.rounded_rectangle([sx0+8*SS, sy0+8*SS, sx1-8*SS, sy1-8*SS], radius=32*SS, fill=(60, 60, 68, 255))

    # Antenna nub attach point (small stem on shell)
    ax, ay = ha["antenna"]["x"] * SS, ha["antenna"]["y"] * SS
    d.ellipse([ax-14*SS, ay-10*SS, ax+14*SS, ay+18*SS], fill=mid)
    d.rectangle([ax-8*SS, ay, ax+8*SS, ay+40*SS], fill=dark)
    dm.ellipse([ax-14*SS, ay-10*SS, ax+14*SS, ay+18*SS], fill=(255,255,255,255))

    # Safety clip: no highlight/body pixels outside shell silhouette
    ss.putalpha(mask_ss.split()[-1])

    shaded = downscale_ss(ss)
    mask = downscale_ss(mask_ss)
    # ensure mask is opaque white where body is
    m = mask.split()[-1]
    mask_out = Image.new("RGBA", (CANVAS, CANVAS), (0,0,0,0))
    white = Image.new("RGBA", (CANVAS, CANVAS), (255,255,255,255))
    mask_out = Image.composite(white, mask_out, m)
    return shaded, mask_out

def build_handhelds():
    out = LAYERS / "handhelds"
    out.mkdir(parents=True, exist_ok=True)
    names = {
        "H01": "classic", "H02": "rounded_square", "H03": "wide", "H04": "tall",
        "H05": "egg", "H06": "capsule", "H07": "compact", "H08": "large",
        "H09": "retro", "H10": "collector",
    }
    for hid, ha in ANCHORS["handhelds"].items():
        shaded, mask = draw_handheld_shape(hid, ha)
        shaded.save(out / f"{hid}_{names[hid]}.png")
        mask.save(out / f"{hid}_mask.png")
    return 10

# ---------- Shell class marks ----------
def build_shell_class():
    out = LAYERS / "shell_class"
    out.mkdir(parents=True, exist_ok=True)
    labels = ["ALPHA", "BETA", "DELTA", "OMEGA"]
    files = ["alpha.png", "beta.png", "delta.png", "omega.png"]
    font = get_font(28)
    for lab, fn in zip(labels, files):
        # draw at SS then downscale for crisp label
        ss = Image.new("RGBA", (400*SS, 80*SS), (0,0,0,0))
        d = ImageDraw.Draw(ss)
        # retro-tech plate
        d.rounded_rectangle([4*SS, 8*SS, 396*SS, 72*SS], radius=8*SS, fill=(40,40,48,230))
        d.rounded_rectangle([4*SS, 8*SS, 396*SS, 72*SS], radius=8*SS, outline=(180,180,190,255), width=3*SS)
        # small corner ticks
        for px in (12, 380):
            d.rectangle([px*SS, 14*SS, (px+8)*SS, 18*SS], fill=(120,255,180,255))
        big = get_font(36 * SS // 2)
        # approximate center text
        d.text((200*SS, 40*SS), lab, font=get_font(22*SS), fill=(200,255,220,255), anchor="mm")
        img = ss.resize((400, 80), Image.Resampling.LANCZOS)
        # place on transparent 2048 centered at default; compose repositions
        canvas = new_canvas()
        canvas.paste(img, (1024 - 200, 1520 - 40), img)
        canvas.save(out / fn)
    return 4

# ---------- Buttons (template at default H01 positions; compose repositions) ----------
def build_buttons():
    out = LAYERS / "buttons"
    out.mkdir(parents=True, exist_ok=True)
    # Store as single-button chip templates; compose draws 3 at anchors
    # Also export full-canvas default H01 layouts for preview convenience
    ha = ANCHORS["handhelds"]["H01"]
    for b in TRAITS["buttons"]:
        ss = ss_canvas()
        d = ImageDraw.Draw(ss)
        rgb = hex_to_rgb(b["hex"])
        hi = shade(rgb, 1.25)
        dk = shade(rgb, 0.65)
        for btn in ha["buttons"]:
            cx, cy, r = btn["x"]*SS, btn["y"]*SS, btn["r"]*SS
            d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(*dk, 255))
            d.ellipse([cx-r+4*SS, cy-r+4*SS, cx+r-4*SS, cy+r-4*SS], fill=(*rgb, 255))
            d.ellipse([cx-r//2, cy-r//2-4*SS, cx+r//3, cy], fill=(*hi, 200))
            d.ellipse([cx-r, cy-r, cx+r, cy+r], outline=(50,50,55,255), width=3*SS)
        img = downscale_ss(ss)
        img.save(out / b["file"])
        # also save single button sprite
        chip = Image.new("RGBA", (128, 128), (0,0,0,0))
        cd = ImageDraw.Draw(chip)
        cr = 48
        cd.ellipse([64-cr, 64-cr, 64+cr, 64+cr], fill=(*dk, 255))
        cd.ellipse([64-cr+3, 64-cr+3, 64+cr-3, 64+cr-3], fill=(*rgb, 255))
        cd.ellipse([64-cr//2, 64-cr//2-3, 64+cr//3, 64], fill=(*hi, 200))
        chip.save(out / f"chip_{b['id']}.png")
    return 8

# ---------- Antennas ----------
def build_antennas():
    """Larger, more prominent antenna traits (~2.1× linear vs prior tiny tips).

    Stem base stays anchored at H01 antenna (ax, ay); tips grow upward.
    Sprite crops use 256×256 so enlarged ornaments are not clipped.
    """
    out = LAYERS / "antennas"
    out.mkdir(parents=True, exist_ok=True)
    designs = [
        ("A01_classic.png", "classic"),
        ("A02_star.png", "star"),
        ("A03_heart.png", "heart"),
        ("A04_lightning.png", "lightning"),
        ("A05_flower.png", "flower"),
        ("A06_spiral.png", "spiral"),
        ("A07_double.png", "double"),
        ("A08_mushroom.png", "mushroom"),
        ("A09_crown.png", "crown"),
        ("A10_orb.png", "orb"),
    ]
    ax = ANCHORS["handhelds"]["H01"]["antenna"]["x"]
    ay = ANCHORS["handhelds"]["H01"]["antenna"]["y"]
    # ~2.1× linear scale vs prior (stem hw 6→13, h 50→92; tips ~2×)
    STEM_HW = 13
    STEM_H = 92
    OUT_W = 5
    outline = (45, 45, 55, 255)
    for fname, kind in designs:
        ss = ss_canvas()
        d = ImageDraw.Draw(ss)
        cx, cy = ax * SS, ay * SS
        stem = (90, 90, 100, 255)
        accent = (240, 240, 245, 255)
        tip = (255, 200, 80, 255)
        # stem (skip center stem for double — twin stems drawn below)
        if kind != "double":
            d.rectangle(
                [cx - STEM_HW * SS, cy, cx + STEM_HW * SS, cy + STEM_H * SS],
                fill=stem,
            )
            # slight outline on stem edges for pop
            d.rectangle(
                [cx - STEM_HW * SS, cy, cx - (STEM_HW - 2) * SS, cy + STEM_H * SS],
                fill=outline,
            )
            d.rectangle(
                [cx + (STEM_HW - 2) * SS, cy, cx + STEM_HW * SS, cy + STEM_H * SS],
                fill=outline,
            )
        if kind == "classic":
            # bead radius ~48 (was 22)
            d.ellipse(
                [cx - 48 * SS, cy - 92 * SS, cx + 48 * SS, cy + 8 * SS],
                fill=tip,
            )
            d.ellipse(
                [cx - 48 * SS, cy - 92 * SS, cx + 48 * SS, cy + 8 * SS],
                outline=outline,
                width=OUT_W * SS,
            )
            # soft highlight
            d.ellipse(
                [cx - 22 * SS, cy - 72 * SS, cx + 6 * SS, cy - 42 * SS],
                fill=(255, 235, 160, 200),
            )
        elif kind == "star":
            pts = []
            for i in range(10):
                ang = math.radians(-90 + i * 36)
                r = 58 * SS if i % 2 == 0 else 25 * SS
                pts.append((cx + r * math.cos(ang), cy - 36 * SS + r * math.sin(ang)))
            d.polygon(pts, fill=(255, 220, 60, 255), outline=outline)
            # strengthen outline by redrawing slightly thicker via second pass ring
            d.line(pts + [pts[0]], fill=outline, width=OUT_W * SS)
        elif kind == "heart":
            fill_h = (255, 90, 120, 255)
            d.ellipse(
                [cx - 50 * SS, cy - 88 * SS, cx + 4 * SS, cy - 28 * SS], fill=fill_h
            )
            d.ellipse(
                [cx - 4 * SS, cy - 88 * SS, cx + 50 * SS, cy - 28 * SS], fill=fill_h
            )
            d.polygon(
                [
                    (cx - 50 * SS, cy - 48 * SS),
                    (cx + 50 * SS, cy - 48 * SS),
                    (cx, cy + 18 * SS),
                ],
                fill=fill_h,
            )
            d.arc(
                [cx - 50 * SS, cy - 88 * SS, cx + 4 * SS, cy - 28 * SS],
                180, 0, fill=outline, width=OUT_W * SS,
            )
            d.arc(
                [cx - 4 * SS, cy - 88 * SS, cx + 50 * SS, cy - 28 * SS],
                180, 0, fill=outline, width=OUT_W * SS,
            )
            d.line(
                [(cx - 50 * SS, cy - 48 * SS), (cx, cy + 18 * SS), (cx + 50 * SS, cy - 48 * SS)],
                fill=outline, width=OUT_W * SS,
            )
        elif kind == "lightning":
            s = 2.1
            pts = [
                (cx - 4 * s * SS, cy - 48 * s * SS),
                (cx + 16 * s * SS, cy - 48 * s * SS),
                (cx + 2 * s * SS, cy - 22 * s * SS),
                (cx + 14 * s * SS, cy - 22 * s * SS),
                (cx - 18 * s * SS, cy + 8 * s * SS),
                (cx - 2 * s * SS, cy - 10 * s * SS),
                (cx - 14 * s * SS, cy - 10 * s * SS),
            ]
            # clamp tip to y>=0 on 1x canvas (cy/SS - top)
            top_y = min(p[1] for p in pts)
            if top_y < 0:
                dy = -top_y
                pts = [(p[0], p[1] + dy) for p in pts]
            d.polygon(pts, fill=(255, 240, 60, 255), outline=outline)
            d.line(pts + [pts[0]], fill=outline, width=OUT_W * SS)
        elif kind == "flower":
            for i in range(5):
                ang = math.radians(i * 72 - 90)
                px = cx + 34 * SS * math.cos(ang)
                py = cy - 36 * SS + 34 * SS * math.sin(ang)
                d.ellipse(
                    [px - 20 * SS, py - 20 * SS, px + 20 * SS, py + 20 * SS],
                    fill=(255, 160, 200, 255),
                    outline=outline,
                    width=max(2, OUT_W - 1) * SS,
                )
            d.ellipse(
                [cx - 16 * SS, cy - 52 * SS, cx + 16 * SS, cy - 20 * SS],
                fill=(255, 220, 80, 255),
                outline=outline,
                width=max(2, OUT_W - 1) * SS,
            )
        elif kind == "spiral":
            for i in range(28):
                ang = i * 0.55
                r = 8 * SS + i * 2.5 * SS
                px = cx + r * math.cos(ang)
                py = cy - 36 * SS + r * math.sin(ang)
                d.ellipse(
                    [px - 8 * SS, py - 8 * SS, px + 8 * SS, py + 8 * SS],
                    fill=(120, 200, 255, 255),
                    outline=outline,
                    width=2 * SS,
                )
        elif kind == "double":
            # thicker twin stems (~10px half-width each) + larger beads
            tw = 10
            gap = 16
            for sign, bead in ((-1, (100, 200, 255, 255)), (1, (255, 140, 200, 255))):
                sx = cx + sign * (gap + tw) * SS
                d.rectangle(
                    [sx - tw * SS, cy, sx + tw * SS, cy + STEM_H * SS],
                    fill=stem,
                )
                d.rectangle(
                    [sx - tw * SS, cy, sx - (tw - 2) * SS, cy + STEM_H * SS],
                    fill=outline,
                )
                d.rectangle(
                    [sx + (tw - 2) * SS, cy, sx + tw * SS, cy + STEM_H * SS],
                    fill=outline,
                )
                d.ellipse(
                    [sx - 38 * SS, cy - 88 * SS, sx + 38 * SS, cy + 6 * SS],
                    fill=bead,
                    outline=outline,
                    width=OUT_W * SS,
                )
        elif kind == "mushroom":
            d.ellipse(
                [cx - 58 * SS, cy - 92 * SS, cx + 58 * SS, cy - 8 * SS],
                fill=(255, 80, 80, 255),
                outline=outline,
                width=OUT_W * SS,
            )
            d.rectangle(
                [cx - 20 * SS, cy - 24 * SS, cx + 20 * SS, cy + 36 * SS],
                fill=(240, 220, 180, 255),
            )
            d.ellipse(
                [cx - 24 * SS, cy - 64 * SS, cx - 8 * SS, cy - 48 * SS],
                fill=accent,
            )
            d.ellipse(
                [cx + 10 * SS, cy - 56 * SS, cx + 28 * SS, cy - 40 * SS],
                fill=accent,
            )
            d.ellipse(
                [cx - 4 * SS, cy - 44 * SS, cx + 10 * SS, cy - 32 * SS],
                fill=accent,
            )
        elif kind == "crown":
            pts = [
                (cx - 56 * SS, cy),
                (cx - 56 * SS, cy - 42 * SS),
                (cx - 28 * SS, cy - 18 * SS),
                (cx, cy - 78 * SS),
                (cx + 28 * SS, cy - 18 * SS),
                (cx + 56 * SS, cy - 42 * SS),
                (cx + 56 * SS, cy),
            ]
            d.polygon(pts, fill=(255, 200, 60, 255), outline=outline)
            d.line(pts + [pts[0]], fill=outline, width=OUT_W * SS)
            for ox in (-40, 0, 40):
                d.ellipse(
                    [
                        cx + ox * SS - 9 * SS,
                        cy - 88 * SS,
                        cx + ox * SS + 9 * SS,
                        cy - 70 * SS,
                    ],
                    fill=(255, 80, 120, 255),
                    outline=outline,
                    width=2 * SS,
                )
        elif kind == "orb":
            d.ellipse(
                [cx - 50 * SS, cy - 92 * SS, cx + 50 * SS, cy + 8 * SS],
                fill=(160, 120, 255, 255),
            )
            d.ellipse(
                [cx - 24 * SS, cy - 72 * SS, cx + 8 * SS, cy - 40 * SS],
                fill=(220, 200, 255, 180),
            )
            d.ellipse(
                [cx - 50 * SS, cy - 92 * SS, cx + 50 * SS, cy + 8 * SS],
                outline=outline,
                width=OUT_W * SS,
            )
        img = downscale_ss(ss)
        # Safety: if tip clipped at y=0, nudge content down slightly (keep base at ay)
        bb = img.getbbox()
        if bb and bb[1] <= 0:
            # tip touching top — shorten by shifting tip region is complex; stem already
            # sized so H01 (ay=380) tip tops stay >= ~280. Log for verify.
            pass
        img.save(out / fname)
        # sprite centered — 256×256 so enlarged tips are not clipped
        half = 128
        sprite = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        crop = img.crop((ax - half, ay - half, ax + half, ay + half))
        sprite.paste(crop, (0, 0), crop)
        sprite.save(out / f"sprite_{kind}.png")
    return 10

# ---------- Screens (bezel templates drawn into H01 rect; compose fits per handheld) ----------
def build_screens():
    """Static screen layers matching live compose.build_screen_for (H01 rect)."""
    # Import here to avoid circular import at module load; compose imports common only.
    from compose import build_screen_for

    out = LAYERS / "screens"
    out.mkdir(parents=True, exist_ok=True)
    ha = ANCHORS["handhelds"]["H01"]
    for s in TRAITS["screens"]:
        img = build_screen_for(ha, s["id"], TRAITS)
        img.save(out / s["file"])
    return 8

# ---------- Shell color chips ----------
def build_shell_color_chips():
    out = LAYERS / "shell_colors"
    out.mkdir(parents=True, exist_ok=True)
    for c in TRAITS["shell_colors"]:
        chip = Image.new("RGBA", (256, 256), hex_to_rgba(c["hex"]))
        chip.save(out / f"{c['id']}.png")
    return len(TRAITS["shell_colors"])

def build_all_shell():
    init()
    counts = {}
    counts["backgrounds"] = build_backgrounds()
    counts["handhelds"] = build_handhelds()
    counts["shell_class"] = build_shell_class()
    counts["buttons"] = build_buttons()
    counts["antennas"] = build_antennas()
    counts["screens"] = build_screens()
    counts["shell_color_chips"] = build_shell_color_chips()
    return counts

if __name__ == "__main__":
    print(build_all_shell())
