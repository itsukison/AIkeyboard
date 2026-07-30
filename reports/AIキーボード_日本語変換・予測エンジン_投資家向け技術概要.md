# 日本語変換・予測エンジン 技術報告

実装確認日：2026年7月26日

## 1. 全体構成

本アプリは、**AzooKeyKanaKanjiConverterを基盤エンジンとして使用し、そのAzooKey内部でZenzaiをニューラル変換モードとして有効化**しています。AzooKeyとZenzaiは別々に候補を出して後から混ぜる競合エンジンではありません。

```text
【かな漢字変換】
romaji／かな入力
  → InputManager
  → AzooKey（辞書・ラティス・誤入力補正・適応学習）
      └→ Zenzai（任意のニューラル変換層）
  → 候補表示
  → 確定結果をAzooKeyへ学習

【確定後の次語予測】
NextWordPreferenceStore
  → 3-gram prior
  → AzooKey post-composition prediction
  → 2-gram prior
  → 重複除去して最大10件
```

通常の入力、変換、学習、次語予測は端末内で完結します。Cloud AI文章書き換えは、ユーザーが明示的に実行した場合だけ通信する別系統です。

## 2. かな漢字変換

### 入力管理層

QWERTYでは `RomajiInputBuffer` がローマ字をかなへ変換し、フリックでは `KanaInputBuffer` がかなを直接保持します。両者は同じ `InputBuffer` の後ろで合流します。

`InputManager` は未確定かな、候補、選択候補、marked text、非同期タスクを管理します。末尾の未完成ローマ字は候補探索から外します。例えば表示が「きょうk」でもAzooKeyへ渡すのは「きょう」です。各キー入力で変換を開始し、古いタスクをキャンセルします。固定デバウンスはありません。かな表示は候補生成より先にiOSへ反映されます。

### AzooKey層

`KanaKanjiAdapter` actorがAzooKeyの `KanaKanjiConverter` をプロセス全体で1個だけ所有します。かなを `ComposingText` に入れ、`requestCandidates()` を呼びます。

| 設定 | 現在値／意味 |
|---|---|
| `N_best` | 20。候補バーに十分な候補を返す |
| `needTypoCorrection` | `true`。ラティス内で入力ミスを補正 |
| `requireJapanesePrediction` | `true`。入力途中および確定後予測を有効化 |
| `learningType` | `inputAndOutput`。確定候補を適応学習へ戻す |
| `maxMemoryCount` | 5,000。学習量と拡張メモリを制限 |

AzooKeyを採用した理由は、辞書、ラティス探索、形態素情報、誤入力補正、適応学習を持つ実用的な日本語変換基盤を再実装せずに利用できるためです。本アプリ側はiOSキーボード固有の状態管理、候補UI、メモリ制御、予測統合に集中しています。

### Zenzai層

Zenzaiは、かな漢字変換に特化した小型ニューラルモデルです。本アプリは `zenz-v3.1-xsmall` のGGUF重み（約20MB）を同梱し、AzooKeyの `zenzaiMode: .on(...)` として使用します。独立した後処理APIではなく、**AzooKeyの `requestCandidates()` 内で古典変換案を文脈付きで検討・修正する層**です。

現在の設定は以下です。

- `inferenceLimit: 2`：古典案を否定した後に修正版を出せる一方、推論回数を抑えて遅延を制限する。
- `personalizationMode: nil`：Zenzai独自の個人化は使わない。個人化はAzooKey学習と次語Preferenceが担当する。
- Zenzai v3の左文脈モードを使用。入力開始時に `documentContextBeforeInput` を一度取得し、直近部分だけを渡す。モデル側の最大左文脈長は20。
- llama.cppをCPUで実行。依存は自社fork `0.11.2-cpu.1`、Traitは `ZenzaiCPU`。

CPU専用forkを使う理由は、上流のMetal付き `llama.xcframework` がキーボード拡張内のモデル読込時にabortしたためです。GPU速度より拡張プロセス内の安定性を優先しています。

### 確定と変換学習

上位20候補を表示し、rawかながなければ必ず追加します。確定候補に対応するAzooKeyのrich candidateを `updateLearningData()` へ渡すため、学習は単純な文字列並べ替えではなく、辞書・形態素情報を含むAzooKeyのラティス順位へ反映されます。重いディスク統合は入力中ではなくキーボード終了時に実行し、App Groupの `conversion-learning` へ保存します。

リポジトリには `ConversionPreferenceStore` もありますが、**現行の日本語変換経路からは呼ばれていません**。現在の変換候補の個人化はAzooKey自身の適応学習が担当します。

## 3. 確定後の次語予測

次語予測は、以下の候補源を優先順に連結し、重複を除いて最大10件にします。

1. **`NextWordPreferenceStore`**  
   端末内で「前の確定語 → 次の確定語」を記録します。最大2,000遷移。使用回数、次に最終使用日時で順位付けし、上位3件を同期的に即時表示します。これは変換候補Preferenceではなく、確定語間の次語Preferenceです。

2. **3-gram corpus prior**  
   AzooKeyのrich candidateが持つ末尾2形態素をキーに、次の形態素を検索します。約12MB、最大200,000キー、各キー上位6件です。

3. **AzooKey post-composition prediction**  
   確定語が直前の `ConversionResult.mainResults` にあれば、そのrich candidateを `requestPostCompositionPredictionCandidates()` へ渡します。予測候補をタップすると `updateLearningData(base, with: prediction)` で学習し、`prediction.join(to: base)` で次の予測へ形態素文脈を連結します。

4. **2-gram corpus prior**  
   rich candidateの末尾1形態素をキーに、coverage用の候補を追加します。約10MB、最大150,000キー、各キー上位8件です。rawかなやcorpus候補など、rich candidateがない確定では、確定文字列そのものをキーにこの表へフォールバックします。

2-gram／3-gram表はFineWeb-2日本語データをMeCab/IPADICで形態素化し、オフライン生成しています。独自 `NWP1` 形式を `mappedIfSafe` でメモリマップし、UTF-8順インデックスを二分探索するため、合計約23MBのファイル全体を常駐RAMへ展開しません。

## 4. Zenzaiの有効化とフォールバック

Zenzaiは次の全条件を満たす場合だけ有効です。

- GGUF重みがバンドルされている。
- ユーザー設定「高精度変換」がON。
- 同一アプリビルドで速度判定による自動停止が記録されていない。
- `os_proc_available_memory() > 50MB`。

Zenzaiは古典変換に加えて約25MBの一時的headroomを必要とする想定です。条件を満たさなければ、同じAzooKeyを `zenzaiMode: .off` で使用します。そのため、辞書変換、誤入力補正、AzooKey学習、次語Preference、corpus priorは継続します。

速度面では、最初の3変換を除外し、その後の直近15回の中央値が150msを超えるとZenzaiを停止します。低電力モードまたはthermal stateがnominal以外の計測は判定に使いません。古典辞書はプロセス開始時にprewarmしますが、Zenzaiの重み読込と初回推論は `viewDidAppear` 後へ遅延します。

AzooKey／Zenzaiのインスタンスは拡張プロセス全体で1個だけです。iOSが複数の入力ViewControllerを残しても、辞書とllamaコンテキストが重複してjetsamへ近づかないための設計です。目標ピークは40MB未満ですが、旧端末を含む実機で全機能を連続使用した最終メモリ検証は公開前の未完了項目です。

## 主要実装

- `Sources/JapaneseKeyboardCore/InputManager.swift`
- `Sources/JapaneseKeyboardCore/KanaKanjiAdapter.swift`
- `Sources/JapaneseKeyboardCore/NextWordPrior.swift`
- `Sources/JapaneseKeyboardCore/ZenzaiLatencyGate.swift`
- `Sources/KeyboardPreferences/NextWordPreferenceStore.swift`
- `Sources/KeyboardPreferences/ConversionPreferenceStore.swift`
- `iOS/KeyboardExtension/KeyboardViewController.swift`

外部資料：[AzooKeyKanaKanjiConverter](https://github.com/azooKey/AzooKeyKanaKanjiConverter)／[FineWeb-2](https://huggingface.co/datasets/HuggingFaceFW/fineweb-2)／[Apple Custom Keyboard](https://developer.apple.com/documentation/uikit/creating-a-custom-keyboard)

