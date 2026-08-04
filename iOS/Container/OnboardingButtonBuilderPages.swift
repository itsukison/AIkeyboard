import KeyboardPreferences
import SwiftUI

// MARK: - Page 2a — reusable preferences
//
// The common path is chip-only. Typing appears only after choosing その他. The
// free-text `custom` path already worked
// (its users run 98% of their rewrites on the button it produced) but only 2.5%
// of people ever chose it, because a blank field asks them to invent the
// structure of the answer.

struct ButtonBuilderSlotsPage: View {
    let progress: Double
    let spec: ButtonBuilderSpec
    /// Replay for an extra button — retitled so the page is not mistaken for the
    /// first pass.
    var isAdditional: Bool = false
    @Binding var selections: BuilderSelections
    let onBack: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void
    @FocusState private var focusedOtherGroup: String?

    private var canContinue: Bool {
        spec.pageAGroups.allSatisfy { group in
            guard let chip = selections.chip(group.id) else { return false }
            return chip.id != "other" || !selections.otherText(group.id).isEmpty
        }
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: { dismissKeyboard(); onBack() },
            onSkip: { dismissKeyboard(); onSkip() },
            ctaTitle: "次へ",
            isCtaEnabled: canContinue,
            onCta: { dismissKeyboard(); onContinue() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    OnboardingTitleBlock(
                        title: isAdditional ? "もう1つ\nボタンを作ります" : "あなた専用の\nボタンを作ります",
                        subtitle: "よく使う場面を選んでください。あとから自由に変更できます。"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    ForEach(spec.pageAGroups) { group in
                        BuilderChipRow(
                            group: group,
                            selection: selections.chip(group.id),
                            otherText: otherTextBinding(for: group.id),
                            focusedOtherGroup: $focusedOtherGroup,
                            onSelect: { chip in
                                withAnimation(.easeOut(duration: 0.16)) {
                                    selections.chips[group.id] = chip
                                }
                                focusedOtherGroup = chip.id == "other" ? group.id : nil
                            }
                        )
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { dismissKeyboard() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.purple)
            }
        }
    }

    private func otherTextBinding(for groupId: String) -> Binding<String> {
        Binding(
            get: { selections.otherTexts[groupId, default: ""] },
            set: { selections.otherTexts[groupId] = $0 }
        )
    }

    private func dismissKeyboard() {
        focusedOtherGroup = nil
    }
}

// MARK: - Page 2b — example-backed final choice

struct ButtonBuilderResultPage: View {
    let progress: Double
    let spec: ButtonBuilderSpec
    let useCase: OnboardingUseCase
    @Binding var selections: BuilderSelections
    /// The button this pass already produced, if the user stepped back here from
    /// the review page. Committing again replaces it rather than adding a
    /// duplicate.
    @Binding var builtButtonId: UUID?
    let onBack: () -> Void
    let onSkip: () -> Void
    /// Naming and editing happen on the review page that follows, not here —
    /// this page only settles the register.
    let onFinish: () -> Void

    @State private var isGenerating = false
    @State private var showError = false
    @FocusState private var focusedField: String?

    private var canContinue: Bool {
        !isGenerating && spec.isComplete(selections)
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: { dismissKeyboard(); onBack() },
            onSkip: { dismissKeyboard(); onSkip() },
            ctaTitle: "この内容で進む",
            isCtaEnabled: canContinue,
            isCtaLoading: isGenerating,
            onCta: commit
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Runtime-constructed rather than a literal because the
                    // question is per-use-case data; the onboarding strings are
                    // ja-source so nothing is lost by not extracting it.
                    OnboardingTitleBlock(
                        title: LocalizedStringKey(spec.toneGroup?.question ?? "この内容で\nボタンを作ります")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    if let toneGroup = spec.toneGroup {
                        toneSelector(toneGroup)
                    }

                    noteField

                    if showError {
                        Text("ボタンを作成できませんでした。もう一度お試しください。")
                            .font(.system(size: 13))
                            .foregroundStyle(OnboardingPalette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { dismissKeyboard() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.purple)
            }
        }
        .onAppear { showError = false }
    }

    // Each option shows the same sentence written at that register, so the
    // choice is made by reading the outcome rather than by parsing a label.
    private func toneSelector(_ group: BuilderSlotGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(group.chips) { chip in
                let isSelected = selections.chip(group.id) == chip
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        selections.chips[group.id] = chip
                    }
                    focusedField = chip.id == "other" ? group.id : nil
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 19))
                            .foregroundStyle(isSelected ? AppColor.purple : OnboardingPalette.subInk.opacity(0.35))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(chip.label)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(OnboardingPalette.ink)
                            if let sample = spec.toneSample(for: chip, selections: selections) {
                                Text("「\(sample)」")
                                    .font(.system(size: 14))
                                    .foregroundStyle(OnboardingPalette.subInk)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(OnboardingPalette.fieldFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isSelected ? AppColor.purple : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            if selections.chip(group.id)?.id == "other" {
                TextField(
                    "具体的に入力してください",
                    text: otherTextBinding(for: group.id),
                    axis: .vertical
                )
                .font(.system(size: 15))
                .foregroundStyle(OnboardingPalette.ink)
                .focused($focusedField, equals: group.id)
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
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(noteTitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)

            TextField(
                notePlaceholder,
                text: $selections.freeText,
                axis: .vertical
            )
            .font(.system(size: 15))
            .foregroundStyle(OnboardingPalette.ink)
            .focused($focusedField, equals: "note")
            .lineLimit(1...3)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(OnboardingPalette.fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(OnboardingPalette.fieldStroke.opacity(0.5), lineWidth: 0.6)
            )
        }
    }

    private var noteTitle: String {
        "ひとこと補足（任意）"
    }

    private var notePlaceholder: String {
        return "例：短く、わかりやすい文章にしてほしい"
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func otherTextBinding(for groupId: String) -> Binding<String> {
        Binding(
            get: { selections.otherTexts[groupId, default: ""] },
            set: { selections.otherTexts[groupId] = $0 }
        )
    }

    /// Only typed input reaches the model, so the common all-tap path completes
    /// without a spinner or a network call.
    private func commit() {
        dismissKeyboard()
        showError = false

        let fallback = OnboardingButtonBuilderService.templated(
            useCase: useCase,
            spec: spec,
            selections: selections
        )

        let note = selections.freeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty || selections.hasOtherChoice else {
            finish(with: fallback)
            return
        }

        let description = note.isEmpty
            ? spec.describe(selections)
            : spec.describe(selections) + "\n補足: \(note)"
        let name = spec.autoName(selections)
        isGenerating = true

        Task {
            let built = await OnboardingButtonBuilderService.generated(
                description: description,
                useCase: useCase,
                name: name
            )
            await MainActor.run {
                isGenerating = false
                finish(with: built ?? fallback)
            }
        }
    }

    private func finish(with built: OnboardingButtonBuilderService.Built?) {
        guard let built else {
            showError = true
            return
        }
        builtButtonId = OnboardingButtonBuilderService.commit(built, replacing: builtButtonId)
        onFinish()
    }
}
