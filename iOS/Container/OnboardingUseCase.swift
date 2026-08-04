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

}

// MARK: - Button specs

/// The four fixed presets per use case that this page used to seed are gone.
/// They were the thing that did not work: 44% picked 敬語, whose preset was
/// identical to the default set, and the rest were permutations of the same
/// built-ins. Every use case now leads into `OnboardingButtonBuilder` instead.
struct OnboardingButtonSpec {
    let title: String
    let prompt: String
    let builtinKey: String?
    var origin: PromptOrigin = .onboardingBuilder
}

// MARK: - Custom (AI-generated) preset

enum OnboardingCustomPresetService {
    struct Request: Encodable {
        let description: String
        let useCase: String?
    }

    private struct Response: Decodable {
        struct Button: Decodable {
            let title: String
            let prompt: String
        }
        struct Practice: Decodable {
            let input: String
            let outputs: [String]
        }
        let buttons: [Button]
        /// Absent when the model didn't produce a usable example. The practice
        /// page then falls back to its built-in scenarios rather than failing.
        let practice: Practice?
    }

    struct Result {
        let specs: [OnboardingButtonSpec]
        /// `nil` when the model produced no usable example. The caller decides
        /// what to do — never persisted here, because the example has to be
        /// keyed to the button's id, which does not exist until it is committed.
        let practice: OnboardingGeneratedPractice?
    }

    /// Calls the `generate-prompt-preset` edge function (publishable-key callable,
    /// no sign-in required) and returns 4 button specs tailored to the user's
    /// use case, plus the worked example the practice page will replay for the
    /// main button.
    static func generate(description: String, useCase: String?) async throws -> Result {
        let response: Response = try await supabase.functions.invoke(
            "generate-prompt-preset",
            options: FunctionInvokeOptions(body: Request(description: description, useCase: useCase))
        )
        let specs = response.buttons.prefix(4).map {
            OnboardingButtonSpec(
                title: $0.title,
                prompt: $0.prompt,
                builtinKey: nil,
                origin: .onboardingBuilder
            )
        }
        guard specs.count == 4 else {
            throw OnboardingCustomPresetError.malformed
        }
        return Result(
            specs: specs,
            practice: response.practice.map {
                OnboardingGeneratedPractice(buttonId: "", input: $0.input, outputs: $0.outputs)
            }
        )
    }
}

enum OnboardingCustomPresetError: Error {
    case malformed
}

// MARK: - Use-case page

struct KeyboardUseCasePage: View {
    let progress: Double
    /// Non-empty when this is a replay for an extra button. The page is
    /// otherwise pixel-identical to the first pass, which reads as "the app went
    /// backwards" rather than "you are adding another one".
    var existingButtonTitles: [String] = []
    let onBack: () -> Void
    var onSkip: (() -> Void)? = nil
    /// Hands the chosen use case to the flow, which routes it into the button
    /// builder. This page no longer writes prompts itself — except for
    /// `.custom`, which collects its description here and has nothing left to
    /// ask on the builder pages.
    let onContinue: (OnboardingUseCase) -> Void

    @State private var selected: OnboardingUseCase?
    @State private var customText: String = ""
    @State private var isGenerating = false
    @State private var showError = false
    @FocusState private var customFieldFocused: Bool

    private var isAdditional: Bool { !existingButtonTitles.isEmpty }

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
                            title: isAdditional ? "次のボタンは\n何に使いますか？" : "何のために\n使いますか？",
                            subtitle: isAdditional
                                ? "さきほどとは別の用途を選ぶと、使い分けられるボタンになります。"
                                : "用途に合わせて、ぴったりのボタンを用意します。あとで自由に変更できます。"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                        if isAdditional {
                            ExistingButtonsBanner(titles: existingButtonTitles)
                                .padding(.top, 20)
                        }

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
                let result = await OnboardingButtonBuilderService.buildFromDescription(
                    description,
                    useCase: .custom
                )
                await MainActor.run {
                    isGenerating = false
                    guard let result, let main = result.specs.first else {
                        showError = true
                        return
                    }
                    // Only the main button is kept. The generator still returns
                    // four, but the three complements are buttons the user did
                    // not ask for, and shipping them back as "buttons you made"
                    // is the conflation this flow exists to remove.
                    OnboardingButtonBuilderService.commit(
                        OnboardingButtonBuilderService.Built(
                            spec: main,
                            practice: result.practice,
                            useCase: .custom,
                            source: "generated"
                        ),
                        replacing: nil
                    )
                    record(selected)
                    onContinue(selected)
                }
            }
            return
        }

        record(selected)
        onContinue(selected)
    }

    private func record(_ useCase: OnboardingUseCase) {
        AppAnalytics.capture("onboarding_use_case_selected", properties: [
            "use_case": useCase.rawValue,
        ])
    }
}

/// Names the buttons that already exist, so the replayed page reads as "adding
/// to a set" instead of "the first page again".
struct ExistingButtonsBanner: View {
    let titles: [String]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(AppColor.purple)

            Text("作成済み：\(titles.joined(separator: "・"))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColor.purple.opacity(0.09))
        )
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
        VStack(alignment: .leading, spacing: 8) {
            Text("何をするボタンですか？")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)

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
}
