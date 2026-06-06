import Foundation

public struct Candidate: Identifiable, Equatable, Hashable, Sendable {
    public let text: String
    public let reading: String

    public init(text: String, reading: String) {
        self.text = text
        self.reading = reading
    }

    public var id: String { "\(reading)|\(text)" }
}
