#!/usr/bin/env python3
"""Convert station_database station.json into ConvProbe input TSV files.

Usage:
    import_station_database.py <station.json> <output-prefix>

Writes <output-prefix>-names.tsv and <output-prefix>-with-eki.tsv as
surface<TAB>reading(katakana)<TAB>line-count. The line count is a rough
interchange/reach priority, not passenger volume. Active station names whose
surface contains no kanji are omitted because they require no kana-kanji
conversion.
"""
import json
import sys


def hiragana_to_katakana(value: str) -> str:
    return "".join(
        chr(ord(character) + 0x60) if "\u3041" <= character <= "\u3096" else character
        for character in value
    )


def contains_kanji(value: str) -> bool:
    return any("\u3400" <= character <= "\u9fff" for character in value)


def main() -> None:
    station_path, output_prefix = sys.argv[1:3]
    with open(station_path, encoding="utf-8") as source:
        stations = json.load(source)

    names: dict[tuple[str, str], set[int]] = {}
    for station in stations:
        if station["closed"]:
            continue
        surface = station["original_name"].strip()
        reading = hiragana_to_katakana(station["name_kana"].strip())
        if not surface or not reading or not contains_kanji(surface):
            continue
        names.setdefault((surface, reading), set()).update(station.get("lines", []))

    rows = sorted(
        ((surface, reading, len(lines)) for (surface, reading), lines in names.items()),
        key=lambda row: (-row[2], row[1], row[0]),
    )
    with open(f"{output_prefix}-names.tsv", "w", encoding="utf-8") as output:
        for surface, reading, line_count in rows:
            output.write(f"{surface}\t{reading}\t{line_count}\n")
    with open(f"{output_prefix}-with-eki.tsv", "w", encoding="utf-8") as output:
        for surface, reading, line_count in rows:
            if surface.endswith("駅"):
                output.write(f"{surface}\t{reading}\t{line_count}\n")
            else:
                output.write(f"{surface}駅\t{reading}エキ\t{line_count}\n")

    print(f"wrote {len(rows)} active kanji station names")


if __name__ == "__main__":
    main()
