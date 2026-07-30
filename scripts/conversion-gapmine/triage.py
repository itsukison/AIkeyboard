#!/usr/bin/env python3
"""Split ranks.tsv (surface, reading, count, rank) into buckets:
ABSENT (sorted desc by count), rank>10, rank<=10.

Usage: triage.py <ranks.tsv>
Writes: absent.tsv, poorly_ranked.tsv, fine.tsv into the same directory.
"""
import os
import sys

def main():
    path = sys.argv[1]
    out_dir = os.path.dirname(os.path.abspath(path))

    absent = []
    poor = []
    fine = []

    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) == 5 and parts[0] == "GAPRESULT":
                parts = parts[1:]
            if len(parts) != 4:
                continue
            surface, reading, count, rank = parts
            try:
                count_i = int(count)
            except ValueError:
                continue
            if rank == "ABSENT":
                absent.append((surface, reading, count_i))
            else:
                rank_i = int(rank)
                if rank_i > 10:
                    poor.append((surface, reading, count_i, rank_i))
                else:
                    fine.append((surface, reading, count_i, rank_i))

    absent.sort(key=lambda t: -t[2])
    poor.sort(key=lambda t: -t[2])
    fine.sort(key=lambda t: -t[2])

    with open(os.path.join(out_dir, "absent.tsv"), "w", encoding="utf-8") as f:
        for surface, reading, count in absent:
            f.write(f"{surface}\t{reading}\t{count}\n")
    with open(os.path.join(out_dir, "poorly_ranked.tsv"), "w", encoding="utf-8") as f:
        for surface, reading, count, rank in poor:
            f.write(f"{surface}\t{reading}\t{count}\t{rank}\n")
    with open(os.path.join(out_dir, "fine.tsv"), "w", encoding="utf-8") as f:
        for surface, reading, count, rank in fine:
            f.write(f"{surface}\t{reading}\t{count}\t{rank}\n")

    print(f"ABSENT: {len(absent)}")
    print(f"rank>10: {len(poor)}")
    print(f"rank<=10: {len(fine)}")

if __name__ == "__main__":
    main()
