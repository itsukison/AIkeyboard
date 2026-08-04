import KeyboardPreferences
import SwiftUI

/// Shows the button(s) the user just built, one editable card each — name and
/// instruction both directly on the page.
///
/// This replaces the full prompt list for the builder arm. The list showed all
/// four buttons behind a tap-to-expand sheet, which buried the one thing the
/// user had actually just made among three they had not, and hid its
/// instruction behind an extra tap.
struct ButtonBuilderReviewPage: View {
    let progress: Double
    let onBack: () -> Void
    let onSkip: () -> Void
    let onAddAnother: () -> Void
    let onContinue: () -> Void

    @State private var entries: [UserPrompt] = []
    @FocusState private var focusedField: String?

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: { commitEdits(); onBack() },
            onSkip: { commitEdits(); onSkip() },
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: { commitEdits(); onContinue() },
            secondaryTitle: "もう1つボタンを作る",
            onSecondary: { commitEdits(); onAddAnother() },
            emphasizesSecondaryAction: true
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingTitleBlock(
                        title: entries.count > 1 ? "ボタンができました" : "ボタンが\nできました",
                        subtitle: "名前と指示は、ここで直接なおせます。"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 4)

                    ForEach($entries) { $entry in
                        BuilderButtonCard(entry: $entry, focusedField: $focusedField)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { entries = OnboardingPromptSetup.load().filter { $0.origin == .onboardingBuilder } }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focusedField = nil }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.purple)
            }
        }
    }

    /// Written on every exit rather than on each keystroke — `save` also
    /// re-normalises and re-publishes the whole set to the App Group, which is
    /// not something to do per character.
    private func commitEdits() {
        focusedField = nil
        guard !entries.isEmpty else { return }
        let cleaned = entries.map { entry -> UserPrompt in
            var copy = entry
            copy.title = OnboardingButtonName.clamp(entry.title)
            if copy.title.isEmpty { copy.title = "ボタン" }
            copy.prompt = entry.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            return copy
        }
        OnboardingPromptSetup.save(cleaned)
    }
}

private struct BuilderButtonCard: View {
    @Binding var entry: UserPrompt
    var focusedField: FocusState<String?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ボタン名")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.subInk.opacity(0.8))

                TextField("ボタン名", text: $entry.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                    .focused(focusedField, equals: "title-\(entry.id)")
                    .submitLabel(.done)
                    .onChange(of: entry.title) { newValue in
                        let clamped = OnboardingButtonName.clamp(newValue)
                        if clamped != newValue { entry.title = clamped }
                    }
            }

            Divider().overlay(OnboardingPalette.fieldStroke.opacity(0.4))

            VStack(alignment: .leading, spacing: 6) {
                Text("AIへの指示")
                    .font(.system(size: 12))
                    .foregroundStyle(OnboardingPalette.subInk.opacity(0.8))

                TextField("指示", text: $entry.prompt, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(OnboardingPalette.ink)
                    .focused(focusedField, equals: "prompt-\(entry.id)")
                    .lineLimit(2...8)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnboardingPalette.fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(OnboardingPalette.fieldStroke.opacity(0.5), lineWidth: 0.6)
        )
    }
}
