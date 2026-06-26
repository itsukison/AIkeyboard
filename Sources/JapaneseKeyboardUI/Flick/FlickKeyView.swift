import JapaneseKeyboardCore
import SwiftUI

/// One flickable key in the 10-key kana layout. Renders the center label,
/// handles the flick gesture, shows the suggest popup on touch-down, and
/// commits the selected character on touch-up.
///
/// For the 小書き key, pass `onCenterTap` to handle the character-type
/// toggle (center tap cycles the last kana through small/dakuten forms).
/// When `onCenterTap` is non-nil and no flick direction is selected, the
/// center tap calls it instead of `onSelect`.
struct FlickKanaKeyView: View {
    let key: FlickKanaTable.FlickKey
    let onSelect: (String) -> Void
    let onCenterTap: (() -> Void)?
    let onTriggerHaptic: () -> Void

    @State private var isPressed = false
    @State private var selectedDirection: FlickKanaTable.FlickDirection? = nil

    private let thresholds: (left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) = (
        left: 24, top: 44, right: 64, bottom: 24
    )

    init(
        key: FlickKanaTable.FlickKey,
        onSelect: @escaping (String) -> Void,
        onCenterTap: (() -> Void)? = nil,
        onTriggerHaptic: @escaping () -> Void = {}
    ) {
        self.key = key
        self.onSelect = onSelect
        self.onCenterTap = onCenterTap
        self.onTriggerHaptic = onTriggerHaptic
    }

    var body: some View {
        keyLabel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(keyBackground)
            .overlay {
                if isPressed {
                    FlickSuggestView(key: key, selectedDirection: selectedDirection)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
            }
            .overlay {
                FlickGesture(
                    onTouchDown: {
                        isPressed = true
                        selectedDirection = nil
                        onTriggerHaptic()
                    },
                    onTouchMove: { dx, dy, _ in
                        selectedDirection = flickDirection(dx: dx, dy: dy)
                    },
                    onTouchUp: { dx, dy, _ in
                        let direction = flickDirection(dx: dx, dy: dy)
                        commit(direction)
                        isPressed = false
                        selectedDirection = nil
                    }
                )
            }
    }

    private var keyLabel: some View {
        Text(key.center)
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.primary)
    }

    private var keyBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(uiColor: isPressed ? .systemBackground : .secondarySystemBackground))
    }

    private func flickDirection(dx: CGFloat, dy: CGFloat) -> FlickKanaTable.FlickDirection? {
        let absX = abs(dx)
        let absY = abs(dy)

        if absX < 8 && absY < 8 {
            return nil
        }

        if absX > absY {
            if dx < 0 && absX >= thresholds.left {
                return key.left != nil ? .left : nil
            } else if dx > 0 && absX >= thresholds.right {
                return key.right != nil ? .right : nil
            }
        } else {
            if dy < 0 && absY >= thresholds.top {
                return key.top != nil ? .top : nil
            } else if dy > 0 && absY >= thresholds.bottom {
                return key.bottom != nil ? .bottom : nil
            }
        }
        return nil
    }

    private func commit(_ direction: FlickKanaTable.FlickDirection?) {
        if let direction, let character = key.character(for: direction) {
            onSelect(character)
        } else if let onCenterTap {
            onCenterTap()
        } else {
            onSelect(key.center)
        }
    }
}

/// A simple (non-flick) utility key: delete, space, return, tab switches.
/// Renders as a tappable button with the native iOS keyboard key style.
struct FlickUtilityKeyView: View {
    let label: AnyView
    let action: () -> Void
    let onTriggerHaptic: () -> Void
    let isWide: Bool

    @State private var isPressed = false

    init<Label: View>(
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void,
        onTriggerHaptic: @escaping () -> Void = {},
        isWide: Bool = false
    ) {
        self.label = AnyView(label())
        self.action = action
        self.onTriggerHaptic = onTriggerHaptic
        self.isWide = isWide
    }

    var body: some View {
        label
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(uiColor: isPressed ? .systemBackground : .secondarySystemBackground))
            )
            .overlay {
                FlickGesture(
                    onTouchDown: {
                        isPressed = true
                        onTriggerHaptic()
                    },
                    onTouchMove: { _, _, _ in },
                    onTouchUp: { _, _, _ in
                        action()
                        isPressed = false
                    }
                )
            }
    }
}
