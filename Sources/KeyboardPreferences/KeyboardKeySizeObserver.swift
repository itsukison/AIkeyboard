import Combine
import Foundation

/// Observable key-size preset shared between a hosting controller and the
/// keyboard views. The keyboard extension cannot rely on `@AppStorage` for
/// this value: iOS does not deliver KVO for App Group writes made by another
/// process (the container app), so the host re-reads via `refresh()` on every
/// keyboard appearance. In-process (the container's live preview), mutating
/// `preset` directly updates observers immediately.
public final class KeyboardKeySizeObserver: ObservableObject {
    @Published public var preset: KeyboardKeySizePreset

    private let defaults: UserDefaults?

    public init(defaults: UserDefaults? = KeyboardSettingsStore.sharedDefaults) {
        self.defaults = defaults
        self.preset = KeyboardSettingsStore.readKeyboardKeySizePreset(defaults: defaults)
    }

    public func refresh() {
        let stored = KeyboardSettingsStore.readKeyboardKeySizePreset(defaults: defaults)
        if stored != preset {
            preset = stored
        }
    }
}
