#!/usr/bin/env python3
"""Compare gap-fill readings with JMdict entries."""
import argparse
import csv
import gzip
from pathlib import Path
import xml.etree.ElementTree as ET


def katakana(value: str) -> str:
    return "".join(
        chr(ord(character) + 0x60) if "ぁ" <= character <= "ゖ" else character
        for character in value
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("gapfill", type=Path)
    parser.add_argument("jmdict", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--limit", type=int)
    arguments = parser.parse_args()

    rows = []
    with arguments.gapfill.open(encoding="utf-8") as source:
        for line, columns in enumerate(csv.reader(source, delimiter="\t"), start=1):
            if len(columns) >= 2:
                rows.append((line, columns[0], columns[1]))
            if arguments.limit and len(rows) >= arguments.limit:
                break

    wanted = {surface for _, _, surface in rows}
    readings: dict[str, set[str]] = {surface: set() for surface in wanted}
    with gzip.open(arguments.jmdict, "rb") as source:
        for _, entry in ET.iterparse(source, events=("end",)):
            if entry.tag != "entry":
                continue
            surfaces = {element.text for element in entry.findall("k_ele/keb")} & wanted
            for reading_element in entry.findall("r_ele"):
                reading = reading_element.findtext("reb")
                restrictions = {element.text for element in reading_element.findall("re_restr")}
                for surface in surfaces:
                    if reading and (not restrictions or surface in restrictions):
                        readings[surface].add(katakana(reading))
            entry.clear()

    counts = {"exact": 0, "mismatch": 0, "missing": 0}
    with arguments.output.open("w", encoding="utf-8") as output:
        output.write("line\treading\tsurface\tstatus\tjmdict_readings\n")
        for line, reading, surface in rows:
            alternatives = readings[surface]
            status = "exact" if reading in alternatives else "mismatch" if alternatives else "missing"
            counts[status] += 1
            output.write(
                f"{line}\t{reading}\t{surface}\t{status}\t{'|'.join(sorted(alternatives))}\n"
            )
    print(" ".join(f"{key}={value}" for key, value in counts.items()))


if __name__ == "__main__":
    main()
