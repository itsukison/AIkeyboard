#!/usr/bin/env python3
"""Sum counts of adjacent equal keys from a merge-sorted "key\tcount" stream,
emitting "key\ttotal" — the input format build_nextword_prior.py /
build_nextword_trigram.py expect.
"""
import sys

cur_key = None
cur_sum = 0
out = sys.stdout
for line in sys.stdin:
    line = line.rstrip("\n")
    tab = line.rfind("\t")
    if tab < 0:
        continue
    key, count_s = line[:tab], line[tab + 1 :]
    try:
        count = int(count_s)
    except ValueError:
        continue
    if key == cur_key:
        cur_sum += count
    else:
        if cur_key is not None:
            out.write(f"{cur_key}\t{cur_sum}\n")
        cur_key = key
        cur_sum = count
if cur_key is not None:
    out.write(f"{cur_key}\t{cur_sum}\n")
