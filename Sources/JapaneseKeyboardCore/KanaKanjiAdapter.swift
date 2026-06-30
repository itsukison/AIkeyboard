import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

public actor KanaKanjiAdapter {
    private let converter: KanaKanjiConverter
    private var options: ConvertRequestOptions
    /// The most recent conversion result, retained so post-commit prediction
    /// can recover the rich AzooKey candidate (with its dictionary data /
    /// right-context id) for the word the user just committed. Our own
    /// `Candidate` only carries text + reading, which isn't enough context for
    /// `requestPostCompositionPredictionCandidates`.
    private var lastConversion: ConversionResult?

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
            // AzooKey's own iOS keyboard defaults this on for live typing. It
            // corrects mistyped romaji in the lattice; the kana echo is
            // unaffected and conversion already runs off-main and cancellable.
            needTypoCorrection: true,
            // Blends in-composition prediction candidates (e.g. き → 今日) into
            // the conversion results, and is also required for the post-commit
            // next-word prediction path below.
            requireJapanesePrediction: true,
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
        lastConversion = results

        let texts = Array(results.mainResults.prefix(maxCandidates).map(\.text))
        var candidates = texts.map { Candidate(text: $0, reading: kana) }
        if !candidates.contains(where: { $0.text == kana }) {
            candidates.append(Candidate(text: kana, reading: kana))
        }
        return candidates
    }

    /// Next-word (予測変換) suggestions to show after the user commits a word,
    /// while nothing is being composed. `committedText` must match a candidate
    /// from the most recent `convert(...)`; otherwise (e.g. a raw-kana commit)
    /// we have no rich left-side context and return nothing rather than guess.
    public func predictNextWords(after committedText: String, maxCandidates: Int = 4) -> [Candidate] {
        guard let leftSideCandidate = lastConversion?.mainResults.first(where: { $0.text == committedText }) else {
            return []
        }
        // Corpus prior keyed on the committed chunk's trailing morpheme(s)
        // (Japanese is head-final). Trigram (last two morphemes) goes first for
        // sharper context, backing off to the bigram table; both rank ahead of
        // azooKey's zero-hint guesses, which surface rare junk (ラー油).
        let morphemes = leftSideCandidate.data
        let bigramTexts = morphemes.last
            .map { NextWordPrior.shared?.suggestions(after: $0.word) ?? [] } ?? []
        let lastTwo = Array(morphemes.suffix(2))
        let trigramTexts = lastTwo.count == 2
            ? (NextWordPrior.sharedTrigram?.suggestions(after: lastTwo[0].word, lastTwo[1].word) ?? [])
            : []
        let priorTexts = trigramTexts + bigramTexts
        let predictions = converter.requestPostCompositionPredictionCandidates(
            leftSideCandidate: leftSideCandidate,
            options: options
        )
        var seen = Set<String>()
        var result: [Candidate] = []
        for text in priorTexts + predictions.map(\.text) {
            guard !text.isEmpty, seen.insert(text).inserted else { continue }
            result.append(Candidate(text: text, reading: ""))
            if result.count == maxCandidates { break }
        }
        return result
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
