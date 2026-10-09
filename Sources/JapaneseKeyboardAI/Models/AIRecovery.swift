import Foundation

public enum AIRecoveryDestination: String, Equatable, Sendable {
    case login, consent, fullaccess, settings, update

    public var url: URL { URL(string: "keigobutton://\(rawValue)")! }
}

public enum AIReadiness: Equatable, Sendable {
    case ready, fullAccessRequired, signInRequired, consentRequired, cloudDisabled

    public static func evaluate(practice: Bool, fullAccess: Bool, hasToken: Bool,
                                sessionRejected: Bool, consent: Bool, cloudEnabled: Bool) -> Self {
        if practice { return .ready }
        if !fullAccess { return .fullAccessRequired }
        if !hasToken || sessionRejected { return .signInRequired }
        if !consent { return .consentRequired }
        if !cloudEnabled { return .cloudDisabled }
        return .ready
    }
}

public struct AIRecoveryHelp: Equatable, Sendable {
    public enum Reason: Equatable, Sendable { case fullAccessDisabled, openingRejected }
    public let destination: AIRecoveryDestination
    public let reason: Reason
}

/// Request identity prevents a late URL completion from reopening dismissed help.
public struct AIRecoveryNavigation: Equatable, Sendable {
    public private(set) var help: AIRecoveryHelp?
    public private(set) var pendingID: UUID?

    public init() {}

    public mutating func begin(_ destination: AIRecoveryDestination, fullAccess: Bool) -> UUID? {
        guard pendingID == nil else { return nil }
        guard fullAccess else {
            help = AIRecoveryHelp(destination: destination, reason: .fullAccessDisabled)
            return nil
        }
        help = nil
        let id = UUID()
        pendingID = id
        return id
    }

    public mutating func complete(_ id: UUID, destination: AIRecoveryDestination, accepted: Bool) {
        guard pendingID == id else { return }
        pendingID = nil
        help = accepted ? nil : AIRecoveryHelp(destination: destination, reason: .openingRejected)
    }

    public mutating func dismiss() {
        pendingID = nil
        help = nil
    }
}
