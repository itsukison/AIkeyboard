import KeyboardKit
import XCTest
@testable import JapaneseKeyboardUI

final class JapaneseKeyboardUITests: XCTestCase {
    func testQwertyViewModuleResolves() {
        // Smoke test: ensure the module compiles and is importable.
        _ = QwertyKeyboardView.self
    }

    func testWholeInputCaptureBeforeOnly() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "これはテストです",
            selectedText: "",
            afterCursor: "",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "これはテストです")
        XCTAssertEqual(capture.moveToEndCharacterCount, 0)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 8)
    }

    func testWholeInputCaptureCursorInMiddle() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は",
            selectedText: "",
            afterCursor: "晴れです",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "今日は晴れです")
        XCTAssertEqual(capture.moveToEndCharacterCount, 4)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 7)
    }

    func testWholeInputCaptureIncludesSelection() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "今日は",
            selectedText: "とても",
            afterCursor: "晴れです",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "今日はとても晴れです")
        XCTAssertEqual(capture.moveToEndCharacterCount, 4)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 10)
    }

    func testWholeInputCaptureRejectsWhitespace() {
        XCTAssertThrowsError(
            try WholeInputCapture.make(
                beforeCursor: "  ",
                selectedText: "\n",
                afterCursor: "",
                documentIdentifierString: "doc",
                maxCharacters: 2_000
            )
        ) { error in
            XCTAssertEqual(error as? WholeInputCaptureError, .empty)
        }
    }

    func testWholeInputCaptureRejectsTooLongInput() {
        XCTAssertThrowsError(
            try WholeInputCapture.make(
                beforeCursor: String(repeating: "あ", count: 2_001),
                selectedText: "",
                afterCursor: "",
                documentIdentifierString: "doc",
                maxCharacters: 2_000
            )
        ) { error in
            XCTAssertEqual(error as? WholeInputCaptureError, .tooLong)
        }
    }

    func testWholeInputCaptureCountsComposedCharacters() throws {
        let capture = try WholeInputCapture.make(
            beforeCursor: "は",
            selectedText: "が",
            afterCursor: "😀",
            documentIdentifierString: "doc",
            maxCharacters: 2_000
        )

        XCTAssertEqual(capture.targetText, "はが😀")
        XCTAssertEqual(capture.moveToEndCharacterCount, 1)
        XCTAssertEqual(capture.deleteBackwardCharacterCount, 3)
    }

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

        let actions = Self.alphabeticCharacterActions(in: layout)
        XCTAssertTrue(actions.contains("a"))
        XCTAssertFalse(actions.contains { action in
            action.unicodeScalars.contains { scalar in
                scalar.value >= 65 && scalar.value <= 90
            }
        })
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
