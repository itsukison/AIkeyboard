import XCTest
@testable import JapaneseKeyboardCore

final class JapaneseKeyboardCoreTests: XCTestCase {
    func testVersionExists() {
        XCTAssertFalse(JapaneseKeyboardCore.version.isEmpty)
    }
}
