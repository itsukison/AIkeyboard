import Foundation

public struct KeyboardDiagnosticEvent: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let occurredAt: Date
    public let distinctId: String?
    public let properties: [String: String]
}

/// Metadata from explicit AI actions and permission changes only. Separate keys
/// keep a container drain from overwriting a concurrently appended event.
public enum KeyboardDiagnosticStore {
    public static let identityKey = "analytics.diagnosticDistinctId"
    public static let onboardingAttemptKey = "analytics.onboardingAttemptId"
    private static let prefix = "analytics.diagnosticEvent."
    public static let limit = 200

    public static func record(_ name: String, properties: [String: String],
                              defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults,
                              now: Date = Date()) {
        guard let defaults else { return }
        let event = KeyboardDiagnosticEvent(id: UUID().uuidString.lowercased(), name: name,
                                            occurredAt: now, distinctId: defaults.string(forKey: identityKey),
                                            properties: properties)
        guard let data = try? JSONEncoder().encode(event) else { return }
        defaults.set(data, forKey: prefix + event.id)
        let entries = pending(defaults: defaults)
        for expired in entries.prefix(max(0, entries.count - limit)) {
            acknowledge(expired, defaults: defaults)
        }
    }

    public static func pending(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) -> [KeyboardDiagnosticEvent] {
        guard let defaults else { return [] }
        return defaults.dictionaryRepresentation().compactMap { key, value in
            guard key.hasPrefix(prefix), let data = value as? Data,
                  let event = try? JSONDecoder().decode(KeyboardDiagnosticEvent.self, from: data) else { return nil }
            return event
        }.sorted { $0.occurredAt == $1.occurredAt ? $0.id < $1.id : $0.occurredAt < $1.occurredAt }
    }

    public static func acknowledge(_ event: KeyboardDiagnosticEvent,
                                   defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) {
        defaults?.removeObject(forKey: prefix + event.id)
    }
}
