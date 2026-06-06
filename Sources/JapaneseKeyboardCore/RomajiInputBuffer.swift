import Foundation

/// Stateful buffer that accumulates romaji characters and exposes the
/// live kana representation. The buffer holds the entire pending romaji
/// (including any partial trailing input that has not yet resolved to kana).
@MainActor
public final class RomajiInputBuffer {
    public private(set) var pendingRomaji: String = ""

    public init() {}

    public var isEmpty: Bool {
        pendingRomaji.isEmpty
    }

    /// Live representation: kana for the resolvable prefix, with any
    /// trailing unresolved romaji left as latin characters. Use this as
    /// marked text in the host while the user is composing.
    public var displayKana: String {
        Romaji.toLiveKana(pendingRomaji)
    }

    /// Best-effort fully-resolved kana for the entire buffer, including any
    /// trailing "n" that will be forced to ん. Use this when committing.
    public var finalKana: String {
        Romaji.toKana(pendingRomaji)
    }

    public func append(_ character: Character) {
        pendingRomaji.append(character)
    }

    public func append(_ string: String) {
        pendingRomaji.append(string)
    }

    /// Deletes one visible kana unit from the marked-text preview. Pops romaji
    /// chars until `displayKana` shrinks by at least one character — so e.g.
    /// `た` (buffer "ta") goes to empty in one stroke instead of leaving "t",
    /// matching native Japanese IME backspace behavior.
    @discardableResult
    public func backspace() -> Bool {
        guard !pendingRomaji.isEmpty else { return false }
        let originalCount = displayKana.count
        repeat {
            pendingRomaji.removeLast()
        } while !pendingRomaji.isEmpty && displayKana.count >= originalCount
        return true
    }

    public func reset() {
        pendingRomaji = ""
    }
}
