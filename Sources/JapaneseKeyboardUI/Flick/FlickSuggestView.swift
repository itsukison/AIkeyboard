import JapaneseKeyboardCore
import SwiftUI

enum FlickPopupPhase: Equatable {
    case hidden
    case quick(FlickKanaTable.FlickDirection?)
    case guide(FlickKanaTable.FlickDirection?)
}

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

struct FlickQuickPreviewMetrics {
    static let bodyRatio: CGFloat = 1.12
    static let pointerRatio: CGFloat = 0.36
    static let crossAxisRatio: CGFloat = 1.42
    static let offsetRatio: CGFloat = 0.97
    static let cornerRatio: CGFloat = 0.20

    static func size(
        for capSize: CGSize,
        direction: FlickKanaTable.FlickDirection
    ) -> CGSize {
        switch direction {
        case .left, .right:
            return CGSize(
                width: capSize.width * (bodyRatio + pointerRatio),
                height: capSize.height * crossAxisRatio
            )
        case .top, .bottom:
            return CGSize(
                width: capSize.width * crossAxisRatio,
                height: capSize.height * (bodyRatio + pointerRatio)
            )
        }
    }

    static func center(
        for capFrame: CGRect,
        direction: FlickKanaTable.FlickDirection
    ) -> CGPoint {
        switch direction {
        case .left:
            return CGPoint(
                x: capFrame.midX - capFrame.width * offsetRatio,
                y: capFrame.midY
            )
        case .top:
            return CGPoint(
                x: capFrame.midX,
                y: capFrame.midY - capFrame.height * offsetRatio
            )
        case .right:
            return CGPoint(
                x: capFrame.midX + capFrame.width * offsetRatio,
                y: capFrame.midY
            )
        case .bottom:
            return CGPoint(
                x: capFrame.midX,
                y: capFrame.midY + capFrame.height * offsetRatio
            )
        }
    }

    static func cornerRadius(for capSize: CGSize) -> CGFloat {
        min(capSize.width, capSize.height) * cornerRatio
    }
}

struct FlickQuickPreviewView: View {
    let key: FlickKanaTable.FlickKey
    let direction: FlickKanaTable.FlickDirection
    let capSize: CGSize

    var body: some View {
        let size = FlickQuickPreviewMetrics.size(for: capSize, direction: direction)
        let cornerRadius = FlickQuickPreviewMetrics.cornerRadius(for: capSize)
        ZStack {
            FlickQuickPreviewShape(direction: direction, cornerRadius: cornerRadius)
                .fill(FlickKeyPalette.kanaKey)
                .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
            Text(key.character(for: direction) ?? key.center)
                .font(.system(size: min(capSize.width, capSize.height) * 0.66, weight: .regular))
                .foregroundStyle(.primary)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// The enlarged key cap shown the instant a finger lands, before any direction
/// is picked. Native replaces the key cap with this on touch-down; the pointed
/// `FlickQuickPreviewView` takes over as soon as a direction is.
struct FlickCenterPreviewView: View {
    let key: FlickKanaTable.FlickKey
    let capSize: CGSize

    var body: some View {
        let scale = FlickQuickPreviewMetrics.bodyRatio
        ZStack {
            RoundedRectangle(
                cornerRadius: FlickQuickPreviewMetrics.cornerRadius(for: capSize),
                style: .continuous
            )
            .fill(FlickKeyPalette.kanaKey)
            .shadow(color: .black.opacity(0.24), radius: 5, y: 2)
            Text(key.face)
                .font(.system(
                    size: min(capSize.width, capSize.height) * (key.face.count > 1 ? 0.4 : 0.66),
                    weight: .regular
                ))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.primary)
        }
        .frame(width: capSize.width * scale, height: capSize.height * scale)
    }
}

struct FlickQuickPreviewShape: Shape {
    let direction: FlickKanaTable.FlickDirection
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        switch direction {
        case .left:
            horizontalPath(in: rect, pointsRight: true)
        case .right:
            horizontalPath(in: rect, pointsRight: false)
        case .top:
            verticalPath(in: rect, pointsDown: true)
        case .bottom:
            verticalPath(in: rect, pointsDown: false)
        }
    }

    private func horizontalPath(in rect: CGRect, pointsRight: Bool) -> Path {
        let pointerFraction = FlickQuickPreviewMetrics.pointerRatio
            / (FlickQuickPreviewMetrics.bodyRatio + FlickQuickPreviewMetrics.pointerRatio)
        let pointerWidth = rect.width * pointerFraction
        let radius = min(cornerRadius, rect.height / 2)
        var path = Path()

        if pointsRight {
            let bodyEdge = rect.maxX - pointerWidth
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: bodyEdge, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: bodyEdge, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            let bodyEdge = rect.minX + pointerWidth
            path.move(to: CGPoint(x: bodyEdge, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: bodyEdge, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        }
        path.closeSubpath()
        return path
    }

    private func verticalPath(in rect: CGRect, pointsDown: Bool) -> Path {
        let pointerFraction = FlickQuickPreviewMetrics.pointerRatio
            / (FlickQuickPreviewMetrics.bodyRatio + FlickQuickPreviewMetrics.pointerRatio)
        let pointerHeight = rect.height * pointerFraction
        let radius = min(cornerRadius, rect.width / 2)
        var path = Path()

        if pointsDown {
            let bodyEdge = rect.maxY - pointerHeight
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: bodyEdge))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: bodyEdge))
        } else {
            let bodyEdge = rect.minY + pointerHeight
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: bodyEdge))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: bodyEdge))
        }
        path.closeSubpath()
        return path
    }
}

/// Describes the flick popup to render at the keyboard level: which key, the
/// selected direction, and the pressed key's frame in the keyboard coordinate
/// space. Published via `FlickPopupKey` so the popup is drawn in a single
/// top-level overlay — above every key, so it is never clipped or hidden.
struct FlickPopup: Equatable {
    let key: FlickKanaTable.FlickKey
    let phase: FlickPopupPhase
    let frame: CGRect
}

struct FlickPopupKey: PreferenceKey {
    static let space = "flickKeyboard"
    static let defaultValue: FlickPopup? = nil
    static func reduce(value: inout FlickPopup?, nextValue: () -> FlickPopup?) {
        value = value ?? nextValue()
    }
}
