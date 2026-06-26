import Foundation

/// Stateful buffer that accumulates romaji characters and exposes the
/// live kana representation. The buffer holds the entire pending romaji
/// (including any partial trailing input that has not yet resolved to kana).
@MainActor
public final class RomajiInputBuffer: InputBuffer {
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
        let originalDisplay = displayKana
        guard !originalDisplay.isEmpty else {
            pendingRomaji.removeLast()
            return true
        }

        let targetDisplay = String(originalDisplay.dropLast())
        if setPendingRomajiByTrimming(to: targetDisplay) { return true }
        if setPendingRomajiByReconciling(to: targetDisplay) { return true }

        pendingRomaji.removeLast()
        return true
    }

    public func reset() {
        pendingRomaji = ""
    }

    private func setPendingRomajiByTrimming(to targetDisplay: String) -> Bool {
        var candidate = pendingRomaji
        repeat {
            candidate.removeLast()
            if Romaji.toLiveKana(candidate) == targetDisplay {
                pendingRomaji = candidate
                return true
            }
        } while !candidate.isEmpty
        return false
    }

    private func setPendingRomajiByReconciling(to targetDisplay: String) -> Bool {
        let original = pendingRomaji
        var prefixEnd = original.endIndex

        while true {
            let rawPrefix = String(original[..<prefixEnd])
            let displayPrefix = Romaji.toLiveKana(rawPrefix)

            if targetDisplay.hasPrefix(displayPrefix) {
                let suffixDisplay = String(targetDisplay.dropFirst(displayPrefix.count))
                let originalSuffix = String(original[prefixEnd...])
                if let suffix = Self.bestRomaji(for: suffixDisplay, originalSuffix: originalSuffix) {
                    let candidate = rawPrefix + suffix
                    if Romaji.toLiveKana(candidate) == targetDisplay {
                        pendingRomaji = candidate
                        return true
                    }
                }
            }

            if prefixEnd == original.startIndex { break }
            prefixEnd = original.index(before: prefixEnd)
        }

        return false
    }

    private static func bestRomaji(for display: String, originalSuffix: String) -> String? {
        guard !display.isEmpty else { return "" }
        return romajiCandidates(for: display)
            .filter { Romaji.toLiveKana($0) == display }
            .sorted { isBetterRomaji($0, than: $1, originalSuffix: originalSuffix) }
            .first
    }

    private static func romajiCandidates(for display: String) -> [String] {
        var results: [String] = []
        let entries = Romaji.kanaTable
            .map { (romaji: $0.key, kana: $0.value) }
            .sorted {
                if $0.kana.count != $1.kana.count { return $0.kana.count > $1.kana.count }
                return $0.romaji < $1.romaji
            }

        func visit(_ remaining: Substring, built: String) {
            guard results.count < 128 else { return }
            guard !remaining.isEmpty else {
                results.append(built)
                return
            }

            if let first = remaining.first, first.isASCII {
                visit(remaining.dropFirst(), built: built + String(first))
            }

            for entry in entries where remaining.hasPrefix(entry.kana) {
                visit(remaining.dropFirst(entry.kana.count), built: built + entry.romaji)
            }
        }

        visit(display[...], built: "")
        return results
    }

    private static func isBetterRomaji(_ lhs: String, than rhs: String, originalSuffix: String) -> Bool {
        let lhsPrefix = commonPrefixLength(lhs, originalSuffix)
        let rhsPrefix = commonPrefixLength(rhs, originalSuffix)
        if lhsPrefix != rhsPrefix { return lhsPrefix > rhsPrefix }

        let lhsSameFirst = lhs.first == originalSuffix.first
        let rhsSameFirst = rhs.first == originalSuffix.first
        if lhsSameFirst != rhsSameFirst { return lhsSameFirst }

        let lhsRank = preferredRomanizationRank(lhs)
        let rhsRank = preferredRomanizationRank(rhs)
        if lhsRank != rhsRank { return lhsRank < rhsRank }

        let lhsDelta = abs(lhs.count - originalSuffix.count)
        let rhsDelta = abs(rhs.count - originalSuffix.count)
        if lhsDelta != rhsDelta { return lhsDelta < rhsDelta }

        if lhs.count != rhs.count { return lhs.count < rhs.count }
        return lhs < rhs
    }

    private static func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        for (left, right) in zip(lhs, rhs) {
            guard left == right else { break }
            count += 1
        }
        return count
    }

    private static func preferredRomanizationRank(_ romaji: String) -> Int {
        switch romaji {
        case "shi", "chi", "tsu", "fu", "ji", "xtu", "xya", "xyu", "xyo":
            return 0
        case "si", "ti", "tu", "hu", "zi", "xtsu", "lya", "lyu", "lyo":
            return 1
        case "ltu", "ltsu":
            return 2
        default:
            return 10
        }
    }
}
