# conversion-gapmine — dictionary gap mining & conversion quality eval

Finds common Japanese words that `AzooKeyKanaKanjiConverter` (the keyboard's
engine) cannot convert, so they can be added to
`Sources/JapaneseKeyboardCore/Resources/conversion_gapfill.tsv` — the curated
list `KanaKanjiAdapter` builds into the converter's user dictionary
(`user.louds`) at launch. First run: July 2026, on FineWeb-2 shard
`jpn_Jpan/train/000_00000.parquet` (500k docs) — results in `REPORT.md`
(top-400 triage) and `TAIL_REPORT.md` (remaining 1,294). Outcome: the TSV grew
from 3 hand-verified entries to 617.

Second run: July 2026, using the NWJC 2022 short-unit frequency list for
ordinary vocabulary and `Seo-4d696b75/station_database` for active station
names. The real converter was missing 24 of 15,134 frequent NWJC lexical
candidates, but manual checking rejected 23 as source-reading errors, unusual
variants, or verbs that cannot safely be installed by the current noun-only
gap-fill loader. `冠婚` was accepted. Of 8,478 active kanji station
name/reading pairs, 2,524 bare names were absent; 27 useful interchange and
unusual-reading names were conservatively accepted after installed-dictionary
and regression probes. See `ROUND2_REPORT.md`.

Third run: July 2026, using a different FineWeb-2 shard and overlapping noun
windows, plus Japanese Wikipedia traffic/redirects as a proper-name and station
popularity signal. Of 50,000 corpus compounds, 4,948 were absent and 168 ranked
below the top ten. Sudachi Full + JMdict agreement, manual fragment/orthography
review, and candidate-collision probes reduced these to 134 safe corpus fixes.
The NWJC low-ranked tail contributed five common words, Wikipedia one verified
proper name, and Wikipedia-ranked station data two station names. See
`ROUND3_REPORT.md`.

## The loop

```bash
python3 -m venv venv && venv/bin/pip install fugashi ipadic pyarrow

# 1. corpus shard (~4.8 GB; use a different shard than 000_00000 for new words)
curl -sL -o fineweb2-ja.parquet "https://huggingface.co/datasets/HuggingFaceFW/fineweb-2/resolve/main/data/jpn_Jpan/train/000_00000.parquet"

# 2. extract overlapping frequent 2-4 morpheme noun compounds (~15 min)
venv/bin/python extract_compounds_v2.py fineweb2-ja.parquet compounds.tsv 500000

# 3. run every compound through the real converter (~90 min for 30k rows)
cd ConvProbe && swift run -c release ConvProbe ../compounds.tsv 2>/dev/null | grep '^GAPRESULT' > ../ranks.tsv

# 4. triage: ABSENT rows are gap candidates
python3 triage.py   # splits into fine / poorly_ranked / absent

# 5. verify candidates + regressions WITH the dictionary installed
#    (second arg = a gapfill TSV in reading<TAB>word format)
cd ConvProbe && swift run -c release ConvProbe ../candidates.tsv ../final_gapfill.tsv
cd ConvProbe && swift run -c release ConvProbe ../regressions.tsv ../final_gapfill.tsv
```

The reproducible production-oriented NWJC import is noun-only, matching the
loader's CID:

```bash
python3 import_nwjc.py NWJC_frequencylist_suw_ver2022_02.tsv nwjc.tsv
cd ConvProbe && swift run -c release ConvProbe ../nwjc.tsv > ../nwjc-ranks.tsv
```

## Station-name pass

The station importer uses the nationwide `station.json` from
[`station_database`](https://github.com/Seo-4d696b75/station_database) (CC BY
4.0). Its `lines` arrays provide a rough interchange/reach priority only; they
are not passenger counts. MLIT N02 station data and SudachiDict were used as
independent surface/reading checks during curation.

```bash
curl -sL -o station.json \
  https://raw.githubusercontent.com/Seo-4d696b75/station_database/main/out/main/station.json
python3 import_station_database.py station.json stations

cd ConvProbe
swift run -c release ConvProbe ../stations-names.tsv > ../station-ranks.tsv
cd ..
python3 triage.py station-ranks.tsv
```

Wikipedia redirects are aliases, not pronunciation data. A kana redirect is
usable only when its reading exactly agrees with Sudachi; the page-view total
is a popularity signal, not reading evidence:

```bash
python3 import_wikipedia_pageviews.py 2026-06-01 30 popular.tsv \
  small_lex.csv core_lex.csv notcore_lex.csv --raw-output raw-pageviews.tsv
python3 import_wikipedia_redirects.py page.sql.gz redirect.sql.gz \
  raw-pageviews.tsv wikipedia.tsv small_lex.csv core_lex.csv notcore_lex.csv
python3 rank_station_pageviews.py stations-names.tsv raw-pageviews.tsv \
  popular-stations.tsv
```

Always probe bare names and `stations-with-eki.tsv` separately. Never bulk-add
station gaps: the dictionary value is high enough that `相老 / アイオイ`, for
example, can displace the more common `相生`. Prefer a curated bare name when
its existing candidates are clearly wrong; otherwise the full `○○駅` form is
the safer fallback. `CONVPROBE_SHOW_CANDIDATES=1` prints the existing top ten
for absent rows so those collisions can be inspected.

`ConvProbe` reads `surface<TAB>reading(katakana)<TAB>count` lines and prints
`GAPRESULT<TAB>surface<TAB>reading<TAB>count<TAB>rank|ABSENT` (rank = position
in the top-20 `mainResults`). With a second argument it first builds that
gap-fill TSV into a user dictionary, exactly as the app does.

## Vetting rules (every one of these was learned the hard way — see reports)

1. **Never trust a mined reading.** Readings are per-morpheme IPADIC
   concatenations and are wrong for ~70% of ABSENT hits: on/kun swaps
   (光回線=ヒカリカイセン not コウ—, 痛車=イタシャ, 骨董市=コットウイチ),
   rendaku (収納棚=—ダナ, 週払い=—バライ). **Re-probe the corrected reading
   first** — in both mining rounds, most "gaps" converted fine once the
   reading was fixed, and only genuinely-ABSENT corrected readings were added.
2. **Check reading collisions.** Gap-fill entries convert at high priority
   (value -9), so an entry whose reading matches a more common word hijacks
   it: 円買い would beat 宴会, 報連相 would beat ほうれん草. Drop these, and
   add the protected word to `regressions.tsv`.
3. **Reject typo surfaces** the web writes but a keyboard must not teach:
   年棒(→年俸), 興味深々(→興味津々), 身分証明証(→書), 店鋪(→店舗),
   世界保健機構(→機関).
4. **Reject fragments** created by the extraction design: number-word heads
   are stripped (歳未満, 個単位, 〜等 boilerplate) — a user never types these
   standalone.
5. **Skip compounds that compose from other entries.** User-dictionary words
   are full lattice citizens, so once 血行促進 is an entry, 血行促進効果
   converts by composition — no separate entry needed.
6. Final gate, both directions: every entry rank ≤3 with the dictionary
   installed; every regression word unaffected. Then run
   `JapaneseKeyboardCoreTests/KanaKanjiAdapterTests` (via xcodebuild, iOS sim).

## Files

| File | What |
|---|---|
| `extract_compounds.py` | parquet → `compounds.tsv` (MeCab/IPADIC via fugashi) |
| `extract_compounds_v2.py` | overlapping 2–4 noun windows from a new parquet shard |
| `import_nwjc.py` | NWJC short-unit vocabulary → noun-only probe TSV |
| `import_station_database.py` | active `station.json` → bare-name and `○○駅` probe TSVs |
| `import_wikipedia_pageviews.py` | aggregate Japanese Wikipedia top-page traffic |
| `import_wikipedia_redirects.py` | popular kana redirects, exact-checked with Sudachi |
| `rank_station_pageviews.py` | rank authoritative station pairs by article traffic |
| `audit_gapfill_readings.py` | compare candidate readings with Sudachi CSVs |
| `audit_gapfill_jmdict.py` | compare candidate readings with JMdict |
| `audit_gapfill_sudachipy.py` | tokenized full-Sudachi reading audit |
| `ConvProbe/` | batch converter checker (SPM, macOS, upstream azooKey 0.11.2) |
| `triage.py` | splits `ranks.tsv` by rank bucket |
| `regressions.tsv` | collision-guard words — grow this whenever rule 2 fires |
| `REPORT.md`, `TAIL_REPORT.md` | July 2026 run: methodology, findings, anomaly catalog |
| `ROUND2_REPORT.md` | NWJC + station-name run, rejection reasons, accepted additions |
| `ROUND3_REPORT.md` | second corpus shard + Wikipedia validation and accepted counts |
| `compounds.tsv.gz`, `ranks.tsv.gz` | July 2026 raw data (reproduction / diffing future runs) |

Related: `docs/` has nothing on this yet; the authoritative explanation of how
the gap-fill dictionary is loaded lives in `KanaKanjiAdapter.swift` comments.
