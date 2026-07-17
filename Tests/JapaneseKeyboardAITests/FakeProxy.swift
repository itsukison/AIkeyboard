import Foundation
@testable import JapaneseKeyboardAI

@MainActor
final class FakeProxy: TextDocumentProxying {
    var before: String
    var selected: String
    var after: String

    var adjustCalls = 0
    var adjustOffsetTotal = 0
    var deleteCalls = 0
    var insertCalls = 0

    init(before: String, selected: String, after: String) {
        self.before = before
        self.selected = selected
        self.after = after
    }

    var documentContextBeforeInput: String? { before }
    var documentContextAfterInput: String? { after }
    var selectedText: String? { selected.isEmpty ? nil : selected }
    var documentIdentifier: UUID? { nil }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        adjustCalls += 1
        adjustOffsetTotal += offset
        // Model: positive offset moves cursor right, pulling text from `after` into `before`.
        if offset > 0 {
            let n = min(offset, after.count)
            let idx = after.index(after.startIndex, offsetBy: n)
            before += String(after[..<idx])
            after = String(after[idx...])
        }
        // Selection is preserved as-is per UITextDocumentProxy semantics for adjustTextPosition.
    }

    func deleteBackward() {
        deleteCalls += 1
        // If selection exists, first delete clears the selection without touching before/after.
        if !selected.isEmpty {
            selected = ""
            return
        }
        guard !before.isEmpty else { return }
        before.removeLast()
    }

    func insertText(_ text: String) {
        insertCalls += 1
        if !selected.isEmpty {
            selected = ""
        }
        before += text
    }
}
