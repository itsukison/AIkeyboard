import Foundation

/// Input buffer for the flick/10-key kana input mode. Stores kana directly —
/// each flick appends one kana grapheme, `displayKana` and `finalKana` are the
/// raw stored string, and backspace drops one kana. There is no romaji
/// resolution step, so the live preview and the committed text are identical.
@MainActor
public final class KanaInputBuffer: InputBuffer {
    private var kana: String = ""

    public init() {}

    public var isEmpty: Bool {
        kana.isEmpty
    }

    public var displayKana: String {
        kana
    }

    public var finalKana: String {
        kana
    }

    public func append(_ string: String) {
        kana.append(string)
    }

    @discardableResult
    public func backspace() -> Bool {
        guard !kana.isEmpty else { return false }
        kana.removeLast()
        return true
    }

    public func reset() {
        kana = ""
    }
}
