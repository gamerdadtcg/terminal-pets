"""Shared utilities for Pocket Critter NFT art system. 100% procedural — no external art."""
from __future__ import annotations
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# In-repo default: this file lives at art/generator/common.py.
# Override with TERMINAL_PETS_ART_ROOT for a box checkout
# (/workspace/nft-pfp-art-system or /home/box/terminal-pets-generative-art-lock/current).
_DEFAULT_ROOT = Path(__file__).resolve().parent.parent
ROOT = Path(os.environ.get("TERMINAL_PETS_ART_ROOT", _DEFAULT_ROOT)).resolve()
LAYERS = ROOT / "layers"
SCHEMA = ROOT / "schema"
ANIM = ROOT / "anim"
PREVIEWS = ROOT / "previews"
CANVAS = 2048
SS = 4  # supersample factor for smooth handhelds

def load_json(name: str):
    with open(SCHEMA / name) as f:
        return json.load(f)

def hex_to_rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def hex_to_rgba(h: str, a: int = 255):
    return (*hex_to_rgb(h), a)

def new_canvas(mode="RGBA", color=(0, 0, 0, 0)):
    return Image.new(mode, (CANVAS, CANVAS), color)

def ss_canvas(color=(0, 0, 0, 0)):
    return Image.new("RGBA", (CANVAS * SS, CANVAS * SS), color)

def downscale_ss(img: Image.Image) -> Image.Image:
    return img.resize((CANVAS, CANVAS), Image.Resampling.LANCZOS)

def shade(rgb, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)

def tint_grayscale_layer(base: Image.Image, color_hex: str) -> Image.Image:
    """Tint a grayscale+alpha layer by multiplying RGB with color, preserving alpha."""
    r, g, b = hex_to_rgb(color_hex)
    out = base.copy().convert("RGBA")
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            pr, pg, pb, pa = px[x, y]
            if pa == 0:
                continue
            # use luminance of pixel as intensity
            lum = (pr + pg + pb) / (3 * 255.0)
            px[x, y] = (int(r * lum), int(g * lum), int(b * lum), pa)
    return out

def multiply_mask(mask: Image.Image, color_hex: str) -> Image.Image:
    """Opaque mask (white=shell) tinted to color; transparent elsewhere."""
    r, g, b = hex_to_rgb(color_hex)
    out = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    m = mask.convert("L")
    colored = Image.new("RGBA", mask.size, (r, g, b, 255))
    out = Image.composite(colored, out, m)
    return out

def scale_pixel_to_screen(px64: Image.Image, screen: dict) -> Image.Image:
    """Nearest-neighbor uniform scale of 64x64 pixel art to fit inside screen.

    Always outputs a square (ps*64)×(ps*64) bitmap — never stretches axes
    independently. Tall/wide screens letterbox/pillarbox at paste time.
    """
    ps = min(screen["w"] // 64, screen["h"] // 64)
    if ps < 1:
        raise ValueError(f"screen too small for 64-grid: {screen['w']}x{screen['h']}")
    side = ps * 64
    return px64.resize((side, side), Image.Resampling.NEAREST)

def paste_center(dst: Image.Image, src: Image.Image, cx: int, cy: int):
    x = cx - src.width // 2
    y = cy - src.height // 2
    dst.alpha_composite(src, (x, y))

def paste_at(dst: Image.Image, src: Image.Image, x: int, y: int):
    dst.alpha_composite(src, (x, y))

def get_font(size: int):
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf",
        "/System/Library/Fonts/Menlo.ttc",
    ]
    for p in candidates:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()

def set_pixel(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)

def fill_rect(img, x, y, w, h, color):
    draw = ImageDraw.Draw(img)
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=color)

def fill_ellipse(img, x, y, w, h, color):
    draw = ImageDraw.Draw(img)
    draw.ellipse([x, y, x + w - 1, y + h - 1], fill=color)

def outline_pixels(img: Image.Image, outline=(20, 20, 30, 255)):
    """Add 1px dark outline around opaque pixels (pixel-art style)."""
    w, h = img.size
    src = img.copy()
    px = src.load()
    out = img.copy()
    opx = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 128:
                continue
            # if neighbor opaque, become outline
            for dx, dy in ((-1,0),(1,0),(0,-1),(0,1)):
                nx, ny = x+dx, y+dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] > 128:
                    opx[x, y] = outline
                    break
    return out

def darken_edge(rgb, amount=0.55):
    return shade(rgb, amount)
