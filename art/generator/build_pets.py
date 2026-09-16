"""Procedural 64×64 pixel-art pets, eggs, FX, animations. Original designs only."""
from __future__ import annotations
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
from common import (
    LAYERS, ANIM, ROOT, load_json, hex_to_rgba, hex_to_rgb, shade,
    outline_pixels, new_canvas, scale_pixel_to_screen
)

def _opt_id(opt):
    """Trait option may be a string id or {id, rarity, weight, ...}."""
    return opt["id"] if isinstance(opt, dict) else opt


OUTLINE = (25, 22, 30, 255)
WHITE = (255, 255, 255, 255)
BLACK = (20, 18, 25, 255)

def blank64():
    return Image.new("RGBA", (64, 64), (0, 0, 0, 0))

def px(img, x, y, c):
    if 0 <= x < 64 and 0 <= y < 64:
        img.putpixel((x, y), c)

def rect(img, x, y, w, h, c):
    for yy in range(y, y+h):
        for xx in range(x, x+w):
            px(img, xx, yy, c)

def ellipse_fill(img, x0, y0, x1, y1, c):
    d = ImageDraw.Draw(img)
    d.ellipse([x0, y0, x1, y1], fill=c)

def circ(img, cx, cy, r, c):
    ellipse_fill(img, cx-r, cy-r, cx+r, cy+r, c)

def fill_poly(img, pts, c):
    ImageDraw.Draw(img).polygon(pts, fill=c)

def tint_body(gray_body: Image.Image, hexcol: str) -> Image.Image:
    """Map grayscale body to colored: dark→outline stays, mid→shade, light→base/hi."""
    r, g, b = hex_to_rgb(hexcol)
    shade_c = shade((r,g,b), 0.7)
    hi_c = tuple(min(255, int(c*1.15+20)) for c in (r,g,b))
    out = gray_body.copy()
    p = out.load()
    for y in range(64):
        for x in range(64):
            pr, pg, pb, pa = p[x, y]
            if pa < 10:
                continue
            if pr < 40:  # outline
                p[x, y] = OUTLINE
            elif pr < 100:  # shade
                p[x, y] = (*shade_c, pa)
            elif pr < 180:  # base
                p[x, y] = (r, g, b, pa)
            else:  # highlight
                p[x, y] = (*hi_c, pa)
    return out

# Intensity keys for grayscale body drawing
OL, SH, BS, HI = (30,30,30,255), (90,90,90,255), (150,150,150,255), (210,210,210,255)

def finalize_body(img):
    return outline_pixels(img, OUTLINE)

# ===================== PET BODIES =====================
def body_pudd():
    img = blank64()
    # round blob
    ellipse_fill(img, 16, 20, 47, 50, BS)
    ellipse_fill(img, 20, 24, 43, 42, HI)  # highlight
    ellipse_fill(img, 18, 38, 45, 52, SH)  # shade bottom
    # stub feet
    rect(img, 22, 50, 6, 4, SH)
    rect(img, 36, 50, 6, 4, SH)
    return finalize_body(img)

def body_snag():
    img = blank64()
    # body 3/4 facing left
    ellipse_fill(img, 20, 26, 48, 52, BS)
    ellipse_fill(img, 24, 28, 42, 44, HI)
    # head/snout left
    ellipse_fill(img, 8, 20, 28, 38, BS)
    ellipse_fill(img, 8, 28, 18, 34, SH)  # snout
    # tail
    ellipse_fill(img, 44, 30, 58, 42, BS)
    rect(img, 52, 28, 6, 4, SH)
    # tiny arms
    rect(img, 22, 36, 5, 3, SH)
    rect(img, 34, 38, 5, 3, SH)
    # legs
    rect(img, 24, 50, 5, 5, SH)
    rect(img, 38, 50, 5, 5, SH)
    # crest bumps
    circ(img, 22, 16, 3, BS)
    circ(img, 28, 14, 3, BS)
    return finalize_body(img)

def body_meowlet():
    img = blank64()
    # head
    ellipse_fill(img, 16, 20, 47, 48, BS)
    ellipse_fill(img, 20, 24, 42, 38, HI)
    # ears triangles
    d = ImageDraw.Draw(img)
    d.polygon([(18,22),(22,8),(28,20)], fill=BS)
    d.polygon([(36,20),(42,8),(46,22)], fill=BS)
    d.polygon([(20,20),(23,11),(27,20)], fill=HI)
    d.polygon([(37,20),(41,11),(44,20)], fill=SH)
    # body
    ellipse_fill(img, 20, 42, 44, 56, BS)
    # paws
    rect(img, 22, 54, 5, 3, SH)
    rect(img, 37, 54, 5, 3, SH)
    return finalize_body(img)

def body_puppo():
    """Front-facing Tamagotchi-simple puppy: soft oval, matching floppy ears, stub muzzle."""
    img = blank64()
    # Soft oval head+body almost one shape (like PUDD / BRUMBLE)
    ellipse_fill(img, 16, 16, 47, 52, BS)
    ellipse_fill(img, 18, 42, 45, 52, SH)
    # LEFT floppy ear — big readable hanging oval (solid, no inner-ear chaos)
    ellipse_fill(img, 5, 14, 17, 38, BS)
    # RIGHT floppy ear — identical mirror
    ellipse_fill(img, 47, 14, 59, 38, BS)
    # Short stubby muzzle = SMALL lighter oval on lower face
    ellipse_fill(img, 26, 34, 38, 44, HI)
    # Tiny black nose = 2×2 pixels on muzzle
    rect(img, 31, 36, 2, 2, OL)
    # Two stubby feet only
    rect(img, 22, 52, 6, 4, SH)
    rect(img, 36, 52, 6, 4, SH)
    # Tiny round tail nub on side — keep minimal
    circ(img, 50, 46, 3, SH)
    return finalize_body(img)


def body_hoplit():
    img = blank64()
    # tall ears
    ellipse_fill(img, 20, 4, 28, 28, BS)
    ellipse_fill(img, 36, 4, 44, 28, BS)
    ellipse_fill(img, 22, 8, 26, 24, HI)
    ellipse_fill(img, 38, 8, 42, 24, HI)
    # oval body
    ellipse_fill(img, 18, 24, 45, 54, BS)
    ellipse_fill(img, 22, 28, 40, 44, HI)
    # feet
    rect(img, 22, 52, 6, 4, SH)
    rect(img, 36, 52, 6, 4, SH)
    return finalize_body(img)

def body_zorp():
    img = blank64()
    # teardrop head/body
    ellipse_fill(img, 16, 14, 47, 54, BS)
    ellipse_fill(img, 20, 18, 42, 40, HI)
    # stalk nubs
    circ(img, 22, 10, 4, BS)
    circ(img, 42, 10, 4, BS)
    rect(img, 20, 10, 4, 8, SH)
    rect(img, 40, 10, 4, 8, SH)
    # tip bottom
    ellipse_fill(img, 24, 48, 40, 58, SH)
    return finalize_body(img)

def body_drakelet():
    """Tiny dragon 3/4-left: elongated snout, horn, bat wing, curling tail, 4 legs."""
    img = blank64()
    # Torso
    ellipse_fill(img, 24, 28, 50, 50, BS)
    ellipse_fill(img, 30, 30, 44, 42, HI)
    # Head
    ellipse_fill(img, 12, 14, 32, 34, BS)
    ellipse_fill(img, 16, 16, 28, 26, HI)
    # Elongated snout facing LEFT
    ellipse_fill(img, 1, 22, 14, 32, BS)
    rect(img, 1, 24, 8, 6, SH)
    rect(img, 2, 28, 10, 3, SH)
    # Horn / crest
    fill_poly(img, [(18, 14), (22, 2), (28, 14)], HI)
    fill_poly(img, [(20, 14), (22, 6), (26, 14)], BS)
    # Bat wing with membrane panels
    fill_poly(img, [
        (36, 20), (44, 6), (56, 10), (58, 20), (54, 28), (46, 30), (38, 26),
    ], SH)
    fill_poly(img, [(38, 20), (44, 10), (50, 14), (42, 24)], BS)
    fill_poly(img, [(42, 22), (50, 14), (54, 22), (46, 28)], BS)
    d = ImageDraw.Draw(img)
    for x0, y0, x1, y1 in [(36, 20, 44, 6), (36, 22, 56, 12), (38, 24, 54, 28)]:
        d.line([(x0, y0), (x1, y1)], fill=OL, width=1)
    # Curling tail + spade tip
    ellipse_fill(img, 48, 40, 60, 52, BS)
    fill_poly(img, [(56, 46), (62, 36), (63, 40), (60, 50), (56, 52)], SH)
    fill_poly(img, [(60, 38), (63, 42), (60, 46), (58, 42)], HI)
    # Four stubby legs
    for i, lx in enumerate([24, 32, 40, 46]):
        ly = 48 if i % 2 == 0 else 50
        rect(img, lx, ly, 5, 7, SH)
        rect(img, lx - 1, ly + 6, 7, 2, BS)
    return finalize_body(img)

def body_blop():
    img = blank64()
    # wide squat
    ellipse_fill(img, 10, 26, 53, 54, BS)
    ellipse_fill(img, 16, 30, 48, 46, HI)
    # eye bumps on TOP
    circ(img, 22, 22, 7, BS)
    circ(img, 42, 22, 7, BS)
    circ(img, 22, 20, 4, HI)
    circ(img, 42, 20, 4, HI)
    # feet
    rect(img, 16, 52, 8, 4, SH)
    rect(img, 40, 52, 8, 4, SH)
    return finalize_body(img)

def body_brumble():
    img = blank64()
    ellipse_fill(img, 14, 18, 49, 54, BS)
    ellipse_fill(img, 20, 22, 42, 42, HI)
    # round ears
    circ(img, 18, 16, 6, BS)
    circ(img, 46, 16, 6, BS)
    circ(img, 18, 16, 3, HI)
    circ(img, 46, 16, 3, SH)
    # snout suggestion
    ellipse_fill(img, 26, 38, 38, 48, HI)
    rect(img, 22, 52, 6, 4, SH)
    rect(img, 36, 52, 6, 4, SH)
    return finalize_body(img)

def body_pip():
    """Bird: round body+head WITHOUT beak, flat L face, teardrop wings, crest, stick legs."""
    img = blank64()
    # Plump body
    ellipse_fill(img, 20, 26, 46, 52, BS)
    ellipse_fill(img, 24, 30, 40, 44, HI)
    # Distinct round head
    ellipse_fill(img, 16, 10, 42, 34, BS)
    ellipse_fill(img, 22, 12, 38, 26, HI)
    # Flat left face plate for beak attach
    rect(img, 15, 18, 5, 12, BS)
    for yy in range(20, 30):
        px(img, 15, yy, BS)
        px(img, 16, yy, HI if 22 <= yy <= 26 else BS)
    # Crest tuft (3 feathers)
    fill_poly(img, [(26, 12), (27, 2), (30, 12)], BS)
    fill_poly(img, [(30, 10), (32, 3), (34, 10)], HI)
    fill_poly(img, [(28, 10), (29, 5), (31, 10)], SH)
    # Teardrop wing nubs (not flipper circles)
    fill_poly(img, [(18, 32), (8, 38), (10, 48), (18, 44), (22, 36)], SH)
    fill_poly(img, [(17, 34), (11, 39), (13, 46), (18, 42)], BS)
    fill_poly(img, [(46, 32), (56, 38), (54, 48), (46, 44), (42, 36)], SH)
    fill_poly(img, [(47, 34), (53, 39), (51, 46), (46, 42)], BS)
    # Stick legs + feet
    rect(img, 26, 50, 2, 8, SH)
    rect(img, 36, 50, 2, 8, SH)
    rect(img, 23, 57, 8, 2, SH)
    rect(img, 33, 57, 8, 2, SH)
    return finalize_body(img)

def body_gilli():
    """Axolotl: soft round body, THREE feathery branching gill fronds per side."""
    img = blank64()
    ellipse_fill(img, 18, 14, 46, 52, BS)
    ellipse_fill(img, 22, 18, 40, 38, HI)
    ellipse_fill(img, 24, 40, 40, 50, SH)

    def fern(ox, oy, direction, length=12):
        for i in range(length):
            px(img, ox + direction * i, oy, BS)
            px(img, ox + direction * i, oy - 1, SH)
        pinnae = [
            (2, -2), (3, -3), (4, -4), (5, -3),
            (3, 2), (4, 3), (5, 4), (6, 3),
            (6, -3), (7, -5), (8, -4), (9, -3),
            (7, 3), (8, 5), (9, 4), (10, 2),
            (10, -2), (10, 0), (10, 1),
        ]
        for dx, dy in pinnae:
            if dx >= length:
                continue
            x = ox + direction * dx
            y = oy + dy
            px(img, x, y, SH if abs(dy) > 2 else BS)
            if abs(dy) >= 4:
                px(img, x, y + (1 if dy > 0 else -1), HI)
                px(img, x + direction, y, HI)

    fern(17, 18, -1, 12)
    fern(16, 28, -1, 13)
    fern(17, 38, -1, 12)
    fern(47, 18, +1, 12)
    fern(48, 28, +1, 13)
    fern(47, 38, +1, 12)
    rect(img, 24, 52, 6, 4, SH)
    rect(img, 34, 52, 6, 4, SH)
    return finalize_body(img)

def body_bolt():
    """Cute Tamagotchi-adjacent virtual-pet robot — hard geometric silhouette = ROBOT."""
    img = blank64()
    # Antenna stalk + LED bulb (body)
    rect(img, 30, 5, 4, 7, SH)
    rect(img, 31, 5, 2, 7, BS)
    circ(img, 32, 3, 3, HI)
    # LED core (recolored red after tint)
    px(img, 32, 3, OL); px(img, 31, 3, OL); px(img, 33, 3, OL)
    px(img, 32, 2, OL); px(img, 32, 4, OL)
    # Rounded rectangular HEAD
    rect(img, 16, 10, 32, 24, BS)
    for pts in [
        [(16, 10), (17, 10), (16, 11)],
        [(47, 10), (46, 10), (47, 11)],
        [(16, 33), (17, 33), (16, 32)],
        [(47, 33), (46, 33), (47, 32)],
    ]:
        for x, y in pts:
            img.putpixel((x, y), (0, 0, 0, 0))
    px(img, 17, 10, BS); px(img, 16, 11, BS); px(img, 16, 12, BS)
    px(img, 46, 10, BS); px(img, 47, 11, BS); px(img, 47, 12, BS)
    px(img, 17, 33, BS); px(img, 16, 32, BS); px(img, 16, 31, BS)
    px(img, 46, 33, BS); px(img, 47, 32, BS); px(img, 47, 31, BS)
    rect(img, 18, 11, 28, 5, HI)
    rect(img, 16, 18, 3, 14, SH)
    rect(img, 45, 18, 3, 14, SH)
    # Visor / screen-face panel (flat; eyes layer sits here)
    rect(img, 20, 16, 24, 12, SH)
    rect(img, 21, 17, 22, 10, OL)
    rect(img, 21, 17, 22, 1, SH)
    # Lower faceplate (mouth attaches here)
    rect(img, 22, 28, 20, 5, BS)
    rect(img, 24, 29, 16, 3, HI)
    # Neck joint
    rect(img, 28, 33, 8, 3, SH)
    rect(img, 29, 33, 6, 2, BS)
    # Chassis body
    rect(img, 20, 34, 24, 16, BS)
    rect(img, 22, 35, 20, 6, HI)
    rect(img, 20, 44, 24, 6, SH)
    px(img, 20, 49, (0, 0, 0, 0)); px(img, 43, 49, (0, 0, 0, 0))
    px(img, 21, 49, BS); px(img, 42, 49, BS)
    # Chest panel + bolt detail
    rect(img, 26, 38, 12, 8, SH)
    rect(img, 27, 39, 10, 6, BS)
    px(img, 31, 41, OL); px(img, 32, 41, OL)
    px(img, 31, 42, OL); px(img, 32, 42, OL)
    px(img, 30, 41, HI); px(img, 33, 42, HI)
    # Jointed blocky arms
    rect(img, 10, 36, 10, 5, BS)
    rect(img, 10, 36, 3, 5, SH)
    rect(img, 8, 40, 6, 5, SH)
    rect(img, 7, 44, 5, 4, BS)
    rect(img, 44, 36, 10, 5, BS)
    rect(img, 51, 36, 3, 5, SH)
    rect(img, 50, 40, 6, 5, SH)
    rect(img, 52, 44, 5, 4, BS)
    # Boot feet
    rect(img, 20, 50, 10, 7, SH)
    rect(img, 34, 50, 10, 7, SH)
    rect(img, 19, 55, 12, 3, BS)
    rect(img, 33, 55, 12, 3, BS)
    rect(img, 21, 51, 6, 2, HI)
    rect(img, 35, 51, 6, 2, HI)
    return finalize_body(img)


# Backward-compatible alias (folder id remains P12_nib)
body_nib = body_bolt

# Antenna LED pixels recolored after tint (red accent)
BOLT_LED_PIXELS = ((31, 2), (32, 2), (33, 2), (31, 3), (32, 3), (33, 3), (32, 4))
BOLT_LED_COLOR = (255, 64, 72, 255)
BOLT_LED_HI = (255, 160, 140, 255)

def apply_bolt_led(img: Image.Image) -> Image.Image:
    """Paint fixed red LED accent on BOLT antenna tip (survives color tint)."""
    out = img.copy()
    p = out.load()
    for x, y in BOLT_LED_PIXELS:
        if 0 <= x < 64 and 0 <= y < 64 and p[x, y][3] > 10:
            p[x, y] = BOLT_LED_HI if y == 2 and x == 32 else BOLT_LED_COLOR
    return out




BODIES = {
    "P01": body_pudd, "P02": body_snag, "P03": body_meowlet, "P04": body_puppo,
    "P05": body_hoplit, "P06": body_zorp, "P07": body_drakelet, "P08": body_blop,
    "P09": body_brumble, "P10": body_pip, "P11": body_gilli, "P12": body_nib,
}

# ===================== EYES (pet-specific) =====================
def draw_eyes(pet_id: str, variant: str, box: dict) -> Image.Image:
    """Draw eyes into the pet's eyes_64 rect so they sit on THAT anatomy.

    Every variant must be glance-distinct: shape/size/open-vs-closed first, color accents second.
    """
    img = blank64()
    x, y, w, h = box["x"], box["y"], box["w"], box["h"]

    if pet_id in ("P02", "P07", "P10"):
        # single eye on head / beside beak — wink must NOT equal sleepy
        size = max(4, min(w - 1, h - 1))
        ex = x + max(0, (w - size) // 2)
        ey = y + max(0, (h - size) // 2)
        _one_eye(img, ex, ey, size, variant, left=True, single=True)
    elif pet_id == "P12":
        # paired LED dots centered in visor rect
        _robot_eye(img, x + 2, y + max(0, h // 2 - 2), variant, left=True)
        _robot_eye(img, x + w - 8, y + max(0, h // 2 - 2), variant, left=False)
    elif pet_id == "P08":
        # eyes centered on the two TOP bulges (body circs ~22,20 and 42,20)
        size = 5
        _one_eye(img, 19, 17, size, variant, left=True)
        _one_eye(img, 39, 17, size, variant, left=False)
    elif pet_id == "P06":
        # huge ovals filling upper face box
        _one_eye(img, x + 1, y + 1, max(7, h - 2), variant, left=True, huge=True)
        _one_eye(img, x + w - max(9, h), y + 1, max(7, h - 2), variant, left=False, huge=True)
    elif pet_id == "P01":
        # close high-center pair
        size = max(3, h - 1)
        gap = 4
        _one_eye(img, x + 1, y + 1, size, variant, left=True)
        _one_eye(img, x + 1 + size + gap, y + 1, size, variant, left=False)
    else:
        # front-facing pair spanning box width
        size = max(3, min(h - 1, w // 3 + 1))
        _one_eye(img, x + 1, y + 1, size, variant, left=True)
        _one_eye(img, x + w - size - 1, y + 1, size, variant, left=False)
    return img


HEART_PINK = (255, 80, 120, 255)
SPARK_BLUE = (180, 220, 255, 255)


def _draw_heart(img, ex, ey, s):
    """Readable pink heart; scales with available eye size."""
    c = HEART_PINK
    # minimum 5×5 heart; grow for larger eyes
    if s <= 5:
        px(img, ex + 1, ey, c); px(img, ex + 3, ey, c)
        rect(img, ex, ey + 1, 5, 2, c)
        px(img, ex + 1, ey + 3, c); px(img, ex + 2, ey + 4, c); px(img, ex + 3, ey + 3, c)
    else:
        # wider heart
        px(img, ex + 1, ey, c); px(img, ex + 2, ey, c)
        px(img, ex + s - 3, ey, c); px(img, ex + s - 2, ey, c)
        rect(img, ex, ey + 1, s, max(2, s // 3), c)
        for i, row in enumerate(range(ey + 1 + max(2, s // 3), ey + s)):
            inset = i + 1
            if inset * 2 >= s:
                break
            for xx in range(ex + inset, ex + s - inset):
                px(img, xx, row, c)


def _sparkle_at(img, x, y):
    """Tiny 4-point sparkle accent (not another pupil)."""
    px(img, x, y, WHITE)
    px(img, x - 1, y, SPARK_BLUE)
    px(img, x + 1, y, SPARK_BLUE)
    px(img, x, y - 1, SPARK_BLUE)
    px(img, x, y + 1, SPARK_BLUE)


def _one_eye(img, ex, ey, size, style, left=True, huge=False, single=False):
    """Organic eye. Styles must stay glance-distinct even at 3–8px."""
    s = max(3, size)
    cx = ex + s // 2
    cy = ey + s // 2

    # --- closed / minimal shapes ---
    if style == "tiny":
        px(img, cx, cy, BLACK)
        return

    if style == "sleepy":
        # heavy flat lid (2px tall bar) — clearly a closed eye, not a tiny dot
        for i in range(s):
            px(img, ex + i, cy, BLACK)
            if s >= 4:
                px(img, ex + i, cy - 1, BLACK)
        return

    if style == "happy":
        # upward crescent ^  (center higher than ends)
        for i in range(s):
            if i == 0 or i == s - 1:
                dy = 1
            elif i == 1 or i == s - 2:
                dy = 0
            else:
                dy = -1
            px(img, ex + i, cy + dy, BLACK)
        return

    if style == "wink":
        if single:
            # profile single-eye wink: ">" chevron (NOT flat sleepy, NOT happy arc)
            #   #
            #    #
            #   #
            mid = s // 2
            for i in range(s):
                ox = abs(i - mid)
                px(img, ex + min(ox, s - 1), ey + i, BLACK)
            return
        if left:
            # closed with DOWNWARD bump (distinct from happy-up and sleepy-flat)
            for i in range(s):
                dy = 0 if (i == 0 or i == s - 1) else 1
                px(img, ex + i, cy + dy, BLACK)
            return
        # right eye stays open → draw as normal
        style = "normal"

    if style == "hearts":
        _draw_heart(img, ex, ey, s)
        return

    # --- open white+pupil family: force shape/size differences ---
    if style == "angry":
        # squint oval + thick inward brow (shape, not just 1px brow)
        ellipse_fill(img, ex, ey + 1, ex + s, ey + s - 1, WHITE)
        circ(img, cx, cy + 1, max(1, s // 3), BLACK)
        # heavy angled brow covering top of sclera
        for i in range(s + 1):
            if left:
                by = ey + (i * 2) // max(1, s)  # \ sloping down toward center
            else:
                by = ey + ((s - i) * 2) // max(1, s)  # / sloping
            px(img, ex + i, by, OUTLINE)
            if by + 1 <= ey + s:
                px(img, ex + i, by + 1, OUTLINE)
        return

    if style == "surprised":
        # HUGE round sclera + tiny centered pupil, NO glint
        ellipse_fill(img, ex - 1, ey - 1, ex + s + 1, ey + s + 1, WHITE)
        px(img, cx, cy, BLACK)
        if s >= 6:
            px(img, cx + 1, cy, BLACK)
            px(img, cx, cy + 1, BLACK)
        return

    if style == "sparkly":
        # medium open eye + external star sparkles (not just a glint pixel)
        ellipse_fill(img, ex, ey, ex + s, ey + s, WHITE)
        circ(img, cx, cy, max(1, s // 3), BLACK)
        px(img, ex + 1, ey + 1, WHITE)
        _sparkle_at(img, ex - 1, ey - 1)
        _sparkle_at(img, ex + s + 1, ey + s // 3)
        return

    if style == "excited":
        # diamond / wide-awake: large filled pupils + raised brow ticks
        ellipse_fill(img, ex, ey, ex + s, ey + s, WHITE)
        # pupil nearly fills eye (clearly bigger than normal)
        pr = max(2, s // 2)
        circ(img, cx, cy, pr, BLACK)
        px(img, ex + 1, ey + 1, WHITE)
        # raised brow ticks above
        px(img, ex + 1, ey - 1, BLACK)
        px(img, ex + s - 2, ey - 1, BLACK)
        if s >= 6:
            px(img, ex, ey - 2, BLACK)
            px(img, ex + s - 1, ey - 2, BLACK)
        return

    # normal — medium sclera, medium pupil, single corner glint
    ellipse_fill(img, ex, ey, ex + s, ey + s, WHITE)
    circ(img, cx, cy, max(1, s // 3), BLACK)
    px(img, ex + 1, ey + 1, WHITE)


def _robot_eye(img, ex, ey, style, left=True):
    """LED / visor eye language for BOLT — each variant a different glyph."""
    led = (80, 220, 255, 255)
    led_dim = (40, 120, 160, 255)
    led_hi = (180, 240, 255, 255)
    red = (255, 80, 90, 255)

    if style == "tiny":
        # single LED pixel
        px(img, ex + 2, ey + 2, led)
        return

    if style == "sleepy":
        # flat dim double-dash (heavy lid)
        for i in range(5):
            px(img, ex + i, ey + 1, led_dim)
            px(img, ex + i, ey + 2, led_dim)
        return

    if style == "happy":
        # upward caret / arc
        for i in range(5):
            dy = 0 if i in (1, 2, 3) else 1
            px(img, ex + i, ey + 1 + dy, led)
        return

    if style == "wink":
        if left:
            # closed dash
            for i in range(5):
                px(img, ex + i, ey + 2, led_dim)
            return
        # right: filled square (open)
        rect(img, ex + 1, ey + 1, 3, 3, led)
        return

    if style == "angry":
        # red X glyph (shape change, not just recolor of normal)
        for i in range(5):
            px(img, ex + i, ey + i, red)
            px(img, ex + i, ey + 4 - i, red)
        return

    if style == "surprised":
        # large hollow square ring
        for i in range(5):
            px(img, ex + i, ey, led)
            px(img, ex + i, ey + 4, led)
            px(img, ex, ey + i, led)
            px(img, ex + 4, ey + i, led)
        return

    if style == "sparkly":
        # plus / star LED
        for i in range(5):
            px(img, ex + 2, ey + i, led)
            px(img, ex + i, ey + 2, led)
        px(img, ex + 2, ey + 2, WHITE)
        px(img, ex, ey, led_hi)
        px(img, ex + 4, ey + 4, led_hi)
        return

    if style == "hearts":
        # red LED heart
        px(img, ex + 1, ey, red); px(img, ex + 3, ey, red)
        rect(img, ex, ey + 1, 5, 2, red)
        px(img, ex + 1, ey + 3, red); px(img, ex + 2, ey + 4, red); px(img, ex + 3, ey + 3, red)
        return

    if style == "excited":
        # tall vertical bars (energy)
        rect(img, ex + 1, ey, 1, 5, led)
        rect(img, ex + 3, ey, 1, 5, led)
        px(img, ex + 1, ey, WHITE)
        px(img, ex + 3, ey, WHITE)
        return

    # normal — solid 2×2 cyan squares (classic LED dots)
    rect(img, ex + 1, ey + 1, 3, 3, led)
    px(img, ex + 2, ey + 2, WHITE)

# ===================== MOUTHS =====================
def draw_mouth(pet_id: str, variant: str, box: dict) -> Image.Image:
    img = blank64()
    x, y, w, h = box["x"], box["y"], box["w"], box["h"]
    cx = x + w // 2
    if pet_id == "P10":
        return draw_beak(variant, box)
    if pet_id == "P12":
        return draw_robot_mouth(variant, box)
    if pet_id in ("P02", "P07"):
        return draw_snout_mouth(variant, box)
    if pet_id == "P08":
        # wide frog mouth — each variant a distinct aperture/shape
        # smile/frown visuals swapped so labels match Travis (upturned = smile)
        mid = y + max(1, h // 2 - 1)
        if variant == "smile":
            # upturned: corners HIGH (was previously drawn under frown)
            for i in range(w):
                px(img, x + i, mid - (1 if abs(i - w // 2) > w // 3 else 0), BLACK)
        elif variant == "open_smile":
            rect(img, x + 2, mid - 1, w - 4, min(3, h), (40, 20, 30, 255))
            for i in range(w):
                px(img, x + i, mid - 1, BLACK)
                px(img, x + i, mid + min(2, h - 1), BLACK)
        elif variant == "laugh":
            rect(img, x + 2, mid - 1, w - 4, min(3, h), (40, 20, 30, 255))
            for i in range(w):
                px(img, x + i, mid - 1, BLACK)
            # wide tongue so ≠ open_smile rails-only
            rect(img, cx - 4, mid + 1, 8, 2, (255, 100, 120, 255))
            rect(img, cx - 2, mid + 3, 4, 1, (255, 100, 120, 255))
        elif variant == "funny":
            # zig-zag grin
            for i in range(w):
                px(img, x + i, mid + (1 if (i // 2) % 2 else 0), BLACK)
            px(img, cx, mid + 2, (255, 100, 140, 255))
        elif variant == "tongue":
            for i in range(w):
                px(img, x + i, mid, BLACK)
            rect(img, cx - 1, mid + 1, 3, min(3, h - 1), (255, 100, 140, 255))
        elif variant == "frown":
            # downturned: corners LOW (was previously drawn under smile)
            for i in range(w):
                px(img, x + i, mid + (1 if abs(i - w // 2) > w // 3 else 0), BLACK)
        elif variant == "sad":
            # CLOSED deep frown (≠ open aperture). Deeper than frown: lower center,
            # wider arc, longer end ticks. No dark fill, no tear.
            for i in range(w):
                dist = abs(i - w // 2)
                if dist <= w // 6:
                    dy = 1          # center sits lower than frown's flat mid
                elif dist <= w // 3:
                    dy = 2
                else:
                    dy = 3          # outer corners drop further
                px(img, x + i, mid + dy, BLACK)
            # long hanging end ticks (frown has none)
            px(img, x, mid + 4, BLACK)
            px(img, x, mid + 5, BLACK)
            px(img, x + 1, mid + 4, BLACK)
            px(img, x + w - 1, mid + 4, BLACK)
            px(img, x + w - 1, mid + 5, BLACK)
            px(img, x + w - 2, mid + 4, BLACK)
        elif variant == "tiny":
            px(img, cx, mid, BLACK); px(img, cx + 1, mid, BLACK)
        elif variant == "surprised":
            ellipse_fill(img, cx - 3, y, cx + 3, y + h - 1, BLACK)
        elif variant == "angry":
            for i in range(w):
                px(img, x + i, mid, BLACK)
            px(img, cx - 4, mid - 1, BLACK); px(img, cx + 4, mid - 1, BLACK)
            px(img, cx - 3, mid - 1, BLACK); px(img, cx + 3, mid - 1, BLACK)
        else:
            for i in range(w):
                px(img, x + i, mid, BLACK)
        return img
    # default front-facing mouths — each shape distinct at a glance
    if variant == "smile":
        # U smile: corners UP (smaller y), center DOWN
        for i in range(-w // 2 + 1, w // 2):
            px(img, cx + i, y + 2, BLACK)
        px(img, cx - w // 2 + 1, y + 1, BLACK)
        px(img, cx + w // 2 - 1, y + 1, BLACK)
        if w >= 6:
            px(img, cx - w // 2 + 2, y + 1, BLACK)
            px(img, cx + w // 2 - 2, y + 1, BLACK)
    elif variant == "open_smile":
        ellipse_fill(img, x, y, x + w - 1, y + h - 1, BLACK)
        rect(img, x + 1, y + 1, w - 2, 1, WHITE)
    elif variant == "frown":
        # inverted U: corners DOWN, center UP (subtle vs sad)
        for i in range(-w // 2 + 1, w // 2):
            px(img, cx + i, y + 1, BLACK)
        px(img, cx - w // 2 + 1, y + 2, BLACK)
        px(img, cx + w // 2 - 1, y + 2, BLACK)
    elif variant == "tiny":
        px(img, cx, y + 1, BLACK)
    elif variant == "surprised":
        ellipse_fill(img, cx - 2, y, cx + 2, y + h - 1, BLACK)
    elif variant == "tongue":
        for i in range(-w // 2 + 1, w // 2):
            px(img, cx + i, y + 1, BLACK)
        rect(img, cx - 1, y + 2, 3, 3, (255, 100, 140, 255))
    elif variant == "angry":
        for i in range(-w // 2 + 1, w // 2):
            px(img, cx + i, y + 1, BLACK)
        px(img, cx - 2, y, BLACK); px(img, cx + 2, y, BLACK)
        px(img, cx - 3, y, BLACK); px(img, cx + 3, y, BLACK)
    elif variant == "laugh":
        ellipse_fill(img, x, y, x + w - 1, y + h - 1, BLACK)
        rect(img, cx - 2, y + 2, 4, 2, (255, 100, 120, 255))
    elif variant == "sad":
        # deeper: flat wide bar + long hanging end ticks (≠ frown short corners)
        for i in range(-w // 2, w // 2 + 1):
            px(img, cx + i, y + 1, BLACK)
        px(img, cx - w // 2, y + 2, BLACK)
        px(img, cx - w // 2, y + 3, BLACK)
        px(img, cx + w // 2, y + 2, BLACK)
        px(img, cx + w // 2, y + 3, BLACK)
    elif variant == "funny":
        # asymmetric grin (not a plain open oval like open_smile/laugh)
        for i in range(-w // 2 + 1, w // 2):
            px(img, cx + i, y + 1 + (1 if i % 2 == 0 else 0), BLACK)
        rect(img, cx, y + 2, 3, 2, (255, 100, 140, 255))
    else:
        px(img, cx, y + 1, BLACK)
    return img


def draw_snout_mouth(variant: str, box: dict) -> Image.Image:
    """Side/snout mouths for ¾ pets (SNAG, DRAKELET) — stay on snout, no chin hang."""
    img = blank64()
    x, y, w, h = box["x"], box["y"], box["w"], box["h"]
    mid = y + max(1, h // 2 - 1)
    # horizontal snout line pointing left — each variant distinct
    if variant == "smile":
        # tip curves UP (happy snout)
        for i in range(w - 1):
            px(img, x + i, mid + (0 if i < w // 3 else 1), BLACK)
        px(img, x, mid - 1, BLACK)
    elif variant == "open_smile":
        rect(img, x + 1, mid - 1, w - 2, min(3, h), (40, 20, 30, 255))
        for i in range(w - 1):
            px(img, x + i, mid - 1, BLACK)
            px(img, x + i, mid + min(2, h - 1), BLACK)
    elif variant == "laugh":
        rect(img, x + 1, mid - 1, w - 2, min(3, h), (40, 20, 30, 255))
        for i in range(w - 1):
            px(img, x + i, mid - 1, BLACK)
            px(img, x + i, mid + min(2, h - 1), BLACK)
        # large tongue blob so laugh ≠ open_smile at a glance
        rect(img, x + 1, mid, max(4, w // 2), 2, (255, 100, 120, 255))
        px(img, x + 2, mid + 2, (255, 100, 120, 255))
    elif variant == "funny":
        # zig-zag snout grin (≠ open_smile rectangle)
        for i in range(w - 1):
            px(img, x + i, mid + (1 if i % 2 else 0), BLACK)
        px(img, x + 2, mid + 2, (255, 100, 140, 255))
    elif variant == "frown":
        # tip downturn only (short)
        for i in range(w - 1):
            px(img, x + i, mid - (1 if i < w // 3 else 0), BLACK)
        px(img, x, mid + 1, BLACK)
    elif variant == "sad":
        # whole line droops + double tear tick at tip (deeper than frown)
        for i in range(w - 1):
            px(img, x + i, mid + (1 if i > w // 3 else 0), BLACK)
        px(img, x, mid + 2, BLACK)
        px(img, x, mid + 3, BLACK)
        px(img, x + 1, mid + 2, BLACK)
    elif variant == "tiny":
        px(img, x + w // 2, mid, BLACK)
    elif variant == "surprised":
        ellipse_fill(img, x + 2, y, x + 6, y + h - 1, BLACK)
    elif variant == "tongue":
        for i in range(w - 1):
            px(img, x + i, mid, BLACK)
        rect(img, x + 1, mid + 1, 3, 2, (255, 100, 140, 255))
    elif variant == "angry":
        for i in range(w - 1):
            px(img, x + i, mid, BLACK)
        px(img, x + 1, mid - 1, BLACK); px(img, x + w - 3, mid - 1, BLACK)
        px(img, x + 2, mid - 1, BLACK)
    else:
        for i in range(w - 1):
            px(img, x + i, mid, BLACK)
    return img


def draw_robot_mouth(variant: str, box: dict) -> Image.Image:
    """Speaker-grill / LED mouth variants for BOLT — each glyph distinct at a glance.

    Dark grill backing is painted under every variant so cyan LED shapes punch through
    the faceplate highlight (bodies locked; cannot darken the plate itself).
    """
    img = blank64()
    x, y, w, h = box["x"], box["y"], box["w"], box["h"]
    cx = x + w // 2
    grill = (28, 30, 38, 255)
    led = (80, 220, 255, 255)
    pink = (255, 100, 140, 255)
    red = (255, 80, 90, 255)
    yellow = (255, 220, 60, 255)
    # full plate backing so glyphs never blend into faceplate cyan
    rect(img, x, y, w, h, grill)

    if variant in ("smile", "happy"):
        # bold 3-row U grin — corners HIGH, deep bottom
        px(img, x + 1, y, led); px(img, x + 2, y, led)
        px(img, x + w - 3, y, led); px(img, x + w - 2, y, led)
        px(img, x + 3, y + 1, led); px(img, x + w - 4, y + 1, led)
        for i in range(4, w - 4):
            px(img, x + i, y + 2, led)
    elif variant == "frown":
        # two SEPARATED cyan dots + downturn ticks
        px(img, x + 1, y + 1, led); px(img, x + 2, y + 1, led)
        px(img, x + w - 3, y + 1, led); px(img, x + w - 2, y + 1, led)
        px(img, x + 1, y + 2, led)
        px(img, x + w - 2, y + 2, led)
    elif variant == "sad":
        # longer flat dash with CENTER GAP + end downturns
        for i in range(0, w // 2 - 1):
            px(img, x + i, y + 1, led)
        for i in range(w // 2 + 2, w):
            px(img, x + i, y + 1, led)
        px(img, x, y + 2, led)
        px(img, x + w - 1, y + 2, led)
    elif variant == "open_smile":
        # toothy grill: vertical cyan tooth columns + rails on dark
        for i in range(0, w):
            px(img, x + i, y, led)
            px(img, x + i, y + h - 1, led)
        for i in range(1, w - 1, 3):
            for yy in range(y + 1, y + h - 1):
                px(img, x + i, yy, led)
    elif variant == "laugh":
        # was tongue glyph: dashed cyan line + pink under (labels swapped)
        for i in range(0, w, 2):
            px(img, x + i, y + 1, led)
        px(img, cx, y + 2, pink)
        px(img, cx + 1, y + 2, pink)
    elif variant == "tiny":
        # single LED pixel centered on dark plate
        px(img, cx, y + h // 2, led)
    elif variant == "surprised":
        # hollow cyan square O on dark
        for i in range(-2, 3):
            px(img, cx + i, y, led)
            px(img, cx + i, y + min(3, h - 1), led)
        px(img, cx - 2, y + 1, led); px(img, cx - 2, y + 2, led)
        px(img, cx + 2, y + 1, led); px(img, cx + 2, y + 2, led)
    elif variant == "tongue":
        # was laugh glyph: wide open + pink tongue fill (labels swapped)
        for i in range(0, w):
            px(img, x + i, y, led)
            px(img, x + i, y + h - 1, led)
        rect(img, cx - 2, y + 1, 4, max(2, h - 1), pink)
    elif variant == "angry":
        # flat red bar with tooth notches (no cyan)
        for i in range(w):
            px(img, x + i, y + 1, red)
        for i in range(1, w - 1, 3):
            px(img, x + i, y, red)
            px(img, x + i, y + 2, grill)
    elif variant == "funny":
        # jagged/electric cyan grin + yellow spark
        for i in range(w):
            py = y + (0 if (i % 4) < 2 else 1)
            px(img, x + i, py, led)
        px(img, cx, y + 2, yellow)
        px(img, cx + 1, y + 1, yellow)
        px(img, cx - 1, y + 2, yellow)
    else:
        for i in range(0, w, 2):
            px(img, x + i, y + 1, led)
    return img

def draw_beak(variant: str, box: dict) -> Image.Image:
    """PIP beak — mouth traits are primarily DIFFERENT COLORS.

    Attach at flat L face (~x=15). Tip points LEFT; base meets head.
    Shape accents kept where helpful; color is the primary gallery signal.
    """
    img = blank64()
    x, y, w, h = box["x"], box["y"], box["w"], box["h"]
    d = ImageDraw.Draw(img)
    base_x = x + w - 1
    tip_x = x
    mid_y = y + h // 2
    pink = (255, 100, 140, 255)

    # (main, shade) — distinct hue per mouth id
    COLORS = {
        "smile":      ((255, 180, 60, 255), (200, 120, 30, 255)),    # classic orange/yellow
        "open_smile": ((255, 230, 70, 255), (220, 170, 40, 255)),    # brighter yellow
        "frown":      ((140, 120, 90, 255), (100, 85, 65, 255)),     # muted gray-brown
        "tiny":       ((255, 240, 200, 255), (220, 200, 160, 255)),  # pale cream
        "surprised":  ((255, 150, 180, 255), (220, 100, 140, 255)),  # pinkish
        "tongue":     ((255, 180, 60, 255), (200, 120, 30, 255)),    # orange + pink tongue
        "angry":      ((180, 30, 40, 255), (120, 20, 30, 255)),      # deep crimson
        "laugh":      ((255, 140, 100, 255), (220, 90, 70, 255)),    # warm coral + tongue
        "sad":        ((120, 140, 160, 255), (80, 100, 120, 255)),   # blue-gray / cool
        "funny":      ((160, 220, 60, 255), (100, 160, 40, 255)),    # lime goofy
    }
    beak, beak_d = COLORS.get(variant, ((255, 180, 60, 255), (200, 120, 30, 255)))

    if variant == "smile":
        # standard closed triangle — classic orange
        d.polygon([(base_x, y + 2), (tip_x, mid_y), (base_x, y + h - 3)], fill=beak)
    elif variant == "open_smile":
        # open gap, brighter yellow, no tongue
        d.polygon([(base_x, y + 1), (tip_x, mid_y - 1), (base_x, mid_y)], fill=beak)
        d.polygon([(base_x, mid_y), (tip_x + 1, mid_y + 1), (base_x, y + h - 2)], fill=beak_d)
    elif variant == "laugh":
        # wider OPEN coral beak (clear gap like open_smile) + small pink tongue.
        # Distinct from open_smile: coral/warm pink vs bright yellow; wider aperture; tongue.
        d.polygon([(base_x, y), (tip_x, mid_y - 2), (base_x, mid_y - 1)], fill=beak)
        d.polygon([(base_x, mid_y + 1), (tip_x, mid_y + 2), (base_x, y + h - 1)], fill=beak_d)
        # dark gap so the open aperture reads (not a solid coral fill)
        d.polygon(
            [(base_x - 1, mid_y - 1), (tip_x + 2, mid_y), (base_x - 1, mid_y + 1)],
            fill=(40, 20, 30, 255),
        )
        # small tongue in the gap (does not seal the tip)
        rect(img, tip_x + 4, mid_y, 4, 1, pink)
        px(img, tip_x + 5, mid_y + 1, pink)
    elif variant == "surprised":
        # pinkish open O-beak
        d.polygon([(base_x, y), (tip_x, mid_y - 2), (base_x, mid_y - 1)], fill=beak)
        d.polygon([(base_x, mid_y + 1), (tip_x, mid_y + 2), (base_x, y + h - 1)], fill=beak_d)
        ellipse_fill(img, tip_x + 2, mid_y - 1, base_x - 2, mid_y + 1, (40, 20, 30, 255))
    elif variant == "funny":
        # lime lopsided open
        d.polygon([(base_x, y + 2), (tip_x + 3, mid_y - 1), (base_x, mid_y)], fill=beak)
        d.polygon([(base_x, mid_y), (tip_x, mid_y + 1), (base_x, y + h - 2)], fill=beak_d)
        px(img, tip_x, mid_y + 1, pink)
        px(img, tip_x + 1, mid_y + 1, pink)
        px(img, tip_x + 1, mid_y + 2, pink)
    elif variant == "tongue":
        # orange closed + pink tongue accent
        d.polygon([(base_x, y + 1), (tip_x, mid_y), (base_x, y + h - 2)], fill=beak)
        rect(img, tip_x, mid_y, 3, 3, pink)
    elif variant == "frown":
        # muted gray-brown, tip angled DOWN
        d.polygon([(base_x, y + 1), (tip_x, mid_y + 2), (base_x, y + h - 2)], fill=beak)
        px(img, tip_x + 1, mid_y + 3, beak_d)
    elif variant == "sad":
        # cool blue-gray, longer droopy tip
        d.polygon([(base_x, y + 2), (tip_x - 1, mid_y + 1), (base_x, y + h - 2)], fill=beak)
        px(img, tip_x, mid_y + 2, beak_d)
        px(img, tip_x, mid_y + 3, beak_d)
    elif variant == "angry":
        # deep crimson short sharp wedge + notch
        d.polygon([(base_x, y + 3), (tip_x + 2, mid_y), (base_x, y + h - 3)], fill=beak)
        px(img, tip_x + 3, mid_y - 1, beak_d)
        px(img, tip_x + 4, mid_y - 1, beak_d)
    elif variant == "tiny":
        # pale cream stub
        d.polygon([(base_x, mid_y - 2), (x + w // 2, mid_y), (base_x, mid_y + 2)], fill=beak)
    else:
        d.polygon([(base_x, y + 2), (tip_x, mid_y), (base_x, y + h - 3)], fill=beak)
        for i in range(tip_x + 2, base_x):
            px(img, i, mid_y, beak_d)
    return outline_pixels(img, OUTLINE)

# ===================== ACCESSORIES =====================
ACC_COLORS = {
    "hat": (60, 80, 160, 255),
    "crown": (255, 200, 60, 255),
    "bow": (255, 100, 160, 255),
    "bandana": (220, 60, 60, 255),
    "headphones": (40, 40, 50, 255),
    "glasses": (30, 30, 40, 255),
    "flower": (255, 120, 180, 255),
    "bowtie": (200, 40, 60, 255),
    "party_hat": (120, 80, 220, 255),
}

# Per-pet overrides for accessories that should NOT sit on the crown box
# (bandana/neck, bowtie/chest, headphones wrap, flower side-bloom). Glasses always use eye_box.
ACC_SEAT = {
    # pid: {kind: (x,y,w,h)} — local draw rect; omit = use accessory_64
    "P01": {  # PUDD blob
        "bandana": (18, 32, 28, 12),
        "bowtie": (24, 40, 16, 8),
        "headphones": (14, 20, 36, 16),
        "flower": (42, 22, 14, 14),
    },
    "P02": {  # SNAG 3/4 — no headphones
        "bandana": (8, 32, 16, 10),
        "bowtie": (12, 36, 12, 8),
        "flower": (30, 14, 12, 12),
    },
    "P03": {  # MEOWLET
        "bandana": (18, 36, 28, 12),
        "bowtie": (24, 44, 16, 8),
        "headphones": (14, 18, 36, 16),
        "flower": (44, 18, 12, 12),
    },
    "P04": {  # PUPPO
        "bandana": (20, 36, 24, 12),
        "bowtie": (24, 42, 16, 8),
        "headphones": (14, 16, 36, 18),
        "flower": (46, 18, 12, 12),
    },
    "P05": {  # HOPLIT tall ears
        "bandana": (22, 38, 20, 12),
        "bowtie": (24, 46, 16, 8),
        "headphones": (18, 22, 28, 16),
        "flower": (40, 20, 12, 12),
    },
    "P06": {  # ZORP
        "bandana": (18, 42, 28, 12),
        "bowtie": (24, 48, 16, 8),
        "headphones": (14, 12, 36, 16),
        "flower": (44, 16, 12, 12),
    },
    "P07": {  # DRAKELET — accessories limited to glasses (eye_box) + none; no crown seats
    },
    "P08": {  # BLOP
        "bandana": (18, 30, 28, 12),
        "bowtie": (24, 42, 16, 8),
        "headphones": (12, 12, 40, 16),
        "flower": (48, 18, 12, 12),
    },
    "P09": {  # BRUMBLE
        "bandana": (18, 34, 28, 12),
        "bowtie": (24, 44, 16, 8),
        "headphones": (12, 16, 40, 16),
        "flower": (44, 16, 12, 12),
    },
    "P10": {  # PIP bird — no headphones
        "bandana": (16, 28, 20, 12),
        "bowtie": (20, 34, 16, 8),
        "flower": (38, 12, 12, 12),
        "party_hat": (24, 0, 14, 12),
        "hat": (22, 0, 16, 12),
        "crown": (22, 0, 16, 12),
        "bow": (28, 2, 12, 10),
    },
    "P11": {  # GILLI — no headphones
        "bandana": (22, 34, 20, 12),
        "bowtie": (24, 42, 16, 8),
        "flower": (42, 18, 12, 12),
    },
    "P12": {  # BOLT — organic seats unused (robot drawer); kept for completeness
        "bandana": (22, 32, 20, 10),
        "bowtie": (24, 32, 16, 8),
        "flower": (38, 0, 14, 14),
        "bow": (26, 0, 14, 10),
        "party_hat": (26, 0, 14, 12),
    },
}


def _acc_box(pet_id, kind, default_box):
    seat = ACC_SEAT.get(pet_id, {}).get(kind)
    if seat:
        return {"x": seat[0], "y": seat[1], "w": seat[2], "h": seat[3]}
    return default_box


def _draw_flower(img, cx_, cy_, petal, center=(255, 220, 60, 255), center_hi=(255, 245, 140, 255)):
    """Clear petal bloom + yellow center — readable at gallery size.

    Five discrete 3×3 lobes around a tight yellow disc; dark outline for contrast.
    """
    petals = [
        (0, -4),
        (4, -1),
        (3, 3),
        (-3, 3),
        (-4, -1),
    ]
    hi = shade_tuple(petal, 1.2)
    # dark under-outline so pink petals punch on any body color
    for ox, oy in petals:
        for dx in (-2, -1, 0, 1, 2):
            for dy in (-2, -1, 0, 1, 2):
                if abs(dx) <= 1 and abs(dy) <= 1:
                    continue
                if abs(dx) + abs(dy) > 3:
                    continue
                px(img, cx_ + ox + dx, cy_ + oy + dy, OUTLINE)
    for ox, oy in petals:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                px(img, cx_ + ox + dx, cy_ + oy + dy, petal)
        tip_x = cx_ + int(round(ox * 1.5))
        tip_y = cy_ + int(round(oy * 1.5))
        px(img, tip_x, tip_y, hi)
        px(img, cx_ + ox, cy_ + oy, hi)
    # yellow center
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1), (0, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)]:
        px(img, cx_ + dx, cy_ + dy, center if (dx, dy) != (0, 0) else center_hi)
    px(img, cx_, cy_, center_hi)
    # stem
    px(img, cx_, cy_ + 5, (60, 160, 70, 255))
    px(img, cx_, cy_ + 6, (40, 130, 55, 255))



def _draw_bowtie(img, x, y, w, h, c):
    """Classic two-triangle wings + center knot on chest/neck."""
    d = ImageDraw.Draw(img)
    seat = y + h - 1
    mid_x = x + w // 2
    mid_y = y + h // 2
    # LEFT wing: wide triangle pointing LEFT (base at knot, tip at left)
    d.polygon([
        (x, mid_y),                 # tip
        (mid_x - 2, y),             # top of base
        (mid_x - 2, seat),          # bottom of base
    ], fill=c)
    # RIGHT wing: mirror
    d.polygon([
        (x + w - 1, mid_y),
        (mid_x + 2, y),
        (mid_x + 2, seat),
    ], fill=c)
    # dark crease down each wing so triangles read
    shade_c = shade_tuple(c, 0.7)
    for xx in range(x + 1, mid_x - 2):
        t = (xx - x) / max(1, mid_x - 2 - x)
        half = max(1, int((1 - t) * (h // 2 - 1)))
        px(img, xx, mid_y, shade_c)
    for xx in range(mid_x + 3, x + w - 1):
        px(img, xx, mid_y, shade_c)
    # CENTER KNOT — clearly darker block with highlight (not a diamond blob)
    knot = shade_tuple(c, 0.45)
    rect(img, mid_x - 2, mid_y - 3, 5, 6, knot)
    rect(img, mid_x - 1, mid_y - 2, 3, 4, shade_tuple(c, 0.65))
    px(img, mid_x, mid_y - 1, shade_tuple(c, 1.25))
    px(img, mid_x, mid_y, c)


def _draw_bandana(img, x, y, w, h, c):
    """Clear triangle/kerchief at neck with visible knot + hanging point."""
    d = ImageDraw.Draw(img)
    seat = y + h - 1
    # soft outline underlayer for contrast on dark/red bodies
    outline = OUTLINE
    d.polygon([(x + 1, y + 3), (x + w - 2, y + 3), (x + w // 2, seat + 1)], fill=outline)
    # neck wrap bar
    rect(img, x, y + 1, w, 3, c)
    rect(img, x + 1, y, w - 2, 1, shade_tuple(c, 1.15))
    # hanging triangle point (kerchief)
    d.polygon([(x + 2, y + 3), (x + w - 3, y + 3), (x + w // 2, seat)], fill=c)
    # cream fold highlight down the point so it reads as fabric
    hi = (255, 220, 200, 255)
    for yy in range(y + 4, seat - 1):
        px(img, x + w // 2, yy, hi if (yy - y) % 2 == 0 else shade_tuple(c, 1.1))
    # knot at wrap center (two little tails) — cream tips for readability
    knot = shade_tuple(c, 0.55)
    rect(img, x + w // 2 - 2, y, 5, 4, knot)
    px(img, x + w // 2, y + 1, hi)
    px(img, x + w // 2 - 3, y + 3, c)
    px(img, x + w // 2 + 3, y + 3, c)
    px(img, x + w // 2 - 4, y + 4, hi)
    px(img, x + w // 2 + 4, y + 4, hi)


def _draw_headphones(img, x, y, w, h, c):
    """Two ear cups + headband that wraps the head (not floating dots)."""
    cup = (55, 55, 65, 255)
    pad = (90, 90, 105, 255)
    # thick headband across top
    for i in range(w):
        px(img, x + i, y + 1, c)
        px(img, x + i, y + 2, c)
    # slight arc dip at ends
    px(img, x, y + 3, c)
    px(img, x + 1, y + 3, c)
    px(img, x + w - 1, y + 3, c)
    px(img, x + w - 2, y + 3, c)
    # left ear cup
    ellipse_fill(img, x - 1, y + 3, x + 6, y + h - 1, cup)
    rect(img, x, y + 4, 5, max(4, h - 6), c)
    ellipse_fill(img, x + 1, y + 6, x + 5, y + h - 2, pad)
    # right ear cup
    ellipse_fill(img, x + w - 7, y + 3, x + w, y + h - 1, cup)
    rect(img, x + w - 5, y + 4, 5, max(4, h - 6), c)
    ellipse_fill(img, x + w - 6, y + 6, x + w - 2, y + h - 2, pad)


def draw_accessory(pet_id: str, kind: str, box: dict, eye_box: dict) -> Image.Image:
    """Draw accessory seated for THIS pet. Hats seat with brim at bottom of box.
    Do not call with kind == "none" — callers write a transparent blank instead.
    """
    if kind == "none":
        raise ValueError("draw_accessory must not be called with kind='none'")
    if pet_id == "P12":
        return draw_robot_accessory(kind, box, eye_box)
    img = blank64()
    box = _acc_box(pet_id, kind, box)
    x, y, w, h = box["x"], box["y"], box["w"], box["h"]
    c = ACC_COLORS.get(kind, (200, 100, 200, 255))
    d = ImageDraw.Draw(img)
    seat = y + h - 1  # bottom of box = contact with head/body

    if kind == "glasses":
        # always on THAT pet's eyes
        ex, ey, ew, eh = eye_box["x"], eye_box["y"], eye_box["w"], eye_box["h"]
        if pet_id in ("P02", "P07", "P10"):
            d.rectangle([ex - 1, ey - 1, ex + max(5, ew - 1), ey + eh], outline=c, width=1)
        elif pet_id == "P08":
            # goggles over both eye bumps
            d.rectangle([17, 15, 27, 24], outline=c, width=1)
            d.rectangle([37, 15, 47, 24], outline=c, width=1)
            px(img, 32, 19, c)
        else:
            mid = ex + ew // 2
            d.rectangle([ex, ey, mid - 2, ey + eh - 1], outline=c, width=1)
            d.rectangle([mid + 1, ey, ex + ew - 1, ey + eh - 1], outline=c, width=1)
            px(img, mid, ey + eh // 2, c)
        return img

    if kind == "hat":
        # brim sits on seat; crown rises above
        brim_y = seat - 2
        crown_h = max(3, h - 4)
        rect(img, x + 2, brim_y - crown_h, w - 4, crown_h, shade_tuple(c, 1.1))
        ellipse_fill(img, x, brim_y - 2, x + w - 1, brim_y + 2, c)
        rect(img, x + 1, brim_y, w - 2, 2, c)
    elif kind == "crown":
        d.polygon([
            (x, seat), (x, seat - h // 2), (x + w // 4, seat - 2),
            (x + w // 2, y), (x + 3 * w // 4, seat - 2),
            (x + w - 1, seat - h // 2), (x + w - 1, seat),
        ], fill=c)
        px(img, x + w // 2, y, (255, 80, 120, 255))
    elif kind == "bow":
        cy = y + h // 2
        ellipse_fill(img, x, cy - h // 3, x + w // 2 - 1, cy + h // 3, c)
        ellipse_fill(img, x + w // 2, cy - h // 3, x + w - 1, cy + h // 3, c)
        rect(img, x + w // 2 - 2, cy - 2, 4, 4, shade_tuple(c, 0.7))
    elif kind == "bandana":
        _draw_bandana(img, x, y, w, h, c)
    elif kind == "headphones":
        _draw_headphones(img, x, y, w, h, c)
    elif kind == "flower":
        _draw_flower(img, x + w // 2, y + h // 2 - 1, c)
    elif kind == "bowtie":
        _draw_bowtie(img, x, y, w, h, c)
    elif kind == "party_hat":
        d.polygon([(x + w // 2, y), (x, seat), (x + w - 1, seat)], fill=c)
        px(img, x + w // 2, y, (255, 255, 100, 255))
        for i in range(3):
            px(img, x + 2 + i * 2, seat - 1, (255, 255, 255, 255))
    return img


def draw_robot_accessory(kind: str, box: dict, eye_box: dict) -> Image.Image:
    """Robot toppers for BOLT — glyphs OK but must still read as the named items."""
    img = blank64()
    d = ImageDraw.Draw(img)
    # Antenna tip ~ (32, 3); head crown ~ y=10; neck ~ y=33
    ax, ay = 32, 3

    if kind == "hat":  # hard-hat on head crown, clearing antenna hole
        c = (255, 200, 60, 255)
        rect(img, 18, 8, 28, 4, c)
        ellipse_fill(img, 16, 6, 47, 12, c)
        rect(img, 20, 4, 24, 5, shade_tuple(c, 1.1))
        # leave antenna slot
        for yy in range(4, 12):
            for xx in range(30, 35):
                if img.getpixel((xx, yy))[3] > 0 and 5 <= yy <= 10:
                    if xx in (31, 32, 33) and yy >= 5:
                        img.putpixel((xx, yy), (0, 0, 0, 0))
    elif kind == "crown":  # circuit spikes on head
        c = (80, 220, 255, 255)
        for hx in (18, 30, 42):
            rect(img, hx, 4 if hx == 30 else 6, 3, 7, c)
        rect(img, 16, 10, 32, 3, (60, 80, 100, 255))
    elif kind == "bow":  # ribbon bow on antenna tip (reads as bow, metal-ish)
        c = (255, 100, 160, 255)
        # two loops
        ellipse_fill(img, ax - 8, ay - 2, ax - 1, ay + 4, c)
        ellipse_fill(img, ax + 1, ay - 2, ax + 8, ay + 4, c)
        rect(img, ax - 2, ay, 5, 3, shade_tuple(c, 0.6))
        px(img, ax, ay + 1, (255, 200, 220, 255))
    elif kind == "bandana":  # kerchief at neck joint (robot-red, still a bandana)
        c = (220, 60, 60, 255)
        _draw_bandana(img, 22, 32, 20, 10, c)
    elif kind == "headphones":  # sensor cups on head sides
        c = (40, 40, 50, 255)
        _draw_headphones(img, 14, 12, 36, 16, c)
        # cyan accent band so it stays robotic
        for i in range(16, 48):
            px(img, i, 13, (80, 220, 255, 255))
    elif kind == "glasses":  # visor goggles over eye LEDs
        ex, ey, ew, eh = eye_box["x"], eye_box["y"], eye_box["w"], eye_box["h"]
        c = (80, 220, 255, 255)
        d.rectangle([ex, ey, ex + ew - 1, ey + eh - 1], outline=c, width=1)
        px(img, ex + ew // 2, ey + eh // 2, c)
    elif kind == "flower":  # LED flower on antenna tip — clear petals + lit center
        petal = (255, 120, 180, 255)
        _draw_flower(img, ax, ay + 2, petal, center=(255, 64, 72, 255), center_hi=(255, 180, 160, 255))
    elif kind == "bowtie":  # classic bow tie on neck/chest (steel + red)
        c = (200, 40, 60, 255)
        _draw_bowtie(img, 24, 32, 16, 8, c)
        # tiny bolt highlight on knot
        px(img, 31, 35, (80, 220, 255, 255))
    elif kind == "party_hat":  # cone on antenna tip
        c = (120, 80, 220, 255)
        d.polygon([(ax, 0), (ax - 6, 10), (ax + 6, 10)], fill=c)
        px(img, ax, 0, (255, 64, 72, 255))
        for i in range(4):
            px(img, ax - 4 + i * 2, 9, (255, 255, 255, 255))
        # stripe
        for i in range(-3, 4):
            px(img, ax + i, 5, (255, 200, 60, 255))
    return img

def shade_tuple(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (c[3] if len(c) > 3 else 255,)

# ===================== BUILD PETS =====================
def build_pets(skip_bodies=None):
    """Build pet layers. skip_bodies: set of pet ids whose body/colors must NOT be rewritten."""
    skip_bodies = set(skip_bodies or [])
    traits = load_json("traits.json")
    anchors = load_json("anchors.json")
    count_body = count_col = count_eye = count_mouth = count_acc = 0
    for pid, meta in traits["pets"].items():
        folder = LAYERS / "pets" / meta["folder"]
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "colors").mkdir(exist_ok=True)
        (folder / "eyes").mkdir(exist_ok=True)
        (folder / "mouths").mkdir(exist_ok=True)
        (folder / "accessories").mkdir(exist_ok=True)
        pa = anchors["pets"][pid]
        if pid not in skip_bodies:
            body_g = BODIES[pid]()
            body_g.save(folder / "body_tintable.png")
            default_hex = meta["colors"][0]["hex"]
            body_default = tint_body(body_g, default_hex)
            if pid == "P12":
                body_default = apply_bolt_led(body_default)
            body_default.save(folder / "body.png")
            count_body += 1
            for col in meta["colors"]:
                tinted = tint_body(body_g, col["hex"])
                if pid == "P12":
                    tinted = apply_bolt_led(tinted)
                tinted.save(folder / "colors" / f"{col['id']}.png")
                count_col += 1
        for ev in meta["eyes"]:
            eid = _opt_id(ev)
            eimg = draw_eyes(pid, eid, pa["eyes_64"])
            eimg.save(folder / "eyes" / f"{eid}.png")
            count_eye += 1
        for mv in meta["mouths"]:
            mid = _opt_id(mv)
            mimg = draw_mouth(pid, mid, pa["mouth_64"])
            mimg.save(folder / "mouths" / f"{mid}.png")
            count_mouth += 1
        for av in meta["accessories"]:
            aid = _opt_id(av)
            if aid == "none":
                # none = no accessory layer: fully transparent 64×64 blank
                aimg = blank64()
            else:
                aimg = draw_accessory(pid, aid, pa["accessory_64"], pa["eyes_64"])
            aimg.save(folder / "accessories" / f"{aid}.png")
            count_acc += 1
    return {"bodies": count_body, "colors": count_col, "eyes": count_eye, "mouths": count_mouth, "accessories": count_acc}


def build_traits_only(lock_bodies=("P04", "P12")):
    """Regenerate eyes/mouths/accessories for all pets; never rewrite locked bodies."""
    return build_pets(skip_bodies=set(lock_bodies) | set(
        # also skip ALL bodies this pass — only trait layers change
        load_json("traits.json")["pets"].keys()
    ))

# ===================== EGGS =====================
def build_eggs():
    """12 pet-linked eggs E01–E12 — one vibe/pattern per pet identity."""
    out = LAYERS / "eggs"
    out.mkdir(parents=True, exist_ok=True)
    # Clear prior egg PNGs so renamed files do not leave orphans.
    for old in out.glob("E*.png"):
        old.unlink()
    # (file, base_rgb, accent_rgb, pattern)
    # patterns: puddle, scales, speckles, paw, hop, alien, dragon, goo, earth, bird, fish, robot
    specs = [
        ("E01_pudd_cream.png",      (255, 236, 200), (210, 170, 120), "puddle"),   # PUDD
        ("E02_snag_green.png",      (120, 190, 110), (60, 120, 70),   "scales"),   # SNAG
        ("E03_meowlet_lavender.png",(220, 200, 245), (150, 110, 190), "speckles"), # MEOWLET
        ("E04_puppo_tan.png",       (232, 190, 140), (170, 120, 80),  "paw"),      # PUPPO
        ("E05_hoplit_mint.png",     (180, 240, 210), (80, 170, 130),  "hop"),      # HOPLIT
        ("E06_zorp_alien.png",      (160, 90, 210),  (60, 210, 190),  "alien"),    # ZORP
        ("E07_drakelet_peach.png",  (255, 170, 120), (220, 90, 50),   "dragon"),   # DRAKELET
        ("E08_blop_magenta.png",    (255, 140, 190), (200, 40, 140),  "goo"),      # BLOP
        ("E09_brumble_earth.png",   (160, 130, 100), (90, 90, 95),    "earth"),    # BRUMBLE
        ("E10_pip_yellow.png",      (255, 230, 90),  (200, 150, 30),  "bird"),     # PIP
        ("E11_gilli_blue.png",      (110, 180, 235), (40, 100, 180),  "fish"),     # GILLI
        ("E12_bolt_robot.png",      (150, 160, 170), (80, 220, 255),  "robot"),    # BOLT
    ]
    rng = random.Random(42)
    for fname, base, spot, pattern in specs:
        img = blank64()
        # oval egg centered
        ellipse_fill(img, 18, 12, 45, 52, (*base, 255))
        ellipse_fill(img, 22, 16, 36, 30, (*shade(base, 1.12), 255))  # highlight
        ellipse_fill(img, 24, 40, 42, 52, (*shade(base, 0.85), 255))
        egg_mask = img.split()[-1].copy()
        if pattern == "puddle":
            # soft irregular puddle spots
            for sx, sy, r in ((24, 24, 3), (36, 30, 2), (28, 40, 3), (38, 42, 2), (32, 22, 1)):
                circ(img, sx, sy, r, (*spot, 200))
        elif pattern == "scales":
            # snakey bands / scale rows
            for y, inset in ((22, 2), (28, 0), (34, 1), (40, 2), (46, 4)):
                rect(img, 20 + inset, y, 24 - 2 * inset, 2, (*spot, 220))
            for sx, sy in ((26, 26), (34, 32), (28, 38), (36, 44)):
                circ(img, sx, sy, 1, (*shade(spot, 1.2), 255))
        elif pattern == "speckles":
            # Fixed inset dots (plus-shaped circ stays on-shell).
            for sx, sy in ((24, 22), (32, 20), (38, 24), (26, 30), (34, 28),
                           (30, 36), (22, 38), (36, 40), (28, 44), (34, 46),
                           (40, 34), (24, 46)):
                circ(img, sx, sy, 1, (*spot, 230))
        elif pattern == "paw":
            # paw-pad style dots (center + 3 toes)
            for cx, cy in ((28, 34), (36, 36)):
                circ(img, cx, cy, 2, (*spot, 230))
                for ox, oy in ((-3, -3), (0, -4), (3, -3)):
                    circ(img, cx + ox, cy + oy, 1, (*spot, 220))
        elif pattern == "hop":
            # mint hop speckles — small arcs of dots
            for i, (sx, sy) in enumerate(((24, 22), (30, 20), (36, 22), (26, 36), (34, 38), (30, 44))):
                circ(img, sx, sy, 1 + (i % 2), (*spot, 220))
        elif pattern == "alien":
            # purple base with teal accent rings / dots
            for y in (26, 36, 46):
                rect(img, 22, y, 20, 2, (*spot, 180))
            for sx, sy in ((26, 30), (36, 32), (30, 42)):
                circ(img, sx, sy, 2, (*spot, 230))
                px(img, sx, sy, (*shade(spot, 1.3), 255))
        elif pattern == "dragon":
            # peach/orange scale diamonds
            for row, y in enumerate((24, 30, 36, 42)):
                xs = range(24 + (row % 2), 42, 4)
                for sx in xs:
                    circ(img, sx, y, 2, (*spot, 200))
                    circ(img, sx, y, 1, (*shade(spot, 1.15), 255))
        elif pattern == "goo":
            # gooey marble blobs
            for sx, sy, r in ((26, 26, 4), (36, 34, 3), (30, 44, 4), (38, 24, 2)):
                circ(img, sx, sy, r, (*spot, 160))
                circ(img, sx - 1, sy - 1, max(1, r - 2), (*shade(spot, 1.2), 200))
        elif pattern == "earth":
            for _ in range(16):
                sx, sy = rng.randint(20, 42), rng.randint(16, 48)
                col = spot if rng.random() < 0.55 else shade(base, 0.65)
                circ(img, sx, sy, rng.randint(1, 2), (*col, 220))
        elif pattern == "bird":
            # yellow bird seed dots
            for sx, sy in ((24, 24), (32, 22), (40, 26), (26, 34), (34, 36),
                           (38, 42), (28, 44), (22, 40), (36, 30)):
                circ(img, sx, sy, 1, (*spot, 255))
        elif pattern == "fish":
            # blue bands + bubble dots
            rect(img, 20, 26, 24, 3, (*spot, 210))
            rect(img, 22, 36, 20, 2, (*spot, 180))
            for sx, sy, r in ((28, 20, 2), (38, 30, 1), (34, 44, 2), (24, 42, 1)):
                circ(img, sx, sy, r, (200, 230, 255, 220))
                px(img, sx - r // 2, sy - r // 2, (255, 255, 255, 200))
        elif pattern == "robot":
            # gray panels + cyan LED accent dots
            rect(img, 24, 24, 16, 2, (*spot, 200))
            rect(img, 22, 34, 20, 2, (*spot, 180))
            for sx, sy in ((26, 28), (32, 28), (38, 28), (26, 40), (32, 40), (38, 40)):
                circ(img, sx, sy, 1, (*spot, 255))
                px(img, sx, sy, (255, 255, 255, 255))
        # Keep spots/patterns inside the egg silhouette (no floating pixels off the shell).
        r, g, b, a = img.split()
        a = ImageChops.multiply(a, egg_mask)
        img = Image.merge("RGBA", (r, g, b, a))
        img = outline_pixels(img, OUTLINE)
        img.save(out / fname)
    return 12

# ===================== SCREEN EFFECTS =====================
FX_MAKERS = {
    "FX01_static": "_fx_static",
    "FX02_scanlines": "_fx_scanlines",
    "FX03_sparkles": "_fx_sparkles",
    "FX04_stars": "_fx_stars",
    "FX05_bubbles": "_fx_bubbles",
    "FX06_lightning": "_fx_lightning",
    "FX07_pixel_rain": "_fx_rain",
    "FX08_glitch": "_fx_glitch",
    "FX09_clouds": "_fx_clouds",
    "FX10_fire": "_fx_fire",
    "FX11_leaves": "_fx_leaves",
    "FX12_digital_grid": "_fx_grid",
}

# id (without FX##_) -> maker name for gallery / compose
FX_ID_TO_MAKER = {
    "static": "_fx_static",
    "scanlines": "_fx_scanlines",
    "sparkles": "_fx_sparkles",
    "stars": "_fx_stars",
    "bubbles": "_fx_bubbles",
    "lightning": "_fx_lightning",
    "pixel_rain": "_fx_rain",
    "glitch": "_fx_glitch",
    "clouds": "_fx_clouds",
    "fire": "_fx_fire",
    "leaves": "_fx_leaves",
    "digital_grid": "_fx_grid",
}

def _fx_maker_fn(name: str):
    return globals()[name]


def make_fx_frame(fx_id: str, frame: int = 0, seed: int = 7) -> Image.Image:
    """Generate one animated frame for an FX id (e.g. 'scanlines', 'FX02_scanlines')."""
    key = fx_id
    if key.startswith("FX") and "_" in key:
        # FX02_scanlines -> scanlines
        key = key.split("_", 1)[1]
    maker_name = FX_ID_TO_MAKER.get(key)
    if maker_name is None:
        raise KeyError(f"unknown fx id: {fx_id}")
    rng = random.Random(seed)
    return _fx_maker_fn(maker_name)(rng, frame=frame)


def build_fx():
    out = LAYERS / "screen_effects"
    out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(7)
    makers = {
        "FX01_static.png": _fx_static,
        "FX02_scanlines.png": _fx_scanlines,
        "FX03_sparkles.png": _fx_sparkles,
        "FX04_stars.png": _fx_stars,
        "FX05_bubbles.png": _fx_bubbles,
        "FX06_lightning.png": _fx_lightning,
        "FX07_pixel_rain.png": _fx_rain,
        "FX08_glitch.png": _fx_glitch,
        "FX09_clouds.png": _fx_clouds,
        "FX10_fire.png": _fx_fire,
        "FX11_leaves.png": _fx_leaves,
        "FX12_digital_grid.png": _fx_grid,
    }
    for fname, fn in makers.items():
        img = fn(rng, frame=0)
        img.save(out / fname)
    return 12

def _fx_static(rng, frame=0):
    # Re-roll noise each frame
    rng = random.Random(rng.randint(0, 10**9) + frame * 7919 + 7)
    img = blank64()
    for y in range(64):
        for x in range(64):
            if rng.random() < 0.08:
                v = rng.randint(80, 200)
                px(img, x, y, (v, v, v, 100))
    return img

def _fx_scanlines(rng, frame=0):
    # Scroll y by 1px per frame (period-2 pattern; +2 would be a no-op)
    img = blank64()
    off = frame % 2
    for y in range(off, 64, 2):
        for x in range(64):
            px(img, x, y, (0, 0, 0, 70))
    return img

def _fx_sparkles(rng, frame=0):
    # Stable positions; twinkle alpha / subset by frame
    base = random.Random(rng.randint(0, 10**9) + 303)
    pts = [(base.randint(2, 61), base.randint(2, 61)) for _ in range(18)]
    img = blank64()
    for i, (x, y) in enumerate(pts):
        # twinkle: phase offset per sparkle
        phase = (frame + i * 3) % 8
        if phase >= 6:
            continue  # off this frame
        a = 220 if phase in (0, 1, 2) else 120
        a2 = max(40, a - 100)
        px(img, x, y, (255, 255, 200, a))
        px(img, x-1, y, (255, 255, 255, a2))
        px(img, x+1, y, (255, 255, 255, a2))
        px(img, x, y-1, (255, 255, 255, a2))
        px(img, x, y+1, (255, 255, 255, a2))
    return img

def _fx_stars(rng, frame=0):
    base = random.Random(rng.randint(0, 10**9) + 404)
    pts = [(base.randint(3, 60), base.randint(3, 60)) for _ in range(12)]
    img = blank64()
    for i, (x, y) in enumerate(pts):
        phase = (frame + i * 2) % 6
        if phase >= 5:
            continue
        a = 230 if phase < 3 else 110
        col = (255, 255, 180, a)
        px(img, x, y, col)
        px(img, x-1, y, col); px(img, x+1, y, col)
        px(img, x, y-1, col); px(img, x, y+1, col)
    return img

def _fx_bubbles(rng, frame=0):
    # Stable bubbles drift upward
    base = random.Random(rng.randint(0, 10**9) + 505)
    bubbles = [(base.randint(4, 58), base.randint(4, 58), base.randint(2, 5)) for _ in range(10)]
    img = blank64()
    d = ImageDraw.Draw(img)
    for i, (x, y0, r) in enumerate(bubbles):
        y = (y0 - frame * 2 - i) % 64
        d.ellipse([x-r, y-r, x+r, y+r], outline=(140, 200, 255, 180))
        px(img, x-r//2, (y-r//2) % 64, (200, 230, 255, 200))
    return img

def _fx_lightning(rng, frame=0):
    # Flicker on/off; new bolt on odd frames
    if frame % 3 == 2:
        return blank64()  # off
    rng = random.Random(rng.randint(0, 10**9) + frame * 1301 + 11)
    img = blank64()
    x, y = 30 + rng.randint(-6, 6), 2
    col = (220, 240, 255, 200)
    for _ in range(8):
        nx = x + rng.randint(-4, 4)
        ny = y + rng.randint(4, 8)
        for t in range(5):
            px(img, x + (nx-x)*t//5, y + (ny-y)*t//5, col)
            px(img, x + (nx-x)*t//5 + 1, y + (ny-y)*t//5, (180, 200, 255, 120))
        x, y = nx, ny
    return img

def _fx_rain(rng, frame=0):
    # Fall downward: stable columns, y scrolls
    base = random.Random(rng.randint(0, 10**9) + 707)
    drops = [(base.randint(0, 63), base.randint(0, 60)) for _ in range(40)]
    img = blank64()
    for x, y0 in drops:
        y = (y0 + frame * 3) % 64
        px(img, x, y, (120, 180, 255, 160))
        px(img, x, (y + 1) % 64, (100, 160, 255, 100))
    return img

def _fx_glitch(rng, frame=0):
    # New bars each frame
    rng = random.Random(rng.randint(0, 10**9) + frame * 1709 + 13)
    img = blank64()
    for _ in range(8):
        y = rng.randint(0, 60)
        h = rng.randint(1, 3)
        x0 = rng.randint(0, 40)
        col = [(255,0,80,100), (0,255,200,100), (80,80,255,100)][rng.randint(0,2)]
        rect(img, x0, y, rng.randint(8, 24), h, col)
    return img

def _fx_clouds(rng, frame=0):
    # Drift sideways
    base = random.Random(rng.randint(0, 10**9) + 909)
    clouds = [(base.randint(4, 50), base.randint(4, 40)) for _ in range(5)]
    img = blank64()
    for i, (x0, y) in enumerate(clouds):
        x = (x0 + frame * 2 + i) % 64
        circ(img, x, y, 5, (220, 230, 240, 100))
        circ(img, (x+4) % 64, y+1, 4, (220, 230, 240, 90))
        circ(img, (x-3) % 64, y+2, 3, (220, 230, 240, 80))
    return img

def _fx_fire(rng, frame=0):
    # Flicker heights each frame
    rng = random.Random(rng.randint(0, 10**9) + frame * 1901 + 17)
    img = blank64()
    for x in range(64):
        h = rng.randint(8, 22)
        for i in range(h):
            yy = 63 - i
            t = i / h
            if t < 0.3:
                col = (255, 240, 100, 140)
            elif t < 0.6:
                col = (255, 140, 40, 130)
            else:
                col = (220, 40, 20, 100)
            if abs(x - 32) < 20 + rng.randint(0, 5):
                px(img, x, yy, col)
    return img

def _fx_leaves(rng, frame=0):
    # Drift down-diagonal
    base = random.Random(rng.randint(0, 10**9) + 1111)
    leaves = []
    for _ in range(14):
        leaves.append((base.randint(2, 60), base.randint(2, 60), base.random() < 0.5))
    img = blank64()
    for i, (x0, y0, green) in enumerate(leaves):
        x = (x0 + frame) % 64
        y = (y0 + frame * 2) % 64
        col = (80, 180, 80, 180) if green else (180, 200, 60, 160)
        px(img, x, y, col); px(img, (x+1)%64, y, col); px(img, x, (y+1)%64, col)
    return img

def _fx_grid(rng, frame=0):
    # Subtle pulse / scan: alpha pulses; optional scan row highlight
    pulse = 40 + int(30 * (0.5 + 0.5 * math.sin(frame * 0.7)))
    img = blank64()
    scan = (frame * 4) % 64
    for i in range(0, 64, 8):
        for j in range(64):
            a = pulse + (25 if abs(j - scan) < 2 else 0)
            a = min(120, a)
            px(img, i, j, (80, 255, 160, a))
            px(img, j, i, (80, 255, 160, a))
    return img

# ===================== ANIMATIONS =====================
def build_egg_rock():
    out = ANIM / "egg_rock"
    out.mkdir(parents=True, exist_ok=True)
    base = Image.open(LAYERS / "eggs" / "E03_meowlet_lavender.png")
    frames = []
    # tilts L/C/R a few pixels — 8 frames ~1.2s
    offsets = [0, -2, -3, -1, 0, 2, 3, 1]
    for i, ox in enumerate(offsets):
        fr = blank64()
        fr.paste(base, (ox, 0), base)
        fr.save(out / f"frame_{i:02d}.png")
        frames.append(fr)
    # egg-only gif
    frames[0].save(
        out / "loop.gif",
        save_all=True, append_images=frames[1:],
        duration=150, loop=0, disposal=2
    )
    return 8

def build_hatch():
    """Legacy disk export of hatch beats (historically baked from E01).

    Compose no longer depends on these for the egg body — compose.build_hatch_frame()
    builds the same timeline at runtime from any pet egg. Kept for overlay reference
    / optional export; egg body in 00–07 is illustrative only.
    """
    out = ANIM / "hatch"
    out.mkdir(parents=True, exist_ok=True)
    egg = Image.open(LAYERS / "eggs" / "E01_pudd_cream.png")
    names = [
        "00_normal", "01_shake", "02_first_crack", "03_more_cracks",
        "04_harder_shake", "05_major_cracks", "06_splitting", "07_pieces_separate",
        "08_flash", "09_silhouette_slot", "10_pet_visible", "11_flash_fade", "12_idle"
    ]
    rng = random.Random(99)
    for i, name in enumerate(names):
        fr = blank64()
        ox = 0
        if i in (1, 4):
            ox = rng.choice([-2, 2, -1, 1])
        if i < 8:
            fr.paste(egg, (ox, 0), egg)
        if i >= 2 and i < 8:
            # cracks
            d = ImageDraw.Draw(fr)
            crack = (40, 30, 40, 255)
            d.line([(32, 20), (28, 32), (34, 40)], fill=crack, width=1)
            if i >= 3:
                d.line([(32, 18), (38, 30), (36, 44)], fill=crack, width=1)
            if i >= 5:
                d.line([(24, 28), (32, 34), (40, 28)], fill=crack, width=1)
            if i >= 6:
                # splitting — shift halves
                left = fr.crop((0, 0, 32, 64))
                right = fr.crop((32, 0, 64, 64))
                fr = blank64()
                fr.paste(left, (-(i-5), 0), left)
                fr.paste(right, (32+(i-5), 0), right)
            if i == 7:
                left = egg.crop((0, 0, 32, 64))
                right = egg.crop((32, 0, 64, 64))
                fr = blank64()
                fr.paste(left, (-4, 2), left)
                fr.paste(right, (36, -2), right)
        if i == 8:
            # flash overlay
            rect(fr, 8, 8, 48, 48, (255, 255, 255, 200))
            for _ in range(20):
                px(fr, rng.randint(10, 54), rng.randint(10, 54), (255, 255, 200, 255))
        if i == 9:
            # silhouette slot (empty dark oval where pet will be)
            ellipse_fill(fr, 20, 18, 44, 50, (20, 20, 30, 180))
        if i == 10:
            # modular: NO pet baked — just open shell pieces + glow
            left = egg.crop((0, 0, 32, 64))
            right = egg.crop((32, 0, 64, 64))
            fr.paste(left, (-6, 4), left)
            fr.paste(right, (38, 4), right)
            ellipse_fill(fr, 22, 20, 42, 48, (255, 255, 200, 60))
        if i == 11:
            rect(fr, 12, 12, 40, 40, (255, 255, 255, 80))
        if i == 12:
            pass  # idle empty — pet composited in preview
        # separate flash/particle overlays
        if i in (8, 11):
            ov = blank64()
            if i == 8:
                rect(ov, 0, 0, 64, 64, (255, 255, 255, 120))
            else:
                for _ in range(15):
                    px(ov, rng.randint(0, 63), rng.randint(0, 63), (255, 255, 200, 180))
            ov.save(out / f"{name}_overlay.png")
        fr.save(out / f"{name}.png")
    return 13

if __name__ == "__main__":
    print("pets", build_pets())
    print("eggs", build_eggs())
    print("fx", build_fx())
    print("rock", build_egg_rock())
    print("hatch", build_hatch())
