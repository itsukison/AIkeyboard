import JapaneseKeyboardCore
import JapaneseKeyboardUI
import KeyboardKit
import KeyboardPreferences
import SwiftUI

/// Live key-size preview: renders the real keyboard views — the same SwiftUI
/// code the extension shows — directly in the container, presented as a
/// bottom overlay that slides up like a keyboard. Deliberately NOT a text
/// field + `inputView`: focusing a field starts the system text-input session,
/// whose XPC ping of the (possibly debugger-killed) keyboard extension process
/// crashed the app (`_NSXPCDistantObject ___nsx_pingHost:`). A plain overlay
/// never touches the input system. Keys press and flick like the real thing
/// but never insert text (the input callbacks are no-ops).
struct KeyboardSizePreviewPane: View {
    let style: KeyboardPreferences.KeyboardStyle
    let keySizeObserver: KeyboardKeySizeObserver

    @StateObject private var engines = PreviewEngines()

    var body: some View {
        keyboard
            // Injects KeyboardKit's context environment objects (FontContext
            // etc.) that the extension's controller provides implicitly —
            // without this, KeyboardKit views fatal-error in-app.
            .keyboardState(engines.state)
            // Matches the real views' intrinsic totals: flick = toolbar 46 +
            // grid 225 (11 top + 4×48 rows + 3×6 gaps + 4 bottom), QWERTY =
            // toolbar 46 + 4 rows × 54.
            .frame(height: style == .japaneseFlick ? 271 : 262)
            .frame(maxWidth: .infinity)
            .background {
                Keyboard.Background.standard.ignoresSafeArea(edges: .bottom)
            }
    }

    @ViewBuilder private var keyboard: some View {
        switch style {
        case .japaneseFlick:
            FlickKeyboardView(
                inputManager: engines.flickInputManager,
                keySizeObserver: keySizeObserver,
                onSelectCandidate: { _ in }
            )
        default:
            QwertyKeyboardView(
                services: engines.services,
                keyboardContext: engines.state.keyboardContext,
                inputManager: engines.qwertyInputManager,
                keySizeObserver: keySizeObserver,
                onSelectCandidate: { _ in }
            )
        }
    }
}

/// Keeps the preview's stub input managers and KeyboardKit state alive across
/// body re-evaluations. Lazy so only the active style's objects are created.
@MainActor
private final class PreviewEngines: ObservableObject {
    lazy var flickInputManager = InputManager(buffer: KanaInputBuffer())
    lazy var qwertyInputManager = InputManager()
    lazy var state = Keyboard.State()
    lazy var services = Keyboard.Services(state: state)
}
