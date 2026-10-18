import Foundation

public struct SwipePoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
    func distance(to point: Self) -> Double { hypot(x - point.x, y - point.y) }
}

/// Small, deterministic gesture recognizer for code vocabulary, entirely on device.
/// It is intentionally not a replacement for a full natural-language swipe model.
public enum SwipeDecoder {
    public static let vocabulary = "hello world name value values result results message messages input output data file files path text string number count index item items list array dictionary key keys object options config settings language keyboard code script function return class struct import export async await error errors success failure true false null print console write read open close append remove insert update delete fetch request response server client token user users command terminal python swift javascript typescript shell json git status commit push pull branch checkout switch let var const if else guard while for case default public private static protocol extension throws catch try self init main view model state binding body some type interface map filter reduce sort first last length size width height color frame content label button title padding spacing start stop test tests debug build run install select selection cursor tab space indent format pair braces bracket parenthesis angle quote and or not in is as from with def pass raise except finally yield echo printf source chmod mkdir touch curl docker node npm ssh cd ls pwd cat grep find sed awk sudo exit done then fi esac home end left right up down page escape control delete backspace reset save load copy paste search replace split join contains hasPrefix hasSuffix lowercased uppercased description identifier set get optional required available task actor weak final override mutating nonisolated associatedtype deinit continue break defer enumerate range len str int float bool super property await Promise boolean readonly implements typeof undefined instanceof new this void never unknown any do throw interface number boolean".components(separatedBy: " ")

    public static func candidates(trace: [SwipePoint], centers: [Character: SwipePoint], words: [String] = vocabulary) -> [String] {
        guard trace.count >= 4, let start = trace.first, let end = trace.last else { return [] }
        let sampled = resample(trace, count: 32)
        let uniqueWords = Set(words.map { $0.lowercased() })
        return uniqueWords.compactMap { word -> (String, Double)? in
            let letters = Array(word)
            guard letters.count >= 2, let first = letters.first.flatMap({ centers[$0] }),
                  let last = letters.last.flatMap({ centers[$0] }),
                  start.distance(to: first) < 0.11, end.distance(to: last) < 0.11 else { return nil }
            var points: [SwipePoint] = []
            for letter in letters {
                guard let point = centers[letter] else { return nil }
                if points.last != point { points.append(point) }
            }
            let template = resample(points, count: 32)
            let shape = zip(sampled, template).reduce(0.0) { $0 + $1.0.distance(to: $1.1) } / 32
            let endpoints = start.distance(to: first) + end.distance(to: last)
            return (word, shape + endpoints * 0.7)
        }.sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }.prefix(3).map(\.0)
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
