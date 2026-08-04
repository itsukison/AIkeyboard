import KeyboardKit
import KeyboardPreferences
import SwiftUI
import UIKit

// MARK: - Input style page

struct KeyboardInputStylePage: View {
    let progress: Double
    let onBack: (() -> Void)?
    @Binding var selectedStyle: KeyboardPreferences.KeyboardStyle
    var onSkip: (() -> Void)? = nil
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: onBack != nil,
            onBack: onBack,
            onSkip: onSkip,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    OnboardingTitleBlock(
                        title: "入力方式を\n選びましょう",
                        subtitle: "ふだん使っているキーボードに合わせて選べます。あとから設定でいつでも変更できます。"
                    )
                    .padding(.top, 24)

                    HStack(spacing: 12) {
                        ForEach(InputStyleOption.selectable, id: \.self) { style in
                            InputStyleSelectionCard(
                                style: style,
                                isSelected: selectedStyle == style,
                                onTap: { selectedStyle = style }
                            )
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Setup page

struct KeyboardSetupPage: View {
    let progress: Double
    let onBack: (() -> Void)?
    let onSkip: (() -> Void)?
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var keyboardStatus = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")
    @State private var didOpenSettings = false
    @State private var showNotEnabledHint = false

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: onBack != nil,
            onBack: onBack,
            onSkip: onSkip,
            ctaTitle: "設定を開く",
            isCtaEnabled: true,
            onCta: openSettings
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    OnboardingTitleBlock(
                        title: "敬語ボタンを\nキーボードに追加",
                        subtitle: "一度追加すると、LINEやメールの入力中にそのまま使えます。AIはボタンを押した時だけ、今の文章を書き直します。"
                    )
                    .padding(.top, 24)

                    SettingsMockCard()
                        .padding(.top, 4)

                    if showNotEnabledHint {
                        Text("まだ追加されていないようです。「設定を開く」→「キーボード」から「敬語ボタン」をオンにしてください。")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(OnboardingPalette.danger)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    }

                    Button {
                        onContinue()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                            Text("追加済みなので次へ")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(OnboardingPalette.ink.opacity(0.82))
                        .padding(.horizontal, 18)
                        .frame(minHeight: 40)
                        .background(OnboardingPalette.fieldFill, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(OnboardingPalette.fieldStroke.opacity(0.55), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .onChange(of: scenePhase) { phase in
            // Only react after the user actually went to Settings, so an
            // unrelated backgrounding (call, app switch) can't jump the page.
            guard phase == .active, didOpenSettings else { return }
            keyboardStatus.refresh()
            if keyboardStatus.isKeyboardEnabled {
                didOpenSettings = false
                onContinue()
            } else {
                showNotEnabledHint = true
            }
        }
    }

    private func openSettings() {
        didOpenSettings = true
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

private struct SettingsMockCard: View {
    var body: some View {
        VStack {
            PhoneFrameMock {
                SettingsKeyboardsMock()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

private struct PhoneFrameMock<Inner: View>: View {
    @ViewBuilder var inner: () -> Inner

    var body: some View {
        VStack(spacing: 0) {
            // Mini status bar
            HStack {
                Text(verbatim: "4:36")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))
                Spacer()
                Capsule()
                    .fill(Color(uiColor: .label))
                    .frame(width: 78, height: 18)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "wifi")
                        .font(.system(size: 9, weight: .semibold))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(uiColor: .label))
                        .frame(width: 18, height: 9)
                }
                .foregroundStyle(Color(uiColor: .label))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))

            inner()
                .background(Color(uiColor: .systemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        )
    }
}

private struct SettingsKeyboardsMock: View {
    var body: some View {
        VStack(spacing: 12) {
            // Nav bar
            ZStack {
                Text(verbatim: "キーボード")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))
                HStack {
                    ZStack {
                        Circle().fill(Color(uiColor: .tertiarySystemFill)).frame(width: 22, height: 22)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // Toggle rows
            VStack(spacing: 0) {
                SettingsToggleRow(label: "敬語ボタン", isOn: true, showDivider: true)
                SettingsToggleRow(label: localizedAppString("フルアクセスを許可"), isOn: true, showDivider: false, iconName: "keyboard")
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 14)

            Text("AIで書き直すために必要です。通常の入力中に勝手に送信されることはありません。")
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
                .padding(.horizontal, 22)
                .padding(.top, 2)
                .lineSpacing(2)

            // Permission dialog
            VStack(alignment: .leading, spacing: 6) {
                Text("“敬語ボタン”に\nフルアクセスを許可しますか？")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .label))
                    .lineSpacing(1)
                Text("AIボタンを押した時だけ、今の文章を敬語に書き直します。")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .lineSpacing(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 14)
        }
    }
}

private struct SettingsToggleRow: View {
    let label: String
    let isOn: Bool
    let showDivider: Bool
    var iconName: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if let iconName {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(uiColor: .systemGray3))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(.white)
                        )
                }
                Text(verbatim: label)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(uiColor: .label))
                Spacer()
                MiniToggle(isOn: isOn)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)

            if showDivider {
                Rectangle()
                    .fill(Color(uiColor: .separator))
                    .frame(height: 0.5)
                    .padding(.leading, iconName == nil ? 12 : 38)
            }
        }
    }
}

private struct MiniToggle: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color(red: 0.20, green: 0.78, blue: 0.35) : Color(uiColor: .systemGray3))
                .frame(width: 28, height: 16)
            Circle()
                .fill(.white)
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 0.5)
                .padding(1.5)
        }
    }
}

// MARK: - Usage page

struct KeyboardUsagePage: View {
    let progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void
    var style: KeyboardPreferences.KeyboardStyle = .japaneseRomaji

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("送信前に\n3つの敬語候補。")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("候補バーの敬語ボタンから、よく使う書き換えをすぐ選べます。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)

                    KeyboardMockCard(style: style)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct KeyboardMockCard: View {
    let style: KeyboardPreferences.KeyboardStyle

    var body: some View {
        NativeKeyboardSurfaceMock(mode: .toolbar, style: style)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppColor.surfaceElevated)
            )
    }
}

struct KeyboardResultPage: View {
    let progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("候補をフリックして\nそのまま置き換え。")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("生成後はカードを横に動かして比較できます。\n選んだ候補で文章を置き換えます。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)

                    KeyboardResultMockCard()
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct KeyboardResultMockCard: View {
    var body: some View {
        NativeKeyboardSurfaceMock(mode: .result)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppColor.surfaceElevated)
            )
    }
}

// MARK: - Reply page

struct KeyboardReplyPage: View {
    let progress: Double
    let onBack: () -> Void
    let onContinue: () -> Void
    var style: KeyboardPreferences.KeyboardStyle = .japaneseRomaji

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: nil,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 14) {
                        Text("コピーした文に\nワンタップで返信。")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("相手のメッセージをコピーすると、ツールバーに返信ボタンが出ます。押すだけで返信文の候補を作成します。")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(OnboardingPalette.subInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(.top, 40)

                    KeyboardReplyMockCard(style: style)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct KeyboardReplyMockCard: View {
    let style: KeyboardPreferences.KeyboardStyle

    var body: some View {
        NativeKeyboardSurfaceMock(mode: .reply, style: style)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppColor.surfaceElevated)
            )
    }
}

// MARK: - Prompts customization page

private func onboardingOrderedPrompts(_ raw: [UserPrompt]) -> [UserPrompt] {
    let mains = raw.filter { $0.slot == .main }.sorted { $0.sortOrder < $1.sortOrder }
    let subs = raw.filter { $0.slot == .sub }.sorted { $0.sortOrder < $1.sortOrder }
    return mains + subs
}

private func onboardingNormalizedPrompts(_ ordered: [UserPrompt]) -> [UserPrompt] {
    var result = ordered
    for index in result.indices {
        result[index].slot = index == 0 ? .main : .sub
        result[index].sortOrder = max(0, index - 1)
        if index == 0 { result[index].isEnabled = true }
    }
    return result
}

struct KeyboardPromptsPage: View {
    let progress: Double
    /// Shown as the secondary action when the user has buttons of their own to
    /// add to. `nil` hides it.
    var onAddAnother: (() -> Void)? = nil
    let onBack: () -> Void
    var onSkip: (() -> Void)? = nil
    let onContinue: () -> Void

    @State private var entries: [UserPrompt] = OnboardingPromptSetup.load()
    @State private var editorEntry: UserPrompt?
    @State private var hasOpenedEditor = false

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: onSkip,
            ctaTitle: "次へ",
            isCtaEnabled: true,
            onCta: onContinue,
            secondaryTitle: onAddAnother == nil ? nil : "もう1つボタンを作る",
            onSecondary: onAddAnother,
            emphasizesSecondaryAction: onAddAnother != nil
        ) {
            VStack(spacing: 16) {
                OnboardingTitleBlock(
                    title: "あなた専用の\nボタンができました",
                    subtitle: "タップすると名前や指示を自由に書き換えられます。長押しで並び替え、左スワイプで削除。一番上がメインボタンです。"
                )
                .padding(.horizontal, 20)
                .padding(.top, 24)

                List {
                    Section {
                        ForEach(entries) { entry in
                            OnboardingPromptRow(
                                entry: entry,
                                isMain: entry.id == entries.first?.id,
                                showsEditHint: entry.id == entries.first?.id && !hasOpenedEditor,
                                onTap: {
                                    hasOpenedEditor = true
                                    editorEntry = entry
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(AppColor.surface)
                            .listRowSeparatorTint(AppColor.rule.opacity(0.35))
                        }
                        .onMove(perform: moveEntries)
                        .onDelete(perform: deleteEntries)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .background(ReorderLiftTuner())
            }
        }
        .onAppear {
            entries = OnboardingPromptSetup.load()
        }
        .sheet(item: $editorEntry) { entry in
            OnboardingPromptEditorSheet(
                entry: entry,
                onSave: { updated in
                    saveEntry(updated)
                    editorEntry = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(32)
            .presentationBackground(OnboardingPalette.background)
        }
    }

    private func moveEntries(from source: IndexSet, to destination: Int) {
        var reordered = entries
        reordered.move(fromOffsets: source, toOffset: destination)
        let normalized = onboardingNormalizedPrompts(reordered)
        entries = normalized
        OnboardingPromptSetup.save(normalized)
        AppAnalytics.capture("onboarding_prompt_reordered")
    }

    /// The keyboard needs a main button, so the last row cannot be deleted —
    /// the swipe simply does nothing rather than being conditionally absent,
    /// which would make the gesture appear and disappear as the list shrinks.
    private func deleteEntries(at offsets: IndexSet) {
        var remaining = entries
        remaining.remove(atOffsets: offsets)
        guard !remaining.isEmpty else { return }
        let normalized = onboardingNormalizedPrompts(remaining)
        entries = normalized
        OnboardingPromptSetup.save(normalized)
        AppAnalytics.capture("onboarding_prompt_deleted", properties: [
            "remaining": normalized.count,
            "onboarding_version": InteractiveOnboardingState.version,
        ])
    }

    private func saveEntry(_ updated: UserPrompt) {
        guard let index = entries.firstIndex(where: { $0.id == updated.id }) else { return }
        entries[index] = updated
        let normalized = onboardingNormalizedPrompts(entries)
        entries = normalized
        OnboardingPromptSetup.save(normalized)
    }
}

/// Guest-local read/write for onboarding prompt edits. The keyboard reads the
/// same App Group prompt cache immediately, and `UserSession.signUp` carries
/// this pending set up to the new account before the server cache refresh.
enum OnboardingPromptSetup {
    static func load() -> [UserPrompt] {
        if let pending = KeyboardSettingsStore.readPendingOnboardingPromptEntries(), !pending.isEmpty {
            return onboardingOrderedPrompts(pending)
        }
        let stored = UserPromptStore.readEntries()
        if !stored.isEmpty {
            return onboardingOrderedPrompts(stored)
        }
        let seeded = UserPromptDefaults.seedEntries()
        UserPromptStore.writeEntries(seeded)
        return onboardingOrderedPrompts(seeded)
    }

    static func save(_ entries: [UserPrompt]) {
        let normalized = onboardingNormalizedPrompts(entries)
        UserPromptStore.writeEntries(normalized)
        if isDefaultPromptSet(normalized) {
            KeyboardSettingsStore.clearPendingOnboardingPromptEntries()
            KeyboardSettingsStore.clearPendingOnboardingMainPrompt()
        } else {
            KeyboardSettingsStore.writePendingOnboardingPromptEntries(normalized)
            if let main = normalized.first {
                KeyboardSettingsStore.writePendingOnboardingMainPrompt(title: main.title, prompt: main.prompt)
            }
            AppAnalytics.capture("onboarding_prompts_customized")
        }
    }

    static func defaultEntry(for entry: UserPrompt) -> UserPrompt? {
        guard
            let key = entry.builtinKey,
            let title = UserPromptDefaults.defaultTitle(for: key),
            let prompt = UserPromptDefaults.defaultPrompt(for: key)
        else { return nil }
        var reset = entry
        reset.title = title
        reset.prompt = prompt
        reset.updatedAt = Date()
        return reset
    }

    private static func isDefaultPromptSet(_ entries: [UserPrompt]) -> Bool {
        let current = onboardingNormalizedPrompts(onboardingOrderedPrompts(entries))
        let defaults = onboardingNormalizedPrompts(onboardingOrderedPrompts(UserPromptDefaults.seedEntries()))
        guard current.count == defaults.count else { return false }
        return zip(current, defaults).allSatisfy { lhs, rhs in
            lhs.slot == rhs.slot
                && lhs.builtinKey == rhs.builtinKey
                && lhs.title == rhs.title
                && lhs.prompt == rhs.prompt
                && lhs.isEnabled == rhs.isEnabled
                && lhs.sortOrder == rhs.sortOrder
        }
    }
}

/// Prompt row rendered like the real Prompts screen, with an explicit edit
/// affordance and a drag handle. The main row carries a repeating shimmer +
/// pencil pulse (until the user opens the editor once) so "tap to customize"
/// is shown, not just told.
private struct OnboardingPromptRow: View {
    let entry: UserPrompt
    let isMain: Bool
    var showsEditHint: Bool = false
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = 0
    @State private var hintPulse = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: BikeyMetrics.Spacing.s) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(verbatim: entry.title)
                            .bikeyFont(17, weight: .medium, relativeTo: .body)
                            .foregroundStyle(AppColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(isMain ? "メイン" : "追加")
                            .bikeyFont(11, weight: .medium, relativeTo: .caption)
                            .foregroundStyle(AppColor.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColor.purple.opacity(0.1), in: Capsule())
                    }

                    Text(verbatim: entry.prompt)
                        .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ZStack {
                    Circle()
                        .fill(hintPulse ? AppColor.purple.opacity(0.22) : AppColor.lavenderMist.opacity(0.9))
                        .frame(width: 32, height: 32)
                    Circle()
                        .stroke(AppColor.purple.opacity(hintPulse ? 0.58 : 0.18), lineWidth: hintPulse ? 2 : 1)
                        .frame(width: 32, height: 32)
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColor.purple)
                }
                .scaleEffect(hintPulse ? 1.28 : 1)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m + 4)
            .padding(.vertical, BikeyMetrics.Spacing.m - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(OnboardingPromptPressStyle())
        .overlay {
            if showsEditHint {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, AppColor.purple.opacity(0.20), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.55)
                    .offset(x: -0.55 * geo.size.width + shimmerPhase * 1.55 * geo.size.width)
                }
                .allowsHitTesting(false)
                .clipped()
            }
        }
        .task(id: showsEditHint) {
            guard showsEditHint, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.78)) { shimmerPhase = 1 }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { hintPulse = true }
                try? await Task.sleep(nanoseconds: 650_000_000)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { hintPulse = false }
                try? await Task.sleep(nanoseconds: 650_000_000)
                shimmerPhase = 0
            }
        }
    }
}

private struct OnboardingPromptPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Compact prompt editor for onboarding: title + prompt, keep-default via
/// デフォルトに戻す. Mirrors the in-app editor's shape without depending on it.
private struct OnboardingPromptEditorSheet: View {
    let entry: UserPrompt
    let onSave: (UserPrompt) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var prompt: String

    private let promptCharLimit = 1000

    init(entry: UserPrompt, onSave: @escaping (UserPrompt) -> Void) {
        self.entry = entry
        self.onSave = onSave
        _title = State(initialValue: entry.title)
        _prompt = State(initialValue: entry.prompt)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && prompt.count <= promptCharLimit
    }

    private var isDefault: Bool {
        guard let defaultEntry = OnboardingPromptSetup.defaultEntry(for: entry) else { return false }
        return title == defaultEntry.title && prompt == defaultEntry.prompt
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("キャンセル") { dismiss() }
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
                Spacer()
                Button("これにする") {
                    var updated = entry
                    updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.updatedAt = Date()
                    onSave(updated)
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(canSave ? AppColor.purple : OnboardingPalette.subInk)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("「\(entry.title)」ボタン")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                        .padding(.top, 8)

                    field(label: "ボタン名") {
                        TextField("敬語", text: $title)
                            .font(.system(size: 16, weight: .regular))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(OnboardingPalette.ink)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .onChange(of: title) { newValue in
                                if newValue.count > 24 { title = String(newValue.prefix(24)) }
                            }
                    }

                    field(label: "書き換え方（AIへの指示）") {
                        TextEditor(text: $prompt)
                            .font(.system(size: 15, weight: .regular))
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(OnboardingPalette.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minHeight: 180)
                            .onChange(of: prompt) { newValue in
                                if newValue.count > promptCharLimit {
                                    prompt = String(newValue.prefix(promptCharLimit))
                                }
                            }
                    }

                    if !isDefault {
                        Button {
                            guard let defaultEntry = OnboardingPromptSetup.defaultEntry(for: entry) else { return }
                            title = defaultEntry.title
                            prompt = defaultEntry.prompt
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 14, weight: .regular))
                                Text("デフォルトに戻す")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .foregroundStyle(OnboardingPalette.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(OnboardingPalette.fieldFill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(OnboardingPalette.background.ignoresSafeArea())
    }

    @ViewBuilder
    private func field<Content: View>(label: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(OnboardingPalette.subInk)
            content()
                .background(OnboardingPalette.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(OnboardingPalette.fieldStroke.opacity(0.5), lineWidth: 0.6)
                )
        }
    }
}

/// A faithful 1:1 slice of the real `PromptsScreen`: "メインボタン" and
/// "追加ボタン" sections of white cards with a floating "+" action. On a loop,
/// a new custom button springs into the 追加ボタン list to show that users can
/// add their own. Uses the same Bikey tokens as the live screen so it matches
/// the app exactly. Honors reduce-motion by resting fully shown.
private struct PromptsCustomizeMock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showNew = false
    @State private var pressFAB = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                section("メインボタン") {
                    MockPromptRow(title: "敬語", detail: "丁寧でやわらかい敬語に変換します。")
                }

                section("追加ボタン") {
                    VStack(spacing: 0) {
                        MockPromptRow(title: "やさしく", detail: "もっとやわらかい言い方に。")
                        rule
                        MockPromptRow(title: "短く", detail: "要点だけ簡潔にまとめます。")
                        if showNew {
                            rule
                            MockPromptRow(title: "カジュアル", detail: "友達に送る軽い感じに。")
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }

            Circle()
                .fill(AppColor.charcoalAction)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .scaleEffect(pressFAB ? 0.86 : 1.0)
                .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
        }
        .task(id: reduceMotion) { await runLoop() }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.s) {
            Text(verbatim: title)
                .bikeyFont(13, weight: .medium, relativeTo: .footnote)
                .foregroundStyle(AppColor.muted)
                .padding(.leading, 4)

            content()
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
        }
    }

    private var rule: some View {
        Rectangle()
            .fill(AppColor.rule.opacity(0.35))
            .frame(height: 0.5)
            .padding(.leading, BikeyMetrics.Spacing.m + 4)
    }

    @MainActor
    private func runLoop() async {
        guard !reduceMotion else {
            showNew = true
            return
        }
        showNew = false
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressFAB = true }
            try? await Task.sleep(nanoseconds: 170_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { showNew = true }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressFAB = false }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { showNew = false }
        }
    }
}

/// Mirrors `PromptsScreen.PromptRow` (title + prompt preview + chevron).
private struct MockPromptRow: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .center, spacing: BikeyMetrics.Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title)
                    .bikeyFont(17, weight: .medium, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)

                Text(verbatim: detail)
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppColor.softText)
        }
        .padding(.horizontal, BikeyMetrics.Spacing.m + 4)
        .padding(.vertical, BikeyMetrics.Spacing.m - 2)
    }
}

// MARK: - Consent page

struct KeyboardConsentPage: View {
    let progress: Double
    let onBack: () -> Void
    var onSkip: (() -> Void)? = nil
    let onAgree: (Bool) -> Void
    let onDecline: () -> Void

    @State private var showPrivacy = false
    @State private var agreedToPolicy = false
    @State private var commercialOptIn = false

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: onBack,
            onSkip: onSkip,
            ctaTitle: "同意してはじめる",
            isCtaEnabled: agreedToPolicy,
            onCta: { onAgree(commercialOptIn) },
            secondaryTitle: "今は使わない（通常のキーボードとして利用）",
            onSecondary: onDecline
        ) {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        OnboardingTitleBlock(
                            title: "AIに送る前に\n確認してください",
                            subtitle: "敬語ボタンを押した時だけ、その文章がAIサービスに送信されます。通常の入力が送信されることはありません。"
                        )
                        .padding(.top, 24)

                        ConsentDataCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }

                VStack(spacing: 12) {
                    CommercialConsentCheckbox(isOn: $commercialOptIn)

                    ConsentAgreementCheckbox(
                        isOn: $agreedToPolicy,
                        onOpenPrivacy: { showPrivacy = true }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: LegalLinks.privacy)
        }
    }
}

// Optional (opt-in) commercial data-use consent, shown above the required
// policy-agreement checkbox. Not required to proceed — the CTA is gated only by
// the policy checkbox. Copy names the real purpose (dataset creation incl.
// third-party provision) with a hedged, secondary benefit line.
private struct CommercialConsentCheckbox: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                isOn.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn ? OnboardingPalette.selectedControlFill : OnboardingPalette.fieldFill)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(isOn ? Color.clear : OnboardingPalette.fieldStroke, lineWidth: 1.5)
                        )

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("日本語AIの改善のためのデータ利用に同意する（任意）")
            .accessibilityAddTraits(isOn ? [.isSelected] : [])

            VStack(alignment: .leading, spacing: 2) {
                Text("【任意】日本語AIの改善に協力する")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OnboardingPalette.ink)
                Text("入力・変換データを匿名化し、日本語AIの学習用データセットの作成・提供（第三者提供を含む）に利用することを許可します。オンにしなくてもすべての機能をご利用いただけ、品質向上により将来的に変換精度の改善につながる可能性があります。")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(OnboardingPalette.subInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ConsentDataCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AIサービスに送信される内容")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(OnboardingPalette.subInk)

            VStack(alignment: .leading, spacing: 14) {
                ConsentDataRow(icon: "text.alignleft", text: "入力したテキスト")
                ConsentDataRow(icon: "wand.and.stars", text: "使用した機能の種類（敬語・メール・翻訳など）")
                ConsentDataRow(icon: "info.circle", text: "処理に関する技術情報（文字数・処理日時など）")
            }

            Divider()
                .overlay(OnboardingPalette.fieldStroke.opacity(0.55))

            ConsentDataRow(icon: "cpu", text: "送信先：第三者のAIサービス")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(OnboardingPalette.fieldFill)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

private struct ConsentAgreementCheckbox: View {
    @Binding var isOn: Bool
    let onOpenPrivacy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                isOn.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn ? OnboardingPalette.selectedControlFill : OnboardingPalette.fieldFill)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(isOn ? Color.clear : OnboardingPalette.fieldStroke, lineWidth: 1.5)
                        )

                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44, alignment: .top)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("プライバシーポリシーの内容に同意する")
            .accessibilityAddTraits(isOn ? [.isSelected] : [])

            Text(.init(localizedAppString("[プライバシーポリシー](\(LegalLinks.privacy.absoluteString))の内容に同意します")))
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .tint(AppColor.purple)
                .environment(\.openURL, OpenURLAction { _ in
                    onOpenPrivacy()
                    return .handled
                })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ConsentDataRow: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .frame(width: 22)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

enum NativeKeyboardSurfaceMode {
    case toolbar
    case result
    case reply
}

struct NativeKeyboardSurfaceMock: View {
    let mode: NativeKeyboardSurfaceMode
    var style: KeyboardPreferences.KeyboardStyle = .japaneseRomaji

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var cardIndex = 0
    @State private var showReply = false

    private let designSize = CGSize(width: 390, height: 266)

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designSize.width

            ZStack(alignment: .topLeading) {
                content
                    .frame(width: designSize.width, height: designSize.height)
                    .scaleEffect(scale, anchor: .topLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .aspectRatio(designSize.width / designSize.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: reduceMotion) {
            await runDemoLoop()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .toolbar:
            VStack(spacing: 8) {
                NativeToolbarDemo(isExpanded: isExpanded)
                if style == .japaneseFlick {
                    NativeFlickRows(keyHeight: 45)
                } else {
                    NativeKeyboardRows()
                    NativeKeyboardAccessoryRow()
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(NativeKeyboardStyle.surface)
        case .result:
            NativeResultDemo(selectedIndex: cardIndex)
                .background(NativeKeyboardStyle.surface)
        case .reply:
            VStack(spacing: 8) {
                NativeIncomingMessageBubble()
                NativeReplyToolbarDemo(showReply: showReply)
                if style == .japaneseFlick {
                    NativeFlickRows(keyHeight: 33)
                } else {
                    NativeKeyboardRows()
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .background(NativeKeyboardStyle.surface)
        }
    }

    @MainActor
    private func runDemoLoop() async {
        guard !reduceMotion else {
            isExpanded = mode == .toolbar
            cardIndex = 0
            showReply = mode == .reply
            return
        }

        switch mode {
        case .toolbar:
            isExpanded = false
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 900_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isExpanded = true
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    isExpanded = false
                }
            }
        case .result:
            cardIndex = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_350_000_000)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                    cardIndex = (cardIndex + 1) % 3
                }
            }
        case .reply:
            showReply = false
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showReply = true
                }
                try? await Task.sleep(nanoseconds: 1_900_000_000)
                withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                    showReply = false
                }
            }
        }
    }
}

private enum NativeKeyboardStyle {
    static let surface = OnboardingPalette.adaptive(
        light: Color(red: 0.86, green: 0.87, blue: 0.89),
        dark: Color(red: 0.11, green: 0.11, blue: 0.12)
    )
    static let keyFill = OnboardingPalette.adaptive(
        light: Color.white.opacity(0.96),
        dark: Color(red: 0.34, green: 0.34, blue: 0.36)
    )
    static let specialKey = OnboardingPalette.adaptive(
        light: Color(red: 0.74, green: 0.76, blue: 0.78),
        dark: Color(red: 0.20, green: 0.20, blue: 0.22)
    )
    static let ink = OnboardingPalette.adaptive(
        light: Color(red: 0.129, green: 0.129, blue: 0.155),
        dark: Color(red: 0.95, green: 0.95, blue: 0.96)
    )
    static let accent = AppColor.purple
    static let accentSoft = AppColor.paleLavender
    static let translucentFill = OnboardingPalette.adaptive(
        light: Color.white.opacity(0.72),
        dark: Color.white.opacity(0.10)
    )
    static let panelFill = OnboardingPalette.adaptive(
        light: Color.white,
        dark: Color(red: 0.16, green: 0.16, blue: 0.18)
    )
}

private struct NativeToolbarDemo: View {
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 6) {
            if !isExpanded {
                NativeToolbarPill(title: "敬語", isSelected: false)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            NativeToolbarPill(title: "…", isSelected: isExpanded, minWidth: 36)

            if isExpanded {
                HStack(spacing: 6) {
                    NativeToolbarPill(title: "自然に", isSelected: false)
                    NativeToolbarPill(title: "メール", isSelected: false)
                    NativeToolbarPill(title: "英訳", isSelected: false)
                    Spacer(minLength: 6)
                    NativeToolbarPill(title: "設定", isSelected: false)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .frame(height: 46)
        .padding(.horizontal, 6)
        .clipped()
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isExpanded)
    }
}

private struct NativeToolbarPill: View {
    let title: String
    let isSelected: Bool
    var minWidth: CGFloat? = nil

    var body: some View {
        Text(verbatim: title)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(NativeKeyboardStyle.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 12)
            .frame(minWidth: minWidth, minHeight: 38)
            .background(
                isSelected ? NativeKeyboardStyle.accentSoft : NativeKeyboardStyle.translucentFill,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? NativeKeyboardStyle.accent : Color.clear, lineWidth: 1.2)
            )
    }
}

private struct NativeIncomingMessageBubble: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(NativeKeyboardStyle.accentSoft)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(NativeKeyboardStyle.accent.opacity(0.7))
                )

            Text(verbatim: "明日の10時で大丈夫ですか？")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(NativeKeyboardStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 6)

            HStack(spacing: 3) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10, weight: .semibold))
                Text(verbatim: "コピー済み")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(NativeKeyboardStyle.accent)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(NativeKeyboardStyle.accentSoft, in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(NativeKeyboardStyle.panelFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 6)
    }
}

private struct NativeReplyToolbarDemo: View {
    let showReply: Bool

    var body: some View {
        HStack(spacing: 6) {
            if showReply {
                NativeReplyPill()
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            NativeToolbarPill(title: "敬語", isSelected: false)
            NativeToolbarPill(title: "…", isSelected: false, minWidth: 36)

            Spacer(minLength: 0)
        }
        .frame(height: 46)
        .padding(.horizontal, 6)
        .clipped()
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: showReply)
    }
}

private struct NativeReplyPill: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowshape.turn.up.left")
                .font(.system(size: 15, weight: .semibold))
            Text(verbatim: "返信")
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(NativeKeyboardStyle.accent)
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(
            NativeKeyboardStyle.translucentFill,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}

// A static depiction of the 10-key flick kana grid, mirroring the real
// `FlickKeyboardView` layout (function keys on the outer columns, kana in the
// middle three, and the 改行 key spanning rows 3–4). `keyHeight` is set per
// host mode so the grid fills the available space without overflowing the
// fixed-aspect mock card.
private struct NativeFlickRows: View {
    let keyHeight: CGFloat

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                fnKey("arrow.right"); kanaKey("あ"); kanaKey("か"); kanaKey("さ"); fnKey("delete.left")
            }
            .frame(height: keyHeight)

            HStack(spacing: 6) {
                fnKey("arrow.counterclockwise"); kanaKey("た"); kanaKey("な"); kanaKey("は"); textKey("空白")
            }
            .frame(height: keyHeight)

            GeometryReader { geo in
                let keyWidth = (geo.size.width - 6 * 4) / 5
                HStack(spacing: 6) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) { textKey("ABC"); kanaKey("ま"); kanaKey("や"); kanaKey("ら") }
                        HStack(spacing: 6) { fnKey("globe"); kanaKey("^_^"); kanaKey("わ"); kanaKey("、。") }
                    }
                    textKey("改行").frame(width: keyWidth)
                }
            }
            .frame(height: keyHeight * 2 + 6)
        }
        .padding(.horizontal, 6)
    }

    private func kanaKey(_ label: String) -> some View {
        flickKey(fill: NativeKeyboardStyle.keyFill) {
            Text(verbatim: label)
                .font(.system(size: min(20, keyHeight * 0.42), weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func textKey(_ label: String) -> some View {
        flickKey(fill: NativeKeyboardStyle.specialKey) {
            Text(verbatim: label)
                .font(.system(size: min(14, keyHeight * 0.34), weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func fnKey(_ symbol: String) -> some View {
        flickKey(fill: NativeKeyboardStyle.specialKey) {
            Image(systemName: symbol)
                .font(.system(size: min(20, keyHeight * 0.42), weight: .regular))
        }
    }

    private func flickKey<Content: View>(fill: Color, @ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundStyle(NativeKeyboardStyle.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fill)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct NativeKeyboardRows: View {
    private let row1 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let row2 = ["a", "s", "d", "f", "g", "h", "j", "k", "l", "ー"]
    private let row3 = ["z", "x", "c", "v", "b", "n", "m"]

    var body: some View {
        VStack(spacing: 8) {
            NativeLetterRow(keys: row1)
            NativeLetterRow(keys: row2)

            HStack(spacing: 6) {
                NativeSpecialKey(symbol: "shift", width: 45)
                Spacer(minLength: 6)
                ForEach(row3, id: \.self) { key in
                    NativeLetterKey(label: key)
                }
                Spacer(minLength: 6)
                NativeSpecialKey(symbol: "delete.left", width: 45)
            }
        }
        .padding(.horizontal, 6)
    }
}

private struct NativeLetterRow: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(keys, id: \.self) { key in
                NativeLetterKey(label: key)
            }
        }
    }
}

private struct NativeLetterKey: View {
    let label: String

    var body: some View {
        Text(verbatim: label)
            .font(.system(size: 25, weight: .regular))
            .foregroundStyle(NativeKeyboardStyle.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 43)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(NativeKeyboardStyle.keyFill)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct NativeSpecialKey: View {
    let symbol: String
    let width: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(NativeKeyboardStyle.ink)
            .frame(width: width, height: 43)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(NativeKeyboardStyle.specialKey)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct NativeKeyboardAccessoryRow: View {
    var body: some View {
        HStack(spacing: 6) {
            NativeBottomKey(text: "123", width: 42, fill: NativeKeyboardStyle.specialKey)
            NativeBottomKey(text: "空白", width: nil, fill: NativeKeyboardStyle.keyFill)
            NativeBottomKey(text: "改行", width: 78, fill: NativeKeyboardStyle.specialKey)
        }
        .frame(height: 43)
        .padding(.horizontal, 6)
    }
}

private struct NativeBottomKey: View {
    var text: String? = nil
    var symbol: String? = nil
    var width: CGFloat?
    let fill: Color

    var body: some View {
        Group {
            if let text {
                Text(verbatim: text)
                    .font(.system(size: 18, weight: .regular))
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .regular))
            }
        }
        .foregroundStyle(NativeKeyboardStyle.ink)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .frame(width: width, height: 43)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(fill)
                .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
        )
    }
}

private struct NativeResultDemo: View {
    let selectedIndex: Int

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                NativeToolbarPill(title: "敬語", isSelected: true)
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(NativeKeyboardStyle.ink)
                    .frame(width: 38, height: 38)
            }
            .frame(height: 52)
            .padding(.horizontal, 6)

            NativeResultCarousel(selectedIndex: selectedIndex)
                .frame(height: 158)

            NativeRefinementRow()
                .padding(.top, 10)

            Spacer(minLength: 0)
        }
    }
}

private struct NativeResultCarousel: View {
    let selectedIndex: Int

    private let cardWidth: CGFloat = 330
    private let spacing: CGFloat = 14
    private let samples = [
        "テストについてご案内いたします",
        "テストの件につきまして、ご案内申し上げます。",
        "テストについて、以下の通りご案内いたします。"
    ]

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, sample in
                NativeCandidateCard(text: sample, isSelected: index == selectedIndex)
                    .frame(width: cardWidth, height: 156)
            }
        }
        .padding(.leading, 30)
        .offset(x: -CGFloat(selectedIndex) * (cardWidth + spacing))
        .frame(width: 390, height: 158, alignment: .leading)
        .clipped()
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: selectedIndex)
    }
}

private struct NativeCandidateCard: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(NativeKeyboardStyle.ink)
            .lineLimit(5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                NativeKeyboardStyle.panelFill,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? NativeKeyboardStyle.accent.opacity(0.74) : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

private struct NativeRefinementRow: View {
    private let chips = [
        ("arrow.clockwise", "再作成"),
        ("briefcase", "より丁寧に"),
        ("arrow.up.arrow.down", "より詳しく"),
        ("arrow.down.right.and.arrow.up.left", "短く")
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    HStack(spacing: 5) {
                        Image(systemName: chip.0)
                            .font(.system(size: 14, weight: .regular))
                        Text(verbatim: chip.1)
                            .font(.system(size: 17, weight: .regular))
                    }
                    .foregroundStyle(NativeKeyboardStyle.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(NativeKeyboardStyle.panelFill.opacity(0.92), in: Capsule())
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
    }
}

private struct ChatInputMock: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 0.5))

            HStack {
                Text(verbatim: "明日までに確認お願いします")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
                Rectangle()
                    .fill(OnboardingPalette.ink)
                    .frame(width: 1.2, height: 16)
                Spacer()
                Image(systemName: "mic")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(
                Capsule()
                    .fill(Color(red: 0.94, green: 0.93, blue: 0.95))
            )
        }
        .padding(.horizontal, 6)
    }
}

private struct KeyboardMock: View {
    private let suggestions = ["敬語", "ビジネス", "メール", "やわらかく"]
    private let row1 = ["q","w","e","r","t","y","u","i","o","p"]
    private let row2 = ["a","s","d","f","g","h","j","k","l"]
    private let row3 = ["z","x","c","v","b","n","m"]

    var body: some View {
        VStack(spacing: 8) {
            SuggestionBar(items: suggestions)
            KeyRow(keys: row1)
            KeyRow(keys: row2, sidePadding: 18)
            HStack(spacing: 5) {
                SpecialKey(symbol: "shift.fill", width: 36)
                ForEach(row3, id: \.self) { k in
                    LetterKey(label: k)
                }
                SpecialKey(symbol: "delete.left", width: 36)
            }
            HStack(spacing: 5) {
                BottomKey(text: "123", width: 42)
                BottomKey(symbol: "face.smiling", width: 36)
                BottomKey(text: "空白", width: nil)
                KeepKey()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.86, green: 0.87, blue: 0.89))
        )
    }
}

private struct SuggestionBar: View {
    let items: [String]

    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "AI")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 26)
                .background(
                    Capsule()
                        .fill(Color(red: 0.18, green: 0.17, blue: 0.22))
                )
                .padding(.leading, 4)
                .padding(.trailing, 6)

            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Text(verbatim: item)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                if idx < items.count - 1 {
                    Rectangle()
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 0.5, height: 16)
                }
            }
        }
        .background(Color.white.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .padding(.horizontal, 4)
    }
}

private struct KeyRow: View {
    let keys: [String]
    var sidePadding: CGFloat = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { k in
                LetterKey(label: k)
            }
        }
        .padding(.horizontal, sidePadding)
    }
}

private struct LetterKey: View {
    let label: String

    var body: some View {
        Text(verbatim: label.uppercased())
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(OnboardingPalette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct SpecialKey: View {
    let symbol: String
    let width: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .regular))
            .foregroundStyle(OnboardingPalette.ink)
            .frame(width: width, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.74, green: 0.76, blue: 0.78))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

private struct BottomKey: View {
    var text: String? = nil
    var symbol: String? = nil
    var width: CGFloat?

    var body: some View {
        Group {
            if let text {
                Text(verbatim: text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(OnboardingPalette.ink)
            }
        }
        .frame(maxWidth: width == nil ? .infinity : nil)
        .frame(width: width, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
        )
    }
}

private struct KeepKey: View {
    var body: some View {
        Text(verbatim: "確定")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 64, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.46, blue: 0.93))
                    .shadow(color: .black.opacity(0.18), radius: 0, x: 0, y: 1)
            )
    }
}

// MARK: - Reply feature announcement (existing users)
//
// Shown once as a bottom sheet to users who completed onboarding before the
// reply feature existed. New users meet the same demo on the onboarding
// `KeyboardReplyPage`, so the sheet is suppressed for them. Container chrome
// uses the Bikey Design System; the keyboard depiction keeps the native look.

struct ReplyFeatureSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppColor.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新機能")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("コピーした文に、\nワンタップで返信。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("LINEやメールで相手のメッセージをコピーすると、キーボードのツールバーに「返信」ボタンが表示されます。押すだけで、文脈に合った返信文の候補を作成します。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NativeKeyboardSurfaceMock(mode: .reply)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppColor.surfaceElevated)
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "doc.on.doc", text: "他のアプリでメッセージをコピー")
                        ReplyFeaturePoint(icon: "arrowshape.turn.up.left", text: "ツールバーの「返信」ボタンをタップ")
                        ReplyFeaturePoint(icon: "sparkles", text: "返信文の候補から選んで置き換え")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            Button {
                dismiss()
            } label: {
                Text("使ってみる")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.charcoalAction, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

private struct ReplyFeaturePoint: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppColor.purple.opacity(0.78))
                .frame(width: 26, height: 26)
                .background(AppColor.paleLavender.opacity(0.85), in: Circle())

            Text(text)
                .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                .foregroundStyle(AppColor.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Flick input announcement (existing users)
//
// Shown once to users who completed onboarding before the flick keyboard
// existed. New users choose their input style on the onboarding
// `KeyboardInputStylePage`, so the sheet is suppressed for them. Mirrors
// `ReplyFeatureSheet`'s layout; the keyboard depiction renders the real
// 10-key flick grid.

struct FlickFeatureSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppColor.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新機能")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("片手でも、\nフリックで入力。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("10キー配列のフリック入力に対応しました。ローマ字と同じように、AIボタンや返信もそのまま使えます。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    NativeKeyboardSurfaceMock(mode: .toolbar, style: .japaneseFlick)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppColor.surfaceElevated)
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "square.grid.3x3", text: "10キー配列でフリック入力")
                        ReplyFeaturePoint(icon: "arrow.left.arrow.right", text: "ローマ字との切り替えはいつでも設定から")
                        ReplyFeaturePoint(icon: "sparkles", text: "AIの書き直し・返信はそのまま使える")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            VStack(spacing: 8) {
                Button {
                    KeyboardSettingsStore.writeKeyboardStyle(.japaneseFlick)
                    dismiss()
                } label: {
                    Text("フリックに切り替える")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColor.charcoalAction, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("今はローマ字のまま使う")
                        .bikeyFont(14, weight: .regular, relativeTo: .body)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

// MARK: - Prompt customization announcement (existing users)
//
// Shown once to users who completed onboarding before this page existed, so
// they discover that the toolbar buttons are editable and that custom buttons
// can be added. New users see `KeyboardPromptsPage` during onboarding, so the
// sheet is suppressed for them. The CTA jumps straight to the Prompts tab.

struct PromptsFeatureSheet: View {
    let onOpen: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppColor.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("使い方")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("ボタンは、\n自分仕様にできる。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("「敬語」ボタンの変換のしかたを変えたり、よく使う言い換えを自分のボタンとして追加できます。設定の「プロンプト」からいつでも編集できます。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PromptsCustomizeMock()
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "pencil", text: "「敬語」ボタンの変換内容を自分好みに編集")
                        ReplyFeaturePoint(icon: "plus", text: "よく使う言い換えを新しいボタンとして追加")
                        ReplyFeaturePoint(icon: "ellipsis", text: "追加したボタンはキーボードの「…」から呼び出し")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            Button {
                onOpen()
                dismiss()
            } label: {
                Text("プロンプトを編集する")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.charcoalAction, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

// MARK: - Zenzai neural conversion announcement (existing users)
//
// Shown once when the update that enables on-device neural conversion lands.
// The feature is on by default (with an automatic memory fallback), so the
// sheet only informs and points at the ProfileScreen toggle — no CTA needed
// beyond dismissal.

struct ZenzaiFeatureSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppColor.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新機能")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("変換が、\nもっと賢く。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("AIによるかな漢字変換を搭載しました。文脈を読んで、より自然な変換候補を提案します。すべて端末内で動作し、入力内容が送信されることはありません。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "sparkles", text: "文脈を理解して変換候補を提案")
                        ReplyFeaturePoint(icon: "iphone", text: "端末内で完結、オフラインでも動作")
                        ReplyFeaturePoint(icon: "gauge.with.needle", text: "端末に合わせて自動で最適化")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            Button {
                dismiss()
            } label: {
                Text("さっそく使う")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.charcoalAction, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

// MARK: - Commercial data-use re-consent (existing users)
//
// Shown once to users who onboarded before the commercial opt-in checkbox
// existed (1.0.9), so they never saw the question. Genuine opt-in: declining
// (今回は見送る / 閉じる / drag-dismiss) records nothing server-side, and the
// disclosure copy mirrors the onboarding checkbox word-for-word so both paths
// stay on consent version 2026-07-02. New users answer in onboarding and
// never see this — completeOnboarding marks it seen.

struct CommercialConsentFeatureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onOptIn: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    onDecline()
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppColor.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ご協力のお願い")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("日本語AIの改善に、\n力を貸してください。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("入力・変換データを匿名化し、日本語AIの学習用データセットの作成・提供（第三者提供を含む）に利用することを許可いただけますか。同意は任意です。同意しなくても、すべての機能をこれまで通りご利用いただけます。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "eye.slash", text: "氏名・連絡先などは自動で匿名化")
                        ReplyFeaturePoint(icon: "checkmark.shield", text: "同意は任意、設定からいつでも取り消し可能")
                        ReplyFeaturePoint(icon: "sparkles", text: "将来的に変換精度の改善につながる可能性")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            VStack(spacing: 10) {
                Button {
                    onOptIn()
                    dismiss()
                } label: {
                    Text("同意して協力する")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(AppColor.charcoalAction, in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    onDecline()
                    dismiss()
                } label: {
                    Text("今回は見送る")
                        .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                        .foregroundStyle(AppColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

// MARK: - Selective rewrite announcement (existing users)
//
// Shown once when highlight-to-rewrite lands. The feature needs no setup, so
// the CTA just dismisses. Mirrors the other feature sheets' scaffold; the mock
// depicts selecting a phrase and rewriting only that part.

struct SelectionRewriteFeatureSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppColor.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新機能")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("気になる部分だけ、\nAIで書き直す。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("文章の一部を選択してAIボタンを押すと、選んだところだけを書き直します。前後の文章はそのまま、自然につながるように整えます。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    SelectionRewriteMock()
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "character.cursor.ibeam", text: "書き直したい部分を選択（ハイライト）")
                        ReplyFeaturePoint(icon: "sparkles", text: "AIボタンを押すと、その部分だけを書き直し")
                        ReplyFeaturePoint(icon: "text.alignleft", text: "選択しなければ、これまで通り全体を書き直し")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            Button {
                dismiss()
            } label: {
                Text("使ってみる")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.charcoalAction, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

/// Depicts selecting a phrase inside a sentence and rewriting only that part:
/// the phrase highlights, the AI pill presses, then just the selected words
/// cross-fade to a polished form while the surrounding text stays put.
private struct SelectionRewriteMock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selected = false
    @State private var thinking = false
    @State private var rewritten = false
    @State private var pressPill = false

    private let leading = "会議の件、"
    private let original = "あとで返すね"
    private let polished = "後ほどご返信します"

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                Text(leading)
                    .foregroundStyle(AppColor.ink)
                Text(rewritten ? polished : original)
                    .foregroundStyle(AppColor.ink)
                    .contentTransition(.opacity)
                    .padding(.horizontal, selected ? 4 : 0)
                    .padding(.vertical, selected ? 1 : 0)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(AppColor.purple.opacity(selected ? 0.20 : 0))
                    )
                Spacer(minLength: 0)
            }
            .bikeyFont(16, weight: .regular, relativeTo: .body)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(height: 52)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColor.rule.opacity(0.4), lineWidth: 1)
            )

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                Text("敬語")
                    .bikeyFont(14, weight: .medium, relativeTo: .footnote)
            }
            .foregroundStyle(thinking ? .white : AppColor.ink)
            .padding(.horizontal, 18)
            .frame(height: 40)
            .background(Capsule().fill(thinking ? AppColor.charcoalAction : AppColor.surface))
            .overlay(Capsule().strokeBorder(AppColor.rule.opacity(0.4), lineWidth: thinking ? 0 : 1))
            .scaleEffect(pressPill ? 0.92 : 1.0)
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(AppColor.surfaceElevated))
        .task(id: reduceMotion) { await loop() }
    }

    @MainActor
    private func loop() async {
        guard !reduceMotion else {
            selected = false
            thinking = false
            rewritten = true
            return
        }
        while !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.3)) {
                rewritten = false
                selected = false
                thinking = false
                pressPill = false
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selected = true }
            try? await Task.sleep(nanoseconds: 800_000_000)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                pressPill = true
                thinking = true
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressPill = false }
            try? await Task.sleep(nanoseconds: 650_000_000)
            withAnimation(.easeInOut(duration: 0.45)) {
                rewritten = true
                selected = false
                thinking = false
            }
            try? await Task.sleep(nanoseconds: 2_200_000_000)
        }
    }
}

// MARK: - Prompt organization announcement (existing users)
//
// Shown once when drag-to-reorder + delete land. Existing users already saw
// `PromptsFeatureSheet` (edit / add); this one announces the organizational
// freedom. CTA jumps to the Prompts tab.

struct PromptOrganizeFeatureSheet: View {
    let onOpen: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .bikeyFont(15, weight: .medium, relativeTo: .body)
                        .foregroundStyle(AppColor.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(AppColor.surface, in: Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BikeyMetrics.Spacing.m)
            .padding(.top, BikeyMetrics.Spacing.m)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: BikeyMetrics.Spacing.l) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新機能")
                            .bikeyFont(11, weight: .semibold, relativeTo: .caption2)
                            .foregroundStyle(AppColor.purple)
                            .tracking(0.6)
                            .padding(.horizontal, 10)
                            .frame(height: 24)
                            .background(AppColor.paleLavender.opacity(0.85), in: Capsule())

                        Text("ボタンは、\n好きな順番に。")
                            .bikeyFont(24, weight: .medium, relativeTo: .title2)
                            .foregroundStyle(AppColor.ink)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("AIボタンをドラッグして並べ替えたり、使わないボタンを削除したり。自分の使い方に合わせて自由に整理できます。")
                            .bikeyFont(14, weight: .regular, relativeTo: .footnote)
                            .foregroundStyle(AppColor.muted)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PromptOrganizeMock()
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        ReplyFeaturePoint(icon: "arrow.up.arrow.down", text: "ドラッグでボタンを並べ替え")
                        ReplyFeaturePoint(icon: "trash", text: "使わないボタンは削除")
                        ReplyFeaturePoint(icon: "pencil", text: "変換内容もいつでも編集")
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, BikeyMetrics.Spacing.l)
                .padding(.top, BikeyMetrics.Spacing.l)
                .padding(.bottom, BikeyMetrics.Spacing.l)
            }

            Button {
                onOpen()
                dismiss()
            } label: {
                Text("プロンプトを整理する")
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppColor.charcoalAction, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BikeyMetrics.Spacing.l)
            .padding(.bottom, BikeyMetrics.Spacing.m)
        }
        .background(AppColor.background.ignoresSafeArea())
    }
}

/// Depicts drag-to-reorder: a row lifts with a shadow, slides above its
/// neighbour, then settles — looping so the gesture reads at a glance.
private struct PromptOrganizeMock: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Item: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
    }

    private static let base: [Item] = [
        .init(id: "keigo", title: "敬語", detail: "丁寧でやわらかい敬語に。"),
        .init(id: "soft", title: "やさしく", detail: "もっとやわらかい言い方に。"),
        .init(id: "short", title: "短く", detail: "要点だけ簡潔に。"),
    ]
    private static let reordered: [Item] = [base[0], base[2], base[1]]

    @State private var items: [Item] = PromptOrganizeMock.base
    @State private var lifted: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                row(item)
                if item.id != items.last?.id {
                    Rectangle()
                        .fill(AppColor.rule.opacity(0.35))
                        .frame(height: 0.5)
                        .padding(.leading, BikeyMetrics.Spacing.m + 4)
                }
            }
        }
        .padding(.vertical, 4)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
        .task(id: reduceMotion) { await loop() }
    }

    private func row(_ item: Item) -> some View {
        let isLifted = lifted == item.id
        return HStack(spacing: BikeyMetrics.Spacing.s) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: item.title)
                    .bikeyFont(17, weight: .medium, relativeTo: .body)
                    .foregroundStyle(AppColor.ink)
                Text(verbatim: item.detail)
                    .bikeyFont(13, weight: .regular, relativeTo: .footnote)
                    .foregroundStyle(AppColor.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isLifted ? AppColor.purple : AppColor.softText)
        }
        .padding(.horizontal, BikeyMetrics.Spacing.m + 4)
        .padding(.vertical, BikeyMetrics.Spacing.m - 2)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isLifted ? AppColor.surfaceElevated : Color.clear)
        )
        .scaleEffect(isLifted ? 1.03 : 1.0)
        .shadow(color: .black.opacity(isLifted ? 0.12 : 0), radius: 10, x: 0, y: 5)
        .zIndex(isLifted ? 1 : 0)
    }

    @MainActor
    private func loop() async {
        guard !reduceMotion else {
            items = PromptOrganizeMock.reordered
            return
        }
        while !Task.isCancelled {
            items = PromptOrganizeMock.base
            lifted = nil
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { lifted = "short" }
            try? await Task.sleep(nanoseconds: 450_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                items = PromptOrganizeMock.reordered
            }
            try? await Task.sleep(nanoseconds: 550_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { lifted = nil }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}

// MARK: - Previews

#Preview("Setup page") {
    KeyboardSetupPage(progress: 0.66, onBack: {}, onSkip: nil, onContinue: {})
}

#Preview("Selection rewrite sheet") {
    SelectionRewriteFeatureSheet()
}

#Preview("Prompt organize sheet") {
    PromptOrganizeFeatureSheet(onOpen: {})
}

#Preview("Flick feature sheet") {
    FlickFeatureSheet()
}

#Preview("Usage page") {
    KeyboardUsagePage(progress: 0.88, onBack: {}, onContinue: {})
}

#Preview("Result page") {
    KeyboardResultPage(progress: 0.75, onBack: {}, onContinue: {})
}

#Preview("Reply page") {
    KeyboardReplyPage(progress: 0.66, onBack: {}, onContinue: {})
}

#Preview("Consent page") {
    KeyboardConsentPage(progress: 1.0, onBack: {}, onAgree: { _ in }, onDecline: {})
}

#Preview("Reply feature sheet") {
    ReplyFeatureSheet()
}

#Preview("Prompts page") {
    KeyboardPromptsPage(progress: 0.625, onBack: {}, onContinue: {})
}

#Preview("Prompts feature sheet") {
    PromptsFeatureSheet(onOpen: {})
}
