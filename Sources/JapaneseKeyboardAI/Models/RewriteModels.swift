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
    public let analyticsAppInstanceId: String?
    /// True when `text` is a fragment the user selected inside a larger text.
    /// The backend rewrites the fragment so it fits where it stands.
    public let selection: Bool
    /// Window-truncated host text around the selection, sent for rewrite
    /// quality only — the backend must never store it.
    public let selectionContextBefore: String?
    public let selectionContextAfter: String?

    public init(
        prompt: String,
        text: String,
        replyTo: String? = nil,
        commandKey: String? = nil,
        title: String? = nil,
        locale: String,
        appVersion: String,
        candidateCount: Int = 3,
        refinement: RefinementIntent? = nil,
        analyticsAppInstanceId: String? = nil,
        selection: Bool = false,
        selectionContextBefore: String? = nil,
        selectionContextAfter: String? = nil
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
        self.analyticsAppInstanceId = analyticsAppInstanceId
        self.selection = selection
        self.selectionContextBefore = selectionContextBefore
        self.selectionContextAfter = selectionContextAfter
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
    /// Server id of the logged rewrite event. Sent back via `submitSelection`
    /// when the user accepts a candidate so the choice can be recorded.
    public let eventId: String?

    public init(candidates: [RewriteCandidate], language: String, eventId: String? = nil) {
        self.candidates = candidates
        self.language = language
        self.eventId = eventId
    }
}

public enum CaptureMode: String, Codable, Sendable {
    /// The window iOS exposes around the cursor; replaced via delete-then-insert.
    case wholeInput
    /// Only the user's active selection; replaced via a single `insertText`.
    case selection
    /// The whole document stitched by `FullDocumentReader`; replaced by the
    /// async full-document engine.
    case fullDocument
}

public struct WholeInputCapture: Equatable, Codable, Sendable {
    public let mode: CaptureMode
    public let beforeCursor: String
    public let selectedText: String
    public let afterCursor: String
    public let targetText: String
    public let moveToEndCharacterCount: Int
    public let deleteBackwardCharacterCount: Int
    public let documentIdentifierString: String?
    public let capturedAt: Date

    public init(
        mode: CaptureMode,
        beforeCursor: String,
        selectedText: String,
        afterCursor: String,
        targetText: String,
        moveToEndCharacterCount: Int,
        deleteBackwardCharacterCount: Int,
        documentIdentifierString: String?,
        capturedAt: Date
    ) {
        self.mode = mode
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
            mode: .wholeInput,
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

    /// Full-document capture: `beforeCursor`/`afterCursor` are the whole
    /// document as stitched by `FullDocumentReader`, not the truncated proxy
    /// windows. Replacement goes through the async full-document engine.
    public static func makeFullDocument(
        beforeCursor: String,
        afterCursor: String,
        documentIdentifierString: String?,
        maxCharacters: Int,
        capturedAt: Date = Date()
    ) throws -> WholeInputCapture {
        let target = beforeCursor + afterCursor
        guard !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WholeInputCaptureError.empty
        }
        guard target.count <= maxCharacters else {
            throw WholeInputCaptureError.tooLong
        }
        return WholeInputCapture(
            mode: .fullDocument,
            beforeCursor: beforeCursor,
            selectedText: "",
            afterCursor: afterCursor,
            targetText: target,
            moveToEndCharacterCount: afterCursor.count,
            deleteBackwardCharacterCount: target.count,
            documentIdentifierString: documentIdentifierString,
            capturedAt: capturedAt
        )
    }

    /// Selection-only capture: the target is the highlighted text alone, and
    /// replacement is a single `insertText` (which natively replaces an active
    /// selection), so no cursor moves or deletes are needed.
    public static func makeSelection(
        beforeCursor: String,
        selectedText: String,
        afterCursor: String,
        documentIdentifierString: String?,
        maxCharacters: Int,
        capturedAt: Date = Date()
    ) throws -> WholeInputCapture {
        guard !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WholeInputCaptureError.empty
        }
        guard selectedText.count <= maxCharacters else {
            throw WholeInputCaptureError.tooLong
        }
        return WholeInputCapture(
            mode: .selection,
            beforeCursor: beforeCursor,
            selectedText: selectedText,
            afterCursor: afterCursor,
            targetText: selectedText,
            moveToEndCharacterCount: 0,
            deleteBackwardCharacterCount: 0,
            documentIdentifierString: documentIdentifierString,
            capturedAt: capturedAt
        )
    }
}

public enum WholeInputCaptureError: Error, Equatable, Sendable {
    case empty
    case tooLong
}
