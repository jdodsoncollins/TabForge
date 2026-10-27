import Foundation

/// Letter-key centers measured in key pitches, so the distance to a horizontal
/// neighbor or to the next row is about 1.0 in any orientation or keyboard width.
/// Tap correction and swipe share this normalization.
public struct KeyGeometry: Sendable {
    public let xPitch: Double
    public let yPitch: Double
    /// Normalized centers indexed by letter, a through z.
    private let centers: [SwipePoint?]

    /// Accepts any coordinate space, such as points or width-normalized values,
    /// as long as touches use the same space. Returns nil without enough keys.
    public init?(centers: [Character: SwipePoint]) {
        let keys: [(UInt8, SwipePoint)] = centers.compactMap { letter, point in
            guard let byte = letter.asciiValue, (97...122).contains(byte),
                  point.x.isFinite, point.y.isFinite else { return nil }
            return (byte, point)
        }
        // Work in key pitches, not screen widths. A one-row error must remain
        // significant when landscape or tabletop keys are wide and short.
        let horizontal = keys.compactMap { key in
            keys.filter { abs($0.1.y - key.1.y) < 0.000001 && $0.1.x > key.1.x + 0.000001 }
                .map { $0.1.x - key.1.x }.min()
        }.sorted()
        let rows = Set(keys.map { $0.1.y }).sorted()
        let vertical = zip(rows, rows.dropFirst()).map { $1 - $0 }.filter { $0 > 0.000001 }.sorted()
        guard let xPitch = horizontal.isEmpty ? vertical.first : horizontal[horizontal.count / 2],
              xPitch.isFinite, xPitch > 0.000001 else { return nil }
        let yPitch = vertical.isEmpty ? xPitch : vertical[vertical.count / 2]
        self.xPitch = xPitch
        self.yPitch = yPitch
        var normalized = [SwipePoint?](repeating: nil, count: 26)
        for (letter, point) in keys {
            normalized[Int(letter - 97)] = SwipePoint(x: point.x / xPitch, y: point.y / yPitch)
        }
        self.centers = normalized
    }

    /// A staggered QWERTY layout in key pitches, used when no drawn layout is
    /// available, for example for words that arrive without touch points.
    public static let qwerty: KeyGeometry = {
        var centers: [Character: SwipePoint] = [:]
        for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            for (column, letter) in letters.enumerated() {
                centers[letter] = SwipePoint(x: Double(column) + [0, 0.5, 1.5][row], y: Double(row))
            }
        }
        return KeyGeometry(centers: centers)!
    }()

    public func normalize(_ point: SwipePoint) -> SwipePoint {
        SwipePoint(x: point.x / xPitch, y: point.y / yPitch)
    }

    /// The normalized center of a lowercase ASCII letter.
    func center(_ letter: UInt8) -> SwipePoint? {
        (97...122).contains(letter) ? centers[Int(letter - 97)] : nil
    }

    var letterCenters: [(UInt8, SwipePoint)] {
        centers.enumerated().compactMap { index, point in point.map { (UInt8(index + 97), $0) } }
    }
}

/// Optional on-device tap calibration. It keeps only the average offset between
/// where each letter key is drawn and where this person taps it, in key pitches,
/// plus a capped sample count. It never stores letters in order, words, or text.
public struct TouchAdaptation: Codable, Equatable, Sendable {
    public struct Offset: Codable, Equatable, Sendable {
        public var dx = 0.0
        public var dy = 0.0
        public var samples = 0
    }

    /// Offsets are clamped so a learned shift never moves a key onto its neighbor.
    static let limit = 0.35
    /// A key's own offset is used only after this many confirmed taps.
    static let minimumSamples = 12
    /// Older taps fade out after roughly this many newer ones.
    static let memory = 200
    /// Taps this far from the key's center are treated as outliers.
    static let outlier = 0.75

    public private(set) var keys: [String: Offset] = [:]
    public private(set) var overall = Offset()

    public init() {}

    public var isEmpty: Bool { overall.samples == 0 }

    /// Records a tap whose intended letter is known, such as a letter in a
    /// listed word that was accepted without correction.
    public mutating func record(letter: Character, touch: SwipePoint, geometry: KeyGeometry) {
        guard let byte = letter.lowercased().first?.asciiValue, let center = geometry.center(byte),
              touch.x.isFinite, touch.y.isFinite else { return }
        let point = geometry.normalize(touch)
        let dx = point.x - center.x, dy = point.y - center.y
        guard hypot(dx, dy) <= Self.outlier else { return }
        let key = String(UnicodeScalar(byte))
        keys[key] = Self.update(keys[key] ?? Offset(), dx: dx, dy: dy)
        overall = Self.update(overall, dx: dx, dy: dy)
    }

    private static func update(_ offset: Offset, dx: Double, dy: Double) -> Offset {
        var result = offset
        result.samples = min(offset.samples + 1, memory)
        let weight = 1 / Double(result.samples)
        result.dx = min(limit, max(-limit, offset.dx + (dx - offset.dx) * weight))
        result.dy = min(limit, max(-limit, offset.dy + (dy - offset.dy) * weight))
        return result
    }

    /// The learned offset for a letter, in key pitches. A key without enough
    /// samples of its own uses the overall offset, and nothing before that.
    func offset(for letter: UInt8) -> (dx: Double, dy: Double) {
        if let own = keys[String(UnicodeScalar(letter))], own.samples >= Self.minimumSamples { return (own.dx, own.dy) }
        if overall.samples >= Self.minimumSamples { return (overall.dx, overall.dy) }
        return (0, 0)
    }

    /// Where this person's taps for `letter` are expected to land, normalized.
    func expectedCenter(_ letter: UInt8, geometry: KeyGeometry) -> SwipePoint? {
        guard let center = geometry.center(letter) else { return nil }
        let offset = offset(for: letter)
        return SwipePoint(x: center.x + offset.dx, y: center.y + offset.dy)
    }
}
