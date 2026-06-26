# UIPasteControl Research — Replacing the Paste Permission Prompt

**Status:** Deferred — out of scope for current release. Reverted to the
original 返信 button (`runReplyFromClipboard` → `UIPasteboard.general.string`,
which triggers the iOS paste permission prompt).

**Date:** 2026-06-25

---

## Problem

The 返信 (reply) button in the keyboard toolbar calls
`UIPasteboard.general.string` to read the clipboard. On iOS 16+, this triggers
a system modal: "Allow 〇〇 to Paste". That's an extra tap for every reply
flow — bad UX.

## Research findings

### What UIPasteControl is

`UIPasteControl` (iOS 16+) is a `UIControl` subclass. A user tap on it pastes
from the clipboard **without** the "Allow X to Paste" permission prompt — the
user gesture itself is the consent. This is Apple's sanctioned alternative to
programmatic `UIPasteboard.general.string` reads.

- Apple docs: https://developer.apple.com/documentation/uikit/uipastecontrol
- Available iOS 16.0+ (project targets 16.4 — compatible).
- `UIInputViewController` conforms to `UIPasteConfigurationSupporting`, so the
  keyboard VC is a legal `target` for the control.

### How the paste is delivered

The pasted content is delivered to the `target` (a
`UIPasteConfigurationSupporting` object you assign) via
`paste(itemProviders:)` — **not** directly into the host app's text field, and
**not** to `textDocumentProxy` (which does not conform to
`UIPasteConfigurationSupporting`). You must:

1. Set `pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)`
   on the VC.
2. Override `paste(itemProviders: [NSItemProvider])` on the VC.
3. Load the `NSString` from the item provider, then forward it to
   `AIKeyboardController.runReply(withCopiedText:)`.

### Styling capabilities

`UIPasteControl.Configuration` allows:
- `baseBackgroundColor` — background fill color
- `baseForegroundColor` — icon + text color
- `cornerRadius` / `cornerStyle` — corner rounding (`.capsule`, `.fixed`)
- `displayMode` — `.iconOnly`, `.iconAndLabel`, `.labelOnly`

**Cannot be customized:**
- Label text — hardcoded to localized "Paste" (Japanese: 「ペースト」)
- Icon — hardcoded to system paste glyph (not `arrowshape.turn.up.left`)
- No font, no padding, no icon-size property

### Can it match the existing toolbar pills?

- Color: yes (`baseForegroundColor` = brand purple, `baseBackgroundColor` = white)
- Shape: approximately (`cornerStyle = .fixed`, `cornerRadius = 8`)
- Label/icon: **no** — will always say 「ペースト」 with the system paste glyph

## Implementation attempts and outcomes

### Attempt 1: Hybrid overlay (Option C)

**Approach:** Place `UIPasteControl` underneath, overlay a SwiftUI 「返信」 pill
with `.allowsHitTesting(false)` so taps fall through to the system control.

**Result:** **FAILED.** iOS does not honor a covered `UIPasteControl` for the
user-consent paste path. The button was not clickable. The user only saw the
main AI button shift right (the zero-width control + spacer took space but
nothing was visible/tappable).

### Attempt 2: Styled system control, no overlay (Option A)

**Approach:** Ship `UIPasteControl` directly, styled white bg + purple fg +
capsule, `.iconAndLabel` mode, in a fixed 120pt frame.

**Result:** **Partially worked.** No paste modal. But the pill was "way bigger"
than neighboring pills (~120pt vs ~44pt for the `…` pill).

### Attempt 3: Fixed width 78pt, `.iconAndLabel`

**Result:** **FAILED — blue box.** 78pt is below `UIPasteControl`'s minimum
content width for `.iconAndLabel` (icon + "ペースト" + system padding needs
~95-110pt). When constrained below its minimum, the control clips its content
entirely and renders as a solid filled box.

### Attempt 4: `.iconOnly`, 44pt width

**Result:** **WORKED.** Purple paste glyph on white, ~44pt, matched the `…`
pill's footprint. No paste modal. This was the correct configuration.

### Attempt 5: Add corner radius matching + icon scaling

**Approach:** Changed `.capsule` → `.fixed` + `cornerRadius = 8`, and tried to
shrink the icon via a `CGAffineTransform(scaleX: 0.88, y: 0.88)` in a
manual-layout container (`layoutSubviews` setting `bounds`/`center`/`transform`
directly instead of Auto Layout).

**Result:** **FAILED — blue box.** `UIPasteControl` applies its
`Configuration` (colors, icon, corner style) during the Auto Layout cycle. A
manual-layout container that sets `bounds`/`center`/`transform` directly
**bypasses that cycle**, causing the control to fall back to its default
system-blue appearance — no white background, no purple icon. Renders as a
solid blue box.

**Root cause:** Auto Layout and `transform` do not mix. Auto Layout resets
`frame` from `bounds` + `transform`, fighting the scale. But abandoning Auto
Layout breaks the configuration application. There is no way to both scale the
icon AND have the configuration apply correctly.

### Attempt 6: `.clear` background + SwiftUI background layer

**Approach:** Set `baseBackgroundColor = .clear`, draw the white pill in
SwiftUI with `RoundedRectangle(cornerRadius: 8)`.

**Result:** **FAILED — black background.** `UIPasteControl` does not support a
truly transparent background. Setting `baseBackgroundColor = .clear` makes it
fall back to a dark system default.

### Attempt 7: Revert to Auto Layout container, `.fixed` + `cornerRadius = 8`, `.white` bg, `.iconOnly`, 44pt

**Result:** **WORKED.** This was the stable state — Auto Layout container
(known working from Attempt 4), with only the corner style changed from
`.capsule` to `.fixed` + `cornerRadius = 8`. No transform, no manual layout.

### Attempt 8: Post-tap icon continuity

**Approach:** Modified `commandResultBar` to show the paste icon
(`doc.on.clipboard`) instead of "返信" text when `prompt.builtinKey ==
UserPromptDefaults.replyKey`, so the icon persists from tap → generating →
result.

**Result:** **WORKED** (independent of the control wrapper).

## Key lessons

1. **`UIPasteControl` needs Auto Layout.** Its `Configuration` is applied
   during the Auto Layout cycle. Manual frame layout or `transform` bypasses
   this, producing a blue box (default system appearance).

2. **`.iconAndLabel` needs ~95-110pt minimum width.** Below that, the control
   clips to a solid filled box. Use `.iconOnly` for compact layouts.

3. **`baseBackgroundColor = .clear` is not supported.** It falls back to a dark
   default. Use `.white` (or another solid color).

4. **Covered `UIPasteControl` does not work.** iOS does not honor the
   user-consent paste path when the control is obscured by another view with
   `allowsHitTesting(false)`.

5. **Icon size is not configurable.** `UIPasteControl.Configuration` has no
   icon-size property. The only lever would be `transform`, which breaks the
   configuration application (see lesson 1). A purely visual SwiftUI
   `.scaleEffect` on the wrapper might work but was not tested.

6. **The label is hardcoded.** You cannot make it say 「返信」 — it will always
   say 「ペースト」 (or the localized equivalent). If brand-match is required,
   `UIPasteControl` is the wrong tool.

7. **Zero-width pitfall.** `UIPasteControl` reports a deferred intrinsic
   content size. Inside a SwiftUI `UIViewRepresentable`, SwiftUI proposes 0
   width before the control lays out, so it collapses to 0 and stays 0. An
   explicit `.frame(width:height:)` is required.

## Working configuration (for future reference)

```swift
// PasteControlButton.swift
struct PasteControlButton: UIViewRepresentable {
    let target: (any UIPasteConfigurationSupporting)?

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let configuration = UIPasteControl.Configuration()
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = UIColor(
            red: 0.341, green: 0.258, blue: 0.656, alpha: 1.0
        )
        configuration.cornerStyle = .fixed
        configuration.cornerRadius = 8
        configuration.displayMode = .iconOnly

        let button = UIPasteControl(configuration: configuration)
        button.target = target
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let button = uiView.subviews.compactMap({ $0 as? UIPasteControl }).first else { return }
        button.target = target
    }
}
```

```swift
// AIKeyboardToolbarView.swift — replyPill()
private func replyPill() -> some View {
    PasteControlButton(target: aiController.pasteTarget)
        .frame(width: 44, height: KeyboardChromeMetrics.toolbarButtonHeight)
}
```

```swift
// AIKeyboardController.swift — pasteTarget
var pasteTarget: (any UIPasteConfigurationSupporting)? { controller }
```

```swift
// KeyboardViewController.swift — paste configuration + handler
override func viewDidLoad() {
    super.viewDidLoad()
    // ...
    pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
}

override func paste(itemProviders: [NSItemProvider]) {
    for provider in itemProviders where provider.canLoadObject(ofClass: NSString.self) {
        provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
            let string = (object as? String) ?? ""
            DispatchQueue.main.async {
                self?.aiKeyboardController.runReply(withCopiedText: string)
            }
        }
    }
}
```

```swift
// AIKeyboardController.swift — animate pill appearance
private func promoteReplyIfFreshCopy() {
    let pasteboard = UIPasteboard.general
    let current = pasteboard.changeCount
    guard current != KeyboardSettingsStore.readLastSeenPasteboardChangeCount() else { return }
    KeyboardSettingsStore.writeLastSeenPasteboardChangeCount(current)
    withAnimation(.easeInOut(duration: 0.28)) {
        replyAvailable = pasteboard.hasStrings
    }
}
```

```swift
// AIKeyboardToolbarView.swift — post-tap icon continuity in commandResultBar
Group {
    if prompt.builtinKey == UserPromptDefaults.replyKey {
        Image(systemName: "doc.on.clipboard")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(KeyboardPalette.accent)
    } else {
        Text(prompt.title)
            .font(.system(size: 14, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(KeyboardPalette.ink)
    }
}
```

## What was NOT solved

- **Icon size:** cannot be reduced without breaking the control's
  configuration. The system default icon size is slightly larger than the
  toolbar's other SF Symbol icons (which use `size: 12-14`). A SwiftUI
  `.scaleEffect` on the wrapper is untested but might work (purely visual,
  doesn't touch the underlying UIView layout).
- **Label:** will always say 「ペースト」, never 「返信」. The onboarding copy
  and `NativeReplyPill` mock must reflect this.
- **Corner radius:** `.fixed` + `cornerRadius = 8` is close to but not
  pixel-identical to SwiftUI's `RoundedRectangle(cornerRadius: 8, style:
  .continuous)`. The difference is subtle and was not visually problematic.

## Next steps when revisiting

1. Start from the working configuration above (Auto Layout, `.iconOnly`, 44pt,
   `.white` bg, `.fixed` + `cornerRadius = 8`).
2. If icon-size matching is needed, try SwiftUI `.scaleEffect(0.88)` on
   `replyPill()` — do NOT use `transform` on the underlying UIView.
3. Accept the 「ペースト」 label. The system paste glyph is universally
   recognized; onboarding copy should explain the reply feature.
4. The slide-in animation (wrapping `replyAvailable` in `withAnimation`) and
   post-tap icon continuity are safe, independent improvements that can be
   applied even to the original 返信 button.
