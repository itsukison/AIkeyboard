# scripts

## build_nextword_prior.py — next-word prior table

Builds `Sources/JapaneseKeyboardCore/Resources/nextword_prior.bin`, the
memory-mapped morpheme → next-morpheme table read by `NextWordPrior` to seed the
prediction bar (see `docs/` and `KanaKanjiAdapter.predictNextWords`).

### Data source

[日本語ウェブコーパス2010 (NWC2010)](https://www.s-yata.jp/corpus/nwc2010/ngrams/)
morpheme (word) 2-grams. Web-domain, word-segmented. The author states terms are
"特にありません。二次配布も自由です" — no restrictions, redistribution (incl.
commercial / derivatives) allowed. The shipped `.bin` is a derived frequency
table, not the corpus text.

### Rebuild

```bash
# freq>=100 tier, 2-gram, both shards (sorted as one stream):
BASE=https://s3-ap-northeast-1.amazonaws.com/nwc2010-ngrams/word/over99/2gms
curl -s "$BASE/2gm-0000.xz" -o 2gm-0000.xz
curl -s "$BASE/2gm-0001.xz" -o 2gm-0001.xz
xz -dc 2gm-0000.xz 2gm-0001.xz | python3 build_nextword_prior.py \
    ../Sources/JapaneseKeyboardCore/Resources/nextword_prior.bin
```

Current artifact: ~9.8 MB, 150k morphemes × up to 8 next-words. Tune `TOP_K` /
`MAX_KEYS` in the script to trade coverage against size. Other tiers: `over999`
(freq>=1000, smaller) or `over9` (freq>=10, much larger).

## build_nextword_trigram.py — next-word trigram prior

Builds `Sources/JapaneseKeyboardCore/Resources/nextword_trigram.bin`, the
sibling trigram table: a morpheme *pair* `(t1, t2)` → likely third morpheme
`t3`. Same `NWP1` binary format as the bigram table, keyed on `t1<U+001F>t2`.
`NextWordPrior.sharedTrigram` reads it and `KanaKanjiAdapter.predictNextWords`
tries it first (sharper context), backing off to the bigram table on a miss —
so the keyboard works unchanged if this `.bin` is absent.

### Data source

Same [NWC2010](https://www.s-yata.jp/corpus/nwc2010/ngrams/) word n-grams, but
the **3-gram** files. Same unrestricted license as the 2-grams.

### Rebuild

```bash
# freq>=100 tier, 3-gram, all shards (sorted as one stream):
BASE=https://s3-ap-northeast-1.amazonaws.com/nwc2010-ngrams/word/over99/3gms
for i in $(seq -w 0 N); do curl -s "$BASE/3gm-000$i.xz" -o "3gm-000$i.xz"; done
xz -dc 3gm-*.xz | python3 build_nextword_trigram.py \
    ../Sources/JapaneseKeyboardCore/Resources/nextword_trigram.bin
```

Trigram keys are far more numerous than bigram, so this `.bin` is larger for the
same `TOP_K`. It is mmap'd (resident memory stays flat — no jetsam risk), but it
adds to the app download size. Lower `MAX_KEYS` / `TOP_K`, or use the `over999`
tier, if the bundle grows too much.
