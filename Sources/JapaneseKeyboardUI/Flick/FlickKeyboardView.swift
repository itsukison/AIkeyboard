import JapaneseKeyboardCore
import KeyboardKit
import KeyboardPreferences
import SwiftUI

/// The 10-key flick kana keyboard. Renders the candidate/AI toolbar on top,
/// then a 4×5 grid of flick kana keys + utility keys (delete, space, return,
/// and the 123/ABC/かな tab switches). Pure-SwiftUI — does not use
/// KeyboardKit's layout engine, because the 10-key layout is fundamentally
/// different from QWERTY.
///
/// The view reads the keyboard style from `KeyboardSettingsStore` to decide
/// whether to show itself; the controller branches on the same setting.
public struct FlickKeyboardView: View {
    public let inputManager: InputManager
    public let onSelectCandidate: (Candidate) -> Void
    public let onSelectPrediction: (Candidate) -> Void
    public let onTriggerHaptic: () -> Void
    public let onBackspace: () -> Void
    public let onSpace: () -> Void
    public let onReturn: () -> Void
    public let onMoveCursorRight: () -> Void
    public let onUndo: () -> Void
    public let onNextKeyboard: () -> Void
    public let onInsertText: (String) -> Void
    public let toolbarContent: AnyView?
    public let overlayContent: AnyView?

    @State private var page: Page = .kana
    @State private var uppercaseLetters = false

    // Key/row height, tuned to match native.
    private let rowHeight: CGFloat = 48
    // Headroom above row 1 so the row-1 flick popup's (enlarged) top tile stays
    // within the keyboard (iOS clips a keyboard extension at its top edge, so we
    // can't let it overflow); the toolbar plus this margin gives it room.
    private let topMargin: CGFloat = 11

    private enum Page {
        case kana, number, abc
    }

    public init(
        inputManager: InputManager,
        onSelectCandidate: @escaping (Candidate) -> Void,
        onSelectPrediction: @escaping (Candidate) -> Void = { _ in },
        onTriggerHaptic: @escaping () -> Void = {},
        onBackspace: @escaping () -> Void = {},
        onSpace: @escaping () -> Void = {},
        onReturn: @escaping () -> Void = {},
        onMoveCursorRight: @escaping () -> Void = {},
        onUndo: @escaping () -> Void = {},
        onNextKeyboard: @escaping () -> Void = {},
        onInsertText: @escaping (String) -> Void = { _ in },
        toolbarContent: AnyView? = nil,
        overlayContent: AnyView? = nil
    ) {
        self.inputManager = inputManager
        self.onSelectCandidate = onSelectCandidate
        self.onSelectPrediction = onSelectPrediction
        self.onTriggerHaptic = onTriggerHaptic
        self.onBackspace = onBackspace
        self.onSpace = onSpace
        self.onReturn = onReturn
        self.onMoveCursorRight = onMoveCursorRight
        self.onUndo = onUndo
        self.onNextKeyboard = onNextKeyboard
        self.onInsertText = onInsertText
        self.toolbarContent = toolbarContent
        self.overlayContent = overlayContent
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                toolbar
                keyGrid
            }
            // Same adaptive surface KeyboardKit paints for the QWERTY layout,
            // so flick's background tracks light/dark identically to romaji.
            .background { Keyboard.Background.standard }
            if let overlayContent {
                overlayContent
            }
        }
        .coordinateSpace(name: FlickPopupKey.space)
        .overlayPreferenceValue(FlickPopupKey.self) { popup in
            if let popup {
                // The focused flick cross is slightly larger than the base key,
                // like native. (topMargin is sized to keep the enlarged top tile
                // from clipping at the keyboard's top edge.)
                let scale: CGFloat = 1.1
                FlickSuggestView(
                    key: popup.key,
                    selectedDirection: popup.direction,
                    tileWidth: popup.frame.width * scale,
                    tileHeight: popup.frame.height * scale
                )
                .position(x: popup.frame.midX, y: popup.frame.midY)
                .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        if let toolbarContent {
            toolbarContent
        } else {
            CandidateBar(
                inputManager: inputManager,
                onTriggerHaptic: onTriggerHaptic,
                onSelect: onSelectCandidate,
                onSelectPrediction: onSelectPrediction
            )
        }
    }

    private var keyGrid: some View {
        VStack(spacing: 6) {
            switch page {
            case .kana: kanaPage
            case .abc: abcPage
            case .number: numberPage
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, topMargin)
        .padding(.bottom, 4)
    }

    // MARK: - Pages (kana → ABC → 123 cycle via the row-3 left key)

    @ViewBuilder private var kanaPage: some View {
        HStack(spacing: 6) {
            cursorKey; kanaKey(FlickKanaTable.a); kanaKey(FlickKanaTable.ka); kanaKey(FlickKanaTable.sa); deleteKey
        }
        .frame(height: rowHeight)
        HStack(spacing: 6) {
            undoKey; kanaKey(FlickKanaTable.ta); kanaKey(FlickKanaTable.na); kanaKey(FlickKanaTable.ha); spaceKey
        }
        .frame(height: rowHeight)
        bottomRows(
            row3Left: {
                pageSwitchKey("ABC", to: .abc)
                kanaKey(FlickKanaTable.ma); kanaKey(FlickKanaTable.ya); kanaKey(FlickKanaTable.ra)
            },
            row4Left: {
                globeKey
                DakutenKaomojiKey(inputManager: inputManager, onInsertText: onInsertText, onTriggerHaptic: onTriggerHaptic)
                kanaKey(FlickKanaTable.wa); kanaKey(FlickKanaTable.kutoten)
            }
        )
    }

    @ViewBuilder private var abcPage: some View {
        HStack(spacing: 6) {
            cursorKey; directKey(FlickKanaTable.abcSymbols); directKey(FlickKanaTable.abcABC); directKey(FlickKanaTable.abcDEF); deleteKey
        }
        .frame(height: rowHeight)
        HStack(spacing: 6) {
            undoKey; directKey(FlickKanaTable.abcGHI); directKey(FlickKanaTable.abcJKL); directKey(FlickKanaTable.abcMNO); halfWidthSpaceKey
        }
        .frame(height: rowHeight)
        bottomRows(
            row3Left: {
                pageSwitchKey("☆123", to: .number)
                directKey(FlickKanaTable.abcPQRS); directKey(FlickKanaTable.abcTUV); directKey(FlickKanaTable.abcWXYZ)
            },
            row4Left: {
                globeKey; caseKey
                directKey(FlickKanaTable.abcQuotes); directKey(FlickKanaTable.abcPunct)
            }
        )
    }

    @ViewBuilder private var numberPage: some View {
        HStack(spacing: 6) {
            cursorKey; directKey(FlickKanaTable.num1); directKey(FlickKanaTable.num2); directKey(FlickKanaTable.num3); deleteKey
        }
        .frame(height: rowHeight)
        HStack(spacing: 6) {
            undoKey; directKey(FlickKanaTable.num4); directKey(FlickKanaTable.num5); directKey(FlickKanaTable.num6); halfWidthSpaceKey
        }
        .frame(height: rowHeight)
        bottomRows(
            row3Left: {
                pageSwitchKey("あいう", to: .kana)
                directKey(FlickKanaTable.num7); directKey(FlickKanaTable.num8); directKey(FlickKanaTable.num9)
            },
            row4Left: {
                globeKey
                directKey(FlickKanaTable.numParens); directKey(FlickKanaTable.num0); directKey(FlickKanaTable.numPunct)
            }
        )
    }

    // Rows 3–4: the left four columns hold the page's keys; the return key spans
    // both rows in the right column, as on the native iOS keyboard.
    private func bottomRows<R3: View, R4: View>(
        @ViewBuilder row3Left: @escaping () -> R3,
        @ViewBuilder row4Left: @escaping () -> R4
    ) -> some View {
        GeometryReader { geo in
            let keyWidth = (geo.size.width - 6 * 4) / 5
            HStack(spacing: 6) {
                VStack(spacing: 6) {
                    HStack(spacing: 6) { row3Left() }
                    HStack(spacing: 6) { row4Left() }
                }
                FlickUtilityKeyView(
                    label: { ReturnKeyLabel(inputManager: inputManager) },
                    action: onReturn,
                    onTriggerHaptic: onTriggerHaptic
                )
                .frame(width: keyWidth)
            }
        }
        .frame(height: rowHeight * 2 + 6)
    }

    // MARK: - Function keys (col 0 + col 4)

    private var cursorKey: some View {
        utilityKey(AnyView(Image(systemName: "arrow.right").font(.system(size: 20))), action: onMoveCursorRight)
    }
    private var undoKey: some View {
        utilityKey(AnyView(Image(systemName: "arrow.counterclockwise").font(.system(size: 20))), action: onUndo)
    }
    private var deleteKey: some View {
        utilityKey(AnyView(Image(systemName: "delete.left").font(.system(size: 22))), action: onBackspace, autoRepeat: true)
    }
    private var spaceKey: some View {
        utilityKey(AnyView(Text("空白").font(.system(size: 16))), action: onSpace)
    }
    /// ABC/number pages insert a half-width space (English/numbers don't want
    /// the full-width 　 that the kana page's space produces).
    private var halfWidthSpaceKey: some View {
        utilityKey(AnyView(Text("空白").font(.system(size: 16))), action: { onInsertText(" ") })
    }
    private var globeKey: some View {
        utilityKey(AnyView(Image(systemName: "globe").font(.system(size: 20))), action: onNextKeyboard)
    }
    private var caseKey: some View {
        utilityKey(AnyView(Text("a/A").font(.system(size: 18))), action: { uppercaseLetters.toggle() })
    }
    private func pageSwitchKey(_ label: String, to target: Page) -> some View {
        tabKey(label: label, action: { page = target })
    }

    /// A flick key on the ABC/number pages: inserts characters literally (no
    /// kana conversion); letters honor the a/A case toggle.
    private func directKey(_ key: FlickKanaTable.FlickKey) -> some View {
        FlickKanaKeyView(
            key: key,
            onSelect: { onInsertText(uppercaseLetters ? $0.uppercased() : $0) },
            onTriggerHaptic: onTriggerHaptic
        )
    }

    private func kanaKey(_ key: FlickKanaTable.FlickKey, onCenterTap: (() -> Void)? = nil) -> some View {
        let centerTap = onCenterTap ?? (
            FlickKanaTable.tapCycle(for: key) == nil ? nil : {
                inputManager.appendKanaFromTapCycle(key)
            }
        )
        return FlickKanaKeyView(
            key: key,
            onSelect: { kana in inputManager.appendKana(kana) },
            onCenterTap: centerTap,
            onTriggerHaptic: onTriggerHaptic
        )
    }

    private func tabKey(label: String, action: @escaping () -> Void) -> some View {
        utilityKey(AnyView(Text(label)), action: action)
    }

    private func utilityKey(_ label: AnyView, action: @escaping () -> Void, autoRepeat: Bool = false) -> some View {
        FlickUtilityKeyView(
            label: { label },
            action: action,
            onTriggerHaptic: onTriggerHaptic,
            autoRepeat: autoRepeat
        )
    }
}

/// The return key's label tracks `isComposing` (確定 while composing, 改行
/// otherwise). Scoped to its own observed view so the change re-renders the
/// label without rebuilding the whole flick grid — mirrors the QWERTY keyboard's
/// `PrimaryKeyLabel`.
private struct ReturnKeyLabel: View {
    @ObservedObject var inputManager: InputManager

    var body: some View {
        Text(inputManager.isComposing ? "確定" : "改行")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.primary)
    }
}

/// The bottom-row slot under あ/た/ま. Native swaps it with composition state:
/// `^_^` (insert kaomoji) when idle, the 小書き/濁点 key when composing. Observed
/// so the swap re-renders without rebuilding the whole grid.
private struct DakutenKaomojiKey: View {
    @ObservedObject var inputManager: InputManager
    let onInsertText: (String) -> Void
    let onTriggerHaptic: () -> Void

    var body: some View {
        if inputManager.isComposing {
            FlickKanaKeyView(
                key: FlickKanaTable.kogaki,
                onSelect: { inputManager.appendKana($0) },
                onCenterTap: { inputManager.toggleLastKanaCharacterType() },
                onTriggerHaptic: onTriggerHaptic
            )
        } else {
            FlickKanaKeyView(
                key: FlickKanaTable.kaomoji,
                onSelect: { _ in onInsertText("^_^") },
                onCenterTap: { onInsertText("^_^") },
                onTriggerHaptic: onTriggerHaptic
            )
        }
    }
}
