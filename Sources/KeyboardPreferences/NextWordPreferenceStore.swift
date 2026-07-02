import Foundation

/// One learned "after word X, the user typed word Y" transition. The keyboard
/// records these on every commit so the next-word (予測変換) bar can surface
/// what *this* user actually types next, instead of only azooKey's static guess.
public struct NextWordPreferenceEntry: Codable, Equatable, Sendable {
    public let previousKey: String
    public let nextKey: String
    public var displayText: String
    public var acceptedCount: Int
    public var lastUsedAt: Date
    public var updatedAt: Date

    public init(
        previousKey: String,
        nextKey: String,
        displayText: String,
        acceptedCount: Int,
        lastUsedAt: Date,
        updatedAt: Date
    ) {
        self.previousKey = previousKey
        self.nextKey = nextKey
        self.displayText = displayText
        self.acceptedCount = acceptedCount
        self.lastUsedAt = lastUsedAt
        self.updatedAt = updatedAt
    }
}

public enum NextWordPreferenceStore {
    /// Bigrams accumulate faster than reading→kanji preferences, so this cap is
    /// higher than `ConversionPreferenceStore`'s. Each entry is a small JSON
    /// record; 2000 stays well clear of the extension memory ceiling.
    public static let maxStoredEntries = 2000

    /// Whole-word keys: trim only. Unlike reading keys we don't lowercase —
    /// these are committed display words (kana/kanji), and lowercasing would
    /// only matter for incidental latin, where folding hurts fidelity.
    public static func normalizedKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func readEntries(
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) -> [NextWordPreferenceEntry] {
        guard let data = defaults?.data(forKey: KeyboardSettingsStore.nextWordPreferenceEntriesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([NextWordPreferenceEntry].self, from: data)) ?? []
    }

    public static func writeEntries(
        _ entries: [NextWordPreferenceEntry],
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        let capped = cappedEntries(entries)
        guard let data = try? JSONEncoder().encode(capped) else { return }
        defaults?.set(data, forKey: KeyboardSettingsStore.nextWordPreferenceEntriesKey)
    }

    /// Record that `next` was committed immediately after `previous`.
    public static func recordTransition(
        previous: String,
        next: String,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults,
        now: Date = Date()
    ) {
        let previousKey = normalizedKey(previous)
        let nextKey = normalizedKey(next)
        guard !previousKey.isEmpty, !nextKey.isEmpty else { return }

        var entries = readEntries(defaults: defaults)
        if let index = entries.firstIndex(where: {
            $0.previousKey == previousKey && $0.nextKey == nextKey
        }) {
            entries[index].displayText = next
            entries[index].acceptedCount += 1
            entries[index].lastUsedAt = now
            entries[index].updatedAt = now
        } else {
            entries.append(NextWordPreferenceEntry(
                previousKey: previousKey,
                nextKey: nextKey,
                displayText: next,
                acceptedCount: 1,
                lastUsedAt: now,
                updatedAt: now
            ))
        }
        writeEntries(entries, defaults: defaults)
    }

    /// The words the user has typed after `previous`, most-repeated first
    /// (recency breaks ties), capped at `limit`.
    public static func suggestions(
        after previous: String,
        limit: Int = 3,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults,
        entries: [NextWordPreferenceEntry]? = nil
    ) -> [String] {
        let previousKey = normalizedKey(previous)
        guard !previousKey.isEmpty, limit > 0 else { return [] }

        return (entries ?? readEntries(defaults: defaults))
            .filter { $0.previousKey == previousKey }
            .sorted {
                if $0.acceptedCount != $1.acceptedCount {
                    return $0.acceptedCount > $1.acceptedCount
                }
                return $0.lastUsedAt > $1.lastUsedAt
            }
            .prefix(limit)
            .map(\.displayText)
    }

    private static func cappedEntries(_ entries: [NextWordPreferenceEntry]) -> [NextWordPreferenceEntry] {
        guard entries.count > maxStoredEntries else { return entries }
        return Array(entries
            .sorted {
                if $0.lastUsedAt == $1.lastUsedAt {
                    return $0.acceptedCount > $1.acceptedCount
                }
                return $0.lastUsedAt > $1.lastUsedAt
            }
            .prefix(maxStoredEntries))
    }
}
