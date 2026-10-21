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
    private struct Entry: Sendable {
        let word: String
        let letters: [UInt8]
    }
    private let endpoints: [UInt16: [Entry]]

    private static let codeVocabulary = "hello world name value values result results message messages input output data file files path text string number count index item items list array dictionary key keys object options config settings language keyboard code script function return class struct import export async await error errors success failure true false null print console write read open close append remove insert update delete fetch request response server client token user users command terminal python swift javascript typescript shell json git status commit push pull branch checkout switch let var const if else guard while for case default public private static protocol extension throws catch try self init main view model state binding body some type interface map filter reduce sort first last length size width height color frame content label button title padding spacing start stop test tests debug build run install select selection cursor tab space indent format pair braces bracket parenthesis angle quote and or not in is as from with def pass raise except finally yield echo printf source chmod mkdir touch curl docker node npm ssh cd ls pwd cat grep find sed awk sudo exit done then fi esac home end left right up down page escape control delete backspace reset save load copy paste search replace split join contains hasPrefix hasSuffix lowercased uppercased description identifier set get optional required available task actor weak final override mutating nonisolated associatedtype deinit continue break defer enumerate range len str int float bool super property await Promise boolean readonly implements typeof undefined instanceof new this void never unknown any do throw interface number boolean".components(separatedBy: " ")

    /// Bundled English words plus programming terms. Loading is local and deterministic.
    /// Callers doing repeated decoding should reuse an instance rather than rebuild this list.
    public static var vocabulary: [String] {
        guard let url = Bundle.module.url(forResource: "swipe-english", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return codeVocabulary }
        return codeVocabulary + text.split(separator: "\n").filter { !$0.hasPrefix("#") }.map(String.init)
    }

    public init(words: [String]? = nil) {
        var endpoints: [UInt16: [Entry]] = [:]
        var seen: Set<String> = []
        for value in words ?? Self.vocabulary {
            let word = value.lowercased()
            guard seen.insert(word).inserted else { continue }
            let bytes = Array(word.utf8)
            guard (2...32).contains(bytes.count), bytes.allSatisfy({ (97...122).contains($0) }),
                  let first = bytes.first, let last = bytes.last else { continue }
            let letters = bytes.enumerated().compactMap { index, letter in
                index == 0 || bytes[index - 1] != letter ? letter : nil
            }
            guard letters.count >= 2 else { continue }
            endpoints[UInt16(first) << 8 | UInt16(last), default: []].append(Entry(word: word, letters: letters))
        }
        self.endpoints = endpoints
    }

    public static func candidates(trace: [SwipePoint], centers: [Character: SwipePoint], words: [String]? = nil) -> [String] {
        Self(words: words).candidates(trace: trace, centers: centers)
    }

    public func candidates(trace: [SwipePoint], centers: [Character: SwipePoint]) -> [String] {
        guard (2...4096).contains(trace.count), trace.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              let firstSample = trace.first, let lastSample = trace.last else { return [] }
        let rawKeys: [(UInt8, SwipePoint)] = centers.compactMap { letter, point in
            guard let byte = letter.asciiValue, (97...122).contains(byte),
                  point.x.isFinite, point.y.isFinite else { return nil }
            return (byte, point)
        }
        // Work in key pitches, not screen widths. A one-row error must remain
        // significant when landscape or tabletop keys are wide and short.
        let horizontal = rawKeys.compactMap { key in
            rawKeys.filter { abs($0.1.y - key.1.y) < 0.000001 && $0.1.x > key.1.x + 0.000001 }
                .map { $0.1.x - key.1.x }.min()
        }.sorted()
        let rows = Set(rawKeys.map { $0.1.y }).sorted()
        let vertical = zip(rows, rows.dropFirst()).map { $1 - $0 }.filter { $0 > 0.000001 }.sorted()
        guard let xPitch = horizontal.isEmpty ? vertical.first : horizontal[horizontal.count / 2],
              xPitch.isFinite, xPitch > 0.000001 else { return [] }
        let yPitch = vertical.isEmpty ? xPitch : vertical[vertical.count / 2]
        func normalize(_ point: SwipePoint) -> SwipePoint { .init(x: point.x / xPitch, y: point.y / yPitch) }
        let path = trace.map(normalize)
        let length = zip(path, path.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
        guard length.isFinite, length > 0.5 else { return [] }
        let sampled = Self.resample(path, count: 32)
        let start = normalize(firstSample), end = normalize(lastSample)
        let keys = rawKeys.map { ($0.0, normalize($0.1)) }
        let positions = Dictionary(uniqueKeysWithValues: keys)
        let starts = keys.filter { start.distance(to: $0.1) < 1.15 }
        let ends = keys.filter { end.distance(to: $0.1) < 1.15 }
        var best: [(entry: Entry, shape: Double, endpoints: Double)] = []
        // End-point buckets avoid scanning and resampling the entire dictionary per gesture.
        for (first, a) in starts {
            for (last, b) in ends {
                for entry in endpoints[UInt16(first) << 8 | UInt16(last)] ?? [] {
                    let points = entry.letters.compactMap { positions[$0] }
                    guard points.count == entry.letters.count else { continue }
                    let template = Self.resample(points, count: 32)
                    let shape = zip(sampled, template).reduce(0.0) { $0 + $1.0.distance(to: $1.1) } / 32
                    guard shape < 0.85 else { continue }
                    best.append((entry, shape, start.distance(to: a) + end.distance(to: b)))
                }
            }
        }
        // Arc-length sampling removes speed differences but aligns rounded
        // corners poorly. Rerank a bounded shortlist with elastic alignment,
        // allowing a corner to occur a few samples earlier or later.
        let shortlist = best.sorted {
            let a = $0.shape + $0.endpoints * 0.7
            let b = $1.shape + $1.endpoints * 0.7
            return a == b ? $0.entry.word < $1.entry.word : a < b
        }.prefix(48)
        let reranked: [(String, Double)] = shortlist.map { candidate in
            let points: [SwipePoint] = candidate.entry.letters.compactMap { positions[$0] }
            let template = Self.resample(points, count: 32)
            let score = Self.elasticDistance(sampled, template) + candidate.endpoints * 0.7
            return (candidate.entry.word, score)
        }
        return reranked.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }.prefix(3).map(\.0)
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
