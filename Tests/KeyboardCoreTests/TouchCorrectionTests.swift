import Foundation
import Testing
@testable import KeyboardCore

/// Synthetic tap regressions. Touch points are chosen geometry, not recordings
/// of anyone's typing, so these are logic checks rather than accuracy estimates.
@Suite
struct TouchCorrectionTests {
    static let bundled = Lexicon.bundled()!

    @Test func bundledLexiconLoadsWordsFrequenciesAndCodeTerms() {
        let lexicon = Self.bundled
        #expect(lexicon.count > 38_000)
        #expect(lexicon.estimatedBytes < 1_000_000, "Word storage is \(lexicon.estimatedBytes) bytes")
        #expect(lexicon.zipf("the") == 7.6)
        #expect(lexicon.zipf("receive")! > lexicon.zipf("aardvark")!)
        #expect(lexicon.contains("Hello"))
        #expect(!lexicon.contains("teh"))
        #expect(!lexicon.contains("recieve"))
        // Programming terms are listed and rank as ordinary words.
        #expect(lexicon.zipf("async")! >= Lexicon.codeZipfFloor)
        #expect(lexicon.zipf("hasprefix")! >= Lexicon.codeZipfFloor)
        #expect(Lexicon.bundled(extraWords: ["kubectl"])!.contains("kubectl"))
        #expect(!lexicon.contains("don't") && !lexicon.contains("a"))
    }

    @Test func lexiconCompletionsPreferFrequentWords() {
        let lexicon = Lexicon(words: ["there", "therefore", "thermal", "the"],
                              frequencies: ["there": 6.1, "therefore": 4.9, "thermal": 3.9, "the": 7.6])
        #expect(lexicon.completions(prefix: "the", limit: 2) == ["there", "therefore"])
        #expect(lexicon.completions(prefix: "The", limit: 5) == ["there", "therefore", "thermal"])
        #expect(lexicon.completions(prefix: "x", limit: 3).isEmpty)
        #expect(lexicon.completions(prefix: "th3", limit: 3).isEmpty)
    }

    @Test(arguments: [("teh", "the"), ("recieve", "receive"), ("helo", "hello"), ("becuase", "because"),
                      ("wiht", "with"), ("somethign", "something"), ("tomorow", "tomorrow"), ("functoin", "function")])
    func commonSlipsWithoutTouchPoints(_ example: (String, String)) {
        #expect(TouchCorrector(lexicon: Self.bundled).correction(for: example.0) == example.1)
    }

    @Test(arguments: ["the", "receive", "async", "Hello", "zzzzqqq", "x"])
    func knownOrHopelessWordsAreLeftAlone(_ word: String) {
        #expect(TouchCorrector(lexicon: Self.bundled).correction(for: word) == nil)
    }

    @Test func tapPositionDecidesBetweenNeighboringKeys() {
        let lexicon = Lexicon(words: ["game", "name", "bane"], frequencies: ["game": 5.3, "name": 5.5, "bane": 2.4])
        let corrector = TouchCorrector(lexicon: lexicon)
        let geometry = KeyGeometry.qwerty
        func taps(firstAt point: SwipePoint) -> [SwipePoint?] {
            [point] + "ame".map { geometry.center($0.asciiValue!) }
        }
        // "b" sits below "g" and left of "n". A tap on b's upper edge points to
        // game; one on its right edge points to name.
        let b = geometry.center(98)!
        #expect(corrector.correction(for: "bame", touches: taps(firstAt: SwipePoint(x: b.x - 0.45, y: b.y - 0.45)), geometry: geometry) == "game")
        #expect(corrector.correction(for: "bame", touches: taps(firstAt: SwipePoint(x: b.x + 0.48, y: b.y)), geometry: geometry) == "name")
        // Without touch points, key distance and frequency choose name.
        #expect(corrector.correction(for: "bame") == "name")
        // A touch count that does not match the letters is ignored.
        #expect(corrector.correction(for: "bame", touches: [b]) == "name")
    }

    @Test func touchesAreReadInTheLayoutsCoordinateSpace() {
        // The same layout expressed in width-normalized coordinates, as the
        // keyboard view reports them, must give the same answer.
        var centers: [Character: SwipePoint] = [:]
        for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            for (column, letter) in letters.enumerated() {
                centers[letter] = SwipePoint(x: (Double(column) + [0, 0.5, 1.5][row]) * 0.1 + 0.05, y: Double(row) * 0.14)
            }
        }
        let geometry = KeyGeometry(centers: centers)!
        #expect(abs(geometry.xPitch - 0.1) < 1e-9 && abs(geometry.yPitch - 0.14) < 1e-9)
        let lexicon = Lexicon(words: ["game", "name"], frequencies: ["game": 5.3, "name": 5.5])
        let b = centers["b"]!
        let touches: [SwipePoint?] = [SwipePoint(x: b.x - 0.045, y: b.y - 0.063)] + "ame".map { centers[$0] }
        #expect(TouchCorrector(lexicon: lexicon).correction(for: "bame", touches: touches, geometry: geometry) == "game")
    }

    @Test func documentWordsAreKnownAndPreferred() {
        let corrector = TouchCorrector(lexicon: Lexicon(words: ["fetch", "fetched"], frequencies: ["fetch": 4.0, "fetched": 3.0]))
        let document = DocumentVocabulary(before: "refetch the cache, then call refetch again\nwe ")
        #expect(corrector.correction(for: "refetch", document: document) == nil)
        #expect(corrector.correction(for: "refecth", document: document) == "refetch")
        #expect(corrector.correction(for: "refecth") == nil)
    }

    @Test func learnedOffsetsMoveTheExpectedCenter() {
        let geometry = KeyGeometry.qwerty
        var adaptation = TouchAdaptation()
        let g = geometry.center(103)!
        for _ in 0..<(TouchAdaptation.minimumSamples - 1) {
            adaptation.record(letter: "g", touch: SwipePoint(x: g.x, y: g.y + 0.3), geometry: geometry)
        }
        #expect(adaptation.offset(for: 103) == (0, 0))
        adaptation.record(letter: "G", touch: SwipePoint(x: g.x, y: g.y + 0.3), geometry: geometry)
        #expect(abs(adaptation.offset(for: 103).dy - 0.3) < 1e-9)
        // Other keys follow the overall tendency once it has enough samples.
        #expect(abs(adaptation.offset(for: 104).dy - 0.3) < 1e-9)
        // Outliers are ignored and offsets stay clamped.
        adaptation.record(letter: "g", touch: SwipePoint(x: g.x + 3, y: g.y), geometry: geometry)
        #expect(adaptation.keys["g"]?.samples == TouchAdaptation.minimumSamples)
        for _ in 0..<500 { adaptation.record(letter: "h", touch: SwipePoint(x: 5.7, y: 1.45), geometry: geometry) }
        #expect(adaptation.keys["h"]!.dy <= TouchAdaptation.limit)
        #expect(adaptation.keys["h"]!.samples == TouchAdaptation.memory)

        // Someone who habitually taps low reaches for "h" and lands on the top
        // of "b". Plain geometry favors the nearer "v"; their learned offset
        // says a tap that high on "b" was meant for the row above.
        let lexicon = Lexicon(words: ["hat", "vat"], frequencies: ["hat": 4.5, "vat": 4.5])
        var low = TouchAdaptation()
        for letter in "abcdefghijklmnopqrstuvwxyz" {
            let center = geometry.center(letter.asciiValue!)!
            for _ in 0..<TouchAdaptation.minimumSamples {
                low.record(letter: letter, touch: SwipePoint(x: center.x, y: center.y + 0.3), geometry: geometry)
            }
        }
        let b = geometry.center(98)!
        let touches: [SwipePoint?] = [SwipePoint(x: b.x - 0.4, y: b.y - 0.35)] + "at".map {
            let center = geometry.center($0.asciiValue!)!
            return SwipePoint(x: center.x, y: center.y + 0.3)
        }
        let corrector = TouchCorrector(lexicon: lexicon)
        #expect(corrector.correction(for: "bat", touches: touches) == "vat")
        #expect(corrector.correction(for: "bat", touches: touches, adaptation: low) == "hat")
    }

    @Test func adaptationRoundTripsAsCoordinatesOnly() throws {
        var adaptation = TouchAdaptation()
        adaptation.record(letter: "e", touch: KeyGeometry.qwerty.center(101)!, geometry: .qwerty)
        let data = try JSONEncoder().encode(adaptation)
        #expect(try JSONDecoder().decode(TouchAdaptation.self, from: data) == adaptation)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"dx\"") && !json.contains("word"))
    }

    @Test func documentVocabularyExcludesTheWordAtTheCursor() {
        let document = DocumentVocabulary(before: "let userName = loadUser()\nprint(userName) teh", after: "xt more")
        #expect(document.contains("username"))
        #expect(document.spelling(of: "USERNAME") == "userName")
        #expect(!document.contains("teh"))
        #expect(!document.contains("xt"))
        #expect(document.contains("more"))
        #expect(document.completions(prefix: "us", limit: 3) == ["userName"])
        #expect(document.letterWords.contains("loadUser"))
        #expect(!document.lowercaseWords.contains("username"))
    }
}
