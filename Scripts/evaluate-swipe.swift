// Synthetic swipe evaluation. This never reads a host document, records a
// gesture, or opens a network connection. Scores are regression evidence, not
// estimates of real users' swipe accuracy.
//
// Build and run from the repository root:
//   swift build -c release --build-system native
//   swiftc -O -parse-as-library -I .build/release/Modules \
//     Scripts/evaluate-swipe.swift .build/release/KeyboardCore.build/*.o \
//     -o /tmp/tabforge-evaluate-swipe
//   /tmp/tabforge-evaluate-swipe --json /tmp/tabforge-swipe-results.json
//
// Keep these fixtures and geometry ratios fixed when comparing decoder changes.
// The layouts below are synthetic proportions, not device captures.

import Foundation
import KeyboardCore

@main
struct EvaluateSwipe {
    static let corpus = "testing programming developer morning repeat keyboard terminal hello world test tests function return language swift python javascript typescript coffee tomorrow today working building writing reading meeting message computer application mobile format indentation snippet privacy correct swipe type typeof the quick brown jumps over lazy dog where what when which why how please thanks support change issue fix bug code words settings example password username localhost install update branch git commit push pull result results file path output input number string class struct learning coding running thinking something anything everything nothing should could would make good better best"
        .split(separator: " ").map(String.init)
    static let repeatedLetters = ["hello", "coffee", "programming", "tomorrow", "too", "book", "letter", "mississippi", "testing", "success"]

    struct Geometry {
        let name: String
        let pitch: Double
        let rowPitch: Double
        let offsets: [Double]
        let origin: SwipePoint

        var centers: [Character: SwipePoint] {
            var result: [Character: SwipePoint] = [:]
            for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
                for (column, letter) in letters.enumerated() {
                    result[letter] = SwipePoint(x: origin.x + offsets[row] + Double(column) * pitch,
                        y: origin.y + Double(row) * rowPitch)
                }
            }
            return result
        }
    }

    // The first layout exactly preserves the original print-regression geometry.
    static let geometries = [
        Geometry(name: "original-regression", pitch: 0.09, rowPitch: 0.12,
            offsets: [0, 0.04, 0.08], origin: .init(x: 0, y: 0)),
        Geometry(name: "phone-portrait", pitch: 0.098, rowPitch: 0.13,
            offsets: [0, 0.047, 0.145], origin: .init(x: 0.05, y: 0.20)),
        Geometry(name: "phone-landscape", pitch: 0.085, rowPitch: 0.047,
            offsets: [0, 0.04, 0.12], origin: .init(x: 0.08, y: 0.06)),
        Geometry(name: "ipad-full", pitch: 0.066, rowPitch: 0.065,
            offsets: [0, 0.033, 0.099], origin: .init(x: 0.14, y: 0.12)),
        Geometry(name: "duo-open", pitch: 0.07, rowPitch: 0.075,
            offsets: [0, 0.035, 0.105], origin: .init(x: 0.12, y: 0.12)),
        Geometry(name: "duo-tabletop", pitch: 0.067, rowPitch: 0.072,
            offsets: [0, 0.0335, 0.1005], origin: .init(x: 0.13, y: 0.14))
    ]

    enum TraceKind: String, CaseIterable {
        case keyVertices, dense, roundedJitter
    }

    struct Failure: Codable {
        let expected: String
        let candidates: [String]
    }

    struct Accuracy: Codable {
        let fixture: String
        let geometry: String
        let trace: String
        let count: Int
        let covered: Int
        let top1: Int
        let top3: Int
        let failures: [Failure]
    }

    struct Latency: Codable {
        let geometry: String
        let samples: Int
        let medianMilliseconds: Double
        let p95Milliseconds: Double
        let maximumMilliseconds: Double
    }

    struct Report: Codable {
        let note: String
        let vocabularyCount: Int
        let initializationMilliseconds: Double
        let accuracy: [Accuracy]
        let latency: [Latency]
    }

    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.contains("--help") {
            print("Usage: tabforge-evaluate-swipe [--json PATH] [--iterations 101]")
            return
        }
        let iterations: Int
        if let index = arguments.firstIndex(of: "--iterations"), arguments.indices.contains(index + 1),
            let value = Int(arguments[index + 1]), (5...1000).contains(value) {
            iterations = value
        } else {
            iterations = 101
        }
        let vocabulary = Set(SwipeDecoder.vocabulary.map { $0.lowercased() })
        let initializationStart = ContinuousClock.now
        let decoder = SwipeDecoder()
        let initialization = initializationStart.duration(to: .now).components
        let initializationMilliseconds = Double(initialization.seconds) * 1_000 + Double(initialization.attoseconds) / 1e15
        var accuracy: [Accuracy] = []
        var latency: [Latency] = []
        for geometry in geometries {
            let centers = geometry.centers
            for (fixture, words) in [("mixed-97", corpus), ("repeated-letters", repeatedLetters)] {
                for kind in TraceKind.allCases {
                    var top1 = 0, top3 = 0
                    var failures: [Failure] = []
                    for word in words {
                        let trace = makeTrace(word: word, geometry: geometry, kind: kind)
                        let result = decoder.candidates(trace: trace, centers: centers)
                        if result.first == word { top1 += 1 }
                        else { failures.append(Failure(expected: word, candidates: result)) }
                        if result.contains(word) { top3 += 1 }
                    }
                    accuracy.append(Accuracy(fixture: fixture, geometry: geometry.name, trace: kind.rawValue,
                        count: words.count, covered: words.filter { vocabulary.contains($0) }.count,
                        top1: top1, top3: top3, failures: failures))
                }
            }
            // Warm up before sampling and keep the same five synthetic words.
            let workload = ["testing", "hello", "programming", "developer", "keyboard"].map {
                makeTrace(word: $0, geometry: geometry, kind: .roundedJitter)
            }
            for trace in workload { _ = decoder.candidates(trace: trace, centers: centers) }
            var elapsed: [Double] = []
            for index in 0..<iterations {
                let start = ContinuousClock.now
                _ = decoder.candidates(trace: workload[index % workload.count], centers: centers)
                let duration = start.duration(to: .now).components
                elapsed.append(Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15)
            }
            elapsed.sort()
            latency.append(Latency(geometry: geometry.name, samples: iterations,
                medianMilliseconds: elapsed[iterations / 2],
                p95Milliseconds: elapsed[min(iterations - 1, Int(ceil(Double(iterations) * 0.95)) - 1)],
                maximumMilliseconds: elapsed.last!))
        }
        let report = Report(note: "Fixed synthetic traces only. No human accuracy or physical-device latency claim.",
            vocabularyCount: vocabulary.count, initializationMilliseconds: initializationMilliseconds, accuracy: accuracy, latency: latency)
        for result in accuracy where result.fixture == "mixed-97" {
            print("\(result.geometry) \(result.trace): covered \(result.covered)/\(result.count), top1 \(result.top1)/\(result.count), top3 \(result.top3)/\(result.count)")
        }
        for result in latency {
            print(String(format: "%@ warm decode: median %.3f ms, p95 %.3f ms, max %.3f ms (%d samples)",
                result.geometry, result.medianMilliseconds, result.p95Milliseconds, result.maximumMilliseconds, result.samples))
        }
        if let index = arguments.firstIndex(of: "--json"), arguments.indices.contains(index + 1) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(to: URL(fileURLWithPath: arguments[index + 1]), options: .atomic)
        }
    }

    static func makeTrace(word: String, geometry: Geometry, kind: TraceKind) -> [SwipePoint] {
        let centers = geometry.centers
        let vertices = word.compactMap { centers[$0] }
        guard kind != .keyVertices, let first = vertices.first, let last = vertices.last else { return vertices }
        var path = [first]
        if kind == .roundedJitter, vertices.count > 2 {
            for index in 1..<(vertices.count - 1) {
                let point = vertices[index]
                for neighbor in [vertices[index - 1], vertices[index + 1]] {
                    let dx = neighbor.x - point.x, dy = neighbor.y - point.y
                    let distance = hypot(dx, dy)
                    let fraction = distance > 0 ? min(0.18, geometry.pitch * 0.30 / distance) : 0
                    path.append(.init(x: point.x + dx * fraction, y: point.y + dy * fraction))
                }
            }
        } else {
            path.append(contentsOf: vertices.dropFirst().dropLast())
        }
        path.append(last)
        var trace = [first]
        for (a, b) in zip(path, path.dropFirst()) {
            for step in 1...6 {
                let fraction = Double(step) / 6
                trace.append(.init(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction))
            }
        }
        if kind == .roundedJitter {
            return trace.enumerated().map { index, point in
                let scale = (index == 0 || index == trace.count - 1) ? 0.04 : 0.12
                return .init(x: point.x + Double((index * 17) % 11 - 5) / 5 * geometry.pitch * scale,
                    y: point.y + Double((index * 23) % 13 - 6) / 6 * geometry.pitch * scale)
            }
        }
        return trace
    }
}
