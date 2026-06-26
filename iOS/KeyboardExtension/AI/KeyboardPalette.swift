import SwiftUI
import UIKit

/// Adaptive AI chrome colors for the keyboard extension.
enum KeyboardPalette {
    /// Brand purple — used for selection strokes and focused card borders.
    static let accent = dynamic(light: UIColor(red: 0.341, green: 0.258, blue: 0.656, alpha: 1),
                                dark: UIColor(red: 0.620, green: 0.545, blue: 0.900, alpha: 1))
    /// Pale lavender fill for selected pills — reads as "selection state" without
    /// the visual weight of a saturated CTA, per design.md.
    static let accentSoft = dynamic(light: UIColor(red: 0.950, green: 0.937, blue: 0.986, alpha: 1),
                                    dark: UIColor(red: 0.225, green: 0.195, blue: 0.360, alpha: 1))
    static let surface = dynamic(light: UIColor(red: 0xD2 / 255, green: 0xD3 / 255, blue: 0xD8 / 255, alpha: 1),
                                 dark: UIColor(red: 0x32 / 255, green: 0x32 / 255, blue: 0x32 / 255, alpha: 1))
    static let cardBackground = dynamic(light: .white,
                                        dark: UIColor(white: 0.24, alpha: 1))
    static let pillBackground = dynamic(light: UIColor(white: 1, alpha: 0.72),
                                        dark: UIColor(white: 0.30, alpha: 1))
    static let prominentPillBackground = dynamic(light: UIColor(white: 1, alpha: 0.92),
                                                 dark: UIColor(white: 0.34, alpha: 1))
    /// Primary text on AI surfaces.
    static let ink = dynamic(light: UIColor(red: 0.129, green: 0.129, blue: 0.155, alpha: 1),
                             dark: UIColor(white: 0.96, alpha: 1))

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
