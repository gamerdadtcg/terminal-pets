#!/usr/bin/env python3
"""Build clean master trait-library sheets for Terminal Pets.

Outputs under previews/gallery/master/ + master-overview.png.
Uses current compose + layers. Does not touch locked pet body art.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    ROOT, LAYERS, PREVIEWS, CANVAS, load_json, hex_to_rgb, hex_to_rgba, get_font,
)
from compose import (
    compose_one, PET_FOLDERS, ANTENNA_MAP, FX_MAP, CLASS_MAP, BG_MAP,
)

OUT = PREVIEWS / "gallery" / "master"
GALLERY = PREVIEWS / "gallery"

# Chrome
BG_DARK = (10, 28, 22, 255)          # near-black RH green
BG_PANEL = (14, 42, 32, 255)
ACCENT = (0, 200, 5, 255)            # Robinhood green
ACCENT_SOFT = (124, 255, 178, 255)   # #7CFFB2
TEXT = (230, 245, 235, 255)
TEXT_DIM = (160, 190, 170, 255)
CELL_BG = (18, 48, 36, 255)
CARD = (22, 55, 42, 255)
WARN = (255, 200, 80, 255)

PET_ORDER = [f"P{i:02d}" for i in range(1, 13)]
EYE_ORDER = ["normal", "happy", "sleepy", "angry", "excited",
             "sparkly", "hearts", "wink", "tiny", "surprised"]
MOUTH_ORDER = ["smile", "open_smile", "frown", "tiny", "surprised",
               "tongue", "angry", "laugh", "sad", "funny"]
ACC_STANDARD = ["none", "hat", "crown", "bow", "bandana",
                "headphones", "glasses", "flower", "bowtie", "party_hat"]


def font(size: int, bold: bool = True) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
        if bold
        else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    )
    try:
        return ImageFont.truetype(path, size)
    except Exception:
        return get_font(size)


def ns(**kw):
    """compose_one Namespace with safe defaults."""
    base = dict(
        bg="BG02",
        handheld="H01",
        color="cream",
        class_name="ALPHA",
        pet_id="1",
        buttons="gray",
        antenna="classic",
        screen="S01",
        fx="scanlines",
        pet="P01",
        pet_color="pink",
        eyes="normal",
        mouth="smile",
        acc="none",
        dormant=False,
        egg="E01",
        rock_frame=None,
        strict=False,
        pet_name="",
        fx_image=None,
    )
    base.update(kw)
    return argparse.Namespace(**base)


def pet_meta(traits, pid: str) -> dict:
    return traits["pets"][pid]


def default_color(traits, pid: str) -> str:
    return pet_meta(traits, pid)["colors"][0]["id"]


def load_pet_stack(pid: str, color: str, eyes: str | None = "normal",
                   mouth: str | None = "smile", acc: str | None = None) -> Image.Image:
    """Composite 64×64 pet layers (body + optional face/acc)."""
    folder = LAYERS / "pets" / PET_FOLDERS[pid]
    col = folder / "colors" / f"{color}.png"
    body = Image.open(col if col.exists() else folder / "body.png").convert("RGBA")
    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    out.alpha_composite(body)
    if eyes:
        p = folder / "eyes" / f"{eyes}.png"
        if p.exists():
            out.alpha_composite(Image.open(p).convert("RGBA"))
    if mouth:
        p = folder / "mouths" / f"{mouth}.png"
        if p.exists():
            out.alpha_composite(Image.open(p).convert("RGBA"))
    if acc and acc != "none":
        p = folder / "accessories" / f"{acc}.png"
        if p.exists():
            a = Image.open(p).convert("RGBA")
            if a.getbbox():
                out.alpha_composite(a)
    return out


def scale_nearest(im: Image.Image, side: int) -> Image.Image:
    return im.resize((side, side), Image.Resampling.NEAREST)


def fit_contain(im: Image.Image, box: int, resample=Image.Resampling.LANCZOS) -> Image.Image:
    """Fit image inside box×box preserving aspect, centered on transparent."""
    im = im.convert("RGBA")
    w, h = im.size
    if w == 0 or h == 0:
        return Image.new("RGBA", (box, box), (0, 0, 0, 0))
    scale = min(box / w, box / h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    resized = im.resize((nw, nh), resample)
    canvas = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((box - nw) // 2, (box - nh) // 2))
    return canvas


def crop_content(im: Image.Image, pad: int = 8) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(im.width, x1 + pad)
    y1 = min(im.height, y1 + pad)
    return im.crop((x0, y0, x1, y1))


def draw_title(sheet: Image.Image, title: str, subtitle: str = ""):
    d = ImageDraw.Draw(sheet)
    d.rectangle([0, 0, sheet.width, 90], fill=BG_PANEL)
    d.rectangle([0, 90, sheet.width, 94], fill=ACCENT)
    d.text((32, 22), title, font=font(36), fill=TEXT)
    if subtitle:
        d.text((32, 60), subtitle, font=font(18, bold=False), fill=TEXT_DIM)


def draw_footer(sheet: Image.Image, text: str = "Terminal Pets — Trait Library"):
    d = ImageDraw.Draw(sheet)
    d.rectangle([0, sheet.height - 36, sheet.width, sheet.height], fill=BG_PANEL)
    d.text((24, sheet.height - 28), text, font=font(14, bold=False), fill=TEXT_DIM)


def labeled_cell(content: Image.Image, label: str, cell: int, label_h: int = 36,
                 bg=CELL_BG) -> Image.Image:
    """content already sized to fit in cell×(cell) art area; label below."""
    out = Image.new("RGBA", (cell, cell + label_h), bg)
    # soft inner panel
    d = ImageDraw.Draw(out)
    d.rounded_rectangle([4, 4, cell - 5, cell - 5], radius=12, fill=CARD)
    # paste content centered in art area
    cw, ch = content.size
    x = (cell - cw) // 2
    y = (cell - ch) // 2
    out.alpha_composite(content, (x, y))
    # label
    f = font(15 if len(label) < 18 else 13)
    bbox = d.textbbox((0, 0), label, font=f)
    tw = bbox[2] - bbox[0]
    d.text(((cell - tw) // 2, cell + (label_h - 18) // 2), label, font=f, fill=TEXT)
    return out


def grid_sheet(title: str, subtitle: str, cells: list[Image.Image], cols: int,
               gap: int = 16, pad: int = 28, extra_top: int = 0) -> Image.Image:
    """Pack equal-sized labeled cells into a sheet."""
    if not cells:
        raise ValueError("no cells")
    cw, ch = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    w = pad * 2 + cols * cw + (cols - 1) * gap
    h = 110 + extra_top + pad + rows * ch + (rows - 1) * gap + 50
    sheet = Image.new("RGBA", (w, h), BG_DARK)
    draw_title(sheet, title, subtitle)
    y0 = 110 + extra_top
    for i, cell in enumerate(cells):
        r, c = divmod(i, cols)
        x = pad + c * (cw + gap)
        y = y0 + r * (ch + gap)
        sheet.alpha_composite(cell, (x, y))
    draw_footer(sheet)
    return sheet


def compose_thumb(**kw) -> Image.Image:
    return compose_one(ns(**kw))


def resize_lanczos(im: Image.Image, side: int) -> Image.Image:
    return im.resize((side, side), Image.Resampling.LANCZOS)


# ─── Sheets ───────────────────────────────────────────────────────────────────

def sheet_00_index(traits) -> Image.Image:
    cats = [
        ("Pets", 12, "P01–P12 bodies"),
        ("Pet colors", 12 * 8, "8 per pet"),
        ("Eyes", 10, "shared set / pet glyphs"),
        ("Mouths", 10, "shared set / pet glyphs"),
        ("Accessories", "2–10", "none + hats…; exceptions"),
        ("Eggs", 12, "E01–E12 pet-linked"),
        ("Handhelds", 10, "H01–H10 shapes"),
        ("Shell colors", 15, "incl. neon green"),
        ("Shell class", 4, "Alpha / Beta / Delta / Omega"),
        ("Buttons", 8, "color chips ×3"),
        ("Antennas", 10, "A01–A10"),
        ("Screens / bezels", 8, "S01–S08"),
        ("Screen effects", 12, "FX01–FX12"),
        ("Backgrounds", 14, "Robinhood greens"),
        ("Pet ID + name", "dyn", "PET #NNNN + owner name"),
        ("Sample PFPs", "6–8", "full trait mixes"),
    ]
    w, h = 1400, 110 + 28 + len(cats) * 52 + 60
    sheet = Image.new("RGBA", (w, h), BG_DARK)
    draw_title(sheet, "Terminal Pets — Trait Library",
               "Master index · current compose + layers")
    d = ImageDraw.Draw(sheet)
    y = 120
    # header row
    d.text((48, y), "CATEGORY", font=font(16), fill=ACCENT_SOFT)
    d.text((420, y), "COUNT", font=font(16), fill=ACCENT_SOFT)
    d.text((560, y), "NOTES", font=font(16), fill=ACCENT_SOFT)
    d.text((980, y), "SHEET", font=font(16), fill=ACCENT_SOFT)
    y += 28
    d.line([(40, y), (w - 40, y)], fill=ACCENT, width=2)
    y += 12
    sheet_files = [
        "01-pets.png", "02-pet-colors.png", "03-eyes-mouths.png", "03-eyes-mouths.png",
        "04-accessories.png", "05-eggs.png", "06-handhelds.png", "07-shell-colors.png",
        "08-shell-class.png", "09-buttons.png", "10-antennas.png", "11-screens.png",
        "12-screen-effects.png", "13-backgrounds.png", "14-pet-id-and-name.png",
        "15-sample-pfps.png",
    ]
    for (name, count, notes), sf in zip(cats, sheet_files):
        d.rounded_rectangle([36, y, w - 36, y + 44], radius=8, fill=CARD)
        d.text((56, y + 10), name, font=font(20), fill=TEXT)
        d.text((420, y + 10), str(count), font=font(20), fill=ACCENT)
        d.text((560, y + 12), notes, font=font(16, bold=False), fill=TEXT_DIM)
        d.text((980, y + 12), sf, font=font(15, bold=False), fill=ACCENT_SOFT)
        y += 52
    draw_footer(sheet, "Scroll sheets 01–15 · see also master-overview.png")
    return sheet


def sheet_01_pets(traits) -> Image.Image:
    cells = []
    cell = 260
    art = 200
    for pid in PET_ORDER:
        meta = pet_meta(traits, pid)
        col = default_color(traits, pid)
        pet = load_pet_stack(pid, col, "normal", "smile", None)
        content = scale_nearest(pet, art)
        label = f"{pid}  {meta['name']}"
        cells.append(labeled_cell(content, label, cell, label_h=40))
    return grid_sheet(
        "01 — Pets",
        "12 species · default body + normal eyes + smile · P01–P12",
        cells, cols=4, gap=18,
    )


def sheet_02_pet_colors(traits) -> Image.Image:
    """One row per pet: name + 8 color variants."""
    thumb = 96
    label_w = 160
    gap = 10
    row_h = thumb + 28
    cols_art = 8
    w = 40 + label_w + cols_art * (thumb + gap) + 40
    h = 110 + 20 + 12 * (row_h + 10) + 50
    sheet = Image.new("RGBA", (w, h), BG_DARK)
    draw_title(sheet, "02 — Pet Colors",
               "8 colorways per pet · body + face (nearest)")
    d = ImageDraw.Draw(sheet)
    y = 120
    for pid in PET_ORDER:
        meta = pet_meta(traits, pid)
        d.rounded_rectangle([28, y, w - 28, y + row_h], radius=10, fill=CARD)
        d.text((40, y + row_h // 2 - 10), f"{pid}", font=font(18), fill=ACCENT)
        d.text((40, y + row_h // 2 + 12), meta["name"], font=font(13, bold=False), fill=TEXT_DIM)
        x = 40 + label_w
        for c in meta["colors"]:
            cid = c["id"]
            pet = load_pet_stack(pid, cid, "normal", "smile", None)
            content = scale_nearest(pet, thumb - 8)
            cell = Image.new("RGBA", (thumb, thumb + 22), (0, 0, 0, 0))
            panel = Image.new("RGBA", (thumb, thumb), CELL_BG)
            panel.alpha_composite(content, (4, 4))
            cell.alpha_composite(panel, (0, 0))
            cd = ImageDraw.Draw(cell)
            f = font(11)
            bb = cd.textbbox((0, 0), cid, font=f)
            tw = bb[2] - bb[0]
            cd.text(((thumb - tw) // 2, thumb + 2), cid, font=f, fill=TEXT)
            sheet.alpha_composite(cell, (x, y + 4))
            x += thumb + gap
        y += row_h + 10
    draw_footer(sheet)
    return sheet


def sheet_03_eyes_mouths(traits) -> Image.Image:
    """Overview: 4 representative pets × all eyes, then × all mouths."""
    reps = ["P01", "P07", "P08", "P12"]  # blob, profile dragon, frog, robot
    thumb = 88
    gap = 8
    label_w = 120
    n_eye = len(EYE_ORDER)
    n_mouth = len(MOUTH_ORDER)
    # width from eyes section (same as mouths)
    w = 40 + label_w + n_eye * (thumb + gap) + 40
    # title + eyes header + 4 rows + mouths header + 4 rows
    section_gap = 28
    row_h = thumb + 8
    h = (110 + 36 + 4 * row_h + 24
         + section_gap + 36 + 4 * row_h + 50)
    sheet = Image.new("RGBA", (w, h), BG_DARK)
    draw_title(sheet, "03 — Eyes & Mouths",
               "Same ID set on every pet · shown on PUDD / DRAKELET / BLOP / BOLT")
    d = ImageDraw.Draw(sheet)

    def draw_matrix(y0: int, section: str, variants: list[str], kind: str) -> int:
        d.text((40, y0), section, font=font(22), fill=ACCENT)
        y0 += 30
        # column headers
        x = 40 + label_w
        for v in variants:
            f = font(11)
            bb = d.textbbox((0, 0), v, font=f)
            tw = bb[2] - bb[0]
            d.text((x + (thumb - tw) // 2, y0), v, font=f, fill=TEXT_DIM)
            x += thumb + gap
        y0 += 18
        for pid in reps:
            meta = pet_meta(traits, pid)
            col = default_color(traits, pid)
            d.text((40, y0 + thumb // 2 - 8), f"{pid}", font=font(16), fill=TEXT)
            d.text((40, y0 + thumb // 2 + 12), meta["name"], font=font(11, bold=False), fill=TEXT_DIM)
            x = 40 + label_w
            for v in variants:
                if kind == "eyes":
                    pet = load_pet_stack(pid, col, v, "smile", None)
                else:
                    pet = load_pet_stack(pid, col, "normal", v, None)
                content = scale_nearest(pet, thumb - 6)
                panel = Image.new("RGBA", (thumb, thumb), CELL_BG)
                panel.alpha_composite(content, (3, 3))
                sheet.alpha_composite(panel, (x, y0))
                x += thumb + gap
            y0 += row_h
        return y0

    y = 118
    y = draw_matrix(y, "EYES (10)", EYE_ORDER, "eyes")
    y += section_gap
    y = draw_matrix(y, "MOUTHS (10)", MOUTH_ORDER, "mouths")
    draw_footer(sheet)
    return sheet


def sheet_04_accessories(traits) -> Image.Image:
    """Standard set on P01 + exception callouts."""
    thumb = 110
    cells = []
    for acc in ACC_STANDARD:
        pet = load_pet_stack("P01", "pink", "happy", "smile", acc if acc != "none" else None)
        # for none, explicitly no acc
        if acc == "none":
            pet = load_pet_stack("P01", "pink", "happy", "smile", None)
        content = scale_nearest(pet, 96)
        cells.append(labeled_cell(content, acc, 140, label_h=34))

    # Build sheet with note banner
    cols = 5
    cw, ch = cells[0].size
    gap = 14
    pad = 28
    note_h = 130
    rows = 2
    w = pad * 2 + cols * cw + (cols - 1) * gap
    h = 110 + note_h + pad + rows * ch + (rows - 1) * gap + 50
    sheet = Image.new("RGBA", (w, h), BG_DARK)
    draw_title(sheet, "04 — Accessories",
               "Standard set on PUDD · exceptions below")
    d = ImageDraw.Draw(sheet)
    # notes panel
    d.rounded_rectangle([28, 110, w - 28, 110 + note_h - 10], radius=12, fill=CARD)
    d.text((48, 122), "Rules", font=font(18), fill=ACCENT)
    lines = [
        "• Every pet starts with none (no accessory layer).",
        "• Default set (10): none, hat, crown, bow, bandana, headphones, glasses, flower, bowtie, party_hat.",
        "• P07 DRAKELET — glasses only (none + glasses).",
        "• P02 SNAG / P10 PIP / P11 GILLI — no headphones (9 total).",
    ]
    yy = 148
    for line in lines:
        d.text((48, yy), line, font=font(15, bold=False), fill=TEXT)
        yy += 22

    y0 = 110 + note_h
    for i, cell in enumerate(cells):
        r, c = divmod(i, cols)
        x = pad + c * (cw + gap)
        y = y0 + r * (ch + gap)
        sheet.alpha_composite(cell, (x, y))
    draw_footer(sheet)
    return sheet


def sheet_05_eggs(traits) -> Image.Image:
    cells = []
    for e in traits["eggs"]:
        egg = Image.open(LAYERS / "eggs" / e["file"]).convert("RGBA")
        content = scale_nearest(egg, 160)
        label = f"{e['id']}  {e['pet']}"
        cells.append(labeled_cell(content, label, 210, label_h=40))
    return grid_sheet(
        "05 — Eggs",
        "12 pet-linked eggs E01–E12 · dormant state",
        cells, cols=4, gap=16,
    )


def sheet_06_handhelds(traits) -> Image.Image:
    cells = []
    for h in traits["handhelds"]:
        hid = h["id"]
        img = compose_thumb(
            handheld=hid, color="cream", class_name="ALPHA", pet_id="1",
            buttons="gray", antenna="classic", screen="S01", fx="scanlines",
            pet="P01", pet_color="pink", eyes="happy", mouth="smile", acc="none",
            bg="BG02",
        )
        thumb = resize_lanczos(img, 220)
        cells.append(labeled_cell(thumb, f"{hid}  {h['name']}", 240, label_h=40))
    return grid_sheet(
        "06 — Handhelds",
        "H01–H10 device family · on-device",
        cells, cols=5, gap=14,
    )


def sheet_07_shell_colors(traits) -> Image.Image:
    cells = []
    for c in traits["shell_colors"]:
        cid = c["id"]
        img = compose_thumb(
            handheld="H01", color=cid, class_name="BETA", pet_id="7",
            buttons="gray", antenna="classic", screen="S01", fx="scanlines",
            pet="P03", pet_color="orange", eyes="normal", mouth="smile", acc="none",
            bg="BG01",
        )
        thumb = resize_lanczos(img, 200)
        cells.append(labeled_cell(thumb, cid, 220, label_h=36))
    return grid_sheet(
        "07 — Shell Colors",
        "15 shell tints on H01 Classic",
        cells, cols=5, gap=14,
    )


def sheet_08_shell_class(traits) -> Image.Image:
    cells = []
    for sc in traits["shell_class"]:
        cid = sc["id"]
        img = compose_thumb(
            handheld="H01", color="mint", class_name=cid, pet_id="42",
            buttons="green", antenna="star", screen="S02", fx="sparkles",
            pet="P01", pet_color="lavender", eyes="happy", mouth="smile", acc="none",
            bg="BG02",
        )
        thumb = resize_lanczos(img, 320)
        cells.append(labeled_cell(thumb, cid, 360, label_h=44))
    return grid_sheet(
        "08 — Shell Class",
        "ALPHA · BETA · DELTA · OMEGA",
        cells, cols=4, gap=20,
    )


def sheet_09_buttons(traits) -> Image.Image:
    cells = []
    for b in traits["buttons"]:
        bid = b["id"]
        img = compose_thumb(
            handheld="H01", color="cream", class_name="ALPHA", pet_id="3",
            buttons=bid, antenna="classic", screen="S01", fx="scanlines",
            pet="P04", pet_color="tan", eyes="happy", mouth="smile", acc="none",
            bg="BG03",
        )
        # crop lower half-ish where buttons live for prominence, but keep full device readable
        thumb = resize_lanczos(img, 210)
        cells.append(labeled_cell(thumb, bid, 230, label_h=36))
    return grid_sheet(
        "09 — Buttons",
        "8 button colorways · 3 chips under screen",
        cells, cols=4, gap=14,
    )


def sheet_10_antennas(traits) -> Image.Image:
    """Large/prominent antenna crops on-device."""
    cells = []
    for i, a in enumerate(traits["antennas"], 1):
        aid = a["id"]
        img = compose_thumb(
            handheld="H01", color="light_blue", class_name="ALPHA", pet_id="10",
            buttons="blue", antenna=aid, screen="S01", fx="scanlines",
            pet="P06", pet_color="cyan", eyes="excited", mouth="open_smile", acc="none",
            bg="BG02",
        )
        # Crop top-center antenna region and enlarge
        # Antenna sits near top of device; device is centered on 2048 canvas
        crop = img.crop((700, 180, 1348, 700)).resize((280, 240), Image.Resampling.LANCZOS)
        # Also include a smaller full device for context
        full = resize_lanczos(img, 120)
        panel_art = Image.new("RGBA", (300, 280), (0, 0, 0, 0))
        panel_art.alpha_composite(crop, (10, 0))
        panel_art.alpha_composite(full, (300 - 120 - 4, 280 - 120 - 4))
        label = f"A{i:02d}  {aid}"
        cells.append(labeled_cell(panel_art, label, 320, label_h=40))
    return grid_sheet(
        "10 — Antennas",
        "10 antennas · large crop + full device inset",
        cells, cols=5, gap=14,
    )


def sheet_11_screens(traits) -> Image.Image:
    cells = []
    for s in traits["screens"]:
        sid = s["id"]
        # Skip incompatible? S01-S08 on H01 should all work
        img = compose_thumb(
            handheld="H01", color="white", class_name="BETA", pet_id="11",
            buttons="pink", antenna="orb", screen=sid, fx="scanlines",
            pet="P05", pet_color="pink", eyes="sparkly", mouth="smile", acc="bow",
            bg="BG01",
        )
        thumb = resize_lanczos(img, 220)
        name = s.get("name", sid)
        cells.append(labeled_cell(thumb, f"{sid}  {name}", 250, label_h=44))
    return grid_sheet(
        "11 — Screens / Bezels",
        "8 differentiated bezel styles S01–S08",
        cells, cols=4, gap=14,
    )


def sheet_12_screen_effects(traits) -> Image.Image:
    cells = []
    for i, fx in enumerate(traits["screen_effects"], 1):
        fid = fx["id"]
        # Show FX pixel art large + small on-device optional — large still is clearer
        fx_img = Image.open(LAYERS / "screen_effects" / fx["file"]).convert("RGBA")
        content = scale_nearest(fx_img, 160)
        cells.append(labeled_cell(content, f"FX{i:02d}  {fid}", 200, label_h=40))
    return grid_sheet(
        "12 — Screen Effects",
        "12 FX stills · pixel layer behind pet",
        cells, cols=4, gap=16,
    )


def sheet_13_backgrounds(traits) -> Image.Image:
    cells = []
    for b in traits["backgrounds"]:
        bid = b["id"]
        bg = Image.open(LAYERS / "backgrounds" / b["file"]).convert("RGBA")
        thumb = resize_lanczos(bg, 180)
        name = b.get("name", bid)
        # shorten long names
        label = f"{bid}"
        sub = name if len(name) < 22 else name[:20] + "…"
        cell = labeled_cell(thumb, f"{label}  {sub}", 210, label_h=44)
        cells.append(cell)
    return grid_sheet(
        "13 — Backgrounds",
        "14 Robinhood-green backgrounds",
        cells, cols=7, gap=12,
    )


def sheet_14_pet_id_and_name(traits) -> Image.Image:
    """Show Pet ID plate + owner name overlay."""
    samples = [
        dict(pet="P01", pet_color="pink", pet_id="1", pet_name="travvvman",
             handheld="H01", color="cream", class_name="ALPHA", antenna="star",
             buttons="yellow", screen="S01", fx="sparkles", eyes="happy",
             mouth="smile", acc="hat", bg="BG02", label="PET #0001 + travvvman"),
        dict(pet="P03", pet_color="orange", pet_id="42", pet_name="travvvman",
             handheld="H03", color="pink", class_name="BETA", antenna="heart",
             buttons="pink", screen="S02", fx="stars", eyes="sparkly",
             mouth="tongue", acc="bow", bg="BG04", label="PET #0042 + travvvman"),
        dict(pet="P07", pet_color="crimson", pet_id="777", pet_name="travvvman",
             handheld="H05", color="mint", class_name="DELTA", antenna="crown",
             buttons="green", screen="S06", fx="fire", eyes="angry",
             mouth="angry", acc="glasses", bg="BG07", label="PET #0777 + travvvman"),
        dict(pet="P12", pet_color="steel", pet_id="1337", pet_name="travvvman",
             handheld="H10", color="black", class_name="OMEGA", antenna="lightning",
             buttons="orange", screen="S05", fx="glitch", eyes="excited",
             mouth="funny", acc="party_hat", bg="BG01", label="PET #1337 + travvvman"),
    ]
    cells = []
    for s in samples:
        label = s.pop("label")
        img = compose_thumb(**s)
        thumb = resize_lanczos(img, 360)
        cells.append(labeled_cell(thumb, label, 400, label_h=44))

    # Also add close-up crops of ID plate and name
    # Recompose first sample for crops
    full = compose_thumb(
        pet="P01", pet_color="pink", pet_id="1", pet_name="travvvman",
        handheld="H01", color="cream", class_name="ALPHA", antenna="star",
        buttons="yellow", screen="S01", fx="sparkles", eyes="happy",
        mouth="smile", acc="hat", bg="BG02",
    )
    # pet_id is near bottom of shell; name is lower-left of screen well
    # Use generous crops
    id_crop = full.crop((780, 1480, 1268, 1680)).resize((400, 160), Image.Resampling.LANCZOS)
    name_crop = full.crop((720, 1050, 1180, 1320)).resize((400, 160), Image.Resampling.LANCZOS)

    cols = 2
    gap = 24
    pad = 28
    cw, ch = cells[0].size
    rows = 2
    detail_h = 280
    sheet_w = pad * 2 + cols * cw + (cols - 1) * gap
    sheet_h = 110 + 30 + rows * ch + (rows - 1) * gap + detail_h + 50
    sheet = Image.new("RGBA", (sheet_w, sheet_h), BG_DARK)
    draw_title(sheet, "14 — Pet ID & Owner Name",
               "Dynamic PET #NNNN plate on shell · owner name lower-left in screen")
    d = ImageDraw.Draw(sheet)
    d.text((40, 112), "Full PFPs with both overlays", font=font(18), fill=ACCENT_SOFT)
    y0 = 140
    for i, cell in enumerate(cells):
        r, c = divmod(i, cols)
        x = pad + c * (cw + gap)
        y = y0 + r * (ch + gap)
        sheet.alpha_composite(cell, (x, y))
    y_det = y0 + 2 * (ch + gap) + 8
    d.text((40, y_det), "Close-ups (PET # plate · travvvman name plate)", font=font(18), fill=ACCENT_SOFT)
    y_det += 28
    # detail cards
    for crop, lab, xx in [(id_crop, "PET #0001 plate", pad),
                          (name_crop, "travvvman (screen LL)", pad + 420)]:
        card = Image.new("RGBA", (410, 200), CARD)
        card.alpha_composite(crop, (5, 5))
        cd = ImageDraw.Draw(card)
        cd.text((12, 172), lab, font=font(16), fill=TEXT)
        sheet.alpha_composite(card, (xx, y_det))
    draw_footer(sheet)
    return sheet


def sheet_15_sample_pfps(traits) -> Image.Image:
    samples = [
        dict(bg="BG02", handheld="H01", color="cream", class_name="ALPHA", pet_id="421",
             buttons="yellow", antenna="star", screen="S01", fx="scanlines",
             pet="P02", pet_color="green", eyes="happy", mouth="smile", acc="crown",
             pet_name="travvvman", label="SNAG · classic"),
        dict(bg="BG04", handheld="H03", color="pink", class_name="BETA", pet_id="7",
             buttons="pink", antenna="heart", screen="S02", fx="sparkles",
             pet="P03", pet_color="calico", eyes="sparkly", mouth="tongue", acc="bow",
             pet_name="", label="MEOWLET · wide"),
        dict(bg="BG05", handheld="H05", color="mint", class_name="DELTA", pet_id="99",
             buttons="green", antenna="flower", screen="S06", fx="bubbles",
             pet="P01", pet_color="lavender", eyes="hearts", mouth="laugh", acc="flower",
             pet_name="travvvman", label="PUDD · egg shell"),
        dict(bg="BG01", handheld="H08", color="purple", class_name="OMEGA", pet_id="1337",
             buttons="orange", antenna="lightning", screen="S05", fx="glitch",
             pet="P12", pet_color="steel", eyes="excited", mouth="funny", acc="party_hat",
             pet_name="", label="BOLT · large"),
        dict(bg="BG07", handheld="H09", color="yellow", class_name="ALPHA", pet_id="55",
             buttons="black", antenna="crown", screen="S01", fx="stars",
             pet="P07", pet_color="crimson", eyes="angry", mouth="angry", acc="glasses",
             pet_name="", label="DRAKELET · retro"),
        dict(bg="BG14", handheld="H02", color="light_blue", class_name="BETA", pet_id="888",
             buttons="blue", antenna="orb", screen="S02", fx="clouds",
             pet="P11", pet_color="coral", eyes="wink", mouth="smile", acc="flower",
             pet_name="travvvman", label="GILLI · rounded"),
        dict(bg="BG09", handheld="H06", color="lavender", class_name="DELTA", pet_id="12",
             buttons="pink", antenna="mushroom", screen="S08", fx="leaves",
             pet="P10", pet_color="yellow", eyes="happy", mouth="open_smile", acc="hat",
             pet_name="", label="PIP · capsule"),
        dict(bg="BG11", handheld="H10", color="black", class_name="OMEGA", pet_id="9999",
             buttons="gray", antenna="double", screen="S05", fx="digital_grid",
             pet="P04", pet_color="golden", eyes="sparkly", mouth="tongue", acc="bandana",
             pet_name="travvvman", label="PUPPO · collector"),
    ]
    cells = []
    for s in samples:
        label = s.pop("label")
        img = compose_thumb(**s)
        thumb = resize_lanczos(img, 280)
        cells.append(labeled_cell(thumb, label, 300, label_h=40))
    return grid_sheet(
        "15 — Sample PFPs",
        "8 composed showcases mixing current traits",
        cells, cols=4, gap=16,
    )


def build_overview(paths: dict[str, Path]) -> Image.Image:
    """Compact 4×4 glance cover of section thumbnails with titles."""
    order = [
        ("00-index.png", "00 Index"),
        ("01-pets.png", "01 Pets"),
        ("02-pet-colors.png", "02 Colors"),
        ("03-eyes-mouths.png", "03 Eyes/Mouths"),
        ("04-accessories.png", "04 Accessories"),
        ("05-eggs.png", "05 Eggs"),
        ("06-handhelds.png", "06 Handhelds"),
        ("07-shell-colors.png", "07 Shell Colors"),
        ("08-shell-class.png", "08 Shell Class"),
        ("09-buttons.png", "09 Buttons"),
        ("10-antennas.png", "10 Antennas"),
        ("11-screens.png", "11 Screens"),
        ("12-screen-effects.png", "12 Screen FX"),
        ("13-backgrounds.png", "13 Backgrounds"),
        ("14-pet-id-and-name.png", "14 Pet ID/Name"),
        ("15-sample-pfps.png", "15 Samples"),
    ]
    cols = 4
    thumb_w, thumb_h = 320, 220
    gap = 16
    pad = 28
    label_h = 32
    rows = (len(order) + cols - 1) // cols
    w = pad * 2 + cols * thumb_w + (cols - 1) * gap
    h = 110 + pad + rows * (thumb_h + label_h + 8) + (rows - 1) * gap + 50
    sheet = Image.new("RGBA", (w, h), BG_DARK)
    draw_title(sheet, "Terminal Pets — Master Overview",
               "Trait library cover · sheets in previews/gallery/master/")
    d = ImageDraw.Draw(sheet)
    y0 = 110
    for i, (fname, title) in enumerate(order):
        r, c = divmod(i, cols)
        x = pad + c * (thumb_w + gap)
        y = y0 + r * (thumb_h + label_h + 8 + gap)
        path = paths.get(fname)
        if not path or not path.exists():
            continue
        im = Image.open(path).convert("RGBA")
        tw, th = im.size
        target_aspect = thumb_w / thumb_h
        src_aspect = tw / th
        if src_aspect > target_aspect:
            new_w = int(th * target_aspect)
            left = (tw - new_w) // 2
            im = im.crop((left, 0, left + new_w, th))
        else:
            new_h = int(tw / target_aspect)
            top = min(90, max(0, (th - new_h) // 5))
            im = im.crop((0, top, tw, top + new_h))
        im = im.resize((thumb_w - 8, thumb_h - 8), Image.Resampling.LANCZOS)
        card = Image.new("RGBA", (thumb_w, thumb_h), CARD)
        card.alpha_composite(im, (4, 4))
        sheet.alpha_composite(card, (x, y))
        f = font(15)
        bb = d.textbbox((0, 0), title, font=f)
        twl = bb[2] - bb[0]
        d.text((x + (thumb_w - twl) // 2, y + thumb_h + 6), title, font=f, fill=TEXT)
    draw_footer(sheet, "Terminal Pets — Trait Library · glance cover")
    return sheet



def trait_counts(traits) -> dict:
    acc_counts = {}
    for pid in PET_ORDER:
        acc_counts[pid] = len(pet_meta(traits, pid)["accessories"])
    return {
        "pets": 12,
        "pet_colors": 12 * 8,
        "eyes": 10,
        "mouths": 10,
        "accessories_standard": 10,
        "accessories_per_pet": acc_counts,
        "eggs": len(traits["eggs"]),
        "handhelds": len(traits["handhelds"]),
        "shell_colors": len(traits["shell_colors"]),
        "shell_class": len(traits["shell_class"]),
        "buttons": len(traits["buttons"]),
        "antennas": len(traits["antennas"]),
        "screens": len(traits["screens"]),
        "screen_effects": len(traits["screen_effects"]),
        "backgrounds": len(traits["backgrounds"]),
        "pet_id": "dynamic PET #NNNN",
        "pet_name": "dynamic owner name overlay",
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    traits = load_json("traits.json")
    builders = [
        ("00-index.png", lambda: sheet_00_index(traits)),
        ("01-pets.png", lambda: sheet_01_pets(traits)),
        ("02-pet-colors.png", lambda: sheet_02_pet_colors(traits)),
        ("03-eyes-mouths.png", lambda: sheet_03_eyes_mouths(traits)),
        ("04-accessories.png", lambda: sheet_04_accessories(traits)),
        ("05-eggs.png", lambda: sheet_05_eggs(traits)),
        ("06-handhelds.png", lambda: sheet_06_handhelds(traits)),
        ("07-shell-colors.png", lambda: sheet_07_shell_colors(traits)),
        ("08-shell-class.png", lambda: sheet_08_shell_class(traits)),
        ("09-buttons.png", lambda: sheet_09_buttons(traits)),
        ("10-antennas.png", lambda: sheet_10_antennas(traits)),
        ("11-screens.png", lambda: sheet_11_screens(traits)),
        ("12-screen-effects.png", lambda: sheet_12_screen_effects(traits)),
        ("13-backgrounds.png", lambda: sheet_13_backgrounds(traits)),
        ("14-pet-id-and-name.png", lambda: sheet_14_pet_id_and_name(traits)),
        ("15-sample-pfps.png", lambda: sheet_15_sample_pfps(traits)),
    ]
    paths = {}
    for fname, fn in builders:
        print(f"Building {fname} …", flush=True)
        img = fn()
        out = OUT / fname
        img.save(out, optimize=True)
        paths[fname] = out
        print(f"  → {out} ({img.size[0]}×{img.size[1]})", flush=True)

    print("Building master-overview.png …", flush=True)
    overview = build_overview(paths)
    overview_path = GALLERY / "master-overview.png"
    overview.save(overview_path, optimize=True)
    print(f"  → {overview_path} ({overview.size[0]}×{overview.size[1]})", flush=True)

    counts = trait_counts(traits)
    print("\n=== TRAIT COUNTS ===")
    for k, v in counts.items():
        print(f"  {k}: {v}")
    print("\n=== OUTPUTS ===")
    for fname in [b[0] for b in builders]:
        print(f"  {OUT / fname}")
    print(f"  {overview_path}")


if __name__ == "__main__":
    main()
