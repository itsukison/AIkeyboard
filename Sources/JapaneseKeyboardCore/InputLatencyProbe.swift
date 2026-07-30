import Foundation
import os

/// DEBUG-only instrumentation for the "typing feels laggier than native"
/// investigation. Two things it answers:
///
/// 1. Named intervals for the per-keystroke work — the `textDidChange` /
///    `selectionDidChange` handlers and their individual pieces, the haptic and
///    audio calls, the marked-text proxy write, and one conversion.
/// 2. `runloop-stall` — how late a 60 Hz main-runloop timer fires, i.e. how
///    congested the main thread is overall.
///
/// Deliberately absent: a finger-to-haptic number. Measuring it needs a
/// `UITouch` timestamp correlated with a KeyboardKit gesture, and the only way
/// to see a `UITouch` here is an observing recognizer on the keyboard's root
/// view — whose `touchesBegan` is *not* guaranteed to run before the SwiftUI
/// gesture that drives the key. When it runs second, every press pairs with the
/// previous keystroke's touch and the metric silently reports the
/// inter-keystroke interval (~130-200 ms while typing) as if it were latency.
/// That artifact is what sent this investigation chasing a phantom; the tell was
/// `gesture:end` (67 ms) reading *earlier* than `gesture:press` (132 ms) for the
/// same touch, which is impossible. Don't reintroduce it without pairing by
/// touch identity.
///
/// Every entry point compiles to nothing in Release, so call sites need no
/// `#if DEBUG` of their own. Read the numbers either as `os_signpost`
/// intervals in Instruments' Points of Interest track, or from the console
/// table printed every 5 s and again on dismiss.
public enum InputLatencyProbe {
    /// Times `body`, recording it under `name` and emitting a signpost interval.
    @inline(__always)
    public static func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        #if DEBUG
        return try Store.shared.measure(name, body)
        #else
        return try body()
        #endif
    }

    /// Clears all samples and starts the runloop-stall sampler. Call on
    /// keyboard appearance so each session reads independently.
    public static func startSampling() {
        #if DEBUG
        Store.shared.startSampling()
        #endif
    }

    /// Stops sampling and prints the final table — the numbers to compare
    /// before and after a fix.
    public static func stopSampling() {
        #if DEBUG
        Store.shared.stopSampling()
        #endif
    }
}

#if DEBUG
/// All mutable state lives behind one lock: `measure` is called from the main
/// actor (input handling) and from the converter actor's thread.
private final class Store: @unchecked Sendable {
    static let shared = Store()

    private let lock = NSLock()
    private let signposter = OSSignposter(subsystem: "com.core7.keigobutton", category: "InputLatency")
    private var samples: [String: [Double]] = [:]
    /// Insertion order, so the table reads in the order events happen.
    private var order: [String] = []
    private var stallTimer: Timer?
    private var lastTick: TimeInterval = 0
    private var ticksUntilDump = 0

    /// Rolling window per metric. Long enough for a stable p90 over a sentence
    /// or two, short enough that one bad early sample doesn't skew the session.
    private static let windowSize = 200
    private static let stallInterval: TimeInterval = 1.0 / 60.0
    private static let ticksPerDump = 300

    func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let state = signposter.beginInterval(name, id: signposter.makeSignpostID())
        let start = ProcessInfo.processInfo.systemUptime
        defer {
            append(name.description, milliseconds: (ProcessInfo.processInfo.systemUptime - start) * 1000)
            signposter.endInterval(name, state)
        }
        return try body()
    }

    private func append(_ name: String, milliseconds: Double) {
        lock.lock()
        defer { lock.unlock() }
        if samples[name] == nil {
            samples[name] = []
            order.append(name)
        }
        samples[name]?.append(milliseconds)
        if let count = samples[name]?.count, count > Self.windowSize {
            samples[name]?.removeFirst()
        }
    }

    func startSampling() {
        lock.lock()
        samples = [:]
        order = []
        lastTick = ProcessInfo.processInfo.systemUptime
        ticksUntilDump = Self.ticksPerDump
        lock.unlock()

        stallTimer?.invalidate()
        // `.common` so ticks keep landing while a scroll drag holds the runloop
        // in tracking mode — that's exactly when stalls matter.
        let timer = Timer(timeInterval: Self.stallInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        stallTimer = timer
    }

    func stopSampling() {
        stallTimer?.invalidate()
        stallTimer = nil
        dump(label: "FINAL")
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        let gap = now - lastTick
        lastTick = now
        ticksUntilDump -= 1
        let shouldDump = ticksUntilDump <= 0
        if shouldDump { ticksUntilDump = Self.ticksPerDump }
        lock.unlock()

        append("runloop-stall", milliseconds: max(0, gap - Self.stallInterval) * 1000)
        if shouldDump { dump(label: "5s") }
    }

    private func dump(label: String) {
        lock.lock()
        let names = order
        let snapshot = samples
        lock.unlock()

        // One log line per metric, each carrying the ⏱ LATENCY marker: a
        // single multi-line NSLog looks right in the raw console but a filter
        // on the marker keeps only its first line and drops every row.
        let width = names.map(\.count).max() ?? 0
        for name in names {
            guard let values = snapshot[name], !values.isEmpty else { continue }
            let sorted = values.sorted()
            NSLog(
                "⏱ LATENCY [%@] %@  n=%-4ld p50=%6.1f  p90=%6.1f  max=%6.1f ms",
                label,
                name.padding(toLength: width, withPad: " ", startingAt: 0),
                values.count,
                percentile(sorted, 0.5),
                percentile(sorted, 0.9),
                sorted[sorted.count - 1]
            )
        }
    }

    private func percentile(_ sorted: [Double], _ fraction: Double) -> Double {
        let index = Int((Double(sorted.count - 1) * fraction).rounded())
        return sorted[index]
    }
}
#endif
