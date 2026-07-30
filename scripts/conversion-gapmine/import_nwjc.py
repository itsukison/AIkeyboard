#!/usr/bin/env python3
"""Convert the NWJC short-unit vocabulary list into ConvProbe input.

Usage:
    import_nwjc.py <NWJC.tsv> <output.tsv> [--min-frequency 100]

Only ordinary nouns are emitted because the production gap-fill loader assigns
every row the general-noun CID. Proper names, non-kanji surfaces, invalid
readings, and surfaces already present in conversion_gapfill.tsv are omitted.
"""
import argparse
import csv
from pathlib import Path
import re


KANJI = re.compile(r"[\u3400-\u9fff\uf900-\ufaff]")
KATAKANA = re.compile(r"^[\u30a1-\u30fa\u30fc]+$")
DEFAULT_GAPFILL = (
    Path(__file__).resolve().parents[2]
    / "Sources/JapaneseKeyboardCore/Resources/conversion_gapfill.tsv"
)


def existing_surfaces(path: Path) -> set[str]:
    surfaces = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        columns = line.split("\t")
        if len(columns) >= 2:
            surfaces.add(columns[1])
    return surfaces


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--min-frequency", type=int, default=100)
    parser.add_argument("--gapfill", type=Path, default=DEFAULT_GAPFILL)
    arguments = parser.parse_args()

    existing = existing_surfaces(arguments.gapfill)
    selected: dict[tuple[str, str], int] = {}
    with arguments.source.open(encoding="utf-8", newline="") as source:
        for row in csv.DictReader(source, delimiter="\t"):
            if not row["pos"].startswith("名詞-普通名詞-") or row["wType"] == "固":
                continue
            surface = row["lemma"]
            reading = row["lForm"]
            try:
                frequency = int(row["frequency"])
            except ValueError:
                continue
            if frequency < arguments.min_frequency:
                continue
            if surface in existing or not KANJI.search(surface) or not KATAKANA.fullmatch(reading):
                continue
            key = (surface, reading)
            selected[key] = max(selected.get(key, 0), frequency)

    rows = sorted(
        ((surface, reading, frequency) for (surface, reading), frequency in selected.items()),
        key=lambda row: (-row[2], row[1], row[0]),
    )
    with arguments.output.open("w", encoding="utf-8") as output:
        for surface, reading, frequency in rows:
            output.write(f"{surface}\t{reading}\t{frequency}\n")
    print(f"wrote {len(rows)} common-noun candidates")


if __name__ == "__main__":
    main()
