import JapaneseKeyboardCore
import SwiftUI
import UIKit

public struct CandidateBar: View {
    @ObservedObject var inputManager: InputManager
    let onSelect: (Candidate) -> Void
    let onSelectPrediction: (Candidate) -> Void
    let onTriggerHaptic: () -> Void
    let horizontalPadding: CGFloat
    let firstCandidateLeadingPadding: CGFloat

    public init(
        inputManager: InputManager,
        horizontalPadding: CGFloat = 6,
        firstCandidateLeadingPadding: CGFloat = 14,
        onTriggerHaptic: @escaping () -> Void = {},
        onSelect: @escaping (Candidate) -> Void,
        onSelectPrediction: @escaping (Candidate) -> Void = { _ in }
    ) {
        self.inputManager = inputManager
        self.horizontalPadding = horizontalPadding
        self.firstCandidateLeadingPadding = firstCandidateLeadingPadding
        self.onTriggerHaptic = onTriggerHaptic
        self.onSelect = onSelect
        self.onSelectPrediction = onSelectPrediction
    }

    public var body: some View {
        if !inputManager.candidates.isEmpty {
            candidateScroll
        } else if !inputManager.predictionSuggestions.isEmpty {
            predictionScroll
        }
    }

    private var candidateScroll: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        // Keyed by position, not Candidate.id: the id embeds the
                        // kana reading, so every keystroke re-identified all rows
                        // and tore down/recreated their UIKit tap surfaces — the
                        // churn that cancels an in-flight toolbar touch. Position
                        // keys update rows in place instead.
                        ForEach(Array(inputManager.candidates.enumerated()), id: \.offset) { index, candidate in
                            CandidateButton(
                                candidate: candidate,
                                isSelected: index == inputManager.selectedCandidateIndex,
                                leadingPadding: index == 0 ? firstCandidateLeadingPadding : 14,
                                onSelect: {
                                    onTriggerHaptic()
                                    onSelect(candidate)
                                }
                            )
                            .id(index)

                            if index < inputManager.candidates.count - 1 {
                                Divider()
                                    .frame(height: KeyboardChromeMetrics.toolbarDividerHeight - 4)
                                    .opacity(0.4)
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                }
                .onChange(of: inputManager.selectedCandidateIndex) { newIndex in
                    guard let i = newIndex else { return }
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(i, anchor: .center)
                    }
                }
            }

            Divider()
                .frame(height: KeyboardChromeMetrics.toolbarDividerHeight)
                .opacity(0.4)

            // Native ∧ expander: opens the full-candidate grid. Lives outside
            // the scroll so it stays pinned at the trailing edge. Fires via the
            // same UIKit tap surface as the candidate cells: a SwiftUI Button
            // here drops presses in the keyboard's hosted toolbar on iOS 26
            // (same failure the cells had before CandidateTapSurface).
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: KeyboardChromeMetrics.toolbarHeight)
                .contentShape(Rectangle())
                .overlay {
                    CandidateTapSurface(label: "chevron", onTap: {
                        NSLog("🔽 chevron tap surface fired")
                        onTriggerHaptic()
                        inputManager.expandCandidateList()
                    })
                }
        }
        .frame(height: KeyboardChromeMetrics.toolbarHeight)
    }

    private var predictionScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Position-keyed for the same reason as the candidate rows above.
                ForEach(Array(inputManager.predictionSuggestions.enumerated()), id: \.offset) { index, candidate in
                    CandidateButton(
                        candidate: candidate,
                        isSelected: false,
                        leadingPadding: index == 0 ? firstCandidateLeadingPadding : 14,
                        onSelect: {
                            onTriggerHaptic()
                            onSelectPrediction(candidate)
                        }
                    )

                    if index < inputManager.predictionSuggestions.count - 1 {
                        Divider()
                            .frame(height: KeyboardChromeMetrics.toolbarDividerHeight - 4)
                            .opacity(0.4)
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
        .frame(height: KeyboardChromeMetrics.toolbarHeight)
    }
}

private struct CandidateButton: View {
    let candidate: Candidate
    let isSelected: Bool
    let leadingPadding: CGFloat
    let onSelect: () -> Void

    var body: some View {
        Text(candidate.text)
            .font(.system(size: 18))
            .lineLimit(1)
            .padding(.leading, leadingPadding)
            .padding(.trailing, 14)
            .frame(height: KeyboardChromeMetrics.candidateTextHeight)
            .foregroundStyle(.primary)
            .background(isSelected ? Color(uiColor: .systemBackground) : Color.clear)
            .cornerRadius(6)
            .frame(height: KeyboardChromeMetrics.toolbarHeight)
            .contentShape(Rectangle())
            .overlay {
                CandidateTapSurface(onTap: onSelect)
            }
    }
}

struct CandidateTapSurface: UIViewRepresentable {
    var label: String = "cell"
    let onTap: () -> Void

    func makeUIView(context: Context) -> CandidateTapSurfaceView {
        CandidateTapSurfaceView(label: label, onTap: onTap)
    }

    func updateUIView(_ view: CandidateTapSurfaceView, context: Context) {
        view.onTap = onTap
    }
}

final class CandidateTapSurfaceView: UIView {
    var onTap: () -> Void
    private let label: String
    private var touchStart: CGPoint?

    /// Taps are recognized from raw touch events, not a UITapGestureRecognizer:
    /// in the keyboard's hosted toolbar, recognizer arbitration (the same
    /// iOS 26 behavior that drops SwiftUI Button presses there) can silently
    /// fail the tap even though the touch was delivered to this view. Raw
    /// touchesEnded only misses when UIKit cancels the touch outright — e.g.
    /// the candidate scroll's pan claiming a swipe — which is exactly when a
    /// tap must not fire. Movement beyond this slop reads as a swipe.
    private static let maximumTapMovement: CGFloat = 12

    init(label: String = "cell", onTap: @escaping () -> Void) {
        self.label = label
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let point = touches.first?.location(in: self) else { return }
        touchSequenceBegan(at: point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let point = touches.first?.location(in: self) else { return }
        touchSequenceEnded(at: point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        touchSequenceCancelled()
    }

    // Temporary diagnostics for the unresponsive-expander investigation:
    // view attach/detach around presses.
    override func willMove(toWindow newWindow: UIWindow?) {
        NSLog("%@", "🪟 [\(label)] \(newWindow == nil ? "DETACHED from window" : "attached to window")")
        super.willMove(toWindow: newWindow)
    }

    // Internal (not private) so the touch-up decision is unit-testable —
    // UITouch instances can't be constructed in tests.
    func touchSequenceBegan(at point: CGPoint) {
        touchStart = point
        NSLog("%@", "🫳 [\(label)] touches began at \(point)")
    }

    func touchSequenceEnded(at point: CGPoint) {
        defer { touchStart = nil }
        guard let start = touchStart else {
            NSLog("%@", "🫳 [\(label)] touches ended with no began")
            return
        }
        let dx = point.x - start.x
        let dy = point.y - start.y
        NSLog("%@", String(format: "🫳 [\(label)] touches ended moved=(%.1f, %.1f)", dx, dy))
        guard hypot(dx, dy) <= Self.maximumTapMovement else { return }
        onTap()
    }

    func touchSequenceCancelled() {
        NSLog("%@", "🛑 [\(label)] touches CANCELLED")
        touchStart = nil
    }
}
