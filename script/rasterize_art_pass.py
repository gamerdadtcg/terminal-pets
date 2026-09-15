#!/usr/bin/env python3
"""Rasterize art-pass SVGs to PNG stills + short GIFs (no SMIL in raster)."""

from __future__ import annotations

import io
import re
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DIRS = [
    ROOT / "artifacts" / "art-pass",
    ROOT / "web" / "public" / "art-pass",
]
SIZE = 400


def svg_to_png_bytes(svg: str) -> bytes:
    return cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=SIZE, output_height=SIZE)


def png_image(svg: str) -> Image.Image:
    return Image.open(io.BytesIO(svg_to_png_bytes(svg))).convert("RGBA")


def strip_smil(svg: str) -> str:
    svg = re.sub(r"<animate[\s\S]*?(?:/>|</animate>)", "", svg)
    svg = re.sub(r"<animateTransform[\s\S]*?(?:/>|</animateTransform>)", "", svg)
    return svg


def bake_attr_frame(svg: str, attr: str, frame: int) -> str:
    svg = strip_smil(svg)
    pattern = rf'<g opacity="[^"]*" {attr}="(\d+)">'

    def repl(match: re.Match[str]) -> str:
        n = int(match.group(1))
        op = "1" if n == frame else "0"
        return f'<g opacity="{op}" {attr}="{n}">'

    return re.sub(pattern, repl, svg)


def bake_teaser_frame(svg: str, frame: int) -> str:
    return bake_attr_frame(svg, "data-f", frame)


def bake_wake_frame(svg: str, frame: int) -> str:
    return bake_attr_frame(svg, "data-w", frame)


def bake_opacity(svg: str, opacity: str) -> str:
    svg = strip_smil(svg)
    return svg.replace("<g><text x=", f'<g opacity="{opacity}"><text x=', 1)


def bake_nudge(svg: str, dx: str, dy: str) -> str:
    svg = strip_smil(svg)
    return svg.replace(
        'clip-path="url(#scr)"><g>',
        f'clip-path="url(#scr)"><g transform="translate({dx} {dy})">',
        1,
    )


def write_png(path: Path, svg: str) -> None:
    png = svg_to_png_bytes(svg)
    path.write_bytes(png)
    print("png", path)


def write_gif(
    path: Path,
    frames: list[Image.Image],
    duration: int | list[int] = 380,
) -> None:
    converted = [im.convert("P", palette=Image.Palette.ADAPTIVE, colors=128) for im in frames]
    converted[0].save(
        path,
        save_all=True,
        append_images=converted[1:],
        duration=duration,
        loop=0,
        disposal=2,
    )
    print("gif", path)


def teaser_frame_count(svg: str) -> int:
    return max((int(n) for n in re.findall(r'data-f="(\d+)"', svg)), default=-1) + 1


def contrast_sheet(src: Path) -> None:
    pairs = [
        "Cat-id3",
        "Dino-id12",
        "Ghost-id7",
        "Bird-id15",
        "Robot-id11",
    ]
    images: list[Image.Image] = []
    for stem in pairs:
        images.append(png_image(strip_smil((src / f"{stem}-dormant.svg").read_text())))
        images.append(png_image(strip_smil((src / f"{stem}-lit.svg").read_text())))
    pad = 16
    cell = SIZE
    cols = 2
    rows = 5
    sheet = Image.new("RGBA", (cols * cell + pad * 3, rows * cell + pad * (rows + 1)), (10, 8, 14, 255))
    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + pad)
        sheet.paste(im, (x, y), im)
    for dest in DIRS:
        dest.mkdir(parents=True, exist_ok=True)
        out = dest / "contrast-sheet.png"
        sheet.convert("RGB").save(out, "PNG")
        print("sheet", out)


def species_lit_sheet(src: Path) -> None:
    stems = [
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
    ]
    images = [png_image(strip_smil((src / f"{stem}.svg").read_text())) for stem in stems]
    pad = 12
    cell = SIZE
    cols = 4
    rows = 3
    sheet = Image.new(
        "RGBA",
        (cols * cell + pad * (cols + 1), rows * cell + pad * (rows + 1)),
        (10, 8, 14, 255),
    )
    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + pad)
        sheet.paste(im, (x, y), im)
    for dest in DIRS:
        dest.mkdir(parents=True, exist_ok=True)
        out = dest / "species-lit-sheet.png"
        sheet.convert("RGB").save(out, "PNG")
        print("sheet", out)


def glasses_sheet(src: Path) -> None:
    stems = [
        "DinoGrin-id49-lit",
        "BirdGlasses-id29-lit",
        "BirdGlasses2-id224-lit",
        "FrogGlasses-id77-lit",
        "CatGlasses-id219-lit",
        "FoxGlasses-id42-lit",
        "RobotGlasses-id40-lit",
    ]
    images = [png_image(strip_smil((src / f"{stem}.svg").read_text())) for stem in stems]
    pad = 12
    cell = SIZE
    cols = 4
    rows = 2
    sheet = Image.new(
        "RGBA",
        (cols * cell + pad * (cols + 1), rows * cell + pad * (rows + 1)),
        (10, 8, 14, 255),
    )
    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + pad)
        sheet.paste(im, (x, y), im)
    for dest in DIRS:
        dest.mkdir(parents=True, exist_ok=True)
        out = dest / "glasses-sheet.png"
        sheet.convert("RGB").save(out, "PNG")
        print("sheet", out)


def bird_glasses_sheet(src: Path) -> None:
    stems = [
        "Bird-id15-lit",
        "BirdGlasses-id29-lit",
        "BirdGlasses2-id224-lit",
    ]
    images = [png_image(strip_smil((src / f"{stem}.svg").read_text())) for stem in stems]
    pad = 12
    cell = SIZE
    cols = 3
    rows = 1
    sheet = Image.new(
        "RGBA",
        (cols * cell + pad * (cols + 1), rows * cell + pad * (rows + 1)),
        (10, 8, 14, 255),
    )
    for i, im in enumerate(images):
        x = pad + i * (cell + pad)
        sheet.paste(im, (x, pad), im)
    for dest in DIRS:
        dest.mkdir(parents=True, exist_ok=True)
        out = dest / "bird-glasses-sheet.png"
        sheet.convert("RGB").save(out, "PNG")
        print("sheet", out)


def dino_faces_sheet(src: Path) -> None:
    stems = [
        "Dino-id12-lit",
        "DinoGrin-id49-lit",
        "DinoClosed-id99-lit",
        "DinoOh-id179-lit",
        "DinoTeeth-id25-lit",
        "DinoTall-id267-lit",
    ]
    images = [png_image(strip_smil((src / f"{stem}.svg").read_text())) for stem in stems]
    pad = 12
    cell = SIZE
    cols = 3
    rows = 2
    sheet = Image.new(
        "RGBA",
        (cols * cell + pad * (cols + 1), rows * cell + pad * (rows + 1)),
        (10, 8, 14, 255),
    )
    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + pad)
        sheet.paste(im, (x, y), im)
    for dest in DIRS:
        dest.mkdir(parents=True, exist_ok=True)
        out = dest / "dino-faces-sheet.png"
        sheet.convert("RGB").save(out, "PNG")
        print("sheet", out)


def main() -> None:
    src = ROOT / "artifacts" / "art-pass"
    for svg_path in sorted(src.glob("*.svg")):
        raw = svg_path.read_text()
        stem = svg_path.stem
        if "sealed" in stem:
            still = bake_teaser_frame(raw, 1 if 'data-f="1"' in raw else 0)
        elif "wake" in stem:
            still = bake_wake_frame(raw, 3)
        else:
            still = raw
        for dest in DIRS:
            dest.mkdir(parents=True, exist_ok=True)
            write_png(dest / f"{stem}.png", still)

        frames: list[Image.Image] = []
        duration: int | list[int] = 380
        bake_gif = "wake" in stem or "sealed" in stem
        if "wake" in stem:
            frames = [png_image(bake_wake_frame(raw, i)) for i in range(4)]
            duration = [900, 700, 280, 1100]
        elif "sealed" in stem:
            n = teaser_frame_count(raw)
            frames = [png_image(bake_teaser_frame(raw, i)) for i in range(n)]
            duration = [900] + [700] * (n - 1)
        elif bake_gif and "dormant" in stem:
            for op in ("0.35", "0.95", "0.55"):
                frames.append(png_image(bake_opacity(raw, op)))
        elif bake_gif:
            for dx, dy in (("0", "0"), ("1", "-1"), ("-1", "1")):
                frames.append(png_image(bake_nudge(raw, dx, dy)))
        if frames:
            for dest in DIRS:
                write_gif(dest / f"{stem}.gif", frames, duration=duration)

    contrast_sheet(src)
    species_lit_sheet(src)
    glasses_sheet(src)
    bird_glasses_sheet(src)
    dino_faces_sheet(src)
    sample_100_sheet(src)


def sample_100_sheet(src: Path) -> None:
    folder = src / "sample-100"
    images: list[Image.Image] = []
    captions: list[str] = []
    for i in range(1, 101):
        path = folder / f"{i}.svg"
        if not path.exists():
            raise SystemExit(f"missing sample {path}")
        raw = strip_smil(path.read_text())
        im = png_image(raw)
        images.append(im)
        captions.append(f"#{i}")
        png_bytes = cairosvg.svg2png(bytestring=raw.encode("utf-8"), output_width=220, output_height=220)
        for dest in (
            ROOT / "artifacts" / "art-pass" / "sample-100",
            ROOT / "web" / "public" / "art-pass" / "sample-100",
        ):
            dest.mkdir(parents=True, exist_ok=True)
            (dest / f"{i}.png").write_bytes(png_bytes)

    pad = 8
    cell = SIZE
    cols = 10
    rows = 10
    caption_h = 22
    title_h = 48
    width = cols * cell + pad * (cols + 1)
    height = title_h + rows * (cell + caption_h) + pad * (rows + 1)
    sheet = Image.new("RGBA", (width, height), (10, 8, 14, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 18)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
        small = font
    draw.text((pad, 10), "Lit pets 1–100", font=font, fill=(232, 228, 240, 255))
    draw.text(
        (pad, 32),
        "AWAKEN_PET_V2 token ids. Mixed species, eyes, and bird beak colors.",
        font=small,
        fill=(139, 147, 162, 255),
    )
    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = title_h + pad + r * (cell + caption_h + pad)
        sheet.paste(im, (x, y), im)
        draw.text((x + 8, y + cell + 2), captions[i], font=small, fill=(232, 228, 240, 255))
    rgb = sheet.convert("RGB")
    for dest in DIRS:
        dest.mkdir(parents=True, exist_ok=True)
        out = dest / "sample-100.png"
        rgb.save(out, "PNG")
        print("sheet", out)


if __name__ == "__main__":
    main()
