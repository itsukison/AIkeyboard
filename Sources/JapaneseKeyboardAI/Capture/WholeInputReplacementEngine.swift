import Foundation

public enum ReplacementError: Error, Equatable {
    case contextChanged
    case unsupportedCaptureMode
}

public enum WholeInputReplacementEngine {
    @MainActor
    public static func replace(
        capture: WholeInputCapture,
        with replacement: String,
        proxy: TextDocumentProxying
    ) throws {
        switch capture.mode {
        case .selection:
            try replaceSelection(capture: capture, with: replacement, proxy: proxy)
            return
        case .fullDocument:
            // Full-document replacement needs the async chunked engine.
            throw ReplacementError.unsupportedCaptureMode
        case .wholeInput:
            break
        }

        let currentTarget = (proxy.documentContextBeforeInput ?? "")
            + (proxy.selectedText ?? "")
            + (proxy.documentContextAfterInput ?? "")
        guard currentTarget == capture.targetText else {
            throw ReplacementError.contextChanged
        }

        if capture.moveToEndCharacterCount > 0 {
            proxy.adjustTextPosition(byCharacterOffset: capture.moveToEndCharacterCount)
        }

        for _ in 0..<capture.deleteBackwardCharacterCount {
            proxy.deleteBackward()
        }

        proxy.insertText(replacement)
    }

    /// Replaces a full-document capture. Async because the cursor must be
    /// moved to the document end in window-sized hops (hosts are unreliable
    /// beyond the visible window, and the proxy needs a settle after each
    /// hop). Validation is suffix/prefix-based: at replace time the proxy
    /// only shows the truncated window, so strict equality is impossible.
    @MainActor
    public static func replaceFullDocument(
        capture: WholeInputCapture,
        with replacement: String,
        proxy: TextDocumentProxying,
        settle: () async -> Void = { try? await Task.sleep(nanoseconds: 50_000_000) }
    ) async throws {
        guard capture.mode == .fullDocument else {
            throw ReplacementError.unsupportedCaptureMode
        }
        guard (proxy.selectedText ?? "").isEmpty,
              capture.beforeCursor.hasSuffix(proxy.documentContextBeforeInput ?? ""),
              capture.afterCursor.hasPrefix(proxy.documentContextAfterInput ?? "") else {
            throw ReplacementError.contextChanged
        }

        var remaining = capture.moveToEndCharacterCount
        var iterations = 0
        let maxIterations = max(80, capture.moveToEndCharacterCount)
        while remaining > 0 {
            guard iterations < maxIterations else {
                throw ReplacementError.contextChanged
            }
            iterations += 1
            let window = proxy.documentContextAfterInput ?? ""
            let step = window.isEmpty ? 1 : min(remaining, window.count)
            proxy.adjustTextPosition(byCharacterOffset: step)
            remaining -= step
            await settle()
        }

        for _ in 0..<capture.deleteBackwardCharacterCount {
            proxy.deleteBackward()
        }

        proxy.insertText(replacement)
    }

    /// Replaces only the captured selection. `insertText` natively replaces an
    /// active selection, so validation requires the selection to still be
    /// present — a cleared selection would make `insertText` insert at the
    /// cursor instead.
    @MainActor
    private static func replaceSelection(
        capture: WholeInputCapture,
        with replacement: String,
        proxy: TextDocumentProxying
    ) throws {
        guard (proxy.documentContextBeforeInput ?? "") == capture.beforeCursor,
              (proxy.selectedText ?? "") == capture.selectedText,
              (proxy.documentContextAfterInput ?? "") == capture.afterCursor else {
            throw ReplacementError.contextChanged
        }
        proxy.insertText(replacement)
    }
}
