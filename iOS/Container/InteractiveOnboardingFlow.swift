import KeyboardKit
import KeyboardPreferences
import SwiftUI
import UIKit

enum InteractiveOnboardingState {
    /// Bumped for the button builder. `shouldResume` compares this against the
    /// stored value, so an onboarding started on v2 restarts rather than
    /// resuming at a page index that now points somewhere else.
    static let version = "interactive_v3"
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
        // A button the builder made carries its own worked example, so the
        // exercise demonstrates the button the user actually made. Everything
        // below is the fallback for seeded built-ins and for the case where the
        // example is missing — a built button has no `builtinKey` and an
        // arbitrary title, so without this it would land on the generic default.
        if prompt.origin == .onboardingBuilder,
           let generated = KeyboardSettingsStore.readOnboardingGeneratedPractice(),
           generated.buttonId == prompt.id.uuidString,
           !generated.input.isEmpty,
           !generated.outputs.isEmpty {
            return OnboardingPracticeScenario(
                text: generated.input,
                candidates: generated.outputs
            )
        }

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

    /// The use case picked on page 2, which drives the builder's questions.
    @State private var selectedUseCase: OnboardingUseCase?
    /// The builder's in-progress answers. Cleared between buttons when the user
    /// chooses "もう1つ作る".
    @State private var builderSelections = BuilderSelections()
    /// The button the current builder pass produced. Stepping back from the
    /// review page and committing again updates it instead of adding a second
    /// copy; "もう1つ作る" clears it so the next pass really does add one.
    @State private var builtButtonId: UUID?
    /// True while pages 2–4 are being replayed for an extra button. Without it
    /// the second pass is pixel-identical to the first, and 戻る on the use-case
    /// page walks back to keyboard setup instead of returning to the list the
    /// user came from.
    @State private var isAddingAnother = false

    private static let totalPages = 11

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
                    existingButtonTitles: useCasePageExistingTitles,
                    onBack: { backFromUseCasePage() },
                    onSkip: { skipUseCasePage() },
                    onContinue: { useCase in
                        selectedUseCase = useCase
                        builderSelections = BuilderSelections()
                        builtButtonId = nil
                        if OnboardingButtonBuilder.spec(for: useCase) == nil {
                            // `.custom` collected its description on the
                            // use-case page and already built its button, so it
                            // has nothing to ask on 3–4.
                            isAddingAnother = false
                            jump(to: 5)
                        } else {
                            AppAnalytics.capture("onboarding_button_builder_started", properties: [
                                "use_case": useCase.rawValue,
                                "onboarding_version": InteractiveOnboardingState.version,
                            ])
                            advance()
                        }
                    }
                )
            case 3:
                if let spec = builderSpec {
                    ButtonBuilderSlotsPage(
                        progress: progress(for: 3),
                        spec: spec,
                        isAdditional: isAddingAnother,
                        selections: $builderSelections,
                        onBack: goBack,
                        onSkip: { skipBuilder(page: "slots") },
                        onContinue: advance
                    )
                } else {
                    Color.clear.onAppear { jump(to: 5) }
                }
            case 4:
                if let useCase = selectedUseCase, let spec = builderSpec {
                    ButtonBuilderResultPage(
                        progress: progress(for: 4),
                        spec: spec,
                        useCase: useCase,
                        selections: $builderSelections,
                        builtButtonId: $builtButtonId,
                        onBack: goBack,
                        onSkip: { skipBuilder(page: "result") },
                        onFinish: {
                            isAddingAnother = false
                            advance()
                        }
                    )
                } else {
                    Color.clear.onAppear { jump(to: 5) }
                }
            case 5:
                // One button is a single editable card — a list of one is a list
                // that looks broken. Past that, ordering and removal start to
                // matter, so it becomes the real list: drag to pick the main
                // button, swipe to delete, tap to edit.
                if builtButtonCount == 1 {
                    ButtonBuilderReviewPage(
                        progress: progress(for: 5),
                        onBack: backFromPromptPage,
                        onSkip: { skip("button_review") },
                        onAddAnother: startAddAnother,
                        onContinue: advance
                    )
                } else {
                    KeyboardPromptsPage(
                        progress: progress(for: 5),
                        onAddAnother: addAnotherAction,
                        onBack: backFromPromptPage,
                        onSkip: { skip("prompt_setup") },
                        onContinue: advance
                    )
                }
            case 6:
                KeyboardSwitchPracticePage(
                    progress: progress(for: 6),
                    style: selectedStyle,
                    onBack: goBack,
                    onSkip: { skip("keyboard_switch_practice") },
                    onContinue: advance
                )
            case 7:
                RewritePracticePage(
                    progress: progress(for: 7),
                    style: selectedStyle,
                    prompt: OnboardingPromptSetup.load().first ?? UserPromptDefaults.seedEntries()[0],
                    onBack: goBack,
                    onSkip: { skip("rewrite_practice") },
                    onContinue: advance
                )
            case 8:
                ReplyPracticePage(
                    progress: progress(for: 8),
                    onBack: goBack,
                    onSkip: { skip("reply_practice") },
                    onContinue: advance
                )
            case 9:
                OnboardingSourcePage(
                    progress: progress(for: 9),
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
                    progress: progress(for: 10),
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

    /// Read from the stored prompts rather than tracked in state, so it survives
    /// the app being backgrounded partway through onboarding.
    private var builtButtons: [UserPrompt] {
        OnboardingPromptSetup.load().filter { $0.origin == .onboardingBuilder }
    }

    private var builtButtonCount: Int { builtButtons.count }

    private var useCasePageExistingTitles: [String] {
        isAddingAnother ? builtButtons.map(\.title) : []
    }

    /// Offered only to people who actually built something: committing a button
    /// discards everything that is not builder-made, which would silently wipe a
    /// skipper's seeded defaults.
    private var addAnotherAction: (() -> Void)? {
        guard builtButtonCount > 1 else { return nil }
        return startAddAnother
    }

    /// Non-nil only when pages 3–4 are part of this user's route — `.custom`
    /// jumps straight to 5, and without this, pressing 戻る there would walk
    /// them into a builder that has nothing to ask.
    private var builderSpec: ButtonBuilderSpec? {
        guard let selectedUseCase else { return nil }
        return OnboardingButtonBuilder.spec(for: selectedUseCase)
    }

    /// Page 5 is reached either by stepping through the builder or by jumping
    /// over it, so "back" has two different meanings.
    private func backFromPromptPage() {
        if builderSpec == nil {
            jump(to: 2)
        } else {
            goBack()
        }
    }

    private func jump(to page: Int) {
        let target = min(Self.totalPages - 1, max(0, page))
        InteractiveOnboardingState.writePageIndex(target)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            pageIndex = target
        }
    }

    /// Skipping any builder page leaves whatever is already stored alone, so
    /// jump past the rest of the builder rather than stepping through it.
    private func skipBuilder(page: String) {
        AppAnalytics.capture("onboarding_button_builder_skipped", properties: [
            "page": page,
            "use_case": selectedUseCase?.rawValue ?? "unknown",
            "is_additional": isAddingAnother,
            "onboarding_version": InteractiveOnboardingState.version,
        ])
        isAddingAnother = false
        jump(to: 5)
    }

    /// Replays the use-case page for an extra button. Back to page 2 rather than
    /// the slot page: a second button is usually a second job (敬語 then 英訳),
    /// and resuming mid-builder would lock it to the first button's use case.
    private func startAddAnother() {
        builderSelections = BuilderSelections()
        builtButtonId = nil
        isAddingAnother = true
        jump(to: 2)
    }

    /// Backing out of an extra button returns to the list it was started from,
    /// not to keyboard setup. Nothing was committed yet, so there is nothing to
    /// undo — only the in-progress selections are dropped.
    private func backFromUseCasePage() {
        guard isAddingAnother else {
            goBack()
            return
        }
        builderSelections = BuilderSelections()
        builtButtonId = nil
        isAddingAnother = false
        jump(to: 5)
    }

    /// スキップ on an add-another pass abandons the extra button rather than
    /// skipping the whole step — the step was already completed once.
    private func skipUseCasePage() {
        guard isAddingAnother else {
            skip("use_case")
            return
        }
        backFromUseCasePage()
    }

    /// The bar would otherwise rewind from 6/11 to 3/11 when someone chooses to
    /// add a second button, reading as lost progress when the extra button is
    /// optional and additive. Hold it at the page the loop returns to.
    private func progress(for index: Int) -> Double {
        let effective = isAddingAnother ? max(index, 5) : index
        return Double(effective + 1) / Double(Self.totalPages)
    }

    /// Practice mode stays armed for the whole keyboard section (pages 1–8), not
    /// just the three exercise pages. Disarming in between made arming a race
    /// against the keyboard's own appearance: the extension reads the flag when
    /// it appears, and an appearance that ran before the container's write was
    /// visible in that process skipped the progress signals for the entire
    /// presentation — the page then sat there unresponsive. Arming once removes
    /// the race; the exercise pages only swap in their own candidates.
    private func configurePractice(for index: Int) {
        guard (1...8).contains(index) else {
            InteractiveOnboardingState.disarmPractice()
            return
        }
        if index == 8 {
            InteractiveOnboardingState.armPractice(
                candidates: OnboardingPracticeScenario.replyCandidates
            )
            return
        }
        let prompt = OnboardingPromptSetup.load().first ?? UserPromptDefaults.seedEntries()[0]
        InteractiveOnboardingState.armPractice(
            candidates: OnboardingPracticeScenario.make(for: prompt).candidates
        )
    }
}

// MARK: - Switch practice

/// Guided exercise 1: switch to 敬語ボタン with the globe key and type a short
/// phrase. Completion is detected from the real keyboard — the active input mode
/// plus the App Group progress signals — never from taps on fake UI.
private struct KeyboardSwitchPracticePage: View {
    let progress: Double
    let style: KeyboardPreferences.KeyboardStyle
    let onBack: () -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var keyboardStatus = KeyboardStatusContext(bundleId: "com.core7.keigobutton.keyboard")
    @State private var text = ""
    @State private var pageOpenedAt = Date()
    @State private var initialOpenCount: Int?
    @State private var didOpenKeyboard = false
    @State private var didTypeWithKeyboard = false
    @State private var isShowingSwitchSuccess = false
    @State private var reportedKeyboardOpen = false
    @State private var reportedTyped = false
    @State private var isUnlockedByTimeout = false
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
            isCtaEnabled: isComplete || isUnlockedByTimeout,
            onCta: {
                isEditorFocused = false
                AppAnalytics.capture("onboarding_keyboard_practice_completed", properties: [
                    "input_style": style.rawValue,
                    "detected": isComplete,
                    "onboarding_version": InteractiveOnboardingState.version,
                ])
                onContinue()
            },
            ctaAvoidsKeyboard: true
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    OnboardingTitleBlock(
                        title: "敬語ボタンに\n切り替えてみましょう",
                        subtitle: "キーボード左下の地球儀キーを長押しして、「敬語ボタン」を選びます。",
                        isCompact: isEditorFocused
                    )
                    .padding(.top, isEditorFocused ? 12 : 24)

                    OnboardingPracticeField(
                        text: $text,
                        isFocused: $isEditorFocused,
                        placeholder: LocalizedStringKey("ここに「\(practicePhrase)」と入力"),
                        isCompact: isEditorFocused
                    )
                    .padding(.top, isEditorFocused ? 16 : 28)

                    OnboardingPracticeStatus(
                        symbol: statusSymbol,
                        text: statusText,
                        hint: statusHint,
                        isComplete: isComplete || isShowingSwitchSuccess
                    )
                    .padding(.top, isEditorFocused ? 12 : 18)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            refreshStatus(initialize: true)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 450_000_000)
                isEditorFocused = true
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            keyboardStatus.refresh()
            refreshStatus(initialize: false)
            if !isComplete {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    isEditorFocused = true
                }
            }
        }
        .task {
            var tick = 0
            while !Task.isCancelled {
                // `refresh()` publishes on every call, and a re-render during
                // composition corrupts marked text (see the rewrite page). So the
                // active-keyboard probe runs on a slow cadence, stops the moment
                // the switch is detected, and in the worst case stops at the
                // timeout — a bounded handful of publishes in the first seconds,
                // never a poll that runs while the user is mid-phrase.
                if !didOpenKeyboard, !isUnlockedByTimeout, tick % 4 == 0 {
                    keyboardStatus.refresh()
                    #if DEBUG
                    logKeyboardStatusProbe()
                    #endif
                }
                refreshStatus(initialize: false)
                tick += 1
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
        // With the keyboard already up the first step is done, and this line is
        // the only instruction on screen (the subtitle collapses), so it must not
        // still be asking for a tap.
        if isEditorFocused {
            return "キーボード左下の地球儀キーを長押し →「敬語ボタン」を選択"
        }
        return "入力欄をタップ → 地球儀キーを長押し →「敬語ボタン」を選択"
    }

    private var statusSymbol: String {
        if isComplete || isShowingSwitchSuccess { return "checkmark" }
        if didOpenKeyboard { return "text.cursor" }
        return "globe"
    }

    /// Surfaced once the timeout has opened the CTA, so the escape is visible
    /// instead of the user having to notice that 次へ went from grey to dark.
    private var statusHint: LocalizedStringKey? {
        guard isUnlockedByTimeout, !isComplete else { return nil }
        return "うまく反応しないときは、このまま「次へ」で進めます。"
    }

    /// Signals are accepted from shortly before the page opened, not strictly
    /// after it. The extension stamps them on its own schedule, and a switch made
    /// during the page transition landed just outside a strict comparison.
    private var signalCutoff: Date {
        pageOpenedAt.addingTimeInterval(-30)
    }

    #if DEBUG
    /// TEMPORARY (2026-08-04): verifies on iOS 26 that KeyboardKit's status probe
    /// still resolves input-mode identifiers — it reads them via private KVC, so a
    /// hardened OS would silently report "not active" forever. Remove once
    /// confirmed on a real device.
    private func logKeyboardStatusProbe() {
        let modes = UITextInputMode.activeInputModes.map { mode -> String in
            (mode.value(forKey: "identifier") as? String) ?? "nil(\(mode.primaryLanguage ?? "?"))"
        }
        let seenAt = KeyboardSettingsStore.readOnboardingPracticeSignal(
            KeyboardSettingsStore.onboardingPracticeKeyboardSeenAtKey
        )
        NSLog(
            "%@",
            "🔎 [switch-probe] active=\(keyboardStatus.isKeyboardActive) "
                + "enabled=\(keyboardStatus.isKeyboardEnabled) "
                + "seenAt=\(seenAt.map { String(format: "%.1fs", Date().timeIntervalSince($0)) } ?? "nil") "
                + "practiceArmed=\(KeyboardSettingsStore.readOnboardingPracticeActive()) "
                + "modes=\(modes)"
        )
    }
    #endif

    private func refreshStatus(initialize: Bool) {
        if initialize {
            pageOpenedAt = Date()
        }
        let usage = KeyboardUsageDailyStore.currentDayUsage()
        if initialize || initialOpenCount == nil {
            initialOpenCount = usage.opens
        }

        // Three independent proofs of "the user is on our keyboard". The first is
        // a state, not an event, and is the one that matters: the other two only
        // fire on a fresh keyboard appearance, so a user who was already on
        // 敬語ボタン when this page opened produced no evidence at all and could
        // never finish the exercise.
        let openedViaActiveMode = keyboardStatus.isKeyboardActive
        let seenAt = KeyboardSettingsStore.readOnboardingPracticeSignal(
            KeyboardSettingsStore.onboardingPracticeKeyboardSeenAtKey
        )
        let openedViaSignal = (seenAt ?? .distantPast) > signalCutoff
        let openedViaCount = initialOpenCount.map { usage.opens > $0 } ?? false
        if !initialize, !didOpenKeyboard, openedViaActiveMode || openedViaSignal || openedViaCount {
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
        if !initialize, !didTypeWithKeyboard, (typedAt ?? .distantPast) > signalCutoff {
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

        // Last line of defence: detection must never be the only way forward.
        // Whatever else failed, the CTA opens after 20 s and the miss is reported
        // with the sub-signals, so the gap is measurable instead of invisible.
        if !initialize, !isComplete, !isUnlockedByTimeout,
           Date().timeIntervalSince(pageOpenedAt) > 20 {
            isUnlockedByTimeout = true
            AppAnalytics.capture("onboarding_practice_stalled", properties: [
                "page": "keyboard_switch",
                "input_style": style.rawValue,
                "opened": didOpenKeyboard,
                "typed": didType,
                "keyboard_active": keyboardStatus.isKeyboardActive,
                "keyboard_enabled": keyboardStatus.isKeyboardEnabled,
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
    @State private var isUnlockedByTimeout = false
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

    /// The timeout unlock ignores `needsKeyboard` on purpose: that flag comes from
    /// the system's active-input-mode list, and when it reads wrong there is no
    /// action the user can take that clears it — 「設定を開く」 forever is the
    /// worst dead end of the three pages.
    private var canAdvance: Bool {
        didAcceptRewrite || isUnlockedByTimeout
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
            ctaTitle: !canAdvance && needsKeyboard ? "設定を開く" : "次へ",
            isCtaEnabled: canAdvance || needsKeyboard,
            onCta: handleCTA,
            ctaAvoidsKeyboard: true
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    OnboardingTitleBlock(
                        title: "AIボタンで\n書き換えてみましょう",
                        subtitle: "キーボード上の「\(prompt.title)」を押すと、候補が3つ出ます。気に入った候補をタップすると、その文章に置き換わります。",
                        isCompact: isEditorFocused
                    )
                    .padding(.top, isEditorFocused ? 12 : 24)

                    OnboardingPracticeField(
                        text: $text,
                        isFocused: $isEditorFocused,
                        placeholder: nil,
                        isCompact: isEditorFocused
                    )
                    .padding(.top, isEditorFocused ? 16 : 28)

                    OnboardingPracticeStatus(
                        symbol: statusSymbol,
                        text: statusText,
                        hint: statusHint,
                        isComplete: didAcceptRewrite
                    )
                    .padding(.top, isEditorFocused ? 12 : 18)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            InteractiveOnboardingState.armPractice(candidates: scenario.candidates)
            // Both exercises share the accepted-at key; drop any stamp from a
            // previous page so it can't complete this one.
            KeyboardSettingsStore.clearOnboardingPracticeSignal(
                KeyboardSettingsStore.onboardingPracticeAcceptedAtKey
            )
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
        // Carries both steps, not just the button press: while the keyboard is up
        // the subtitle collapses and this is the only place the tap-to-replace
        // gesture is explained.
        return "候補バーの上の「\(prompt.title)」を押して、気に入った候補をタップしてください"
    }

    private var statusSymbol: String {
        if didAcceptRewrite { return "checkmark" }
        if needsKeyboard { return "gearshape" }
        return "hand.tap"
    }

    private var statusHint: LocalizedStringKey? {
        guard isUnlockedByTimeout, !didAcceptRewrite else { return nil }
        return "うまく反応しないときは、このまま「次へ」で進めます。"
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
        // A rewrite is two keyboard interactions, so this page gets longer than
        // the switch page before it stops blocking.
        if !didAcceptRewrite, !isUnlockedByTimeout,
           Date().timeIntervalSince(pageOpenedAt) > 35 {
            isUnlockedByTimeout = true
            AppAnalytics.capture("onboarding_practice_stalled", properties: [
                "page": "rewrite",
                "input_style": style.rawValue,
                "command_title": prompt.title,
                "needs_keyboard": needsKeyboard,
                "keyboard_active": keyboardStatus.isKeyboardActive,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
        }
    }

    private func handleCTA() {
        if canAdvance {
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
    @State private var isUnlockedByTimeout = false
    @FocusState private var isEditorFocused: Bool

    /// Reading the pasteboard from the keyboard needs Full Access, so the
    /// exercise checks it (unlike the rewrite practice, which is fully local).
    private var needsSettings: Bool {
        !keyboardStatus.isKeyboardEnabled
            || !(keyboardStatus.isFullAccessEnabled || KeyboardSettingsStore.readLastKnownFullAccessEnabled())
    }

    private var canAdvance: Bool {
        didAcceptReply || isUnlockedByTimeout
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
            ctaTitle: !canAdvance && needsSettings ? "設定を開く" : "次へ",
            isCtaEnabled: canAdvance || needsSettings,
            onCta: handleCTA,
            ctaAvoidsKeyboard: true
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    OnboardingTitleBlock(
                        title: "返信も、\nコピーするだけ",
                        subtitle: "相手のメッセージをコピーすると、キーボードに「返信」ボタンが現れます。",
                        isCompact: isEditorFocused
                    )
                    .padding(.top, isEditorFocused ? 12 : 24)

                    ReplyIncomingMessageCard(
                        message: OnboardingPracticeScenario.replyIncomingMessage,
                        copied: copied,
                        onCopy: copyIncomingMessage
                    )
                    .padding(.top, isEditorFocused ? 16 : 28)

                    OnboardingPracticeField(
                        text: $reply,
                        isFocused: $isEditorFocused,
                        placeholder: "返信がここに入ります",
                        isCompact: isEditorFocused
                    )
                    .padding(.top, 12)

                    OnboardingPracticeStatus(
                        symbol: statusSymbol,
                        text: statusText,
                        hint: statusHint,
                        isComplete: didAcceptReply
                    )
                    .padding(.top, isEditorFocused ? 12 : 18)

                    Spacer(minLength: 12)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            InteractiveOnboardingState.armPractice(candidates: OnboardingPracticeScenario.replyCandidates)
            // The rewrite page stamps the same accepted-at key; drop it so the
            // previous exercise can't complete this one.
            KeyboardSettingsStore.clearOnboardingPracticeSignal(
                KeyboardSettingsStore.onboardingPracticeAcceptedAtKey
            )
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

    private var statusHint: LocalizedStringKey? {
        guard isUnlockedByTimeout, !didAcceptReply else { return nil }
        return "うまく反応しないときは、このまま「次へ」で進めます。"
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
        // Copy → switch fields → press 返信 → tap a candidate: the longest of the
        // three exercises, so it waits longest before it stops blocking.
        if !didAcceptReply, !isUnlockedByTimeout,
           Date().timeIntervalSince(pageOpenedAt) > 45 {
            isUnlockedByTimeout = true
            AppAnalytics.capture("onboarding_practice_stalled", properties: [
                "page": "reply",
                "copied": copied,
                "needs_settings": needsSettings,
                "keyboard_active": keyboardStatus.isKeyboardActive,
                "onboarding_version": InteractiveOnboardingState.version,
            ])
        }
    }

    private func handleCTA() {
        if canAdvance {
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
    /// Shrinks to three lines of text while the keyboard is up. Drive this from
    /// focus only — never from `text` — because re-laying out the TextEditor
    /// mid-composition corrupts the marked text.
    var isCompact: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty, let placeholder {
                Text(placeholder)
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(OnboardingPalette.subInk.opacity(0.55))
                    .padding(.horizontal, 21)
                    .padding(.vertical, isCompact ? 14 : 20)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .focused(isFocused)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(
                    minHeight: isCompact ? 84 : 128,
                    maxHeight: isCompact ? 104 : 152
                )
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OnboardingPalette.heroFill)
        )
    }
}

/// One-line live status under the practice field: what to do next, and a
/// green check once the step is done. `hint` adds a quieter second line without
/// taking the instruction away — used to surface the "just continue" escape when
/// detection has not fired.
private struct OnboardingPracticeStatus: View {
    let symbol: String
    let text: LocalizedStringKey
    var hint: LocalizedStringKey? = nil
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

            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OnboardingPalette.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let hint {
                    Text(hint)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(OnboardingPalette.subInk)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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

// The 完了 keyboard accessory that used to sit here existed only to collapse the
// keyboard and reveal the CTA hidden behind it. The CTA now rides above the
// keyboard, so the accessory was a second bar competing for the same 46 pt;
// swipe-to-dismiss on the practice scroll views replaces it.
