#!/usr/bin/env python3
"""Compare gap-fill readings with Sudachi Full tokenized readings."""
import argparse
import csv
from pathlib import Path

from sudachipy import dictionary, tokenizer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("gapfill", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--limit", type=int)
    arguments = parser.parse_args()
    sudachi = dictionary.Dictionary(dict="full").create()

    mismatches = 0
    with arguments.gapfill.open(encoding="utf-8") as source, arguments.output.open(
        "w", encoding="utf-8"
    ) as output:
        output.write("line\treading\tsurface\tsudachi_reading\tsegments\n")
        seen = 0
        for line, columns in enumerate(csv.reader(source, delimiter="\t"), start=1):
            if len(columns) < 2:
                continue
            seen += 1
            if arguments.limit and seen > arguments.limit:
                break
            reading, surface = columns[:2]
            morphemes = sudachi.tokenize(surface, tokenizer.Tokenizer.SplitMode.C)
            expected = "".join(morpheme.reading_form() for morpheme in morphemes)
            if reading == expected:
                continue
            mismatches += 1
            segments = "|".join(
                f"{morpheme.surface()}:{morpheme.reading_form()}" for morpheme in morphemes
            )
            output.write(f"{line}\t{reading}\t{surface}\t{expected}\t{segments}\n")
    print(f"mismatches={mismatches}")


if __name__ == "__main__":
    main()
