import Foundation
import KeyboardPreferences

@MainActor
public final class InputManager: ObservableObject {
    /// Live kana representation of the romaji buffer. Not @Published because it
    /// is only consumed by `markedText` / tests; UI reacts to `isComposing` and
    /// `candidates` instead. Avoiding @Published here prevents every keystroke
    /// from invalidating any view that observes the manager.
    public private(set) var displayKana: String = ""

    @Published public private(set) var candidates: [Candidate] = [] {
        didSet {
            // The full-candidate grid only makes sense while there are
            // candidates; auto-collapse when they clear (commit, backspace to
            // empty, etc.) so it can't linger over an empty keyboard.
            if candidates.isEmpty && isCandidateListExpanded {
                isCandidateListExpanded = false
            }
        }
    }

    /// Whether the full "show all candidates" grid (native ∧ expander) is open.
    /// Owned here so both the candidate bar (expand button) and the grid overlay
    /// observe one source of truth.
    @Published public private(set) var isCandidateListExpanded: Bool = false

    /// Next-word (予測変換) suggestions shown after a commit, while nothing is
    /// being composed. Cleared the moment the user starts the next word.
    @Published public private(set) var predictionSuggestions: [Candidate] = []

    /// Index into `candidates` of the currently-cycled candidate, or nil when
    /// the user has not yet pressed space to enter candidate-cycling mode.
    /// When nil, marked text shows kana; when set, marked text shows the
    /// selected candidate's text. Native Japanese IME convention.
    @Published public private(set) var selectedCandidateIndex: Int? = nil

    /// Stored (not computed) so SwiftUI can observe the empty↔composing
    /// transition cheaply, without rebuilding on every keystroke.
    @Published public private(set) var isComposing: Bool = false

    /// Called whenever the marked-text content should be refreshed in the host.
    /// The controller wires this up to `textDocumentProxy.setMarkedText`.
    public var onMarkedTextDidChange: ((String) -> Void)?

    private let buffer: any InputBuffer
    /// Learned next-word (予測変換) suggestions for a just-committed word. Read
    /// fresh from `NextWordPreferenceStore` on each commit; injected so tests
    /// can supply deterministic data without touching the App Group.
    private let nextWordSuggestions: (String) -> [Candidate]
    private let kanaTapCycleTimeout: TimeInterval
    private var adapter: KanaKanjiAdapter?
    private var conversionTask: Task<Void, Never>?
    private var predictionTask: Task<Void, Never>?
    private var lastNotifiedMarkedText: String = ""
    /// Kana prefix of the most recently scheduled conversion. Keystrokes that
    /// don't change the convertible prefix (e.g. the trailing "k" of the next
    /// syllable) reuse the in-flight or already-published candidates.
    private var lastScheduledKanaPrefix: String?
    private var kanaTapCycleState: KanaTapCycleState?

    public init(
        buffer: any InputBuffer = RomajiInputBuffer(),
        nextWordSuggestions: @escaping (String) -> [Candidate] = { committedText in
            NextWordPreferenceStore.suggestions(after: committedText)
                .map { Candidate(text: $0, reading: "") }
        },
        kanaTapCycleTimeout: TimeInterval = 0.8
    ) {
        self.buffer = buffer
        self.nextWordSuggestions = nextWordSuggestions
        self.kanaTapCycleTimeout = kanaTapCycleTimeout
    }

    public func setAdapter(_ adapter: KanaKanjiAdapter) {
        self.adapter = adapter
        if !buffer.isEmpty {
            refresh()
        }
    }

    /// Live preview shown as marked text in the host. Default: kana being
    /// composed (kanji candidates live in the candidate bar, not inline).
    /// Once the user starts cycling via space (`selectNextCandidate`), shows
    /// the currently-selected candidate's text instead. Reverts to kana on
    /// backspace or fresh keystrokes.
    public var markedText: String {
        if let i = selectedCandidateIndex, candidates.indices.contains(i) {
            return candidates[i].text
        }
        return displayKana
    }

    /// Text the host should receive on commit (return / cursor flush). If the
    /// user cycled to a candidate, that candidate; otherwise the raw kana —
    /// never the top kanji guess. Matches native 確定-key behavior: return
    /// confirms what's currently shown, it does not guess a kanji for you.
    public var commitText: String {
        if let i = selectedCandidateIndex, candidates.indices.contains(i) {
            return candidates[i].text
        }
        return buffer.finalKana
    }

    public var currentConversionInput: String {
        convertiblePrefix(of: displayKana)
    }

    /// 次候補 (next-candidate). First call selects index 0; subsequent calls
    /// advance and wrap. No-op if conversion hasn't produced candidates yet.
    public func selectNextCandidate() {
        guard !candidates.isEmpty else { return }
        kanaTapCycleState = nil
        let next: Int
        if let current = selectedCandidateIndex, candidates.indices.contains(current) {
            next = (current + 1) % candidates.count
        } else {
            next = 0
        }
        selectedCandidateIndex = next
        notifyMarkedTextChange()
    }

    /// Open the full-candidate grid (native ∧ expander). No-op with no candidates.
    public func expandCandidateList() {
        guard !candidates.isEmpty, !isCandidateListExpanded else { return }
        isCandidateListExpanded = true
    }

    /// Close the full-candidate grid (native ∨ / selecting a candidate).
    public func collapseCandidateList() {
        guard isCandidateListExpanded else { return }
        isCandidateListExpanded = false
    }

    public func appendRomaji(_ character: Character) {
        kanaTapCycleState = nil
        clearPredictions()
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
        }
        buffer.append(String(character.lowercased()))
        refresh()
    }

    /// Direct kana entry for the flick/10-key input mode. Each call appends
    /// one kana (or a small-kana modifier) to the buffer; conversion runs
    /// through the same pipeline as romaji.
    public func appendKana(_ kana: String) {
        kanaTapCycleState = nil
        clearPredictions()
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
        }
        buffer.append(kana)
        refresh()
    }

    public func appendKanaFromTapCycle(_ key: FlickKanaTable.FlickKey, now: Date = Date()) {
        guard let cycle = FlickKanaTable.tapCycle(for: key), !cycle.isEmpty else {
            appendKana(key.center)
            return
        }
        clearPredictions()
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
        }

        if let state = kanaTapCycleState,
           state.keyCenter == key.center,
           now.timeIntervalSince(state.lastTapAt) <= kanaTapCycleTimeout,
           buffer.displayKana.last.map({ String($0) }) == cycle[state.index] {
            let nextIndex = (state.index + 1) % cycle.count
            _ = buffer.backspace()
            buffer.append(cycle[nextIndex])
            kanaTapCycleState = KanaTapCycleState(
                keyCenter: key.center,
                index: nextIndex,
                lastTapAt: now
            )
        } else {
            buffer.append(cycle[0])
            kanaTapCycleState = KanaTapCycleState(
                keyCenter: key.center,
                index: 0,
                lastTapAt: now
            )
        }
        refresh()
    }

    /// 小書き key center tap: cycles the last kana through its
    /// small/dakuten/handakuten form (e.g. か→が, は→ば→ぱ, つ→っ, や→ゃ).
    /// No-op if the buffer is empty or the last kana has no alternate form.
    /// Only meaningful in kana (flick) input mode.
    public func toggleLastKanaCharacterType() {
        kanaTapCycleState = nil
        clearPredictions()
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
        }
        let current = buffer.displayKana
        guard let last = current.last else { return }
        guard let toggled = FlickKanaTable.toggledForm(of: String(last)) else { return }
        buffer.backspace()
        buffer.append(toggled)
        refresh()
    }

    /// Backspace has two modes: if the user has cycled to a candidate, the
    /// first backspace just cancels selection (reverts marked text to kana);
    /// otherwise it shrinks the romaji buffer by one visible kana unit.
    @discardableResult
    public func backspace() -> Bool {
        kanaTapCycleState = nil
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
            notifyMarkedTextChange()
            return true
        }
        guard buffer.backspace() else { return false }
        refresh()
        return true
    }

    /// Fetch next-word suggestions for the just-committed word. Call after the
    /// commit's `reset()` so the suggestions survive into the idle state.
    public func requestPrediction(after committedText: String) {
        predictionTask?.cancel()
        // The user's own next-word history takes priority over azooKey's static
        // guess; show it immediately, then fill remaining slots with azooKey's
        // predictions once they return.
        let learned = nextWordSuggestions(committedText)
        guard let adapter else {
            let merged = Self.mergePredictions(learned: learned, azoo: [])
            if predictionSuggestions != merged {
                predictionSuggestions = merged
            }
            return
        }
        if !learned.isEmpty, predictionSuggestions != learned {
            predictionSuggestions = learned
        }
        predictionTask = Task { [weak self] in
            let azoo = await adapter.predictNextWords(after: committedText)
            guard !Task.isCancelled, let self else { return }
            let merged = Self.mergePredictions(learned: learned, azoo: azoo)
            if self.predictionSuggestions != merged {
                self.predictionSuggestions = merged
            }
        }
    }

    /// Learned suggestions first (deduped), then azooKey's to fill the bar.
    private static func mergePredictions(
        learned: [Candidate],
        azoo: [Candidate],
        limit: Int = 4
    ) -> [Candidate] {
        var seen = Set<String>()
        var result: [Candidate] = []
        for candidate in learned + azoo {
            guard seen.insert(candidate.text).inserted else { continue }
            result.append(candidate)
            if result.count == limit { break }
        }
        return result
    }

    /// Record the committed word into azooKey's adaptive learning so future
    /// conversions of the same reading rank it higher. Fire-and-forget and off
    /// the typing path; no-op for raw-kana commits with no rich candidate.
    public func recordCommitForLearning(_ committedText: String) {
        guard let adapter else { return }
        Task { await adapter.recordCommit(committedText) }
    }

    /// Persist learned conversions to disk. Call on keyboard dismiss, never
    /// while composing — the on-disk merge is heavy.
    public func persistLearning() {
        guard let adapter else { return }
        Task { await adapter.persistLearning() }
    }

    public func clearPredictions() {
        predictionTask?.cancel()
        predictionTask = nil
        if !predictionSuggestions.isEmpty {
            predictionSuggestions = []
        }
    }

    public func reset() {
        clearPredictions()
        conversionTask?.cancel()
        conversionTask = nil
        lastScheduledKanaPrefix = nil
        kanaTapCycleState = nil
        if let adapter {
            Task { await adapter.stopComposition() }
        }
        buffer.reset()
        displayKana = ""
        if !candidates.isEmpty {
            candidates = []
        }
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
        }
        if isComposing {
            isComposing = false
        }
        notifyMarkedTextChange()
    }

    /// Exposed for tests: await any in-flight conversion before asserting candidates.
    public func currentConversionTask() -> Task<Void, Never>? {
        conversionTask
    }

    private func refresh() {
        let kana = buffer.displayKana
        displayKana = kana

        let composing = !buffer.isEmpty
        if isComposing != composing {
            isComposing = composing
        }

        let kanaPrefix = convertiblePrefix(of: kana)
        if kanaPrefix.isEmpty {
            if !candidates.isEmpty {
                candidates = []
            }
            conversionTask?.cancel()
            conversionTask = nil
            lastScheduledKanaPrefix = nil
            notifyMarkedTextChange()
            return
        }

        notifyMarkedTextChange()
        if kanaPrefix == lastScheduledKanaPrefix { return }
        scheduleConversion(kanaPrefix: kanaPrefix)
    }

    // No debounce: the kana preview is already on screen before this runs, the
    // converter extends its lattice incrementally per keystroke, and the actor
    // serializes requests — so converting eagerly costs a few ms off the main
    // thread while a delay here is added candidate latency one-for-one.
    private func scheduleConversion(kanaPrefix: String) {
        conversionTask?.cancel()
        guard let adapter else { return }
        lastScheduledKanaPrefix = kanaPrefix
        conversionTask = Task { [weak self] in
            // Request a deeper candidate list (was 10) so the intended word is
            // far more likely to be present and reachable in the candidate bar.
            let results = await adapter.convert(kana: kanaPrefix, maxCandidates: 20)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            // Compare prefixes, not the full buffer: trailing unresolved
            // romaji typed while we converted doesn't invalidate the result.
            guard self.convertiblePrefix(of: self.buffer.displayKana) == kanaPrefix else { return }
            // azooKey's own adaptive learning already personalizes the lattice
            // order, so show the converter's ranking directly.
            if self.candidates != results {
                self.candidates = results
            }
            self.notifyMarkedTextChange()
        }
    }

    private func notifyMarkedTextChange() {
        let text = markedText
        if text == lastNotifiedMarkedText { return }
        lastNotifiedMarkedText = text
        onMarkedTextDidChange?(text)
    }

    /// The convertible portion of the display string: everything except the
    /// trailing run of unresolved romaji (a partial syllable still being
    /// typed). Unresolved letters *inside* the string — typos like the b in
    /// たbもの — stay in, so conversion keeps covering the full input and the
    /// candidate bar makes the typo visible, matching the native keyboard.
    private func convertiblePrefix(of s: String) -> String {
        var prefix = s
        while let last = prefix.last, last.isASCII, last.isLetter {
            prefix.removeLast()
        }
        return prefix
    }

    private struct KanaTapCycleState {
        let keyCenter: String
        let index: Int
        let lastTapAt: Date
    }
}
