import SwiftUI

enum BikeyMetrics {
    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let field: CGFloat = 18
        static let largeCard: CGFloat = 20
        static let card: CGFloat = 24
        static let banner: CGFloat = 28
        static let hero: CGFloat = 36
        static let tile: CGFloat = 14
    }

    enum Sizing {
        static let inputHeight: CGFloat = 56
        static let tappableMin: CGFloat = 44
        static let tabBarHeight: CGFloat = 88
        static let screenHorizontalInset: CGFloat = 24
    }

    static func systemFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

struct BikeyScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let textStyle: Font.TextStyle

    init(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.textStyle = textStyle
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight))
    }
}

extension View {
    func bikeyFont(_ size: CGFloat, weight: Font.Weight = .regular, relativeTo textStyle: Font.TextStyle = .body) -> some View {
        modifier(BikeyScaledFont(size, weight: weight, relativeTo: textStyle))
    }
}
