import Foundation

/// Surface of `UITextDocumentProxy` that the capture/replacement engine
/// actually needs. Declared here so `JapaneseKeyboardAI` stays free of
/// UIKit and remains unit-testable from `swift test`.
///
/// `UITextDocumentProxy` already satisfies this surface; conformance is
/// declared by an extension in the keyboard extension target.
@MainActor
public protocol TextDocumentProxying: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    var selectedText: String? { get }
    var documentIdentifier: UUID? { get }
    func adjustTextPosition(byCharacterOffset offset: Int)
    func deleteBackward()
    func insertText(_ text: String)
}
