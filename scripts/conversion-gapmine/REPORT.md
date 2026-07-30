# Kana-Kanji Conversion Dictionary Gap Mining — Report

Engine: AzooKeyKanaKanjiConverter, classical mode (`zenzaiMode: .off`), N_best 20.
Corpus: FineWeb-2 `jpn_Jpan/train/000_00000.parquet` (CommonCrawl-derived, 2013-2024).

## Corpus stats

| Metric | Value |
|---|---|
| Documents processed | 500,000 (of ~2.76M in the shard) |
| Unique (surface, reading) compound candidates seen | 2,498,638 |
| Rows kept (count >= 20, capped) | 30,000 |
| Rows actually checked against the converter | 30,000 |

Extraction: MeCab/IPADIC (fugashi `GenericTagger`, full features, not `-Owakati`).
Candidates are maximal runs of 2-4 consecutive noun morphemes whose subclass1
is one of {一般, サ変接続, 接尾, 形容動詞語幹} (固有名詞 and 数 morphemes are
excluded, which matters a lot for interpreting the results -- see Notes).
Reading = concatenation of each morpheme's IPADIC yomi field (katakana),
4-12 chars long; surface must contain kanji and no ASCII/digits/katakana-only.

## Conversion results (all 30,000 rows)

| Bucket | Count | % |
|---|---|---|
| rank <= 10 (fine, discarded) | 28,222 | 94.1% |
| rank > 10 (poorly ranked) | 84 | 0.3% |
| ABSENT (true gap candidates) | 1,694 | 5.6% |

## Manual triage of ABSENT items

Reviewed the top 400 ABSENT items by corpus frequency (out of 1,694 total --
**1,294 items, the lower-frequency tail, were not reviewed**). Bucketed:

| Bucket | Count (of 400 reviewed) |
|---|---|
| (a) real-common-word | 119 |
| (b) proper-noun (clean) | 7 |
| (c) junk / fragment / wrong-reading | 274 |

**Extrapolation to the unreviewed tail (1,294 items):** this is a genuine
extrapolation, not a count -- I only read the head. The ~30% (a)-rate at the
head is itself inflated by frequency: the most common *generalizable*
vocabulary words surface first, and a large share of the junk (numeral/proper
noun fragments -- see Notes) is roughly frequency-independent, since it stems
from the extraction design rather than corpus rarity. I'd expect the tail's
hit rate to be lower, plausibly 10-20%, as low-frequency entries skew more
toward one-off SEO-compound spam, single-source phrase artifacts, and
increasingly obscure proper-noun fragments. That gives a rough estimate of
**130-260 additional real-word candidates** in the unreviewed 1,294, i.e. a
plausible total real-gap yield of **~250-380** across the full ABSENT set --
call it **order-of-magnitude 300**, not a precise figure. Reviewing the tail
directly would replace this estimate with a real count.

## The candidate gap list (bucket a -- reviewed, ready for human sign-off)

Format: `reading(katakana)<TAB>surface<TAB>corpus-count`, sorted by count desc.

```
ファンシンセイ	ファン申請	1777
コウカカイトリ	高価買取	1162
ビヨウコウカ	美容効果	856
シヨウジョウ	使用上	809
ケッコウフリョウ	血行不良	687
ブンカショウ	文科省	554
ケッコウソクシン	血行促進	537
シャケンショウ	車検証	534
リヨウテイシ	利用停止	517
シボウヨウカイチュウシャ	脂肪溶解注射	498
カバライキンセイキュウ	過払い金請求	484
ケンコウウン	健康運	480
ロングタケ	ロング丈	457
ジコウエンヨウ	時効援用	449
ユウリョウサイト	優良サイト	442
キュウシンビ	休診日	433
ショウカイヨテイハケン	紹介予定派遣	426
シンビシカ	審美歯科	409
リヨウカ	利用可	408
ショウヒンシヨウ	商品仕様	370
ツボタンカ	坪単価	365
シコウジレイ	施工事例	353
カイモノカゴ	買い物かご	349
ロウカゲンショウ	老化現象	343
トソウコウジ	塗装工事	332
コウナイシャセイ	口内射精	327
ショコクメイカ	諸国銘菓	325
ソウキチリョウ	早期治療	323
カードリヨウカ	カード利用可	303
チュウセイセンザイ	中性洗剤	302
ヒシマク	皮脂膜	299
テイケイガイユウビン	定形外郵便	290
センユウメンセキ	専有面積	289
キジカン	生地感	289
オンシンフツウ	音信不通	284
リヨウカンキョウ	利用環境	277
ギフトホウソウフカノウ	ギフト包装不可能	276
シジョウシャ	試乗車	273
ツイカヒヨウ	追加費用	271
アブラショウハダ	脂性肌	270
カンソウタイサク	乾燥対策	262
シコウセイ	嗜好性	261
シコウレイ	施工例	261
シンセイホウケイ	真性包茎	247
ショウニシカ	小児歯科	247
シゼンカンソウ	自然乾燥	247
セイヒンシヨウ	製品仕様	246
カソウジョウ	火葬場	243
ハイソウリョウムリョウ	配送料無料	243
カセイホウケイ	仮性包茎	236
ヒシセン	皮脂腺	233
コテイカイセン	固定回線	233
セイキュウコウ	請求項	227
チチュウノウド	血中濃度	227
ハクセンキン	白癬菌	227
ロセンカ	路線価	227
コウレイシャカイ	高齢社会	225
シヨウカンキョウ	使用環境	221
フウゾクジョウホウ	風俗情報	221
ハレツキョウセイ	歯列矯正	220
メールアドレスアテ	メールアドレス宛	216
トモダチシンセイ	友達申請	216
ハリカン	ハリ感	216
シヨウジョウケン	使用条件	215
コウジヒヨウ	工事費用	215
センタクソウ	洗濯槽	213
プロシヨウ	プロ仕様	210
セイカンマッサージ	性感マッサージ	210
ショートタケ	ショート丈	210
オープンカカク	オープン価格	209
ミツモリイライ	見積り依頼	209
ジュウタクカイシャ	住宅会社	208
ダツモウキキ	脱毛機器	208
モチュウハガキ	喪中はがき	208
レンゾクシヨウ	連続使用	207
ケイチョウキュウカ	慶弔休暇	206
コウカカ	高架下	205
キンカツ	菌活	204
リヨウキカン	利用期間	200
ヒフカイ	皮膚科医	198
ジンコウアマミリョウ	人工甘味料	198
ワキガショウ	腋臭症	197
イチモクキンコウヒョウ	一目均衡表	196
シカイリョウ	歯科医療	196
ジヨウキョウソウ	滋養強壮	195
ジヒシンリョウ	自費診療	192
シュウノウタナ	収納棚	192
チュウコシジョウ	中古市場	191
カシタンポセキニン	瑕疵担保責任	191
チュウトカイヤク	中途解約	190
チカクカビン	知覚過敏	190
コウカイジダイ	航海時代	189
ジュウクウカン	住空間	188
レーザースミダシキ	レーザー墨出し器	188
イチゴカリ	いちご狩り	187
カワコモノ	革小物	187
シロメシ	白飯	187
エホンタメシヨミサイト	絵本ためしよみサイト	187
ハイカンリョウ	拝観料	185
コウコウゲカ	口腔外科	185
シンケンコウサイ	真剣交際	184
センメンケショウダイ	洗面化粧台	182
ソウシンコウカ	痩身効果	181
ハカンブラシ	歯間ブラシ	180
フドウシャ	不動車	177
シンセンヤサイ	新鮮野菜	176
ケイザイジョウセイ	経済情勢	175
コンインヒヨウ	婚姻費用	175
キョウセイソウチ	矯正装置	174
コウタイセイ	交替制	173
パソコンチュウコカイトリ	パソコン中古買取	171
ページセントウ	ページ先頭	169
ショウカキナイカ	消化器内科	169
ヘイショ	弊所	169
ネイティブコウシ	ネイティブ講師	168
セイキツウハンテン	正規通販店	168
ヒッコシヒヨウ	引っ越し費用	166
ショウカイサイト	紹介サイト	166
ニンテイコウシ	認定講師	165
```

(119 rows. A couple -- 口内射精, 性感マッサージ -- are adult-content vocabulary
present because the corpus is unfiltered CommonCrawl; correctly read and
genuinely typed by users, but flag for the human reviewer to decide if a
general-purpose keyboard should carry them.)

## Top proper nouns (bucket b)

Only 7 survived triage as *clean* (real reading, standalone, not a fragment) --
most celebrity/brand names in the ABSENT set had mangled readings from MeCab
falling back to per-character defaults (see Notes) and were binned as junk
instead.

| reading | surface | count |
|---|---|---|
| コンゴウスジシャツ | 金剛筋シャツ | 2,922 |
| ジュウシン | 住信 | 399 |
| カジュン | 架純 | 362 |
| センヒメゼッショウ | 戦姫絶唱 | 209 |
| ユウコウイズミ | 優光泉 | 258 |
| カンムスメ | 艦娘 | 251 |
| スッポンモロミス | すっぽんもろみ酢 | 183 |

## Notes -- anomalies and converter/pipeline behavior worth knowing

**1. Reading concatenation systematically breaks on-yomi/kun-yomi selection.**
This is the single biggest cause of false gaps among genuinely common words.
IPADIC gives each morpheme its *most frequent standalone* reading, but many
kanji switch reading inside a specific compound (typically kun-yomi to
on-yomi). Naively concatenating morpheme readings then produces a reading
nobody would ever type. Examples pulled straight from the top 400 (extracted
reading -> actual reading):

- 唐揚げ: とうあげ -> からあげ
- 肩甲骨: かたこうこつ -> けんこうこつ
- 貧乳/断乳/卒乳/熟女: ちち/おんな -> にゅう/じょ (乳・女 pattern repeats constantly)
- 体脂肪率: からだしぼうりつ -> たいしぼうりつ
- 獣医師: ししいし -> じゅういし
- 縮毛矯正: ちぢみけきょうせい -> しゅくもうきょうせい
- 美白(効果/化粧品/成分/ケア): びしろ... -> びはく... (this one alone accounts for 4 of the 274 junk items)
- 生協: なまきょう -> せいきょう
- 食洗機: しょくあらいき -> しょくせんき
- 顎関節症: あごかんせつしょう -> がくかんせつしょう
- 骨粗しょう症: ほねそしょうしょう -> こつそしょうしょう
- 冷麺/内視鏡/日当たり/月会費/水栓/日中/金目鯛/駐車場代/電飾/白砂糖/黄緑色: each has the same kun/on swap in one direction or the other.
- 令和: りょうわ -> れいわ (the era name postdates this IPADIC build, so MeCab has no lexical entry and guesses character-by-character -- not really a reading bug so much as a stale-dictionary artifact; the app's converter may or may not have れいわ registered, untested here since our extracted reading was wrong).

If this project ever wants a reading-normalized second pass, the fix isn't in
the converter -- it's in how the mining reads morpheme sequences (would need a
reading-aware compound lexicon or a real furigana model, not raw IPADIC
concatenation).

**2. Rendaku (sequential voicing) is a second, smaller failure mode.**
解決済 -> extracted すみ, but usual pronunciation voices it to ずみ (かいけつずみ,
same pattern as 確認済み). 化粧下地 -> extracted したち, actual したじ. This is
exactly the failure mode the task brief called out in advance.

**3. The majority of ABSENT rows are not gaps at all -- they're extraction
artifacts, by design of the extraction rules themselves:**
- **Numeral-fragment artifacts**: rejecting subclass1=数 (as specified) means
  any phrase like "20歳未満", "3年半", "10%増", "一番人気" gets chopped to
  "歳未満", "年半", "％増", "番人気" once the leading digit/number-word is
  dropped. This alone is probably 40%+ of the 1,694 ABSENT rows -- a real user
  would never type these fragments in isolation, so they are not converter
  gaps.
- **Proper-noun-fragment artifacts**: rejecting 固有名詞 (per spec) means
  phrases like "渋谷区周辺", "所沢市在住" lose their place name, leaving
  "区周辺", "市在住", "市大字" as fragments. Same story for franchise/name
  fragments (東方神起->東方神, 一眼レフ->眼レフ, 攻殻機動隊->殻機動隊).

Both are expected consequences of the extraction spec (which deliberately
excludes numerals and proper nouns to keep the candidate pool to plain common
nouns) -- not something to "fix," just something to account for when reading
the ABSENT count. It's why the true positive rate among ABSENT items is only
~30% even in the frequency-sorted head.

**4. Fullwidth Latin letters slipped through the surface filter.** The
extraction's ASCII rejection regex only matches halfwidth [A-Za-z0-9]; it let
through ＡＶ女優, ＮＰＯ法人, 公式ＨＰ (fullwidth A,V,N,P,O,H,P). These are real
terms, but not typed in this fullwidth form in practice, so they were placed
in junk rather than the gap list. Worth patching the filter if this
extraction is rerun.

**5. Well-known celebrity/brand name readings were badly garbled** by
MeCab/IPADIC treating rare-in-context kanji with default per-character
readings: 上戸彩->じょうごいろどり (actual うえとあや), 妻夫木->つまおっとき
(actual つまぶき), 政宗->せいむね (actual まさむね), 獺祭->うそさい (actual
だっさい), 竹達彩奈->たけたちいろどり (actual たけたちあやな), 審神者->しんしんしゃ
(actual さにわ, a special reading). None of these are usable gap candidates as
extracted, but they explain why the "clean" proper-noun bucket (7 items) is so
much smaller than the raw proper-noun-shaped hits in the ABSENT list.

**6. Corpus content skew.** CommonCrawl-derived FineWeb-2 has heavy
SEO/affiliate-marketing and adult-content representation (skincare, debt
consolidation, used-car resale, adult entertainment, dating/marriage-hunting
services all appear disproportionately in the top-400). This shaped which
"real" words surfaced -- worth keeping in mind if this pipeline is reused for
a different vocabulary target.

## Reproduction

All artifacts left in place under this directory:
- `fineweb2-ja.parquet` -- the downloaded shard (4.84 GB)
- `extract_compounds.py` -- extraction script (MeCab/IPADIC via fugashi)
- `compounds.tsv` -- 30,000 extracted candidates (surface, reading, count)
- `../ConvProbeZ/Sources/ConvProbeZ/main.swift` -- rewritten batch checker
- `ranks.tsv` -- raw `GAPRESULT<TAB>surface<TAB>reading<TAB>count<TAB>rank` lines (30,000)
- `triage.py`, `absent.tsv` / `poorly_ranked.tsv` / `fine.tsv` -- triage split
- `absent_top400.tsv` -- the 400 manually reviewed in this report
