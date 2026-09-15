#!/usr/bin/env python3
"""Hub-only 128×128 pixel-pet preview. Does not change on-chain TerminalRenderer.

Takes existing Lit art-pass SVGs, rasterizes only the creature + traits onto a
128×128 nearest-neighbor canvas, then composites that bitmap back into the
unchanged handheld chrome (shell, bezel, buttons, antenna, wallpaper, labels).
"""

from __future__ import annotations

import base64
import io
import re
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "artifacts" / "art-pass"
DESTS = [
    ROOT / "artifacts" / "art-pass" / "pixel",
    ROOT / "web" / "public" / "art-pass" / "pixel",
]
SCREEN = (116, 94, 168, 160)  # x, y, w, h in the 400×400 viewBox
PET_PX = 128
FULL_PX = 400  # matches on-chain viewBox so chrome stays 1:1
ZOOM = 4

GLOW_RE = re.compile(
    r'<ellipse cx="200" cy="174" rx="70" ry="64"[\s\S]*?(?:/>|</ellipse>)'
)

LIT_STEMS = [
    "Blob-id2-lit",
    "Cat-id3-lit",
    "Dino-id12-lit",
    "Fox-id16-lit",
    "Ghost-id7-lit",
    "Bunny-id28-lit",
    "Bird-id15-lit",
    "Frog-id5-lit",
    "Bear-id1-lit",
    "Robot-id11-lit",
    "Owl-id4-lit",
    "Bug-id6-lit",
    "DinoGrin-id49-lit",
    "DinoClosed-id99-lit",
    "DinoOh-id179-lit",
    "DinoTeeth-id25-lit",
    "DinoTall-id267-lit",
    "BirdGlasses-id29-lit",
    "BirdGlasses2-id224-lit",
    "FrogGlasses-id77-lit",
    "CatGlasses-id219-lit",
    "FoxGlasses-id42-lit",
    "RobotGlasses-id40-lit",
]

COMPARE_PAIRS = [
    ("Cat-id3-lit", "Cat #3"),
    ("Dino-id12-lit", "Dino #12"),
    ("BirdGlasses-id29-lit", "Bird #29 glasses"),
    ("Ghost-id7-lit", "Ghost #7"),
    ("Robot-id11-lit", "Robot #11"),
    ("FrogGlasses-id77-lit", "Frog #77 glasses"),
]

TRAIT_STEMS = [
    "DinoGrin-id49-lit",
    "CatGlasses-id219-lit",
    "BirdGlasses-id29-lit",
    "FoxGlasses-id42-lit",
    "RobotGlasses-id40-lit",
    "DinoTeeth-id25-lit",
]


def strip_smil(svg: str) -> str:
    svg = re.sub(r"<animate[\s\S]*?(?:/>|</animate>)", "", svg)
    svg = re.sub(r"<animateTransform[\s\S]*?(?:/>|</animateTransform>)", "", svg)
    return svg


def split_pet(svg: str) -> tuple[str, str, str]:
    """Return (before_pet, pet_markup, after_pet) from a Lit SVG."""
    svg = strip_smil(svg)
    glow = GLOW_RE.search(svg)
    if not glow:
        raise ValueError("missing lit glow ellipse — not a Lit pet SVG")
    start = glow.end()
    end = svg.rfind("</g></g></svg>")
    if end < 0 or end < start:
        raise ValueError("could not find inner group close")
    return svg[:start], svg[start:end], svg[end:]


def pet_only_svg(pet_markup: str) -> str:
    sx, sy, sw, sh = SCREEN
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{sx} {sy} {sw} {sh}" '
        f'width="{PET_PX}" height="{PET_PX}">'
        '<defs><clipPath id="scr">'
        f'<rect x="{sx}" y="{sy}" width="{sw}" height="{sh}" rx="12"/>'
        "</clipPath></defs>"
        f'<g clip-path="url(#scr)">{pet_markup}</g></svg>'
    )


def crunch_alpha(im: Image.Image) -> Image.Image:
    """Snap anti-aliased edges so the 128 canvas reads as pixels, not blur."""
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                px[x, y] = (0, 0, 0, 0)
            else:
                px[x, y] = (r, g, b, 255)
    return im


def raster_pet(pet_markup: str) -> Image.Image:
    raw = cairosvg.svg2png(
        bytestring=pet_only_svg(pet_markup).encode("utf-8"),
        output_width=PET_PX,
        output_height=PET_PX,
    )
    return crunch_alpha(Image.open(io.BytesIO(raw)).convert("RGBA"))


def png_b64(im: Image.Image) -> str:
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode("ascii")


def embed_pixel_svg(before: str, after: str, pet: Image.Image) -> str:
    sx, sy, sw, sh = SCREEN
    b64 = png_b64(pet)
    image = (
        f'<image href="data:image/png;base64,{b64}" x="{sx}" y="{sy}" '
        f'width="{sw}" height="{sh}" preserveAspectRatio="none" '
        'style="image-rendering:pixelated;image-rendering:crisp-edges;'
        'image-rendering:-moz-crisp-edges"/>'
    )
    return before + image + after


def composite_handheld(before: str, after: str, pet: Image.Image) -> Image.Image:
    chrome_svg = before + after
    chrome = Image.open(
        io.BytesIO(
            cairosvg.svg2png(
                bytestring=chrome_svg.encode("utf-8"),
                output_width=FULL_PX,
                output_height=FULL_PX,
            )
        )
    ).convert("RGBA")
    scale = FULL_PX / 400
    sx, sy, sw, sh = SCREEN
    dest = (
        round(sx * scale),
        round(sy * scale),
        round(sw * scale),
        round(sh * scale),
    )
    scaled = pet.resize((dest[2], dest[3]), Image.Resampling.NEAREST)
    chrome.paste(scaled, (dest[0], dest[1]), scaled)
    return chrome


def font(size: int) -> ImageFont.ImageFont:
    try:
        return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", size)
    except OSError:
        return ImageFont.load_default()


def caption_cell(im: Image.Image, label: str, cell: int) -> Image.Image:
    cap_h = 28
    out = Image.new("RGBA", (cell, cell + cap_h), (10, 8, 14, 255))
    fitted = im.convert("RGBA")
    if fitted.size != (cell, cell):
        fitted = fitted.resize((cell, cell), Image.Resampling.NEAREST)
    out.paste(fitted, (0, 0), fitted)
    draw = ImageDraw.Draw(out)
    draw.text((8, cell + 6), label, fill=(232, 228, 240, 255), font=font(14))
    return out


def sheet(cells: list[Image.Image], cols: int, pad: int = 12) -> Image.Image:
    if not cells:
        raise ValueError("empty sheet")
    cw, ch = cells[0].size
    rows = (len(cells) + cols - 1) // cols
    w = cols * cw + pad * (cols + 1)
    h = rows * ch + pad * (rows + 1)
    out = Image.new("RGBA", (w, h), (10, 8, 14, 255))
    for i, im in enumerate(cells):
        r, c = divmod(i, cols)
        x = pad + c * (cw + pad)
        y = pad + r * (ch + pad)
        out.paste(im, (x, y), im)
    return out


def write_all(name: str, data: bytes | str) -> None:
    for dest in DESTS:
        dest.mkdir(parents=True, exist_ok=True)
        path = dest / name
        if isinstance(data, str):
            path.write_text(data)
        else:
            path.write_bytes(data)
        print("write", path)


def save_png(name: str, im: Image.Image) -> None:
    buf = io.BytesIO()
    im.convert("RGB").save(buf, format="PNG")
    write_all(name, buf.getvalue())


def main() -> None:
    handhelds: dict[str, Image.Image] = {}
    pets: dict[str, Image.Image] = {}
    vectors: dict[str, Image.Image] = {}

    for stem in LIT_STEMS:
        path = SRC / f"{stem}.svg"
        if not path.exists():
            path = ROOT / "web" / "public" / "art-pass" / f"{stem}.svg"
        raw = path.read_text()
        before, pet_markup, after = split_pet(raw)
        pet = raster_pet(pet_markup)
        pets[stem] = pet
        pixel_svg = embed_pixel_svg(before, after, pet)
        handheld = composite_handheld(before, after, pet)
        handhelds[stem] = handheld
        vec = Image.open(
            io.BytesIO(
                cairosvg.svg2png(
                    bytestring=strip_smil(raw).encode("utf-8"),
                    output_width=FULL_PX,
                    output_height=FULL_PX,
                )
            )
        ).convert("RGBA")
        vectors[stem] = vec

        write_all(f"{stem.replace('-lit', '')}-pet128.png", _png_bytes(pet))
        write_all(
            f"{stem.replace('-lit', '')}-pet128-zoom.png",
            _png_bytes(pet.resize((PET_PX * ZOOM, PET_PX * ZOOM), Image.Resampling.NEAREST)),
        )
        write_all(f"{stem.replace('-lit', '')}-pixel.svg", pixel_svg)
        save_png(f"{stem.replace('-lit', '')}-pixel.png", handheld)

    compare_cells: list[Image.Image] = []
    cell = 360
    for stem, label in COMPARE_PAIRS:
        left = caption_cell(vectors[stem].resize((cell, cell), Image.Resampling.LANCZOS), f"{label} · vector", cell)
        right = caption_cell(handhelds[stem].resize((cell, cell), Image.Resampling.NEAREST), f"{label} · 128px", cell)
        compare_cells.extend([left, right])
    save_png("pixel-vs-vector-sheet.png", sheet(compare_cells, cols=2, pad=14))

    species_cells = [
        caption_cell(handhelds[stem].resize((320, 320), Image.Resampling.NEAREST), stem.replace("-lit", ""), 320)
        for stem in LIT_STEMS[:12]
    ]
    save_png("pixel-species-sheet.png", sheet(species_cells, cols=4, pad=12))

    trait_cells = [
        caption_cell(handhelds[stem].resize((320, 320), Image.Resampling.NEAREST), stem.replace("-lit", ""), 320)
        for stem in TRAIT_STEMS
    ]
    save_png("pixel-traits-sheet.png", sheet(trait_cells, cols=3, pad=12))

    zoom_cells = [
        caption_cell(pets[stem].resize((256, 256), Image.Resampling.NEAREST), stem.replace("-lit", "") + " · 128 canvas", 256)
        for stem in ["Cat-id3-lit", "Dino-id12-lit", "BirdGlasses-id29-lit", "Robot-id11-lit", "Ghost-id7-lit", "DinoGrin-id49-lit"]
    ]
    save_png("pixel-pet-canvas-sheet.png", sheet(zoom_cells, cols=3, pad=12))


def _png_bytes(im: Image.Image) -> bytes:
    buf = io.BytesIO()
    im.save(buf, format="PNG")
    return buf.getvalue()


if __name__ == "__main__":
    main()
