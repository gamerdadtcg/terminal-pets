#!/usr/bin/env python3
"""Generate ALL trait PNG layers from code (source of truth). Original art only."""
from __future__ import annotations
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from build_shell import build_all_shell
from build_pets import build_pets, build_eggs, build_fx, build_egg_rock, build_hatch

def main():
    print("=== Building shell / BG / UI layers ===")
    shell_counts = build_all_shell()
    print(shell_counts)

    print("=== Building pets ===")
    pet_counts = build_pets()
    print(pet_counts)

    print("=== Building eggs ===")
    print("eggs", build_eggs())

    print("=== Building screen FX ===")
    print("fx", build_fx())

    print("=== Building egg rock anim ===")
    print("egg_rock frames", build_egg_rock())

    print("=== Building hatch anim ===")
    print("hatch frames", build_hatch())

    print("DONE")
    return {**shell_counts, **pet_counts}

if __name__ == "__main__":
    main()
