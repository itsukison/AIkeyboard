# Conversion gap mining — NWJC + station names

Run: July 2026. Converter: the pinned `ConvProbe` build using the same
AzooKey default dictionary and gap-fill dictionary settings as the app.

## Sources

- National Institute for Japanese Language and Linguistics (2022),
  *NWJC Chuunagon vocabulary list version 2022.02*, CC BY 4.0:
  <https://repository.ninjal.ac.jp/records/3683>
- `Seo-4d696b75/station_database`, nationwide active station names, readings,
  and line membership, CC BY 4.0:
  <https://github.com/Seo-4d696b75/station_database>
- MLIT National Land Numerical Information N02 railway data and SudachiDict
  Full were used as independent station-surface and reading checks during
  curation. They are not bundled with the app.

`station_database.lines.count` is only an interchange/reach signal. It is not
ridership and must not be described as popularity.

## NWJC result

The pass selected kanji-bearing common nouns, verbs, and adjectives with
frequency at least 100, excluding proper-name categories.

| Result | Count |
|---|---:|
| Probed | 15,134 |
| Rank 1–10 | 14,143 |
| Rank >10 | 967 |
| Absent | 24 |
| Accepted | 1 |

Accepted: `カンコン → 冠婚`.

The other 23 absent rows were not safe dictionary additions. Several had an
incorrect or misleading source analysis (`元彼 / モトカノ`, `打ち明ける /
ブチアケル`); others were uncommon spellings/readings (`鬘 / ズラ`) or
verbs. The app currently exports every gap-fill row with the general-noun CID,
so adding inflecting words would encode the wrong part of speech and can damage
lattice composition. The 967 low-ranked rows were likewise not bulk-promoted:
most were already available variants, single-kanji readings, or ordinary words
whose high-priority promotion would create regressions.

## Station result

The importer produced 8,478 unique active kanji-bearing station
surface/reading pairs.

| Probe | Absent | Rank >10 | Rank 1–10 |
|---|---:|---:|---:|
| Bare station name | 2,524 | 328 | 5,626 |
| Full `○○駅` form | 2,869 | 1 | 5,608 |

A bulk station dictionary was rejected. Gap-fill entries use value `-9`, so a
rare station can outrank an ordinary word or a better-known homophonic station.
For example, promoting `相老 / アイオイ` can displace `相生`.

The accepted shortlist is restricted to active, useful interchange or
unusual-reading names with clean surfaces. Existing top-ten candidates were
inspected, exact readings did not collide with the existing gap-fill or
regression sets, all 27 were absent before installation, and all ranked first
after installation.

| Reading | Accepted surface |
|---|---|
| タカハタフドウ | 高幡不動 |
| キンシチョウ | 錦糸町 |
| シロカネタカナワ | 白金高輪 |
| ナガレヤマオオタカノモリ | 流山おおたかの森 |
| シンハクシマ | 新白島 |
| チクゴフナゴヤ | 筑後船小屋 |
| ツバメサンジョウ | 燕三条 |
| アラタマバシ | 新瑞橋 |
| シンジョハラ | 新所原 |
| シンアンジョウ | 新安城 |
| カワニシノセグチ | 川西能勢口 |
| ブバイガワラ | 分倍河原 |
| サクダイラ | 佐久平 |
| ケイセイウエノ | 京成上野 |
| ヒサヤオオドオリ | 久屋大通 |
| カミオタイ | 上小田井 |
| カミマエヅ | 上前津 |
| ミカワアンジョウ | 三河安城 |
| ヤマトヤギ | 大和八木 |
| エチゼンハナンドウ | 越前花堂 |
| キブカワ | 貴生川 |
| カイタイチ | 海田市 |
| カタビラノツジ | 帷子ノ辻 |
| タイシバシイマイチ | 太子橋今市 |
| オクツガルイマベツ | 奥津軽いまべつ |
| オオエヤマグチナイク | 大江山口内宮 |
| インバニホンイダイ | 印旛日本医大 |

## Verification

- Proposed additions: 28/28 ranked first with the full installed dictionary.
- Existing `regressions.tsv`: byte-for-byte identical probe output before and
  after these additions. (`いちご狩り` remains the pre-existing rank-13
  baseline; this round did not change it.)
- Focused unit coverage was added for `錦糸町` and `冠婚` through the production
  `KanaKanjiAdapter` resource-loading path.

The TSV is compiled into the keyboard extension bundle. No converter code or
server deployment is needed, but users receive the new conversions only after
installing an app build that contains the updated resource.
