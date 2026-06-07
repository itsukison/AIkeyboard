import JapaneseKeyboardAI
import UIKit

/// Adapter so the AI capture / replacement engine can drive
/// `UITextDocumentProxy` without importing UIKit itself.
///
/// Swift forbids declaring protocol-to-protocol conformance via `extension`
/// (you can only retroactively conform concrete types), and
/// `UITextDocumentProxy` is itself a protocol with many concrete hosts.
/// Wrapping is the cheapest workaround: a single retained reference per call.
@MainActor
final class TextDocumentProxyAdapter: TextDocumentProxying {
    private let proxy: UITextDocumentProxy

    init(_ proxy: UITextDocumentProxy) {
        self.proxy = proxy
    }

    var documentContextBeforeInput: String? { proxy.documentContextBeforeInput }
    var documentContextAfterInput: String? { proxy.documentContextAfterInput }
    var selectedText: String? { proxy.selectedText }
    var documentIdentifier: UUID? { proxy.documentIdentifier }

    func adjustTextPosition(byCharacterOffset offset: Int) {
        proxy.adjustTextPosition(byCharacterOffset: offset)
    }

    func deleteBackward() {
        proxy.deleteBackward()
    }

    func insertText(_ text: String) {
        proxy.insertText(text)
    }
}

extension UITextDocumentProxy {
    /// Adapter view that satisfies `TextDocumentProxying`.
    var ai: TextDocumentProxying { TextDocumentProxyAdapter(self) }
}
