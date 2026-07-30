import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

// Scores every eval case's candidate pool with the zenz model under several
// prompt formats and reports whether rescoring beats the pool's frequency
// order at putting a gold continuation first. Latency is NOT measured here
// (mac + Metal llama says nothing about the extension) — this probe is about
// ranking quality only.

let weightURL = URL(fileURLWithPath: "/Users/itsuki/Desktop/key/Japanese/Sources/JapaneseKeyboardCore/Resources/zenz-xsmall.gguf")
guard FileManager.default.fileExists(atPath: weightURL.path) else {
    FileHandle.standardError.write("zenz weight not found at \(weightURL.path)\n".data(using: .utf8)!)
    exit(1)
}

let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("RescoreProbe", isDirectory: true)
try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

let options = ConvertRequestOptions(
    N_best: 10, needTypoCorrection: false,
    requireJapanesePrediction: false, requireEnglishPrediction: false,
    keyboardLanguage: .ja_JP, englishCandidateInRoman2KanaInput: false,
    fullWidthRomanCandidate: false, halfWidthKanaCandidate: false,
    learningType: .nothing, maxMemoryCount: 0, shouldResetMemory: false,
    memoryDirectoryURL: tmp, sharedContainerURL: tmp,
    textReplacer: .empty,
    specialCandidateProviders: KanaKanjiConverter.defaultSpecialCandidateProviders,
    zenzaiMode: .on(weight: weightURL, inferenceLimit: 1, personalizationMode: nil, versionDependentMode: .v3(.init())),
    metadata: .init(versionString: "RescoreProbe/1.0")
)

let converter = KanaKanjiConverter.withDefaultDictionary()

// Prompt formats under test. v3 conversion prompts are
// "\u{EE02}<context>\u{EE00}<input>\u{EE01}<output>"; predict_next_character
// (v2 era) used "\u{EE00}。\u{EE02}<context>" and let the model continue the
// context directly.
let formats: [(name: String, wrap: (String) -> String)] = [
    ("raw", { $0 }),
    ("v3ctx", { "\u{EE02}" + $0 }),
    ("v2trick", { "\u{EE00}。\u{EE02}" + $0 }),
]

struct Tally {
    var top1 = 0
    var mrrSum = 0.0
    mutating func record(rank: Int?) {
        if rank == 1 { top1 += 1 }
        mrrSum += rank.map { 1.0 / Double($0) } ?? 0
    }
}

// Rank (1-based) of the best-placed gold candidate under `order`.
func goldRank(order: [String], gold: Set<String>) -> Int? {
    for (i, c) in order.enumerated() where gold.contains(c) { return i + 1 }
    return nil
}

var baseline = Tally()
var tallies: [String: Tally] = [:]
var misses: [String: [String]] = [:]
// group → per-format count of cases whose gold ranked 1st (for contrast-pair resolution)
var groupWins: [String: [String: Int]] = [:]
var groupSizes: [String: Int] = [:]

for evalCase in evalCases {
    groupSizes[evalCase.group, default: 0] += 1
    baseline.record(rank: goldRank(order: evalCase.pool, gold: evalCase.gold))
    for format in formats {
        guard let scores = converter.evaluateZenzaiContinuations(evalCase.pool, prompt: format.wrap(evalCase.context), options: options) else {
            FileHandle.standardError.write("model unavailable\n".data(using: .utf8)!)
            exit(1)
        }
        let order = zip(evalCase.pool, scores).sorted { $0.1 > $1.1 }.map(\.0)
        let rank = goldRank(order: order, gold: evalCase.gold)
        tallies[format.name, default: Tally()].record(rank: rank)
        if rank == 1 {
            groupWins[evalCase.group, default: [:]][format.name, default: 0] += 1
        } else {
            misses[format.name, default: []].append("  [\(evalCase.group)] \(evalCase.context)→ gold=\(evalCase.gold.sorted().joined(separator: "/")) got=\(order.prefix(3).joined(separator: ","))")
        }
    }
}

let n = evalCases.count
print("cases: \(n)\n")
print(String(format: "%-8@  top1          MRR", "format" as NSString))
print(String(format: "%-8@  %3d/%d (%2.0f%%)  %.3f", "baseline" as NSString, baseline.top1, n, 100.0 * Double(baseline.top1) / Double(n), baseline.mrrSum / Double(n)))
for format in formats {
    let t = tallies[format.name]!
    print(String(format: "%-8@  %3d/%d (%2.0f%%)  %.3f", format.name as NSString, t.top1, n, 100.0 * Double(t.top1) / Double(n), t.mrrSum / Double(n)))
}

// A group is "resolved" when every case in it ranked a gold first — the
// context-sensitivity headline (frequency order can never resolve a group
// whose golds differ).
print("\ngroup resolution (all cases in group top-1):")
let groups = groupSizes.keys.sorted()
for format in formats {
    let resolved = groups.filter { groupWins[$0]?[format.name] ?? 0 == groupSizes[$0]! }.count
    print("  \(format.name): \(resolved)/\(groups.count) groups")
}

for format in formats {
    guard let lines = misses[format.name], !lines.isEmpty else { continue }
    print("\nmisses (\(format.name)):")
    lines.forEach { print($0) }
}
