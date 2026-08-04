import KeyboardKit
import SwiftUI

/// Key metrics of the native Japanese iPad keyboard.
///
/// Measured off a 2× capture of the system Japanese (romaji) keyboard on an
/// 810pt-wide iPad, portrait, dark mode — see `scripts/keycap-diff.py` for the
/// capture protocol. Cell widths are fractions of the keyboard width so they
/// scale to other iPads. Native sizes every row independently, so the three
/// cell widths below really are different.
private enum NativePadMetrics {
    /// 12.5pt between caps, 6.25pt at the row edges.
    static let horizontalButtonInset: CGFloat = 6.25
    /// 55pt caps in a 64pt row.
    static let verticalButtonInset: CGFloat = 4.5

    private static let referenceWidth: CGFloat = 810

    static let topRowCell: CGFloat = 73.25 / referenceWidth
    static let homeRowCell: CGFloat = 72.75 / referenceWidth
    static let lowerRowCell: CGFloat = 71.75 / referenceWidth
    /// The home row starts ~0.42 of a cell in from the edge. This stagger is
    /// most of what makes the keyboard read as native.
    static let homeRowIndent: CGFloat = 30.75 / referenceWidth
    /// The dismiss cap spans one and a half cells.
    static let wideBottomCell: CGFloat = 1.5 * 71.75 / referenceWidth
}

extension KeyboardLayout {
    /// Reshape KeyboardKit's iPad layout into the native Japanese iPad keyboard.
    ///
    /// `KeyboardLayout.standard(for:)` hands us a desktop-shaped iPad keyboard:
    /// tab, caps lock, a second shift and a second mode key, rows that run edge
    /// to edge with no stagger, and function labels pinned to a cap corner. The
    /// native Japanese keyboard has none of that. Rather than build rows from
    /// scratch we keep KeyboardKit's own actions — they carry the current shift
    /// case and the field's return-key type — and re-arrange, re-size and
    /// re-label them.
    ///
    /// Only the alphabetic page is rebuilt. The number and symbol pages keep
    /// KeyboardKit's iPad shape until there's a native capture to measure them
    /// against; they still pick up the pad button insets.
    mutating func applyNativePadLayout(for keyboardType: Keyboard.KeyboardType) {
        if keyboardType == .alphabetic {
            applyNativePadAlphabeticRows()
        }
        applyNativePadButtonInsets()
    }

    private mutating func applyNativePadAlphabeticRows() {
        guard itemRows.count == 4 else { return }
        let topLetters = characterItems(inRow: 0)
        let homeLetters = characterItems(inRow: 1)
        let lowerLetters = characterItems(inRow: 2)
        guard topLetters.count >= 10, homeLetters.count >= 9, lowerLetters.count >= 7 else { return }
        guard let shift = firstItem(where: { if case .shift = $0 { return true }; return false }),
              let primary = firstItem(where: { if case .primary = $0 { return true }; return false })
        else { return }

        let height = topLetters[0].size.height
        func key(_ action: KeyboardAction, _ width: ItemWidth, secondary: String? = nil) -> Item {
            Item(
                action: action,
                secondaryAction: secondary.map { .character($0) },
                size: .init(width: width, height: height),
                alignment: .center
            )
        }

        let top = ItemWidth.percentage(NativePadMetrics.topRowCell)
        let home = ItemWidth.percentage(NativePadMetrics.homeRowCell)
        let lower = ItemWidth.percentage(NativePadMetrics.lowerRowCell)

        var topRow = zip(topLetters.prefix(10), Self.padTopRowSecondaries).map {
            key($0.action, top, secondary: $1)
        }
        topRow.append(key(.backspace, .available))

        var homeRow = [key(.none, .percentage(NativePadMetrics.homeRowIndent))]
        homeRow += zip(homeLetters.prefix(9), Self.padHomeRowSecondaries).map {
            key($0.action, home, secondary: $1)
        }
        homeRow.append(key(primary.action, .available))

        var lowerRow = [key(shift.action, lower)]
        lowerRow += zip(lowerLetters.prefix(7), Self.padLowerRowSecondaries).map {
            key($0.action, lower, secondary: $1)
        }
        lowerRow.append(key(.character("、"), lower, secondary: "!"))
        lowerRow.append(key(.character("。"), lower, secondary: "?"))
        // `-` is what the romaji buffer maps to ー; `QwertyKeyboardView`
        // relabels the cap.
        lowerRow.append(key(.character("-"), lower))
        // Native drops the right-hand shift and leaves the slot empty.
        lowerRow.append(key(.none, .available))

        // Native's bottom row is [.?123][🌐][🎤][空白][abc][⌨]. Dictation isn't
        // available to a keyboard extension, and `abc` has no destination while
        // Japanese is the only active input mode, so the spacebar absorbs both
        // slots. The four keys we keep sit at their native positions and widths.
        let bottomRow = [
            key(.keyboardType(.numeric), lower),
            key(.nextKeyboard, lower),
            key(.space, .available),
            key(.dismissKeyboard, .percentage(NativePadMetrics.wideBottomCell)),
        ]

        itemRows = [topRow, homeRow, lowerRow, bottomRow]
    }

    private mutating func applyNativePadButtonInsets() {
        let insets = EdgeInsets(
            top: NativePadMetrics.verticalButtonInset,
            leading: NativePadMetrics.horizontalButtonInset,
            bottom: NativePadMetrics.verticalButtonInset,
            trailing: NativePadMetrics.horizontalButtonInset
        )
        // Written in all three places because it isn't clear which one the iPad
        // renderer reads: setting the item insets alone (what the phone path
        // does, and what works there) left the pad caps at KeyboardKit's 5pt.
        deviceConfiguration.buttonInsets = insets
        idealItemInsets = insets
        for rowIndex in itemRows.indices {
            for itemIndex in itemRows[rowIndex].indices {
                itemRows[rowIndex][itemIndex].edgeInsets = insets
            }
        }
    }

    private func characterItems(inRow row: Int) -> [Item] {
        itemRows[row].filter {
            if case .character = $0.action { return true }
            return false
        }
    }

    private func firstItem(where matches: (KeyboardAction) -> Bool) -> Item? {
        for row in itemRows {
            if let item = row.first(where: { matches($0.action) }) { return item }
        }
        return nil
    }

    /// Swipe-down labels, read off the native capture. KeyboardKit's own iPad
    /// secondaries differ on six keys (`$ & ' "` on the home row, `% - + =` on
    /// the row below).
    private static let padTopRowSecondaries = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private static let padHomeRowSecondaries = ["@", "#", "¥", "-", "*", "(", ")", "「", "」"]
    private static let padLowerRowSecondaries = ["^_^", "%", "~", "…", "/", ";", ":"]
}
