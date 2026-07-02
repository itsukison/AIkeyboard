# scripts

## Next-word prior tables (bigram + trigram)

`build_nextword_prior.py` builds
`Sources/JapaneseKeyboardCore/Resources/nextword_prior.bin`, the memory-mapped
morpheme → next-morpheme table read by `NextWordPrior` to seed the prediction
bar (see `KanaKanjiAdapter.predictNextWords`).

`build_nextword_trigram.py` builds the sibling
`Sources/JapaneseKeyboardCore/Resources/nextword_trigram.bin`: a morpheme
*pair* `(t1, t2)` → likely third morpheme `t3`, same `NWP1` binary format,
keyed on `t1<U+001F>t2`. `NextWordPrior.sharedTrigram` reads it and
`KanaKanjiAdapter.predictNextWords` tries it first (sharper context), backing
off to the bigram table on a miss — so the keyboard works unchanged if this
`.bin` is absent.

Both builders consume the same input format on stdin: `tokens<TAB>freq` per
line, sorted lexicographically by the token string so each key forms a
contiguous block.

### Data source (current artifacts, July 2026)

[FineWeb-2](https://huggingface.co/datasets/HuggingFaceFW/fineweb-2)
`jpn_Jpan/train` shard `000_00000.parquet` (~2.76M documents, ~2.19B morphemes
after tokenization; 2013–2024 CommonCrawl, dedup + quality filtered).
License: ODC-By 1.0 (attribution — cite the FineWeb-2 dataset) subject to the
CommonCrawl terms of use. The shipped `.bin` is a derived frequency table, not
the corpus text.

Tokenization: MeCab/IPADIC via `fugashi` + `ipadic` (pip), wakati output —
IPAdic segmentation matches the IME-style morpheme units the tables are keyed
on (食べ/たい, not UniDic short units).

Earlier artifacts (pre-July 2026) were built from
[NWC2010](https://www.s-yata.jp/corpus/nwc2010/ngrams/) word n-grams
(unrestricted license); the corpus is from 2010, which is why it was replaced.

### Rebuild

```bash
python3 -m venv venv && venv/bin/pip install fugashi ipadic pyarrow

# 1. one FineWeb-2 Japanese shard (~4.8 GB)
curl -sL -o fineweb2-ja.parquet "https://huggingface.co/datasets/HuggingFaceFW/fineweb-2/resolve/main/data/jpn_Jpan/train/000_00000.parquet"

# 2. tokenize + emit sorted partial-count part files (~35 GB, ~15 min on 8 cores)
venv/bin/python emit_ngram_counts.py fineweb2-ja.parquet parts/

# 3. merge-sort parts, sum duplicate keys, build each table
LC_ALL=C sort -m -S 2G --batch-size=200 parts/bi_*.txt \
  | venv/bin/python sum_adjacent.py \
  | venv/bin/python build_nextword_prior.py \
      ../Sources/JapaneseKeyboardCore/Resources/nextword_prior.bin
LC_ALL=C sort -m -S 2G --batch-size=200 parts/tri_*.txt \
  | venv/bin/python sum_adjacent.py \
  | venv/bin/python build_nextword_trigram.py \
      ../Sources/JapaneseKeyboardCore/Resources/nextword_trigram.bin
```

Current artifacts: bigram ~10.8 MB (150k morphemes × up to 8 next-words, from
68M unique bigrams), trigram ~12.6 MB (200k pairs × up to 6, from 332M unique
trigrams). Tune `TOP_K` / `MAX_KEYS` in the builders to trade coverage against
size. Both are mmap'd (resident memory stays flat — no jetsam risk) but add to
the app download size.
