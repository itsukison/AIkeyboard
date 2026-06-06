import SwiftUI

struct BikeyPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(BikeyPrimaryButtonStyle(isLoading: isLoading, isEnabled: isEnabled))
        .disabled(!isEnabled || isLoading)
    }

    @ViewBuilder
    private var label: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(title)
                    .bikeyFont(15, weight: .medium, relativeTo: .body)
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: BikeyMetrics.Sizing.inputHeight)
    }
}

private struct BikeyPrimaryButtonStyle: ButtonStyle {
    let isLoading: Bool
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(background)
            .scaleEffect(pressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.15), value: pressed)
    }

    private var background: some View {
        return Capsule()
            .fill(AppColor.charcoalAction.opacity(isEnabled ? 1.0 : 0.42))
            .shadow(color: .black.opacity(isEnabled ? 0.12 : 0.0), radius: 14, x: 0, y: 8)
    }
}
