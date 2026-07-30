#!/usr/bin/env python3
"""Compare gap-fill readings with one or more Sudachi dictionary CSV files."""
import argparse
import csv
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("gapfill", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("dictionaries", nargs="+", type=Path)
    parser.add_argument("--limit", type=int)
    arguments = parser.parse_args()

    rows = []
    with arguments.gapfill.open(encoding="utf-8") as source:
        for index, columns in enumerate(csv.reader(source, delimiter="\t"), start=1):
            if len(columns) >= 2:
                rows.append((index, columns[0], columns[1]))
            if arguments.limit and len(rows) >= arguments.limit:
                break

    wanted = {surface for _, _, surface in rows}
    readings: dict[str, set[str]] = {surface: set() for surface in wanted}
    for dictionary in arguments.dictionaries:
        with dictionary.open(encoding="utf-8", newline="") as source:
            for columns in csv.reader(source):
                if len(columns) > 11 and columns[0] in wanted:
                    readings[columns[0]].add(columns[11])

    counts = {"exact": 0, "mismatch": 0, "missing": 0}
    with arguments.output.open("w", encoding="utf-8") as output:
        output.write("line\treading\tsurface\tstatus\tsudachi_readings\n")
        for line, reading, surface in rows:
            alternatives = readings[surface]
            if reading in alternatives:
                status = "exact"
            elif alternatives:
                status = "mismatch"
            else:
                status = "missing"
            counts[status] += 1
            output.write(
                f"{line}\t{reading}\t{surface}\t{status}\t{'|'.join(sorted(alternatives))}\n"
            )
    print(" ".join(f"{key}={value}" for key, value in counts.items()))


if __name__ == "__main__":
    main()
