import Foundation
import XCTest
@testable import JapaneseKeyboardAI

final class RewriteAttemptMetadataTests: XCTestCase {
    func testRepeatedGenerationKeepsRootAndExactParent() throws {
        let original = RewriteAttemptMetadata()
        let regenerated = RewriteAttemptMetadata(kind: "regenerate", previous: original, parentGenerationId: "generation-original")
        let refined = RewriteAttemptMetadata(kind: "refine", previous: original, parentGenerationId: "generation-original")
        XCTAssertNotEqual(original.attemptId, regenerated.attemptId)
        XCTAssertNotEqual(regenerated.attemptId, refined.attemptId)
        XCTAssertEqual(regenerated.rootAttemptId, original.attemptId)
        XCTAssertEqual(refined.rootAttemptId, original.attemptId)
        XCTAssertEqual(refined.parentGenerationId, "generation-original")
        XCTAssertNotEqual(RewriteAttemptMetadata().rootAttemptId, original.rootAttemptId)
    }

    func testRequestCarriesMetadataWithoutChangingRewriteContent() throws {
        let metadata = RewriteAttemptMetadata(onboardingAttemptId: "onboarding-a", appBuild: "23", now: Date(timeIntervalSince1970: 1_700_000_000))
        let request = RewriteRequest(prompt: "丁寧に", text: "確認して", locale: "ja-JP", appVersion: "test", diagnostics: metadata)
        let decoded = try JSONDecoder().decode(RewriteRequest.self, from: JSONEncoder().encode(request))
        XCTAssertEqual(decoded.diagnostics, metadata)
        XCTAssertEqual(decoded.diagnostics?.appBuild, "23")
        XCTAssertEqual(decoded.diagnostics?.onboardingAttemptId, "onboarding-a")
        XCTAssertEqual(decoded.text, request.text)
        XCTAssertEqual(decoded.prompt, request.prompt)
        XCTAssertEqual(metadata.properties["attempt_occurred_at"], "2023-11-14T22:13:20Z")
        XCTAssertFalse(metadata.properties.keys.contains("text"))
    }

    func testOldRequestDecodesWithoutDiagnostics() throws {
        let data = Data(#"{"prompt":"丁寧に","text":"確認して","locale":"ja-JP","appVersion":"old","candidateCount":3,"selection":false,"stream":false}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(RewriteRequest.self, from: data).diagnostics)
    }
}
