import JapaneseKeyboardCore
import KeyboardKit
import SwiftUI

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

    public init(
        services: Keyboard.Services,
        keyboardContext: KeyboardContext,
        inputManager: InputManager,
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
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.primary)
                    case .keyboardType(.numeric):
                        Text("123")
                            .font(.system(size: 16, weight: .regular))
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
                        PrimaryKeyLabel(inputManager: inputManager)
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
                }
                return style
            }

            if let overlayContent {
                overlayContent
            }
        }
    }

    private var keyboardLayout: KeyboardLayout {
        var layout = KeyboardLayout.standard(for: keyboardContext)
        layout.deviceConfiguration.inputToolbarHeight = KeyboardChromeMetrics.toolbarHeight
        // KeyboardKit's default key caps are ~2pt taller with ~2pt tighter row
        // gaps than native iOS. Widening the vertical button insets by 1pt per
        // side rebalances within the same row pitch (caps 44→42pt, gaps
        // 10→12pt). Horizontal insets already match native, so leave them.
        layout.deviceConfiguration.buttonInsets.top += 1
        layout.deviceConfiguration.buttonInsets.bottom += 1
        if shouldForceLowercaseAlphabeticCharacters() {
            layout.forceLowercasedAlphabeticCharacters(for: keyboardContext.keyboardType)
            layout.forceInactiveAlphabeticShift(for: keyboardContext.keyboardType)
        }
        layout.insertInputModeSwitchKeyBeforeSpace()
        layout.insertLongVowelKeyOnHomeRow()
        layout.replaceEnglishPunctuationWithJapanese(for: keyboardContext.keyboardType)
        return layout
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

    var body: some View {
        Text(inputManager.isComposing ? "確定" : "改行")
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(.primary)
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
    mutating func insertInputModeSwitchKeyBeforeSpace() {
        remove(.nextKeyboard)
        tryInsertBottomRowAction(.nextKeyboard, before: .space)
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
