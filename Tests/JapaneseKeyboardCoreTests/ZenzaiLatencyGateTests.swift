import XCTest
@testable import JapaneseKeyboardCore

final class ZenzaiLatencyGateTests: XCTestCase {
    private func makeGate() -> ZenzaiLatencyGate {
        ZenzaiLatencyGate(warmupCount: 3, windowSize: 15, thresholdMilliseconds: 150)
    }

    func testWarmupSamplesNeverTrip() {
        var gate = makeGate()
        for _ in 0..<3 {
            XCTAssertFalse(gate.record(latencyMilliseconds: 10_000))
        }
    }

    func testDoesNotTripBeforeFullWindow() {
        var gate = makeGate()
        for _ in 0..<3 { _ = gate.record(latencyMilliseconds: 500) }
        for _ in 0..<14 {
            XCTAssertFalse(gate.record(latencyMilliseconds: 500))
        }
    }

    func testTripsOnSustainedSlowness() {
        var gate = makeGate()
        for _ in 0..<3 { _ = gate.record(latencyMilliseconds: 500) }
        for _ in 0..<14 { _ = gate.record(latencyMilliseconds: 500) }
        XCTAssertTrue(gate.record(latencyMilliseconds: 500))
    }

    func testMedianIgnoresMinoritySpikes() {
        var gate = makeGate()
        for _ in 0..<3 { _ = gate.record(latencyMilliseconds: 30) }
        // 7 huge spikes among 8 fast samples: median stays fast.
        var tripped = false
        for i in 0..<15 {
            tripped = gate.record(latencyMilliseconds: i < 7 ? 5_000 : 30) || tripped
        }
        XCTAssertFalse(tripped)
    }

    func testWindowRollsOffOldSlowSamples() {
        var gate = makeGate()
        for _ in 0..<3 { _ = gate.record(latencyMilliseconds: 30) }
        // A slow stretch shorter than the window, then sustained fast
        // conversions: the slow samples roll out and the gate stays open.
        var tripped = false
        for _ in 0..<7 { tripped = gate.record(latencyMilliseconds: 500) || tripped }
        for _ in 0..<20 { tripped = gate.record(latencyMilliseconds: 30) || tripped }
        XCTAssertFalse(tripped)
    }

    func testBoundaryMedianDoesNotTrip() {
        var gate = makeGate()
        for _ in 0..<3 { _ = gate.record(latencyMilliseconds: 150) }
        var tripped = false
        for _ in 0..<15 { tripped = gate.record(latencyMilliseconds: 150) || tripped }
        XCTAssertFalse(tripped, "median exactly at the threshold must not trip")
    }
}
