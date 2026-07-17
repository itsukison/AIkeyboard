#!/usr/bin/env python3
"""Tokenize a FineWeb-2 parquet shard with MeCab/IPADIC and emit partial
bigram/trigram counts as sorted part files.

Each worker chunk accumulates Counters, then writes them sorted as
"t1 t2\tcount" / "t1 t2 t3\tcount" part files. Merge afterwards with:

  LC_ALL=C sort -m parts/bi_*.txt | python3 sum_adjacent.py | build_nextword_prior.py ...

Usage: emit_ngram_counts.py <shard.parquet> <parts_dir> [max_docs]
"""
import os
import sys
from collections import Counter
from multiprocessing import Pool

import pyarrow.parquet as pq

TAGGER = None
MAX_TOKEN_BYTES = 60  # NWP1 stores next-token length in a uint8; keys in uint16


def init_worker():
    global TAGGER
    import fugashi, ipadic
    TAGGER = fugashi.GenericTagger(ipadic.MECAB_ARGS + " -Owakati")


def ok_token(tok: str) -> bool:
    if not tok or len(tok.encode("utf-8")) > MAX_TOKEN_BYTES:
        return False
    return "\t" not in tok and "\x1f" not in tok


def process_chunk(args):
    idx, texts, parts_dir = args
    bi = Counter()
    tri = Counter()
    n_tokens = 0
    for text in texts:
        for line in text.split("\n"):
            line = line.strip()
            if len(line) < 2:
                continue
            toks = [t for t in TAGGER.parse(line).split(" ") if ok_token(t)]
            n_tokens += len(toks)
            for i in range(len(toks) - 1):
                bi[toks[i] + " " + toks[i + 1]] += 1
            for i in range(len(toks) - 2):
                tri[toks[i] + " " + toks[i + 1] + " " + toks[i + 2]] += 1
    for name, counter in (("bi", bi), ("tri", tri)):
        path = os.path.join(parts_dir, f"{name}_{idx:06d}.txt")
        with open(path, "w", encoding="utf-8") as f:
            for key in sorted(counter):
                f.write(f"{key}\t{counter[key]}\n")
    return len(texts), n_tokens


def batches(parquet_path, docs_per_chunk, max_docs):
    pf = pq.ParquetFile(parquet_path)
    idx = 0
    served = 0
    for batch in pf.iter_batches(batch_size=docs_per_chunk, columns=["text"]):
        texts = batch.column("text").to_pylist()
        if max_docs and served + len(texts) > max_docs:
            texts = texts[: max_docs - served]
        if not texts:
            return
        served += len(texts)
        yield (idx, texts)
        idx += 1
        if max_docs and served >= max_docs:
            return


def main():
    shard = sys.argv[1]
    parts_dir = sys.argv[2]
    max_docs = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    os.makedirs(parts_dir, exist_ok=True)
    total_docs = 0
    total_tokens = 0
    with Pool(processes=8, initializer=init_worker) as pool:
        args = ((i, t, parts_dir) for i, t in batches(shard, 2000, max_docs))
        for n_docs, n_tokens in pool.imap_unordered(process_chunk, args, chunksize=1):
            total_docs += n_docs
            total_tokens += n_tokens
            if total_docs % 50_000 < 2000:
                print(f"docs={total_docs} tokens={total_tokens}", file=sys.stderr, flush=True)
    print(f"DONE docs={total_docs} tokens={total_tokens}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    main()
