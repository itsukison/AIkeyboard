import SwiftUI

enum AppColor {
    static let background = dynamic(
        light: Color(red: 0.984, green: 0.981, blue: 0.976),
        dark: Color(red: 0.078, green: 0.078, blue: 0.086)
    )
    static let canvas = background
    static let ink = dynamic(
        light: Color(red: 0.129, green: 0.129, blue: 0.155),
        dark: Color(red: 0.945, green: 0.945, blue: 0.961)
    )
    static let muted = dynamic(
        light: Color(red: 0.469, green: 0.462, blue: 0.522),
        dark: Color(red: 0.690, green: 0.686, blue: 0.745)
    )
    static let secondaryInk = muted
    static let softText = dynamic(
        light: Color(red: 0.636, green: 0.630, blue: 0.735),
        dark: Color(red: 0.560, green: 0.553, blue: 0.662)
    )
    static let purple = dynamic(
        light: Color(red: 0.341, green: 0.258, blue: 0.656),
        dark: Color(red: 0.671, green: 0.580, blue: 1.000)
    )
    static let lavender = dynamic(
        light: Color(red: 0.917, green: 0.900, blue: 0.973),
        dark: Color(red: 0.220, green: 0.196, blue: 0.345)
    )
    static let paleLavender = dynamic(
        light: Color(red: 0.950, green: 0.937, blue: 0.986),
        dark: Color(red: 0.180, green: 0.164, blue: 0.290)
    )
    static let lavenderMist = paleLavender
    static let charcoalAction = dynamic(
        light: Color(red: 0.151, green: 0.152, blue: 0.187),
        dark: Color(red: 0.243, green: 0.247, blue: 0.290)
    )
    static let rule = dynamic(
        light: Color(red: 0.805, green: 0.804, blue: 0.803),
        dark: Color.white.opacity(0.10)
    )

    static let surface = dynamic(
        light: Color.white,
        dark: Color(red: 0.118, green: 0.118, blue: 0.137)
    )
    static let surfaceElevated = dynamic(
        light: Color.white.opacity(0.90),
        dark: Color(red: 0.137, green: 0.137, blue: 0.165)
    )

    private static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}
