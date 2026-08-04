import KeyboardPreferences
import SwiftUI

// MARK: - Builder schema
//
// The use-case page seeds a preset; this builder turns that choice into a
// button that describes the user's actual job. It exists because a preset is
// not an authored button: users who author one reach 3+ rewrite days at 32%
// against a 7% baseline, while users who merely pick a preset sit at 9%.
//
// Everything is data rather than six hand-written pages, because the stable
// preferences differ by job — translation needs a target language and style,
// proofreading needs a correction scope, and summarising needs an output shape.
//
// Every common answer is a tap. Free text appears only after choosing その他,
// or in the optional note. Per-message facts such as request vs apology stay
// out of the questions: the rewrite model can infer those from the source text.

struct BuilderChip: Identifiable, Equatable {
    let id: String
    let label: String
    /// What this chip contributes to the auto-generated button name, which the
    /// toolbar clips hard (see `OnboardingButtonName.maxLength`). Falls back to
    /// the label when it is already short enough.
    var shortName: String?

    var name: String { shortName ?? label }
}

struct BuilderSlotGroup: Identifiable, Equatable {
    let id: String
    let question: String
    let chips: [BuilderChip]
}

/// A user's answers, keyed by slot-group id.
struct BuilderSelections: Equatable {
    var chips: [String: BuilderChip] = [:]
    var otherTexts: [String: String] = [:]
    var freeText: String = ""

    func chip(_ groupId: String) -> BuilderChip? { chips[groupId] }
    func label(_ groupId: String) -> String? { chips[groupId]?.label }
    func otherText(_ groupId: String) -> String {
        otherTexts[groupId, default: ""]
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var hasOtherChoice: Bool { chips.values.contains { $0.id == "other" } }
}

struct ButtonBuilderSpec {
    /// Chip groups shown on the first builder page. One or two.
    let pageAGroups: [BuilderSlotGroup]
    /// The example-backed register, preservation, or length axis on page two.
    /// `nil` is reserved for a future purpose with no second-page choice.
    let toneGroup: BuilderSlotGroup?
    /// Worked examples for the tone selector, keyed by tone chip id. Static, so
    /// changing the tone is instant; generating these would put a two-second
    /// wait on a radio button.
    let toneSamples: [String: String]
    /// Translation examples must follow the selected target language. Other
    /// purposes leave this empty and use `toneSamples` directly.
    var toneSamplesByLanguage: [String: [String: String]] = [:]
    /// Which slot supplies the button name. Never a concatenation — the toolbar
    /// cannot fit one.
    let nameSlotId: String
    /// Composes the sentence sent to the generator.
    let describe: (BuilderSelections) -> String

    func isComplete(_ selections: BuilderSelections) -> Bool {
        let pageADone = pageAGroups.allSatisfy { selections.chip($0.id) != nil }
        let toneDone = toneGroup.map { selections.chip($0.id) != nil } ?? true
        let groups = pageAGroups + (toneGroup.map { [$0] } ?? [])
        let otherTextDone = groups.allSatisfy { group in
            selections.chip(group.id)?.id != "other" || !selections.otherText(group.id).isEmpty
        }
        return pageADone && toneDone && otherTextDone
    }

    func autoName(_ selections: BuilderSelections) -> String {
        let selected = selections.chip(nameSlotId)
        let raw = selected?.id == "other"
            ? selections.otherText(nameSlotId)
            : selected?.name ?? ""
        return OnboardingButtonName.clamp(raw)
    }

    func toneSample(for chip: BuilderChip, selections: BuilderSelections) -> String? {
        guard let language = selections.chip("language") else {
            return toneSamples[chip.id]
        }
        if language.id == "other" { return nil }
        return toneSamplesByLanguage[language.id]?[chip.id] ?? toneSamples[chip.id]
    }
}

struct PresetPromptTemplate {
    let slotOrder: [String]
    let fragments: [String: String]
    let tail: String
    let complements: [OnboardingButtonSpec]
    let practiceKeyOrder: [String]
    let practice: [String: OnboardingGeneratedPractice]

    /// Assembles the authored fragments for the chosen chips into the button's
    /// instruction. Missing slots are skipped so a partially answered builder
    /// still yields grammatical Japanese.
    func prompt(for selections: BuilderSelections) -> String {
        let body = slotOrder.compactMap { groupId -> String? in
            guard let chip = selections.chip(groupId) else { return nil }
            return fragments["\(groupId).\(chip.id)"]
        }.joined()
        return body + tail
    }

    /// Practice examples are keyed only by the slots that materially change the
    /// visible result, so the table stays hand-authorable instead of one entry
    /// per combination.
    func practiceExample(for selections: BuilderSelections) -> OnboardingGeneratedPractice? {
        let key = practiceKeyOrder.compactMap { groupId -> String? in
            guard let chip = selections.chip(groupId) else { return nil }
            return "\(groupId).\(chip.id)"
        }.joined(separator: "|")
        return practice[key] ?? practice["default"]
    }
}

// MARK: - Name budget

enum OnboardingButtonName {
    /// The toolbar renders titles at 14pt with 11pt of horizontal padding and no
    /// `minimumScaleFactor`, leaving roughly 87pt per pill when four are shown.
    /// A full-width glyph is ~14pt, so anything past six characters truncates or
    /// crowds its neighbours.
    static let maxLength = 6

    static func clamp(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(maxLength))
    }
}

// MARK: - Specs

enum OnboardingButtonBuilder {
    // Chip order is frequency order, and the lists differ per use case on
    // purpose. Sharing one audience list across 敬語 and カジュアル put 友達 and
    // 家族 at the top of the 敬語 flow, which is close to nonsense — you do not
    // reach for a keigo button to text your family. The first chip a user sees
    // should be the one most of them would pick.

    static func spec(for useCase: OnboardingUseCase) -> ButtonBuilderSpec? {
        switch useCase {
        case .keigo:
            return ButtonBuilderSpec(
                pageAGroups: [
                    BuilderSlotGroup(
                        id: "audience",
                        question: "主に誰に送りますか？",
                        chips: [
                            BuilderChip(id: "bossTeacher", label: "上司・先生", shortName: "上司"),
                            BuilderChip(id: "client", label: "取引先", shortName: "取引先"),
                            BuilderChip(id: "customer", label: "お客さま", shortName: "お客さま"),
                            BuilderChip(id: "senior", label: "先輩・目上", shortName: "目上"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    ),
                    BuilderSlotGroup(
                        id: "channel",
                        question: "主にどこで使いますか？",
                        chips: [
                            BuilderChip(id: "chat", label: "チャット・LINE"),
                            BuilderChip(id: "email", label: "メール"),
                            BuilderChip(id: "document", label: "文書・案内"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    ),
                ],
                toneGroup: BuilderSlotGroup(
                    id: "politeness",
                    question: "どのくらい丁寧にしますか？",
                    chips: [
                        BuilderChip(id: "natural", label: "自然な丁寧語"),
                        BuilderChip(id: "business", label: "ビジネス敬語"),
                        BuilderChip(id: "formal", label: "かなりかしこまる"),
                        BuilderChip(id: "other", label: "その他"),
                    ]
                ),
                toneSamples: [
                    "natural": "明日の打ち合わせを10時に変更してもらえますか。",
                    "business": "恐れ入りますが、明日の打ち合わせを10時に変更していただけますか。",
                    "formal": "大変恐縮ですが、明日の打ち合わせを10時に変更していただけますと幸いです。",
                ],
                nameSlotId: "audience",
                describe: { s in
                    "\(answer(s, "audience"))に送る\(answer(s, "channel"))の文章を、\(answer(s, "politeness"))に整える。"
                }
            )

        case .casual:
            return ButtonBuilderSpec(
                pageAGroups: [
                    BuilderSlotGroup(
                        id: "channel",
                        question: "主にどこで使いますか？",
                        chips: [
                            BuilderChip(id: "lineDM", label: "LINE・DM", shortName: "LINE"),
                            BuilderChip(id: "groupChat", label: "グループチャット", shortName: "グループ"),
                            BuilderChip(id: "socialPost", label: "SNS投稿", shortName: "SNS"),
                            BuilderChip(id: "comment", label: "コメント・返信", shortName: "コメント"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    ),
                ],
                toneGroup: BuilderSlotGroup(
                    id: "casualness",
                    question: "どのくらいくだけた文章にしますか？",
                    chips: [
                        BuilderChip(id: "soft", label: "丁寧さを少し残す"),
                        BuilderChip(id: "natural", label: "自然で親しみやすい"),
                        BuilderChip(id: "veryCasual", label: "かなりくだける"),
                        BuilderChip(id: "other", label: "その他"),
                    ]
                ),
                toneSamples: [
                    "soft": "明日ちょっと遅れそうです。ごめんなさい。",
                    "natural": "明日ちょっと遅れるかも！ごめんね。",
                    "veryCasual": "ごめん、明日ちょい遅れる〜！",
                ],
                nameSlotId: "channel",
                describe: { s in
                    "\(answer(s, "channel"))で使う文章を、\(answer(s, "casualness"))口調に整える。"
                }
            )

        case .email:
            return ButtonBuilderSpec(
                pageAGroups: [
                    BuilderSlotGroup(
                        id: "recipient",
                        question: "主に誰に送りますか？",
                        chips: [
                            BuilderChip(id: "internal", label: "社内の人", shortName: "社内"),
                            BuilderChip(id: "boss", label: "上司", shortName: "上司"),
                            BuilderChip(id: "client", label: "取引先", shortName: "取引先"),
                            BuilderChip(id: "customer", label: "お客さま", shortName: "客先"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    ),
                    BuilderSlotGroup(
                        id: "format",
                        question: "どこまでメールらしく整えますか？",
                        chips: [
                            BuilderChip(id: "body", label: "本文だけ", shortName: "本文"),
                            BuilderChip(id: "complete", label: "あいさつ・結びも入れる", shortName: "メール"),
                            BuilderChip(id: "subject", label: "件名から整える", shortName: "件名"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    ),
                ],
                toneGroup: BuilderSlotGroup(
                    id: "length",
                    question: "どのくらい短くしますか？",
                    chips: [
                        BuilderChip(id: "concise", label: "簡潔"),
                        BuilderChip(id: "standard", label: "標準"),
                        BuilderChip(id: "detailed", label: "丁寧に詳しく"),
                        BuilderChip(id: "other", label: "その他"),
                    ]
                ),
                toneSamples: [
                    "concise": "資料をご確認ください。",
                    "standard": "お手数ですが、添付の資料をご確認いただけますでしょうか。",
                    "detailed": "お忙しいところ恐れ入りますが、添付の資料をご確認のうえ、ご意見をお知らせいただけますと幸いです。",
                ],
                nameSlotId: "recipient",
                describe: { s in
                    "\(answer(s, "recipient"))に送るメールを、\(answer(s, "format"))形で、\(answer(s, "length"))整える。"
                }
            )

        case .translate:
            return ButtonBuilderSpec(
                pageAGroups: [
                    BuilderSlotGroup(
                        id: "language",
                        question: "どの言語に訳しますか？",
                        chips: [
                            BuilderChip(id: "en", label: "英語", shortName: "英訳"),
                            BuilderChip(id: "zh", label: "中国語", shortName: "中訳"),
                            BuilderChip(id: "ko", label: "韓国語", shortName: "韓訳"),
                            BuilderChip(id: "other", label: "その他", shortName: "翻訳"),
                        ]
                    ),
                    BuilderSlotGroup(
                        id: "style",
                        question: "どんな翻訳にしますか？",
                        chips: [
                            BuilderChip(id: "natural", label: "自然な現地表現"),
                            BuilderChip(id: "balanced", label: "原文とのバランス"),
                            BuilderChip(id: "faithful", label: "原文に忠実"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    ),
                ],
                // Translation's axis is register, not politeness — a casual
                // translation is a different thing from a casual rewrite.
                toneGroup: BuilderSlotGroup(
                    id: "tone",
                    question: "どんな口調にしますか？",
                    chips: [
                        BuilderChip(id: "casual", label: "カジュアル"),
                        BuilderChip(id: "polite", label: "丁寧"),
                        BuilderChip(id: "business", label: "ビジネス"),
                        BuilderChip(id: "other", label: "その他"),
                    ]
                ),
                toneSamples: [
                    "casual": "Sorry, I might be a little late tomorrow!",
                    "polite": "I'm sorry, but I may be a little late tomorrow.",
                    "business": "I am afraid I will arrive a little late tomorrow.",
                ],
                toneSamplesByLanguage: [
                    "zh": [
                        "casual": "不好意思，我明天可能会晚一点！",
                        "polite": "不好意思，我明天可能会晚到一会儿。",
                        "business": "很抱歉，我明天可能会稍晚到达。",
                    ],
                    "ko": [
                        "casual": "미안, 나 내일 조금 늦을 수도 있어!",
                        "polite": "죄송하지만 내일 조금 늦을 수도 있어요.",
                        "business": "죄송합니다만, 내일 조금 늦게 도착할 수 있습니다.",
                    ],
                ],
                nameSlotId: "language",
                describe: { s in
                    let lang = answer(s, "language")
                    let style: String
                    switch s.chip("style")?.id {
                    case "natural": style = "読みやすい意訳"
                    case "balanced": style = "自然さと原文のバランスを取った訳"
                    case "faithful": style = "原文に忠実な訳"
                    default: style = answer(s, "style")
                    }
                    let tone = answer(s, "tone")
                    return "\(lang)へ\(style)で翻訳し、文体は\(tone)。"
                }
            )

        case .proofread:
            return ButtonBuilderSpec(
                pageAGroups: [
                    BuilderSlotGroup(
                        id: "scope",
                        question: "どこまで直しますか？",
                        chips: [
                            BuilderChip(id: "typos", label: "誤字・文法だけ", shortName: "校正"),
                            BuilderChip(id: "natural", label: "不自然な表現も直す", shortName: "添削"),
                            BuilderChip(id: "rewrite", label: "全体を自然に書き直す", shortName: "推敲"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    ),
                ],
                toneGroup: BuilderSlotGroup(
                    id: "preservation",
                    question: "元の書き方を残しますか？",
                    chips: [
                        BuilderChip(id: "keep", label: "できるだけ残す"),
                        BuilderChip(id: "balanced", label: "ある程度残す"),
                        BuilderChip(id: "natural", label: "自然さを最優先"),
                        BuilderChip(id: "other", label: "その他"),
                    ]
                ),
                toneSamples: [
                    "keep": "資料を確認していただけますでしょうか。",
                    "balanced": "資料をご確認いただけますでしょうか。",
                    "natural": "資料をご確認いただけると幸いです。",
                ],
                nameSlotId: "scope",
                describe: { s in
                    "日本語を\(answer(s, "scope"))直し、元の書き方は\(answer(s, "preservation"))。"
                }
            )

        case .summarize:
            return ButtonBuilderSpec(
                pageAGroups: [
                    BuilderSlotGroup(
                        id: "format",
                        question: "どんな形でまとめますか？",
                        chips: [
                            BuilderChip(id: "paragraph", label: "短い文章", shortName: "要約"),
                            BuilderChip(id: "bullets", label: "箇条書き", shortName: "箇条書き"),
                            BuilderChip(id: "points", label: "要点リスト", shortName: "要点"),
                            BuilderChip(id: "other", label: "その他"),
                        ]
                    )
                ],
                toneGroup: BuilderSlotGroup(
                    id: "length",
                    question: "どのくらい短くしますか？",
                    chips: [
                        BuilderChip(id: "slightly", label: "少し短く"),
                        BuilderChip(id: "very", label: "かなり短く"),
                        BuilderChip(id: "oneSentence", label: "一文だけ"),
                        BuilderChip(id: "other", label: "その他"),
                    ]
                ),
                toneSamples: [
                    "slightly": "明日の会議は10時から第3会議室で行います。資料は本日中に共有します。",
                    "very": "明日10時、第3会議室で会議。資料は本日共有します。",
                    "oneSentence": "明日10時に第3会議室で会議を行い、資料は本日共有します。",
                ],
                nameSlotId: "format",
                describe: { s in
                    "文章を\(answer(s, "format"))で、\(answer(s, "length"))要約する。"
                }
            )

        case .custom:
            // Free text only — the user already described the job in their own
            // words on the use-case page.
            return nil
        }
    }

    private static func answer(_ selections: BuilderSelections, _ groupId: String) -> String {
        if selections.chip(groupId)?.id == "other" {
            return selections.otherText(groupId)
        }
        return selections.label(groupId) ?? ""
    }

    static func template(for useCase: OnboardingUseCase) -> PresetPromptTemplate? {
        switch useCase {
        case .keigo: return keigoTemplate
        case .casual: return casualTemplate
        case .email: return emailTemplate
        case .translate: return translateTemplate
        case .proofread: return proofreadTemplate
        case .summarize: return summarizeTemplate
        case .custom: return nil
        }
    }

    private static let keigoTemplate = PresetPromptTemplate(
        slotOrder: ["audience", "channel", "politeness"],
        fragments: [
            "audience.bossTeacher": "上司や先生に送る文章として、",
            "audience.client": "取引先に送る文章として、",
            "audience.customer": "お客さまに送る文章として、",
            "audience.senior": "先輩や目上の人に送る文章として、",
            "audience.other": "相手との関係を文章から判断し、",
            "channel.chat": "チャットで読みやすい短い文にし、",
            "channel.email": "メール本文として自然な段落と文末にし、",
            "channel.document": "文書や案内として省略のない整った表現にし、",
            "channel.other": "用途に合う文章構成にし、",
            "politeness.natural": "文末をです・ます調にし、日常的な丁寧語を使う。",
            "politeness.business": "尊敬語と謙譲語を関係に合わせ、依頼にはクッション言葉を一つ添える。",
            "politeness.formal": "文末を「〜いたします／〜申し上げます」調にし、依頼や断りには前置きを添える。",
            "politeness.other": "相手と場面に合う丁寧さにする。",
        ],
        tail: "誤った二重敬語は避ける。",
        complements: [
            button("自然に", "直訳調や不自然な語順を直し、日本語として自然に読める文にする。"),
            button("短く", "重複と回りくどい部分を削り、要点がすぐ伝わる長さにする。"),
            button("英訳", "自然な英語に翻訳し、英語で一般的な語順と表現にする。"),
        ],
        practiceKeyOrder: ["politeness"],
        practice: [
            "politeness.natural": practice(
                "明日の打ち合わせ、10時に変えてほしい",
                "明日の打ち合わせを10時に変更してもらえますか。",
                "明日の打ち合わせですが、10時に変更してもらえると助かります。",
                "明日の打ち合わせを10時に変更してください。お願いします。"
            ),
            "politeness.business": practice(
                "明日の打ち合わせ、10時に変えてほしい",
                "明日の打ち合わせを10時に変更していただけますか。",
                "明日の打ち合わせを10時に変更していただけると助かります。",
                "お手数ですが、明日の打ち合わせを10時に変更していただけますでしょうか。"
            ),
            "politeness.formal": practice(
                "明日の打ち合わせ、10時に変えてほしい",
                "恐れ入りますが、明日の打ち合わせを10時に変更していただけますでしょうか。",
                "差し支えなければ、明日の打ち合わせを10時に変更していただけますと幸いです。",
                "大変恐縮ですが、明日の打ち合わせを10時に変更していただけますようお願いいたします。"
            ),
        ]
    )

    private static let casualTemplate = PresetPromptTemplate(
        slotOrder: ["channel", "casualness"],
        fragments: [
            "channel.lineDM": "LINEやDMで一読できる短い文にし、",
            "channel.groupChat": "グループチャットで要点が伝わる文にし、",
            "channel.socialPost": "SNS投稿として読みやすい語順と改行にし、",
            "channel.comment": "コメントや返信として前置きを省いた文にし、",
            "channel.other": "使う場所に合う文章構成にし、",
            "casualness.soft": "です・ますを少し残し、硬い敬語を日常的な表現に変える。",
            "casualness.natural": "敬語を外し、自然な話し言葉と「〜だね／〜かも」などの文末を使う。",
            "casualness.veryCasual": "敬語を外し、主語の省略や短い相づちを使う親しい話し方にする。",
            "casualness.other": "相手との距離感に合うくだけた口調にする。",
        ],
        tail: "乱暴な語や内輪でしか通じない呼び方は使わない。",
        complements: [
            button("自然に", "不自然な語順と直訳調を直し、普段使う日本語にする。"),
            button("短く", "重複を削り、スマートフォンで一読できる短い文にする。"),
            button("英訳", "会話で使う自然な英語に翻訳し、硬い書き言葉は避ける。"),
        ],
        practiceKeyOrder: ["casualness"],
        practice: [
            "casualness.soft": practice(
                "今日はありがとうございました。またぜひよろしくお願いします。",
                "今日はありがとうございました。またぜひお願いします！",
                "今日はありがとうございました。またぜひご一緒できるとうれしいです！",
                "今日はありがとうございました。またぜひよろしくお願いします！"
            ),
            "casualness.natural": practice(
                "今日はありがとうございました。またぜひよろしくお願いします。",
                "今日はありがとう！またぜひよろしくね。",
                "今日はありがとう！また一緒にできたらうれしい！",
                "今日はありがとう！またぜひね。"
            ),
            "casualness.veryCasual": practice(
                "今日はありがとうございました。またぜひよろしくお願いします。",
                "今日はありがと！またぜひ〜！",
                "今日はありがとー！またやろ！",
                "今日はありがと！次もよろしく！"
            ),
        ]
    )

    private static let emailTemplate = PresetPromptTemplate(
        slotOrder: ["recipient", "format", "length"],
        fragments: [
            "recipient.internal": "社内向けの簡潔なビジネス敬語を使い、",
            "recipient.boss": "上司への報告や依頼に合う敬語を使い、",
            "recipient.client": "取引先への配慮が伝わるビジネス敬語を使い、",
            "recipient.customer": "お客さまに安心感を与える丁寧な敬語を使い、",
            "recipient.other": "宛先との関係を文章から判断し、",
            "format.complete": "用件に合うあいさつを冒頭に、結びを末尾に入れ、",
            "format.body": "挨拶・結び・件名・宛名・署名を足さず本文だけを整え、",
            "format.subject": "先頭に「件名：」で始まる簡潔な件名を置き、続けて本文を整え、",
            "format.other": "用件の種類を文章から判断して本文を整え、",
            "length.concise": "定型句と重複を減らして簡潔にする。",
            "length.standard": "用件が過不足なく伝わる標準的な長さにする。",
            "length.detailed": "原文にある背景、条件、期限を省かず、配慮を示す表現も入れる。",
            "length.other": "用件に合う長さに整える。",
        ],
        tail: "拝啓・敬具は使わない。",
        complements: [
            button("敬語", "文末をです・ますで統一し、依頼には文脈に合うクッション言葉を添える。"),
            button("短く", "重複と定型句を減らし、用件が先に伝わる短い文にする。"),
            button("誤字", "誤字・脱字、助詞、送りがなの誤りだけを直し、文体は変えない。"),
        ],
        practiceKeyOrder: ["format", "length"],
        practice: [
            "format.body|length.concise": practice(
                "資料を金曜までに確認してください",
                "金曜日までに資料をご確認ください。",
                "金曜日までに資料をご確認いただけると助かります。",
                "恐れ入りますが、金曜日までに資料をご確認ください。"
            ),
            "format.body|length.standard": practice(
                "資料を金曜までに確認してください",
                "お手数ですが、資料を金曜日までにご確認いただけますでしょうか。",
                "資料を金曜日までにご確認いただけると助かります。",
                "恐れ入りますが、資料を金曜日までにご確認いただけますと幸いです。"
            ),
            "format.body|length.detailed": practice(
                "資料を金曜までに確認してください",
                "お忙しいところ恐れ入りますが、資料の内容を金曜日までにご確認いただけますでしょうか。",
                "お手数をおかけしますが、資料の内容を金曜日までにご確認いただけると助かります。",
                "ご多用のところ恐縮ですが、資料の内容を金曜日までにご確認いただけますと幸いです。"
            ),
            "format.complete|length.concise": practice(
                "資料を金曜までに確認してください",
                "お世話になっております。金曜日までに資料をご確認ください。よろしくお願いします。",
                "お世話になっております。金曜日までに資料をご確認いただけると助かります。よろしくお願いします。",
                "お世話になっております。恐れ入りますが、金曜日までに資料をご確認ください。よろしくお願いいたします。"
            ),
            "format.complete|length.standard": practice(
                "資料を金曜までに確認してください",
                "お世話になっております。\nお手数ですが、資料を金曜日までにご確認いただけますでしょうか。\nよろしくお願いいたします。",
                "お世話になっております。\n資料を金曜日までにご確認いただけると助かります。\nどうぞよろしくお願いします。",
                "お世話になっております。\n恐れ入りますが、資料を金曜日までにご確認いただけますと幸いです。\n何卒よろしくお願いいたします。"
            ),
            "format.complete|length.detailed": practice(
                "資料を金曜までに確認してください",
                "お世話になっております。\nお忙しいところ恐れ入りますが、資料の内容を金曜日までにご確認いただけますでしょうか。\nご対応のほど、よろしくお願いいたします。",
                "お世話になっております。\nお手数をおかけしますが、資料の内容を金曜日までにご確認いただけると助かります。\nどうぞよろしくお願いします。",
                "平素よりお世話になっております。\nご多用のところ恐縮ですが、資料の内容を金曜日までにご確認いただけますと幸いです。\n何卒よろしくお願い申し上げます。"
            ),
            "format.subject|length.concise": practice(
                "資料を金曜までに確認してください",
                "件名：資料確認のお願い\n\n金曜日までに資料をご確認ください。",
                "件名：資料確認のお願い\n\n金曜日までに資料をご確認いただけると助かります。",
                "件名：資料ご確認のお願い\n\n恐れ入りますが、金曜日までに資料をご確認ください。"
            ),
            "format.subject|length.standard": practice(
                "資料を金曜までに確認してください",
                "件名：資料確認のお願い\n\nお手数ですが、資料を金曜日までにご確認いただけますでしょうか。",
                "件名：資料確認のお願い\n\n資料を金曜日までにご確認いただけると助かります。",
                "件名：資料ご確認のお願い\n\n恐れ入りますが、資料を金曜日までにご確認いただけますと幸いです。"
            ),
            "format.subject|length.detailed": practice(
                "資料を金曜までに確認してください",
                "件名：金曜日までの資料確認のお願い\n\nお忙しいところ恐れ入りますが、資料の内容を金曜日までにご確認いただけますでしょうか。",
                "件名：資料確認のお願い（金曜日まで）\n\nお手数をおかけしますが、資料の内容を金曜日までにご確認いただけると助かります。",
                "件名：資料ご確認のお願い（金曜日期限）\n\nご多用のところ恐縮ですが、資料の内容を金曜日までにご確認いただけますと幸いです。"
            ),
        ]
    )

    private static let translateTemplate = PresetPromptTemplate(
        slotOrder: ["language", "style", "tone"],
        fragments: [
            "language.en": "英語に翻訳し、",
            "language.zh": "中国語の簡体字に翻訳し、",
            "language.ko": "韓国語に翻訳し、",
            "language.other": "補足で指定された言語に翻訳し、",
            "style.natural": "同じ場面で実際に使う表現へ置き換え、",
            "style.balanced": "自然な語順にしつつ原文の言い回しと強さも残し、",
            "style.faithful": "原文の情報の細かさ、語調、文の構造をできるだけ保ち、",
            "style.other": "場面に合う訳し方を選び、",
            "tone.casual": "短い話し言葉と日常的な表現を使う。",
            "tone.polite": "日常的で丁寧な文体にする。",
            "tone.business": "ビジネスで使う丁寧な文体と用語にする。",
            "tone.other": "指定された口調にする。",
        ],
        tail: "対象言語で文法的に正しい文章にする。",
        complements: [
            button("自然に", "不自然な語順と直訳調を直し、その言語で一般的な表現にする。"),
            button("短く", "重複と回りくどい部分を削り、要点が一読で伝わる長さにする。"),
            button("添削", "文法、綴り、句読点、語の使い方の誤りを直し、文体は変えない。"),
        ],
        practiceKeyOrder: ["language", "tone"],
        practice: [
            "language.en|tone.casual": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "Tomorrow's meeting starts at 10. I might be a little late.",
                "We're meeting at 10 tomorrow. I might be running a bit late.",
                "Tomorrow's meeting is at 10. I could be a little late."
            ),
            "language.en|tone.polite": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "Tomorrow's meeting starts at 10. I may be a little late.",
                "We are meeting at 10 tomorrow, and I might arrive a little late.",
                "Tomorrow's meeting will begin at 10. I may arrive slightly late."
            ),
            "language.en|tone.business": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "Tomorrow's meeting is scheduled to begin at 10. I may arrive a little late.",
                "Our meeting tomorrow begins at 10. I may be slightly delayed.",
                "Tomorrow's meeting is scheduled for 10. I may be slightly delayed."
            ),
            "language.zh|tone.casual": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "明天十点开会，我可能会晚一点。",
                "我们明天十点开会，我可能晚点到。",
                "明天的会十点开始，我可能会迟到一会儿。"
            ),
            "language.zh|tone.polite": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "明天的会议从十点开始，我可能会晚到一会儿。",
                "明天十点开始开会，我可能会稍晚到达。",
                "明天的会议将于十点开始，我可能会稍微晚到。"
            ),
            "language.zh|tone.business": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "明天的会议定于十点开始，我可能会稍晚到达。",
                "明天的会议将于十点开始，我可能会稍有延误。",
                "明天的会议定于十点开始，届时我可能会稍晚到达。"
            ),
            "language.ko|tone.casual": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "내일 회의는 10시에 시작해. 나 조금 늦을 수도 있어.",
                "우리 내일 10시에 회의해. 나 조금 늦을지도 몰라.",
                "내일 회의는 10시부터야. 나 조금 늦을 수도 있어."
            ),
            "language.ko|tone.polite": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "내일 회의는 10시에 시작해요. 제가 조금 늦을 수도 있어요.",
                "내일 10시에 회의해요. 제가 조금 늦을지도 몰라요.",
                "내일 회의는 10시부터예요. 제가 조금 늦을 수 있어요."
            ),
            "language.ko|tone.business": practice(
                "明日の打ち合わせは10時からです。少し遅れるかもしれません。",
                "내일 회의는 오전 10시에 시작됩니다. 제가 조금 늦을 수 있습니다.",
                "내일 오전 10시에 회의가 시작되며, 제가 다소 늦을 수도 있습니다.",
                "내일 회의는 오전 10시에 시작될 예정입니다. 제가 다소 늦을 가능성이 있습니다."
            ),
        ]
    )

    private static let proofreadTemplate = PresetPromptTemplate(
        slotOrder: ["scope", "preservation"],
        fragments: [
            "scope.typos": "誤字・脱字、助詞、活用の誤りだけを直し、",
            "scope.natural": "誤字・文法に加え、不自然な語順、語の選び方、重複も直し、",
            "scope.rewrite": "文章全体の語順と文のつながりを組み直して自然な日本語にし、",
            "scope.other": "指定された範囲を直し、",
            "preservation.keep": "選んだ修正範囲の中で、元の語彙と語順をできるだけ残す。",
            "preservation.balanced": "選んだ修正範囲の中で必要な箇所だけ言い換え、それ以外の書き方は残す。",
            "preservation.natural": "選んだ修正範囲の中では、元の語順より日本語としての自然さを優先する。",
            "preservation.other": "指定された程度で元の書き方を残す。",
        ],
        tail: "元の丁寧さと口調は変えない。誤りがない固有の表現は残す。",
        complements: [
            button("自然に", "直訳調、不自然な語順、使い方の不自然な語を、日本語で一般的な表現に直す。"),
            button("短く", "重複と回りくどい部分を削り、要点がすぐ伝わる長さにする。"),
            button("敬語", "文末をです・ますで統一し、依頼には文脈に合うクッション言葉を添える。"),
        ],
        practiceKeyOrder: ["scope", "preservation"],
        practice: [
            "scope.typos|preservation.keep": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。"
            ),
            "scope.typos|preservation.balanced": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。"
            ),
            "scope.typos|preservation.natural": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題とかあったら連絡ください。"
            ),
            "scope.natural|preservation.keep": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "明日までに会議の資料を確認していただきたいです。問題などがあったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。何か問題があったら連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題などがあれば連絡ください。"
            ),
            "scope.natural|preservation.balanced": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "明日までに会議資料をご確認いただきたいです。問題があればご連絡ください。",
                "明日までに会議資料をご確認いただけると助かります。何か問題があればご連絡ください。",
                "明日までに会議資料をご確認いただきたいです。問題などがあればご連絡ください。"
            ),
            "scope.natural|preservation.natural": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "会議資料を明日までにご確認ください。問題があればご連絡ください。",
                "会議資料を明日までにご確認いただけると助かります。何か問題があればご連絡ください。",
                "会議資料を明日までにご確認ください。問題などがあればご連絡ください。"
            ),
            "scope.rewrite|preservation.keep": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "明日までに会議の資料を確認していただきたいです。問題などがあれば連絡ください。",
                "明日までに会議の資料を確認していただけると助かります。何か問題があれば連絡ください。",
                "明日までに会議の資料を確認していただきたいです。問題があれば連絡ください。"
            ),
            "scope.rewrite|preservation.balanced": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "会議資料を明日までにご確認ください。問題があればご連絡ください。",
                "会議資料を明日までにご確認いただけると助かります。何か問題があればご連絡ください。",
                "会議資料を明日までにご確認ください。問題などがあればご連絡ください。"
            ),
            "scope.rewrite|preservation.natural": practice(
                "明日までに会議の資料を確認して頂きたいです。問題とかあったら連絡くさだい。",
                "会議資料は明日までにご確認をお願いします。問題がありましたら、ご連絡ください。",
                "会議資料を明日までにご確認いただけると助かります。気になる点があれば、ご連絡ください。",
                "会議資料は明日までにご確認ください。問題があれば、ご連絡ください。"
            ),
        ]
    )

    private static let summarizeTemplate = PresetPromptTemplate(
        slotOrder: ["format", "length"],
        fragments: [
            "format.paragraph": "重要な情報を短い文章にまとめ、",
            "format.bullets": "重要な情報を「・」で始まる箇条書きにし、",
            "format.points": "各項目を短い見出しと内容の組み合わせで整理し、",
            "format.other": "指定された形にまとめ、",
            "length.slightly": "前置きと重複を削り、原文より少し短くする。",
            "length.very": "結論、重要な条件、次の行動だけを残して大幅に短くする。",
            "length.oneSentence": "箇条書きなら一項目、それ以外なら一文だけにする。",
            "length.other": "指定された長さにする。",
        ],
        tail: "重要な結論、数値、期限、次の行動は残す。",
        complements: [
            button("要点", "最も重要な結論、理由、次の行動だけを残して短くする。"),
            button("簡単に", "難しい語を日常的な語に置き換え、長い一文は短く分ける。"),
            button("整理", "関連する内容をまとめ、結論、理由、次の行動の順に並べ直す。"),
        ],
        practiceKeyOrder: ["format", "length"],
        practice: [
            "format.paragraph|length.slightly": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "明日の定例は10時30分開始です。参加が難しい場合は本日17時までに連絡してください。資料は開始前に共有します。",
                "明日の定例は10時30分から。難しい人は今日17時までに連絡してください。資料は事前に共有します。",
                "明日の定例は10時30分開始です。ご参加が難しい場合は本日17時までにご連絡ください。資料は開始前に共有いたします。"
            ),
            "format.paragraph|length.very": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "明日の定例は10時30分開始です。参加が難しい場合は本日17時までに連絡してください。",
                "明日の定例は10時30分から。難しい人は今日17時までに連絡してください。",
                "明日の定例は10時30分開始です。ご参加が難しい場合は本日17時までにご連絡ください。"
            ),
            "format.paragraph|length.oneSentence": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "明日の定例は10時30分開始で、参加が難しい場合は本日17時までに連絡し、資料は開始前に共有します。",
                "明日の定例は10時30分からで、難しい人は今日17時までに連絡、資料は事前に共有します。",
                "明日の定例は10時30分開始で、ご参加が難しい場合のご連絡は本日17時まで、資料の共有は開始前です。"
            ),
            "format.bullets|length.slightly": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "・明日の定例は10時30分開始\n・参加が難しい場合は本日17時までに連絡\n・資料は開始前に共有",
                "・明日の定例は10時30分から\n・難しい人は今日17時までに連絡\n・資料は事前に共有",
                "・明日の定例は10時30分開始\n・ご参加が難しい場合は本日17時までにご連絡ください\n・資料は開始前に共有"
            ),
            "format.bullets|length.very": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "・定例：明日10時30分開始\n・欠席連絡：本日17時まで",
                "・明日10時30分から定例\n・難しい人は今日17時までに連絡",
                "・定例：明日10時30分開始\n・ご欠席の連絡：本日17時まで"
            ),
            "format.bullets|length.oneSentence": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "・明日10時30分に定例を開始し、欠席連絡は本日17時まで、資料は開始前に共有",
                "・明日10時30分から定例、難しい人は今日17時までに連絡、資料は事前共有",
                "・明日10時30分に定例を開始し、ご欠席の連絡は本日17時まで、資料は開始前に共有"
            ),
            "format.points|length.slightly": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "日時：明日10時30分開始\n欠席連絡：本日17時まで\n資料：開始前に共有",
                "日時：明日10時30分から\n連絡：難しい人は今日17時まで\n資料：事前に共有",
                "日時：明日10時30分開始\nご欠席の連絡：本日17時まで\n資料：開始前に共有"
            ),
            "format.points|length.very": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "日時：明日10時30分開始\n対応：参加できない場合は本日17時までに連絡",
                "日時：明日10時30分から\n対応：難しい人は今日17時までに連絡",
                "日時：明日10時30分開始\n対応：ご欠席の場合は本日17時までにご連絡ください"
            ),
            "format.points|length.oneSentence": practice(
                "明日の定例は10時30分開始に変更します。参加が難しい人は今日17時までに連絡してください。資料は開始前に共有します。",
                "要点：明日10時30分に定例を開始し、欠席連絡は本日17時まで、資料は開始前に共有",
                "要点：明日10時30分から定例、難しい人は今日17時までに連絡、資料は事前共有",
                "要点：明日10時30分に定例を開始し、ご欠席の連絡は本日17時まで、資料は開始前に共有"
            ),
        ]
    )

    private static func button(_ title: String, _ prompt: String) -> OnboardingButtonSpec {
        OnboardingButtonSpec(
            title: title,
            prompt: prompt,
            builtinKey: nil,
            origin: .onboardingBuilder
        )
    }

    private static func practice(
        _ input: String,
        _ standard: String,
        _ softer: String,
        _ morePolite: String
    ) -> OnboardingGeneratedPractice {
        // `buttonId` is filled in once the button is written to the prompt cache
        // and has an id.
        OnboardingGeneratedPractice(
            buttonId: "",
            input: input,
            outputs: [standard, softer, morePolite]
        )
    }
}

// MARK: - Shared chip UI

struct BuilderChipRow: View {
    let group: BuilderSlotGroup
    let selection: BuilderChip?
    @Binding var otherText: String
    var focusedOtherGroup: FocusState<String?>.Binding
    let onSelect: (BuilderChip) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(group.question)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)

            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(group.chips) { chip in
                    BuilderChipView(
                        label: chip.label,
                        isSelected: selection == chip,
                        onTap: { onSelect(chip) }
                    )
                }
            }

            if selection?.id == "other" {
                TextField(
                    "具体的に入力してください",
                    text: $otherText,
                    axis: .vertical
                )
                .font(.system(size: 15))
                .foregroundStyle(OnboardingPalette.ink)
                .focused(focusedOtherGroup, equals: group.id)
                .submitLabel(.done)
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(OnboardingPalette.fieldFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColor.purple, lineWidth: 1.2)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BuilderChipView: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : OnboardingPalette.ink)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule().fill(isSelected ? AppColor.purple : OnboardingPalette.fieldFill)
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.clear : OnboardingPalette.fieldStroke.opacity(0.5),
                        lineWidth: 0.6
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
