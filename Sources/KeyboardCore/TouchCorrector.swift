import Foundation

/// Chooses the word a person most likely meant when the letters they tapped do
/// not form a known word. Each candidate is scored by how well the actual tap
/// points fit its keys, plus how common the word is: a noisy-channel model,
/// the approach published for mobile keyboards. Everything runs on device over
/// the bundled lexicon and the current document's words.
public struct TouchCorrector: Sendable {
    public let lexicon: Lexicon

    /// Tap spread around a key's expected center, in key pitches.
    static let sigma = 0.5
    /// Cost of a letter the person skipped, or of an extra letter they hit.
    static let omission = 2.8, doubledOmission = 0.8
    static let extra = 2.8, doubledExtra = 1.0
    static let transposition = 2.0
    /// How strongly word frequency counts against tap evidence.
    static let priorWeight = 0.35
    /// Words used in the current document rank like common words.
    static let documentZipf = 5.0

    public init(lexicon: Lexicon) { self.lexicon = lexicon }

    /// Whether a word is listed or used elsewhere in the document. Known words
    /// are never corrected.
    public func isKnown(_ word: String, document: DocumentVocabulary = .init()) -> Bool {
        lexicon.contains(word) || document.contains(word)
    }

    /// The most likely intended word, in lowercase, or nil when the typed word
    /// is known or no candidate is close enough. `touches` holds one tap point
    /// per letter, in the coordinate space `geometry` was built from; a nil
    /// point, or a count that does not match, falls back to key centers.
    public func correction(
        for typed: String,
        touches: [SwipePoint?] = [],
        geometry: KeyGeometry = .qwerty,
        adaptation: TouchAdaptation? = nil,
        document: DocumentVocabulary = .init()
    ) -> String? {
        guard let letters = Lexicon.normalized(typed), letters.count >= 2,
              !isKnown(typed, document: document) else { return nil }
        let n = letters.count
        let points = touches.count == n ? touches.map { $0.map(geometry.normalize) } : Array(repeating: nil, count: n)
        func expected(_ letter: UInt8) -> SwipePoint? {
            adaptation?.expectedCenter(letter, geometry: geometry) ?? geometry.center(letter)
        }
        func squared(_ a: SwipePoint, _ b: SwipePoint) -> Double { (a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y) }
        let scale = 2 * Self.sigma * Self.sigma
        // Substitution costs for every typed position and every letter, so the
        // per-candidate alignment does no geometry.
        var substitution = [Double](repeating: 0, count: n * 26)
        for i in 0..<n {
            let typedCenter = expected(letters[i])
            for c in 0..<26 where UInt8(97 + c) != letters[i] {
                guard let target = expected(UInt8(97 + c)), let typedCenter else { substitution[i * 26 + c] = 8; continue }
                if let point = points[i] {
                    // Relative to the key that registered the tap: a point near
                    // the shared edge makes either key nearly equally likely.
                    substitution[i * 26 + c] = max(0, squared(point, target) - squared(point, typedCenter)) / scale
                } else {
                    substitution[i * 26 + c] = squared(typedCenter, target) / scale
                }
            }
        }
        let window = n <= 4 ? 1 : 2
        let maximumChannel = n <= 3 ? 2.6 : n <= 5 ? 3.6 : 5.0
        var previous2 = [Double](repeating: 0, count: 40)
        var previous = [Double](repeating: 0, count: 40)
        var current = [Double](repeating: 0, count: 40)

        // Weighted Damerau–Levenshtein alignment with early abandonment once
        // every cell in a row exceeds the bound.
        func channel(_ word: ArraySlice<UInt8>, bound: Double) -> Double? {
            let m = word.count, base = word.startIndex
            func omission(_ j: Int) -> Double {
                j > 0 && word[base + j] == word[base + j - 1] ? Self.doubledOmission : Self.omission
            }
            func extra(_ i: Int) -> Double {
                i > 0 && letters[i] == letters[i - 1] ? Self.doubledExtra : Self.extra
            }
            previous[0] = 0
            for j in 1...m { previous[j] = previous[j - 1] + omission(j - 1) }
            var previousMinimum = 0.0
            for i in 1...n {
                current[0] = previous[0] + extra(i - 1)
                var rowMinimum = current[0]
                for j in 1...m {
                    let letter = word[base + j - 1]
                    var cost = min(
                        previous[j - 1] + substitution[(i - 1) * 26 + Int(letter - 97)],
                        previous[j] + extra(i - 1),
                        current[j - 1] + omission(j - 1)
                    )
                    if i > 1, j > 1, letters[i - 1] == word[base + j - 2], letters[i - 2] == letter,
                       letters[i - 1] != letters[i - 2] {
                        cost = min(cost, previous2[j - 2] + Self.transposition)
                    }
                    current[j] = cost
                    rowMinimum = min(rowMinimum, cost)
                }
                // A transposition reaches back two rows, so both must exceed the bound.
                if min(rowMinimum, previousMinimum) > bound { return nil }
                previousMinimum = rowMinimum
                swap(&previous2, &previous)
                swap(&previous, &current)
            }
            return previous[m] <= bound ? previous[m] : nil
        }

        var best: (word: String, total: Double)?
        func consider(_ word: ArraySlice<UInt8>, zipf: Double, index: Int?) {
            let prior = Self.prior(zipf)
            let bound = min(maximumChannel, (best?.total ?? .infinity) - prior)
            guard bound >= 0, let cost = channel(word, bound: bound) else { return }
            let total = cost + prior
            if total < best?.total ?? .infinity {
                best = (index.map(lexicon.string(at:)) ?? String(decoding: word, as: UTF8.self), total)
            }
        }
        // Most slips keep the first letter. Scoring those words first finds a
        // strong candidate early, which lets the frequency bound skip most of
        // the remaining words before any alignment.
        let sameFirst = lexicon.range(startingWith: letters[0])
        for range in [sameFirst, 0..<sameFirst.lowerBound, sameFirst.upperBound..<lexicon.count] {
            for index in range where abs(lexicon.length(at: index) - n) <= window {
                consider(lexicon.word(at: index), zipf: lexicon.zipf(at: index), index: index)
            }
        }
        for word in document.lowercaseWords where abs(word.utf8.count - n) <= window {
            let zipf = max(lexicon.zipf(word) ?? Lexicon.unmeasuredZipf, Self.documentZipf)
            consider(ArraySlice(word.utf8), zipf: zipf, index: nil)
        }
        return best?.word
    }

    /// Negative log probability of a word from its Zipf frequency, scaled.
    static func prior(_ zipf: Double) -> Double {
        Self.priorWeight * max(0, Lexicon.maximumZipf - zipf) * log(10)
    }
}
