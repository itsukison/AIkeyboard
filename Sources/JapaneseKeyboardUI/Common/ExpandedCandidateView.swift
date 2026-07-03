import JapaneseKeyboardCore
import KeyboardKit
import SwiftUI
import UIKit

/// Full-area "show all candidates" grid — the native iOS ∧ expander. Renders
/// only while `inputManager.isCandidateListExpanded`; otherwise it is an empty
/// view that takes no space and blocks nothing. Tapping a candidate commits it
/// (and the list auto-collapses once composition resets); the ∨ chevron
/// collapses it.
public struct ExpandedCandidateView: View {
    @ObservedObject var inputManager: InputManager
    let onSelect: (Candidate) -> Void
    let onTriggerHaptic: () -> Void

    private static let controlRailWidth: CGFloat = 44
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
            HStack(spacing: 0) {
                grid
                controlRail
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.keyboardBackground)
        }
    }

    private var controlRail: some View {
        VStack(spacing: 0) {
            Button {
                onTriggerHaptic()
                inputManager.collapseCandidateList()
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: Self.controlRailWidth,
                        height: KeyboardChromeMetrics.toolbarHeight
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .frame(width: Self.controlRailWidth)
    }

    private var grid: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    let rows = Self.packRows(inputManager.candidates, width: geo.size.width)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(row) { candidate in
                                cell(candidate)
                            }
                            Spacer(minLength: 0)
                        }
                        Divider().opacity(0.4)
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

    private static func packRows(_ candidates: [Candidate], width: CGFloat) -> [[Candidate]] {
        guard width > 0 else { return candidates.map { [$0] } }
        var rows: [[Candidate]] = []
        var current: [Candidate] = []
        var currentWidth: CGFloat = 0
        for candidate in candidates {
            let textWidth = (candidate.text as NSString)
                .size(withAttributes: [.font: font]).width
            let cellWidth = min(textWidth + cellHorizontalPadding * 2, width)
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
