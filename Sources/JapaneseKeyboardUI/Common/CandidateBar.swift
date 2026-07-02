import JapaneseKeyboardCore
import SwiftUI

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
                    .frame(width: 40, height: KeyboardChromeMetrics.toolbarHeight)
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

/// A candidate cell that registers a tap without blocking horizontal scrolling.
/// A `Button` / `.buttonStyle(.plain)` inside a `ScrollView` has a finicky
/// press-state machine that drops the first tap, while a `DragGesture` (even via
/// `.simultaneousGesture`) wins the touch immediately and kills scrolling. A
/// plain tap gesture does neither: it fires only on a genuine press-and-release
/// and leaves the scroll view's pan untouched.
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
            .onTapGesture { onSelect() }
    }
}
