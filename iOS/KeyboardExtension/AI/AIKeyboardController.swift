import JapaneseKeyboardAI
import JapaneseKeyboardCore
import KeyboardPreferences
import KeyboardKit
import SwiftUI
import UIKit

@MainActor
final class AIKeyboardController: ObservableObject {
    static let settingsURL = URL(string: "keigobutton://settings")!
    static let loginURL = URL(string: "keigobutton://login")!
    static let fullAccessURL = URL(string: "keigobutton://fullaccess")!
    static let consentURL = URL(string: "keigobutton://consent")!
    static let updateURL = URL(string: "keigobutton://update")!
    /// Candidates requested per generation. Also the number of shimmer
    /// placeholders shown before any have streamed in.
    static let candidateCount = 3

    @Published private(set) var state: AIKeyboardState = .hidden
    @Published private(set) var mainPrompt: UserPrompt? = UserPromptStore.mainPrompt()
    @Published private(set) var subPrompts: [UserPrompt] = UserPromptStore.subPrompts()
    /// True when the clipboard holds a freshly copied message the user can reply
    /// to. Detected from pasteboard metadata only (no content read, no banner).
    @Published private(set) var replyAvailable: Bool = false
    /// True when the container's App Store check relayed a newer version via the
    /// App Group (the extension itself never checks the network for this).
    @Published private(set) var updateAvailable: Bool = false

    @Published private(set) var readiness: AIReadiness = .ready
    @Published private(set) var recoveryNavigation = AIRecoveryNavigation()
    private var rejectedAccessToken: String?

    var hasFullAccess: Bool { controller?.hasFullAccess == true }
    var needsReauthentication: Bool { rejectedAccessToken != nil }

    func refreshRecoveryState(onAppearance: Bool = false) {
        if onAppearance { recoveryNavigation.dismiss() }
        let token = AIAuthStore.readAccessToken()
        if token != rejectedAccessToken { rejectedAccessToken = nil }
        readiness = AIReadiness.evaluate(
            practice: isPracticeModeActive, fullAccess: hasFullAccess,
            hasToken: token != nil, sessionRejected: rejectedAccessToken != nil,
            consent: KeyboardSettingsStore.readAIConsentGranted(),
            cloudEnabled: KeyboardSettingsStore.readCloudAIEnabled()
        )
        if recoveryNavigation.help?.reason == .fullAccessDisabled && hasFullAccess {
            recoveryNavigation.dismiss()
        }
        switch state {
        case .signInRequired, .consentRequired, .fullAccessRequired, .cloudDisabled:
            state = .hidden
        default: break
        }
    }

    func openDestination(_ destination: AIRecoveryDestination,
                         using open: (URL, @escaping (Bool) -> Void) -> Void) {
        refreshRecoveryState()
        inputManager.collapseCandidateList()
        guard let id = recoveryNavigation.begin(destination, fullAccess: hasFullAccess) else { return }
        open(destination.url) { [weak self] accepted in
            Task { @MainActor in
                self?.recoveryNavigation.complete(id, destination: destination, accepted: accepted)
            }
        }
    }

    private weak var controller: KeyboardViewController?
    private let fallbackInputManager: InputManager
    private var inputManager: InputManager {
        controller?.inputManager ?? fallbackInputManager
    }
    private var rewriteTask: Task<Void, Never>?
    /// Where the user scrolled while a batch was still streaming in, including
    /// onto a shimmer placeholder. `nil` means they never took over, so
    /// completion falls back to focusing the first card of the new batch.
    private var generationScrollIndex: Int?
    /// The in-flight full-document replacement. Deliberately not cancelled by
    /// `close()`: cancelling between the move-to-end hops and the delete loop
    /// would leave the document half-replaced.
    private var replaceTask: Task<Void, Never>?
    /// True while the full-document reader/replacer is programmatically moving
    /// the cursor. Those moves fire `selectionDidChange` → `documentDidChange`,
    /// and the host can transiently report a different/absent `documentIdentifier`
    /// mid-move — which would otherwise `close()` and cancel our own walk. We
    /// suppress the auto-close for the duration of the self-induced movement;
    /// the toolbar's explicit close still calls `close()` directly.
    private var isMovingCursorInternally = false
    /// Maps the combined candidate list back to the rewrite event that produced
    /// each segment (start index → event id), so an accepted candidate is
    /// reported to the right event. Reset when a fresh generation begins.
    private var generationSegments: [(eventId: String, start: Int, attempt: RewriteAttemptMetadata)] = []
    /// When the current result was first shown, for action latency (how long the
    /// user considered the candidates before regenerating or dismissing).
    private var resultShownAt: Date?
    private var attempt: RewriteAttemptMetadata?
    private var firstCandidateShown = false
    /// The copied message for the active reply session. Set on `runReply`, reused
    /// by `regenerate`, cleared by `runFresh` and `close`.
    private var replyContext: String?
    /// Polls the pasteboard while the keyboard is visible. iOS delivers no
    /// notification when another app copies, so a freshly copied message would
    /// otherwise not surface the 返信 pill until the next text/selection change.
    private var clipboardMonitor: Timer?
    /// When the keyboard last appeared, and the change count the pill was last
    /// raised for. Process-wide rather than per-instance because iOS can deliver
    /// a second appearance callback for one presentation — possibly onto a fresh
    /// controller — and the pill has to survive that without it counting as the
    /// user reopening the keyboard.
    private static var lastAppearedAt: Date?
    private static var lastPromotedChangeCount: Int?
    /// Appearance callbacks this close together are one presentation. Anything
    /// later is the user having closed and reopened the keyboard.
    private static let samePresentationWindow: TimeInterval = 2

    init(controller: KeyboardViewController, inputManager: InputManager) {
        self.controller = controller
        self.fallbackInputManager = inputManager
        refreshRecoveryState()
    }

    var isActive: Bool {
        if case .hidden = state { return false }
        return true
    }

    func refreshPrompts() {
        mainPrompt = UserPromptStore.mainPrompt()
        subPrompts = UserPromptStore.subPrompts()
        if subPrompts.isEmpty, case .overflow = state {
            state = .hidden
        }
    }

    func canOpenAI() -> Bool {
        guard !inputManager.isComposing else { return true }
        guard let controller else { return false }
        return (try? InputCapture.capture(from: controller.textDocumentProxy.ai)) != nil
    }

    func isSignedInForAI() -> Bool {
        AIAuthStore.readAccessToken() != nil
    }

    /// Onboarding practice mode: armed by the container while the user is on
    /// the guided practice pages. The toolbar shows the AI buttons before
    /// sign-in and `fire` answers with local practice candidates — no network.
    var isPracticeModeActive: Bool {
        KeyboardSettingsStore.readOnboardingPracticeActive()
    }

    func close(reason: String = "explicit_dismissal") {
        recoveryNavigation.dismiss()
        if case .result(_, _, _, let selectedIndex) = state {
            reportAction("dismissed", selectedIndex: selectedIndex)
            recordResultClose(reason, selectedIndex: selectedIndex)
        } else if case .generating = state {
            recordDiagnostic("ai_rewrite_generation_cancelled", extra: ["close_reason": reason])
        }
        rewriteTask?.cancel()
        rewriteTask = nil
        isMovingCursorInternally = false
        replyContext = nil
        resultShownAt = nil
        state = .hidden
    }

    /// Re-evaluates the reply pill on keyboard appearance: a copy the pill has
    /// not been raised for yet shows it, an already-offered clipboard hides it.
    /// Also starts polling so a copy made while the keyboard stays open surfaces
    /// the pill. Safe to call repeatedly within one presentation.
    func refreshReplyAvailabilityOnAppear() {
        let now = Date()
        let isSamePresentation = Self.lastAppearedAt.map {
            now.timeIntervalSince($0) < Self.samePresentationWindow
        } ?? false
        Self.lastAppearedAt = now
        replyAvailable = false
        promoteReplyIfFreshCopy(rePromotingLastCopy: isSamePresentation)
        startClipboardMonitoring()
    }

    /// Re-reads the container-relayed update nudge on keyboard appearance.
    func refreshUpdateNudgeOnAppear() {
        updateAvailable = AppUpdateNudge.shouldShowNudge(currentVersion: Self.appVersion)
    }

    private func startClipboardMonitoring() {
        clipboardMonitor?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.promoteReplyIfFreshCopy() }
        }
        timer.tolerance = 0.2
        clipboardMonitor = timer
    }

    func stopClipboardMonitoring() {
        clipboardMonitor?.invalidate()
        clipboardMonitor = nil
    }

    /// Promotes the reply pill if something new was copied while the keyboard is
    /// already visible. Never hides an already-shown pill within a session.
    func refreshReplyAvailability() {
        promoteReplyIfFreshCopy()
    }

    /// Detects a freshly copied message using pasteboard metadata only
    /// (`changeCount` / `hasStrings`) — no content access, so iOS shows no paste
    /// banner. The count is consumed here, the moment the pill is raised: one
    /// copy earns one offer, so closing and reopening the keyboard hides the pill
    /// again. Consuming it on disappearance instead left the pill stuck forever
    /// whenever the extension went away without `viewWillDisappear` running to
    /// completion (host backgrounded, jetsam, the App Group write dying with the
    /// process) — nothing else ever lowers the pill.
    ///
    /// `rePromotingLastCopy` covers the one case that must not consume: iOS
    /// delivering a second appearance callback for the same presentation. That
    /// re-run resets `replyAvailable`, and without re-promotion the copy-then-
    /// focus flow (copy, then tap the field) could never raise the pill.
    private func promoteReplyIfFreshCopy(rePromotingLastCopy: Bool = false) {
        guard !replyAvailable else { return }
        let pasteboard = UIPasteboard.general
        let current = pasteboard.changeCount
        let isFreshCopy = current != KeyboardSettingsStore.readLastSeenPasteboardChangeCount()
        guard isFreshCopy || (rePromotingLastCopy && current == Self.lastPromotedChangeCount) else { return }
        let hasStrings = pasteboard.hasStrings
        #if DEBUG
        NSLog("%@", "📋 [reply-pill] changeCount=\(current) hasStrings=\(hasStrings) fresh=\(isFreshCopy)")
        #endif
        // A cold-launching extension can report the copy's changeCount before the
        // item itself is readable; the poll retries until `hasStrings` is true.
        guard hasStrings else { return }
        Self.lastPromotedChangeCount = current
        KeyboardSettingsStore.writeLastSeenPasteboardChangeCount(current)
        withAnimation(.easeInOut(duration: 0.28)) {
            replyAvailable = true
        }
    }

    /// Reads the clipboard and starts a reply. Reading `UIPasteboard.general.string`
    /// here triggers the iOS paste permission prompt. (A `UIPasteControl`-based
    /// path that avoids the prompt is deferred — see docs/ai-rewrite.md.)
    func runReplyFromClipboard() {
        // Practice mode answers with canned replies that don't use the copied
        // text, so skip the pasteboard read — it would hit the iOS paste
        // permission prompt, and a denial would dead-end the exercise.
        if isPracticeModeActive {
            runReply(withCopiedText: "練習")
            return
        }
        runReply(withCopiedText: UIPasteboard.general.string ?? "")
    }

    /// Starts a reply with the given message text (e.g. delivered by a future
    /// system paste control). Empty text surfaces a Japanese error.
    func runReply(withCopiedText text: String) {
        guard let controller else { return }
        beginAttempt()
        let copied = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !copied.isEmpty else {
            failAttempt("reply_source_empty")
            state = .error(prompt: UserPromptDefaults.replyPrompt(), message: "返信元のメッセージをコピーしてください")
            return
        }

        if inputManager.isComposing {
            controller.flushBufferToHost()
        }

        let capture: WholeInputCapture
        do {
            capture = try InputCapture.captureForReply(from: controller.textDocumentProxy.ai)
        } catch WholeInputCaptureError.tooLong {
            failAttempt("input_too_long")
            state = .error(prompt: UserPromptDefaults.replyPrompt(), message: "入力が長すぎます")
            return
        } catch {
            failAttempt("capture_unavailable")
            state = .error(prompt: UserPromptDefaults.replyPrompt(), message: "返信を作成できませんでした")
            return
        }

        replyContext = copied
        fire(
            prompt: UserPromptDefaults.replyPrompt(),
            capture: capture,
            inputText: capture.targetText,
            refinement: nil,
            existing: [],
            replyTo: copied
        )
    }

    func toggleOverflow() {
        guard !subPrompts.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.28)) {
            if case .overflow = state {
                state = .hidden
            } else {
                state = .overflow
            }
        }
    }

    func runMain() {
        guard let prompt = mainPrompt else {
            state = .error(prompt: nil, message: "プロンプトが設定されていません")
            return
        }
        runFresh(prompt: prompt)
    }

    func runFromOverflow(_ prompt: UserPrompt) {
        runFresh(prompt: prompt)
    }

    func selectCandidate(index: Int) {
        // Mid-generation the index can point at a shimmer placeholder, which is
        // not selectable yet — just remember it, so the arrival of the last
        // candidate doesn't yank the user back to the first card.
        if case .generating = state {
            generationScrollIndex = index
            return
        }
        guard case .result(let prompt, let capture, let candidates, _) = state else { return }
        guard candidates.indices.contains(index) else { return }
        state = .result(prompt: prompt, capture: capture, candidates: candidates, selectedIndex: index)
    }

    func selectCandidate(id: UUID) {
        guard case .result(_, _, let candidates, _) = state else { return }
        guard let index = candidates.firstIndex(where: { $0.id == id }) else { return }
        selectCandidate(index: index)
    }

    func regenerate() {
        guard case .result(let prompt, let capture, let candidates, _) = state else { return }
        reportAction("regenerated")
        beginAttempt(kind: "regenerate", parent: generationSegments.last)
        fire(prompt: prompt, capture: capture, inputText: capture.targetText, refinement: nil, existing: candidates, replyTo: replyContext)
    }

    func refine(_ intent: RefinementIntent) {
        guard case .result(let prompt, let capture, let candidates, let selectedIndex) = state else { return }
        guard candidates.indices.contains(selectedIndex) else { return }
        let focused = candidates[selectedIndex].replacement
        beginAttempt(kind: "refine", parent: generationSegments.last(where: { $0.start <= selectedIndex }))
        // Refinement operates on the chosen candidate as a plain rewrite, so it
        // does not re-reply (no `replyTo`).
        fire(prompt: prompt, capture: capture, inputText: focused, refinement: intent, existing: candidates)
    }

    func replaceFocusedCandidate() {
        guard let controller else { return }
        guard case .result(_, let capture, let candidates, let selectedIndex) = state else { return }
        guard candidates.indices.contains(selectedIndex) else { return }
        let replacement = candidates[selectedIndex].replacement

        if capture.mode == .fullDocument {
            guard replaceTask == nil else { return }
            inputManager.reset()
            // The chunked move-to-end and delete loop move the cursor and edit
            // text, firing documentDidChange; suppress the auto-close so it
            // doesn't tear down the replacement mid-flight.
            isMovingCursorInternally = true
            replaceTask = Task { [weak self] in
                do {
                    try await WholeInputReplacementEngine.replaceFullDocument(
                        capture: capture,
                        with: replacement,
                        proxy: controller.textDocumentProxy.ai
                    )
                    guard let self else { return }
                    self.isMovingCursorInternally = false
                    KeyboardUsageStatsStore.recordAcceptedRewrite()
                    Self.reportPracticeAcceptedIfNeeded()
                    self.submitSelectionFeedback(for: selectedIndex)
                    self.replaceTask = nil
                    self.state = .hidden
                } catch {
                    self?.isMovingCursorInternally = false
                    self?.replaceTask = nil
                    self?.reportAction("replace_failed", selectedIndex: selectedIndex)
                    self?.recordReplacement("failed", selectedIndex: selectedIndex)
                    self?.state = .error(prompt: nil, message: "入力が変わりました。もう一度実行してください")
                }
            }
            return
        }

        do {
            inputManager.reset()
            try WholeInputReplacementEngine.replace(
                capture: capture,
                with: replacement,
                proxy: controller.textDocumentProxy.ai
            )
            KeyboardUsageStatsStore.recordAcceptedRewrite()
            Self.reportPracticeAcceptedIfNeeded()
            submitSelectionFeedback(for: selectedIndex)
            state = .hidden
        } catch {
            reportAction("replace_failed", selectedIndex: selectedIndex)
            recordReplacement("failed", selectedIndex: selectedIndex)
            state = .error(prompt: nil, message: "入力が変わりました。もう一度実行してください")
        }
    }

    /// Practice-mode completion signal for the onboarding rewrite / reply
    /// exercises: an accepted replacement is the exact moment they're done.
    private static func reportPracticeAcceptedIfNeeded() {
        guard KeyboardSettingsStore.readOnboardingPracticeActive() else { return }
        KeyboardSettingsStore.writeOnboardingPracticeSignal(
            KeyboardSettingsStore.onboardingPracticeAcceptedAtKey
        )
    }

    /// Reports the accepted candidate back to its originating rewrite event.
    /// Fire-and-forget so the replace UI never waits on the network.
    private func submitSelectionFeedback(for selectedIndex: Int) {
        recordReplacement("accepted", selectedIndex: selectedIndex)
        guard let segment = generationSegments.last(where: { $0.start <= selectedIndex }) else { return }
        let eventId = segment.eventId
        let localIndex = selectedIndex - segment.start
        let service = CloudRewriteService(configuration: CloudRewriteConfiguration(appVersion: Self.appVersion))
        Task.detached {
            await service.submitSelection(eventId: eventId, selectedIndex: localIndex)
        }
    }

    /// Reports a lifecycle action (regenerated / dismissed) on the current
    /// result to its latest rewrite event. Fire-and-forget.
    private func reportAction(_ action: String, selectedIndex: Int? = nil) {
        let segment = selectedIndex.flatMap { index in generationSegments.last(where: { $0.start <= index }) }
            ?? generationSegments.last
        guard let eventId = segment?.eventId else { return }
        let latencyMs = resultShownAt.map { Int(Date().timeIntervalSince($0) * 1000) }
        let service = CloudRewriteService(configuration: CloudRewriteConfiguration(appVersion: Self.appVersion))
        Task.detached {
            await service.submitAction(eventId: eventId, action: action, latencyMs: latencyMs)
        }
    }

    func documentDidChange() {
        // Ignore selection/text changes we cause ourselves while walking or
        // replacing the full document — otherwise our own cursor moves cancel
        // the very task performing them.
        guard !isMovingCursorInternally else { return }
        guard let controller else { return }
        let current = String(describing: controller.textDocumentProxy.documentIdentifier)
        switch state {
        case .generating(_, let capture, _, _, _), .result(_, let capture, _, _):
            if capture.documentIdentifierString != current {
                close(reason: "document_changed")
            }
        default:
            break
        }
    }

    private func runFresh(prompt: UserPrompt) {
        guard let controller else { return }
        beginAttempt()
        replyContext = nil

        // Selection mode: rewrite only the highlighted text. Checked before the
        // composing flush — flushing would `insertText` into the selection and
        // destroy it. A selection during active composition is not a real state,
        // so composing keeps the whole-input path.
        if !inputManager.isComposing,
           let selected = controller.textDocumentProxy.ai.selectedText,
           !selected.isEmpty {
            let capture: WholeInputCapture
            do {
                capture = try InputCapture.captureSelection(from: controller.textDocumentProxy.ai)
            } catch WholeInputCaptureError.tooLong {
                failAttempt("input_too_long")
                state = .error(prompt: prompt, message: "入力が長すぎます")
                return
            } catch {
                failAttempt("input_empty_or_unavailable")
                state = .error(prompt: prompt, message: "入力してからAIを使えます")
                return
            }
            fire(prompt: prompt, capture: capture, inputText: capture.targetText, refinement: nil, existing: [])
            return
        }

        let didFlush = inputManager.isComposing
        if didFlush {
            controller.flushBufferToHost()
        }

        // Cheap window capture first: validates the field is non-empty / not
        // over the cap before the (slower) full-document walk. This is also the
        // fallback if the walk can't reliably stitch the document.
        let windowCapture: WholeInputCapture
        do {
            windowCapture = try InputCapture.capture(from: controller.textDocumentProxy.ai)
        } catch WholeInputCaptureError.tooLong {
            failAttempt("input_too_long")
            state = .error(prompt: prompt, message: "入力が長すぎます")
            return
        } catch {
            failAttempt("input_empty_or_unavailable")
            state = .error(prompt: prompt, message: "入力してからAIを使えます")
            return
        }

        // Gate before walking so a ~2s walk is never spent on a user who will
        // just hit a consent / sign-in wall.
        guard passGates(prompt: prompt) else { return }

        // Show the generating UI immediately; the walk runs inside rewriteTask
        // so `close()` cancels it and the reader restores the cursor.
        rewriteTask?.cancel()
        generationSegments = []
        state = .generating(prompt: prompt, capture: windowCapture, refinement: nil, existing: [], pending: Self.candidateCount)

        rewriteTask = Task { [weak self] in
            // The flush lands on the host asynchronously; let it settle before
            // walking or the first window read is stale.
            if didFlush {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            guard !Task.isCancelled, let self, let controller = self.controller else { return }
            // Our own cursor moves must not trip documentDidChange → close().
            self.isMovingCursorInternally = true
            let result = await FullDocumentReader(proxy: controller.textDocumentProxy.ai).read()
            self.isMovingCursorInternally = false
            guard !Task.isCancelled else { return }

            let capture: WholeInputCapture
            switch result {
            case .tooLong:
                self.rewriteTask = nil
                self.failAttempt("input_too_long")
                self.state = .error(prompt: prompt, message: "入力が長すぎます")
                return
            case .failed:
                // Anomaly: fall back to the window capture (today's behavior).
                capture = windowCapture
            case .snapshot(let before, let after):
                let full = try? WholeInputCapture.makeFullDocument(
                    beforeCursor: before,
                    afterCursor: after,
                    documentIdentifierString: windowCapture.documentIdentifierString,
                    maxCharacters: InputCapture.maxCharacters
                )
                // Only genuinely-longer results become .fullDocument; a walk
                // that only saw the window keeps the strict sync replace path.
                if let full, full.targetText != windowCapture.targetText {
                    capture = full
                } else {
                    capture = windowCapture
                }
            }

            // fire() cancels rewriteTask; clear it first so it doesn't cancel
            // the very network task fire is about to start.
            self.rewriteTask = nil
            self.fire(prompt: prompt, capture: capture, inputText: capture.targetText, refinement: nil, existing: [])
        }
    }

    /// The consent / cloud-toggle / full-access / sign-in gates. Sets the
    /// matching state and returns false on the first failure. Called before the
    /// full-document walk so a slow walk is never wasted on a gated user, and
    /// again (idempotently) from `fire`.
    private func passGates(prompt: UserPrompt) -> Bool {
        guard let controller else { return false }
        // Practice mode never touches the network, so the consent / cloud /
        // full-access / sign-in gates don't apply to it.
        if isPracticeModeActive { return true }
        refreshRecoveryState()
        switch readiness {
        case .ready: return true
        case .fullAccessRequired: failAttempt("full_access_required"); state = .fullAccessRequired(prompt: prompt)
        case .signInRequired: failAttempt("sign_in_required"); state = .signInRequired(prompt: prompt)
        case .consentRequired: failAttempt("consent_required"); state = .consentRequired(prompt: prompt)
        case .cloudDisabled: failAttempt("cloud_disabled"); state = .cloudDisabled(prompt: prompt)
        }
        return false
    }

    private func fire(
        prompt: UserPrompt,
        capture: WholeInputCapture,
        inputText: String,
        refinement: RefinementIntent?,
        existing: [RewriteCandidate],
        replyTo: String? = nil
    ) {
        rewriteTask?.cancel()

        guard let controller else { return }

        if existing.isEmpty {
            generationSegments = []
        }

        guard passGates(prompt: prompt) else { return }

        if isPracticeModeActive {
            firePractice(prompt: prompt, capture: capture, inputText: inputText)
            return
        }

        let configuration = CloudRewriteConfiguration(appVersion: Self.appVersion)
        let isSelection = capture.mode == .selection
        let request = RewriteRequest(
            prompt: prompt.prompt,
            text: inputText,
            replyTo: replyTo,
            commandKey: prompt.builtinKey,
            title: prompt.title,
            promptOrigin: prompt.origin.rawValue,
            buttonId: prompt.id.uuidString.lowercased(),
            buttonPurpose: prompt.purpose?.rawValue,
            locale: Self.locale(for: prompt),
            appVersion: configuration.appVersion,
            candidateCount: Self.candidateCount,
            refinement: refinement,
            analyticsAppInstanceId: KeyboardSettingsStore.readAnalyticsAppInstanceId(),
            selection: isSelection,
            selectionContextBefore: isSelection ? String(capture.beforeCursor.suffix(200)) : nil,
            selectionContextAfter: isSelection ? String(capture.afterCursor.prefix(200)) : nil,
            stream: true,
            diagnostics: attempt
        )
        let generationAttempt = attempt ?? RewriteAttemptMetadata()
        firstCandidateShown = false
        recordDiagnostic("ai_rewrite_generation_started")
        let service = CloudRewriteService(configuration: configuration)
        // A new batch starts with the user not having taken over yet.
        generationScrollIndex = nil
        state = .generating(
            prompt: prompt,
            capture: capture,
            refinement: refinement,
            existing: existing,
            pending: Self.candidateCount
        )

        // Shows each candidate the moment it lands, replacing one shimmer
        // placeholder, so the user can start reading the first option while the
        // rest are still being written. Declared here rather than inside the
        // task below so `[weak self]` binds the controller, not the task's own
        // capture. A no-op unless we are still generating, which makes a late
        // callback after cancel or completion harmless.
        let applyStreamedCandidate: @Sendable (RewriteCandidate) -> Void = { [weak self] candidate in
            Task { @MainActor in
                guard let self else { return }
                guard case .generating(
                    let statePrompt, let stateCapture, let stateRefinement, let shown, let pending
                ) = self.state, pending > 0 else { return }
                guard self.attempt?.attemptId == generationAttempt.attemptId else { return }
                if !self.firstCandidateShown {
                    self.firstCandidateShown = true
                    self.recordDiagnostic("ai_rewrite_first_candidate_shown")
                }
                self.state = .generating(
                    prompt: statePrompt,
                    capture: stateCapture,
                    refinement: stateRefinement,
                    existing: shown + [candidate],
                    pending: pending - 1
                )
            }
        }

        rewriteTask = Task { [weak self] in
            do {
                let result = try await service.rewriteStreaming(
                    request,
                    onCandidate: applyStreamedCandidate
                )
                guard !Task.isCancelled else { return }
                let newCandidates = result.candidates.isEmpty
                    ? [RewriteCandidate(replacement: inputText, changed: false)]
                    : result.candidates
                await MainActor.run {
                    guard self?.attempt?.attemptId == generationAttempt.attemptId else { return }
                    let combined = existing + newCandidates
                    if let eventId = result.eventId {
                        self?.generationSegments.append((eventId: eventId, start: existing.count, attempt: generationAttempt))
                        self?.recordDiagnostic("ai_rewrite_result_shown", extra: ["event_id": eventId])
                    }
                    // Default to the first card of the new batch, but if the user
                    // scrolled while it was streaming in, leave them there — the
                    // scroll position may point past what actually arrived, so
                    // clamp it.
                    let scrolled = self?.generationScrollIndex
                    self?.generationScrollIndex = nil
                    let focused = min(
                        max(scrolled ?? existing.count, 0),
                        max(combined.count - 1, 0)
                    )
                    self?.state = .result(
                        prompt: prompt,
                        capture: capture,
                        candidates: combined,
                        selectedIndex: focused
                    )
                    self?.resultShownAt = Date()
                    self?.rewriteTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self?.attempt?.attemptId == generationAttempt.attemptId else { return }
                    self?.recordDiagnostic("ai_rewrite_generation_failed", extra: ["failure_reason": Self.failureCategory(error)])
                    if error as? CloudRewriteError == .credentialsChanged {
                        self?.state = .hidden
                        self?.refreshRecoveryState()
                    } else if case .sessionRejected(let token) = error as? CloudRewriteError {
                        if AIAuthStore.readAccessToken() == token {
                            self?.rejectedAccessToken = token
                            self?.readiness = .signInRequired
                            self?.state = .signInRequired(prompt: prompt)
                        } else {
                            self?.state = .hidden
                            self?.refreshRecoveryState()
                        }
                    } else if error as? CloudRewriteError == .notSignedIn {
                        self?.state = .hidden
                        self?.refreshRecoveryState()
                        if self?.readiness == .signInRequired {
                            self?.state = .signInRequired(prompt: prompt)
                        }
                    } else {
                        self?.state = .error(prompt: prompt, message: Self.message(for: error))
                    }
                    self?.rewriteTask = nil
                }
            }
        }
    }

    private func beginAttempt(kind: String = "fresh", parent: (eventId: String, start: Int, attempt: RewriteAttemptMetadata)? = nil) {
        if case .generating = state {
            recordDiagnostic("ai_rewrite_generation_cancelled", extra: ["close_reason": "superseded"])
        } else if case .result(_, _, _, let selectedIndex) = state, kind == "fresh" {
            recordResultClose("superseded", selectedIndex: selectedIndex)
        }
        attempt = RewriteAttemptMetadata(kind: kind, previous: parent?.attempt, parentGenerationId: parent?.eventId,
            onboardingAttemptId: KeyboardSettingsStore.sharedDefaults?.string(forKey: KeyboardDiagnosticStore.onboardingAttemptKey),
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        recordDiagnostic("ai_rewrite_attempted")
    }

    private func failAttempt(_ reason: String) {
        recordDiagnostic("ai_rewrite_attempt_blocked", extra: ["readiness_blocker": reason])
    }

    private func recordDiagnostic(_ name: String, extra: [String: String] = [:],
                                  originating: RewriteAttemptMetadata? = nil) {
        guard let metadata = originating ?? attempt else { return }
        var values = metadata.properties.merging(extra) { _, new in new }
        values["context"] = isPracticeModeActive ? "practice" : "live"
        values["app_version"] = Self.appVersion
        values["app_build"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        if let id = KeyboardSettingsStore.sharedDefaults?.string(forKey: KeyboardDiagnosticStore.onboardingAttemptKey) {
            values["onboarding_attempt_id"] = id
        }
        KeyboardDiagnosticStore.record(name, properties: values)
    }

    private func recordReplacement(_ outcome: String, selectedIndex: Int) {
        if let segment = generationSegments.last(where: { $0.start <= selectedIndex }) {
            recordDiagnostic("ai_rewrite_replacement", extra: ["outcome": outcome, "event_id": segment.eventId,
                "selected_index": String(selectedIndex - segment.start)], originating: segment.attempt)
        } else if isPracticeModeActive {
            recordDiagnostic("ai_rewrite_replacement", extra: ["outcome": outcome])
        }
    }

    private func recordResultClose(_ reason: String, selectedIndex: Int) {
        if let segment = generationSegments.last(where: { $0.start <= selectedIndex }) {
            recordDiagnostic("ai_rewrite_result_closed", extra: ["close_reason": reason, "event_id": segment.eventId], originating: segment.attempt)
        } else if isPracticeModeActive {
            recordDiagnostic("ai_rewrite_result_closed", extra: ["close_reason": reason])
        }
    }

    func submitUsefulness(_ reason: String) {
        guard case .result(_, _, _, let selectedIndex) = state,
              let segment = generationSegments.last(where: { $0.start <= selectedIndex }) else { return }
        recordDiagnostic("ai_rewrite_usefulness", extra: ["reason": reason, "event_id": segment.eventId,
            "selected_index": String(selectedIndex - segment.start)], originating: segment.attempt)
    }

    private static func failureCategory(_ error: Error) -> String {
        switch error {
        case CloudRewriteError.notSignedIn, CloudRewriteError.sessionRejected: return "session_rejected"
        case CloudRewriteError.credentialsChanged: return "credentials_changed"
        case CloudRewriteError.temporarilyUnavailable: return "service_unavailable"
        case CloudRewriteError.invalidResponse: return "invalid_response"
        case is URLError: return "network_error"
        default: return "generation_error"
        }
    }

    /// Practice-mode generation: shows the real generating → result flow with
    /// the container-provided candidates after a short beat, entirely offline.
    /// `generationSegments` stays empty, so selection/action feedback no-ops.
    private func firePractice(prompt: UserPrompt, capture: WholeInputCapture, inputText: String) {
        recordDiagnostic("ai_rewrite_generation_started")
        let stored = KeyboardSettingsStore.readOnboardingPracticeCandidates()
        let replacements = stored.isEmpty
            ? [
                "ご確認のほど、よろしくお願いいたします。",
                "お手数ですが、ご確認いただけますと幸いです。",
                inputText,
            ]
            : stored
        let candidates = replacements.map { RewriteCandidate(replacement: $0, changed: $0 != inputText) }

        state = .generating(prompt: prompt, capture: capture, refinement: nil, existing: [], pending: Self.candidateCount)
        rewriteTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.recordDiagnostic("ai_rewrite_result_shown")
                self?.state = .result(prompt: prompt, capture: capture, candidates: candidates, selectedIndex: 0)
                self?.resultShownAt = Date()
                self?.rewriteTask = nil
            }
        }
    }

    private static let appVersion: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    private static func locale(for prompt: UserPrompt) -> String {
        switch prompt.builtinKey {
        case UserPromptDefaults.translateToEnglishKey: return "en-US"
        default: return "ja-JP"
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case CloudRewriteError.notSignedIn, CloudRewriteError.sessionRejected:
            return "アプリでサインインしてください"
        case CloudRewriteError.backend(let message):
            return message
        default:
            return "通信に失敗しました。電波の良い場所で、もう一度お試しください。"
        }
    }
}
