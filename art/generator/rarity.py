"""Weighted rarity helpers for Terminal Pets trait rolls."""
from __future__ import annotations

import json
import random
import sys
from pathlib import Path
from typing import Any, Iterable, Sequence

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import SCHEMA, load_json

TIER_WEIGHTS = {
    "common": 60,
    "rare": 25,
    "epic": 10,
    "legendary": 5,
}

TIER_ORDER = ["common", "rare", "epic", "legendary"]

TIER_LABELS = {
    "common": "Common",
    "rare": "Rare",
    "epic": "Epic",
    "legendary": "Legendary",
}

TIER_COLORS = {
    "common": "#8B9BB4",
    "rare": "#3D7EFF",
    "epic": "#A855F7",
    "legendary": "#F5A623",
}


def option_id(opt: Any) -> str:
    """Normalize a trait option (string or {id:...}) to its id."""
    if isinstance(opt, dict):
        return opt["id"]
    return str(opt)


def option_rarity(opt: Any) -> str | None:
    if isinstance(opt, dict):
        return opt.get("rarity")
    return None


def option_weight(opt: Any) -> int | None:
    if isinstance(opt, dict):
        return opt.get("weight")
    return None


def as_option(opt: Any) -> dict:
    """Coerce string or dict option into a dict with at least id."""
    if isinstance(opt, dict):
        return opt
    return {"id": str(opt)}


def pick_weighted(options: Sequence[Any], rng: random.Random | None = None) -> Any:
    """Pick one option using each option's ``weight`` field (default 1).

    Accepts dict options with ``weight`` or plain strings (weight 1).
    Returns the original option object from the sequence.
    """
    if not options:
        raise ValueError("pick_weighted: empty options")
    weights: list[float] = []
    for opt in options:
        w = option_weight(opt)
        if w is None:
            w = 1
        if w < 0:
            raise ValueError(f"negative weight for {option_id(opt)}")
        weights.append(float(w))
    total = sum(weights)
    if total <= 0:
        raise ValueError("pick_weighted: total weight is 0")
    r = (rng or random).random() * total
    acc = 0.0
    for opt, w in zip(options, weights):
        acc += w
        if r <= acc:
            return opt
    return options[-1]


def expected_odds(options: Sequence[Any]) -> list[dict]:
    """Return per-option expected odds within a category.

    Each row: id, rarity, weight, probability (0–1), percent (0–100).
    """
    rows = []
    weights = []
    for opt in options:
        o = as_option(opt)
        w = o.get("weight", 1) or 0
        weights.append(float(w))
        rows.append(
            {
                "id": o.get("id"),
                "rarity": o.get("rarity"),
                "weight": o.get("weight"),
            }
        )
    total = sum(weights)
    out = []
    for row, w in zip(rows, weights):
        p = (w / total) if total else 0.0
        out.append(
            {
                **row,
                "probability": p,
                "percent": round(p * 100, 4),
            }
        )
    return out


def category_tier_counts(options: Sequence[Any]) -> dict[str, int]:
    counts = {t: 0 for t in TIER_ORDER}
    for opt in options:
        r = option_rarity(opt)
        if r in counts:
            counts[r] += 1
    return counts


def load_traits() -> dict:
    return load_json("traits.json")


def iter_top_level_lists(traits: dict) -> Iterable[tuple[str, list]]:
    for key in (
        "backgrounds",
        "handhelds",
        "shell_colors",
        "shell_class",
        "buttons",
        "antennas",
        "screens",
        "screen_effects",
        "eggs",
    ):
        if key in traits:
            yield key, traits[key]


def build_rarity_summary(traits: dict | None = None) -> dict:
    """Machine-readable odds snapshot for every selectable category."""
    traits = traits or load_traits()
    tiers = traits.get("rarity_tiers") or {
        t: {"weight": TIER_WEIGHTS[t], "label": TIER_LABELS[t], "order": i}
        for i, t in enumerate(TIER_ORDER)
    }
    categories: dict[str, Any] = {}

    for key, opts in iter_top_level_lists(traits):
        odds = expected_odds(opts)
        categories[key] = {
            "count": len(opts),
            "tier_counts": category_tier_counts(opts),
            "options": odds,
        }

    pets = traits.get("pets") or {}
    pet_opts = []
    for pid, meta in pets.items():
        pet_opts.append(
            {
                "id": pid,
                "name": meta.get("name"),
                "rarity": meta.get("rarity", "common"),
                "weight": meta.get("weight", TIER_WEIGHTS["common"]),
            }
        )
    categories["pets"] = {
        "count": len(pet_opts),
        "tier_counts": category_tier_counts(pet_opts),
        "options": expected_odds(pet_opts),
    }

    per_pet: dict[str, Any] = {}
    for pid, meta in pets.items():
        entry: dict[str, Any] = {}
        for sub in ("colors", "eyes", "mouths", "accessories"):
            opts = [as_option(o) for o in meta.get(sub, [])]
            entry[sub] = {
                "count": len(opts),
                "tier_counts": category_tier_counts(opts),
                "options": expected_odds(opts),
            }
        per_pet[pid] = entry
    categories["per_pet"] = per_pet

    return {
        "version": traits.get("version", 1),
        "rarity_tiers": tiers,
        "categories": categories,
    }


def write_rarity_summary(path: Path | None = None) -> Path:
    path = path or (SCHEMA / "rarity-summary.json")
    summary = build_rarity_summary()
    path.write_text(json.dumps(summary, indent=2) + "\n")
    return path


if __name__ == "__main__":
    out = write_rarity_summary()
    print(f"wrote {out}")
