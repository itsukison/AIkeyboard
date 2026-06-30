import Foundation

/// Read-only, memory-mapped next-word prior: morpheme → likely next morphemes,
/// built offline from the NWC2010 web-corpus word 2-grams (see
/// `scripts/build_nextword_prior.py`). Keyed on the *last morpheme* of a
/// committed word because Japanese is head-final — what follows a committed
/// chunk is determined mostly by its final morpheme (食べ**たい** → と/です/の …).
///
/// The table is mmap'd, never fully loaded: a lookup binary-searches the index
/// and touches only a handful of pages, so resident memory stays flat
/// regardless of table size (keeps us clear of the extension jetsam ceiling).
///
/// Binary format (little-endian) — produced by the build script:
/// ```
/// magic    : 4 bytes "NWP1"
/// keyCount : uint32
/// index    : keyCount × (keyOff:uint32 keyLen:uint16 valOff:uint32 valLen:uint16)  // absolute offsets, keys sorted by UTF-8 bytes
/// keysBlob : concatenated key UTF-8
/// valsBlob : per key, repeated (nextLen:uint8, next UTF-8, weight:uint8), most-frequent first
/// ```
public final class NextWordPrior: Sendable {
    public static let shared: NextWordPrior? = {
        guard let url = Bundle.module.url(forResource: "nextword_prior", withExtension: "bin") else {
            return nil
        }
        return NextWordPrior(url: url)
    }()

    /// Trigram table: morpheme *pair* → likely third morpheme, same binary
    /// format keyed on `first<U+001F>second` (see `build_nextword_trigram.py`).
    /// nil until the table is built and bundled; callers back off to `shared`.
    public static let sharedTrigram: NextWordPrior? = {
        guard let url = Bundle.module.url(forResource: "nextword_trigram", withExtension: "bin") else {
            return nil
        }
        return NextWordPrior(url: url)
    }()

    /// English unigram table: word → (empty next, frequency weight), keyed on the
    /// word and sorted by UTF-8 bytes so `completions(prefix:)` can prefix-scan.
    /// Built by `scripts/build_english_ngram.py`; nil until generated + bundled.
    public static let englishUnigram: NextWordPrior? = load("english_unigram")

    /// English bigram table: word → likely next words, same NWP1 format as the
    /// Japanese prior, used by `suggestions(after:)`. nil until generated.
    public static let englishBigram: NextWordPrior? = load("english_bigram")

    private static func load(_ name: String) -> NextWordPrior? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "bin") else {
            return nil
        }
        return NextWordPrior(url: url)
    }

    /// Separator joining the two preceding morphemes into a trigram key.
    /// Must match `SEP` in `scripts/build_nextword_trigram.py`.
    private static let keySeparator = "\u{1f}"

    private let data: Data
    private let count: Int

    public init?(url: URL) {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= 8,
              data.prefix(4).elementsEqual("NWP1".utf8) else {
            return nil
        }
        self.data = data
        self.count = Int(data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self)
        }.littleEndian)
    }

    /// Likely next morphemes after the pair `first second` (a trigram lookup),
    /// most-frequent first, or empty if the pair isn't in the table. Build the
    /// composite key the builder used so the same binary search hits it.
    public func suggestions(after first: String, _ second: String) -> [String] {
        guard !first.isEmpty, !second.isEmpty else { return [] }
        return suggestions(after: first + Self.keySeparator + second)
    }

    /// Likely next morphemes after `morpheme`, most-frequent first (≤ 8), or
    /// empty if the morpheme isn't in the table.
    public func suggestions(after morpheme: String) -> [String] {
        guard count > 0, !morpheme.isEmpty else { return [] }
        let query = Array(morpheme.utf8)
        return data.withUnsafeBytes { raw -> [String] in
            let base = raw.baseAddress!
            var lo = 0
            var hi = count - 1
            while lo <= hi {
                let mid = (lo + hi) / 2
                let rec = base.advanced(by: 8 + mid * 12)
                let keyOff = Int(rec.loadUnaligned(as: UInt32.self).littleEndian)
                let keyLen = Int(rec.loadUnaligned(fromByteOffset: 4, as: UInt16.self).littleEndian)
                let cmp = Self.compare(base.advanced(by: keyOff), keyLen, query)
                if cmp == 0 {
                    let valOff = Int(rec.loadUnaligned(fromByteOffset: 6, as: UInt32.self).littleEndian)
                    let valLen = Int(rec.loadUnaligned(fromByteOffset: 10, as: UInt16.self).littleEndian)
                    return Self.decode(base.advanced(by: valOff), valLen)
                } else if cmp < 0 {
                    lo = mid + 1
                } else {
                    hi = mid - 1
                }
            }
            return []
        }
    }

    /// Words sharing `prefix` (a prefix lower-bound search over the sorted index
    /// then a forward scan), ranked by stored frequency weight, then shorter
    /// first, then alphabetically. Used for English word completion. Empty if the
    /// table is the bigram/Japanese kind or nothing matches.
    public func completions(prefix: String, limit: Int = 8) -> [String] {
        guard count > 0 else { return [] }
        let needle = Array(prefix.utf8)
        guard !needle.isEmpty else { return [] }
        return data.withUnsafeBytes { raw -> [String] in
            let base = raw.baseAddress!
            // Lower bound: first index whose key is >= needle.
            var lo = 0
            var hi = count
            while lo < hi {
                let mid = (lo + hi) / 2
                let rec = base.advanced(by: 8 + mid * 12)
                let keyOff = Int(rec.loadUnaligned(as: UInt32.self).littleEndian)
                let keyLen = Int(rec.loadUnaligned(fromByteOffset: 4, as: UInt16.self).littleEndian)
                if Self.compare(base.advanced(by: keyOff), keyLen, needle) < 0 {
                    lo = mid + 1
                } else {
                    hi = mid
                }
            }
            var matches: [(word: String, weight: Int, len: Int)] = []
            var i = lo
            while i < count {
                let rec = base.advanced(by: 8 + i * 12)
                let keyOff = Int(rec.loadUnaligned(as: UInt32.self).littleEndian)
                let keyLen = Int(rec.loadUnaligned(fromByteOffset: 4, as: UInt16.self).littleEndian)
                guard Self.hasPrefix(base.advanced(by: keyOff), keyLen, needle) else { break }
                let valOff = Int(rec.loadUnaligned(fromByteOffset: 6, as: UInt32.self).littleEndian)
                let valLen = Int(rec.loadUnaligned(fromByteOffset: 10, as: UInt16.self).littleEndian)
                let kp = base.advanced(by: keyOff).assumingMemoryBound(to: UInt8.self)
                let word = String(decoding: UnsafeBufferPointer(start: kp, count: keyLen), as: UTF8.self)
                matches.append((word, Self.firstWeight(base.advanced(by: valOff), valLen), keyLen))
                i += 1
                if matches.count >= 20000 { break } // runaway guard for 1-char prefixes
            }
            return matches
                .sorted { a, b in
                    if a.weight != b.weight { return a.weight > b.weight }
                    if a.len != b.len { return a.len < b.len }
                    return a.word < b.word
                }
                .prefix(limit)
                .map(\.word)
        }
    }

    /// The frequency weight stored for an exact key, or nil if the key is absent.
    /// Doubles as a dictionary membership test for the unigram table.
    public func weight(for key: String) -> Int? {
        guard count > 0, !key.isEmpty else { return nil }
        let query = Array(key.utf8)
        return data.withUnsafeBytes { raw -> Int? in
            let base = raw.baseAddress!
            var lo = 0
            var hi = count - 1
            while lo <= hi {
                let mid = (lo + hi) / 2
                let rec = base.advanced(by: 8 + mid * 12)
                let keyOff = Int(rec.loadUnaligned(as: UInt32.self).littleEndian)
                let keyLen = Int(rec.loadUnaligned(fromByteOffset: 4, as: UInt16.self).littleEndian)
                let cmp = Self.compare(base.advanced(by: keyOff), keyLen, query)
                if cmp == 0 {
                    let valOff = Int(rec.loadUnaligned(fromByteOffset: 6, as: UInt32.self).littleEndian)
                    let valLen = Int(rec.loadUnaligned(fromByteOffset: 10, as: UInt16.self).littleEndian)
                    return Self.firstWeight(base.advanced(by: valOff), valLen)
                } else if cmp < 0 {
                    lo = mid + 1
                } else {
                    hi = mid - 1
                }
            }
            return nil
        }
    }

    /// Weight byte of the first value entry: layout is (nlen:uint8, next, weight:uint8).
    private static func firstWeight(_ ptr: UnsafeRawPointer, _ len: Int) -> Int {
        guard len >= 1 else { return 0 }
        let p = ptr.assumingMemoryBound(to: UInt8.self)
        let weightIdx = 1 + Int(p[0])
        guard weightIdx < len else { return 0 }
        return Int(p[weightIdx])
    }

    /// Whether the stored key begins with `needle`'s bytes.
    private static func hasPrefix(_ keyPtr: UnsafeRawPointer, _ keyLen: Int, _ needle: [UInt8]) -> Bool {
        guard keyLen >= needle.count else { return false }
        let k = keyPtr.assumingMemoryBound(to: UInt8.self)
        var i = 0
        while i < needle.count {
            if k[i] != needle[i] { return false }
            i += 1
        }
        return true
    }

    /// memcmp-style compare of a stored key against the query, matching the
    /// builder's UTF-8 byte sort (a prefix sorts before the longer string).
    private static func compare(_ keyPtr: UnsafeRawPointer, _ keyLen: Int, _ query: [UInt8]) -> Int {
        let k = keyPtr.assumingMemoryBound(to: UInt8.self)
        let n = min(keyLen, query.count)
        var i = 0
        while i < n {
            if k[i] != query[i] { return k[i] < query[i] ? -1 : 1 }
            i += 1
        }
        if keyLen == query.count { return 0 }
        return keyLen < query.count ? -1 : 1
    }

    private static func decode(_ ptr: UnsafeRawPointer, _ len: Int) -> [String] {
        let p = ptr.assumingMemoryBound(to: UInt8.self)
        var out: [String] = []
        var i = 0
        while i < len {
            let nlen = Int(p[i])
            i += 1
            if i + nlen > len { break }
            out.append(String(decoding: UnsafeBufferPointer(start: p + i, count: nlen), as: UTF8.self))
            i += nlen
            if i >= len { break }
            i += 1 // weight byte: stored most-frequent-first, not needed for ordering
        }
        return out
    }
}
