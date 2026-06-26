import JapaneseKeyboardCore
import SwiftUI

/// The popup that appears when a flick key is held, showing the center
/// character enlarged and the 4 flick alternatives positioned in their
/// respective directions. Styled to match the native iOS keyboard: light
/// gray popup bubbles, system font, no Bikey design tokens.
struct FlickSuggestView: View {
    let key: FlickKanaTable.FlickKey
    let selectedDirection: FlickKanaTable.FlickDirection?

    private let bubbleColor = Color(uiColor: .secondarySystemBackground)
    private let selectedColor = Color(uiColor: .systemBackground)
    private let keySize: CGFloat = 56
    private let bubbleSize: CGFloat = 40
    private let offset: CGFloat = 44

    var body: some View {
        ZStack {
            centerBubble
            if let left = key.left {
                suggestBubble(text: left, direction: .left, isOn: selectedDirection == .left)
                    .offset(x: -offset, y: 0)
            }
            if let top = key.top {
                suggestBubble(text: top, direction: .top, isOn: selectedDirection == .top)
                    .offset(x: 0, y: -offset)
            }
            if let right = key.right {
                suggestBubble(text: right, direction: .right, isOn: selectedDirection == .right)
                    .offset(x: offset, y: 0)
            }
            if let bottom = key.bottom {
                suggestBubble(text: bottom, direction: .bottom, isOn: selectedDirection == .bottom)
                    .offset(x: 0, y: offset)
            }
        }
    }

    private var centerBubble: some View {
        Text(key.center)
            .font(.system(size: 26, weight: .regular))
            .frame(width: keySize, height: keySize)
            .foregroundStyle(.primary)
            .background(selectedDirection == nil ? selectedColor : bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    private func suggestBubble(text: String, direction: FlickKanaTable.FlickDirection, isOn: Bool) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .regular))
            .frame(width: bubbleSize, height: bubbleSize)
            .foregroundStyle(.primary)
            .background(isOn ? selectedColor : bubbleColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }
}
