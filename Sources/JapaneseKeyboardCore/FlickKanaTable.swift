import Foundation

/// Static layout data for the 10-key flick kana input mode. Defines the
/// canonical iOS Japanese flick mapping: 10 kana keys × 5 directions, the
/// 小書き (small kana / dakuten) key, the くてんてん (punctuation) key, and
/// the character-type toggle table used by the 小書き key's center tap.
///
/// Kana key layout (columns left→right), matching the native iOS keyboard.
/// The return key spans the bottom two rows in the right column. The bottom-row
/// 小ﾞﾟ slot shows ^_^ when idle and 小ﾞﾟ while composing:
/// ```
///  [→ ]  [あ] [か] [さ] [⌫]
///  [↺ ]  [た] [な] [は] [空白]
///  [ABC] [ま] [や] [ら] [⏎ ]
///  [🌐]  [^_^/小ﾞﾟ][わ] [、。][⏎ ]
/// ```
public enum FlickKanaTable {

    public enum FlickDirection: String, Sendable {
        case left, top, right, bottom
    }

    /// One flickable kana key: the center character and up to 4 flick
    /// alternatives. A nil direction means that flick is unavailable.
    public struct FlickKey: Sendable, Equatable {
        public let center: String
        /// Face label when it differs from the inserted center char (e.g. an
        /// "ABC" key whose center tap inserts "a"). Defaults to `center`.
        public let display: String?
        public let left: String?
        public let top: String?
        public let right: String?
        public let bottom: String?

        public init(center: String, display: String? = nil, left: String? = nil, top: String? = nil, right: String? = nil, bottom: String? = nil) {
            self.center = center
            self.display = display
            self.left = left
            self.top = top
            self.right = right
            self.bottom = bottom
        }

        /// What's drawn on the key cap.
        public var face: String { display ?? center }

        public func character(for direction: FlickDirection) -> String? {
            switch direction {
            case .left: return left
            case .top: return top
            case .right: return right
            case .bottom: return bottom
            }
        }
    }

    // MARK: - Kana keys (canonical iOS 10-key flick order)

    public static let a = FlickKey(center: "あ", left: "い", top: "う", right: "え", bottom: "お")
    public static let ka = FlickKey(center: "か", left: "き", top: "く", right: "け", bottom: "こ")
    public static let sa = FlickKey(center: "さ", left: "し", top: "す", right: "せ", bottom: "そ")
    public static let ta = FlickKey(center: "た", left: "ち", top: "つ", right: "て", bottom: "と")
    public static let na = FlickKey(center: "な", left: "に", top: "ぬ", right: "ね", bottom: "の")
    public static let ha = FlickKey(center: "は", left: "ひ", top: "ふ", right: "へ", bottom: "ほ")
    public static let ma = FlickKey(center: "ま", left: "み", top: "む", right: "め", bottom: "も")
    public static let ya = FlickKey(center: "や", left: "「", top: "ゆ", right: "」", bottom: "よ")
    public static let ra = FlickKey(center: "ら", left: "り", top: "る", right: "れ", bottom: "ろ")
    public static let wa = FlickKey(center: "わ", left: "を", top: "ん", right: "ー", bottom: nil)

    /// All 10 kana keys in grid order (column-major, matching the layout).
    public static let kanaKeys: [FlickKey] = [a, ka, sa, ta, na, ha, ma, ya, ra, wa]

    // MARK: - 小書き key (small kana / dakuten / handakuten)

    /// Flick alternatives for the 小書き key. Center tap toggles the last
    /// kana's character type via `toggleCharacterType`; the flicks insert
    /// small kana directly.
    public static let kogaki = FlickKey(center: "小ﾞﾟ", left: "ぁ", top: "ゃ", right: "っ", bottom: "ゔ")

    /// Shown in the 小書き slot when not composing (native swaps the two): a
    /// kaomoji key whose center inserts "^_^". No flick alternatives.
    public static let kaomoji = FlickKey(center: "^_^")

    // MARK: - くてんてん key (punctuation)

    public static let kutoten = FlickKey(center: "、", left: "。", top: "？", right: "！", bottom: "・")

    // MARK: - ABC (English) page — center tap inserts the first letter, flicks
    // insert the rest. Letters are lowercase; the a/A key toggles case.

    public static let abcSymbols = FlickKey(center: "@", display: "@#/&_", left: "#", top: "/", right: "&", bottom: "_")
    public static let abcABC = FlickKey(center: "a", display: "ABC", left: "b", top: "c")
    public static let abcDEF = FlickKey(center: "d", display: "DEF", left: "e", top: "f")
    public static let abcGHI = FlickKey(center: "g", display: "GHI", left: "h", top: "i")
    public static let abcJKL = FlickKey(center: "j", display: "JKL", left: "k", top: "l")
    public static let abcMNO = FlickKey(center: "m", display: "MNO", left: "n", top: "o")
    public static let abcPQRS = FlickKey(center: "p", display: "PQRS", left: "q", top: "r", right: "s")
    public static let abcTUV = FlickKey(center: "t", display: "TUV", left: "u", top: "v")
    public static let abcWXYZ = FlickKey(center: "w", display: "WXYZ", left: "x", top: "y", right: "z")
    public static let abcQuotes = FlickKey(center: "'", display: "'\"()", left: "\"", top: "(", right: ")")
    public static let abcPunct = FlickKey(center: ".", display: ".,?!", left: ",", top: "?", right: "!")

    // MARK: - Number / symbol page

    public static let num1 = FlickKey(center: "1", left: "☆", top: "♪", right: "→")
    public static let num2 = FlickKey(center: "2", left: "¥", top: "$", right: "€")
    public static let num3 = FlickKey(center: "3", left: "%", top: "°", right: "#")
    public static let num4 = FlickKey(center: "4", left: "○", top: "*", right: "・")
    public static let num5 = FlickKey(center: "5", left: "+", top: "×", right: "÷")
    public static let num6 = FlickKey(center: "6", left: "<", top: "=", right: ">")
    public static let num7 = FlickKey(center: "7", left: "「", top: "」", right: ":")
    public static let num8 = FlickKey(center: "8", left: "〒", top: "々", right: "〆")
    public static let num9 = FlickKey(center: "9", left: "^", top: "¦", right: "\\")
    public static let numParens = FlickKey(center: "(", display: "()[]", left: ")", top: "[", right: "]")
    public static let num0 = FlickKey(center: "0", left: "~", top: "…")
    public static let numPunct = FlickKey(center: ".", display: ".,-/", left: ",", top: "-", right: "/")

    // MARK: - Character-type toggle (小書き center tap)

    /// Maps a kana to the next form in its small/dakuten/handakuten cycle.
    /// Used by the 小書き key's center tap: pop the last kana, look it up
    /// here, push the result. Keys not present have no alternate form.
    public static let toggleCycle: [String: String] = [
        // Small vowels (bidirectional)
        "あ": "ぁ", "ぁ": "あ",
        "い": "ぃ", "ぃ": "い",
        "う": "ぅ", "ぅ": "う",
        "え": "ぇ", "ぇ": "え",
        "お": "ぉ", "ぉ": "お",
        // Small yoon (bidirectional)
        "や": "ゃ", "ゃ": "や",
        "ゆ": "ゅ", "ゅ": "ゆ",
        "よ": "ょ", "ょ": "よ",
        // Sokuon (bidirectional)
        "つ": "っ", "っ": "つ",
        // Dakuten (bidirectional)
        "か": "が", "が": "か",
        "き": "ぎ", "ぎ": "き",
        "く": "ぐ", "ぐ": "く",
        "け": "げ", "げ": "け",
        "こ": "ご", "ご": "こ",
        "さ": "ざ", "ざ": "さ",
        "し": "じ", "じ": "し",
        "す": "ず", "ず": "す",
        "せ": "ぜ", "ぜ": "せ",
        "そ": "ぞ", "ぞ": "そ",
        "た": "だ", "だ": "た",
        "ち": "ぢ", "ぢ": "ち",
        "て": "で", "で": "て",
        "と": "ど", "ど": "と",
        // Ha row: は→ば→ぱ→は (dakuten + handakuten, 3-cycle)
        "は": "ば", "ば": "ぱ", "ぱ": "は",
        "ひ": "び", "び": "ぴ", "ぴ": "ひ",
        "ふ": "ぶ", "ぶ": "ぷ", "ぷ": "ふ",
        "へ": "べ", "べ": "ぺ", "ぺ": "へ",
        "ほ": "ぼ", "ぼ": "ぽ", "ぽ": "ほ",
    ]

    /// Returns the toggled form of a kana, or nil if it has no alternate.
    public static func toggledForm(of kana: String) -> String? {
        toggleCycle[kana]
    }

    public static func tapCycle(for key: FlickKey) -> [String]? {
        tapCycles[key.center]
    }

    private static let tapCycles: [String: [String]] = [
        "あ": ["あ", "い", "う", "え", "お"],
        "か": ["か", "き", "く", "け", "こ"],
        "さ": ["さ", "し", "す", "せ", "そ"],
        "た": ["た", "ち", "つ", "て", "と"],
        "な": ["な", "に", "ぬ", "ね", "の"],
        "は": ["は", "ひ", "ふ", "へ", "ほ"],
        "ま": ["ま", "み", "む", "め", "も"],
        "や": ["や", "ゆ", "よ"],
        "ら": ["ら", "り", "る", "れ", "ろ"],
        "わ": ["わ", "を", "ん", "ー"],
        "、": ["、", "。", "？", "！", "・"],
    ]
}
