import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("ConvProbeUserDict", isDirectory: true)
try? FileManager.default.removeItem(at: tmp)
try! FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

func makeOptions() -> ConvertRequestOptions {
    ConvertRequestOptions(
        N_best: 20, needTypoCorrection: true,
        requireJapanesePrediction: true, requireEnglishPrediction: false,
        keyboardLanguage: .ja_JP, englishCandidateInRoman2KanaInput: false,
        fullWidthRomanCandidate: false, halfWidthKanaCandidate: false,
        learningType: .nothing, maxMemoryCount: 0, shouldResetMemory: false,
        memoryDirectoryURL: tmp, sharedContainerURL: tmp,
        textReplacer: .empty,
        specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
        zenzaiMode: .off,
        metadata: .init(versionString: "ConvProbeZ/1.0")
    )
}

// Katakana (U+30A1-U+30F6) -> Hiragana by shifting down 0x60. ー is left as-is.
func katakanaToHiragana(_ s: String) -> String {
    var scalars: [Unicode.Scalar] = []
    scalars.reserveCapacity(s.unicodeScalars.count)
    for scalar in s.unicodeScalars {
        if scalar.value >= 0x30A1 && scalar.value <= 0x30F6 {
            scalars.append(Unicode.Scalar(scalar.value - 0x60)!)
        } else {
            scalars.append(scalar)
        }
    }
    var result = ""
    result.unicodeScalars.append(contentsOf: scalars)
    return result
}

func eprint(_ s: String) {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
}

guard CommandLine.arguments.count > 1 else {
    eprint("Usage: ConvProbeZ <check tsv> [gapfill tsv (reading<TAB>word) to install as user dict]")
    exit(1)
}
let tsvPath = CommandLine.arguments[1]
let showCandidates = ProcessInfo.processInfo.environment["CONVPROBE_SHOW_CANDIDATES"] == "1"

// Optional: install a gap-fill TSV as the user dictionary (mirrors what
// KanaKanjiAdapter.installGapFillDictionary does in the app).
if CommandLine.arguments.count > 2 {
    // The dictionary's charID.chid lives in the azooKey resource bundle,
    // which SPM places next to the built executable.
    let charIDURL = Bundle.main.bundleURL
        .appendingPathComponent("AzooKeyKanaKanjiConverter_KanaKanjiConverterModuleWithDefaultDictionary.bundle", isDirectory: true)
        .appendingPathComponent("Dictionary/louds/charID.chid", isDirectory: false)
    let gapContent = try! String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
    let entries: [DicdataElement] = gapContent.split(separator: "\n").compactMap { line in
        let cols = line.split(separator: "\t")
        guard cols.count >= 2 else { return nil }
        return DicdataElement(word: String(cols[1]), ruby: String(cols[0]), cid: CIDData.一般名詞.cid, mid: MIDData.一般.mid, value: -9)
    }
    try! DictionaryBuilder.exportDictionary(entries: entries, to: tmp, baseName: "user", shardByFirstCharacter: false, charIDFileURL: charIDURL)
    eprint("installed \(entries.count) gap-fill entries as user dict")
}
guard let data = FileManager.default.contents(atPath: tsvPath),
      let content = String(data: data, encoding: .utf8) else {
    eprint("Failed to read \(tsvPath)")
    exit(1)
}

let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
eprint("total lines: \(lines.count)")

var converter = KanaKanjiConverter.withDefaultDictionary()
var processed = 0

for line in lines {
    let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
    guard parts.count >= 3 else { continue }
    let surface = String(parts[0])
    let reading = String(parts[1])
    let freqCount = String(parts[2])
    let hiragana = katakanaToHiragana(reading)

    var composing = ComposingText()
    composing.insertAtCursorPosition(hiragana, inputStyle: .direct)
    let result = converter.requestCandidates(composing, options: makeOptions())
    let texts = result.mainResults.map(\.text)
    let hit = texts.firstIndex(of: surface)
    let rankStr = hit.map { String($0 + 1) } ?? "ABSENT"
    print("GAPRESULT\t\(surface)\t\(reading)\t\(freqCount)\t\(rankStr)")
    if showCandidates && (hit == nil || hit! >= 3) {
        print("GAPCANDIDATES\t\(surface)\t\(reading)\t\(texts.prefix(10).joined(separator: "|"))")
    }
    converter.stopComposition()

    processed += 1
    if processed % 1000 == 0 {
        eprint("progress: \(processed)/\(lines.count)")
    }
    if processed % 2000 == 0 {
        converter = KanaKanjiConverter.withDefaultDictionary()
    }
}
eprint("DONE processed=\(processed)")
