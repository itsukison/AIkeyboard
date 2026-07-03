import Foundation

/// Decides when Zenzai is too slow for the current device and conversion
/// should silently fall back to the classical lattice — the latency
/// counterpart of the jetsam-headroom gate. Pure sample math so it can be
/// unit-tested; the caller owns environment checks (Low Power Mode, thermal
/// state) and simply withholds samples taken under throttling, because a
/// deliberately-slowed CPU says nothing about the device's real speed.
struct ZenzaiLatencyGate {
    /// Conversions ignored after process start: the first requests page in
    /// the model mmap and fill caches, so they are structurally slow on
    /// every device.
    let warmupCount: Int
    /// Samples required before judging. A full window plus the median makes
    /// one-off spikes (GC, page fault) unable to trip the gate.
    let windowSize: Int
    /// Sustained median above this reads as "candidates visibly trail
    /// typing" — classical conversion lands in ~10-30 ms.
    let thresholdMilliseconds: Double

    private var samples: [Double] = []
    private var warmupRemaining: Int

    init(warmupCount: Int = 3, windowSize: Int = 15, thresholdMilliseconds: Double = 150) {
        self.warmupCount = warmupCount
        self.windowSize = windowSize
        self.thresholdMilliseconds = thresholdMilliseconds
        self.warmupRemaining = warmupCount
    }

    /// Records one conversion's latency. Returns `true` when the rolling
    /// median over a full window crosses the threshold — the caller should
    /// then disable Zenzai for this process and persist the decision.
    mutating func record(latencyMilliseconds: Double) -> Bool {
        if warmupRemaining > 0 {
            warmupRemaining -= 1
            return false
        }
        samples.append(latencyMilliseconds)
        if samples.count > windowSize {
            samples.removeFirst()
        }
        guard samples.count == windowSize else { return false }
        return median(of: samples) > thresholdMilliseconds
    }

    private func median(of values: [Double]) -> Double {
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
