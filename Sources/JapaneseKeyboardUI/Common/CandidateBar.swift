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
                        ForEach(Array(inputManager.candidates.enumerated()), id: \.element.id) { index, candidate in
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
            // the scroll so it stays pinned at the trailing edge.
            Button {
                onTriggerHaptic()
                inputManager.expandCandidateList()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: KeyboardChromeMetrics.toolbarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: KeyboardChromeMetrics.toolbarHeight)
    }

    private var predictionScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(inputManager.predictionSuggestions.enumerated()), id: \.element.id) { index, candidate in
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

private struct CandidateTapSurface: UIViewRepresentable {
    let onTap: () -> Void

    func makeUIView(context: Context) -> CandidateTapSurfaceView {
        CandidateTapSurfaceView(onTap: onTap)
    }

    func updateUIView(_ view: CandidateTapSurfaceView, context: Context) {
        view.onTap = onTap
    }
}

final class CandidateTapSurfaceView: UIView, UIGestureRecognizerDelegate {
    var onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = .clear

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        addGestureRecognizer(recognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer is UIPanGestureRecognizer
    }

    @objc private func handleTap() {
        onTap()
    }
}
