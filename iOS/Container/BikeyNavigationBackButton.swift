import SwiftUI

struct BikeyNavigationBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("戻る")
    }
}
