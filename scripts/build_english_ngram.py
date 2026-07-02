#!/usr/bin/env python3
"""Build the English unigram + bigram tables for the English keyboard mode.

Inputs (Peter Norvig's frequency data, https://norvig.com/ngrams/):
  count_1w.txt : "word\\tcount"        (top ~1/3M words by frequency)
  count_2w.txt : "word1 word2\\tcount"  (top ~1/4M bigrams)

Outputs (NWP1 format, identical to scripts/build_nextword_prior.py so the same
mmap'd `NextWordPrior` reader loads them):
  english_unigram.bin : key=word, value=(empty next, freq weight). Keys sorted by
                        UTF-8 bytes -> enables `completions(prefix:)` prefix scan
                        and `weight(for:)` exact lookup.
  english_bigram.bin  : key=word1, value=top-K next words by frequency.

Usage:
  curl -O https://norvig.com/ngrams/count_1w.txt
  curl -O https://norvig.com/ngrams/count_2w.txt
  python3 scripts/build_english_ngram.py count_1w.txt count_2w.txt \\
      Sources/JapaneseKeyboardCore/Resources/

FORMAT (little-endian):
  magic   : 4 bytes  b"NWP1"
  keyCount: uint32
  index   : keyCount * 12 bytes, each: keyOff:uint32 keyLen:uint16 valOff:uint32 valLen:uint16
  keysBlob: concatenated key UTF-8
  valsBlob: per key, repeated: nextLen:uint8, next UTF-8, weight:uint8
"""
import sys, os, struct, math

MAX_VOCAB = 60_000   # words kept for completion + correction vocabulary
TOP_K = 8            # next words kept per bigram key
MIN_LEN = 1
MAX_LEN = 20


def is_word(w: str) -> bool:
    return MIN_LEN <= len(w) <= MAX_LEN and w.isascii() and w.isalpha()


def quantize(count: int, max_count: int) -> int:
    # Relative-log scale: spreads frequencies across the full 1..255 byte range
    # instead of saturating, so completion ranking keeps useful resolution.
    if count <= 0:
        return 1
    return max(1, min(255, int(round(255 * math.log(count + 1) / math.log(max_count + 1)))))


def write_nwp1(path: str, items):
    """items: list of (key_str, [(next_str, weight_int), ...]); will be sorted by key UTF-8."""
    items = sorted(((k.encode("utf-8"), vals) for k, vals in items), key=lambda x: x[0])

    keys_blob = bytearray()
    vals_blob = bytearray()
    key_meta = []   # (keyOff, keyLen)
    val_meta = []   # valLen
    for kb, vals in items:
        key_meta.append((len(keys_blob), len(kb)))
        keys_blob += kb
        start = len(vals_blob)
        for nxt, w in vals:
            eb = nxt.encode("utf-8")
            vals_blob += struct.pack("<B", len(eb)) + eb + struct.pack("<B", w)
        val_meta.append(len(vals_blob) - start)

    header = b"NWP1" + struct.pack("<I", len(items))
    index_size = len(items) * 12
    keys_base = len(header) + index_size
    vals_base = keys_base + len(keys_blob)

    index = bytearray()
    voff = 0
    for (koff, klen), vlen in zip(key_meta, val_meta):
        index += struct.pack("<IHIH", keys_base + koff, klen, vals_base + voff, vlen)
        voff += vlen

    with open(path, "wb") as f:
        f.write(header)
        f.write(index)
        f.write(keys_blob)
        f.write(vals_blob)

    total = len(header) + len(index) + len(keys_blob) + len(vals_blob)
    sys.stderr.write(f"{os.path.basename(path)}: keys={len(items)} size={total/1e6:.2f}MB\n")


def load_unigrams(path):
    counts = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            tab = line.rfind("\t")
            if tab < 0:
                continue
            w = line[:tab].strip().lower()
            if not is_word(w):
                continue
            try:
                counts[w] = int(line[tab + 1:])
            except ValueError:
                continue
    top = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)[:MAX_VOCAB]
    return dict(top)


def main():
    uni_path, bi_path, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]

    vocab = load_unigrams(uni_path)
    max_count = max(vocab.values())

    # Unigram table: word -> single (empty-next, weight) entry.
    uni_items = [(w, [("", quantize(c, max_count))]) for w, c in vocab.items()]
    write_nwp1(os.path.join(out_dir, "english_unigram.bin"), uni_items)

    # Bigram table: word1 -> top-K next words (both in vocabulary).
    nexts = {}   # word1 -> list[(count, word2)]
    with open(bi_path, encoding="utf-8", errors="replace") as f:
        for line in f:
            tab = line.rfind("\t")
            if tab < 0:
                continue
            toks = line[:tab].split(" ")
            if len(toks) != 2:
                continue
            w1, w2 = toks[0].strip().lower(), toks[1].strip().lower()
            if w1 not in vocab or w2 not in vocab:
                continue
            try:
                c = int(line[tab + 1:])
            except ValueError:
                continue
            nexts.setdefault(w1, []).append((c, w2))

    bi_items = []
    for w1, lst in nexts.items():
        lst.sort(reverse=True)
        top = lst[:TOP_K]
        bmax = top[0][0]
        bi_items.append((w1, [(w2, quantize(c, bmax)) for c, w2 in top]))
    write_nwp1(os.path.join(out_dir, "english_bigram.bin"), bi_items)


if __name__ == "__main__":
    main()
