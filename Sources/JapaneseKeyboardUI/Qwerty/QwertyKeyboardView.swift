import CoreText
import JapaneseKeyboardCore
import KeyboardKit
import KeyboardPreferences
import SwiftUI
import UIKit

public struct QwertyKeyboardView: View {
    public let services: Keyboard.Services
    @ObservedObject public var keyboardContext: KeyboardContext
    // Intentionally NOT @ObservedObject: keystrokes mutate @Published state on
    // `inputManager`, and observing it here would re-run the whole keyboard's
    // body (re-building the layout) on every key. Observation is pushed down
    // into the smallest views that actually depend on input state
    // (`CandidateBar`, `PrimaryKeyLabel`).
    public let inputManager: InputManager
    public let onSelectCandidate: (Candidate) -> Void
    public let onTriggerHaptic: () -> Void
    public let toolbarContent: AnyView?
    public let overlayContent: AnyView?
    public let shouldForceLowercaseAlphabeticCharacters: () -> Bool
    public let manualKeyboardCase: () -> Keyboard.KeyboardCase?
    // Injected (not @AppStorage): the host refreshes it on appearance because
    // iOS never notifies this process of the container app's App Group writes.
    @ObservedObject private var keySizeObserver: KeyboardKeySizeObserver

    public init(
        services: Keyboard.Services,
        keyboardContext: KeyboardContext,
        inputManager: InputManager,
        keySizeObserver: KeyboardKeySizeObserver,
        onSelectCandidate: @escaping (Candidate) -> Void,
        onTriggerHaptic: @escaping () -> Void = {},
        toolbarContent: AnyView? = nil,
        overlayContent: AnyView? = nil,
        shouldForceLowercaseAlphabeticCharacters: @escaping () -> Bool = { false },
        manualKeyboardCase: @escaping () -> Keyboard.KeyboardCase? = { nil }
    ) {
        self.services = services
        self.keyboardContext = keyboardContext
        self.inputManager = inputManager
        self.keySizeObserver = keySizeObserver
        self.onSelectCandidate = onSelectCandidate
        self.onTriggerHaptic = onTriggerHaptic
        self.toolbarContent = toolbarContent
        self.overlayContent = overlayContent
        self.shouldForceLowercaseAlphabeticCharacters = shouldForceLowercaseAlphabeticCharacters
        self.manualKeyboardCase = manualKeyboardCase
    }

    public var body: some View {
        ZStack(alignment: .top) {
            KeyboardView(
                layout: keyboardLayout,
                services: services,
                buttonContent: { params in
                    switch params.item.action {
                    case .nextKeyboard:
                        Image(systemName: "globe")
                            .font(.system(size: 22, weight: .regular))
                    case .keyboardType(.symbolic):
                        Text("#+=")
                            .font(.system(size: NativeKeyMetrics.modeLabelFontSize, weight: .regular))
                            .foregroundStyle(.primary)
                    // Native labels this key `.?123` on iPad and `123` on iPhone.
                    case .keyboardType(.numeric):
                        Text(isPadKeyboard ? ".?123" : "123")
                            .font(.system(size: NativeKeyMetrics.modeLabelFontSize, weight: .regular))
                            .foregroundStyle(.primary)
                    // KeyboardKit ships no CJK locale, so its own label for this
                    // key resolves to empty on ja_JP and the cap rendered blank.
                    case .keyboardType(.alphabetic):
                        Text("あいう")
                            .font(.system(size: NativeKeyMetrics.modeLabelFontSize, weight: .regular))
                            .foregroundStyle(.primary)
                    case .character(let s) where s == NativeKeyMetrics.kaomoji:
                        Text(s)
                            .font(.system(size: NativeKeyMetrics.modeLabelFontSize, weight: .regular))
                            .foregroundStyle(.primary)
                    // Not on the iPad letter page: 、。 carry a swipe-down hint
                    // label there, and replacing the whole button content would
                    // drop it. KeyboardKit's own content keeps the hint, at the
                    // cost of the em-box offset this branch exists to correct.
                    case .character(let s) where NativeKeyMetrics.usesProportionalMetrics(s)
                        && !(isPadKeyboard && keyboardContext.keyboardType == .alphabetic):
                        Text(s)
                            .font(NativeKeyMetrics.proportionalFont(
                                ofSize: characterFontSize(for: params.item.action)
                            ))
                            .foregroundStyle(.primary)
                    case .character("-") where keyboardContext.keyboardType == .alphabetic:
                        Text("ー")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(.primary)
                    case .shift:
                        ShiftKeyLabel(keyboardCase: manualKeyboardCase())
                    case .space:
                        SpaceKeyLabel(inputManager: inputManager)
                    case .primary:
                        PrimaryKeyLabel(inputManager: inputManager, usesNewlineGlyph: isPadKeyboard)
                    default:
                        params.view
                    }
                },
                buttonView: { $0.view },
                collapsedView: { $0.view },
                emojiKeyboard: { $0.view },
                toolbar: { _ in
                    if let toolbarContent {
                        toolbarContent
                    } else {
                        AnyView(CandidateBar(inputManager: inputManager, onTriggerHaptic: onTriggerHaptic, onSelect: onSelectCandidate))
                    }
                }
            )
            .keyboardButtonStyle { params in
                var style = params.standardStyle()
                // Match native iOS 26 key caps: KeyboardKit's default corner
                // radius reads rounder than the system keyboard.
                style.cornerRadius = NativeKeyMetrics.cornerRadius
                // KeyboardKit's character font runs 1pt larger than native's.
                // `style.font` is derived from `keyboardFont`, so set that one.
                if case .character = params.action {
                    style.keyboardFont = KeyboardFont(
                        .system(size: characterFontSize(for: params.action)),
                        params.action.standardButtonFontWeight(for: params.context)
                    )
                }
                // KeyboardKit paints an inactive shift key near-white, so it
                // reads as "active" against the other (gray) function keys. Pin
                // it to the system function-key background — borrowed from the
                // backspace key's own standard style so it tracks the system
                // color across themes/appearances. The active shift
                // (uppercased / caps-locked) keeps its white highlight.
                if case .shift(let shiftCase) = params.action, shiftCase == .lowercased {
                    let systemKey = Keyboard.ButtonStyleBuilderParams(
                        action: .backspace,
                        context: params.context,
                        isPressed: false
                    ).standardStyle()
                    style.backgroundColor = systemKey.backgroundColor
                    style.foregroundColor = systemKey.foregroundColor
                }
                // Dark mode only — the light-mode values still need their own
                // side-by-side capture before we touch them.
                if params.context.colorScheme == .dark {
                    style.shadowColor = NativeKeyMetrics.darkKeyShadow
                    // Match on the fill rather than on `isSystemAction` so the
                    // active (uppercased / caps-locked) shift keeps its white
                    // highlight, and so pressed states are left to KeyboardKit.
                    let systemFill = KeyboardAction.backspace
                        .standardButtonBackgroundColor(for: params.context)
                    if style.backgroundColor == systemFill {
                        style.backgroundColor = NativeKeyMetrics.darkFunctionKeyFill
                    }
                }
                if isPadKeyboard {
                    applyNativePadStyle(&style, params: params)
                }
                return style
            }

            if let overlayContent {
                overlayContent
            }
        }
    }

    private var isPadKeyboard: Bool {
        keyboardContext.deviceTypeForKeyboard == .pad
    }

    /// iPad-only style corrections, measured against the native capture: the
    /// function caps render 64/255 where native uses 70/255, and the two slots
    /// the native layout leaves empty must not draw a cap.
    private func applyNativePadStyle(
        _ style: inout Keyboard.ButtonStyle,
        params: Keyboard.ButtonStyleBuilderParams
    ) {
        if case .none = params.action {
            style.backgroundColor = .clear
            style.shadowColor = .clear
            return
        }
        guard params.context.colorScheme == .dark, !params.isPressed else { return }
        // The colour match above never fires on iPad. The pad layout is ours,
        // so match on the action instead — we know which keys are function keys.
        if params.action.isNativePadFunctionKey {
            style.backgroundColor = NativeKeyMetrics.darkFunctionKeyFill
        }
    }

    private var keyboardLayout: KeyboardLayout {
        var layout = KeyboardLayout.standard(for: keyboardContext)
        layout.deviceConfiguration.inputToolbarHeight = KeyboardChromeMetrics.toolbarHeight
        layout.applyKeyboardKeySizePreset(keyboardKeySizePreset)
        if shouldForceLowercaseAlphabeticCharacters() {
            layout.forceLowercasedAlphabeticCharacters(for: keyboardContext.keyboardType)
            layout.forceInactiveAlphabeticShift(for: keyboardContext.keyboardType)
        }
        // KeyboardKit's iPad layout shares almost nothing with the native
        // Japanese iPad keyboard, so it gets its own row surgery. The phone
        // path below stays exactly as it was.
        if isPadKeyboard {
            if keyboardContext.keyboardType != .alphabetic {
                layout.insertInputModeSwitchKeyBeforeSpace()
                layout.replaceEnglishPunctuationWithJapanese(for: keyboardContext.keyboardType)
            }
            layout.applyNativePadLayout(for: keyboardContext.keyboardType)
            return layout
        }
        layout.insertInputModeSwitchKeyBeforeSpace()
        layout.insertLongVowelKeyOnHomeRow()
        layout.replaceEnglishPunctuationWithJapanese(for: keyboardContext.keyboardType)
        // Last, so the keys inserted above are covered too.
        layout.applyNativeVerticalButtonInsets(NativeKeyMetrics.verticalButtonInset)
        return layout
    }

    /// Native character caps run 1pt smaller than KeyboardKit's standard size.
    /// Derived from KeyboardKit's own value so it tracks device and key type.
    private func characterFontSize(for action: KeyboardAction) -> CGFloat {
        action.standardButtonFontSize(for: keyboardContext)
            - NativeKeyMetrics.characterFontSizeReduction
    }

    private var keyboardKeySizePreset: KeyboardKeySizePreset {
        keySizeObserver.preset
    }
}

/// Key-cap values where KeyboardKit's defaults miss the iOS 26 system keyboard.
/// Every number is measured off a side-by-side device capture of this keyboard
/// and the native Japanese keyboard — see `scripts/keycap-diff.py`.
private enum NativeKeyMetrics {
    /// Mode-switch and kaomoji caps (あいう / 123 / #+= / ^_^). KeyboardKit drew
    /// ^_^ with the full character font (~25pt) and #+= at 16pt.
    static let modeLabelFontSize: CGFloat = 13
    static let cornerRadius: CGFloat = 5
    static let characterFontSizeReduction: CGFloat = 1
    /// Vertical button inset per side. KeyboardKit's 5pt leaves a 44pt cap in a
    /// 54pt row; native insets 6pt for a 42pt cap and a 12pt gap.
    static let verticalButtonInset: CGFloat = 6
    /// Dark-mode function-key fill: KeyboardKit renders 64/255, native 70/255.
    static let darkFunctionKeyFill = Color(white: 70.0 / 255.0)
    /// Dark-mode drop shadow. KeyboardKit's composites to 13/255 over the
    /// 43/255 keyboard background; native lands on 26/255.
    static let darkKeyShadow = Color.black.opacity(0.4)

    static let kaomoji = "^_^"

    /// Full-width CJK punctuation carries its ink in one corner of the em box,
    /// so centring the glyph leaves the ink ~6.5pt off-centre — the single most
    /// visible difference on the number page. The system keyboard renders these
    /// with proportional metrics (`palt`), which trims the empty side bearings
    /// and brings the ink back to the middle.
    private static let proportionalMetricCharacters: Set<String> = ["。", "、", "「", "」"]

    static func usesProportionalMetrics(_ character: String) -> Bool {
        proportionalMetricCharacters.contains(character)
    }

    static func proportionalFont(ofSize size: CGFloat) -> Font {
        let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            .addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kTextSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kAltProportionalTextSelector
                ]]
            ])
        return Font(UIFont(descriptor: descriptor, size: size) as CTFont)
    }
}

private struct ShiftKeyLabel: View {
    let keyboardCase: Keyboard.KeyboardCase?

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundStyle(.primary)
    }

    private var image: Image {
        switch keyboardCase {
        case .uppercased:
            return .keyboardShiftUppercased
        case .capsLocked:
            return .keyboardShiftCapslockActive
        default:
            return .keyboardShiftLowercased
        }
    }
}

/// Render the primary (return) key text from input state. Scoped so only this
/// tiny view re-renders when `isComposing` toggles — the surrounding keyboard
/// chrome does not need to rebuild.
private struct PrimaryKeyLabel: View {
    @ObservedObject var inputManager: InputManager
    /// Native's idle return cap is the ⏎ glyph on iPad and 改行 text on iPhone.
    /// Both show 確定 while composing.
    var usesNewlineGlyph = false

    var body: some View {
        if !inputManager.isComposing, usesNewlineGlyph {
            Image.keyboardNewline
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 21)
                .foregroundStyle(.primary)
        } else {
            Text(inputManager.isComposing ? "確定" : "改行")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.primary)
        }
    }
}

private extension KeyboardAction {
    /// The function keys in the native iPad layout built by
    /// `applyNativePadLayout(for:)`.
    var isNativePadFunctionKey: Bool {
        switch self {
        case .backspace, .primary, .keyboardType, .nextKeyboard, .dismissKeyboard:
            return true
        case .shift(let keyboardCase):
            return keyboardCase == .lowercased
        default:
            return false
        }
    }
}

/// Space key flips to 次候補 while composing (consistent with the native
/// iOS Japanese keyboard, where space cycles candidates during composition).
private struct SpaceKeyLabel: View {
    @ObservedObject var inputManager: InputManager

    var body: some View {
        Text(inputManager.isComposing ? "次候補" : "空白")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.primary)
    }
}

extension KeyboardLayout {
    mutating func applyKeyboardKeySizePreset(_ preset: KeyboardKeySizePreset) {
        let adjustment = CGFloat(preset.keyCapInsetAdjustment)
        deviceConfiguration.buttonInsets.top += adjustment
        deviceConfiguration.buttonInsets.leading += adjustment
        deviceConfiguration.buttonInsets.bottom += adjustment
        deviceConfiguration.buttonInsets.trailing += adjustment
    }

    /// Native puts an emoji key in this slot and leaves keyboard switching to the
    /// bar iOS draws under the keyboard. We keep the globe here instead — the one
    /// deliberate departure from the native bottom row.
    mutating func insertInputModeSwitchKeyBeforeSpace() {
        remove(.nextKeyboard)
        tryInsertBottomRowAction(.nextKeyboard, before: .space)
    }

    /// `KeyboardLayout.standard(for:)` resolves button insets per item, and the
    /// renderer reads the item's copy — mutating `deviceConfiguration` afterwards
    /// does nothing (which is why the previous +1pt here never took effect and
    /// caps stayed at KeyboardKit's 44pt instead of native's 42pt). Write both,
    /// and only vertically: the horizontal insets already match native exactly.
    mutating func applyNativeVerticalButtonInsets(_ inset: CGFloat) {
        deviceConfiguration.buttonInsets.top = inset
        deviceConfiguration.buttonInsets.bottom = inset
        for rowIndex in itemRows.indices {
            for itemIndex in itemRows[rowIndex].indices {
                itemRows[rowIndex][itemIndex].edgeInsets.top = inset
                itemRows[rowIndex][itemIndex].edgeInsets.bottom = inset
            }
        }
    }

    /// Add a chōonpu (ー) key to the right of `l` on the home row, matching the
    /// native iOS romaji keyboard. The action uses `.character("-")` so the
    /// existing romaji buffer (which maps `-` → `ー`) handles it transparently.
    /// We strip the row's character margins so the row keeps its width with one
    /// extra key, mirroring native row 2 (10 keys, no leading/trailing inset).
    mutating func insertLongVowelKeyOnHomeRow() {
        guard itemRows.count > 1 else { return }
        var row = itemRows[1]
        guard let lIndex = row.firstIndex(where: { Self.isCharacter($0.action, "l", caseInsensitive: true) }) else {
            return
        }
        let template = row[lIndex]
        let dashItem = KeyboardLayout.Item(
            action: .character("-"),
            size: template.size,
            alignment: template.alignment,
            edgeInsets: template.edgeInsets
        )
        row.removeAll { item in
            if case .characterMargin = item.action { return true }
            return false
        }
        guard let insertIndex = row.firstIndex(where: { Self.isCharacter($0.action, "l", caseInsensitive: true) }) else {
            return
        }
        row.insert(dashItem, at: insertIndex + 1)
        itemRows[1] = row
    }

    mutating func replaceEnglishPunctuationWithJapanese(for keyboardType: Keyboard.KeyboardType) {
        switch keyboardType {
        case .numeric:
            replaceCharacterRows(with: Self.japaneseNumericPageCharacters)
        case .symbolic:
            replaceCharacterRows(with: Self.japaneseSymbolicPageCharacters)
        default:
            return
        }
    }

    static func isCharacter(_ action: KeyboardAction, _ value: String, caseInsensitive: Bool = false) -> Bool {
        if case .character(let s) = action {
            return caseInsensitive ? s.caseInsensitiveCompare(value) == .orderedSame : s == value
        }
        return false
    }

    private mutating func replaceCharacterRows(with replacementRows: [[String]]) {
        for (rowIndex, replacements) in replacementRows.enumerated() {
            guard itemRows.indices.contains(rowIndex) else { continue }
            replaceCharacters(inRow: rowIndex, with: replacements)
        }
    }

    private mutating func replaceCharacters(inRow rowIndex: Int, with replacements: [String]) {
        var replacementIndex = 0
        let row = itemRows[rowIndex].compactMap { item -> KeyboardLayout.Item? in
            guard case .character = item.action else { return item }
            guard replacementIndex < replacements.count else {
                replacementIndex += 1
                return nil
            }
            let replacement = item.copy(withAction: .character(replacements[replacementIndex]))
            replacementIndex += 1
            return replacement
        }
        itemRows[rowIndex] = row
    }

    mutating func forceLowercasedAlphabeticCharacters(for keyboardType: Keyboard.KeyboardType) {
        guard keyboardType == .alphabetic else { return }
        for rowIndex in itemRows.indices {
            var row = itemRows[rowIndex]
            for itemIndex in row.indices {
                guard case .character(let value) = row[itemIndex].action else { continue }
                guard value.count == 1, let scalar = value.unicodeScalars.first else { continue }
                guard scalar.value >= 65 && scalar.value <= 90 else { continue }
                row[itemIndex] = row[itemIndex].copy(withAction: .character(value.lowercased()))
            }
            itemRows[rowIndex] = row
        }
    }

    mutating func forceInactiveAlphabeticShift(for keyboardType: Keyboard.KeyboardType) {
        guard keyboardType == .alphabetic else { return }
        for rowIndex in itemRows.indices {
            var row = itemRows[rowIndex]
            for itemIndex in row.indices {
                if case .shift = row[itemIndex].action {
                    row[itemIndex] = row[itemIndex].copy(withAction: .shift(.lowercased))
                }
            }
            itemRows[rowIndex] = row
        }
    }

    private static let japaneseNumericPageCharacters = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["-", "/", ":", "@", "(", ")", "「", "」", "¥", "&"],
        ["。", "、", "？", "！", "^_^"],
    ]

    private static let japaneseSymbolicPageCharacters = [
        ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
        ["_", "\\", ";", "|", "<", ">", "\"", "'", "$", "€"],
        [".", ",", "？", "！", "・"],
    ]
}
