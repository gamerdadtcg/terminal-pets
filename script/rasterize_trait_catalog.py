#!/usr/bin/env python3
"""Rasterize trait-catalog SVGs into labeled PNG tiles and per-category sheets."""

from __future__ import annotations

import re
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "artifacts" / "art-pass" / "traits"
DESTS = [
    ROOT / "artifacts" / "art-pass" / "traits",
    ROOT / "web" / "public" / "art-pass" / "traits",
]
TILE = 280
CAPTION_H = 36
TITLE_H = 52
PAD = 14
BG = (10, 8, 14, 255)
INK = (232, 228, 240, 255)
MUTED = (139, 147, 162, 255)
CELL_BG = (7, 8, 11, 255)

SHEETS: list[dict] = [
    {
        "id": "species",
        "title": "Species",
        "blurb": "All 12 silhouettes. Same Round/Sky chassis, Mint body, smile, no accessory.",
        "prefix": "species-",
        "cols": 4,
    },
    {
        "id": "shell",
        "title": "Shell / chassis",
        "blurb": "Handheld outline. Pet inside is the same Cat.",
        "prefix": "shell-",
        "cols": 4,
    },
    {
        "id": "shell-color",
        "title": "Shell color",
        "blurb": "Chassis pigment on a Round shell.",
        "prefix": "shell-color-",
        "cols": 4,
    },
    {
        "id": "buttons",
        "title": "Buttons",
        "blurb": "Three bezel buttons under the screen.",
        "prefix": "buttons-",
        "cols": 4,
    },
    {
        "id": "antenna",
        "title": "Antenna",
        "blurb": "Top nub. None is a valid roll.",
        "prefix": "antenna-",
        "cols": 3,
    },
    {
        "id": "wallpaper",
        "title": "Screen / wallpaper",
        "blurb": "Lit screen fill + pattern. Solid is the default catalog base.",
        "prefix": "wallpaper-",
        "cols": 4,
    },
    {
        "id": "body",
        "title": "Body color",
        "blurb": "Pet fill on the Cat silhouette.",
        "prefix": "body-",
        "cols": 4,
    },
    {
        "id": "belly",
        "title": "Belly",
        "blurb": "Belly patch on most species. Not drawn for Dino or Ghost (OpenSea value is n/a).",
        "prefix": "belly-",
        "cols": 4,
    },
    {
        "id": "eyes",
        "title": "Eyes · Cat (neutral)",
        "blurb": "Front-facing eye types on Cat. Bead, sleepy lid, oversized, sparkle, vertical slit, target rings.",
        "prefix": "eyes-",
        "cols": 3,
        "exclude_prefix": ("eyes-dino-", "eyes-bird-", "eyes-frog-", "eyes-robot-", "eyes-ghost-"),
    },
    {
        "id": "eyes-dino",
        "title": "Eyes · Dino profile",
        "blurb": "Each eye type on the left-facing Dino head.",
        "prefix": "eyes-dino-",
        "cols": 3,
    },
    {
        "id": "eyes-bird",
        "title": "Eyes · Bird",
        "blurb": "Compact pupils on the round Bird head.",
        "prefix": "eyes-bird-",
        "cols": 3,
    },
    {
        "id": "eyes-frog",
        "title": "Eyes · Frog",
        "blurb": "Wide-gap eyes in the Frog bumps.",
        "prefix": "eyes-frog-",
        "cols": 3,
    },
    {
        "id": "eyes-robot",
        "title": "Eyes · Robot",
        "blurb": "LED visor variants. Face overlay is skipped; eyes live in the visor.",
        "prefix": "eyes-robot-",
        "cols": 3,
    },
    {
        "id": "eyes-ghost",
        "title": "Eyes · Ghost",
        "blurb": "Hollow-eye Ghost variants.",
        "prefix": "eyes-ghost-",
        "cols": 3,
    },
    {
        "id": "pupil",
        "title": "Pupils",
        "blurb": "Center, slate fill, or downward glance. Neutral Cat, Dot eyes.",
        "prefix": "pupil-",
        "cols": 3,
    },
    {
        "id": "mouth",
        "title": "Mouth · Cat (neutral)",
        "blurb": "Front-facing mouth / expression.",
        "prefix": "mouth-",
        "cols": 3,
        "exclude_prefix": ("mouth-dino-", "mouth-bird-"),
    },
    {
        "id": "mouth-dino",
        "title": "Mouth · Dino snout",
        "blurb": "Each mouth type on the Dino profile snout.",
        "prefix": "mouth-dino-",
        "cols": 3,
    },
    {
        "id": "mouth-bird",
        "title": "Mouth · Bird beak",
        "blurb": "Bird mouth roll is beak color: Amber, Coral, Sky, Gold, Rose, Ink. Same beak shape.",
        "prefix": "mouth-bird-",
        "cols": 3,
    },
    {
        "id": "cheeks",
        "title": "Cheeks · Cat",
        "blurb": "None, blush, or freckles.",
        "prefix": "cheeks-",
        "cols": 3,
        "exclude_prefix": ("cheeks-dino-",),
    },
    {
        "id": "cheeks-dino",
        "title": "Cheeks · Dino",
        "blurb": "Blush and freckles sit on the snout, behind the eye.",
        "prefix": "cheeks-dino-",
        "cols": 3,
    },
    {
        "id": "brows",
        "title": "Brows (ears roll) · Cat",
        "blurb": "On-chain trait is Ears. Round draws no brow; the others are brow shapes.",
        "prefix": "brows-",
        "cols": 5,
        "exclude_prefix": ("brows-dino-",),
    },
    {
        "id": "brows-dino",
        "title": "Brows (ears roll) · Dino",
        "blurb": "Same ears roll as a single brow over the profile eye.",
        "prefix": "brows-dino-",
        "cols": 5,
    },
    {
        "id": "accessory",
        "title": "Accessories · Cat",
        "blurb": "Bow, cap, star, glasses, halo — plus None.",
        "prefix": "accessory-",
        "cols": 3,
        "exclude_prefix": ("accessory-dino-", "accessory-bird-"),
    },
    {
        "id": "accessory-dino",
        "title": "Accessories · Dino",
        "blurb": "Hats, monocle glasses, and halo on the profile silhouette.",
        "prefix": "accessory-dino-",
        "cols": 3,
    },
    {
        "id": "accessory-bird",
        "title": "Accessories · Bird",
        "blurb": "Same accessory list on the small Bird head. Glasses are wire rims.",
        "prefix": "accessory-bird-",
        "cols": 3,
    },
    {
        "id": "glasses",
        "title": "Glasses on every species",
        "blurb": "Accessory = Glasses (4). One still per species so frames can be judged on each head.",
        "prefix": "glasses-",
        "cols": 4,
    },
    {
        "id": "generation",
        "title": "Generation",
        "blurb": "Footer label only. Pet art does not change.",
        "prefix": "generation-",
        "cols": 4,
    },
    {
        "id": "dormant",
        "title": "Dormant egg",
        "blurb": "Spotted mystery egg on each shell. Species is hidden until Ignite.",
        "prefix": "dormant-",
        "cols": 4,
    },
]


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    ):
        p = Path(path)
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


def svg_to_tile(svg: str) -> Image.Image:
    png = cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=TILE, output_height=TILE)
    im = Image.open(__import__("io").BytesIO(png)).convert("RGBA")
    return im


def parse_stem(stem: str, prefix: str) -> tuple[int, str]:
    rest = stem[len(prefix) :]
    m = re.match(r"(\d+)-(.+)$", rest)
    if not m:
        return 0, rest
    return int(m.group(1)), m.group(2).replace("-", " ")


def list_tiles(prefix: str, exclude_prefix: tuple[str, ...] = ()) -> list[Path]:
    files = []
    for p in sorted(SRC.glob(f"{prefix}*.svg")):
        if any(p.name.startswith(ex) for ex in exclude_prefix):
            continue
        rest = p.stem[len(prefix) :]
        if not re.match(r"^\d+-", rest):
            continue
        files.append(p)
    files.sort(key=lambda p: parse_stem(p.stem, prefix)[0])
    return files


def caption_for(path: Path, prefix: str) -> str:
    idx, name = parse_stem(path.stem, prefix)
    return f"{idx}  ·  {name}"


def build_sheet(spec: dict) -> None:
    exclude = tuple(spec.get("exclude_prefix", ()))
    tiles = list_tiles(spec["prefix"], exclude)
    if not tiles:
        raise SystemExit(f"no tiles for {spec['id']} prefix={spec['prefix']}")
    cols = spec["cols"]
    rows = (len(tiles) + cols - 1) // cols
    cell_w = TILE
    cell_h = TILE + CAPTION_H
    width = cols * cell_w + PAD * (cols + 1)
    height = TITLE_H + rows * cell_h + PAD * (rows + 1)
    sheet = Image.new("RGBA", (width, height), BG)
    draw = ImageDraw.Draw(sheet)
    title_font = font(22)
    blurb_font = font(13)
    cap_font = font(14)
    draw.text((PAD, 10), spec["title"], font=title_font, fill=INK)
    draw.text((PAD, 34), spec["blurb"], font=blurb_font, fill=MUTED)

    for i, path in enumerate(tiles):
        r, c = divmod(i, cols)
        x = PAD + c * (cell_w + PAD)
        y = TITLE_H + PAD + r * (cell_h + PAD)
        tile = svg_to_tile(path.read_text())
        sheet.paste(tile, (x, y), tile)
        cap = caption_for(path, spec["prefix"])
        draw.text((x + 8, y + TILE + 8), cap, font=cap_font, fill=INK)

        tile_png = tile.convert("RGB")
        for dest in DESTS:
            dest.mkdir(parents=True, exist_ok=True)
            tile_png.save(dest / f"{path.stem}.png", "PNG")

    out_name = f"traits-{spec['id']}.png"
    rgb = sheet.convert("RGB")
    for dest in DESTS:
        dest.mkdir(parents=True, exist_ok=True)
        rgb.save(dest / out_name, "PNG")
        print("sheet", dest / out_name)


def write_index_png() -> None:
    """Contact sheet of every category sheet, for the art-pass landing card."""
    thumbs: list[tuple[str, Image.Image]] = []
    for spec in SHEETS:
        path = SRC / f"traits-{spec['id']}.png"
        if not path.exists():
            continue
        im = Image.open(path).convert("RGB")
        im.thumbnail((420, 320))
        thumbs.append((spec["title"], im))
    cols = 4
    rows = (len(thumbs) + cols - 1) // cols
    tw, th = 420, 340
    width = cols * tw + PAD * (cols + 1)
    height = TITLE_H + rows * th + PAD * (rows + 1)
    sheet = Image.new("RGB", (width, height), (10, 8, 14))
    draw = ImageDraw.Draw(sheet)
    draw.text((PAD, 12), "Trait catalog · every option", font=font(22), fill=(232, 228, 240))
    draw.text(
        (PAD, 36),
        "Neutral Cat base unless the sheet names another species. AWAKEN_PET_V2 names, not random tokenIds.",
        font=font(13),
        fill=(139, 147, 162),
    )
    for i, (title, im) in enumerate(thumbs):
        r, c = divmod(i, cols)
        x = PAD + c * (tw + PAD)
        y = TITLE_H + PAD + r * (th + PAD)
        sheet.paste(im, (x, y))
        draw.text((x, y + im.height + 6), title, font=font(13), fill=(232, 228, 240))
    for dest in DESTS:
        dest.mkdir(parents=True, exist_ok=True)
        out = dest / "traits-index.png"
        sheet.save(out, "PNG")
        print("sheet", out)


def main() -> None:
    SRC.mkdir(parents=True, exist_ok=True)
    for spec in SHEETS:
        build_sheet(spec)
    write_index_png()


if __name__ == "__main__":
    main()
