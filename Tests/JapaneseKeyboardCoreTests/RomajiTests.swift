import XCTest
@testable import JapaneseKeyboardCore

final class RomajiTests: XCTestCase {

    // Baseline gojuuon
    func testGojuuon() {
        XCTAssertEqual(Romaji.toKana("aiueo"), "あいうえお")
        XCTAssertEqual(Romaji.toKana("kakikukeko"), "かきくけこ")
        XCTAssertEqual(Romaji.toKana("sashisuseso"), "さしすせそ")
        XCTAssertEqual(Romaji.toKana("tachitsuteto"), "たちつてと")
        XCTAssertEqual(Romaji.toKana("naninuneno"), "なにぬねの")
        XCTAssertEqual(Romaji.toKana("hahihuheho"), "はひふへほ")
        XCTAssertEqual(Romaji.toKana("mamimumemo"), "まみむめも")
        XCTAssertEqual(Romaji.toKana("yayuyo"), "やゆよ")
        XCTAssertEqual(Romaji.toKana("rarirurero"), "らりるれろ")
        XCTAssertEqual(Romaji.toKana("wawowonn"), "わををん")
    }

    func testDakutenHandakuten() {
        XCTAssertEqual(Romaji.toKana("gagigugego"), "がぎぐげご")
        XCTAssertEqual(Romaji.toKana("zajizuzezo"), "ざじずぜぞ")
        XCTAssertEqual(Romaji.toKana("dadidudedo"), "だぢづでど")
        XCTAssertEqual(Romaji.toKana("babibubebo"), "ばびぶべぼ")
        XCTAssertEqual(Romaji.toKana("papipupepo"), "ぱぴぷぺぽ")
    }

    func testYoon() {
        XCTAssertEqual(Romaji.toKana("kya"), "きゃ")
        XCTAssertEqual(Romaji.toKana("sha"), "しゃ")
        XCTAssertEqual(Romaji.toKana("cho"), "ちょ")
        XCTAssertEqual(Romaji.toKana("kyo"), "きょ")
    }

    func testSmallChars() {
        XCTAssertEqual(Romaji.toKana("xa"), "ぁ")
        XCTAssertEqual(Romaji.toKana("xtu"), "っ")
        XCTAssertEqual(Romaji.toKana("xya"), "ゃ")
    }

    func testVRow() {
        XCTAssertEqual(Romaji.toKana("va"), "ゔぁ")
        XCTAssertEqual(Romaji.toKana("vu"), "ゔ")
    }

    func testSokuon() {
        XCTAssertEqual(Romaji.toKana("kitte"), "きって")
        XCTAssertEqual(Romaji.toKana("matta"), "まった")
        XCTAssertEqual(Romaji.toKana("ippai"), "いっぱい")
        XCTAssertEqual(Romaji.toKana("cchi"), "っち")
        XCTAssertEqual(Romaji.toKana("sshi"), "っし")
    }

    func testLongVowelDash() {
        XCTAssertEqual(Romaji.toKana("ko-hi-"), "こーひー")
    }

    // Strict "nn" rule: `nn` always commits ん and consumes both characters.
    // To type ん followed by a syllable that starts with a vowel/y, use the
    // apostrophe form `n'`.
    func testKonnichiha() {
        XCTAssertEqual(Romaji.toKana("kon'nichiha"), "こんにちは")
    }

    func testKonbanha() {
        XCTAssertEqual(Romaji.toKana("konbanha"), "こんばんは")
    }

    func testArigatou() {
        XCTAssertEqual(Romaji.toKana("arigatou"), "ありがとう")
    }

    func testGomennasai() {
        XCTAssertEqual(Romaji.toKana("gomen'nasai"), "ごめんなさい")
    }

    func testSayounara() {
        XCTAssertEqual(Romaji.toKana("sayounara"), "さようなら")
    }

    func testAnna() {
        XCTAssertEqual(Romaji.toKana("an'na"), "あんな")
    }

    // Strict nn rule: `nn` consumes both n's as ん and the following character
    // starts a fresh syllable (e.g. tikinno → ちきんお, not ちきんの).
    func testStrictNNDoesNotBleedIntoNextSyllable() {
        XCTAssertEqual(Romaji.toKana("tikinno"), "ちきんお")
        XCTAssertEqual(Romaji.toKana("anna"), "あんあ")
        XCTAssertEqual(Romaji.toKana("nni"), "んい")
    }

    func testNDisambiguation() {
        XCTAssertEqual(Romaji.toKana("na"), "な")
        XCTAssertEqual(Romaji.toKana("nn"), "ん")
        XCTAssertEqual(Romaji.toKana("n'a"), "んあ")
        XCTAssertEqual(Romaji.toKana("nko"), "んこ")
        XCTAssertEqual(Romaji.toKana("nya"), "にゃ")
    }

    func testNAtEndAlone() {
        XCTAssertEqual(Romaji.toKana("n"), "ん")
        XCTAssertEqual(Romaji.toKana("hon"), "ほん")
    }

    // Live conversion: trailing partial romaji should stay as latin
    func testLiveKanaTrailingPartial() {
        XCTAssertEqual(Romaji.toLiveKana("k"), "k")
        XCTAssertEqual(Romaji.toLiveKana("ky"), "ky")
        XCTAssertEqual(Romaji.toLiveKana("kya"), "きゃ")
        XCTAssertEqual(Romaji.toLiveKana("kk"), "っk")
        XCTAssertEqual(Romaji.toLiveKana("kko"), "っこ")
    }

    func testLiveKanaProgressive() {
        // Incrementally building "kon'nichi". Trailing lone `n` defers to latin
        // (native IME behavior); `nn` commits ん; the apostrophe form `n'` is
        // needed when ん is followed by a syllable starting with a vowel/y.
        XCTAssertEqual(Romaji.toLiveKana("k"), "k")
        XCTAssertEqual(Romaji.toLiveKana("ko"), "こ")
        XCTAssertEqual(Romaji.toLiveKana("kon"), "こn")
        XCTAssertEqual(Romaji.toLiveKana("kon'"), "こん")
        XCTAssertEqual(Romaji.toLiveKana("kon'n"), "こんn")
        XCTAssertEqual(Romaji.toLiveKana("kon'ni"), "こんに")
        XCTAssertEqual(Romaji.toLiveKana("kon'nic"), "こんにc")
        XCTAssertEqual(Romaji.toLiveKana("kon'nich"), "こんにch")
        XCTAssertEqual(Romaji.toLiveKana("kon'nichi"), "こんにち")
    }

    // Trailing lone `n` stays latin in live preview; doubling or adding a
    // non-vowel/non-y follow-up still produces ん. Final commit (`toKana`)
    // is unaffected and still converts trailing `n` to ん.
    func testLiveKanaDefersTrailingN() {
        XCTAssertEqual(Romaji.toLiveKana("n"), "n")
        XCTAssertEqual(Romaji.toLiveKana("hon"), "ほn")
        XCTAssertEqual(Romaji.toLiveKana("nn"), "ん")
        XCTAssertEqual(Romaji.toLiveKana("nk"), "んk")
        XCTAssertEqual(Romaji.toLiveKana("na"), "な")
        XCTAssertEqual(Romaji.toLiveKana("ny"), "ny")
        XCTAssertEqual(Romaji.toKana("n"), "ん")
        XCTAssertEqual(Romaji.toKana("hon"), "ほん")
    }
}
