# Exit comps — 3億円イグジットのリアリティチェック

Researched 2026-07-18 (web research; sources inline). 凡例: [確定] = sourced fact, 【推測】/[推定] = estimate.

## 一行サマリ

3億円は「財務価値」では**有料会員8,000〜10,000人相当（ARR約1億円）**が必要。「データ価値」単体では2,800ユーザー規模の先例はなく代替調達コストの壁があるが、**同意取得済み・実環境・敬語特化のin-situ選好パイプライン**は戦略買いの強い加点要素。最も現実的な経路は**Simeji型の数億円戦略買い**（PKSHA・SB Intuitions・ジャストシステム筋）。

## 「100万DL/30万ユーザー必要」説の検証 → **不要。ただしデータ単体でも不成立**

- ユーザー数の論理で3億円 ÷ 2,800人 = 約10.7万円/人。ベンチマークは SwiftKey 約125円/台（$250M÷3億台）、TRANBI実例 1.6円/DL（1,800万DLゲームが2,900万円）。ユーザー基盤の論理で売るなら確かに数十万〜100万ユーザーが要る。
- **収益で代替する場合**: Flippa 2025 — アプリ利益倍率 平均2.4x/上位5.4x、売上倍率1.75x〜**3.58x（サブスク・AI・高継続）**。3.58xなら **ARR 8,400万〜1億円 ≒ 月額980円×約8,500人の有料会員**で3億円が相場内。100万DLは不要。
- **データで代替する場合**: RLHF外注実勢 時給$45–70 → 1ペア約450〜1,000円。10万ペア×700円でも代替コスト約7,000万円だが、買い手は「発注すれば作れる」ため満額は払わない。データが主役になる条件【推測】: (i) 数百万ペア規模、(ii) 買い手が自力収集できない継続パイプライン、(iii) 同意・権利処理の完全性。**現状満たすのは (iii) のみ**（fail-closed設計・APPI対応は交渉上の実質的強み）。
- 年買法（営業利益×3〜5年）だと3億円 = 営業利益6,000万〜1億円/年相当。
- 警告事例: Origami→メルペイ 実質0円。ユーザー基盤があっても赤字＋戦略価値欠如なら値段はつかない。

## キーボードアプリ買収の前例

| 案件 | 年 | 金額 | 教訓 |
|---|---|---|---|
| SwiftKey → Microsoft | 2016 | $250M | 「キーボードではなくAI技術と人材を買った」 |
| Swype → Nuance | 2011 | $102.5M | 入力技術IP |
| **Simeji → Baidu** | 2011 | 非公表・報道で「数億円程度」 | **個人開発2名・法人化前で数億円。日本市場参入の足がかり＋日本語入力データ。敬語ボタンの3億円はこのレンジの上限に相当** |
| Fleksy → Pinterest | 2016 | 非公表 | 規模がないとアクハイア（人材のみ）扱いになる |

2024–26年にAIキーボードの買収事例は確認できず。買い手はまだ「作る/投資する」フェーズ（Wispr Flow $81M調達等）。

## 選好データ市場の相場観

- LMArena: 2026-01 シリーズA $150M・**評価額$1.7B**。ただし月500万ユーザー・月6,000万会話・ARR$30M・中立ベンチマークブランドがあってこそ。
- Meta→Scale AI $14.3B/49%。Surge AI 無調達で年商$1.2B。Reddit→Google 年$60M。
- SB Intuitions は数十名の社内アノテーションチームで日本語データを内製 → **日本語選好データを「買う」ニーズは構造的に存在**。
- ただし松尾研等からオープン日本語選好データセット公開が進む → 汎用ペアの希少性は低下中。**差別化は「実ビジネス文脈のin-situ敬語選好」**（ラボ製で再現困難）。

## 想定買い手リスト（優先順）

1. **PKSHA Technology** — 国内で最も活発な小型AI連続買収者（アーニーMLG 2024、VideoTouch 2026、X Capital 2026）。数億円ディールの実行確度が最も高い。
2. **SB Intuitions / ELYZA(KDDI) / NTT(tsuzumi) / rinna** — 日本語選好データ・パイプラインのストーリーが最も刺さる。ELYZAはKDDIが53.4%を「2桁億円後半」で取得した前例。
3. **ジャストシステム（ATOK）/ Baidu Japan（Simeji）/ LINEヤフー** — プロダクトシナジーが最も自然。ATOK Passportのビジネス層と敬語ニーズが重なる。
4. **kubell（Chatwork）・サイボウズ・ラクス**（ビジネスコミュSaaS）、**SmartHR・リクルート**(HR-tech研修領域)、朝日新聞typoless・Shodo（校正AI、体力は限定的）。

## 戦略への示唆

- 2026年末期限なら**収益（有料会員数千人）とデータパイプラインを並行して作る**のが交渉力最大化の道。どちらか単独では3億円に届かない。
- 売り物は「データ×プロダクト×チーム」のセット。ストーリー: 敬語×ビジネス日本語 niche の独占 + 成長する同意済み選好データパイプライン。

## 主要ソース

[Flippa 2025](https://flippa.com/blog/mobile-app-valuation-key-methods-metrics-and-multiples-for-2025/) / [fundbook](https://fundbook.co.jp/column/industries-ma/application/) / [SwiftKey](https://techcrunch.com/2016/02/03/microsoft-confirms-swiftkey-acquisition-for-250m-in-cash/) / [Simeji買収](https://jp.techcrunch.com/2011/12/13/jp20111213baidu-bought-simeji/) / [LMArena $1.7B](https://techcrunch.com/2026/01/06/lmarena-lands-1-7b-valuation-four-months-after-launching-its-product/) / [Reddit-Google](https://www.cbsnews.com/news/google-reddit-60-million-deal-ai-training/) / [ELYZA→KDDI](https://www.businessinsider.jp/article/284105/) / [SB Intuitions](https://note.com/sb_intuitions/n/n41a7c1dd432a) / [PKSHA M&A](https://www.nihon-ma.co.jp/news/20241206_3993-4/) / [Origami](https://xtech.nikkei.com/atcl/nxt/news/18/07027/) / [TRANBI](https://www.tranbi.com/buy/detail/?id=11369) / [ラッコM&A](https://prtimes.jp/main/html/rd/p/000000053.000040858.html)
