import KeyboardPreferences
import Supabase
import SwiftUI

// MARK: - Use-case catalog
//
// The use-case page (right before the prompt-setup page) asks what the user
// wants the keyboard for and seeds a tailored set of 4 buttons, so people who
// came for translation / correction / casual writing get the right preset
// without discovering the prompt editor themselves.
//
// Each preset is 4 ordered buttons (index 0 = main). They are written onto the
// same local prompt cache the keyboard reads, and carried up to the account at
// sign-up. `builtinKey` is kept ONLY where the action genuinely matches one of
// the four seeded built-ins (so analytics `command_key` and the translate
// locale hint stay honest); every genuinely new action carries `nil` and is
// told apart in analytics by its title.

enum OnboardingUseCase: String, CaseIterable, Identifiable {
    case keigo
    case email
    case casual
    case translate
    case proofread
    case summarize
    case custom

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .keigo:     return "敬語に整える"
        case .email:     return "メール・ビジネス文書"
        case .casual:    return "カジュアル・フレンドリー"
        case .translate: return "翻訳する"
        case .proofread: return "日本語をチェック・添削"
        case .summarize: return "要約・わかりやすく"
        case .custom:    return "その他（AIにおまかせ）"
        }
    }

    var caption: LocalizedStringKey {
        switch self {
        case .keigo:     return "目上の人・ビジネス向けの丁寧な言い方に"
        case .email:     return "そのまま送れるメール本文に整える"
        case .casual:    return "友達やSNS向けの自然でやわらかい口調に"
        case .translate: return "英語・中国語などに翻訳する"
        case .proofread: return "文法や誤字、不自然な言い回しを直す"
        case .summarize: return "長い文章を短く、読みやすくする"
        case .custom:    return "使いたい用途を書くと、AIがボタンを作成"
        }
    }

    var symbol: String {
        switch self {
        case .keigo:     return "briefcase"
        case .email:     return "envelope"
        case .casual:    return "bubble.left.and.bubble.right"
        case .translate: return "globe"
        case .proofread: return "text.badge.checkmark"
        case .summarize: return "list.bullet.rectangle"
        case .custom:    return "wand.and.stars"
        }
    }

    /// The 4 fixed buttons for this use case (index 0 = main). `nil` for `.custom`,
    /// which is generated on-device from the user's free-text description.
    var presetButtons: [OnboardingButtonSpec]? {
        switch self {
        case .keigo:
            // Must equal the seeded default set exactly, so picking 敬語 leaves
            // existing/new accounts untouched.
            return [.builtin(UserPromptDefaults.politeKey), .builtin(UserPromptDefaults.naturalKey), .builtin(UserPromptDefaults.emailKey), .builtin(UserPromptDefaults.translateToEnglishKey)]
        case .email:
            return [.builtin(UserPromptDefaults.emailKey), .builtin(UserPromptDefaults.politeKey), .builtin(UserPromptDefaults.naturalKey), .builtin(UserPromptDefaults.translateToEnglishKey)]
        case .casual:
            return [.casual, .builtin(UserPromptDefaults.naturalKey), .builtin(UserPromptDefaults.politeKey), .builtin(UserPromptDefaults.translateToEnglishKey)]
        case .translate:
            return [.builtin(UserPromptDefaults.translateToEnglishKey), .translateToChinese, .builtin(UserPromptDefaults.naturalKey), .builtin(UserPromptDefaults.politeKey)]
        case .proofread:
            return [.proofread, .builtin(UserPromptDefaults.naturalKey), .builtin(UserPromptDefaults.politeKey), .casual]
        case .summarize:
            return [.summarize, .simplify, .builtin(UserPromptDefaults.politeKey), .builtin(UserPromptDefaults.naturalKey)]
        case .custom:
            return nil
        }
    }
}

// MARK: - Button specs

struct OnboardingButtonSpec {
    let title: String
    let prompt: String
    let builtinKey: String?

    /// Reuses an existing seeded built-in verbatim (keeps its key, so analytics
    /// and the translate locale hint stay correct).
    static func builtin(_ key: String) -> OnboardingButtonSpec {
        OnboardingButtonSpec(
            title: UserPromptDefaults.defaultTitle(for: key) ?? "",
            prompt: UserPromptDefaults.defaultPrompt(for: key) ?? "",
            builtinKey: key
        )
    }

    // New actions (builtinKey = nil). Prompts follow the house style: imperative
    // Japanese, preserve meaning, don't invent facts, output the rewritten text
    // only. The cloud function still returns 3 candidates per tap.

    static let casual = OnboardingButtonSpec(
        title: "カジュアル",
        prompt: "次の文章を、友達や親しい人に送るカジュアルで自然な日本語に書き直してください。\n\n敬語や堅い表現は避け、日常会話やSNSでそのまま送れるフレンドリーな口調にしてください。ただし乱暴・失礼な印象にはせず、親しみやすさを保ってください。\n原文の意味や意図は変えず、事実を付け足したり省いたりしないでください。絵文字は原文にある場合のみ活かし、無理に足さないでください。\n出力は書き直した文章だけにしてください。",
        builtinKey: nil
    )

    static let proofread = OnboardingButtonSpec(
        title: "添削",
        prompt: "あなたは日本語の校正者です。次の文章の文法・助詞・送りがな・誤字脱字・不自然な言い回しを修正し、自然で正しい日本語にしてください。\n\n書き手の本来の意味・意図・文体（丁寧さのレベル）は変えず、必要最小限の修正にとどめてください。情報を新たに付け足したり、勝手に敬語やカジュアルへ変換したりしないでください。誤りがない場合は原文のまま返してください。\n出力は修正後の文章だけにしてください。解説や修正理由は書かないでください。",
        builtinKey: nil
    )

    static let summarize = OnboardingButtonSpec(
        title: "要約",
        prompt: "次の文章を、要点を保ったまま簡潔に要約してください。\n\n重要な情報は落とさず、冗長な部分や繰り返しを削ってください。原文にない事実や解釈を付け加えないでください。元の文体・丁寧さのレベルは保ってください。\n出力は要約した文章だけにしてください。",
        builtinKey: nil
    )

    static let simplify = OnboardingButtonSpec(
        title: "わかりやすく",
        prompt: "次の文章を、意味を変えずに、より分かりやすく読みやすい日本語に書き直してください。\n\n難しい言葉や回りくどい表現は、平易で伝わりやすい言い方に置き換えてください。一文が長い場合は自然に区切ってください。情報を付け足したり省いたりしないでください。\n出力は書き直した文章だけにしてください。",
        builtinKey: nil
    )

    static let translateToChinese = OnboardingButtonSpec(
        title: "中国語訳",
        prompt: "次の文章を、自然で読みやすい中国語（簡体字）に翻訳してください。\n\n直訳ではなく、中国語のネイティブが日常的に使う自然な表現・語順にしてください。原文の意味やニュアンスを正確に伝え、固有名詞・数字・日付はそのまま保ってください。\n出力は翻訳した文章だけにしてください。",
        builtinKey: nil
    )
}

// MARK: - Applying a preset

enum OnboardingUseCasePreset {
    /// Builds the 4 ordered `UserPrompt` entries from a spec list. `slot`/`sortOrder`
    /// are placeholders — `OnboardingPromptSetup.save` normalizes index 0 to main.
    static func entries(from specs: [OnboardingButtonSpec]) -> [UserPrompt] {
        specs.enumerated().map { index, spec in
            UserPrompt(
                slot: index == 0 ? .main : .sub,
                builtinKey: spec.builtinKey,
                title: spec.title,
                prompt: spec.prompt,
                isEnabled: true,
                sortOrder: max(0, index - 1)
            )
        }
    }
}

// MARK: - Custom (AI-generated) preset

enum OnboardingCustomPresetService {
    struct Request: Encodable {
        let description: String
    }

    private struct Response: Decodable {
        struct Button: Decodable {
            let title: String
            let prompt: String
        }
        let buttons: [Button]
    }

    /// Calls the `generate-prompt-preset` edge function (publishable-key callable,
    /// no sign-in required) and returns 4 button specs tailored to the user's
    /// free-text use case.
    static func generate(description: String) async throws -> [OnboardingButtonSpec] {
        let response: Response = try await supabase.functions.invoke(
            "generate-prompt-preset",
            options: FunctionInvokeOptions(body: Request(description: description))
        )
        let specs = response.buttons.prefix(4).map {
            OnboardingButtonSpec(title: $0.title, prompt: $0.prompt, builtinKey: nil)
        }
        guard specs.count == 4 else {
            throw OnboardingCustomPresetError.malformed
        }
        return specs
    }
}

enum OnboardingCustomPresetError: Error {
    case malformed
}

// MARK: - Use-case page

struct KeyboardUseCasePage: View {
    let progress: Double
    let onBack: () -> Void
    var onSkip: (() -> Void)? = nil
    let onContinue: () -> Void

    @State private var selected: OnboardingUseCase?
    @State private var customText: String = ""
    @State private var isGenerating = false
    @State private var showError = false
    @FocusState private var customFieldFocused: Bool

    private var canContinue: Bool {
        guard let selected, !isGenerating else { return false }
        if selected == .custom {
            return !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: onSkip,
            ctaTitle: selected == .custom ? "ボタンを作成" : "次へ",
            isCtaEnabled: canContinue,
            isCtaLoading: isGenerating,
            onCta: handleContinue
        ) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        OnboardingTitleBlock(
                            title: "何のために\n使いますか？",
                            subtitle: "用途に合わせて、ぴったりのボタンを用意します。あとで自由に変更できます。"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                        VStack(spacing: 10) {
                            ForEach(OnboardingUseCase.allCases) { useCase in
                                UseCaseOptionCard(
                                    useCase: useCase,
                                    isSelected: selected == useCase,
                                    onTap: {
                                        withAnimation(.easeOut(duration: 0.16)) {
                                            selected = useCase
                                            showError = false
                                        }
                                        customFieldFocused = (useCase == .custom)
                                    }
                                )
                            }
                        }
                        .padding(.top, 28)

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.interactively)

                // Custom composer lives in a fixed footer above the CTA (not in
                // the scroll), so the keyboard can never crush it against the
                // button. It restates the picked option (which is scrolled out of
                // view behind the keyboard) and keeps a gap from the CTA.
                if selected == .custom {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(OnboardingPalette.fieldStroke.opacity(0.4))
                            .frame(height: 0.5)

                        VStack(alignment: .leading, spacing: 10) {
                            SelectedUseCaseChip(useCase: .custom)

                            CustomUseCaseField(text: $customText, isFocused: $customFieldFocused)

                            if showError {
                                Text("ボタンを作成できませんでした。少し待ってからもう一度お試しください。")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(OnboardingPalette.danger)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                    }
                    .background(OnboardingPalette.background)
                    .transition(.opacity)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { customFieldFocused = false }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.purple)
                }
            }
        }
    }

    private func handleContinue() {
        guard let selected else { return }
        showError = false
        customFieldFocused = false

        if selected == .custom {
            let description = customText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { return }
            isGenerating = true
            Task {
                do {
                    let specs = try await OnboardingCustomPresetService.generate(description: description)
                    await MainActor.run {
                        isGenerating = false
                        apply(selected, specs: specs)
                    }
                } catch {
                    await MainActor.run {
                        isGenerating = false
                        showError = true
                    }
                }
            }
            return
        }

        guard let specs = selected.presetButtons else { return }
        apply(selected, specs: specs)
    }

    private func apply(_ useCase: OnboardingUseCase, specs: [OnboardingButtonSpec]) {
        OnboardingPromptSetup.save(OnboardingUseCasePreset.entries(from: specs))
        AppAnalytics.capture("onboarding_use_case_selected", properties: [
            "use_case": useCase.rawValue,
        ])
        onContinue()
    }
}

private struct UseCaseOptionCard: View {
    let useCase: OnboardingUseCase
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? AppColor.purple.opacity(0.12) : OnboardingPalette.background)
                    Image(systemName: useCase.symbol)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(isSelected ? AppColor.purple : OnboardingPalette.ink)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(useCase.title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(OnboardingPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(useCase.caption)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(OnboardingPalette.subInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(isSelected ? AppColor.purple : OnboardingPalette.subInk.opacity(0.35))
            }
            .padding(.leading, 12)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(OnboardingPalette.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? AppColor.purple : Color.clear, lineWidth: isSelected ? 1.5 : 0)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(UseCaseCardPressStyle())
        .accessibilityLabel(useCase.title)
        .accessibilityHint(useCase.caption)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct UseCaseCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Compact restatement of the picked use case, shown in the pinned composer so
/// the user still sees what they're configuring while the option list is hidden
/// behind the keyboard.
private struct SelectedUseCaseChip: View {
    let useCase: OnboardingUseCase

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(AppColor.purple.opacity(0.12))
                Image(systemName: useCase.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.purple)
            }
            .frame(width: 26, height: 26)

            Text(useCase.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(OnboardingPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(AppColor.purple)
        }
    }
}

private struct CustomUseCaseField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(
            "例：中国語を自然な日本語に直す",
            text: $text,
            axis: .vertical
        )
        .font(.system(size: 16, weight: .regular))
        .foregroundStyle(OnboardingPalette.ink)
        .focused(isFocused)
        .submitLabel(.done)
        .lineLimit(1...3)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(OnboardingPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OnboardingPalette.fieldStroke.opacity(0.5), lineWidth: 0.6)
        )
    }
}
