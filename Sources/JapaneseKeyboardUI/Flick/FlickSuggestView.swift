import JapaneseKeyboardCore
import SwiftUI

/// The popup that appears when a flick key is held. Renders the native iOS
/// "flick cross": five tiles in a plus, the selected tile filled blue with
/// white text. Tiles are sized to the pressed key (passed in) so each option
/// is the same footprint as the original key, matching native.
struct FlickSuggestView: View {
    let key: FlickKanaTable.FlickKey
    let selectedDirection: FlickKanaTable.FlickDirection?
    var tileWidth: CGFloat = 52
    var tileHeight: CGFloat = 48

    private enum Role { case center, top, bottom, left, right }
    private enum Corner { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    private let cornerRadius: CGFloat = 7

    var body: some View {
        ZStack {
            if let top = key.top {
                tile(top, role: .top, isOn: selectedDirection == .top).offset(y: -tileHeight)
            }
            if let bottom = key.bottom {
                tile(bottom, role: .bottom, isOn: selectedDirection == .bottom).offset(y: tileHeight)
            }
            if let left = key.left {
                tile(left, role: .left, isOn: selectedDirection == .left).offset(x: -tileWidth)
            }
            if let right = key.right {
                tile(right, role: .right, isOn: selectedDirection == .right).offset(x: tileWidth)
            }
            tile(key.center, role: .center, isOn: selectedDirection == nil)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }

    private func tile(_ text: String, role: Role, isOn: Bool) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .regular))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(width: tileWidth, height: tileHeight)
            .background(
                // Only the cross's outer corners are rounded; the edges where
                // tiles meet stay square so the plus reads as one connected shape.
                UnevenRoundedRectangle(
                    topLeadingRadius: radius(role, .topLeading),
                    bottomLeadingRadius: radius(role, .bottomLeading),
                    bottomTrailingRadius: radius(role, .bottomTrailing),
                    topTrailingRadius: radius(role, .topTrailing),
                    style: .continuous
                )
                .fill(isOn ? Color(uiColor: .systemBlue) : FlickKeyPalette.kanaKey)
            )
    }

    private func radius(_ role: Role, _ corner: Corner) -> CGFloat {
        switch role {
        case .top:
            return corner == .topLeading || corner == .topTrailing ? cornerRadius : 0
        case .bottom:
            return corner == .bottomLeading || corner == .bottomTrailing ? cornerRadius : 0
        case .left:
            return corner == .topLeading || corner == .bottomLeading ? cornerRadius : 0
        case .right:
            return corner == .topTrailing || corner == .bottomTrailing ? cornerRadius : 0
        case .center:
            // A center corner is outer (rounded) only when neither adjacent
            // direction has a tile to connect to.
            switch corner {
            case .topLeading: return key.top == nil && key.left == nil ? cornerRadius : 0
            case .topTrailing: return key.top == nil && key.right == nil ? cornerRadius : 0
            case .bottomLeading: return key.bottom == nil && key.left == nil ? cornerRadius : 0
            case .bottomTrailing: return key.bottom == nil && key.right == nil ? cornerRadius : 0
            }
        }
    }
}

/// Describes the flick popup to render at the keyboard level: which key, the
/// selected direction, and the pressed key's frame in the keyboard coordinate
/// space. Published via `FlickPopupKey` so the popup is drawn in a single
/// top-level overlay — above every key, so it is never clipped or hidden.
struct FlickPopup: Equatable {
    let key: FlickKanaTable.FlickKey
    let direction: FlickKanaTable.FlickDirection?
    let frame: CGRect
}

struct FlickPopupKey: PreferenceKey {
    static let space = "flickKeyboard"
    static let defaultValue: FlickPopup? = nil
    static func reduce(value: inout FlickPopup?, nextValue: () -> FlickPopup?) {
        value = value ?? nextValue()
    }
}
