#!/usr/bin/env python3
"""Rewrite ERC-721 metadata `image` fields after pinning GIFs to IPFS/HTTP.

Example after pinning awake GIFs to ipfs://bafyArt/ and eggs to ipfs://bafyEgg/:

    python art/generator/rewrite_image_uris.py \\
      --dir art/export/gif-test/metadata --base ipfs://bafyArt/
    python art/generator/rewrite_image_uris.py \\
      --dir art/export/gif-test/egg-metadata --base ipfs://bafyEgg/
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def join_asset_uri(base: str, filename: str) -> str:
    if base.endswith("/"):
        return base + filename
    return f"{base}/{filename}"


def rewrite_dir(directory: Path, base: str, field: str = "image") -> int:
    n = 0
    for path in sorted(directory.glob("*.json")):
        data = json.loads(path.read_text())
        current = str(data.get(field, ""))
        filename = Path(current).name if current else f"{path.stem}.gif"
        data[field] = join_asset_uri(base, filename)
        path.write_text(json.dumps(data, indent=2) + "\n")
        n += 1
    return n


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Prefix metadata image URIs")
    p.add_argument("--dir", type=Path, required=True, help="Directory of {id}.json files")
    p.add_argument("--base", required=True, help="ipfs://CID/ or https://host/path/")
    p.add_argument("--field", default="image", help="JSON field to rewrite (default: image)")
    args = p.parse_args(argv)
    if not args.dir.is_dir():
        raise SystemExit(f"not a directory: {args.dir}")
    n = rewrite_dir(args.dir, args.base, args.field)
    print(f"rewrote {n} files in {args.dir} → {args.base}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
