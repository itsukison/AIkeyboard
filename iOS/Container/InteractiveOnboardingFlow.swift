import KeyboardKit
import KeyboardPreferences
import SwiftUI
import UIKit

enum InteractiveOnboardingState {
    static let version = "interactive_v2"
    static let startedKey = "aikJP.interactiveOnboardingStarted"
    static let authRequiredKey = "aikJP.interactiveOnboardingAuthRequired"
    static let pageIndexKey = "aikJP.interactiveOnboardingPageIndex"

    static func markStarted(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: startedKey)
        defaults.set(version, forKey: "aikJP.onboardingVersion")
        defaults.set(false, forKey: authRequiredKey)
        defaults.set(0, forKey: pageIndexKey)
    }

    static func markAuthRequired(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: authRequiredKey)
    }

    static func markAuthenticated(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: authRequiredKey)
        defaults.set(false, forKey: startedKey)
        defaults.removeObject(forKey: pageIndexKey)
    }

    static func isAuthRequired(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: authRequiredKey)
    }

    static func shouldResume(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: startedKey)
            && defaults.string(forKey: "aikJP.onboardingVersion") == version
    }

    static func pageIndex(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: pageIndexKey)
    }

    static func writePageIndex(_ index: Int, defaults: UserDefaults = .standard) {
        defaults.set(index, forKey: pageIndexKey)
    }

    /// Arms keyboard practice mode for the guided pages: the extension shows
    /// the AI buttons before sign-in and answers taps with these local
    /// candidates. The expiry guarantees an abandoned onboarding can't leave
    /// the keyboard practicing forever.
    static func armPractice(candidates: [String]) {
        KeyboardSettingsStore.writeOnboardingPracticeActive(until: Date().addingTimeInterval(30 * 60))
        KeyboardSettingsStore.writeOnboardingPracticeCandidates(candidates)
    }

    static func disarmPractice() {
        KeyboardSettingsStore.clearOnboardingPractice()
    }
}

// MARK: - Practice scenarios

/// The worked example for the AI-rewrite practice page, keyed to the main
/// button the use-case page seeded. `text` pre-fills the practice field and
/// `candidates` are what the keyboard presents when the button is tapped —
/// locally, so the exercise works before sign-in and offline.
struct OnboardingPracticeScenario {
    let text: String
    let candidates: [String]

    /// The reply exercise: the message the user copies and the canned replies
    /// the 返信 button presents while practice mode is armed.
    static let replyIncomingMessage = "明日の10時で大丈夫ですか？"
    static let replyCandidates = [
        "はい、10時で大丈夫です。よろしくお願いいたします。",
        "10時で問題ございません。当日はよろしくお願いいたします。",
        "はい、大丈夫です。それでは明日10時にお願いします。",
    ]

    static func make(for prompt: UserPrompt) -> OnboardingPracticeScenario {
        switch prompt.builtinKey {
        case UserPromptDefaults.emailKey:
            return OnboardingPracticeScenario(
                text: "資料確認おねがいします",
                candidates: [
                    "お世話になっております。お手数ですが、資料のご確認をお願いいたします。",
                    "お忙しいところ恐れ入りますが、資料をご確認いただけますと幸いです。",
                    "資料をお送りしましたので、ご確認のほどよろしくお願いいたします。",
                ]
            )
        case UserPromptDefaults.translateToEnglishKey:
            return OnboardingPracticeScenario(
                text: "明日の会議は10時からです",
                candidates: [
                    "Tomorrow's meeting starts at 10 a.m.",
                    "The meeting tomorrow will begin at 10:00.",
                    "We'll start tomorrow's meeting at 10.",
                ]
            )
        case UserPromptDefaults.naturalKey:
            return OnboardingPracticeScenario(
                text: "確認の方よろしくお願いします",
                candidates: [
                    "ご確認をよろしくお願いします。",
                    "ご確認いただけますと幸いです。",
                    "お手数ですが、ご確認をお願いします。",
                ]
            )
        case UserPromptDefaults.politeKey:
            return OnboardingPracticeScenario(
                text: "すみません、明日の会議すこしおくれます",
                candidates: [
                    "申し訳ありません。明日の会議に少し遅れてしまいます。",
                    "恐れ入りますが、明日の会議には少々遅れて参加いたします。",
                    "申し訳ございません。明日の会議に少し遅れる見込みです。",
                ]
            )
        default:
            break
        }

        if prompt.title.contains("カジュアル") {
            return OnboardingPracticeScenario(
                text: "明日の予定をご確認いただけますでしょうか",
                candidates: [
                    "明日の予定、確認してもらえる？",
                    "明日の予定チェックしておいてね！",
                    "明日の予定、見といてもらえると助かる！",
                ]
            )
        }
        if prompt.title.contains("中国語") {
            return OnboardingPracticeScenario(
                text: "明日の会議は10時からです",
                candidates: [
                    "明天的会议从上午10点开始。",
                    "明天上午10点开会。",
                    "会议定于明天上午10点开始。",
                ]
            )
        }
        if prompt.title.contains("添削") {
            return OnboardingPracticeScenario(
                text: "資料を確認して頂けますでしょうか",
                candidates: [
                    "資料をご確認いただけますでしょうか。",
                    "資料のご確認をお願いできますでしょうか。",
                    "資料をご確認いただけますと幸いです。",
                ]
            )
        }
        if prompt.title.contains("要約") || prompt.title.contains("わかりやすく") {
            return OnboardingPracticeScenario(
                text: "明日の会議は10時から第3会議室で開催します。資料は本日中に共有しますので、事前に確認をお願いします。",
                candidates: [
                    "明日10時から第3会議室で会議。資料は本日共有、事前確認をお願いします。",
                    "明日の会議：10時・第3会議室。資料は今日中に共有します。",
                    "明日10時に第3会議室で会議を行います。資料は本日中に共有します。",
                ]
            )
        }

        // Custom (AI-generated) buttons: a neutral politeness upgrade that
        // reads sensibly under almost any rewrite-style button.
        return OnboardingPracticeScenario(
            text: "よろしくおねがいします",
            candidates: [
                "よろしくお願いいたします。",
                "何卒よろしくお願いいたします。",
                "今後ともよろしくお願いいたします。",
            ]
        )
    }
}

// MARK: - Flow

struct InteractiveOnboardingFlow: View {
    let onFinish: () -> Void

    @State private var pageIndex: Int
    @State private var selectedStyle = KeyboardSettingsStore.readKeyboardStyle()
    @AppStorage("aikJP.seenReplyFeature") private var seenReplyFeature = false
    @AppStorage("aikJP.seenFlickFeature") private var seenFlickFeature = false
    @AppStorage("aikJP.seenPromptsFeature") private var seenPromptsFeature = false
    @AppStorage("aikJP.seenZenzaiFeature") private var seenZenzaiFeature = false
    @AppStorage("aikJP.seenSelectionFeature") private var seenSelectionFeature = false
    @AppStorage("aikJP.seenPromptOrganizeFeature") private var seenPromptOrganizeFeature = false
    @AppStorage("aikJP.seenCommercialConsentFeature") private var seenCommercialConsentFeature = false

    private static let totalPages = 9

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let restoredPage = InteractiveOnboardingState.pageIndex()
        _pageIndex = State(initialValue: min(Self.totalPages - 1, max(0, restoredPage)))
    }

    var body: some View {
        Group {
            switch pageIndex {
            case 0:
                KeyboardInputStylePage(
                    progress: progress(for: 0),
                    onBack: nil,
                    selectedStyle: $selectedStyle,
                    onSkip: {
                        persistSelectedStyle()
                        skip("input_style")
                    },
                    onContinue: {
                        persistSelectedStyle()
                        advance()
                    }
                )
            case 1:
                KeyboardSetupPage(
                    progress: progress(for: 1),
                    onBack: goBack,
                    onSkip: { skip("keyboard_setup") },
                    onContinue: advance
                )
            case 2:
                KeyboardUseCasePage(
                    progress: progress(for: 2),
                    onBack: goBack,
                    onSkip: { skip("use_case") },
                    onContinue: advance
                )
            case 3:
                KeyboardPromptsPage(
                    progress: progress(for: 3),
                    onBack: goBack,
                    onSkip: { skip("prompt_setup") },
                    onContinue: advance
                )
            case 4:
                KeyboardSwitchPracticePage(
                    progress: progress(for: 4),
                    style: selectedStyle,
                    onBack: goBack,
                    onSkip: { skip("keyboard_switch_practice") },
                    onContinue: advance
                )
            case 5:
                RewritePracticePage(
                    progress: progress(for: 5),
                    style: selectedStyle,
                    prompt: OnboardingPromptSetup.load().first ?? UserPromptDefaults.seedEntries()[0],
                    onBack: goBack,
                    onSkip: { skip("rewrite_practice") },
                    onContinue: advance
                )
            case 6:
                ReplyPracticePage(
                    progress: progress(for: 6),
                    onBack: goBack,
                    onSkip: { skip("reply_practice") },
                    onContinue: advance
                )
            case 7:
                OnboardingSourcePage(
                    progress: progress(for: 7),
                    onBack: goBack,
                    onSkip: { skip("source") },
                    onContinue: { source in
                        if let source {
                            OnboardingSourceStore.write(source)
                            AppAnalytics.capture("onboarding_source_selected", properties: [
                                "source": source.rawValue,
                                "onboarding_version": InteractiveOnboardingState.version,
                            ])
                        }
                        advance()
                    }
                )
            default:
                KeyboardConsentPage(
                    progress: progress(for: 8),
                    onBack: goBack,
                    onSkip: { completePreAuth(consentGranted: false, commercialOptIn: false, skipped: true) },
                    onAgree: { commercialOptIn in
                        completePreAuth(consentGranted: true, commercialOptIn: commercialOptIn, skipped: false)
                    },
                    onDecline: {
                        completePreAuth(consentGranted: false, commercialOptIn: false, skipped: false)
                    }
                )
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.995)))
        .onAppear {
            configurePractice(for: pageIndex)
        }
        .onChange(of: pageIndex) { index in
            configurePractice(for: index)
        }
    }

    private func persistSelectedStyle() {
        KeyboardSettingsStore.writeKeyboardStyle(selectedStyle)
        AppAnalytics.capture("onboarding_input_style_selected", properties: [
            "style": selectedStyle.rawValue,
            "onboarding_version": InteractiveOnboardingState.version,
        ])
    }

    private func skip(_ step: String) {
        AppAnalytics.capture("onboarding_step_skipped", properties: [
            "step": step,
            "onboarding_version": InteractiveOnboardingState.version,
        ])
        advance()
    }

    private func completePreAuth(consentGranted: Bool, commercialOptIn: Bool, skipped: Bool) {
        seenReplyFeature = true
        seenFlickFeature = true
        seenPromptsFeature = true
        seenZenzaiFeature = true
        seenSelectionFeature = true
        seenPromptOrganizeFeature = true
        seenCommercialConsentFeature = true
        InteractiveOnboardingState.disarmPractice()
        KeyboardSettingsStore.writeAIConsentGranted(consentGranted)
        KeyboardSettingsStore.writeAICommercialOptIn(commercialOptIn)
        AppAnalytics.capture("ai_consent_decision", properties: [
            "granted": consentGranted,
            "commercial_opt_in": commercialOptIn,
            "skipped": skipped,
            "onboarding_version": InteractiveOnboardingState.version,
        ])
        AppAnalytics.capture("onboarding_pre_auth_completed", properties: [
            "onboarding_version": InteractiveOnboardingState.version,
        ])
        InteractiveOnboardingState.markAuthRequired()
        onFinish()
    }

    private func advance() {
        let nextPage = min(Self.totalPages - 1, pageIndex + 1)
        InteractiveOnboardingState.writePageIndex(nextPage)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            pageIndex = nextPage
        }
    }

    private func goBack() {
        let previousPage = max(0, pageIndex - 1)
        InteractiveOnboardingState.writePageIndex(previousPage)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            pageIndex = previousPage
        }
    }

    private func progress(for index: Int) -> Double {
        Double(index + 1) / Double(Self.totalPages)
    }

    private func configurePractice(for index: Int) {
        switch index {
        case 4, 5:
            let prompt = OnboardingPromptSetup.load().first ?? UserPromptDefaults.seedEntries()[0]
            InteractiveOnboardingState.armPractice(
                candidates: OnboardingPracticeScenario.make(for: prompt).candidates
            )
        case 6:
            InteractiveOnboardingState.armPractice(
                candidates: OnboardingPracticeScenario.replyCandidates
            )
        default:
            InteractiveOnboardingState.disarmPractice()
        }
    }
}

// MARK: - Switch practice

/// Guided exercise 1: switch to 敬語ボタン with the globe key and type a short
/// phrase. Completion is detected from the App Group (keyboard open count and
/// the field's text), so the page reacts to the real keyboard, not taps on
/// fake UI.
private struct KeyboardSwitchPracticePage: View {
    let progress: Double
    let style: KeyboardPreferences.KeyboardStyle
    let onBack: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var text = ""
    @State private var pageOpenedAt = Date()
    @State private var initialOpenCount: Int?
    @State private var didOpenKeyboard = false
    @State private var didTypeWithKeyboard = false
    @State private var isShowingSwitchSuccess = false
    @State private var reportedKeyboardOpen = false
    @State private var reportedTyped = false
    @FocusState private var isEditorFocused: Bool

    private let practicePhrase = "よろしくおねがいします"

    private var didType: Bool {
        didTypeWithKeyboard || text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    private var isComplete: Bool {
        didOpenKeyboard && didType
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: {
                isEditorFocused = false
                onBack()
            },
            onSkip: {
                isEditorFocused = false
                onSkip()
            },
            ctaTitle: "次へ",
            isCtaEnabled: isComplete,
            onCta: {
                isEditorFocused = false
                AppAnalytics.capture("onboarding_keyboard_practice_completed", properties: [
                    "input_style": style.rawValue,
                    "onboarding_version": InteractiveOnboardingState.version,
                ])
                onContinue()
            }
        ) {
            VStack(spacing: 0) {
                OnboardingTitleBlock(
                    title: "敬語ボタンに\n切り替えてみましょう",
                    subtitle: "キーボード左下の地球儀キーを長押しして、「敬語ボタン」を選びます。"
                )
                .padding(.top, 24)
                .padding(.horizontal, 20)

                OnboardingPracticeField(
                    text: $text,
                    isFocused: $isEditorFocused,
                    placeholder: LocalizedStringKey("ここに「\(practicePhrase)」と入力")
                )
                .padding(.top, 28)
                .padding(.horizontal, 20)

                OnboardingPracticeStatus(
                    symbol: statusSymbol,
                    text: statusText,
                    isComplete: isComplete || isShowingSwitchSuccess
                )
                .padding(.top, 18)
                .padding(.horizontal, 20)

                Spacer(minLength: 12)
            }
        }
        .practiceKeyboardDoneButton(isFocused: $isEditorFocused)
        .onAppear {
            refreshStatus(initialize: true)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                isEditorFocused = true
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            refreshStatus(initialize: false)
            if !isComplete {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    isEditorFocused = true
                }
            }
        }
        .task {
            while !Task.isCancelled {
                refreshStatus(initialize: false)
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
        .onChange(of: text) { _ in
            guard didType, !reportedTyped else { return }
            reportedTyped = true
            AppAnalytics.capture("onboarding_practice_typed", properties: [
                "input_style": style.rawValue,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
        }
        // Deliberately no auto-dismiss on completion: the typed signal fires on
        // the first composing keystroke, so dropping focus here would cut the
        // user off mid-phrase. The green check + enabled CTA are enough.
    }

    private var statusText: LocalizedStringKey {
        if isComplete {
            return "できました。この調子です！"
        }
        if isShowingSwitchSuccess {
            return "敬語ボタンに切り替わりました！"
        }
        if didOpenKeyboard {
            return "次は、「\(practicePhrase)」と入力してみましょう。"
        }
        return "入力欄をタップ → 地球儀キーを長押し →「敬語ボタン」を選択"
    }

    private var statusSymbol: String {
        if isComplete || isShowingSwitchSuccess { return "checkmark" }
        if didOpenKeyboard { return "text.cursor" }
        return "globe"
    }

    private func refreshStatus(initialize: Bool) {
        if initialize {
            pageOpenedAt = Date()
        }
        let usage = KeyboardUsageDailyStore.currentDayUsage()
        if initialize || initialOpenCount == nil {
            initialOpenCount = usage.opens
        }

        // Two independent proofs of "the user switched to our keyboard": the
        // explicit practice signal the extension stamps on appearance, and the
        // daily open counter moving past the page-entry baseline.
        let seenAt = KeyboardSettingsStore.readOnboardingPracticeSignal(
            KeyboardSettingsStore.onboardingPracticeKeyboardSeenAtKey
        )
        let openedViaSignal = (seenAt ?? .distantPast) > pageOpenedAt
        let openedViaCount = initialOpenCount.map { usage.opens > $0 } ?? false
        if !initialize, !didOpenKeyboard, openedViaSignal || openedViaCount {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                didOpenKeyboard = true
                isShowingSwitchSuccess = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingSwitchSuccess = false
                }
            }
        }

        // Typing during kana composition never reaches this field's binding
        // (marked text), so the extension's typing signal is the reliable one.
        let typedAt = KeyboardSettingsStore.readOnboardingPracticeSignal(
            KeyboardSettingsStore.onboardingPracticeTypedAtKey
        )
        if !initialize, !didTypeWithKeyboard, (typedAt ?? .distantPast) > pageOpenedAt {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                didTypeWithKeyboard = true
            }
        }

        if didOpenKeyboard && !reportedKeyboardOpen {
            reportedKeyboardOpen = true
            AppAnalytics.capture("onboarding_keyboard_selected", properties: [
                "input_style": style.rawValue,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
        }
    }
}

// MARK: - Rewrite practice

/// Guided exercise 2: press the seeded main AI button on the real keyboard and
/// replace the text with a candidate. Practice mode is armed while this page
/// is visible, so the buttons work before sign-in and the candidates come from
/// the local scenario — nothing is sent anywhere.
private struct RewritePracticePage: View {
    let progress: Double
    let style: KeyboardPreferences.KeyboardStyle
    let prompt: UserPrompt
    let onBack: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var keyboardStatus = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")
    @State private var text: String
    @State private var pageOpenedAt = Date()
    @State private var baselineConversions: Int?
    @State private var didAcceptRewrite = false
    @State private var reportedCompletion = false
    @FocusState private var isEditorFocused: Bool

    private let scenario: OnboardingPracticeScenario

    init(
        progress: Double,
        style: KeyboardPreferences.KeyboardStyle,
        prompt: UserPrompt,
        onBack: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.progress = progress
        self.style = style
        self.prompt = prompt
        self.onBack = onBack
        self.onSkip = onSkip
        self.onContinue = onContinue
        let scenario = OnboardingPracticeScenario.make(for: prompt)
        self.scenario = scenario
        _text = State(initialValue: scenario.text)
    }

    private var needsKeyboard: Bool {
        !keyboardStatus.isKeyboardEnabled
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: {
                isEditorFocused = false
                onBack()
            },
            onSkip: {
                isEditorFocused = false
                onSkip()
            },
            ctaTitle: needsKeyboard && !didAcceptRewrite ? "設定を開く" : "次へ",
            isCtaEnabled: didAcceptRewrite || needsKeyboard,
            onCta: handleCTA
        ) {
            VStack(spacing: 0) {
                OnboardingTitleBlock(
                    title: "AIボタンで\n書き換えてみましょう",
                    subtitle: "キーボード上の「\(prompt.title)」を押すと、候補が3つ出ます。好きな候補で「置き換え」してください。"
                )
                .padding(.top, 24)
                .padding(.horizontal, 20)

                OnboardingPracticeField(
                    text: $text,
                    isFocused: $isEditorFocused,
                    placeholder: nil
                )
                .padding(.top, 28)
                .padding(.horizontal, 20)

                OnboardingPracticeStatus(
                    symbol: statusSymbol,
                    text: statusText,
                    isComplete: didAcceptRewrite
                )
                .padding(.top, 18)
                .padding(.horizontal, 20)

                Spacer(minLength: 12)
            }
        }
        .practiceKeyboardDoneButton(isFocused: $isEditorFocused)
        .onAppear {
            InteractiveOnboardingState.armPractice(candidates: scenario.candidates)
            pageOpenedAt = Date()
            baselineConversions = KeyboardUsageStatsStore.snapshot().conversionsTotal
            keyboardStatus.refresh()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                isEditorFocused = true
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            keyboardStatus.refresh()
            if !didAcceptRewrite {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    isEditorFocused = true
                }
            }
        }
        .task {
            while !Task.isCancelled {
                refreshStatus()
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
        .onChange(of: didAcceptRewrite) { accepted in
            guard accepted, !reportedCompletion else { return }
            reportedCompletion = true
            AppAnalytics.capture("onboarding_rewrite_practice_completed", properties: [
                "input_style": style.rawValue,
                "command_title": prompt.title,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                isEditorFocused = false
            }
        }
    }

    private var statusText: LocalizedStringKey {
        if didAcceptRewrite {
            return "できました。使い方はこれだけです！"
        }
        if needsKeyboard {
            return "先にキーボードの追加が必要です。「設定を開く」から追加してください。"
        }
        return "候補バーの上にある「\(prompt.title)」ボタンを押してみましょう"
    }

    private var statusSymbol: String {
        if didAcceptRewrite { return "checkmark" }
        if needsKeyboard { return "gearshape" }
        return "hand.tap"
    }

    private func refreshStatus() {
        // No keyboardStatus.refresh() here: it publishes on every poll, and the
        // resulting 350ms re-renders rebuild the TextEditor mid-composition,
        // corrupting marked text. It refreshes on appear / foregrounding instead.
        guard let baselineConversions else { return }
        // Counter delta plus the extension's explicit accepted-replacement
        // signal — either one proves the exercise finished.
        let acceptedAt = KeyboardSettingsStore.readOnboardingPracticeSignal(
            KeyboardSettingsStore.onboardingPracticeAcceptedAtKey
        )
        let accepted = KeyboardUsageStatsStore.snapshot().conversionsTotal > baselineConversions
            || (acceptedAt ?? .distantPast) > pageOpenedAt
        if accepted, !didAcceptRewrite {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                didAcceptRewrite = true
            }
        }
    }

    private func handleCTA() {
        if didAcceptRewrite {
            isEditorFocused = false
            onContinue()
            return
        }
        isEditorFocused = false
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Reply practice

/// Guided exercise 3: copy the incoming message so the 返信 pill appears in
/// the keyboard toolbar, tap it, and replace with one of the canned replies.
/// The copy is real (system pasteboard), so the pill appears exactly the way
/// it does in daily use.
private struct ReplyPracticePage: View {
    let progress: Double
    let onBack: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var keyboardStatus = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")
    @State private var reply = ""
    @State private var copied = false
    @State private var pageOpenedAt = Date()
    @State private var baselineConversions: Int?
    @State private var didAcceptReply = false
    @State private var reportedCompletion = false
    @FocusState private var isEditorFocused: Bool

    /// Reading the pasteboard from the keyboard needs Full Access, so the
    /// exercise checks it (unlike the rewrite practice, which is fully local).
    private var needsSettings: Bool {
        !keyboardStatus.isKeyboardEnabled
            || !(keyboardStatus.isFullAccessEnabled || KeyboardSettingsStore.readLastKnownFullAccessEnabled())
    }

    var body: some View {
        OnboardingScaffold(
            progress: progress,
            canGoBack: true,
            onBack: {
                isEditorFocused = false
                onBack()
            },
            onSkip: {
                isEditorFocused = false
                onSkip()
            },
            ctaTitle: needsSettings && !didAcceptReply ? "設定を開く" : "次へ",
            isCtaEnabled: didAcceptReply || needsSettings,
            onCta: handleCTA
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    OnboardingTitleBlock(
                        title: "返信も、\nコピーするだけ",
                        subtitle: "相手のメッセージをコピーすると、キーボードに「返信」ボタンが現れます。"
                    )
                    .padding(.top, 24)

                    ReplyIncomingMessageCard(
                        message: OnboardingPracticeScenario.replyIncomingMessage,
                        copied: copied,
                        onCopy: copyIncomingMessage
                    )
                    .padding(.top, 28)

                    OnboardingPracticeField(
                        text: $reply,
                        isFocused: $isEditorFocused,
                        placeholder: "返信がここに入ります"
                    )
                    .padding(.top, 12)

                    OnboardingPracticeStatus(
                        symbol: statusSymbol,
                        text: statusText,
                        isComplete: didAcceptReply
                    )
                    .padding(.top, 18)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .practiceKeyboardDoneButton(isFocused: $isEditorFocused)
        .onAppear {
            InteractiveOnboardingState.armPractice(candidates: OnboardingPracticeScenario.replyCandidates)
            pageOpenedAt = Date()
            baselineConversions = KeyboardUsageStatsStore.snapshot().conversionsTotal
            keyboardStatus.refresh()
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            keyboardStatus.refresh()
        }
        .task {
            while !Task.isCancelled {
                refreshStatus()
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }
        .onChange(of: didAcceptReply) { accepted in
            guard accepted, !reportedCompletion else { return }
            reportedCompletion = true
            AppAnalytics.capture("onboarding_reply_practice_completed", properties: [
                "onboarding_version": InteractiveOnboardingState.version,
            ])
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                isEditorFocused = false
            }
        }
    }

    private func copyIncomingMessage() {
        UIPasteboard.general.string = OnboardingPracticeScenario.replyIncomingMessage
        withAnimation(.easeOut(duration: 0.18)) {
            copied = true
        }
        isEditorFocused = true
        AppAnalytics.capture("onboarding_reply_message_copied", properties: [
            "onboarding_version": InteractiveOnboardingState.version,
        ])
    }

    private var statusText: LocalizedStringKey {
        if didAcceptReply {
            return "できました。もう返信で悩みません！"
        }
        if needsSettings {
            return "返信ボタンにはフルアクセスが必要です。「設定を開く」から有効にしてください。"
        }
        if copied {
            return "入力欄をタップして、キーボードの「返信」ボタンを押してみましょう"
        }
        return "まず、上のメッセージをコピーしてください"
    }

    private var statusSymbol: String {
        if didAcceptReply { return "checkmark" }
        if needsSettings { return "gearshape" }
        if copied { return "hand.tap" }
        return "doc.on.doc"
    }

    private func refreshStatus() {
        // Same as the rewrite page: no keyboardStatus.refresh() in the poll —
        // its per-tick publishes rebuilt the TextEditor during composition and
        // made typed text vanish or duplicate.
        guard let baselineConversions else { return }
        let acceptedAt = KeyboardSettingsStore.readOnboardingPracticeSignal(
            KeyboardSettingsStore.onboardingPracticeAcceptedAtKey
        )
        let accepted = KeyboardUsageStatsStore.snapshot().conversionsTotal > baselineConversions
            || (acceptedAt ?? .distantPast) > pageOpenedAt
        if accepted, !didAcceptReply {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                didAcceptReply = true
            }
        }
    }

    private func handleCTA() {
        if didAcceptReply {
            isEditorFocused = false
            onContinue()
            return
        }
        isEditorFocused = false
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

/// The incoming message the reply exercise copies: a chat-style bubble with
/// the copy affordance sitting right beside it, floating on the canvas like
/// the reference mockups.
private struct ReplyIncomingMessageCard: View {
    let message: String
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Circle()
                .fill(OnboardingPalette.heroFill)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(OnboardingPalette.subInk)
                )

            Text(verbatim: message)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(OnboardingPalette.heroFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button(action: onCopy) {
                Label(
                    copied ? "コピー済み" : "コピー",
                    systemImage: copied ? "checkmark" : "doc.on.doc"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(copied ? Color.green : AppColor.purple)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    (copied ? Color.green : AppColor.purple).opacity(0.10),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("このメッセージをコピー")

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Practice UI pieces

/// The clean compose field the practice exercises type into: a soft gray card
/// floating on the canvas, in the reference's style.
private struct OnboardingPracticeField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let placeholder: LocalizedStringKey?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty, let placeholder {
                Text(placeholder)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(OnboardingPalette.subInk.opacity(0.55))
                    .padding(.horizontal, 21)
                    .padding(.vertical, 20)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .focused(isFocused)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 128, maxHeight: 152)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OnboardingPalette.heroFill)
        )
    }
}

/// One-line live status under the practice field: what to do next, and a
/// green check once the step is done.
private struct OnboardingPracticeStatus: View {
    let symbol: String
    let text: LocalizedStringKey
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isComplete ? Color.white : OnboardingPalette.ink)
                .frame(width: 26, height: 26)
                .background(
                    isComplete ? Color.green : OnboardingPalette.heroFill,
                    in: Circle()
                )

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isComplete ? Color.green.opacity(0.10) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .id(symbol)
        .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
}

/// A 完了 accessory above the keyboard so the practice pages can always be
/// collapsed — the practice field keeps focus otherwise and would hide the CTA
/// behind the keyboard.
private struct PracticeKeyboardDoneButton: ViewModifier {
    var isFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { isFocused.wrappedValue = false }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.purple)
            }
        }
    }
}

private extension View {
    func practiceKeyboardDoneButton(isFocused: FocusState<Bool>.Binding) -> some View {
        modifier(PracticeKeyboardDoneButton(isFocused: isFocused))
    }
}
