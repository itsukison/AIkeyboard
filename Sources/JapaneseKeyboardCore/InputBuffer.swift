import Foundation

/// Abstraction over the pending input that feeds the kana-kanji converter.
/// `RomajiInputBuffer` accumulates latin letters and resolves them to kana;
/// `KanaInputBuffer` stores kana directly (the flick/10-key input mode).
/// `InputManager` drives either through this protocol, so the conversion,
/// candidate, and commit pipeline is shared between the two input modes.
@MainActor
public protocol InputBuffer: AnyObject {
    var displayKana: String { get }
    var finalKana: String { get }
    var isEmpty: Bool { get }
    func append(_ string: String)
    @discardableResult
    func backspace() -> Bool
    func reset()
}
