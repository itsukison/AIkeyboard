#!/usr/bin/env python3
"""Rank station_database candidates using Japanese Wikipedia page views."""
import argparse
import csv
from pathlib import Path


def normalize_title(value: str) -> str:
    return value.split("_(", 1)[0].replace("_", " ")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stations", type=Path)
    parser.add_argument("pageviews", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()

    views: dict[str, int] = {}
    with arguments.pageviews.open(encoding="utf-8") as source:
        for columns in csv.reader(source, delimiter="\t"):
            if len(columns) < 2:
                continue
            title = normalize_title(columns[0])
            views[title] = views.get(title, 0) + int(columns[1])

    selected = []
    with arguments.stations.open(encoding="utf-8") as source:
        for columns in csv.reader(source, delimiter="\t"):
            if len(columns) < 2:
                continue
            surface, reading = columns[:2]
            article = surface if surface.endswith("駅") else surface + "駅"
            if article in views:
                selected.append((surface, reading, views[article]))

    selected.sort(key=lambda row: (-row[2], row[1], row[0]))
    with arguments.output.open("w", encoding="utf-8") as output:
        for surface, reading, count in selected:
            output.write(f"{surface}\t{reading}\t{count}\n")
    print(f"popular_station_pairs={len(selected)}")


if __name__ == "__main__":
    main()
