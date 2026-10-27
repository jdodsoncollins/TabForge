import Foundation
import Testing
@testable import KeyboardCore

@Suite @MainActor
struct LanguageFeatureTests {
    private func engine(_ document: MemoryDocument) -> EditingEngine {
        var settings = KeyboardSettings()
        settings.autocorrectProse = true
        document.allowsAutocorrection = true
        return EditingEngine(document: document, settings: settings)
    }

    @Test func tapPointsReachTheProviderOnlyForTheWholeTypedWord() {
        let document = MemoryDocument(text: "Say ")
        let editor = engine(document)
        var seen: [[SwipePoint?]] = []
        editor.correctionProvider = { word in
            seen.append(editor.correctionTouches)
            return word == "teh" ? "the" : nil
        }
        let points = [SwipePoint(x: 1, y: 2), nil, SwipePoint(x: 3, y: 4)]
        for (letter, point) in zip("teh", points) { editor.type(String(letter), touch: point) }
        editor.type(" ")
        #expect(document.text == "Say the ")
        #expect(seen == [points])
        #expect(editor.correctionTouches.isEmpty)

        // A word that was not typed letter by letter here has no tap points.
        document.insert("helo")
        editor.type(" ")
        #expect(seen.last == [])
    }

    @Test func longerWordsMayTakeTwoEdits() {
        let document = MemoryDocument(text: "Please recieeve")
        let editor = engine(document)
        editor.correctionProvider = { $0 == "recieeve" ? "receive" : $0 == "teh" ? "theme" : nil }
        editor.type(" ")
        #expect(document.text == "Please receive ")
        // Short words still accept only one edit.
        document.insert("teh")
        editor.type(" ")
        #expect(document.text == "Please receive teh ")
    }

    @Test func completionsRankDocumentNamesAndAddEnglishOnlyForProse() {
        let lexicon = Lexicon(words: ["meeting", "meet", "meeting"], frequencies: ["meeting": 5.2, "meet": 5.0])
        let document = MemoryDocument(text: "meetingRoom = 1\nmeetingRoom += meetingTime\nmee")
        var settings = KeyboardSettings()
        settings.language = .python
        let editor = EditingEngine(document: document, settings: settings)
        editor.lexicon = lexicon
        #expect(editor.completions == ["meetingRoom", "meetingTime"])
        editor.settings.autocorrectProse = true
        #expect(editor.completions == ["meetingRoom", "meetingTime", "meeting"])
        // Capitalized or code-shaped prefixes never get English filler.
        document.insert("\nMee")
        #expect(!editor.completions.contains("meeting"))
    }

    @Test func documentVocabularyComesFromBoundedContextAroundTheCursor() {
        let document = MemoryDocument(text: String(repeating: "farAway ", count: 2000) + "let total = subtotal + tax\nprint(tot", cursor: nil)
        let editor = EditingEngine(document: document)
        let vocabulary = editor.documentVocabulary()
        #expect(vocabulary.contains("subtotal"))
        #expect(!vocabulary.contains("tot"))
        editor.settings.compatibility = .terminal
        #expect(editor.documentVocabulary().isEmpty)
    }

    @Test func memoryTierFollowsHeadroomAndDeviceSize() {
        let mb: UInt64 = 1 << 20, gb: UInt64 = 1 << 30
        #expect(MemoryBudget.tier(available: 30 * mb, footprint: nil, physicalMemory: 6 * gb) == .full)
        #expect(MemoryBudget.tier(available: 10 * mb, footprint: nil, physicalMemory: 6 * gb) == .standard)
        #expect(MemoryBudget.tier(available: 4 * mb, footprint: nil, physicalMemory: 6 * gb) == .minimal)
        // Without a system report, current use is measured against a low assumed limit.
        #expect(MemoryBudget.tier(available: 0, footprint: 20 * mb, physicalMemory: 6 * gb) == .full)
        #expect(MemoryBudget.tier(available: nil, footprint: 36 * mb, physicalMemory: 6 * gb) == .standard)
        #expect(MemoryBudget.tier(available: nil, footprint: 60 * mb, physicalMemory: 6 * gb) == .minimal)
        #expect(MemoryBudget.tier(available: nil, footprint: nil, physicalMemory: 0) == .full)
        // Smaller devices skip swipe even with headroom.
        #expect(MemoryBudget.tier(available: 30 * mb, footprint: nil, physicalMemory: 2 * gb) == .standard)
        #expect(MemoryBudget.tier(available: 4 * mb, footprint: nil, physicalMemory: 2 * gb) == .minimal)
    }

    @Test func swipeProducesDocumentSpellingsAndPrefersFrequentWords() {
        var centers: [Character: SwipePoint] = [:]
        for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            for (column, letter) in letters.enumerated() {
                centers[letter] = SwipePoint(x: Double(column) * 0.1 + [0.05, 0.1, 0.2][row], y: Double(row) * 0.14)
            }
        }
        func trace(_ word: String) -> [SwipePoint] {
            let keys = word.compactMap { centers[$0] }
            var points: [SwipePoint] = []
            for (a, b) in zip(keys, keys.dropFirst()) {
                for step in 0..<8 {
                    let fraction = Double(step) / 8
                    points.append(SwipePoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction))
                }
            }
            return points + [keys[keys.count - 1]]
        }
        let decoder = SwipeDecoder(lexicon: Lexicon(words: ["user", "name"], frequencies: ["user": 5.0]))
        let document = DocumentVocabulary(before: "let userName = load(userName)\n")
        #expect(decoder.candidates(trace: trace("username"), centers: centers, document: document).first == "userName")
        #expect(decoder.candidates(trace: trace("username"), centers: centers).first != "userName")
    }
}
