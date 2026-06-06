import SwiftUI

extension View {
    @ViewBuilder
    func bikeyGlass<S: Shape>(in shape: S, fallback: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(fallback, in: shape)
        }
    }

    @ViewBuilder
    func bikeyInteractiveGlass<S: Shape>(in shape: S, fallback: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(fallback, in: shape)
        }
    }
}
