import JapaneseKeyboardCore
import SwiftUI

public struct CandidateBar: View {
    @ObservedObject var inputManager: InputManager
    let onSelect: (Candidate) -> Void
    let horizontalPadding: CGFloat
    let firstCandidateLeadingPadding: CGFloat

    public init(
        inputManager: InputManager,
        horizontalPadding: CGFloat = 6,
        firstCandidateLeadingPadding: CGFloat = 14,
        onSelect: @escaping (Candidate) -> Void
    ) {
        self.inputManager = inputManager
        self.horizontalPadding = horizontalPadding
        self.firstCandidateLeadingPadding = firstCandidateLeadingPadding
        self.onSelect = onSelect
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(inputManager.candidates.enumerated()), id: \.element.id) { index, candidate in
                        Button {
                            onSelect(candidate)
                        } label: {
                            Text(candidate.text)
                                .font(.system(size: 18))
                                .lineLimit(1)
                                .padding(.leading, index == 0 ? firstCandidateLeadingPadding : 14)
                                .padding(.trailing, 14)
                                .frame(height: KeyboardChromeMetrics.candidateTextHeight)
                                .foregroundStyle(.primary)
                                .background(
                                    index == inputManager.selectedCandidateIndex
                                        ? Color(uiColor: .systemBackground)
                                        : Color.clear
                                )
                                .cornerRadius(6)
                                .frame(height: KeyboardChromeMetrics.toolbarHeight)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
            .frame(height: KeyboardChromeMetrics.toolbarHeight)
            .onChange(of: inputManager.selectedCandidateIndex) { newIndex in
                guard let i = newIndex else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(i, anchor: .center)
                }
            }
        }
    }
}
