import XCTest
@testable import JapaneseKeyboardAI

final class AIRecoveryTests: XCTestCase {
    func testReadinessPriorityAcrossEveryCombination() {
        for practice in [false, true] {
            for fullAccess in [false, true] {
                for token in [false, true] {
                    for rejected in [false, true] {
                        for consent in [false, true] {
                            for cloud in [false, true] {
                                let expected: AIReadiness = practice ? .ready :
                                    !fullAccess ? .fullAccessRequired :
                                    (!token || rejected) ? .signInRequired :
                                    !consent ? .consentRequired : !cloud ? .cloudDisabled : .ready
                                XCTAssertEqual(AIReadiness.evaluate(
                                    practice: practice, fullAccess: fullAccess, hasToken: token,
                                    sessionRejected: rejected, consent: consent, cloudEnabled: cloud
                                ), expected)
                            }
                        }
                    }
                }
            }
        }
    }

    func testAllDestinationsHaveLocalHelpWithoutFullAccess() {
        for destination: AIRecoveryDestination in [.login, .consent, .fullaccess, .settings, .update] {
            var navigation = AIRecoveryNavigation()
            XCTAssertNil(navigation.begin(destination, fullAccess: false))
            XCTAssertEqual(navigation.help?.destination, destination)
            XCTAssertEqual(navigation.help?.reason, .fullAccessDisabled)
            XCTAssertNil(navigation.pendingID)
        }
    }

    func testRejectedOpeningCanRetryAndAcceptedOpeningClearsHelp() throws {
        var navigation = AIRecoveryNavigation()
        let first = try XCTUnwrap(navigation.begin(.login, fullAccess: true))
        XCTAssertNil(navigation.begin(.login, fullAccess: true))
        navigation.complete(first, destination: .login, accepted: false)
        XCTAssertEqual(navigation.help?.reason, .openingRejected)
        let retry = try XCTUnwrap(navigation.begin(.login, fullAccess: true))
        navigation.complete(retry, destination: .login, accepted: true)
        XCTAssertNil(navigation.help)
        XCTAssertNil(navigation.pendingID)
    }

    func testDismissedAndSupersededCompletionsAreIgnored() throws {
        var navigation = AIRecoveryNavigation()
        let old = try XCTUnwrap(navigation.begin(.consent, fullAccess: true))
        navigation.dismiss()
        navigation.complete(old, destination: .consent, accepted: false)
        XCTAssertNil(navigation.help)
        let current = try XCTUnwrap(navigation.begin(.settings, fullAccess: true))
        navigation.complete(old, destination: .consent, accepted: false)
        XCTAssertEqual(navigation.pendingID, current)
        XCTAssertNil(navigation.help)
    }
}
