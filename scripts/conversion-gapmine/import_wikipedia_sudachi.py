#!/usr/bin/env python3
"""Build ConvProbe candidates from Japanese Wikipedia titles and Sudachi readings."""
import argparse
import csv
import gzip
from pathlib import Path
import re


KANJI = re.compile(r"[\u3400-\u9fff\uf900-\ufaff]")
SAFE_SURFACE = re.compile(r"^[\u3041-\u3096\u30a1-\u30fa\u30fc\u3400-\u9fff\uf900-\ufaff々ヶヵ]+$")
KATAKANA = re.compile(r"^[\u30a1-\u30fa\u30fc]+$")
DEFAULT_GAPFILL = (
    Path(__file__).resolve().parents[2]
    / "Sources/JapaneseKeyboardCore/Resources/conversion_gapfill.tsv"
)


def read_titles(path: Path) -> set[str]:
    titles = set()
    with gzip.open(path, "rt", encoding="utf-8") as source:
        for line in source:
            title = line.rstrip("\n").replace("_", " ")
            if 2 <= len(title) <= 20 and KANJI.search(title) and SAFE_SURFACE.fullmatch(title):
                titles.add(title)
    return titles


def read_existing(path: Path) -> set[str]:
    with path.open(encoding="utf-8") as source:
        return {
            columns[1]
            for columns in csv.reader(source, delimiter="\t")
            if len(columns) >= 2
        }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("titles", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("dictionaries", nargs="+", type=Path)
    parser.add_argument("--gapfill", type=Path, default=DEFAULT_GAPFILL)
    parser.add_argument("--max-rows", type=int, default=30_000)
    arguments = parser.parse_args()

    titles = read_titles(arguments.titles)
    existing = read_existing(arguments.gapfill)
    selected: dict[tuple[str, str], int] = {}
    for dictionary in arguments.dictionaries:
        with dictionary.open(encoding="utf-8", newline="") as source:
            for columns in csv.reader(source):
                if len(columns) <= 11:
                    continue
                surface = columns[0]
                reading = columns[11]
                if (
                    surface not in titles
                    or surface in existing
                    or columns[5:7] != ["名詞", "固有名詞"]
                    or not KATAKANA.fullmatch(reading)
                ):
                    continue
                try:
                    cost = int(columns[3])
                except ValueError:
                    continue
                key = (surface, reading)
                selected[key] = min(selected.get(key, cost), cost)

    rows = sorted(
        ((surface, reading, cost) for (surface, reading), cost in selected.items()),
        key=lambda row: (row[2], row[1], row[0]),
    )[: arguments.max_rows]
    with arguments.output.open("w", encoding="utf-8") as output:
        for surface, reading, cost in rows:
            output.write(f"{surface}\t{reading}\t{max(0, 20_000 - cost)}\n")
    print(f"titles={len(titles)} candidates={len(rows)}")


if __name__ == "__main__":
    main()
