#!/usr/bin/env python3
"""Extract candidate compound nouns (2-4 consecutive noun morphemes) from a
FineWeb-2 Japanese parquet shard, tokenized with MeCab/IPADIC via fugashi.

Usage: extract_compounds.py <shard.parquet> <out.tsv> [max_docs]

Output: surface<TAB>reading(katakana)<TAB>count, sorted by count desc,
count >= 20, capped at 30000 rows.
"""
import re
import sys
from collections import Counter

import pyarrow.parquet as pq
import fugashi
import ipadic

MAX_DOCS = 500_000
MIN_COUNT = 20
MAX_ROWS = 30_000
PRUNE_THRESHOLD = 20_000_000

# 品詞細分類1 values that are acceptable inside a compound-noun run.
ACCEPT_SUBCLASS = {"一般", "サ変接続", "接尾", "形容動詞語幹"}
REJECT_SUBCLASS = {"数", "非自立", "代名詞"}

KANJI_RE = re.compile(r"[一-鿿]")
ASCII_RE = re.compile(r"[A-Za-z0-9]")
FULLWIDTH_DIGIT_RE = re.compile(r"[０-９]")
KATAKANA_ONLY_RE = re.compile(r"^[゠-ヿー]+$")


def is_valid_surface(surface: str) -> bool:
    if not KANJI_RE.search(surface):
        return False
    if ASCII_RE.search(surface):
        return False
    if FULLWIDTH_DIGIT_RE.search(surface):
        return False
    if KATAKANA_ONLY_RE.match(surface):
        return False
    return True


def extract_runs(tagger, line):
    """Yield (surface, reading) for maximal runs of 2-4 noun morphemes."""
    run_surfaces = []
    run_readings = []

    def flush():
        results = []
        n = len(run_surfaces)
        if n >= 2:
            # emit maximal run itself, capped at 4; if run > 4, slide window
            # to still capture 2-4 length subsequences without runaway
            # combinatorics: just take non-overlapping windows starting at 0.
            i = 0
            while i < n:
                length = min(4, n - i)
                if length < 2:
                    break
                surface = "".join(run_surfaces[i:i + length])
                reading = "".join(run_readings[i:i + length])
                results.append((surface, reading))
                i += length
        run_surfaces.clear()
        run_readings.clear()
        return results

    out = []
    for word in tagger(line):
        feats = word.feature
        # GenericTagger + ipadic MECAB_ARGS yields feature as a plain tuple:
        # (品詞,品詞細分類1,品詞細分類2,品詞細分類3,活用型,活用形,原形,読み,発音)
        if len(feats) < 8:
            out.extend(flush())
            continue
        hinshi = feats[0]
        subclass1 = feats[1]
        reading = feats[7]
        if hinshi == "名詞" and subclass1 in ACCEPT_SUBCLASS and reading != "*" and reading:
            run_surfaces.append(word.surface)
            run_readings.append(reading)
        else:
            out.extend(flush())
    out.extend(flush())
    return out


def main():
    shard = sys.argv[1]
    out_path = sys.argv[2]
    max_docs = int(sys.argv[3]) if len(sys.argv) > 3 else MAX_DOCS

    tagger = fugashi.GenericTagger(ipadic.MECAB_ARGS)

    counts = Counter()
    docs_processed = 0
    pf = pq.ParquetFile(shard)
    for batch in pf.iter_batches(batch_size=2000, columns=["text"]):
        texts = batch.column("text").to_pylist()
        for text in texts:
            if docs_processed >= max_docs:
                break
            docs_processed += 1
            if not text:
                continue
            for line in text.split("\n"):
                line = line.strip()
                if len(line) < 2:
                    continue
                for surface, reading in extract_runs(tagger, line):
                    if not is_valid_surface(surface):
                        continue
                    rlen = len(reading)
                    if rlen < 4 or rlen > 12:
                        continue
                    counts[(surface, reading)] += 1
            if len(counts) > PRUNE_THRESHOLD:
                counts = Counter({k: v for k, v in counts.items() if v > 1})
        if docs_processed % 50_000 < 2000:
            print(f"docs={docs_processed} uniq_compounds={len(counts)}", file=sys.stderr, flush=True)
        if docs_processed >= max_docs:
            break

    print(f"DONE docs={docs_processed} uniq_compounds={len(counts)}", file=sys.stderr, flush=True)

    rows = [(s, r, c) for (s, r), c in counts.items() if c >= MIN_COUNT]
    rows.sort(key=lambda t: -t[2])
    rows = rows[:MAX_ROWS]

    with open(out_path, "w", encoding="utf-8") as f:
        for surface, reading, c in rows:
            f.write(f"{surface}\t{reading}\t{c}\n")

    print(f"wrote {len(rows)} rows to {out_path}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()
