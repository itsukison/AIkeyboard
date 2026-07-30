import JapaneseKeyboardCore
import KeyboardPreferences
import SwiftUI
import UIKit

/// Drives the English keyboard mode (Model B): letters insert directly through
/// KeyboardKit's standard action handler, and this controller observes the
/// document to surface completions / next-word predictions in the suggestion
/// bar, accept a tapped suggestion, and autocorrect a word when space is typed.
///
/// It never touches the Japanese composition path — it's only constructed and
/// called when `KeyboardLanguage` is `.english`.
@MainActor
final class EnglishInputController: ObservableObject {
    /// Words shown in the suggestion bar, most-likely first.
    @Published private(set) var suggestions: [String] = []

    private weak var controller: KeyboardViewController?
    /// The last completed word, carried forward as next-word context.
    private var lastWord: String?
    /// Guards `documentDidChange` from reacting to our own proxy edits.
    private var isApplyingEdit = false

    init(controller: KeyboardViewController) {
        self.controller = controller
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }

    /// Recompute the suggestion bar after the document changed.
    func documentDidChange() {
        guard !isApplyingEdit, let proxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let trailing = Self.trailingWord(before)
        if trailing.isEmpty {
            // At a word boundary: predict the next word from the previous one.
            suggestions = Self.lastCompletedWord(before)
                .map { EnglishSuggestionEngine.nextWords(after: $0, limit: 4) } ?? []
        } else {
            // Mid-word: frequency-ranked completions, personalised, cased to match.
            let completions = EnglishSuggestionEngine.completions(forPartialWord: trailing, limit: 6)
            let ranked = ConversionPreferenceStore.rerank(scope: .english, input: trailing, candidates: completions)
            suggestions = ranked.map { Self.applyCasing(of: trailing, to: $0) }
        }
    }

    /// Replace the partial word with a tapped suggestion (then a space).
    func acceptSuggestion(_ word: String) {
        guard let proxy else { return }
        let trailing = Self.trailingWord(proxy.documentContextBeforeInput ?? "")
        isApplyingEdit = true
        for _ in 0..<trailing.count { proxy.deleteBackward() }
        proxy.insertText(word + " ")
        isApplyingEdit = false

        if !trailing.isEmpty {
            ConversionPreferenceStore.recordSelection(scope: .english, input: trailing, candidate: word)
        }
        learnTransition(to: word)
        suggestions = []
    }

    /// Called when the user types space: autocorrect the just-finished word (if a
    /// markedly more frequent spelling exists) before the space is inserted, and
    /// carry the final word forward as next-word context.
    func finishWordOnSpace() {
        guard let proxy else { return }
        let trailing = Self.trailingWord(proxy.documentContextBeforeInput ?? "")
        guard !trailing.isEmpty else { return }

        var finalWord = trailing
        if let corrected = EnglishSuggestionEngine.correction(for: trailing) {
            let cased = Self.applyCasing(of: trailing, to: corrected)
            if cased != trailing {
                isApplyingEdit = true
                for _ in 0..<trailing.count { proxy.deleteBackward() }
                proxy.insertText(cased)
                isApplyingEdit = false
                finalWord = cased
            }
        }
        learnTransition(to: finalWord)
        suggestions = []
    }

    private func learnTransition(to word: String) {
        if let previous = lastWord {
            NextWordPreferenceStore.recordTransition(previous: previous, next: word)
        }
        lastWord = word
    }

    // MARK: - Word parsing / casing

    /// The run of ASCII letters at the very end of `s` (the word being typed),
    /// or "" when the text ends on a non-letter (a word boundary).
    static func trailingWord(_ s: String) -> String {
        var out: [Character] = []
        for ch in s.reversed() {
            guard ch.isLetter, ch.isASCII else { break }
            out.append(ch)
        }
        return String(out.reversed())
    }

    /// The last complete ASCII-letter word in `s`, skipping any trailing
    /// non-letters (e.g. the space just typed). Used for next-word prediction.
    static func lastCompletedWord(_ s: String) -> String? {
        var out: [Character] = []
        var seenLetter = false
        for ch in s.reversed() {
            if ch.isLetter, ch.isASCII {
                out.append(ch)
                seenLetter = true
            } else if seenLetter {
                break
            }
        }
        return out.isEmpty ? nil : String(out.reversed())
    }

    /// Apply the typed prefix's casing to a lowercase suggestion: ALL-CAPS if the
    /// user typed 2+ uppercase letters, Title-case if it starts uppercase.
    static func applyCasing(of typed: String, to word: String) -> String {
        guard let first = typed.first else { return word }
        if typed.count > 1, typed.allSatisfy({ $0.isUppercase }) {
            return word.uppercased()
        }
        if first.isUppercase {
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return word
    }
}
