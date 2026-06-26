import XCTest
@testable import JapaneseKeyboardCore

final class FlickKanaTableTests: XCTestCase {

    func testKanaKeyDirections() {
        XCTAssertEqual(FlickKanaTable.a.center, "あ")
        XCTAssertEqual(FlickKanaTable.a.character(for: .left), "い")
        XCTAssertEqual(FlickKanaTable.a.character(for: .top), "う")
        XCTAssertEqual(FlickKanaTable.a.character(for: .right), "え")
        XCTAssertEqual(FlickKanaTable.a.character(for: .bottom), "お")
    }

    func testAllKanaKeysHaveFiveMappings() {
        let keys: [(FlickKanaTable.FlickKey, String)] = [
            (FlickKanaTable.a, "あ"),
            (FlickKanaTable.ka, "か"),
            (FlickKanaTable.sa, "さ"),
            (FlickKanaTable.ta, "た"),
            (FlickKanaTable.na, "な"),
            (FlickKanaTable.ha, "は"),
            (FlickKanaTable.ma, "ま"),
            (FlickKanaTable.ra, "ら"),
        ]
        for (key, label) in keys {
            XCTAssertNotNil(key.character(for: .left), "\(label) left")
            XCTAssertNotNil(key.character(for: .top), "\(label) top")
            XCTAssertNotNil(key.character(for: .right), "\(label) right")
            XCTAssertNotNil(key.character(for: .bottom), "\(label) bottom")
        }
    }

    func testYaKeyHasBracketsOnLeftAndRight() {
        XCTAssertEqual(FlickKanaTable.ya.center, "や")
        XCTAssertEqual(FlickKanaTable.ya.character(for: .left), "「")
        XCTAssertEqual(FlickKanaTable.ya.character(for: .right), "」")
        XCTAssertEqual(FlickKanaTable.ya.character(for: .top), "ゆ")
        XCTAssertEqual(FlickKanaTable.ya.character(for: .bottom), "よ")
    }

    func testWaKeyHasNoBottomFlick() {
        XCTAssertEqual(FlickKanaTable.wa.center, "わ")
        XCTAssertEqual(FlickKanaTable.wa.character(for: .left), "を")
        XCTAssertEqual(FlickKanaTable.wa.character(for: .top), "ん")
        XCTAssertEqual(FlickKanaTable.wa.character(for: .right), "ー")
        XCTAssertNil(FlickKanaTable.wa.character(for: .bottom))
    }

    func testKanaKeysCount() {
        XCTAssertEqual(FlickKanaTable.kanaKeys.count, 10)
    }

    func testTapCycles() {
        XCTAssertEqual(FlickKanaTable.tapCycle(for: FlickKanaTable.a), ["あ", "い", "う", "え", "お"])
        XCTAssertEqual(FlickKanaTable.tapCycle(for: FlickKanaTable.ya), ["や", "ゆ", "よ"])
        XCTAssertEqual(FlickKanaTable.tapCycle(for: FlickKanaTable.wa), ["わ", "を", "ん", "ー"])
        XCTAssertEqual(FlickKanaTable.tapCycle(for: FlickKanaTable.kutoten), ["、", "。", "？", "！", "・"])
    }

    func testSpecialKeysDoNotHaveTapCycles() {
        XCTAssertNil(FlickKanaTable.tapCycle(for: FlickKanaTable.kogaki))
        XCTAssertNil(FlickKanaTable.tapCycle(for: FlickKanaTable.kaomoji))
    }

    func testKogakiFlicks() {
        XCTAssertEqual(FlickKanaTable.kogaki.center, "小ﾞﾟ")
        XCTAssertEqual(FlickKanaTable.kogaki.character(for: .left), "ぁ")
        XCTAssertEqual(FlickKanaTable.kogaki.character(for: .top), "ゃ")
        XCTAssertEqual(FlickKanaTable.kogaki.character(for: .right), "っ")
        XCTAssertEqual(FlickKanaTable.kogaki.character(for: .bottom), "ゔ")
    }

    func testKutotenFlicks() {
        XCTAssertEqual(FlickKanaTable.kutoten.center, "、")
        XCTAssertEqual(FlickKanaTable.kutoten.character(for: .left), "。")
        XCTAssertEqual(FlickKanaTable.kutoten.character(for: .top), "？")
        XCTAssertEqual(FlickKanaTable.kutoten.character(for: .right), "！")
        XCTAssertEqual(FlickKanaTable.kutoten.character(for: .bottom), "・")
    }

    func testToggleDakuten() {
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "か"), "が")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "が"), "か")
    }

    func testToggleHaRowCyclesThroughDakutenAndHandakuten() {
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "は"), "ば")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "ば"), "ぱ")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "ぱ"), "は")
    }

    func testToggleSmallVowels() {
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "あ"), "ぁ")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "ぁ"), "あ")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "つ"), "っ")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "っ"), "つ")
    }

    func testToggleSmallYoon() {
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "や"), "ゃ")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "ゃ"), "や")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "ゆ"), "ゅ")
        XCTAssertEqual(FlickKanaTable.toggledForm(of: "よ"), "ょ")
    }

    func testToggleReturnsNilForNoAlternate() {
        XCTAssertNil(FlickKanaTable.toggledForm(of: "ん"))
        XCTAssertNil(FlickKanaTable.toggledForm(of: "ー"))
        XCTAssertNil(FlickKanaTable.toggledForm(of: "、"))
    }
}
