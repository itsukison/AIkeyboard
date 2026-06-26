import Foundation

/// Static layout data for the 10-key flick kana input mode. Defines the
/// canonical iOS Japanese flick mapping: 10 kana keys × 5 directions, the
/// 小書き (small kana / dakuten) key, the くてんてん (punctuation) key, and
/// the character-type toggle table used by the 小書き key's center tap.
///
/// Kana key layout (4×5 grid, columns left→right):
/// ```
///  [123] [あ] [か] [さ] [⌫]
///  [ABC] [た] [な] [は] [␣]
///  [かな] [ま] [や] [ら] [⏎]
///  [🌐]  [小ﾞﾟ] [わ] [、。]
/// ```
public enum FlickKanaTable {

    public enum FlickDirection: String, Sendable {
        case left, top, right, bottom
    }

    /// One flickable kana key: the center character and up to 4 flick
    /// alternatives. A nil direction means that flick is unavailable.
    public struct FlickKey: Sendable, Equatable {
        public let center: String
        public let left: String?
        public let top: String?
        public let right: String?
        public let bottom: String?

        public init(center: String, left: String? = nil, top: String? = nil, right: String? = nil, bottom: String? = nil) {
            self.center = center
            self.left = left
            self.top = top
            self.right = right
            self.bottom = bottom
        }

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

    // MARK: - くてんてん key (punctuation)

    public static let kutoten = FlickKey(center: "、", left: "。", top: "？", right: "！", bottom: "・")

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
}
