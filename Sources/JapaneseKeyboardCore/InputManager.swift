import Foundation
import KeyboardPreferences

@MainActor
public final class InputManager: ObservableObject {
    /// Live kana representation of the romaji buffer. Not @Published because it
    /// is only consumed by `markedText` / tests; UI reacts to `isComposing` and
    /// `candidates` instead. Avoiding @Published here prevents every keystroke
    /// from invalidating any view that observes the manager.
    public private(set) var displayKana: String = ""

    @Published public private(set) var candidates: [Candidate] = []

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

    private let buffer = RomajiInputBuffer()
    private let conversionPreferenceEntries: () -> [ConversionPreferenceEntry]
    private var cachedConversionPreferenceEntries: [ConversionPreferenceEntry]
    private var adapter: KanaKanjiAdapter?
    private var conversionTask: Task<Void, Never>?
    private var lastNotifiedMarkedText: String = ""

    public init(
        conversionPreferenceEntries: @escaping () -> [ConversionPreferenceEntry] = {
            ConversionPreferenceStore.readEntries()
        }
    ) {
        self.conversionPreferenceEntries = conversionPreferenceEntries
        self.cachedConversionPreferenceEntries = conversionPreferenceEntries()
    }

    public func setAdapter(_ adapter: KanaKanjiAdapter) {
        self.adapter = adapter
        if !buffer.isEmpty {
            refresh()
        }
    }

    public func refreshConversionPreferenceEntries() {
        cachedConversionPreferenceEntries = conversionPreferenceEntries()
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
        leadingKanaPrefix(of: displayKana)
    }

    /// 次候補 (next-candidate). First call selects index 0; subsequent calls
    /// advance and wrap. No-op if conversion hasn't produced candidates yet.
    public func selectNextCandidate() {
        guard !candidates.isEmpty else { return }
        let next: Int
        if let current = selectedCandidateIndex, candidates.indices.contains(current) {
            next = (current + 1) % candidates.count
        } else {
            next = 0
        }
        selectedCandidateIndex = next
        notifyMarkedTextChange()
    }

    public func appendRomaji(_ character: Character) {
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
        }
        buffer.append(Character(character.lowercased()))
        refresh()
    }

    /// Backspace has two modes: if the user has cycled to a candidate, the
    /// first backspace just cancels selection (reverts marked text to kana);
    /// otherwise it shrinks the romaji buffer by one visible kana unit.
    @discardableResult
    public func backspace() -> Bool {
        if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
            notifyMarkedTextChange()
            return true
        }
        guard buffer.backspace() else { return false }
        refresh()
        return true
    }

    public func reset() {
        conversionTask?.cancel()
        conversionTask = nil
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

        let kanaPrefix = leadingKanaPrefix(of: kana)
        if kanaPrefix.isEmpty {
            if !candidates.isEmpty {
                candidates = []
            }
            conversionTask?.cancel()
            conversionTask = nil
            notifyMarkedTextChange()
            return
        }

        notifyMarkedTextChange()
        scheduleConversion(kanaPrefix: kanaPrefix, bufferSnapshot: kana)
    }

    private func scheduleConversion(kanaPrefix: String, bufferSnapshot: String) {
        conversionTask?.cancel()
        guard let adapter else { return }
        conversionTask = Task { [weak self] in
            // Short debounce so rapid keystrokes don't spawn many converter jobs,
            // but small enough to feel responsive on slow typing.
            try? await Task.sleep(nanoseconds: 15_000_000)
            guard !Task.isCancelled else { return }
            let results = await adapter.convert(kana: kanaPrefix, maxCandidates: 10)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard self.buffer.displayKana == bufferSnapshot else { return }
            self.candidates = Self.rerankCandidates(
                results,
                input: kanaPrefix,
                entries: self.cachedConversionPreferenceEntries
            )
            self.notifyMarkedTextChange()
        }
    }

    private func notifyMarkedTextChange() {
        let text = markedText
        if text == lastNotifiedMarkedText { return }
        lastNotifiedMarkedText = text
        onMarkedTextDidChange?(text)
    }

    private func leadingKanaPrefix(of s: String) -> String {
        var prefix = ""
        for c in s {
            if c.isASCII && c.isLetter { break }
            prefix.append(c)
        }
        return prefix
    }

    private static func rerankCandidates(
        _ candidates: [Candidate],
        input: String,
        entries: [ConversionPreferenceEntry]
    ) -> [Candidate] {
        guard candidates.count > 1 else { return candidates }

        var candidateByText: [String: Candidate] = [:]
        var candidateTexts: [String] = []
        for candidate in candidates {
            guard candidateByText[candidate.text] == nil else { continue }
            candidateByText[candidate.text] = candidate
            candidateTexts.append(candidate.text)
        }

        return ConversionPreferenceStore.rerank(
            scope: .japanese,
            input: input,
            candidates: candidateTexts,
            entries: entries
        ).compactMap { candidateByText[$0] }
    }
}
