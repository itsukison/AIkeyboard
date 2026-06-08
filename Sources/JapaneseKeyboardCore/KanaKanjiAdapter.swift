import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

public actor KanaKanjiAdapter {
    private let converter: KanaKanjiConverter
    private let supportURL: URL

    public init(supportDirectoryURL: URL? = nil) {
        self.supportURL = supportDirectoryURL
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("KeigoButton", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        self.converter = KanaKanjiConverter.withDefaultDictionary()
    }

    public func convert(kana: String, maxCandidates: Int = 10) -> [Candidate] {
        guard !kana.isEmpty else { return [] }

        var composingText = ComposingText()
        composingText.insertAtCursorPosition(kana, inputStyle: .direct)

        let results = converter.requestCandidates(composingText, options: .init(
            N_best: maxCandidates,
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
            textReplacer: .withDefaultEmojiDictionary(),
            specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
            zenzaiMode: .off,
            metadata: .init(versionString: "KeigoButton/1.0")
        ))

        let texts = Array(results.mainResults.prefix(maxCandidates).map(\.text))
        var candidates = texts.map { Candidate(text: $0, reading: kana) }
        if !candidates.contains(where: { $0.text == kana }) {
            candidates.append(Candidate(text: kana, reading: kana))
        }
        return candidates
    }
}
