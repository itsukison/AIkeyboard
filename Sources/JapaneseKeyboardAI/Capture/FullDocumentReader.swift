import Foundation

public enum FullDocumentReadResult: Equatable, Sendable {
    case snapshot(beforeCursor: String, afterCursor: String)
    case tooLong
    case failed
}

/// Stitches the whole document out of the truncated windows
/// `UITextDocumentProxy` exposes, by walking the cursor in window-sized hops.
///
/// iOS truncates `documentContextBeforeInput`/`AfterInput` to a window around
/// the cursor (cut at paragraph breaks and a host-defined length). Hops are
/// never larger than the currently visible window — hosts are only reliable
/// about positions they have reported. Proxy state updates asynchronously
/// after `adjustTextPosition`, hence the settle delay between hop and re-read.
///
/// Each re-read window is merged with overlap trimming, so a hop that
/// undershoots (host counts offsets differently than Swift `Character`s)
/// self-corrects instead of duplicating text. An empty window at a
/// non-boundary position means the adjacent character is a paragraph break, so
/// crossings are stitched as "\n". The document edge is detected by a
/// 1-character probe that leaves both windows unchanged.
///
/// Known degenerate cases (3+ consecutive newlines, text that repeats at
/// exactly the window length, hosts that ignore `adjustTextPosition`, or that
/// overshoot) end the walk early or fail the final verification, and the caller
/// falls back to the plain window capture — never worse than the status quo.
@MainActor
public struct FullDocumentReader {
    private let proxy: TextDocumentProxying
    private let maxCharacters: Int
    private let maxIterationsPerDirection: Int
    private let settle: () async -> Void

    public init(
        proxy: TextDocumentProxying,
        maxCharacters: Int = InputCapture.maxCharacters,
        maxIterationsPerDirection: Int = 40,
        settle: @escaping () async -> Void = { try? await Task.sleep(nanoseconds: 50_000_000) }
    ) {
        self.proxy = proxy
        self.maxCharacters = maxCharacters
        self.maxIterationsPerDirection = maxIterationsPerDirection
        self.settle = settle
    }

    public func read() async -> FullDocumentReadResult {
        // Walking would collapse an active selection; selection mode never
        // needs the walk in the first place.
        guard (proxy.selectedText ?? "").isEmpty else { return .failed }

        let backward = await walk(.backward)
        await restore(hopsToward: .forward, count: backward.moved)
        guard case .completed(let stitchedBefore) = backward.outcome else {
            return backward.outcome == .tooLong ? .tooLong : .failed
        }

        let forward = await walk(.forward)
        await restore(hopsToward: .backward, count: forward.moved)
        guard case .completed(let stitchedAfter) = forward.outcome else {
            return forward.outcome == .tooLong ? .tooLong : .failed
        }

        guard !Task.isCancelled else { return .failed }
        await settle()

        // The cursor must be back where it started: the stitched text has to
        // agree with the windows visible right now, or the walk drifted.
        let currentBefore = proxy.documentContextBeforeInput ?? ""
        let currentAfter = proxy.documentContextAfterInput ?? ""
        guard stitchedBefore.hasSuffix(currentBefore), stitchedAfter.hasPrefix(currentAfter) else {
            return .failed
        }
        guard stitchedBefore.count + stitchedAfter.count <= maxCharacters else {
            return .tooLong
        }
        return .snapshot(beforeCursor: stitchedBefore, afterCursor: stitchedAfter)
    }

    private enum Direction {
        case backward, forward
    }

    private enum WalkOutcome: Equatable {
        case completed(String)
        case tooLong
        case failed
    }

    /// Accumulates the document on one side of the cursor. Returns the hops
    /// actually issued so the caller can restore the cursor even on failure.
    private func walk(_ direction: Direction) async -> (outcome: WalkOutcome, moved: Int) {
        var stitched = ""
        var moved = 0
        var iterations = 0

        while true {
            if Task.isCancelled { return (.failed, moved) }
            if stitched.count > maxCharacters { return (.tooLong, moved) }
            if iterations >= maxIterationsPerDirection { return (.failed, moved) }
            iterations += 1

            let window = readWindow(direction)
            if window.isEmpty {
                // Paragraph boundary or document edge — probe one character.
                let signature = windowSignature()
                proxy.adjustTextPosition(byCharacterOffset: direction == .backward ? -1 : 1)
                await settle()
                if windowSignature() == signature {
                    // The host didn't move: document edge.
                    return (.completed(stitched), moved)
                }
                moved += 1
                // An empty window at a position the host could move past means
                // the crossed character is a paragraph break.
                stitched = direction == .backward ? "\n" + stitched : stitched + "\n"
                continue
            }

            let added = merge(window, into: &stitched, direction: direction)
            if added == 0 {
                // The window is entirely text we already have and the cursor is
                // not advancing — a host that ignores the hop. Cannot stitch
                // reliably; fail and let the caller fall back.
                return (.failed, moved)
            }
            proxy.adjustTextPosition(byCharacterOffset: direction == .backward ? -window.count : window.count)
            await settle()
            moved += window.count
        }
    }

    /// Best-effort cursor restore. Runs even after cancellation (`settle`
    /// swallows the cancellation error), because leaving the cursor
    /// mid-document is worse than a few unsettled hops.
    private func restore(hopsToward direction: Direction, count: Int) async {
        var remaining = count
        var iterations = 0
        while remaining > 0 && iterations < maxIterationsPerDirection * 2 {
            iterations += 1
            let window = readWindow(direction)
            let step = window.isEmpty ? 1 : min(remaining, window.count)
            proxy.adjustTextPosition(byCharacterOffset: direction == .backward ? -step : step)
            remaining -= step
            await settle()
        }
    }

    /// Merges a freshly read window into the accumulator, trimming the overlap
    /// a hop undershoot leaves behind. Returns the number of new characters
    /// actually added.
    private func merge(_ window: String, into stitched: inout String, direction: Direction) -> Int {
        switch direction {
        case .backward:
            // Drop the longest suffix of `window` that repeats the prefix of
            // what we already stitched.
            let overlap = overlapLength(suffixOf: window, prefixOf: stitched)
            let addition = String(window.dropLast(overlap))
            stitched = addition + stitched
            return addition.count
        case .forward:
            let overlap = overlapLength(suffixOf: stitched, prefixOf: window)
            let addition = String(window.dropFirst(overlap))
            stitched = stitched + addition
            return addition.count
        }
    }

    /// Largest k such that the last k characters of `a` equal the first k of `b`.
    private func overlapLength(suffixOf a: String, prefixOf b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let maxK = min(aChars.count, bChars.count)
        var k = maxK
        while k > 0 {
            if Array(aChars.suffix(k)) == Array(bChars.prefix(k)) { return k }
            k -= 1
        }
        return 0
    }

    private func windowSignature() -> String {
        // Combines both windows so the probe detects any cursor movement.
        (proxy.documentContextBeforeInput ?? "") + "\u{1F}" + (proxy.documentContextAfterInput ?? "")
    }

    private func readWindow(_ direction: Direction) -> String {
        switch direction {
        case .backward: return proxy.documentContextBeforeInput ?? ""
        case .forward: return proxy.documentContextAfterInput ?? ""
        }
    }
}
