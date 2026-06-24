import Foundation

public enum RefinementIntent: String, Codable, CaseIterable, Sendable {
    case morePolite
    case moreDetailed
    case moreConcise

    public var title: String {
        switch self {
        case .morePolite: return "より丁寧に"
        case .moreDetailed: return "より詳しく"
        case .moreConcise: return "より短く"
        }
    }

    public var iconName: String {
        switch self {
        case .morePolite: return "briefcase"
        case .moreDetailed: return "arrow.up.and.down.text.horizontal"
        case .moreConcise: return "arrow.down.right.and.arrow.up.left"
        }
    }
}

public struct RewriteRequest: Codable, Sendable {
    public let prompt: String
    public let text: String
    /// The message being replied to (reply mode). When present, the backend
    /// composes a reply to this instead of rewriting `text`; `text` then carries
    /// the user's intent/notes for the reply and may be empty.
    public let replyTo: String?
    public let commandKey: String?
    public let title: String?
    public let locale: String
    public let appVersion: String
    public let candidateCount: Int
    public let refinement: RefinementIntent?

    public init(
        prompt: String,
        text: String,
        replyTo: String? = nil,
        commandKey: String? = nil,
        title: String? = nil,
        locale: String,
        appVersion: String,
        candidateCount: Int = 3,
        refinement: RefinementIntent? = nil
    ) {
        self.prompt = prompt
        self.text = text
        self.replyTo = replyTo
        self.commandKey = commandKey
        self.title = title
        self.locale = locale
        self.appVersion = appVersion
        self.candidateCount = candidateCount
        self.refinement = refinement
    }
}

public struct RewriteCandidate: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let replacement: String
    public let changed: Bool

    public init(id: UUID = UUID(), replacement: String, changed: Bool) {
        self.id = id
        self.replacement = replacement
        self.changed = changed
    }

    private enum CodingKeys: String, CodingKey {
        case id, replacement, changed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decodeIfPresent(UUID.self, forKey: .id)
        self.id = decodedId ?? UUID()
        self.replacement = try container.decode(String.self, forKey: .replacement)
        self.changed = try container.decodeIfPresent(Bool.self, forKey: .changed) ?? true
    }
}

public struct RewriteResult: Codable, Equatable, Sendable {
    public let candidates: [RewriteCandidate]
    public let language: String

    public init(candidates: [RewriteCandidate], language: String) {
        self.candidates = candidates
        self.language = language
    }
}

public struct WholeInputCapture: Equatable, Codable, Sendable {
    public let beforeCursor: String
    public let selectedText: String
    public let afterCursor: String
    public let targetText: String
    public let moveToEndCharacterCount: Int
    public let deleteBackwardCharacterCount: Int
    public let documentIdentifierString: String?
    public let capturedAt: Date

    public init(
        beforeCursor: String,
        selectedText: String,
        afterCursor: String,
        targetText: String,
        moveToEndCharacterCount: Int,
        deleteBackwardCharacterCount: Int,
        documentIdentifierString: String?,
        capturedAt: Date
    ) {
        self.beforeCursor = beforeCursor
        self.selectedText = selectedText
        self.afterCursor = afterCursor
        self.targetText = targetText
        self.moveToEndCharacterCount = moveToEndCharacterCount
        self.deleteBackwardCharacterCount = deleteBackwardCharacterCount
        self.documentIdentifierString = documentIdentifierString
        self.capturedAt = capturedAt
    }

    public static func make(
        beforeCursor: String,
        selectedText: String,
        afterCursor: String,
        documentIdentifierString: String?,
        maxCharacters: Int,
        allowEmpty: Bool = false,
        capturedAt: Date = Date()
    ) throws -> WholeInputCapture {
        let target = beforeCursor + selectedText + afterCursor
        if !allowEmpty {
            guard !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw WholeInputCaptureError.empty
            }
        }
        guard target.count <= maxCharacters else {
            throw WholeInputCaptureError.tooLong
        }
        return WholeInputCapture(
            beforeCursor: beforeCursor,
            selectedText: selectedText,
            afterCursor: afterCursor,
            targetText: target,
            moveToEndCharacterCount: afterCursor.count,
            deleteBackwardCharacterCount: target.count,
            documentIdentifierString: documentIdentifierString,
            capturedAt: capturedAt
        )
    }
}

public enum WholeInputCaptureError: Error, Equatable, Sendable {
    case empty
    case tooLong
}
