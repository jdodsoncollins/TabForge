import Foundation

public struct SwipePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    func distance(to point: Self) -> Double { hypot(x - point.x, y - point.y) }
}

/// Offline geometric recognizer. Keep one instance while swipe is enabled, then
/// discard it on dismissal or memory pressure. No gesture or document text is retained.
public struct SwipeDecoder: Sendable {
    private let lexicon: Lexicon
    /// Lexicon indices grouped by first and last letter.
    private let endpoints: [UInt16: [UInt32]]
    /// How much word frequency counts against shape, in key pitches per Zipf step.
    static let priorWeight = 0.02

    /// Bundled English words plus programming terms. Loading is local and deterministic.
    /// Decoders share the compact ``Lexicon`` instead of this list.
    public static var vocabulary: [String] {
        guard let url = Bundle.module.url(forResource: "swipe-english", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return Lexicon.codeVocabulary }
        return Lexicon.codeVocabulary + text.split(separator: "\n").filter { !$0.hasPrefix("#") }.map(String.init)
    }

    /// Shares an already loaded lexicon, including its word frequencies.
    public init(lexicon: Lexicon) {
        var endpoints: [UInt16: [UInt32]] = [:]
        for index in 0..<lexicon.count {
            let word = lexicon.word(at: index)
            guard let first = word.first, let last = word.last, Self.letters(word).count >= 2 else { continue }
            endpoints[Self.key(first, last), default: []].append(UInt32(index))
        }
        self.lexicon = lexicon
        self.endpoints = endpoints
    }

    /// Uses the given words without frequencies, or the bundled lexicon when nil.
    public init(words: [String]? = nil) {
        let lexicon = words.map { Lexicon(words: $0) } ?? Lexicon.bundled() ?? Lexicon(words: Lexicon.codeVocabulary)
        self.init(lexicon: lexicon)
    }

    private static func key(_ first: UInt8, _ last: UInt8) -> UInt16 { UInt16(first) << 8 | UInt16(last) }

    /// A path visits a repeated letter once.
    private static func letters(_ word: some Collection<UInt8>) -> [UInt8] {
        var result: [UInt8] = []
        for letter in word where result.last != letter { result.append(letter) }
        return result
    }

    public static func candidates(trace: [SwipePoint], centers: [Character: SwipePoint], words: [String]? = nil) -> [String] {
        Self(words: words).candidates(trace: trace, centers: centers)
    }

    /// Up to three words, best first. Words from `document` can be produced in
    /// their document spelling, such as `userName`, and rank like common words.
    public func candidates(trace: [SwipePoint], centers: [Character: SwipePoint],
                           document: DocumentVocabulary = .init()) -> [String] {
        guard (2...4096).contains(trace.count), trace.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              let firstSample = trace.first, let lastSample = trace.last,
              let geometry = KeyGeometry(centers: centers) else { return [] }
        let path = trace.map(geometry.normalize)
        let length = zip(path, path.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
        guard length.isFinite, length > 0.5 else { return [] }
        let sampled = Self.resample(path, count: 32)
        let start = geometry.normalize(firstSample), end = geometry.normalize(lastSample)
        let keys = geometry.letterCenters
        let positions = Dictionary(uniqueKeysWithValues: keys)
        let starts = keys.filter { start.distance(to: $0.1) < 1.15 }
        let ends = keys.filter { end.distance(to: $0.1) < 1.15 }

        // Document words that the lexicon lacks join the same endpoint buckets.
        var extra: [UInt16: [(String, [UInt8])]] = [:]
        for spelling in document.letterWords {
            let folded = Array(spelling.lowercased().utf8)
            guard folded.count >= 2, !lexicon.contains(spelling), let first = folded.first, let last = folded.last else { continue }
            extra[Self.key(first, last), default: []].append((spelling, folded))
        }
        struct Candidate { let word: String; let letters: [UInt8]; let zipf: Double; let shape: Double; let endpoints: Double }
        var best: [Candidate] = []
        func consider(_ word: () -> String, _ folded: some Collection<UInt8>, zipf: () -> Double, _ endpoints: Double) {
            let letters = Self.letters(folded)
            guard letters.count >= 2 else { return }
            let points = letters.compactMap { positions[$0] }
            guard points.count == letters.count else { return }
            let template = Self.resample(points, count: 32)
            let shape = zip(sampled, template).reduce(0.0) { $0 + $1.0.distance(to: $1.1) } / 32
            guard shape < 0.85 else { return }
            best.append(Candidate(word: word(), letters: letters, zipf: zipf(), shape: shape, endpoints: endpoints))
        }
        // End-point buckets avoid scanning and resampling the entire dictionary per gesture.
        for (first, a) in starts {
            for (last, b) in ends {
                let distance = start.distance(to: a) + end.distance(to: b)
                for index in endpoints[Self.key(first, last)] ?? [] {
                    let index = Int(index)
                    consider({ lexicon.string(at: index) }, lexicon.word(at: index), zipf: { lexicon.zipf(at: index) }, distance)
                }
                for (spelling, folded) in extra[Self.key(first, last)] ?? [] {
                    consider({ spelling }, folded, zipf: { TouchCorrector.documentZipf }, distance)
                }
            }
        }
        // Arc-length sampling removes speed differences but aligns rounded
        // corners poorly. Rerank a bounded shortlist with elastic alignment,
        // allowing a corner to occur a few samples earlier or later.
        let shortlist = best.sorted {
            let a = $0.shape + $0.endpoints * 0.7
            let b = $1.shape + $1.endpoints * 0.7
            return a == b ? $0.word < $1.word : a < b
        }.prefix(48)
        let reranked: [(String, Double)] = shortlist.map { candidate in
            let points: [SwipePoint] = candidate.letters.compactMap { positions[$0] }
            let template = Self.resample(points, count: 32)
            let spelling = document.spelling(of: candidate.word)
            // A small frequency prior breaks near-ties between paths that fit
            // almost equally well. Words used in the document count as common.
            let zipf = spelling == nil ? candidate.zipf : max(candidate.zipf, TouchCorrector.documentZipf)
            let prior = Self.priorWeight * max(0, Lexicon.maximumZipf - zipf)
            let score = Self.elasticDistance(sampled, template) + candidate.endpoints * 0.7 + prior
            return (spelling.flatMap { $0.allSatisfy(\.isLetter) ? $0 : nil } ?? candidate.word, score)
        }
        var seen = Set<String>()
        return reranked.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }
            .filter { seen.insert($0.0).inserted }.prefix(3).map(\.0)
    }

    private static func elasticDistance(_ trace: [SwipePoint], _ template: [SwipePoint]) -> Double {
        let count = trace.count
        var previous = Array(repeating: Double.infinity, count: count + 1)
        previous[0] = 0
        for i in 1...count {
            var current = Array(repeating: Double.infinity, count: count + 1)
            for j in max(1, i - 4)...min(count, i + 4) {
                current[j] = trace[i - 1].distance(to: template[j - 1]) +
                    min(previous[j - 1], previous[j], current[j - 1])
            }
            previous = current
        }
        return previous[count] / Double(count)
    }

    private static func resample(_ points: [SwipePoint], count: Int) -> [SwipePoint] {
        guard let first = points.first, let last = points.last else { return [] }
        var distances = [0.0]
        for pair in zip(points, points.dropFirst()) { distances.append(distances.last! + pair.0.distance(to: pair.1)) }
        guard let length = distances.last, length > 0 else { return Array(repeating: first, count: count) }
        var segment = 1
        return (0..<count).map { index in
            let target = length * Double(index) / Double(count - 1)
            while segment < distances.count - 1 && distances[segment] < target { segment += 1 }
            guard segment < points.count else { return last }
            let denominator = distances[segment] - distances[segment - 1]
            let fraction = denominator > 0 ? (target - distances[segment - 1]) / denominator : 0
            let a = points[segment - 1], b = points[segment]
            return SwipePoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
        }
    }
}
