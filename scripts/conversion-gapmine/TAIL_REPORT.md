# Tail gap-mining report — absent_tail.tsv (1,294 lines, all reviewed)

## Bucket counts

| Bucket | File | Count | % of 1,294 |
|---|---|---|---|
| (a) real-common-word | tail_accepted.tsv | 579 | 44.7% |
| (d) real-word-wrong-reading | tail_corrected.tsv | 131 | 10.1% |
| (b) proper-noun | tail_propernouns.tsv | 17 | 1.3% |
| (c) junk | (not emitted) | 567 | 43.8% |

Total accepted for dictionary work (a+b+d): 727 rows.

## Methodology

Read all 1,294 lines in the source file, in original count-descending order, in
sequential batches (no sampling). For every row asked three questions in order:

1. **Is the surface a standalone word, or a fragment?** The dominant junk
   pattern (as flagged in the brief) is a stripped leading numeral or kanji
   prefix — `カ月連続` (missing 数字ヶ), `号議案` (missing 第N), `市付近` /
   `市中央` (missing a place name), `歳会社員` (missing N), `円送料別`
   (missing 価格). These account for a large share of the 567 junk rows.
   Also common: proper-noun fragments with an attached generic suffix
   (`天狼院` missing 書店, `倉院` missing 正, `研ゼミ` missing 進), and SEO
   title/keyword-stuffing concatenations that are not words a person would
   type as one unit (`クルマ買取ランキング`, `事故車買取比較`-style entries,
   `理黒柄デザート`-type garbled mis-segmentations).
2. **If it's a real, complete word — is the mined katakana reading actually
   correct?** This is where the earlier pass's only mistakes were, so every
   row that looked like bucket (a) was checked against how the word is
   actually read, not just how MeCab concatenated it. Found 131 cases where a
   real, common word had a naive/wrong reading mined for it (on/kun swap,
   rendaku miss, or a flatly wrong per-kanji reading) — these went to bucket
   (d) with both readings recorded.
3. **If it's a name/brand/place — is the reading right?** Proper nouns with a
   *wrong* mined reading (very common: `剛力彩芽`→ゴウリキイロドリメ should be
   アヤメ, `柳宗理`→ムネリ should be ソウリ, `首里城`→クビサトジョウ should be
   シュリジョウ, `南砺市`→ミナミアラトシ should be ナントシ) were routed to
   **junk, not (b) and not (d)**. Rationale: bucket (b)'s deliverable format
   has no slot for a correction, and fabricating/verifying a "correct"
   reading for an arbitrary personal name or place name from web text alone
   carries a much higher error risk than for common-noun vocabulary (which
   has a stable, checkable standard reading). Being wrong about a proper
   noun's reading is also lower-value to fix than a common noun, since it
   won't generalize the way a common-noun fix does. Only proper nouns whose
   mined reading was independently verified as the standard/expected reading
   went to (b) (17 rows — e.g. 西遊記, 協会けんぽ, 気象協会, 東進衛星予備校).

Adult-content vocabulary with a *correct* reading (神待ち, エッチ友, 乳ブラ,
美乳おっぱい, 貧乳おっぱい, 母子相姦, 大量射精, 顔射→corrected, etc.) was kept
in scope per the standing product decision and bucketed the same as any other
word — (a) if the reading was right, (d) if not.

## Notable reading-error patterns found (bucket d, 131 rows)

- **on/kun and compound-reading swaps** (biggest single category): 戸建住宅
  トケンジュウタク→コダテジュウタク, 筋膜リリース スジマクリリース→キンマク,
  僧帽筋 ソウボウスジ→ソウボウキン, 鶏胸肉/鶏がらスープ/鶏モモ肉
  ニワトリ…→トリ… (the 鶏=とり-in-cooking-compounds pattern recurred 3×),
  素揚げ モトアゲ→スアゲ, 母犬 ハハケン→ハハイヌ, 美白* (3 occurrences:
  美白美容液, 美白クリーム, 美白用) ビシロ→ビハク — same pattern the brief
  flagged for 美白 itself, confirmed recurring across compounds.
- **rendaku misses**: 認証済/締切済/完結済 all mined with unvoiced スミ,
  corrected to voiced ズミ, matching the 解決済み example in the brief exactly.
- **garbled/literal kanji-by-kanji misreads of medical & anatomy terms** —
  this cluster was the highest-risk-of-silent-error category and got the
  most scrutiny: 小陰唇 コカゲクチビル→ショウインシン, 眼輪筋 メワスジ→ガンリンキン,
  外腹斜筋 ソトハラハススジ→ガイフクシャキン, 側頭葉 ガワアタマハ→ソクトウヨウ,
  会陰切開 カイカゲセッカイ→エインセッカイ, 脂腺母斑 アブラセンハハムラ→シセンボハン,
  褥瘡 シトネクサ→ジョクソウ, 粉瘤 コナコブ→フンリュウ, 子宮腺筋症
  シキュウセンスジショウ→シキュウセンキンショウ. These are all real
  clinical/dermatology terms a patient would plausibly type after a doctor's
  visit or while researching a diagnosis — high value to fix, high risk if
  fixed wrong, so each was checked against the standard clinical reading.
- **isolated but confident fixes**: 雀荘 スズメソウ→ジャンソウ, 手表-adjacent
  車高調 クルマコウチョウ→シャコウチョウ, 一気通貫 イッキドオリヌキ→イッキツウカン,
  ひとり言 ヒトリゲン→ヒトリゴト, 頭突き アタマツキ→ズツキ, 連荘 レンソウ→レンチャン.

## Anomalies / things flagged but excluded

- **Chinese-text bleed-through**: `上架日期`(ウエカビキ), `手表`(シュヒョウ),
  `打折スペルガ` are Chinese phrases/words picked up by the crawler, not
  Japanese at all — junked outright.
- **Nonce/franchise-specific readings that look like real words but aren't
  standard**: 魔導 マシルベ, 魔導士 マシルベシ, 魔導書 マシルベショ all share
  the same non-standard "マシルベ" reading for 魔導 (standard is マドウ) across
  three separate rows — almost certainly a single game/franchise's stylized
  furigana bleeding into the corpus repeatedly. Junked all three rather than
  "correcting" to マドウ, since it's unclear the surface+マドウ combination is
  actually what users are typing for these specific rows.
- **店鋪 (alt-kanji variant of 店舗, correct reading テンポ) appears 5 times**
  in the tail with 4 different wrong mined readings (テンシキ, ミセシキ, plus
  compounds 店鋪情報/店鋪名/人気店鋪) — all corrected to テンポ-based readings
  and kept as separate rows in tail_corrected.tsv since they're independent
  mining errors at different counts.
- **Ambiguous rendaku call**: 鹿革 (deerskin) mined as シカカワ; both シカカワ
  and シカガワ appear in different reference sources. Erred toward the
  rendaku correction (シカガワ) for consistency with the pattern the brief
  warned about, but flagging this one as lower-confidence than the rest of
  bucket (d).
- **号艇/号車-style entries**: 号艇 (boat-racing "boat number") was initially
  a borderline (a) candidate since it's a real racing term, but on reflection
  it patterns identically to the ~15 other "N号X" numeral-fragment junk rows
  in this file (号議案, 号発行, 号サイズ, 号公報, 号墳, etc.) and essentially
  always appears with a leading digit in real usage — junked for consistency
  with the numeral-fragment rule rather than carved out as an exception.
- **年棒 (should be 年俸, "annual salary")**: kept as a bucket (d) entry even
  though the *surface itself* uses a nonstandard kanji (棒 instead of 俸) —
  this is an extremely common real-world typo/homophone-adjacent substitution,
  not a MeCab segmentation artifact, so it was treated as "real word, wrong
  reading" (corrected to ネンポウ) rather than junked.
