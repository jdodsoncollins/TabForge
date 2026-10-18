import Foundation
import Testing
@testable import KeyboardCore

/// Synthetic geometry regressions, not an estimate of accuracy on people's gestures.
/// Coordinates follow the renderer's width-normalized coordinate system and row weights.
@Suite
struct SwipeDecoderTests {
    private struct Geometry: Sendable, CustomStringConvertible {
        let name: String
        let width: Double
        let rowPitch: Double
        let extendedRows: Bool
        var description: String { name }

        var centers: [Character: SwipePoint] {
            var result: [Character: SwipePoint] = [:]
            for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
                let inset = !extendedRows && row == 1 ? (width - 10) * 0.045 : 0
                let available = width - 10 - inset * 2
                let extraKeys = extendedRows ? (row == 2 ? 3 : row == 0 ? 2 : 3) : 0
                let count = letters.count + extraKeys + (row == 2 ? 2 : 0)
                let weight = Double(letters.count + extraKeys) + (row == 2 ? 2.8 : 0)
                let unit = (available - Double(count - 1) * 5) / weight
                let start = 5 + inset + (row == 2 ? unit * 1.4 + 5 : 0)
                for (column, letter) in letters.enumerated() {
                    result[letter] = SwipePoint(
                        x: (start + Double(column) * (unit + 5) + unit / 2) / width,
                        y: (50 + Double(row) * rowPitch) / width)
                }
            }
            return result
        }
    }

    private enum TraceStyle: String, CaseIterable, Sendable {
        case exact, jitter, cornerCut, uneven

        // These are acceptance targets for this fixed synthetic suite, not measured user accuracy.
        var minimumTopOne: Double { self == .exact || self == .uneven ? 0.95 : 0.85 }
        var minimumTopThree: Double { self == .exact || self == .uneven ? 0.98 : 0.95 }
    }

    private static let geometries = [
        Geometry(name: "narrow phone portrait", width: 320, rowPitch: 52, extendedRows: false),
        Geometry(name: "phone compact landscape", width: 760, rowPitch: 45, extendedRows: false),
        Geometry(name: "iPad full width", width: 820, rowPitch: 56, extendedRows: true),
        Geometry(name: "Duo open or tabletop width", width: 951, rowPitch: 62, extendedRows: true)
    ]

    // Deliberately mixes everyday prose, repeated letters, and programming terms. The vocabulary
    // argument is intentionally omitted below: expanding the test's dictionary would hide OOV bugs.
    private static let ordinaryWords = [
        "testing", "hello", "world", "message", "please", "thanks", "today", "tomorrow",
        "because", "before", "after", "again", "should", "would", "could", "there", "their",
        "keyboard", "something", "coffee", "letter", "little", "better", "running", "people", "really"
    ]
    private static let codeWords = [
        "print", "function", "return", "import", "export", "typeof", "async", "await",
        "const", "struct", "shell", "git", "status", "debug", "commit", "branch"
    ]

    @Test func testingDoesNotBecomeTypeof() {
        // Keep the existing core swipe test's staggered QWERTY geometry as a stable minimal
        // reproduction. The broader corpus below separately follows rendered row weights.
        var centers: [Character: SwipePoint] = [:]
        for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            for (column, letter) in letters.enumerated() {
                centers[letter] = SwipePoint(x: Double(column) * 0.09 + Double(row) * 0.04,
                    y: Double(row) * 0.12)
            }
        }
        let candidates = SwipeDecoder.candidates(trace: "testing".compactMap { centers[$0] }, centers: centers)
        #expect(candidates.first == "testing", "Synthetic testing trace returned \(candidates)")
    }

    @Test(arguments: geometries, TraceStyle.allCases)
    private func ordinaryAndCodeWordsMeetSyntheticAccuracyTargets(_ geometry: Geometry, _ style: TraceStyle) {
        let decoder = SwipeDecoder()
        for (category, words) in [("ordinary English", Self.ordinaryWords), ("code", Self.codeWords)] {
            var topOne = 0
            var topThree = 0
            var missed: [String] = []
            for word in words {
                let candidates = decoder.candidates(
                    trace: Self.trace(word, geometry: geometry, style: style), centers: geometry.centers)
                if candidates.first == word { topOne += 1 }
                else { missed.append("\(word)→\(candidates.first ?? "∅")") }
                if candidates.contains(word) { topThree += 1 }
            }
            let detail = "\(geometry), \(style.rawValue), \(category): top1 \(topOne)/\(words.count), top3 \(topThree)/\(words.count); \(missed.joined(separator: ", "))"
            #expect(Double(topOne) / Double(words.count) >= style.minimumTopOne, Comment(rawValue: detail))
            #expect(Double(topThree) / Double(words.count) >= style.minimumTopThree, Comment(rawValue: detail))
        }
    }

    @Test func invalidOrStationaryPathsDoNotInventWords() {
        let centers = Self.geometries[0].centers
        let t = centers["t"]!
        #expect(SwipeDecoder.candidates(trace: [], centers: centers).isEmpty)
        #expect(SwipeDecoder.candidates(trace: [t, t, t], centers: centers).isEmpty)
        #expect(SwipeDecoder.candidates(trace: Array(repeating: t, count: 12), centers: centers, words: ["tt", "test"]).isEmpty)
        #expect(SwipeDecoder.candidates(trace: Self.trace("testing", geometry: Self.geometries[0], style: .exact), centers: [:]).isEmpty)
        for invalid in [Double.nan, .infinity, -.infinity] {
            var trace = Self.trace("print", geometry: Self.geometries[0], style: .exact)
            trace[trace.count / 2].x = invalid
            #expect(SwipeDecoder.candidates(trace: trace, centers: centers).isEmpty)
        }
    }

    @Test func repeatedLettersHaveTheSameResultWithDifferentSamplingDensity() {
        let geometry = Self.geometries[0]
        for word in ["letter", "coffee", "little", "running", "testing"] {
            let candidates = SwipeDecoder.candidates(
                trace: Self.trace(word, geometry: geometry, style: .uneven), centers: geometry.centers)
            #expect(candidates.first == word, "\(word) returned \(candidates)")
        }
    }

    @Test(arguments: geometries)
    private func poorShapesWithMatchingEndpointsAreDeclined(_ geometry: Geometry) {
        let centers = geometry.centers
        let decoder = SwipeDecoder(words: ["testing"])
        let unrelatedPath = "tpmqpmqg".compactMap { centers[$0] }
        #expect(decoder.candidates(trace: unrelatedPath, centers: centers).isEmpty)
        #expect(decoder.candidates(trace: Self.trace("testing", geometry: geometry, style: .exact),
            centers: centers).first == "testing")
    }

    private static func trace(_ word: String, geometry: Geometry, style: TraceStyle) -> [SwipePoint] {
        let centers = geometry.centers
        let targets = word.compactMap { centers[$0] }
        guard let first = targets.first else { return [] }
        var vertices = [first]
        if style == .cornerCut {
            for index in targets.indices.dropFirst().dropLast() {
                vertices.append(interpolate(targets[index - 1], targets[index], fraction: 0.88))
                vertices.append(interpolate(targets[index], targets[index + 1], fraction: 0.12))
            }
            vertices.append(targets.last!)
        } else { vertices = targets }
        var points = [first]
        for (segment, pair) in zip(vertices, vertices.dropFirst()).enumerated() {
            // Uneven sampling also dwells on repeated letters; arc-length normalization should
            // prevent drawing speed or repeated sensor samples from changing the word.
            let steps = style == .uneven ? [2, 17, 3, 11][segment % 4] : 8
            for step in 1...steps {
                var point = interpolate(pair.0, pair.1, fraction: Double(step) / Double(steps))
                if style == .jitter {
                    let sample = Double(points.count)
                    point.x += sin(sample * 1.7) * 0.008
                    point.y += cos(sample * 2.3) * (geometry.rowPitch / geometry.width) * 0.07
                }
                points.append(point)
            }
        }
        return points
    }

    private static func interpolate(_ a: SwipePoint, _ b: SwipePoint, fraction: Double) -> SwipePoint {
        SwipePoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
    }
}
