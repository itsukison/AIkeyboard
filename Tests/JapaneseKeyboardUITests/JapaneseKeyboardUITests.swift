import JapaneseKeyboardCore
import KeyboardKit
import KeyboardPreferences
import UIKit
import XCTest
@testable import JapaneseKeyboardUI

final class JapaneseKeyboardUITests: XCTestCase {
    func testQwertyViewModuleResolves() {
        // Smoke test: ensure the module compiles and is importable.
        _ = QwertyKeyboardView.self
    }

    func testFlickTouchShowsEnlargedCenterCapImmediately() {
        var state = FlickInteractionState()

        state.touchDown()

        XCTAssertTrue(state.isPressed)
        XCTAssertEqual(state.phase, .quick(nil))
        XCTAssertTrue(state.showsPopup)
        XCTAssertNil(state.direction)
        // The centred cap covers the key on its own; only the offset
        // directional preview needs the key underneath hidden.
        XCTAssertFalse(state.hidesBaseKey)
    }

    func testFastFlickShowsQuickPreviewAndLocksOutGuide() {
        var state = FlickInteractionState()
        state.touchDown()

        state.move(to: .left)
        XCTAssertEqual(state.phase, .quick(.left))
        XCTAssertEqual(state.direction, .left)
        XCTAssertTrue(state.hidesBaseKey)

        state.longPressElapsed()

        XCTAssertEqual(state.phase, .quick(.left))
    }

    func testQuickFlickCanReturnToCenterTile() {
        var state = FlickInteractionState()
        state.touchDown()
        state.move(to: .top)

        state.move(to: nil)

        XCTAssertEqual(state.phase, .quick(nil))
        XCTAssertNil(state.direction)
        XCTAssertFalse(state.hidesBaseKey)
    }

    func testStationaryHoldShowsGuideAndTracksDirection() {
        var state = FlickInteractionState()
        state.touchDown()

        state.longPressElapsed()
        XCTAssertEqual(state.phase, .guide(nil))

        state.move(to: .right)
        XCTAssertEqual(state.phase, .guide(.right))
        XCTAssertEqual(state.direction, .right)
    }

    // MARK: - Flick direction resolution

    /// The threshold is uniform, so a flick of the same length and angle
    /// resolves in every direction. The per-direction thresholds this replaced
    /// (left 24, top 44, right 64, bottom 24 pt) made 上 and 右 unreachable at
    /// normal flick lengths — those flicks committed the center kana instead,
    /// which is what users read as "the angle has to be exact".
    func testUniformThresholdResolvesEveryDirectionAtTheSameDistance() {
        let key = FlickKanaTable.a
        let distance = FlickDirectionResolver.threshold

        XCTAssertEqual(resolve(dx: -distance, dy: 0, key: key), .left)
        XCTAssertEqual(resolve(dx: distance, dy: 0, key: key), .right)
        XCTAssertEqual(resolve(dx: 0, dy: -distance, key: key), .top)
        XCTAssertEqual(resolve(dx: 0, dy: distance, key: key), .bottom)
    }

    func testTypicalFlickResolvesWellOffAxis() {
        let key = FlickKanaTable.a
        // A 40 pt flick 14° off horizontal — え, unreachable before.
        XCTAssertEqual(resolve(dx: 40, dy: 10, key: key), .right)
        // A 35 pt upward flick with sideways drift — う.
        XCTAssertEqual(resolve(dx: 12, dy: -35, key: key), .top)
        // Anything inside the 45° cone counts, right up to the edge.
        XCTAssertEqual(resolve(dx: 30, dy: -28, key: key), .right)
    }

    func testShortDragStaysACenterTap() {
        let key = FlickKanaTable.a
        XCTAssertNil(resolve(dx: 12, dy: 4, key: key))
        XCTAssertNil(resolve(dx: 0, dy: 0, key: key))
    }

    func testDirectionWithNoCharacterResolvesToCenter() {
        // わ has no bottom mapping.
        XCTAssertNil(resolve(dx: 0, dy: 40, key: FlickKanaTable.wa))
        XCTAssertEqual(resolve(dx: -40, dy: 0, key: FlickKanaTable.wa), .left)
    }

    func testLatchedDirectionSurvivesTheLiftOffSlideBack() {
        let key = FlickKanaTable.a
        // Finger eases back from 30 pt to 14 pt on release: still え, not あ.
        XCTAssertEqual(
            FlickDirectionResolver.resolve(dx: 14, dy: 0, latched: .right, key: key),
            .right
        )
        // All the way back to the center tile, though, releases the latch.
        XCTAssertNil(
            FlickDirectionResolver.resolve(dx: 4, dy: 0, latched: .right, key: key)
        )
    }

    func testLatchedDirectionSwitchesWhenTheFingerCrossesOver() {
        XCTAssertEqual(
            FlickDirectionResolver.resolve(dx: -30, dy: 0, latched: .right, key: FlickKanaTable.a),
            .left
        )
    }

    private func resolve(
        dx: CGFloat,
        dy: CGFloat,
        key: FlickKanaTable.FlickKey
    ) -> FlickKanaTable.FlickDirection? {
        FlickDirectionResolver.resolve(dx: dx, dy: dy, latched: nil, key: key)
    }

    func testFlickResetClearsPressedAndPopupState() {
        var state = FlickInteractionState()
        state.touchDown()
        state.move(to: .bottom)

        state.reset()

        XCTAssertFalse(state.isPressed)
        XCTAssertEqual(state.phase, .hidden)
        XCTAssertFalse(state.showsPopup)
    }

    func testQuickPreviewMetricsMatchNativeRatios() {
        let capSize = CGSize(width: 72, height: 48)

        let horizontal = FlickQuickPreviewMetrics.size(for: capSize, direction: .left)
        XCTAssertEqual(horizontal.width, 106.56, accuracy: 0.001)
        XCTAssertEqual(horizontal.height, 68.16, accuracy: 0.001)

        let vertical = FlickQuickPreviewMetrics.size(for: capSize, direction: .top)
        XCTAssertEqual(vertical.width, 102.24, accuracy: 0.001)
        XCTAssertEqual(vertical.height, 71.04, accuracy: 0.001)
    }

    func testQuickPreviewCentersMirrorAroundKeyCap() {
        let frame = CGRect(x: 100, y: 200, width: 72, height: 48)
        let left = FlickQuickPreviewMetrics.center(for: frame, direction: .left)
        let right = FlickQuickPreviewMetrics.center(for: frame, direction: .right)
        let top = FlickQuickPreviewMetrics.center(for: frame, direction: .top)
        let bottom = FlickQuickPreviewMetrics.center(for: frame, direction: .bottom)

        XCTAssertEqual(left.x + right.x, frame.midX * 2, accuracy: 0.001)
        XCTAssertEqual(left.y, frame.midY, accuracy: 0.001)
        XCTAssertEqual(right.y, frame.midY, accuracy: 0.001)
        XCTAssertEqual(top.y + bottom.y, frame.midY * 2, accuracy: 0.001)
        XCTAssertEqual(top.x, frame.midX, accuracy: 0.001)
        XCTAssertEqual(bottom.x, frame.midX, accuracy: 0.001)
    }

    /// The tap surface must not interfere with the candidate bar's scroll:
    /// a delegate that gated the scroll view's pan on the tap's failure made
    /// horizontal scrolling unresponsive, and recognizer arbitration in the
    /// hosted toolbar silently dropped chevron taps on iOS 26. Taps are now
    /// decided from raw touch events, so there is no recognizer to gate or
    /// be gated — a swipe reaches the pan untouched, and the pan's takeover
    /// surfaces here as touchesCancelled (which must not fire the tap).
    @MainActor
    func testCandidateTapSurfaceHasNoGestureRecognizers() {
        let view = CandidateTapSurfaceView(onTap: {})
        XCTAssertTrue(view.gestureRecognizers?.isEmpty ?? true)
    }

    @MainActor
    func testCandidateTapSurfaceFiresOnStationaryTouchUp() {
        var fired = 0
        let view = CandidateTapSurfaceView(onTap: { fired += 1 })

        view.touchSequenceBegan(at: CGPoint(x: 10, y: 10))
        view.touchSequenceEnded(at: CGPoint(x: 14, y: 12))

        XCTAssertEqual(fired, 1)
    }

    @MainActor
    func testCandidateTapSurfaceIgnoresSwipes() {
        var fired = 0
        let view = CandidateTapSurfaceView(onTap: { fired += 1 })

        view.touchSequenceBegan(at: CGPoint(x: 10, y: 10))
        view.touchSequenceEnded(at: CGPoint(x: 60, y: 10))

        XCTAssertEqual(fired, 0)
    }

    @MainActor
    func testCandidateTapSurfaceIgnoresCancelledTouches() {
        var fired = 0
        let view = CandidateTapSurfaceView(onTap: { fired += 1 })

        view.touchSequenceBegan(at: CGPoint(x: 10, y: 10))
        view.touchSequenceCancelled()
        // UIKit never sends touchesEnded after a cancel; even if it did, the
        // cleared start point must keep the tap from firing.
        view.touchSequenceEnded(at: CGPoint(x: 10, y: 10))

        XCTAssertEqual(fired, 0)
    }

    @MainActor
    func testStandardKeySizePresetPreservesQwertyGeometry() {
        let context = KeyboardContext()
        var layout = KeyboardLayout.standard(for: context)
        let originalConfiguration = layout.deviceConfiguration

        layout.applyKeyboardKeySizePreset(.standard)

        XCTAssertEqual(layout.deviceConfiguration.rowHeight, originalConfiguration.rowHeight)
        XCTAssertEqual(layout.deviceConfiguration.buttonInsets.top, originalConfiguration.buttonInsets.top)
        XCTAssertEqual(layout.deviceConfiguration.buttonInsets.leading, originalConfiguration.buttonInsets.leading)
        XCTAssertEqual(layout.deviceConfiguration.buttonInsets.bottom, originalConfiguration.buttonInsets.bottom)
        XCTAssertEqual(layout.deviceConfiguration.buttonInsets.trailing, originalConfiguration.buttonInsets.trailing)
    }

    @MainActor
    func testLargeKeySizePresetExpandsCapsWithoutChangingRows() {
        let context = KeyboardContext()
        var layout = KeyboardLayout.standard(for: context)
        let originalConfiguration = layout.deviceConfiguration
        let adjustment = CGFloat(KeyboardKeySizePreset.large.keyCapInsetAdjustment)

        layout.applyKeyboardKeySizePreset(.large)

        XCTAssertEqual(layout.deviceConfiguration.rowHeight, originalConfiguration.rowHeight)
        XCTAssertEqual(
            layout.deviceConfiguration.buttonInsets.top,
            originalConfiguration.buttonInsets.top + adjustment
        )
        XCTAssertEqual(
            layout.deviceConfiguration.buttonInsets.leading,
            originalConfiguration.buttonInsets.leading + adjustment
        )
        XCTAssertEqual(
            layout.deviceConfiguration.buttonInsets.bottom,
            originalConfiguration.buttonInsets.bottom + adjustment
        )
        XCTAssertEqual(
            layout.deviceConfiguration.buttonInsets.trailing,
            originalConfiguration.buttonInsets.trailing + adjustment
        )
    }

    // WholeInputCapture tests moved to JapaneseKeyboardAITests/WholeInputCaptureTests.swift
    // when the AI domain models migrated out of JapaneseKeyboardUI.

    @MainActor
    func testLongVowelKeyInsertedAfterLowercaseL() {
        let context = KeyboardContext()
        context.keyboardCase = .lowercased
        var layout = KeyboardLayout.standard(for: context)
        layout.insertLongVowelKeyOnHomeRow()
        XCTAssertTrue(Self.hasLongVowelKeyAfterL(in: layout))
    }

    @MainActor
    func testLongVowelKeyInsertedAfterUppercaseL() {
        let context = KeyboardContext()
        context.keyboardCase = .uppercased
        var layout = KeyboardLayout.standard(for: context)
        layout.insertLongVowelKeyOnHomeRow()
        XCTAssertTrue(Self.hasLongVowelKeyAfterL(in: layout))
    }

    @MainActor
    func testAlphabeticPageUsesLowercaseLetterActionsEvenWhenContextIsUppercased() {
        let context = KeyboardContext()
        context.keyboardCase = .uppercased
        context.keyboardType = .alphabetic
        var layout = KeyboardLayout.standard(for: context)
        layout.forceLowercasedAlphabeticCharacters(for: context.keyboardType)
        layout.forceInactiveAlphabeticShift(for: context.keyboardType)

        let actions = Self.alphabeticCharacterActions(in: layout)
        XCTAssertTrue(actions.contains("a"))
        XCTAssertFalse(actions.contains { action in
            action.unicodeScalars.contains { scalar in
                scalar.value >= 65 && scalar.value <= 90
            }
        })
        XCTAssertEqual(Self.shiftCase(in: layout), .lowercased)
    }

    @MainActor
    func testUppercaseAlphabeticActionsRemainAvailableForManualShift() {
        let context = KeyboardContext()
        context.keyboardCase = .uppercased
        context.keyboardType = .alphabetic
        let layout = KeyboardLayout.standard(for: context)

        XCTAssertTrue(Self.alphabeticCharacterActions(in: layout).contains("A"))
    }

    @MainActor
    func testNumericPageUsesJapanesePunctuation() {
        let context = KeyboardContext()
        context.keyboardType = .numeric
        var layout = KeyboardLayout.standard(for: context)
        layout.replaceEnglishPunctuationWithJapanese(for: context.keyboardType)

        XCTAssertEqual(
            Self.punctuationActionRows(in: layout),
            [
                ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
                ["-", "/", ":", "@", "(", ")", "「", "」", "¥", "&"],
                ["#+=", "。", "、", "?", "!", "^_^", "backspace"],
            ]
        )
    }

    @MainActor
    func testSymbolicPageUsesJapaneseSymbols() {
        let context = KeyboardContext()
        context.keyboardType = .symbolic
        var layout = KeyboardLayout.standard(for: context)
        layout.replaceEnglishPunctuationWithJapanese(for: context.keyboardType)

        XCTAssertEqual(
            Self.punctuationActionRows(in: layout),
            [
                ["[", "]", "{", "}", "#", "%", "^", "*", "+", "="],
                ["_", "\\", ";", "|", "<", ">", "\"", "'", "$", "€"],
                ["123", ".", ",", "?", "!", "・", "backspace"],
            ]
        )
    }

    @MainActor
    func testThirdPunctuationRowHasFiveCharacterKeysBetweenModeSwitchAndBackspace() {
        for keyboardType in [Keyboard.KeyboardType.numeric, .symbolic] {
            let context = KeyboardContext()
            context.keyboardType = keyboardType
            var layout = KeyboardLayout.standard(for: context)
            layout.replaceEnglishPunctuationWithJapanese(for: context.keyboardType)

            XCTAssertEqual(Self.characterCountBetweenModeSwitchAndBackspace(in: layout), 5)
        }
    }

    private static func hasLongVowelKeyAfterL(in layout: KeyboardLayout) -> Bool {
        guard layout.itemRows.count > 1 else { return false }
        let row = layout.itemRows[1]
        for (index, item) in row.enumerated() {
            guard KeyboardLayout.isCharacter(item.action, "l", caseInsensitive: true) else { continue }
            let nextIndex = index + 1
            guard nextIndex < row.count else { return false }
            return KeyboardLayout.isCharacter(row[nextIndex].action, "-")
        }
        return false
    }

    private static func alphabeticCharacterActions(in layout: KeyboardLayout) -> [String] {
        layout.itemRows.flatMap { row in
            row.compactMap { item in
                guard case .character(let value) = item.action else { return nil }
                guard value.count == 1, let scalar = value.unicodeScalars.first else { return nil }
                guard (scalar.value >= 65 && scalar.value <= 90) || (scalar.value >= 97 && scalar.value <= 122) else {
                    return nil
                }
                return value
            }
        }
    }

    private static func shiftCase(in layout: KeyboardLayout) -> Keyboard.KeyboardCase? {
        for item in layout.itemRows.flatMap({ $0 }) {
            if case .shift(let keyboardCase) = item.action {
                return keyboardCase
            }
        }
        return nil
    }

    private static func punctuationActionRows(in layout: KeyboardLayout) -> [[String]] {
        layout.itemRows.prefix(3).map { row in
            row.compactMap { item in
                switch item.action {
                case .character(let character):
                    return character
                case .keyboardType(.symbolic):
                    return "#+="
                case .keyboardType(.numeric):
                    return "123"
                case .backspace:
                    return "backspace"
                default:
                    return nil
                }
            }
        }
    }

    private static func characterCountBetweenModeSwitchAndBackspace(in layout: KeyboardLayout) -> Int? {
        guard layout.itemRows.count > 2 else { return nil }
        let row = layout.itemRows[2]
        guard
            let modeSwitchIndex = row.firstIndex(where: { item in
                if case .keyboardType = item.action { return true }
                return false
            }),
            let backspaceIndex = row.firstIndex(where: { $0.action == .backspace }),
            modeSwitchIndex < backspaceIndex
        else {
            return nil
        }

        return row[(modeSwitchIndex + 1)..<backspaceIndex].filter { item in
            if case .character = item.action { return true }
            return false
        }.count
    }
}

/// The iPad layout is measured against the system Japanese keyboard, so the
/// expectations below are numbers read off that capture (2×, 810pt-wide iPad,
/// portrait) rather than round values. See `PadNativeLayout.swift`.
@MainActor
final class NativePadLayoutTests: XCTestCase {
    private let totalWidth: Double = 810
    private let accuracy: Double = 1

    private func padAlphabeticLayout() -> KeyboardLayout {
        let context = KeyboardContext()
        context.deviceTypeForKeyboard = .pad
        context.keyboardType = .alphabetic
        var layout = KeyboardLayout.standard(for: context)
        layout.applyNativePadLayout(for: .alphabetic)
        return layout
    }

    /// Cap rects per row, resolved the way the renderer resolves them.
    ///
    /// `width(forRowWidth:inputWidth:)` returns the cap width — the item's cell
    /// minus its own insets — and nil for `.available` items, which split
    /// whatever the fixed cells leave over.
    private func caps(in layout: KeyboardLayout) -> [[(x: Double, width: Double)]] {
        let inputWidth = layout.inputWidth(for: totalWidth)
        return layout.itemRows.map { row in
            let cells = zip(row, row.map { $0.width(forRowWidth: totalWidth, inputWidth: inputWidth) })
                .map { item, cap in
                    cap.map { $0 + item.edgeInsets.leading + item.edgeInsets.trailing }
                }
            let fixed = cells.compactMap { $0 }.reduce(0, +)
            let flexible = Double(cells.filter { $0 == nil }.count)
            let available = flexible > 0 ? (totalWidth - fixed) / flexible : 0
            var x: Double = 0
            return cells.enumerated().map { index, cell in
                let width = cell ?? available
                let insets = row[index].edgeInsets
                defer { x += width }
                return (x + insets.leading, width - insets.leading - insets.trailing)
            }
        }
    }

    func testPadLayoutDropsTheKeysTheNativeKeyboardDoesNotHave() {
        let actions = padAlphabeticLayout().itemRows.flatMap { $0.map(\.action) }

        XCTAssertFalse(actions.contains(.tab))
        XCTAssertFalse(actions.contains(.capsLock))
        XCTAssertEqual(actions.filter { if case .shift = $0 { return true }; return false }.count, 1)
        XCTAssertEqual(actions.filter { if case .keyboardType = $0 { return true }; return false }.count, 1)
        XCTAssertTrue(actions.contains(.character("、")))
        XCTAssertTrue(actions.contains(.character("。")))
        XCTAssertTrue(actions.contains(.character("-")))
        XCTAssertFalse(actions.contains(.character(",")))
        XCTAssertFalse(actions.contains(.character(".")))
    }

    func testPadTopRowMatchesTheNativeCapture() {
        let row = caps(in: padAlphabeticLayout())[0]

        XCTAssertEqual(row.count, 11)
        XCTAssertEqual(row[0].x, 6, accuracy: accuracy)
        XCTAssertEqual(row[0].width, 60.5, accuracy: accuracy)
        XCTAssertEqual(row[1].x - row[0].x, 73.25, accuracy: accuracy)
        // Backspace is wider than a letter and ends at the right margin.
        XCTAssertEqual(row[10].x, 739, accuracy: accuracy)
        XCTAssertEqual(row[10].x + row[10].width, 803.5, accuracy: accuracy)
    }

    func testPadHomeRowIsIndentedAndEndsInAWideReturn() {
        let row = caps(in: padAlphabeticLayout())[1]

        XCTAssertEqual(row.count, 11)
        // Index 0 is the empty indent slot; the row starts at `a`.
        XCTAssertEqual(row[1].x, 37, accuracy: accuracy)
        XCTAssertEqual(row[2].x - row[1].x, 72.75, accuracy: accuracy)
        XCTAssertEqual(row[10].x, 691.5, accuracy: accuracy)
        XCTAssertEqual(row[10].width, 112.5, accuracy: accuracy)
    }

    func testPadLowerRowEndsInTheLongVowelKeyAndAGutter() {
        let layout = padAlphabeticLayout()
        let row = caps(in: layout)[2]

        XCTAssertEqual(row.count, 12)
        XCTAssertEqual(row[0].x, 6, accuracy: accuracy)
        XCTAssertEqual(row[0].width, 59.5, accuracy: accuracy)
        XCTAssertEqual(row[1].x - row[0].x, 71.75, accuracy: accuracy)
        // ー sits in the last cap; native leaves ~21pt of bare background after it.
        XCTAssertEqual(layout.itemRows[2][10].action, .character("-"))
        XCTAssertEqual(row[10].x + row[10].width, 782, accuracy: accuracy)
        XCTAssertEqual(layout.itemRows[2][11].action, .none)
    }

    func testPadBottomRowKeepsTheNativePositionsWeCanFill() {
        let layout = padAlphabeticLayout()
        let row = caps(in: layout)[3]

        XCTAssertEqual(layout.itemRows[3].map(\.action), [
            .keyboardType(.numeric), .nextKeyboard, .space, .dismissKeyboard,
        ])
        XCTAssertEqual(row[0].x, 6, accuracy: accuracy)
        XCTAssertEqual(row[1].x, 78, accuracy: accuracy)
        // The dismiss cap keeps its native width and right edge.
        XCTAssertEqual(row[3].width, 95.5, accuracy: accuracy)
        XCTAssertEqual(row[3].x + row[3].width, 803.5, accuracy: accuracy)
    }

    func testPadCapsAre55PointsTallInA64PointRow() {
        let layout = padAlphabeticLayout()
        let insets = layout.itemRows[0][0].edgeInsets

        XCTAssertEqual(insets.top, 4.5)
        XCTAssertEqual(insets.bottom, 4.5)
        XCTAssertEqual(insets.leading, 6.25)
        XCTAssertEqual(insets.trailing, 6.25)
        XCTAssertEqual(layout.idealItemInsets.top, 4.5)
    }

    func testPadSwipeDownLabelsMatchTheNativeCapture() {
        let layout = padAlphabeticLayout()

        XCTAssertEqual(Self.secondaryCharacters(in: layout.itemRows[0]), [
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        ])
        XCTAssertEqual(Self.secondaryCharacters(in: layout.itemRows[1]), [
            "@", "#", "¥", "-", "*", "(", ")", "「", "」",
        ])
        XCTAssertEqual(Self.secondaryCharacters(in: layout.itemRows[2]), [
            "^_^", "%", "~", "…", "/", ";", ":", "!", "?",
        ])
    }

    private static func secondaryCharacters(in row: [KeyboardLayout.Item]) -> [String] {
        row.compactMap { item in
            guard case .character(let character)? = item.secondaryAction else { return nil }
            return character
        }
    }
}
