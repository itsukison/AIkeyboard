import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

public actor KanaKanjiAdapter {
    private let converter: KanaKanjiConverter
    private var options: ConvertRequestOptions

    public init(supportDirectoryURL: URL? = nil) {
        let supportURL = supportDirectoryURL
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("KeigoButton", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        self.converter = KanaKanjiConverter.withDefaultDictionary()
        // Built once: constructing options per convert call would re-read the
        // emoji TSV from disk on every keystroke (TextReplacer's init parses
        // the whole file). `.empty` because the replacer only feeds
        // post-composition prediction, which we never request.
        self.options = .init(
            N_best: 10,
            needTypoCorrection: false,
            requireJapanesePrediction: false,
            requireEnglishPrediction: false,
            keyboardLanguage: .ja_JP,
            englishCandidateInRoman2KanaInput: false,
            fullWidthRomanCandidate: false,
            halfWidthKanaCandidate: false,
            learningType: .nothing,
            maxMemoryCount: 0,
            shouldResetMemory: false,
            memoryDirectoryURL: supportURL,
            sharedContainerURL: supportURL,
            textReplacer: .empty,
            specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
            zenzaiMode: .off,
            metadata: .init(versionString: "KeigoButton/1.0")
        )
    }

    public func convert(kana: String, maxCandidates: Int = 10) -> [Candidate] {
        guard !kana.isEmpty else { return [] }
        // A keystroke may have cancelled this request while it was queued
        // behind another conversion; skip the wasted lattice work.
        guard !Task.isCancelled else { return [] }

        var composingText = ComposingText()
        composingText.insertAtCursorPosition(kana, inputStyle: .direct)

        options.N_best = maxCandidates
        let results = converter.requestCandidates(composingText, options: options)

        let texts = Array(results.mainResults.prefix(maxCandidates).map(\.text))
        var candidates = texts.map { Candidate(text: $0, reading: kana) }
        if !candidates.contains(where: { $0.text == kana }) {
            candidates.append(Candidate(text: kana, reading: kana))
        }
        return candidates
    }

    /// Clears the converter's incremental lattice state when a composition
    /// ends, so the next composition diffs against a clean slate.
    public func stopComposition() {
        converter.stopComposition()
    }

    /// Runs one throwaway conversion so the first real keystroke doesn't pay
    /// the lazy dictionary-load cost (charID, mm.binary, LOUDS shard I/O).
    public func prewarm() {
        _ = convert(kana: "あ")
        converter.stopComposition()
    }
}
