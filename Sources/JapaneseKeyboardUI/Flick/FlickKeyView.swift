import JapaneseKeyboardCore
import SwiftUI
import UIKit

private struct FlickKeyCapInsetEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var flickKeyCapInset: CGFloat {
        get { self[FlickKeyCapInsetEnvironmentKey.self] }
        set { self[FlickKeyCapInsetEnvironmentKey.self] = newValue }
    }
}

/// One flickable key in the 10-key kana layout. Renders the center label,
/// handles the flick gesture, shows a compact preview for quick flicks or the
/// full guide after a hold, and commits the selected character on touch-up.
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

    @State private var interaction = FlickInteractionState()
    @State private var guideTimer: Timer?
    @Environment(\.flickKeyCapInset) private var keyCapInset

    private let guideDelay: TimeInterval = 0.30
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
        ZStack {
            keyBackground
                .padding(keyCapInset)
                .opacity(interaction.hidesBaseKey ? 0 : 1)
            keyLabel
                .opacity(interaction.hidesBaseKey ? 0 : 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Publish the pressed key + its frame so FlickKeyboardView can draw
        // the flick cross in one top-level overlay (never clipped by other
        // keys or the rows below).
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: FlickPopupKey.self,
                    value: interaction.showsPopup
                        ? FlickPopup(
                            key: key,
                            phase: interaction.phase,
                            frame: geo.frame(in: .named(FlickPopupKey.space)).insetBy(
                                dx: keyCapInset,
                                dy: keyCapInset
                            )
                        )
                        : nil
                )
            }
        )
        .overlay {
            FlickGesture(
                onTouchDown: {
                    interaction.touchDown()
                    scheduleGuide()
                    onTriggerHaptic()
                },
                onTouchMove: { dx, dy, _ in
                    if interaction.move(to: flickDirection(dx: dx, dy: dy)) {
                        cancelGuide()
                    }
                },
                onTouchUp: { dx, dy, _ in
                    let direction = flickDirection(dx: dx, dy: dy)
                    resetInteraction()
                    commit(direction)
                },
                onTouchCancel: {
                    resetInteraction()
                }
            )
        }
        .onDisappear {
            resetInteraction()
        }
    }

    private var keyLabel: some View {
        // Single glyphs (kana, digits) are large like native; multi-character
        // faces (ABC, @#/&_, 小ﾞﾟ) are smaller so they don't look oversized.
        Text(key.face)
            .font(.system(size: key.face.count > 1 ? 17 : 22, weight: .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.primary)
    }

    private var keyBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(interaction.isPressed ? FlickKeyPalette.kanaKeyPressed : FlickKeyPalette.kanaKey)
            // Subtle bottom-only shadow, like the native key cap.
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }

    private func scheduleGuide() {
        cancelGuide()
        let timer = Timer(timeInterval: guideDelay, repeats: false) { _ in
            MainActor.assumeIsolated {
                guideTimer = nil
                interaction.longPressElapsed()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        guideTimer = timer
    }

    private func cancelGuide() {
        guideTimer?.invalidate()
        guideTimer = nil
    }

    private func resetInteraction() {
        cancelGuide()
        interaction.reset()
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
    /// When true (the delete key), the action fires on touch-down and then
    /// repeats while held, like the native iOS keyboard. Other utility keys
    /// fire once on touch-up.
    let autoRepeat: Bool

    @State private var isPressed = false
    @State private var repeatTimer: Timer?
    @Environment(\.flickKeyCapInset) private var keyCapInset

    init<Label: View>(
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void,
        onTriggerHaptic: @escaping () -> Void = {},
        autoRepeat: Bool = false
    ) {
        self.label = AnyView(label())
        self.action = action
        self.onTriggerHaptic = onTriggerHaptic
        self.autoRepeat = autoRepeat
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(isPressed ? FlickKeyPalette.functionKeyPressed : FlickKeyPalette.functionKey)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
                .padding(keyCapInset)
            label
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            FlickGesture(
                onTouchDown: {
                    isPressed = true
                    onTriggerHaptic()
                    if autoRepeat {
                        action()
                        startRepeat()
                    }
                },
                onTouchMove: { _, _, _ in },
                onTouchUp: { _, _, _ in
                    stopRepeat()
                    if !autoRepeat {
                        action()
                    }
                    isPressed = false
                },
                onTouchCancel: {
                    stopRepeat()
                    isPressed = false
                }
            )
        }
    }

    // Native cadence: ~0.45 s hold before the first repeat, then ~0.09 s steps.
    // The timers are scheduled on RunLoop.main, so their callbacks always fire
    // on the main actor — assume that isolation to touch the view's state.
    private func startRepeat() {
        let delay = Timer(timeInterval: 0.45, repeats: false) { _ in
            MainActor.assumeIsolated {
                let fast = Timer(timeInterval: 0.09, repeats: true) { _ in
                    MainActor.assumeIsolated {
                        onTriggerHaptic()
                        action()
                    }
                }
                RunLoop.main.add(fast, forMode: .common)
                repeatTimer = fast
            }
        }
        RunLoop.main.add(delay, forMode: .common)
        repeatTimer = delay
    }

    private func stopRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

struct FlickInteractionState: Equatable {
    private(set) var isPressed = false
    private(set) var phase: FlickPopupPhase = .hidden

    var showsPopup: Bool {
        phase != .hidden
    }

    var hidesBaseKey: Bool {
        if case .quick(let direction) = phase {
            return direction != nil
        }
        return false
    }

    mutating func touchDown() {
        isPressed = true
        phase = .hidden
    }

    @discardableResult
    mutating func move(to direction: FlickKanaTable.FlickDirection?) -> Bool {
        guard isPressed else { return false }
        switch phase {
        case .hidden:
            guard let direction else { return false }
            phase = .quick(direction)
            return true
        case .quick:
            phase = .quick(direction)
        case .guide:
            phase = .guide(direction)
        }
        return false
    }

    mutating func longPressElapsed() {
        guard isPressed, phase == .hidden else { return }
        phase = .guide(nil)
    }

    mutating func reset() {
        isPressed = false
        phase = .hidden
    }
}

/// Native iOS keyboard surface colors, replicated for the hand-built flick grid.
/// KeyboardKit paints these automatically for the QWERTY layout; the flick grid
/// is pure SwiftUI, so it needs its own tokens. Values approximate the system
/// keyboard — lighter "input" (kana) keys, darker function keys — in both
/// light and dark mode.
enum FlickKeyPalette {
    static let kanaKey = dynamic(light: .white,
                                 dark: UIColor(white: 0.42, alpha: 1))
    static let kanaKeyPressed = dynamic(light: UIColor(white: 0.90, alpha: 1),
                                        dark: UIColor(white: 0.32, alpha: 1))
    static let functionKey = dynamic(light: UIColor(red: 0.67, green: 0.69, blue: 0.72, alpha: 1),
                                     dark: UIColor(white: 0.29, alpha: 1))
    static let functionKeyPressed = dynamic(light: .white,
                                            dark: UIColor(white: 0.42, alpha: 1))

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
