import SwiftUI

/// Color tokens mirroring the container app's Bikey Design System
/// (see `keyboard/design.md` and `iOS/Container/Design/AppColor.swift`).
/// Defined locally because `AppColor` is in the container target and not
/// reachable from the keyboard extension.
enum KeyboardPalette {
    /// Brand purple — used for selection strokes and focused card borders.
    static let accent = Color(red: 0.341, green: 0.258, blue: 0.656)
    /// Pale lavender fill for selected pills — reads as "selection state" without
    /// the visual weight of a saturated CTA, per design.md.
    static let accentSoft = Color(red: 0.950, green: 0.937, blue: 0.986)
    /// Warm near-black for primary text on light surfaces.
    static let ink = Color(red: 0.129, green: 0.129, blue: 0.155)
}
