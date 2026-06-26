import JapaneseKeyboardCore
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
    public let onSwitchToRomaji: () -> Void
    public let toolbarContent: AnyView?
    public let overlayContent: AnyView?

    @State private var page: Page = .kana

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
        onSwitchToRomaji: @escaping () -> Void = {},
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
        self.onSwitchToRomaji = onSwitchToRomaji
        self.toolbarContent = toolbarContent
        self.overlayContent = overlayContent
    }

    public var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                toolbar
                keyGrid
            }
            if let overlayContent {
                overlayContent
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
            row1
            row2
            row3
            row4
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
        .background(Color(uiColor: .systemBackground))
    }

    // Row 1: [123/☆] [あ/1/a] [か/2/b] [さ/3/c] [⌫]
    private var row1: some View {
        HStack(spacing: 6) {
            tabKey(label: page == .kana ? "123" : "かな", action: { page = page == .kana ? .number : .kana })
            kanaKey(FlickKanaTable.a)
            kanaKey(FlickKanaTable.ka)
            kanaKey(FlickKanaTable.sa)
            utilityKey(
                AnyView(Image(systemName: "delete.left").font(.system(size: 22))),
                action: onBackspace
            )
        }
        .frame(height: 52)
    }

    // Row 2: [ABC] [た/な/は] [␣]
    private var row2: some View {
        HStack(spacing: 6) {
            tabKey(label: "ABC", action: { page = .abc })
            kanaKey(FlickKanaTable.ta)
            kanaKey(FlickKanaTable.na)
            kanaKey(FlickKanaTable.ha)
            utilityKey(
                AnyView(Text("空白").font(.system(size: 16))),
                action: onSpace
            )
        }
        .frame(height: 52)
    }

    // Row 3: [かな] [ま/や/ら] [⏎]
    private var row3: some View {
        HStack(spacing: 6) {
            tabKey(label: "ローマ字", action: onSwitchToRomaji)
            kanaKey(FlickKanaTable.ma)
            kanaKey(FlickKanaTable.ya)
            kanaKey(FlickKanaTable.ra)
            utilityKey(
                AnyView(Text(inputManager.isComposing ? "確定" : "改行").font(.system(size: 16))),
                action: onReturn,
                isWide: true
            )
        }
        .frame(height: 52)
    }

    // Row 4: [小ﾞﾟ] [わ] [、。]
    private var row4: some View {
        HStack(spacing: 6) {
            kanaKey(FlickKanaTable.kogaki, onCenterTap: { inputManager.toggleLastKanaCharacterType() })
            kanaKey(FlickKanaTable.wa)
            kanaKey(FlickKanaTable.kutoten)
            Spacer().frame(maxWidth: .infinity)
        }
        .frame(height: 52)
    }

    private func kanaKey(_ key: FlickKanaTable.FlickKey, onCenterTap: (() -> Void)? = nil) -> some View {
        FlickKanaKeyView(
            key: key,
            onSelect: { kana in inputManager.appendKana(kana) },
            onCenterTap: onCenterTap,
            onTriggerHaptic: onTriggerHaptic
        )
        .frame(maxWidth: .infinity)
    }

    private func tabKey(label: String, action: @escaping () -> Void) -> some View {
        utilityKey(AnyView(Text(label)), action: action)
    }

    private func utilityKey(_ label: AnyView, action: @escaping () -> Void, isWide: Bool = false) -> some View {
        FlickUtilityKeyView(
            label: { label },
            action: action,
            onTriggerHaptic: onTriggerHaptic,
            isWide: isWide
        )
    }
}
