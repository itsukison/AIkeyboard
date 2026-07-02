import JapaneseKeyboardCore
import SwiftUI
import UIKit

/// Full-area "show all candidates" grid — the native iOS ∧ expander. Renders
/// only while `inputManager.isCandidateListExpanded`; otherwise it is an empty
/// view that takes no space and blocks nothing. Candidates are greedily packed
/// left-to-right and wrapped to new rows (variable-width cells, ragged right
/// edge) in the same ranked order as the candidate bar, matching the native
/// keyboard's expanded list. Tapping a candidate commits it (and the list
/// auto-collapses once composition resets); the ∨ chevron collapses it.
public struct ExpandedCandidateView: View {
    @ObservedObject var inputManager: InputManager
    let onSelect: (Candidate) -> Void
    let onTriggerHaptic: () -> Void

    private static let font = UIFont.systemFont(ofSize: 18)
    private static let cellHorizontalPadding: CGFloat = 14

    public init(
        inputManager: InputManager,
        onSelect: @escaping (Candidate) -> Void,
        onTriggerHaptic: @escaping () -> Void = {}
    ) {
        self.inputManager = inputManager
        self.onSelect = onSelect
        self.onTriggerHaptic = onTriggerHaptic
    }

    public var body: some View {
        if inputManager.isCandidateListExpanded, !inputManager.candidates.isEmpty {
            VStack(spacing: 0) {
                header
                grid
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground))
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer()
            Button {
                onTriggerHaptic()
                inputManager.collapseCandidateList()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: KeyboardChromeMetrics.toolbarHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(height: KeyboardChromeMetrics.toolbarHeight)
    }

    private var grid: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    let rows = Self.packRows(inputManager.candidates, width: geo.size.width)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Divider().opacity(0.4)
                        HStack(spacing: 0) {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, candidate in
                                cell(candidate)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    private func cell(_ candidate: Candidate) -> some View {
        Text(candidate.text)
            .font(.system(size: 18))
            .lineLimit(1)
            .foregroundStyle(.primary)
            .padding(.horizontal, Self.cellHorizontalPadding)
            .frame(height: KeyboardChromeMetrics.toolbarHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                onTriggerHaptic()
                onSelect(candidate)
            }
    }

    /// Greedy width-packing: append each candidate to the current row until the
    /// next cell would overflow `width`, then wrap. Mirrors azooKey's expanded
    /// view (measured cell widths, not a fixed column count).
    private static func packRows(_ candidates: [Candidate], width: CGFloat) -> [[Candidate]] {
        guard width > 0 else { return candidates.map { [$0] } }
        var rows: [[Candidate]] = []
        var current: [Candidate] = []
        var currentWidth: CGFloat = 0
        for candidate in candidates {
            let textWidth = (candidate.text as NSString)
                .size(withAttributes: [.font: font]).width
            let cellWidth = textWidth + cellHorizontalPadding * 2
            if !current.isEmpty, currentWidth + cellWidth > width {
                rows.append(current)
                current = []
                currentWidth = 0
            }
            current.append(candidate)
            currentWidth += cellWidth
        }
        if !current.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
