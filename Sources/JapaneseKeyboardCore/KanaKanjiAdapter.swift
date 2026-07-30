import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary
import KeyboardPreferences

public actor KanaKanjiAdapter {
    private let converter: KanaKanjiConverter
    private var options: ConvertRequestOptions
    /// The most recent conversion result, retained so post-commit prediction
    /// can recover the rich AzooKey candidate (with its dictionary data /
    /// right-context id) for the word the user just committed. Our own
    /// `Candidate` only carries text + reading, which isn't enough context for
    /// `requestPostCompositionPredictionCandidates`.
    private var lastConversion: ConversionResult?
    /// The kana `lastConversion` was requested for, so the full-list read
    /// below can label its candidates and let the caller detect staleness.
    private var lastConversionKana: String?
    /// Whether Zenzai is currently active (weight bundled, user-enabled,
    /// enough jetsam headroom at init, and the latency gate hasn't tripped).
    private var zenzaiEnabled: Bool
    private let zenzaiWeightURL: URL?
    /// Trips when the rolling median conversion latency shows this device is
    /// too slow for neural conversion — the speed counterpart of the memory
    /// headroom gate. Once tripped, the decision persists via
    /// `KeyboardSettingsStore.recordZenzaiAutoDisabled` until the next build.
    private var latencyGate = ZenzaiLatencyGate()
    /// Left context currently baked into `options.zenzaiMode`, so a repeated
    /// convert call with the same context skips the mode rebuild.
    private var currentLeftContext: String?
    /// The azooKey candidate the last `predictNextWords` predictions extend,
    /// plus those predictions, retained so a tapped prediction can be fed back
    /// into learning (`updateLearningData(_:with:)`) and joined into a new
    /// base for chained prediction — the mechanism the upstream azooKey app
    /// relies on for its post-commit prediction quality.
    private var lastPredictionBase: KanaKanjiConverterModule.Candidate?
    private var lastPredictions: [PostCompositionPredictionCandidate] = []
    /// After a prediction tap: the tapped text and the joined candidate that
    /// becomes the left-side context for the next prediction round. Cleared on
    /// the next conversion (typing supersedes the chain).
    private var chainedBase: (text: String, candidate: KanaKanjiConverterModule.Candidate)?
    /// Whether the zenz weight has been loaded (by `prewarmZenzai()` or a real
    /// conversion), so the deferred warm-up never runs twice.
    private var zenzaiPrewarmed = false

    public init(supportDirectoryURL: URL? = nil, zenzaiUserEnabled: Bool = true) {
        let supportURL = supportDirectoryURL
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("KeigoButton", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        self.converter = KanaKanjiConverter.withDefaultDictionary()
        // Zenzai (neural conversion) — xsmall CPU model bundled as a resource.
        // Falls back to .off if the weight isn't bundled so a missing model can
        // never crash the build/runtime, and when jetsam headroom is short:
        // Zenzai costs ~25 MB of transient dirty memory (KV + compute + first
        // decode) on top of the classical converter, and the extension's cap
        // shrinks under host-app memory pressure — classical-only conversion
        // beats a jetsam kill at launch. inferenceLimit 2 matches azooKey's own
        // xsmall tier: it's the LM's review-and-correct budget (limit 1 lets the
        // model reject the classical draft but never re-decode a fix), and each
        // extra iteration costs latency (reused KV/compute buffers, no added
        // memory) — the latency gate below covers slow devices.
        // `zenzaiUserEnabled` is the user's opt-out toggle (App Group setting,
        // read by the caller — Core stays decoupled from KeyboardPreferences).
        let weightURL = Bundle.module.url(forResource: "zenz-xsmall", withExtension: "gguf")
        self.zenzaiWeightURL = weightURL
        let zenzai: ConvertRequestOptions.ZenzaiMode
        if let weightURL, zenzaiUserEnabled, Self.hasZenzaiHeadroom {
            zenzai = .on(
                weight: weightURL,
                inferenceLimit: 2,
                personalizationMode: nil,
                versionDependentMode: .v3(.init())
            )
            self.zenzaiEnabled = true
        } else {
            zenzai = .off
            self.zenzaiEnabled = false
        }
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
            // Use azooKey's own adaptive lattice learning: committed choices
            // re-rank future conversions of the same/related readings, and —
            // unlike our exact-match reranker — can pull a learned word up into
            // the candidate list. Requires a persistent `memoryDirectoryURL`
            // (App Group, passed by the caller); the temp-dir fallback would
            // make learning evaporate. Bounded count keeps resident memory and
            // the on-dismiss merge cost in check under the extension jetsam ceiling.
            learningType: .inputAndOutput,
            maxMemoryCount: 5000,
            shouldResetMemory: false,
            memoryDirectoryURL: supportURL,
            sharedContainerURL: supportURL,
            textReplacer: .empty,
            specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
            zenzaiMode: zenzai,
            metadata: .init(versionString: "KeigoButton/1.0")
        )
        // Before the first conversion: the user-dictionary LOUDS is loaded
        // lazily and then cached for the life of the converter.
        Self.installGapFillDictionary(into: supportURL)
    }

    /// Builds the bundled gap-fill entries (readings the default dictionary
    /// can't compose, e.g. なんごうしゃ → 何号車) into the converter's user
    /// dictionary (user.louds in `sharedContainerURL`). Real LOUDS files —
    /// unlike `importDynamicUserDictionary`, whose entries only match at the
    /// very end of the input — so the words also compose mid-sentence
    /// (何号車に乗る). Rebuilt on every init: the build is microseconds for a
    /// list this size, and it keeps an updated TSV effective immediately.
    private static func installGapFillDictionary(into directoryURL: URL) {
        guard let tsvURL = Bundle.module.url(forResource: "conversion_gapfill", withExtension: "tsv"),
              let tsv = try? String(contentsOf: tsvURL, encoding: .utf8),
              let charIDURL = defaultDictionaryCharIDURL else {
            #if DEBUG
            NSLog("%@", "📗 GAPFILL skipped — tsv or charID.chid not found")
            #endif
            return
        }
        let entries: [DicdataElement] = tsv.split(separator: "\n").compactMap { line in
            let columns = line.split(separator: "\t")
            guard columns.count >= 2 else { return nil }
            return DicdataElement(
                word: String(columns[1]),
                ruby: String(columns[0]),
                cid: CIDData.一般名詞.cid,
                mid: MIDData.一般.mid,
                value: -9
            )
        }
        guard !entries.isEmpty else { return }
        do {
            try DictionaryBuilder.exportDictionary(
                entries: entries,
                to: directoryURL,
                baseName: "user",
                shardByFirstCharacter: false,
                charIDFileURL: charIDURL
            )
            #if DEBUG
            NSLog("%@", "📗 GAPFILL installed \(entries.count) entries into \(directoryURL.lastPathComponent)/user.louds")
            #endif
        } catch {
            #if DEBUG
            NSLog("%@", "📗 GAPFILL export failed: \(error)")
            #endif
        }
    }

    /// charID.chid of the bundled azooKey dictionary, so the exported LOUDS
    /// uses the same character IDs the converter searches with. Resolved by
    /// locating the converter package's resource bundle next to wherever the
    /// converter class itself is loaded from (appex bundle when statically
    /// linked, framework bundle otherwise).
    private static var defaultDictionaryCharIDURL: URL? {
        let converterBundle = Bundle(for: KanaKanjiConverter.self)
        let resourceBundleName = "AzooKeyKanaKanjiConverter_KanaKanjiConverterModuleWithDefaultDictionary.bundle"
        let roots = [converterBundle.resourceURL, converterBundle.bundleURL]
        for root in roots.compactMap({ $0 }) {
            let url = root
                .appendingPathComponent(resourceBundleName, isDirectory: true)
                .appendingPathComponent("Dictionary/louds/charID.chid", isDirectory: false)
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    public func convert(kana: String, maxCandidates: Int = 10, leftContext: String? = nil) -> [Candidate] {
        guard !kana.isEmpty else { return [] }
        // A keystroke may have cancelled this request while it was queued
        // behind another conversion; skip the wasted lattice work.
        guard !Task.isCancelled else { return [] }
        applyLeftContext(leftContext)
        chainedBase = nil

        var composingText = ComposingText()
        composingText.insertAtCursorPosition(kana, inputStyle: .direct)

        options.N_best = maxCandidates
        let conversionStart: ContinuousClock.Instant? = zenzaiEnabled ? .now : nil
        let results = InputLatencyProbe.measure("convert") {
            converter.requestCandidates(composingText, options: options)
        }
        if let conversionStart {
            zenzaiPrewarmed = true
            recordZenzaiLatency(since: conversionStart)
        }
        lastConversion = results
        lastConversionKana = kana

        let texts = Array(results.mainResults.prefix(maxCandidates).map(\.text))
        var candidates = texts.map { Candidate(text: $0, reading: kana) }
        if !candidates.contains(where: { $0.text == kana }) {
            candidates.append(Candidate(text: kana, reading: kana))
        }
        return candidates
    }

    /// Every candidate of the most recent conversion — the full `mainResults`
    /// the bar's `maxCandidates` slice was cut from (whole-sentence and
    /// first-clause conversions plus the unbounded single-word/variant tail).
    /// Runs no new conversion: the result was already computed per keystroke
    /// and retained for prediction. Returns the kana it was converted from so
    /// the caller can discard a stale expansion.
    public func allCandidatesFromLastConversion() -> (kana: String, candidates: [Candidate])? {
        guard let lastConversion, let kana = lastConversionKana else { return nil }
        var seen = Set<String>()
        var candidates: [Candidate] = []
        for text in lastConversion.mainResults.map(\.text) where seen.insert(text).inserted {
            candidates.append(Candidate(text: text, reading: kana))
        }
        if !seen.contains(kana) {
            candidates.append(Candidate(text: kana, reading: kana))
        }
        return (kana, candidates)
    }

    /// Bake the text left of the composition into Zenzai's conversion prompt
    /// (zenz-v3's 文脈考慮変換), matching what the upstream azooKey app passes.
    /// The context is captured once per composition by the caller, so within a
    /// composition this is a no-op after the first keystroke.
    private func applyLeftContext(_ raw: String?) {
        guard zenzaiEnabled, let weightURL = zenzaiWeightURL else { return }
        let context = raw.flatMap { $0.isEmpty ? nil : String($0.suffix(40)) }
        guard context != currentLeftContext else { return }
        currentLeftContext = context
        options.zenzaiMode = .on(
            weight: weightURL,
            inferenceLimit: 2,
            personalizationMode: nil,
            versionDependentMode: .v3(.init(
                leftSideContext: context,
                maxLeftSideContextLength: 20
            ))
        )
    }

    /// Next-word (予測変換) suggestions to show after the user commits a word,
    /// while nothing is being composed. Prefers the rich azooKey candidate for
    /// `committedText` (from the most recent `convert(...)` or the chained base
    /// built by `recordPredictionCommit`); without one (raw-kana commit, tapped
    /// corpus-prior suggestion) it falls back to the bigram prior keyed on the
    /// committed surface itself — usually a single morpheme (です, と, はい) —
    /// so the bar stays populated and prediction chains don't die.
    public func predictNextWords(after committedText: String, maxCandidates: Int = 10) -> [Candidate] {
        let leftSideCandidate: KanaKanjiConverterModule.Candidate?
        if let match = lastConversion?.mainResults.first(where: { $0.text == committedText }) {
            leftSideCandidate = match
        } else if let chained = chainedBase, chained.text == committedText {
            leftSideCandidate = chained.candidate
        } else {
            leftSideCandidate = nil
        }
        let orderedTexts: [String]
        let predictions: [PostCompositionPredictionCandidate]
        if let leftSideCandidate {
            // Corpus prior keyed on the committed chunk's trailing morpheme(s)
            // (Japanese is head-final). Trigram (last two morphemes) first —
            // sharpest context. azooKey's predictions next: with learning on
            // they carry the user's own patterns and keep the join-chain alive,
            // so they outrank the generic bigram tail.
            let morphemes = leftSideCandidate.data
            let bigramTexts = morphemes.last
                .map { NextWordPrior.shared?.suggestions(after: $0.word) ?? [] } ?? []
            let lastTwo = Array(morphemes.suffix(2))
            let trigramTexts = lastTwo.count == 2
                ? (NextWordPrior.sharedTrigram?.suggestions(after: lastTwo[0].word, lastTwo[1].word) ?? [])
                : []
            predictions = converter.requestPostCompositionPredictionCandidates(
                leftSideCandidate: leftSideCandidate,
                options: options
            )
            orderedTexts = trigramTexts + predictions.map(\.text) + bigramTexts
        } else {
            predictions = []
            orderedTexts = NextWordPrior.shared?.suggestions(after: committedText) ?? []
        }
        // Also cleared (not just set) so a tap after a fallback round can't
        // learn/join against a stale base from an earlier conversion.
        lastPredictionBase = leftSideCandidate
        lastPredictions = predictions
        var seen = Set<String>()
        var texts: [String] = []
        for text in orderedTexts {
            guard !text.isEmpty, seen.insert(text).inserted else { continue }
            texts.append(text)
            if texts.count == maxCandidates { break }
        }
        texts = rescorePredictionHead(texts, committed: leftSideCandidate?.text ?? committedText)
        return texts.map { Candidate(text: $0, reading: "") }
    }

    /// How many prediction candidates the zenz rescoring pass reorders. The
    /// n-gram/dictionary merge above is context-blind beyond two morphemes;
    /// scoring its head against the real left context fixes what it cannot see
    /// (+16pp top-1 on the contrastive probe, scripts/rescore-probe). Five keeps
    /// the single batched decode ~60-80 ms on A15-class devices.
    private static let rescoreHeadCount = 5
    /// Process-local speed valve, same philosophy as `ZenzaiLatencyGate` but
    /// not persisted: two consecutive unthrottled rescores over 150 ms stop
    /// rescoring until the next launch. Not fed into the conversion gate —
    /// slow rescoring should cost the reorder, not neural conversion.
    private var rescoreSlowStrikes = 0
    private var rescoreTripped = false

    /// Reorders the head of the merged prediction list by zenz log-probability
    /// under `leftContext + committed`. The prompt reuses conversion's
    /// `\u{EE02}<context>` prefix so the llama KV cache is shared in both
    /// directions. Returns the input unchanged whenever the model isn't warm,
    /// Zenzai is off/tripped, or scoring fails.
    private func rescorePredictionHead(_ texts: [String], committed: String) -> [String] {
        guard zenzaiEnabled, zenzaiPrewarmed, !rescoreTripped, texts.count > 1 else { return texts }
        let context = String(((currentLeftContext ?? "") + committed).suffix(20))
        let head = Array(texts.prefix(Self.rescoreHeadCount))
        let start = ContinuousClock.now
        guard let scores = converter.evaluateZenzaiContinuations(head, prompt: "\u{EE02}" + context, options: options) else {
            return texts
        }
        let duration = start.duration(to: .now)
        let milliseconds = Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1e15
        #if DEBUG
        NSLog("%@", String(format: "📈 ZENZ-RESCORE %.1f ms ctx=%@", milliseconds, context))
        #endif
        let info = ProcessInfo.processInfo
        if !info.isLowPowerModeEnabled, info.thermalState == .nominal {
            rescoreSlowStrikes = milliseconds > 150 ? rescoreSlowStrikes + 1 : 0
            if rescoreSlowStrikes >= 2 {
                rescoreTripped = true
                #if DEBUG
                NSLog("%@", "📈 ZENZ-RESCORE tripped — n-gram order for the rest of this process")
                #endif
            }
        }
        let reordered = zip(head, scores).enumerated()
            .map { (index: $0.offset, text: $0.element.0, score: $0.element.1.isNaN ? -Float.infinity : $0.element.1) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index }
            .map(\.text)
        return reordered + texts.dropFirst(head.count)
    }

    /// Learn a tapped next-word prediction and extend the chain: feeds the
    /// selection into azooKey's adaptive learning (the main quality driver of
    /// its zero-hint predictions) and joins it onto the base candidate so the
    /// next `predictNextWords(after: predictionText)` keeps the accumulated
    /// morpheme context instead of going blind. No-op for a tap on a
    /// corpus-prior suggestion that azooKey didn't produce.
    public func recordPredictionCommit(_ predictionText: String) {
        guard let base = lastPredictionBase,
              let prediction = lastPredictions.first(where: { $0.text == predictionText }) else {
            return
        }
        converter.updateLearningData(base, with: prediction)
        chainedBase = (predictionText, prediction.join(to: base))
    }

    /// Record a committed word into azooKey's adaptive learning so the same
    /// reading ranks this choice higher next time. Cheap (in-RAM trie); the
    /// on-disk persistence happens separately in `persistLearning()`. No-op for
    /// a raw-kana commit that doesn't match a rich candidate from the last
    /// conversion — we'd have no morpheme data to learn from.
    public func recordCommit(_ committedText: String) {
        guard let candidate = lastConversion?.mainResults.first(where: { $0.text == committedText }) else {
            return
        }
        converter.updateLearningData(candidate)
    }

    /// Flush in-RAM learning into the on-disk long-term memory. Expensive
    /// (LOUDS rebuild) — call only off the typing path, e.g. keyboard dismiss.
    public func persistLearning() {
        converter.commitUpdateLearningData()
    }

    /// Clears the converter's incremental lattice state when a composition
    /// ends, so the next composition diffs against a clean slate.
    public func stopComposition() {
        converter.stopComposition()
    }

    /// Runs one throwaway classical conversion so the first real keystroke
    /// doesn't pay the lazy dictionary-load cost (charID, mm.binary, LOUDS
    /// shard I/O). Deliberately does NOT touch the zenz weight: this runs at
    /// keyboard launch, and llama's model load + first decode saturating
    /// `min(8, cores-2)` threads there is exactly what delays the first frame.
    /// Zenzai warms separately via `prewarmZenzai()` once the keyboard is on
    /// screen.
    public func prewarm() {
        var classicalOptions = options
        classicalOptions.zenzaiMode = .off
        var composingText = ComposingText()
        composingText.insertAtCursorPosition("あ", inputStyle: .direct)
        _ = converter.requestCandidates(composingText, options: classicalOptions)
        #if DEBUG
        NSLog("%@", "📕 ZENZAI enabled=\(zenzaiEnabled) (weight load deferred to prewarmZenzai)")
        #endif
        converter.stopComposition()
    }

    /// Loads the zenz weight and runs one throwaway neural conversion so the
    /// first real keystroke doesn't pay the model-load + first-decode cost.
    /// Call after the keyboard's first frame is visible. No-op when Zenzai is
    /// off or the model was already warmed — including by a real conversion,
    /// so a fast typer's in-flight work is never stomped by this.
    public func prewarmZenzai() {
        guard zenzaiEnabled, !zenzaiPrewarmed else { return }
        zenzaiPrewarmed = true
        var composingText = ComposingText()
        composingText.insertAtCursorPosition("あ", inputStyle: .direct)
        _ = converter.requestCandidates(composingText, options: options)
        #if DEBUG
        NSLog("%@", "📕 ZENZAI enabled=\(zenzaiEnabled) status=[\(converter.zenzStatus)]")
        #endif
        converter.stopComposition()
    }

    /// Feeds the latency gate with one conversion's duration; when it trips,
    /// the rest of the process runs classical conversion and the decision is
    /// persisted (until the next app build re-probes). Samples taken under
    /// CPU throttling are withheld — a device in Low Power Mode or running
    /// hot is slow on purpose, which says nothing about its real speed.
    private func recordZenzaiLatency(since start: ContinuousClock.Instant) {
        let info = ProcessInfo.processInfo
        guard !info.isLowPowerModeEnabled, info.thermalState == .nominal else { return }
        let duration = start.duration(to: .now)
        var milliseconds = Double(duration.components.seconds) * 1000
            + Double(duration.components.attoseconds) / 1e15
        #if DEBUG
        // On-device verification hook: inflating the *sample* (not sleeping)
        // trips the gate without degrading typing. Set from the container's
        // DEBUG-only row; never compiled into Release.
        if KeyboardSettingsStore.sharedDefaults?.bool(forKey: "debug.zenzaiForceSlowSample") == true {
            milliseconds += 300
        }
        NSLog("%@", String(format: "📉 ZENZAI conversion %.1f ms", milliseconds))
        #endif
        if latencyGate.record(latencyMilliseconds: milliseconds) {
            zenzaiEnabled = false
            options.zenzaiMode = .off
            KeyboardSettingsStore.recordZenzaiAutoDisabled()
            #if DEBUG
            NSLog("%@", "📉 ZENZAI latency gate TRIPPED — classical conversion for the rest of this process")
            #endif
        }
    }

    /// Zenzai needs ~25 MB of dirty-memory headroom on top of the classical
    /// converter's peak; require a comfortable margin so a pressured host
    /// (smaller jetsam cap) silently falls back to classical conversion
    /// instead of being killed. iOS-only API; non-iOS builds (tests) have no
    /// comparable budget.
    private static var hasZenzaiHeadroom: Bool {
        #if os(iOS)
        return os_proc_available_memory() > 50 * 1024 * 1024
        #else
        return true
        #endif
    }
}
