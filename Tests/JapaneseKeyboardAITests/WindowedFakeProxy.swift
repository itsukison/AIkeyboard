import Foundation
@testable import JapaneseKeyboardAI

/// A proxy backed by a full document that only exposes truncated windows around
/// the cursor — the way `UITextDocumentProxy` behaves in real hosts. Used to
/// exercise `FullDocumentReader` and the full-document replacement path.
@MainActor
final class WindowedFakeProxy: TextDocumentProxying {
    enum AdjustBehavior: Equatable {
        /// Moves exactly by the requested offset (clamped to document bounds).
        case exact
        /// Never moves — a host that does not support `adjustTextPosition`.
        case ignore
        /// Moves fewer characters than requested (magnitude reduced by `drift`),
        /// simulating a host whose offset counting disagrees with Swift
        /// `Character`s. Exercises the reader's overlap-trimming recovery.
        case undershoot(Int)
    }

    /// The whole document, as characters. The cursor sits between indices.
    private(set) var characters: [Character]
    private(set) var cursor: Int
    /// Length of an active selection starting at `cursor` (0 = no selection).
    private var selectionLength: Int

    let maxWindow: Int
    let paragraphTruncation: Bool
    let adjustBehavior: AdjustBehavior

    var adjustCalls = 0
    var deleteCalls = 0
    var insertCalls = 0

    init(
        text: String,
        cursor: Int? = nil,
        selectionLength: Int = 0,
        maxWindow: Int = 20,
        paragraphTruncation: Bool = true,
        adjustBehavior: AdjustBehavior = .exact
    ) {
        self.characters = Array(text)
        self.cursor = cursor ?? self.characters.count
        self.selectionLength = selectionLength
        self.maxWindow = maxWindow
        self.paragraphTruncation = paragraphTruncation
        self.adjustBehavior = adjustBehavior
    }

    var text: String { String(characters) }

    var documentContextBeforeInput: String? {
        var start = 0
        if paragraphTruncation {
            // Context stops at the most recent newline before the cursor.
            for i in stride(from: cursor - 1, through: 0, by: -1) where characters[i] == "\n" {
                start = i + 1
                break
            }
        }
        start = max(start, cursor - maxWindow)
        guard start < cursor else { return "" }
        return String(characters[start..<cursor])
    }

    var documentContextAfterInput: String? {
        let from = cursor + selectionLength
        var end = characters.count
        if paragraphTruncation {
            var i = from
            while i < characters.count {
                if characters[i] == "\n" { end = i; break }
                i += 1
            }
        }
        end = min(end, from + maxWindow)
        guard from < end else { return "" }
        return String(characters[from..<end])
    }

    var selectedText: String? {
        guard selectionLength > 0 else { return nil }
        return String(characters[cursor..<(cursor + selectionLength)])
    }

    var documentIdentifier: UUID? { nil }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        adjustCalls += 1
        let effective: Int
        switch adjustBehavior {
        case .ignore:
            return
        case .exact:
            effective = offset
        case .undershoot(let drift):
            if offset > 0 {
                effective = max(0, offset - drift)
            } else if offset < 0 {
                effective = min(0, offset + drift)
            } else {
                effective = 0
            }
        }
        // A selection collapses to its far edge before the cursor moves.
        if selectionLength > 0 {
            cursor += selectionLength
            selectionLength = 0
        }
        cursor = max(0, min(characters.count, cursor + effective))
    }

    func deleteBackward() {
        deleteCalls += 1
        if selectionLength > 0 {
            characters.removeSubrange(cursor..<(cursor + selectionLength))
            selectionLength = 0
            return
        }
        guard cursor > 0 else { return }
        characters.remove(at: cursor - 1)
        cursor -= 1
    }

    func insertText(_ text: String) {
        insertCalls += 1
        if selectionLength > 0 {
            characters.removeSubrange(cursor..<(cursor + selectionLength))
            selectionLength = 0
        }
        characters.insert(contentsOf: Array(text), at: cursor)
        cursor += text.count
    }
}
