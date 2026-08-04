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

/// Drives a key's characters straight into the composing buffer while the
/// finger is still down, which is how the native kana keyboard behaves: the
/// character appears on touch-down and swaps as the finger moves, so typing
/// never waits for a release. Only the kana keys use it — the ABC/123 pages
/// insert into the host document and the 小書き key's center tap mutates the
/// previous kana, and neither can be provisional.
struct FlickLiveInput {
    let begin: () -> Void
    let update: (FlickKanaTable.FlickDirection?) -> Void
    let end: () -> Void
    let cancel: () -> Void
}

/// One flickable key in the 10-key kana layout. Renders the center label,
/// handles the flick gesture, shows the enlarged cap on touch-down (swapping
/// to the flicked character, or to the full guide after a hold), and delivers
/// the character through `live` when set, otherwise on touch-up.
///
/// For the 小書き key, pass `onCenterTap` to handle the character-type
/// toggle (center tap cycles the last kana through small/dakuten forms).
/// When `onCenterTap` is non-nil and no flick direction is selected, the
/// center tap calls it instead of `onSelect`.
struct FlickKanaKeyView: View {
    let key: FlickKanaTable.FlickKey
    let onSelect: (String) -> Void
    let onCenterTap: (() -> Void)?
    let live: FlickLiveInput?
    let onTriggerHaptic: () -> Void

    @State private var interaction = FlickInteractionState()
    @State private var guideTimer: Timer?
    @Environment(\.flickKeyCapInset) private var keyCapInset

    private let guideDelay: TimeInterval = 0.30

    init(
        key: FlickKanaTable.FlickKey,
        onSelect: @escaping (String) -> Void = { _ in },
        onCenterTap: (() -> Void)? = nil,
        live: FlickLiveInput? = nil,
        onTriggerHaptic: @escaping () -> Void = {}
    ) {
        self.key = key
        self.onSelect = onSelect
        self.onCenterTap = onCenterTap
        self.live = live
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
                    live?.begin()
                },
                onTouchMove: { dx, dy, _ in
                    track(dx: dx, dy: dy)
                },
                onTouchUp: { dx, dy, _ in
                    let direction = track(dx: dx, dy: dy)
                    let didFlick = max(abs(dx), abs(dy)) >= FlickDirectionResolver.threshold
                    resetInteraction()
                    if let live {
                        live.end()
                    } else {
                        commit(direction: direction, didFlick: didFlick)
                    }
                },
                onTouchCancel: {
                    resetInteraction()
                    live?.cancel()
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

    /// Resolve the drag, update what the popup shows, and push the character
    /// under the finger into the composition. Deduped on the resolved direction
    /// so a stationary finger costs nothing per touch-move event.
    @discardableResult
    private func track(dx: CGFloat, dy: CGFloat) -> FlickKanaTable.FlickDirection? {
        let direction = FlickDirectionResolver.resolve(
            dx: dx,
            dy: dy,
            latched: interaction.direction,
            key: key
        )
        guard direction != interaction.direction else { return direction }
        interaction.move(to: direction)
        if direction != nil {
            cancelGuide()
        }
        live?.update(direction)
        return direction
    }

    private func commit(direction: FlickKanaTable.FlickDirection?, didFlick: Bool) {
        if let direction, let character = key.character(for: direction) {
            onSelect(character)
            return
        }
        if didFlick {
            // Native commits the center character when a flick lands on a
            // direction the key doesn't map. The 小書き key's center is a cap
            // label whose tap mutates the previous kana, so a stray flick there
            // must do nothing rather than fire the toggle.
            if key.centerIsInsertable {
                onSelect(key.center)
            }
            return
        }
        if let onCenterTap {
            onCenterTap()
        } else {
            onSelect(key.center)
        }
    }
}

/// Resolves a drag vector to a flick direction the way the native keyboard
/// does: one threshold for all four directions, small enough that the 45°
/// cone — not the distance — is what rejects a flick. Distance stops binding
/// once a flick is longer than `threshold * √2` (25 pt, the cone edge), which
/// every deliberate flick is.
///
/// The per-direction thresholds this replaced (left 24, top 44, right 64,
/// bottom 24 pt) made 上 and 右 unreachable at normal flick lengths, so those
/// flicks silently fell back to the center character.
enum FlickDirectionResolver {
    static let threshold: CGFloat = 18
    /// Hysteresis: a latched direction survives until the finger comes back
    /// inside this radius, so the small reverse slide a finger makes on
    /// lift-off can't drop the flick back to the center character.
    static let releaseRadius: CGFloat = 10

    static func resolve(
        dx: CGFloat,
        dy: CGFloat,
        latched: FlickKanaTable.FlickDirection?,
        key: FlickKanaTable.FlickKey
    ) -> FlickKanaTable.FlickDirection? {
        let absX = abs(dx)
        let absY = abs(dy)
        let travel = max(absX, absY)

        if latched != nil && travel < releaseRadius { return nil }
        guard travel >= threshold else { return latched }

        let direction: FlickKanaTable.FlickDirection = absX > absY
            ? (dx < 0 ? .left : .right)
            : (dy < 0 ? .top : .bottom)
        return key.character(for: direction) != nil ? direction : nil
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

    /// The direction under the finger — what the popup is showing, and so what
    /// touch-up commits. Display and commit read the same value, they are never
    /// computed separately.
    var direction: FlickKanaTable.FlickDirection? {
        switch phase {
        case .hidden: return nil
        case .quick(let direction), .guide(let direction): return direction
        }
    }

    /// Only the directional preview needs the key hidden: it is drawn offset
    /// towards the flick, so the original cap would still show beside it. The
    /// touch-down cap sits centred and is larger than the key, so it covers it.
    /// (Only one popup renders at a time — see `FlickPopupKey.reduce` — so a
    /// second finger during rollover must not blank its own key.)
    var hidesBaseKey: Bool {
        if case .quick(let direction) = phase {
            return direction != nil
        }
        return false
    }

    /// Native puts the enlarged center cap up the instant the finger lands; the
    /// full flick guide follows only if the press turns into a hold.
    mutating func touchDown() {
        isPressed = true
        phase = .quick(nil)
    }

    mutating func move(to direction: FlickKanaTable.FlickDirection?) {
        guard isPressed else { return }
        switch phase {
        case .hidden:
            break
        case .quick:
            phase = .quick(direction)
        case .guide:
            phase = .guide(direction)
        }
    }

    mutating func longPressElapsed() {
        guard isPressed, phase == .quick(nil) else { return }
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
