#!/usr/bin/env python3
"""Build reading-verified candidates from popular Japanese Wikipedia redirects."""
import argparse
import csv
import gzip
from pathlib import Path
import re


KANJI = re.compile(r"[\u3400-\u9fff\uf900-\ufaff]")
KANA = re.compile(r"^[\u3041-\u3096\u30a1-\u30fa\u30fc]+$")
SAFE_SURFACE = re.compile(r"^[\u3041-\u3096\u30a1-\u30fa\u30fc\u3400-\u9fff\uf900-\ufaff々ヶヵ]+$")
ROW = re.compile(rb"\((\d+),(\d+),'((?:[^'\\]|\\.)*)'")
DEFAULT_GAPFILL = (
    Path(__file__).resolve().parents[2]
    / "Sources/JapaneseKeyboardCore/Resources/conversion_gapfill.tsv"
)


def decode_sql_string(value: bytes) -> str:
    replacements = {
        ord("0"): b"\0",
        ord("n"): b"\n",
        ord("r"): b"\r",
        ord("Z"): b"\x1a",
    }
    output = bytearray()
    index = 0
    while index < len(value):
        if value[index] == ord("\\") and index + 1 < len(value):
            index += 1
            output.extend(replacements.get(value[index], bytes([value[index]])))
        else:
            output.append(value[index])
        index += 1
    return output.decode("utf-8")


def base_title(value: str) -> str:
    return value.split("_(", 1)[0].replace("_", " ")


def katakana(value: str) -> str:
    return "".join(
        chr(ord(character) + 0x60) if "\u3041" <= character <= "\u3096" else character
        for character in value
    )


def read_views(path: Path) -> dict[str, int]:
    views = {}
    with path.open(encoding="utf-8") as source:
        for columns in csv.reader(source, delimiter="\t"):
            if len(columns) >= 2:
                views[columns[0]] = int(columns[1])
    return views


def read_redirects(path: Path) -> dict[int, str]:
    redirects = {}
    with gzip.open(path, "rb") as source:
        for line in source:
            if not line.startswith(b"INSERT INTO `redirect`"):
                continue
            for match in ROW.finditer(line):
                if match.group(2) == b"0":
                    redirects[int(match.group(1))] = decode_sql_string(match.group(3))
    return redirects


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("pages", type=Path)
    parser.add_argument("redirects", type=Path)
    parser.add_argument("pageviews", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("dictionaries", nargs="+", type=Path)
    parser.add_argument("--gapfill", type=Path, default=DEFAULT_GAPFILL)
    parser.add_argument("--max-rows", type=int, default=10_000)
    arguments = parser.parse_args()

    views = read_views(arguments.pageviews)
    dictionary_pairs = set()
    for dictionary in arguments.dictionaries:
        with dictionary.open(encoding="utf-8", newline="") as source:
            for columns in csv.reader(source):
                if len(columns) > 11:
                    dictionary_pairs.add((columns[0], columns[11]))
    redirects = read_redirects(arguments.redirects)
    candidates: dict[tuple[str, str], int] = {}
    with gzip.open(arguments.pages, "rb") as source:
        for line in source:
            if not line.startswith(b"INSERT INTO `page`"):
                continue
            for match in ROW.finditer(line):
                page_id = int(match.group(1))
                if match.group(2) != b"0" or page_id not in redirects:
                    continue
                source_title = base_title(decode_sql_string(match.group(3)))
                target_title = redirects[page_id]
                surface = base_title(target_title)
                reading = katakana(source_title)
                if (
                    target_title not in views
                    or not KANA.fullmatch(source_title)
                    or not KANJI.search(surface)
                    or not SAFE_SURFACE.fullmatch(surface)
                    or not 2 <= len(surface) <= 20
                    or (surface, reading) not in dictionary_pairs
                ):
                    continue
                key = (surface, reading)
                candidates[key] = candidates.get(key, 0) + views[target_title]

    with arguments.gapfill.open(encoding="utf-8") as source:
        existing = {
            columns[1]
            for columns in csv.reader(source, delimiter="\t")
            if len(columns) >= 2
        }
    readings_by_surface: dict[str, set[str]] = {}
    for surface, reading in candidates:
        readings_by_surface.setdefault(surface, set()).add(reading)
    rows = sorted(
        (
            (surface, reading, count)
            for (surface, reading), count in candidates.items()
            if surface not in existing and len(readings_by_surface[surface]) == 1
        ),
        key=lambda row: (-row[2], row[1], row[0]),
    )[: arguments.max_rows]
    with arguments.output.open("w", encoding="utf-8") as output:
        for surface, reading, count in rows:
            output.write(f"{surface}\t{reading}\t{count}\n")
    print(f"redirects={len(redirects)} verified_popular_candidates={len(rows)}")


if __name__ == "__main__":
    main()
