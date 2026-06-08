import Foundation

public enum Romaji {
    static let kanaTable: [String: String] = [
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "sa": "さ", "si": "し", "shi": "し", "su": "す", "se": "せ", "so": "そ",
        "ta": "た", "ti": "ち", "chi": "ち", "tu": "つ", "tsu": "つ", "te": "て", "to": "と",
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "ha": "は", "hi": "ひ", "hu": "ふ", "fu": "ふ", "he": "へ", "ho": "ほ",
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "ya": "や", "yu": "ゆ", "yo": "よ",
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を", "n": "ん", "nn": "ん",
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "za": "ざ", "zi": "じ", "ji": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",
        "sha": "しゃ", "shu": "しゅ", "sho": "しょ", "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
        "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ", "tya": "ちゃ", "tyu": "ちゅ", "tyo": "ちょ",
        "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
        "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
        "mya": "みゃ", "myu": "みゅ", "myo": "みょ",
        "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
        "ja": "じゃ", "ju": "じゅ", "jo": "じょ", "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
        "bya": "びゃ", "byu": "びゅ", "byo": "びょ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",

        // Small characters via x- / l- prefix (Mozc / AzooKey convention)
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ",
        "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ",
        "xtu": "っ", "xtsu": "っ", "ltu": "っ", "ltsu": "っ",
        "xwa": "ゎ", "lwa": "ゎ",
        "xka": "ヵ", "xke": "ヶ", "lka": "ヵ", "lke": "ヶ",
        "xn": "ん",

        // v row (ヴ)
        "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
        "vya": "ゔゃ", "vyu": "ゔゅ", "vyo": "ゔょ",

        // Foreign-sound extensions: ts / th / dh / tw / dw / she / che / je
        "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
        "tha": "てゃ", "thi": "てぃ", "thu": "てゅ", "the": "てぇ", "tho": "てょ",
        "dha": "でゃ", "dhi": "でぃ", "dhu": "でゅ", "dhe": "でぇ", "dho": "でょ",
        "twa": "とぁ", "twi": "とぃ", "twu": "とぅ", "twe": "とぇ", "two": "とぉ",
        "dwa": "どぁ", "dwi": "どぃ", "dwu": "どぅ", "dwe": "どぇ", "dwo": "どぉ",
        "she": "しぇ", "che": "ちぇ", "je": "じぇ",
        "sye": "しぇ", "zye": "じぇ", "jye": "じぇ", "cye": "ちぇ",

        // f row extensions
        "fya": "ふゃ", "fyu": "ふゅ", "fyo": "ふょ",
        "fwa": "ふぁ", "fwi": "ふぃ", "fwu": "ふぅ", "fwe": "ふぇ", "fwo": "ふぉ",

        // w row extensions
        "wha": "うぁ", "whi": "うぃ", "whu": "う", "whe": "うぇ", "who": "うぉ",
        "wyi": "ゐ", "wye": "ゑ",

        // k / g / q extensions
        "kwa": "くぁ", "kwi": "くぃ", "kwu": "くぅ", "kwe": "くぇ", "kwo": "くぉ",
        "gwa": "ぐぁ", "gwi": "ぐぃ", "gwu": "ぐぅ", "gwe": "ぐぇ", "gwo": "ぐぉ",
        "kye": "きぇ", "gye": "ぎぇ",
        "qa": "くぁ", "qi": "くぃ", "qu": "く", "qe": "くぇ", "qo": "くぉ",
        "qwa": "くぁ", "qwi": "くぃ", "qwu": "くぅ", "qwe": "くぇ", "qwo": "くぉ",

        // Other -e yoon
        "nye": "にぇ", "hye": "ひぇ", "bye": "びぇ", "pye": "ぴぇ",
        "mye": "みぇ", "rye": "りぇ",
    ]

    static let consonants = Set("bcdfghjklmnpqrstvwxyz")
    static let vowels: Set<Character> = ["a", "i", "u", "e", "o"]
    private static let kanaPrefixes: Set<String> = Set(kanaTable.keys.flatMap { key in
        key.indices.dropFirst().map { String(key[..<$0]) }
    })

    public static func toKana(_ raw: String) -> String {
        let chars = Array(raw.lowercased())
        var index = 0
        var output = ""

        while index < chars.count {
            let current = chars[index]
            let next: Character = index + 1 < chars.count ? chars[index + 1] : "\0"

            if current == "-" {
                output += "ー"
                index += 1
                continue
            }

            if current.isNumber {
                output.append(current)
                index += 1
                continue
            }

            if current == "n", next == "'" {
                output += "ん"
                index += 2
                continue
            }

            // Strict "nn" handling: `nn` always commits ん and consumes both
            // characters, regardless of what follows. The next character starts
            // a fresh syllable. Users who want ん+母音 (e.g. んい) type `n'i`.
            if current == "n", next == "n" {
                output += "ん"
                index += 2
                continue
            }

            if current == "n", next != "\0", !vowels.contains(next), next != "y" {
                output += "ん"
                index += 1
                continue
            }

            if consonants.contains(current), current == next, current != "n" {
                output += "っ"
                index += 1
                continue
            }

            var matched = false
            for length in [4, 3, 2, 1] where index + length <= chars.count {
                let piece = String(chars[index ..< index + length])
                if let kana = kanaTable[piece] {
                    output += kana
                    index += length
                    matched = true
                    break
                }
            }

            if !matched {
                output.append(current)
                index += 1
            }
        }

        return output
    }

    public static func toLiveKana(_ raw: String) -> String {
        let chars = Array(raw.lowercased())
        var index = 0
        var output = ""

        while index < chars.count {
            let current = chars[index]
            let next: Character = index + 1 < chars.count ? chars[index + 1] : "\0"
            let remaining = String(chars[index...])

            if current == "-" {
                output += "ー"
                index += 1
                continue
            }

            if current.isNumber {
                output.append(current)
                index += 1
                continue
            }

            if current == "n", next == "'" {
                output += "ん"
                index += 2
                continue
            }

            // Strict "nn" handling: `nn` always commits ん and consumes both
            // characters. See `toKana` for the rationale.
            if current == "n", next == "n" {
                output += "ん"
                index += 2
                continue
            }

            // Native Japanese IMEs defer a lone trailing `n` until the user
            // either doubles it (`nn` → ん) or types a non-vowel follow-up.
            // Show latin `n` in the live preview so the next keystroke can
            // still extend to na/ni/nu/ne/no/ny*. Final commit goes through
            // `toKana`, which still converts a standalone trailing `n` to ん.
            if current == "n", next == "\0" {
                output.append("n")
                break
            }

            if remainingCouldBecomeKana(remaining) {
                output += remaining
                break
            }

            if current == "n", next != "\0", !vowels.contains(next), next != "y" {
                output += "ん"
                index += 1
                continue
            }

            if consonants.contains(current), current == next, current != "n" {
                output += "っ"
                index += 1
                continue
            }

            var matched = false
            for length in [4, 3, 2, 1] where index + length <= chars.count {
                let piece = String(chars[index ..< index + length])
                if let kana = kanaTable[piece] {
                    output += kana
                    index += length
                    matched = true
                    break
                }
            }

            if !matched {
                output.append(current)
                index += 1
            }
        }

        return output
    }

    private static func remainingCouldBecomeKana(_ remaining: String) -> Bool {
        guard !remaining.isEmpty else { return false }
        guard kanaTable[remaining] == nil else { return false }
        return kanaPrefixes.contains(remaining)
    }
}
