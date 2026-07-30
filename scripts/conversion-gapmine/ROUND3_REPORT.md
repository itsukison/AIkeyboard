# Conversion gap mining — second corpus + Wikipedia

Run: July 2026. Converter: the pinned release `ConvProbe` build, classical
mode, top 20 candidates. Production gap-fill baseline after the reading audit:
629 entries.

## Sources and safeguards

- FineWeb-2 Japanese shard `jpn_Jpan/train/000_00001.parquet`: a different
  500,000-document sample from round one.
- SudachiDict Full and JMdict: independent reading checks. Neither source alone
  was treated as proof that a mined phrase was a useful keyboard entry.
- Japanese Wikipedia top-page traffic: popularity only.
- Japanese Wikipedia kana redirects: accepted as reading evidence only when an
  exact Sudachi surface/reading pair independently agreed.
- `station_database`: authoritative station surface/readings; Wikipedia traffic
  only prioritized which station gaps to inspect.

Wikipedia redirects include nicknames and aliases. Treating every kana redirect
as a pronunciation produced obviously wrong pairs, so the exact Sudachi gate is
mandatory.

## Second FineWeb-2 shard

`extract_compounds_v2.py` extracts overlapping 2–4 noun windows. This fixes the
first extractor's tendency to keep only maximal, non-overlapping runs, but the
IPADIC readings still require independent validation.

| Result | Count |
|---|---:|
| Documents | 500,000 |
| Probed compounds | 50,000 |
| Rank 1–10 | 44,884 |
| Rank >10 | 168 |
| Absent | 4,948 |

All 5,116 non-fine rows were reviewed. The automated audit found 1,683 reading
mismatches, 459 extraction fragments, 302 short/collision risks, 537 surfaces
already covered by the production gap-fill, 38 usable existing top-20 results,
1,438 unverified rows, and 482 long names/terms held for future source-specific
checking. Sudachi + JMdict agreed exactly on 177 absent candidates.

Manual completeness, standard-spelling, noun-CID, and collision review accepted
116 of those absent pairs. Eighteen additional correctly read common terms from
the low-ranked bucket were promoted. Examples include `連帯保証`, `脊柱管`,
`口腔外科`, `回帰分析`, `色移り`, and `仲卸`.

Entries were rejected even with correct readings when a value of `-9` would
steal a common conversion: `休薬 / 旧約`, `配水管 / 排水管`, `施政方針 /
市政方針`, and `交歓会 / 交換会`. Nonstandard or secondary spellings such as
`シミ抜き` and `切干大根` were also not promoted.

## NWJC tail, Wikipedia names, and stations

- Full review of the 967 low-ranked NWJC rows produced six plausible common
  nouns. Five were accepted: `発毛`, `連中`, `玩具`, `金運`, `図形`.
  `前号` was rejected because forcing it over `全豪` is not safe.
- 30 days of Japanese Wikipedia top-page traffic produced 40 popular
  surface/readings after the redirect + Sudachi agreement gate. Thirty-six
  already ranked in the top ten, three low-ranked names were spelling/name
  collisions, and `洪明甫` was genuinely absent and accepted.
- Seven station articles reached the traffic shortlist. `上鳥羽口` and
  `岐阜羽島` were absent, had authoritative station readings, and were accepted.

## Outcome and verification

| Addition source | Accepted |
|---|---:|
| FineWeb-2 absent | 116 |
| FineWeb-2 low-ranked | 18 |
| NWJC low-ranked tail | 5 |
| Wikipedia proper name | 1 |
| Wikipedia-ranked stations | 2 |
| **Total** | **142** |

The production TSV now contains 771 entries. All 142 additions rank first with
the complete installed dictionary. `regressions.tsv` produces byte-for-byte
identical results before and after installation. The focused production
`KanaKanjiAdapterTests` cover a corrected first-round reading, a promoted
low-ranked word, and a newly accepted station.

The TSV is bundled into the keyboard extension. No converter-code or backend
deployment is needed, but users receive these conversions only in an app build
that contains the updated resource.
