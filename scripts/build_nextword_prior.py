#!/usr/bin/env python3
"""Build the next-word prior table from NWC2010 word 2-grams.

Input: stdin = decompressed NWC2010 word 2-gram stream ("t1 t2\tfreq" per line,
       sorted lexicographically by "t1 t2" so each t1 forms a contiguous block).
Output: a compact binary file (see FORMAT) keyed by the morpheme t1.

FORMAT (little-endian):
  magic   : 4 bytes  b"NWP1"
  keyCount: uint32
  index   : keyCount * 12 bytes, each: keyOff:uint32 keyLen:uint16 valOff:uint32 valLen:uint16
            (offsets are absolute file offsets; keys sorted by UTF-8 bytes for binary search)
  keysBlob: concatenated key UTF-8
  valsBlob: per key, repeated entries: nextLen:uint8, next UTF-8, weight:uint8
"""
import sys, heapq, struct, math, io

TOP_K = 8           # next-words kept per morpheme
MAX_KEYS = 150_000  # morphemes kept (top by total frequency)
BOUNDARY = {"<S>", "</S>", "<s>", "</s>"}
ALLOWED_PUNCT = {"。", "、", "！", "？", "」", "』", "）", "…", "ー"}

def has_jp(s: str) -> bool:
    for ch in s:
        o = ord(ch)
        if 0x3040 <= o <= 0x30FF or 0x4E00 <= o <= 0x9FFF or 0x3005 <= o <= 0x3007:
            return True
    return False

def keep_next(t2: str) -> bool:
    if t2 in BOUNDARY:
        return False
    return has_jp(t2) or t2 in ALLOWED_PUNCT

def quantize(freq: int) -> int:
    return max(1, min(255, int(round(math.log10(freq + 1) * 30))))

def flush(cur_key, nexts, kept):
    """nexts: list[(freq,t2)]. Keep top-K, push (total, key, entries) into kept heap."""
    if not nexts:
        return
    top = heapq.nlargest(TOP_K, nexts)            # by freq desc
    total = sum(f for f, _ in top)
    entries = [(t2, quantize(f)) for f, t2 in top]
    if len(kept) < MAX_KEYS:
        heapq.heappush(kept, (total, cur_key, entries))
    elif total > kept[0][0]:
        heapq.heapreplace(kept, (total, cur_key, entries))

def main():
    out_path = sys.argv[1]
    inp = io.TextIOWrapper(sys.stdin.buffer, encoding="utf-8", errors="replace")
    kept = []           # min-heap of (total, key, entries)
    cur_key = None
    nexts = []
    lines = 0
    for line in inp:
        lines += 1
        line = line.rstrip("\n")
        tab = line.rfind("\t")
        if tab < 0:
            continue
        tokens, freq_s = line[:tab], line[tab + 1:]
        sp = tokens.find(" ")
        if sp < 0:
            continue
        t1, t2 = tokens[:sp], tokens[sp + 1:]
        if not t1 or not t2 or " " in t2:
            continue
        if not has_jp(t1):
            continue
        if not keep_next(t2):
            continue
        try:
            freq = int(freq_s)
        except ValueError:
            continue
        if t1 != cur_key:
            flush(cur_key, nexts, kept)
            cur_key, nexts = t1, []
        nexts.append((freq, t2))
    flush(cur_key, nexts, kept)

    # Sort kept keys by UTF-8 bytes for binary search at runtime.
    items = sorted(((k.encode("utf-8"), entries) for _, k, entries in kept), key=lambda x: x[0])

    keys_blob = bytearray()
    vals_blob = bytearray()
    val_meta = []   # (valLen,) per key, in order
    key_meta = []   # (keyOff, keyLen)
    for kb, entries in items:
        key_meta.append((len(keys_blob), len(kb)))
        keys_blob += kb
        start = len(vals_blob)
        for t2, w in entries:
            eb = t2.encode("utf-8")
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

    with open(out_path, "wb") as f:
        f.write(header)
        f.write(index)
        f.write(keys_blob)
        f.write(vals_blob)

    total_bytes = len(header) + len(index) + len(keys_blob) + len(vals_blob)
    sys.stderr.write(
        f"lines={lines} keys={len(items)} "
        f"size={total_bytes/1e6:.2f}MB (index={index_size/1e6:.2f} keys={len(keys_blob)/1e6:.2f} vals={len(vals_blob)/1e6:.2f})\n"
    )

if __name__ == "__main__":
    main()
