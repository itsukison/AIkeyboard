// Contrastive next-word eval: cases in the same `group` share a candidate
// pool but their contexts force different continuations — exactly the
// distinction an n-gram (2-word window) cannot make and a context-reading
// rescorer must. `gold` is a set because Japanese often admits several
// correct surface forms (した/しました). Pools are ordered by rough corpus
// frequency so the untouched order is an honest n-gram-ish baseline.
struct EvalCase {
    let group: String
    let context: String
    let gold: Set<String>
    let pool: [String]
}

let evalCases: [EvalCase] = [
    // --- Tense from a time adverb far outside the n-gram window ---
    .init(group: "tense-sakusei", context: "昨日、会議の資料を作成", gold: ["した", "しました"], pool: ["する", "します", "した", "しました", "して", "中"]),
    .init(group: "tense-sakusei", context: "明日、会議の資料を作成", gold: ["する", "します"], pool: ["する", "します", "した", "しました", "して", "中"]),
    .init(group: "tense-mita", context: "先週、友達とその映画を", gold: ["観た", "見た", "観ました", "見ました"], pool: ["見る", "見た", "観る", "観た", "見ました", "観ました"]),
    .init(group: "tense-mita", context: "来週、友達とその映画を", gold: ["観る", "見る", "観ます", "見ます"], pool: ["見る", "見た", "観る", "観た", "見ます", "観ます"]),
    .init(group: "tense-iku", context: "去年の夏は北海道に", gold: ["行った", "行きました"], pool: ["行く", "行った", "行きます", "行きました", "行って", "いる"]),
    .init(group: "tense-iku", context: "来年の夏は北海道に", gold: ["行く", "行きます", "行きたい"], pool: ["行く", "行った", "行きます", "行きました", "行きたい", "いる"]),

    // --- Counters selected by the counted noun ---
    .init(group: "counter", context: "コーヒーを2", gold: ["杯"], pool: ["つ", "個", "人", "杯", "匹", "冊", "枚", "台"]),
    .init(group: "counter", context: "犬を2", gold: ["匹"], pool: ["つ", "個", "人", "杯", "匹", "冊", "枚", "台"]),
    .init(group: "counter", context: "本を2", gold: ["冊"], pool: ["つ", "個", "人", "杯", "匹", "冊", "枚", "台"]),
    .init(group: "counter", context: "コピーを2", gold: ["枚", "部"], pool: ["つ", "個", "人", "杯", "匹", "冊", "枚", "部"]),
    .init(group: "counter", context: "車を2", gold: ["台"], pool: ["つ", "個", "人", "杯", "匹", "冊", "枚", "台"]),

    // --- Collocation: object noun selects the verb ---
    .init(group: "wear", context: "雨が降ってきたので傘を", gold: ["さした", "さす", "差した"], pool: ["かぶった", "履いた", "着た", "さした", "差した", "つけた", "さす"]),
    .init(group: "wear", context: "日差しが強いので帽子を", gold: ["かぶった", "かぶる"], pool: ["かぶった", "履いた", "着た", "さした", "つけた", "かぶる"]),
    .init(group: "wear", context: "玄関で新しい靴を", gold: ["履いた", "履く", "履いて"], pool: ["かぶった", "履いた", "着た", "さした", "つけた", "履く", "履いて"]),
    .init(group: "consume", context: "頭が痛いので薬を", gold: ["飲んだ", "飲む", "飲んで"], pool: ["食べた", "飲んだ", "買った", "飲む", "飲んで", "食べる"]),
    .init(group: "consume", context: "お腹が空いたので何か", gold: ["食べたい", "食べた", "食べよう"], pool: ["飲みたい", "食べたい", "買いたい", "食べた", "食べよう", "飲もう"]),
    .init(group: "consume", context: "喉が渇いたので水を", gold: ["飲んだ", "飲む", "飲みたい"], pool: ["食べた", "飲んだ", "買った", "飲む", "飲みたい", "食べる"]),

    // --- Weather subject selects the verb ---
    .init(group: "weather", context: "朝から強い雨が", gold: ["降って", "降った", "降る"], pool: ["吹いて", "降って", "出て", "降った", "降る", "吹く"]),
    .init(group: "weather", context: "朝から強い風が", gold: ["吹いて", "吹いた", "吹く"], pool: ["吹いて", "降って", "出て", "吹いた", "吹く", "降る"]),

    // --- Emotion selected by the outcome ---
    .init(group: "emotion", context: "第一志望の大学に合格して", gold: ["嬉しい", "うれしい"], pool: ["嬉しい", "悲しい", "悔しい", "楽しい", "うれしい", "つらい"]),
    .init(group: "emotion", context: "最終面接で落ちてしまって", gold: ["悔しい", "悲しい", "つらい"], pool: ["嬉しい", "悲しい", "悔しい", "楽しい", "うれしい", "つらい"]),

    // --- Register: business mail vs casual chat ---
    .init(group: "register-close", context: "ご確認のほど、何卒よろしく", gold: ["お願い"], pool: ["お願い", "頼む", "よろしく", "願います", "お願え"]),
    .init(group: "register-close", context: "明日の飲み会、幹事", gold: ["よろしく", "頼む", "お願い"], pool: ["お願い", "頼む", "よろしく", "願います"]),
    .init(group: "register-thanks", context: "本日はお忙しい中お時間をいただき", gold: ["ありがとう"], pool: ["ありがとう", "すみません", "感謝", "どうも", "恐縮"]),
    .init(group: "register-send", context: "部長、先ほどの資料を", gold: ["お送り", "送付", "お渡し"], pool: ["送った", "お送り", "送る", "送付", "お渡し", "渡した"]),
    .init(group: "register-send", context: "LINEでさっきの写真", gold: ["送った", "送る", "送って"], pool: ["送った", "お送り", "送る", "送付", "送って", "渡した"]),

    // --- Negation forced by 全然 / affirmation by 毎日 ---
    .init(group: "study", context: "テスト前なのに全然勉強して", gold: ["いない", "ない", "いません"], pool: ["いる", "いない", "いた", "います", "いません", "ない"]),
    .init(group: "study", context: "資格試験に向けて毎日勉強して", gold: ["いる", "います"], pool: ["いる", "いない", "いた", "います", "いません", "ない"]),

    // --- Cause → consequence polarity ---
    .init(group: "maniau", context: "電車が遅れたので約束の時間に", gold: ["間に合わ", "遅れ", "間に合い"], pool: ["間に合った", "間に合わ", "着いた", "遅れ", "間に合い", "行けた"]),
    .init(group: "maniau", context: "早めに家を出たので約束の時間に", gold: ["間に合った", "間に合い"], pool: ["間に合った", "間に合わ", "着いた", "遅れ", "間に合い", "行けた"]),

    // --- Question particle vs statement ---
    .init(group: "ikimasu", context: "週末の勉強会、田中さんも一緒に行き", gold: ["ませんか", "ます"], pool: ["ます", "ました", "ませんか", "たい", "ましょう"]),
    .init(group: "ikimasu", context: "はい、私もぜひ一緒に行き", gold: ["たい", "ます", "ましょう"], pool: ["ます", "ました", "ませんか", "たい", "ましょう"]),

    // --- Semantic frame: transport / duration ---
    .init(group: "shudan", context: "駅までは歩いて10", gold: ["分"], pool: ["分", "時間", "日", "円", "個", "km"]),
    .init(group: "shudan", context: "東京から大阪まで新幹線で2", gold: ["時間"], pool: ["分", "時間", "日", "円", "個", "km"]),
    .init(group: "shudan", context: "このりんごは1個100", gold: ["円"], pool: ["分", "時間", "日", "円", "個", "km"]),

    // --- Direction of giving ---
    .init(group: "give", context: "誕生日に母からプレゼントを", gold: ["もらった", "もらいました", "もらって"], pool: ["あげた", "もらった", "くれた", "渡した", "もらいました", "もらって"]),
    .init(group: "give", context: "誕生日に弟へプレゼントを", gold: ["あげた", "渡した", "あげました"], pool: ["あげた", "もらった", "くれた", "渡した", "あげました", "買った"]),

    // --- Body-part collocation ---
    .init(group: "body", context: "走りすぎて足が", gold: ["痛い", "疲れた", "痛く"], pool: ["痛い", "眠い", "空いた", "渇いた", "疲れた", "痛く"]),
    .init(group: "body", context: "昼ご飯を抜いたのでお腹が", gold: ["空いた", "すいた", "減った"], pool: ["痛い", "眠い", "空いた", "渇いた", "すいた", "減った"]),
    .init(group: "body", context: "徹夜が続いてとても", gold: ["眠い", "疲れた", "つらい"], pool: ["痛い", "眠い", "空いた", "渇いた", "疲れた", "つらい"]),

    // --- Aspect: continuing state vs completed ---
    .init(group: "ame-aspect", context: "窓の外を見ると、まだ雨が降って", gold: ["いる", "いた", "います"], pool: ["いる", "いた", "きた", "います", "やんだ"]),
    .init(group: "ame-aspect", context: "朝には雨がやっと", gold: ["やんだ", "やみました", "上がった"], pool: ["やんだ", "降った", "やみました", "上がった", "降る"]),

    // --- Formal noun selection ---
    .init(group: "yotei", context: "来月から新しいプロジェクトが始まる", gold: ["予定", "こと", "みたい"], pool: ["予定", "こと", "つもり", "ため", "みたい", "はず"]),
    .init(group: "yotei", context: "私は来年留学する", gold: ["予定", "つもり"], pool: ["予定", "こと", "つもり", "ため", "みたい", "はず"]),
]
