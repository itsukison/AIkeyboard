#!/usr/bin/env python3
"""Extract overlapping 2–4-morpheme noun compounds from a FineWeb-2 shard."""
import re
import sys
from collections import Counter

import fugashi
import ipadic
import pyarrow.parquet as pq


MAX_DOCS = 500_000
MIN_COUNT = 20
MAX_ROWS = 50_000
PRUNE_THRESHOLD = 20_000_000
ACCEPT_SUBCLASS = {"一般", "サ変接続", "接尾", "形容動詞語幹"}
KANJI = re.compile(r"[一-鿿]")
LATIN_OR_DIGIT = re.compile(r"[A-Za-z0-9Ａ-Ｚａ-ｚ０-９]")


def valid_surface(surface: str) -> bool:
    return bool(KANJI.search(surface)) and not LATIN_OR_DIGIT.search(surface)


def windows(tagger, line: str):
    run = []

    def flush():
        for start in range(len(run)):
            for length in range(2, 5):
                segment = run[start : start + length]
                if len(segment) == length:
                    yield "".join(item[0] for item in segment), "".join(item[1] for item in segment)
        run.clear()

    for word in tagger(line):
        features = word.feature
        if (
            len(features) >= 8
            and features[0] == "名詞"
            and features[1] in ACCEPT_SUBCLASS
            and features[7] not in {"", "*"}
        ):
            run.append((word.surface, features[7]))
        else:
            yield from flush()
    yield from flush()


def main() -> None:
    shard = sys.argv[1]
    output_path = sys.argv[2]
    max_documents = int(sys.argv[3]) if len(sys.argv) > 3 else MAX_DOCS
    tagger = fugashi.GenericTagger(ipadic.MECAB_ARGS)
    counts = Counter()
    processed = 0

    parquet = pq.ParquetFile(shard)
    for batch in parquet.iter_batches(batch_size=2_000, columns=["text"]):
        for text in batch.column("text").to_pylist():
            if processed >= max_documents:
                break
            processed += 1
            if text:
                for line in text.split("\n"):
                    for surface, reading in windows(tagger, line.strip()):
                        if valid_surface(surface) and 4 <= len(reading) <= 20:
                            counts[(surface, reading)] += 1
            if len(counts) > PRUNE_THRESHOLD:
                counts = Counter({key: count for key, count in counts.items() if count > 1})
        if processed % 50_000 < 2_000:
            print(f"documents={processed} candidates={len(counts)}", file=sys.stderr, flush=True)
        if processed >= max_documents:
            break

    rows = [
        (surface, reading, count)
        for (surface, reading), count in counts.items()
        if count >= MIN_COUNT
    ]
    rows.sort(key=lambda row: (-row[2], row[1], row[0]))
    rows = rows[:MAX_ROWS]
    with open(output_path, "w", encoding="utf-8") as output:
        for surface, reading, count in rows:
            output.write(f"{surface}\t{reading}\t{count}\n")
    print(f"wrote {len(rows)} rows from {processed} documents", file=sys.stderr)


if __name__ == "__main__":
    main()
