#!/usr/bin/env python3
"""Build ConvProbe candidates from popular Japanese Wikipedia pages and Sudachi."""
import argparse
import csv
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta
import json
from pathlib import Path
import re
import time
from urllib.error import HTTPError
from urllib.request import Request, urlopen


KANJI = re.compile(r"[\u3400-\u9fff\uf900-\ufaff]")
SAFE_SURFACE = re.compile(r"^[\u3041-\u3096\u30a1-\u30fa\u30fc\u3400-\u9fff\uf900-\ufaff々ヶヵ]+$")
KATAKANA = re.compile(r"^[\u30a1-\u30fa\u30fc]+$")
DEFAULT_GAPFILL = (
    Path(__file__).resolve().parents[2]
    / "Sources/JapaneseKeyboardCore/Resources/conversion_gapfill.tsv"
)


def fetch(day: date) -> list[dict]:
    url = (
        "https://wikimedia.org/api/rest_v1/metrics/pageviews/top/"
        f"ja.wikipedia/all-access/{day:%Y/%m/%d}"
    )
    request = Request(url, headers={"User-Agent": "KeigoButtonConversionAudit/1.0 (core7.jp)"})
    for attempt in range(5):
        try:
            with urlopen(request, timeout=30) as response:
                return json.load(response)["items"][0]["articles"]
        except HTTPError as error:
            if error.code != 429 or attempt == 4:
                raise
            time.sleep(min(int(error.headers.get("Retry-After", "1")), 10))
    return []


def normalize_title(value: str) -> str:
    value = value.split("_(", 1)[0].replace("_", " ")
    return value


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("start", type=date.fromisoformat)
    parser.add_argument("days", type=int)
    parser.add_argument("output", type=Path)
    parser.add_argument("dictionaries", nargs="+", type=Path)
    parser.add_argument("--gapfill", type=Path, default=DEFAULT_GAPFILL)
    parser.add_argument("--max-rows", type=int, default=10_000)
    parser.add_argument("--raw-output", type=Path)
    arguments = parser.parse_args()

    dates = [arguments.start + timedelta(days=offset) for offset in range(arguments.days)]
    raw_views: dict[str, int] = {}
    with ThreadPoolExecutor(max_workers=2) as executor:
        for articles in executor.map(fetch, dates):
            for article in articles:
                title = article["article"]
                raw_views[title] = raw_views.get(title, 0) + int(article["views"])

    if arguments.raw_output:
        with arguments.raw_output.open("w", encoding="utf-8") as output:
            for title, count in sorted(raw_views.items(), key=lambda row: (-row[1], row[0])):
                output.write(f"{title}\t{count}\n")

    views: dict[str, int] = {}
    for title, count in raw_views.items():
        surface = normalize_title(title)
        if (
            2 <= len(surface) <= 20
            and KANJI.search(surface)
            and SAFE_SURFACE.fullmatch(surface)
        ):
            views[surface] = views.get(surface, 0) + count

    with arguments.gapfill.open(encoding="utf-8") as source:
        existing = {
            columns[1]
            for columns in csv.reader(source, delimiter="\t")
            if len(columns) >= 2
        }

    selected: dict[tuple[str, str], int] = {}
    for dictionary in arguments.dictionaries:
        with dictionary.open(encoding="utf-8", newline="") as source:
            for columns in csv.reader(source):
                if len(columns) <= 11:
                    continue
                surface = columns[0]
                reading = columns[11]
                if (
                    surface not in views
                    or surface in existing
                    or columns[5] != "名詞"
                    or not KATAKANA.fullmatch(reading)
                ):
                    continue
                selected[(surface, reading)] = views[surface]

    rows = sorted(
        ((surface, reading, count) for (surface, reading), count in selected.items()),
        key=lambda row: (-row[2], row[1], row[0]),
    )[: arguments.max_rows]
    with arguments.output.open("w", encoding="utf-8") as output:
        for surface, reading, count in rows:
            output.write(f"{surface}\t{reading}\t{count}\n")
    print(f"popular_titles={len(views)} candidates={len(rows)}")


if __name__ == "__main__":
    main()
