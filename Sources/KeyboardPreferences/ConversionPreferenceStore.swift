import Foundation

public enum ConversionPreferenceScope: String, Codable, Sendable {
    case japanese
    case english
}

public struct ConversionPreferenceEntry: Codable, Equatable, Sendable {
    public let scope: ConversionPreferenceScope
    public let inputKey: String
    public let candidateKey: String
    public var displayText: String
    public var acceptedCount: Int
    public var lastUsedAt: Date
    public var updatedAt: Date

    public init(
        scope: ConversionPreferenceScope,
        inputKey: String,
        candidateKey: String,
        displayText: String,
        acceptedCount: Int,
        lastUsedAt: Date,
        updatedAt: Date
    ) {
        self.scope = scope
        self.inputKey = inputKey
        self.candidateKey = candidateKey
        self.displayText = displayText
        self.acceptedCount = acceptedCount
        self.lastUsedAt = lastUsedAt
        self.updatedAt = updatedAt
    }
}

public enum ConversionPreferenceStore {
    public static let maxStoredEntries = 500

    public static func normalizedInputKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func normalizedCandidateKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public static func readEntries(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> [ConversionPreferenceEntry] {
        guard let data = defaults?.data(forKey: KeyboardSettingsStore.conversionPreferenceEntriesKey) else {
            return []
        }
        return (try? JSONDecoder().decode([ConversionPreferenceEntry].self, from: data)) ?? []
    }

    public static func writeEntries(
        _ entries: [ConversionPreferenceEntry],
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults
    ) {
        let capped = cappedEntries(entries)
        guard let data = try? JSONEncoder().encode(capped) else { return }
        defaults?.set(data, forKey: KeyboardSettingsStore.conversionPreferenceEntriesKey)
    }

    public static func recordSelection(
        scope: ConversionPreferenceScope,
        input: String,
        candidate: String,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults,
        now: Date = Date()
    ) {
        let inputKey = normalizedInputKey(input)
        let candidateKey = normalizedCandidateKey(candidate)
        guard !inputKey.isEmpty, !candidateKey.isEmpty else { return }

        var entries = readEntries(defaults: defaults)
        if let index = entries.firstIndex(where: {
            $0.scope == scope && $0.inputKey == inputKey && $0.candidateKey == candidateKey
        }) {
            entries[index].displayText = candidate
            entries[index].acceptedCount += 1
            entries[index].lastUsedAt = now
            entries[index].updatedAt = now
        } else {
            entries.append(ConversionPreferenceEntry(
                scope: scope,
                inputKey: inputKey,
                candidateKey: candidateKey,
                displayText: candidate,
                acceptedCount: 1,
                lastUsedAt: now,
                updatedAt: now
            ))
        }
        writeEntries(entries, defaults: defaults)
    }

    public static func recordKeepRaw(
        scope: ConversionPreferenceScope,
        input: String,
        defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults,
        now: Date = Date()
    ) {
        recordSelection(scope: scope, input: input, candidate: input, defaults: defaults, now: now)
    }

    public static func rerank(
        scope: ConversionPreferenceScope,
        input: String,
        candidates: [String],
        entries: [ConversionPreferenceEntry] = readEntries(),
        now: Date = Date()
    ) -> [String] {
        let inputKey = normalizedInputKey(input)
        guard !inputKey.isEmpty, candidates.count > 1 else { return candidates }

        let candidateEntries = Dictionary(
            entries
                .filter { $0.scope == scope && $0.inputKey == inputKey }
                .map { ($0.candidateKey, $0) },
            uniquingKeysWith: { first, second in
                first.updatedAt >= second.updatedAt ? first : second
            }
        )

        return candidates.enumerated()
            .sorted { lhs, rhs in
                let lhsScore = score(
                    index: lhs.offset,
                    candidate: lhs.element,
                    entry: candidateEntries[normalizedCandidateKey(lhs.element)],
                    now: now
                )
                let rhsScore = score(
                    index: rhs.offset,
                    candidate: rhs.element,
                    entry: candidateEntries[normalizedCandidateKey(rhs.element)],
                    now: now
                )
                if lhsScore == rhsScore {
                    return lhs.offset < rhs.offset
                }
                return lhsScore > rhsScore
            }
            .map(\.element)
    }

    private static func score(
        index: Int,
        candidate: String,
        entry: ConversionPreferenceEntry?,
        now: Date
    ) -> Double {
        var value = -Double(index)
        guard let entry, entry.acceptedCount > 0 else { return value }

        if entry.acceptedCount == 1 {
            value += 0.5
        } else {
            value += Double(min(8, entry.acceptedCount * 2))
        }

        let age = max(0, now.timeIntervalSince(entry.lastUsedAt))
        if age <= 7 * 24 * 60 * 60 {
            value += 1
        }

        if normalizedCandidateKey(candidate) == entry.inputKey {
            value += 0.5
        }
        return value
    }

    private static func cappedEntries(_ entries: [ConversionPreferenceEntry]) -> [ConversionPreferenceEntry] {
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
