#!/usr/bin/env python3
"""Build the checked-in asset manifest and license ledger.

Only files under the five retained asset categories are included. This tool is
deliberately dependency-free and never follows a source URL or executes an
asset; it records the files already present on disk.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path


SOURCES = [
    ("beasts/quaternius/cute-monsters", "CC0 1.0 (legacy pack page)", "https://quaternius.com/packs/cutemonsters.html", "https://drive.google.com/drive/folders/1zLLO_7ZoWgUsS4uooYnVSErQYRu1VdS0?usp=sharing", "Inert model/texture formats only; .blend excluded."),
    ("beasts/quaternius/animated-monsters", "CC0 1.0 (legacy pack page)", "https://quaternius.com/packs/animatedmonster.html", "https://drive.google.com/drive/folders/102H-oyUM8SGYi1mW0GOgkjEu7xSdaORA?usp=sharing", "Inert model/texture formats only; .blend excluded."),
    ("beasts/quaternius/animated-aliens", "CC0 1.0 (legacy pack page)", "https://quaternius.com/packs/animatedalien.html", "https://drive.google.com/drive/folders/1ADdETHqjSIEUhjKjhLB9hQjeppXEqcvL?usp=sharing", "Inert model/texture formats only; .blend excluded."),
    ("beasts/quaternius/ultimate-nature", "CC0 1.0 (legacy pack page)", "https://quaternius.com/packs/ultimatenature.html", "https://drive.google.com/drive/folders/1-Kl0L_Jg8awbh0S5T-z3zxh4mVlnxTpa?usp=sharing", "Inert model formats only; .blend excluded."),
    ("beasts/quaternius/ultimate-fantasy-rts", "CC0 1.0 (legacy pack page)", "https://quaternius.com/packs/ultimatefantasyrts.html", "https://drive.google.com/drive/folders/1h7sztlZyavWla-JDk3jp6KiWDdMh08yd?usp=sharing", "Optional inert model subset; .blend excluded."),
    ("environment/kenney/nature-kit", "CC0 1.0", "https://kenney.nl/assets/nature-kit", "https://kenney.nl/media/pages/assets/nature-kit/37ac38a37b-1677698939/kenney_nature-kit.zip", "Inert mesh/texture subset from official ZIP."),
    ("environment/kenney/graveyard-kit", "CC0 1.0", "https://kenney.nl/assets/graveyard-kit", "https://kenney.nl/media/pages/assets/graveyard-kit/ba8d4b4517-1760691807/kenney_graveyard-kit_5.0.zip", "Inert mesh/texture subset from official ZIP."),
    ("environment/kenney/mini-dungeon", "CC0 1.0", "https://kenney.nl/assets/mini-dungeon", "https://kenney.nl/media/pages/assets/mini-dungeon/6cd72dc849-1785314274/kenney_mini-dungeon.zip", "Inert mesh/texture subset from official ZIP."),
    ("environment/kenney/city-kit-roads", "CC0 1.0", "https://kenney.nl/assets/city-kit-roads", "https://kenney.nl/media/pages/assets/city-kit-roads/74288c9459-1791628607/kenney_city-kit-roads.zip", "Inert mesh/texture subset from official ZIP."),
    ("environment/kenney/city-kit-industrial", "CC0 1.0", "https://kenney.nl/assets/city-kit-industrial", "https://kenney.nl/media/pages/assets/city-kit-industrial/0ec35b139d-1788171848/kenney_city-kit-industrial_2.0.zip", "Inert mesh/texture subset from official ZIP."),
    ("sprites/kenney/monster-builder-pack", "CC0 1.0", "https://kenney.nl/assets/monster-builder-pack", "https://kenney.nl/media/pages/assets/monster-builder-pack/663e4ef6de-1677495438/kenney_monster-builder-pack.zip", "PNG subset; vector/metadata files excluded."),
    ("sprites/kenney/platformer-art-extended-enemies", "CC0 1.0", "https://kenney.nl/assets/platformer-art-extended-enemies", "https://kenney.nl/media/pages/assets/platformer-art-extended-enemies/38f1885b37-1677696504/kenney_platformer-art-extended-enemies.zip", "PNG subset; vector/metadata files excluded."),
    ("sprites/kenney/animal-pack-remastered", "CC0 1.0", "https://kenney.nl/assets/animal-pack-remastered", "https://kenney.nl/media/pages/assets/animal-pack-remastered/54a307a369-1774771709/kenney_animal-pack-remastered.zip", "PNG subset; metadata files excluded."),
    ("audio/kenney/rpg-audio", "CC0 1.0", "https://kenney.nl/assets/rpg-audio", "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip", "Audio subset; Roblox upload/moderation still applies."),
    ("audio/kenney/impact-sounds", "CC0 1.0", "https://kenney.nl/assets/impact-sounds", "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip", "Audio subset; Roblox upload/moderation still applies."),
    ("audio/kenney/digital-audio", "CC0 1.0", "https://kenney.nl/assets/digital-audio", "https://kenney.nl/media/pages/assets/digital-audio/216eac4753-1677590265/kenney_digital-audio.zip", "Audio subset; Roblox upload/moderation still applies."),
    ("materials/polyhaven/wood_floor", "CC0 1.0", "https://polyhaven.com/a/wood_floor", "https://api.polyhaven.com/files/wood_floor", "1K JPG/PNG maps from official API/CDN."),
    ("materials/polyhaven/aerial_rocks_04", "CC0 1.0", "https://polyhaven.com/a/aerial_rocks_04", "https://api.polyhaven.com/files/aerial_rocks_04", "1K JPG/PNG maps from official API/CDN."),
]


def source_for(relative: str) -> tuple[str, str, str, str, str]:
    for item in SOURCES:
        if (
            relative == item[0]
            or relative.startswith(item[0] + "/")
            or relative.startswith(item[0] + "_")
        ):
            return item
    raise ValueError(f"no provenance mapping for {relative}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build(root: Path, date: str) -> int:
    entries: list[dict[str, object]] = []
    rows: list[list[object]] = []
    for category in ("beasts", "environment", "sprites", "audio", "materials"):
        for path in sorted((root / category).rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(root).as_posix()
            prefix, license_name, page, download, notes = source_for(relative)
            digest = sha256(path)
            size = path.stat().st_size
            entries.append({"path": relative, "size": size, "sha256": digest, "license": license_name, "source_page": page})
            rows.append([relative, size, digest, license_name, page, download, date, notes])

    manifest = {
        "schemaVersion": 1,
        "generated": date,
        "purpose": "Inert, original brainrot-style asset library for Snatch a Beast",
        "licensePolicy": "CC0 or a source-specific license explicitly recorded in SOURCES.md; no scripts or executables",
        "assets": entries,
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    with (root / "LICENSE-LEDGER.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["path", "size_bytes", "sha256", "license", "source_page", "download_url", "retrieved_date", "notes"])
        writer.writerows(rows)
    print(f"Wrote {len(entries)} asset entries ({sum(int(entry['size']) for entry in entries)} bytes).")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the asset SHA-256 manifest and license ledger.")
    parser.add_argument("--root", default="assets", help="asset directory (default: assets)")
    parser.add_argument("--date", default="2026-10-15", help="retrieval date recorded in the ledger")
    args = parser.parse_args()
    return build(Path(args.root).resolve(), args.date)


if __name__ == "__main__":
    raise SystemExit(main())
