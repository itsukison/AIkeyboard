import Foundation

/// English typing assistance for the opt-in English keyboard mode: word
/// completion, next-word prediction, and autocorrect. Fully offline and
/// frequency-ranked, backed by the mmap'd `NextWordPrior` unigram/bigram tables
/// (see `scripts/build_english_ngram.py`).
///
/// Correction uses the classic Norvig generate-and-verify approach (build the
/// edit-distance neighbourhood of the typed word, keep those that exist in the
/// vocabulary, pick the most frequent) rather than a precomputed SymSpell delete
/// index. Same quality, but it adds no resident memory beyond the mmap'd vocab —
/// which is what keeps us clear of the extension jetsam ceiling.
///
/// All lookups are lowercase; callers reapply the typed word's casing.
public enum EnglishSuggestionEngine {
    private static let letters = Array("abcdefghijklmnopqrstuvwxyz")

    /// A known typed word is only overridden when a neighbour outweighs it by at
    /// least this much (weights are a relative-log 1…255 scale). It separates real
    /// typos that happen to exist in the web-frequency vocabulary (e.g. "teh",
    /// "adn") from valid words with a near-frequency neighbour (e.g. "hello"/"hell").
    private static let correctionMargin = 40

    /// Completions for the partial word the user is typing, most-likely first.
    public static func completions(forPartialWord partial: String, limit: Int = 6) -> [String] {
        completions(forPartialWord: partial, limit: limit, unigram: NextWordPrior.englishUnigram)
    }

    /// Likely next words after `previousWord`, most-likely first.
    public static func nextWords(after previousWord: String, limit: Int = 4) -> [String] {
        nextWords(after: previousWord, limit: limit, bigram: NextWordPrior.englishBigram)
    }

    /// A higher-frequency correctly-spelled word for `typed`, or nil when `typed`
    /// is already a known word (or no confident correction exists). The result is
    /// lowercase; the caller restores casing to match what the user typed.
    public static func correction(for typed: String) -> String? {
        correction(for: typed, vocab: NextWordPrior.englishUnigram)
    }

    // MARK: Injectable cores (tables passed in so they're testable without the bundle)

    static func completions(forPartialWord partial: String, limit: Int, unigram: NextWordPrior?) -> [String] {
        let prefix = partial.lowercased()
        guard prefix.count >= 1, let table = unigram else { return [] }
        return table.completions(prefix: prefix, limit: limit)
    }

    static func nextWords(after previousWord: String, limit: Int, bigram: NextWordPrior?) -> [String] {
        let key = previousWord.lowercased()
        guard !key.isEmpty, let table = bigram else { return [] }
        return Array(table.suggestions(after: key).prefix(limit))
    }

    static func correction(for typed: String, vocab: NextWordPrior?) -> String? {
        let word = typed.lowercased()
        guard word.count >= 2,
              word.allSatisfy({ $0.isLetter && $0.isASCII }),
              let vocab else { return nil }

        let typedWeight = vocab.weight(for: word)

        // Most frequent known word within one edit.
        var best = bestKnown(in: edits1(word), vocab: vocab)
        // Widen to edit distance 2 only when nothing at distance 1 matched and the
        // typed word is itself unknown — where typos with no close neighbour live.
        // Bounded by length to keep the candidate set sane.
        if best == nil, typedWeight == nil, word.count <= 12 {
            var seen = Set<String>()
            var distance2: [String] = []
            for e1 in edits1(word) {
                for e2 in edits1(e1) where seen.insert(e2).inserted {
                    distance2.append(e2)
                }
            }
            best = bestKnown(in: distance2, vocab: vocab)
        }

        guard let best, best.word != word else { return nil }
        // The typed word is a known word: only override it when the neighbour is
        // markedly more frequent, so valid words aren't "corrected" to commoner ones.
        if let typedWeight, best.weight <= typedWeight + correctionMargin { return nil }
        return best.word
    }

    private static func bestKnown(in candidates: [String], vocab: NextWordPrior) -> (word: String, weight: Int)? {
        var best: (word: String, weight: Int)?
        for candidate in candidates {
            guard let weight = vocab.weight(for: candidate) else { continue }
            if best == nil || weight > best!.weight {
                best = (candidate, weight)
            }
        }
        return best
    }

    /// All strings one edit (delete / transpose / replace / insert) from `word`.
    private static func edits1(_ word: String) -> [String] {
        let chars = Array(word)
        var result: [String] = []
        let n = chars.count
        for i in 0...n {
            // delete
            if i < n {
                var s = chars
                s.remove(at: i)
                result.append(String(s))
            }
            // transpose
            if i < n - 1 {
                var s = chars
                s.swapAt(i, i + 1)
                result.append(String(s))
            }
            // replace
            if i < n {
                for c in letters where c != chars[i] {
                    var s = chars
                    s[i] = c
                    result.append(String(s))
                }
            }
            // insert
            for c in letters {
                var s = chars
                s.insert(c, at: i)
                result.append(String(s))
            }
        }
        return result
    }
}
