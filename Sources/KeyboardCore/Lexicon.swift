import Foundation

/// Bundled English and programming words with word frequencies, held as one
/// sorted byte buffer (roughly 0.5 MB for the bundled list). Load it once, off
/// the main thread, and share it between autocorrect, swipe, and suggestions.
/// It contains no user text and is never written back.
public final class Lexicon: Sendable {
    /// Frequencies use the Zipf scale: log10 of occurrences per billion words.
    static let maximumZipf = 7.6
    /// Listed words that the frequency source does not measure.
    static let unmeasuredZipf = 2.0
    /// Programming terms are ordinary here even when books rarely use them.
    static let codeZipfFloor = 4.0

    static let codeVocabulary = "hello world name value values result results message messages input output data file files path text string number count index item items list array dictionary key keys object options config settings language keyboard code script function return class struct import export async await error errors success failure true false null print console write read open close append remove insert update delete fetch request response server client token user users command terminal python swift javascript typescript shell json git status commit push pull branch checkout switch let var const if else guard while for case default public private static protocol extension throws catch try self init main view model state binding body some type interface map filter reduce sort first last length size width height color frame content label button title padding spacing start stop test tests debug build run install select selection cursor tab space indent format pair braces bracket parenthesis angle quote and or not in is as from with def pass raise except finally yield echo printf source chmod mkdir touch curl docker node npm ssh cd ls pwd cat grep find sed awk sudo exit done then fi esac home end left right up down page escape control delete backspace reset save load copy paste search replace split join contains hasPrefix hasSuffix lowercased uppercased description identifier set get optional required available task actor weak final override mutating nonisolated associatedtype deinit continue break defer enumerate range len str int float bool super property await Promise boolean readonly implements typeof undefined instanceof new this void never unknown any do throw interface number boolean".components(separatedBy: " ")

    private let bytes: [UInt8]
    private let offsets: [UInt32]
    /// Zipf × 10; zero means unmeasured.
    private let frequencies: [UInt8]

    public var count: Int { offsets.count - 1 }
    /// Resident size of the word storage, excluding small fixed overhead.
    public var estimatedBytes: Int { bytes.count + offsets.count * 4 + frequencies.count }

    /// Builds a lexicon from arbitrary words. Words are folded to lowercase;
    /// anything other than 2–32 ASCII letters is skipped. A nil frequency is
    /// treated as unmeasured. Duplicate words keep their highest frequency.
    public convenience init(words: [String], frequencies: [String: Double] = [:], codeWords: [String] = []) {
        var entries: [[UInt8]: UInt8] = [:]
        func add(_ word: String, _ tenths: UInt8) {
            guard let key = Self.normalized(word) else { return }
            entries[key] = max(entries[key] ?? 0, tenths)
        }
        for word in words { add(word, frequencies[word.lowercased()].map(Self.tenths) ?? 0) }
        for word in codeWords { add(word, Self.tenths(Self.codeZipfFloor)) }
        self.init(sorted: entries.sorted { $0.key.lexicographicallyPrecedes($1.key) })
    }

    private init(sorted entries: some Sequence<([UInt8], UInt8)>) {
        var bytes: [UInt8] = [], offsets: [UInt32] = [0], frequencies: [UInt8] = []
        for (word, tenths) in entries {
            bytes += word
            offsets.append(UInt32(bytes.count))
            frequencies.append(tenths)
        }
        self.bytes = bytes; self.offsets = offsets; self.frequencies = frequencies
    }

    /// Loads the bundled list: ESDB words, SymSpell frequencies, programming
    /// terms, and any extra keywords. Returns nil if the resources are missing
    /// or out of order. The files are memory-mapped and streamed straight into
    /// the final buffers, so loading allocates little beyond the result.
    public static func bundled(extraWords: [String] = []) -> Lexicon? {
        guard let wordsURL = Bundle.module.url(forResource: "swipe-english", withExtension: "txt"),
              let frequencyURL = Bundle.module.url(forResource: "english-frequency", withExtension: "txt"),
              let words = try? Data(contentsOf: wordsURL, options: .alwaysMapped),
              let frequencies = try? Data(contentsOf: frequencyURL, options: .alwaysMapped) else { return nil }
        let extras = Set((codeVocabulary + extraWords).compactMap(normalized)).sorted { $0.lexicographicallyPrecedes($1) }
        let codeTenths = tenths(codeZipfFloor)
        var bytes: [UInt8] = [], offsets: [UInt32] = [0], values: [UInt8] = []
        bytes.reserveCapacity(words.count)
        offsets.reserveCapacity(40_000)
        values.reserveCapacity(40_000)
        func append(_ word: [UInt8], _ tenths: UInt8) -> Bool {
            if let last = offsets.dropLast().last,
               !bytes[Int(last)...].lexicographicallyPrecedes(word) { return false }
            bytes += word
            offsets.append(UInt32(bytes.count))
            values.append(tenths)
            return true
        }
        let sorted = words.withUnsafeBytes { wordFile in
            frequencies.withUnsafeBytes { frequencyFile in
                // Both files list words in the same sorted order, so one pass
                // pairs each word with its frequency and slots in the extras.
                var measured = Lines(frequencyFile)
                var next = measured.next()
                var extra = 0
                var lines = Lines(wordFile)
                while let line = lines.next() {
                    guard let word = normalized(wordFile[line]) else { continue }
                    while extra < extras.count, extras[extra].lexicographicallyPrecedes(word) {
                        guard append(extras[extra], codeTenths) else { return false }
                        extra += 1
                    }
                    var value: UInt8 = 0
                    while let entry = next, let tab = frequencyFile[entry].firstIndex(of: 9) {
                        let key = frequencyFile[entry.lowerBound..<tab]
                        if key.lexicographicallyPrecedes(word) { next = measured.next(); continue }
                        if key.elementsEqual(word) {
                            value = UInt8(clamping: frequencyFile[(tab + 1)..<entry.upperBound]
                                .reduce(0) { $1 >= 48 && $1 <= 57 ? $0 * 10 + Int($1 - 48) : $0 })
                            next = measured.next()
                        }
                        break
                    }
                    if extra < extras.count, extras[extra] == word { value = max(value, codeTenths); extra += 1 }
                    guard append(word, value) else { return false }
                }
                for word in extras[extra...] { guard append(word, codeTenths) else { return false } }
                return true
            }
        }
        guard sorted else { return nil }
        return Lexicon(bytes: bytes, offsets: offsets, frequencies: values)
    }

    private init(bytes: [UInt8], offsets: [UInt32], frequencies: [UInt8]) {
        self.bytes = bytes; self.offsets = offsets; self.frequencies = frequencies
    }

    /// Non-empty lines that are not `#` comments, as byte ranges.
    private struct Lines: IteratorProtocol {
        let buffer: UnsafeRawBufferPointer
        var position = 0
        init(_ buffer: UnsafeRawBufferPointer) { self.buffer = buffer }
        mutating func next() -> Range<Int>? {
            while position < buffer.count {
                let start = position
                while position < buffer.count, buffer[position] != 10 { position += 1 }
                let line = start..<position
                position += 1
                if !line.isEmpty, buffer[start] != 35 { return line }
            }
            return nil
        }
    }

    static func normalized(_ word: some Sequence<UInt8>) -> [UInt8]? {
        var result: [UInt8] = []
        for byte in word {
            switch byte {
            case 97...122: result.append(byte)
            case 65...90: result.append(byte + 32)
            case 13: continue
            default: return nil
            }
        }
        return (2...32).contains(result.count) ? result : nil
    }

    static func normalized(_ word: String) -> [UInt8]? { normalized(word.utf8) }

    private static func tenths(_ zipf: Double) -> UInt8 { UInt8(clamping: Int((zipf * 10).rounded())) }

    // MARK: Lookup

    func word(at index: Int) -> ArraySlice<UInt8> { bytes[Int(offsets[index])..<Int(offsets[index + 1])] }
    func length(at index: Int) -> Int { Int(offsets[index + 1] - offsets[index]) }
    func zipf(at index: Int) -> Double {
        frequencies[index] == 0 ? Self.unmeasuredZipf : Double(frequencies[index]) / 10
    }
    func string(at index: Int) -> String { String(decoding: word(at: index), as: UTF8.self) }

    /// The first index whose word is not ordered before `key`.
    private func lowerBound(_ key: [UInt8]) -> Int {
        var low = 0, high = count
        while low < high {
            let middle = (low + high) / 2
            if word(at: middle).lexicographicallyPrecedes(key) { low = middle + 1 } else { high = middle }
        }
        return low
    }

    /// Indices of the words that begin with `letter`.
    func range(startingWith letter: UInt8) -> Range<Int> {
        lowerBound([letter])..<(letter == 255 ? count : lowerBound([letter + 1]))
    }

    func index(of word: String) -> Int? {
        guard let key = Self.normalized(word) else { return nil }
        let index = lowerBound(key)
        return index < count && self.word(at: index).elementsEqual(key) ? index : nil
    }

    public func contains(_ word: String) -> Bool { index(of: word) != nil }

    /// The word's Zipf frequency, or nil when it is not listed.
    public func zipf(_ word: String) -> Double? { index(of: word).map(zipf(at:)) }

    /// The most frequent listed words that extend `prefix`, most frequent first.
    public func completions(prefix: String, limit: Int) -> [String] {
        guard limit > 0, let key = Self.normalized(prefix) else { return [] }
        var best: [(Int, UInt8)] = []
        var index = lowerBound(key)
        while index < count, word(at: index).starts(with: key) {
            if length(at: index) > key.count {
                best.append((index, frequencies[index]))
                if best.count > limit * 8 {
                    best.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
                    best.removeLast(best.count - limit)
                }
            }
            index += 1
        }
        best.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
        return best.prefix(limit).map { string(at: $0.0) }
    }
}
