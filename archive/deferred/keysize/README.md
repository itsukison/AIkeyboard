# Deferred: keyboard key-size setting

Parked 2026-07-03. Not compiled (the build only includes `iOS/`, `Sources/`,
`iOS/Shared` — not `archive/deferred/`).

## Why deferred
The settings UI shipped a live keyboard preview + size slider, but on device:
- the preview pane overlapped the tab bar and had no candidate toolbar (looked broken);
- the size change was imperceptible — the preset only adjusts the key **cap
  inset by ±4pt** (`KeyboardKeySizePreset.keyCapInsetAdjustment`), not the actual
  key/row height, so the keyboard looked identical across presets.

Not a priority, so the UI is parked until it's worth doing properly.

## What's still live (dormant, renders at `.standard`)
Left in the compiled sources so re-enabling is UI-only:
- `Sources/KeyboardPreferences/KeyboardKeySizeObserver.swift`
- `KeyboardKeySizePreset` + `read/writeKeyboardKeySizePreset` in `KeyboardSettingsStore.swift`
- `keySizeObserver` param on `FlickKeyboardView` / `QwertyKeyboardView` (applies the inset)
- `keySizeObserver.refresh()` in `KeyboardViewController.viewWillAppear`
- `KeyboardSettingsStoreTests` coverage for the preset + observer

Because nothing writes a non-standard preset while the UI is gone, the keyboard
always renders at `.standard`.

## Files here
- `KeyboardSizePreviewPane.swift` — the in-app live preview (real keyboard views
  via `.keyboardState(...)`, no text-input session).
- `KeyboardKeySizeSettingsUI.swift` — the removed `KeyboardSettingsView` card +
  slider + `KeyboardKeySizeOption`, with step-by-step re-enable notes.

## To re-enable
Follow the numbered steps in `KeyboardKeySizeSettingsUI.swift`, then fix the two
known issues above before shipping.
