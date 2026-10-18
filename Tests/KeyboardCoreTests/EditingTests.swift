import Foundation
import Testing
@testable import KeyboardCore

@Suite @MainActor
struct EditingTests {
    @Test func bracketPairsKeepCursorInside() {
        let doc = MemoryDocument()
        let engine = EditingEngine(document: doc)
        engine.type("{")
        #expect(doc.text == "{}")
        #expect(doc.cursor == 1)
        engine.type("}")
        #expect(doc.text == "{}")
        #expect(doc.cursor == 2)
    }

    @Test func newlineInsidePairCreatesIndentedBlock() {
        let doc = MemoryDocument(text: "func run() {}", cursor: 12)
        let engine = EditingEngine(document: doc)
        engine.newline()
        #expect(doc.text == "func run() {\n    \n}")
        #expect(doc.before == "func run() {\n    ")
    }

    @Test func selectionIsWrappedWithoutLosingContent() {
        let doc = MemoryDocument(text: "value", selection: .init(location: 0, length: 5))
        EditingEngine(document: doc).type("[")
        #expect(doc.text == "[value]")
    }

    @Test func pairDeletionIsAtomic() {
        let doc = MemoryDocument(text: "[]", cursor: 1)
        EditingEngine(document: doc).backspace()
        #expect(doc.text.isEmpty)
    }

    @Test func tabStopsAndOutdentPreserveCode() {
        let doc = MemoryDocument(text: "  hello", cursor: 7)
        let engine = EditingEngine(document: doc)
        engine.indent()
        #expect(doc.text == "      hello")
        #expect(doc.cursor == 11)
        engine.outdent()
        #expect(doc.text == "  hello")
        #expect(doc.cursor == 7)
        engine.tab()
        #expect(doc.text == "  hello ")
    }

    @Test func unicodeCursorMovementDoesNotSplitEmoji() {
        let doc = MemoryDocument(text: "    let x = \"🧑🏽‍💻\"", cursor: nil)
        let engine = EditingEngine(document: doc)
        engine.outdent()
        #expect(doc.text == "let x = \"🧑🏽‍💻\"")
        #expect(doc.cursor == doc.text.utf16.count)
    }

    @Test func terminalProfileNeverAddsSmartCharacters() {
        let doc = MemoryDocument()
        var settings = KeyboardSettings()
        settings.compatibility = .terminal
        let engine = EditingEngine(document: doc, settings: settings)
        engine.type("{")
        engine.tab()
        engine.newline()
        engine.navigate(.up)
        engine.control("c")
        #expect(doc.text == "{\t\r\u{1B}[A\u{03}")
    }

    @Test func remoteProfileUsesLiteralInput() {
        let doc = MemoryDocument()
        var settings = KeyboardSettings()
        settings.compatibility = .remoteDesktop
        let engine = EditingEngine(document: doc, settings: settings)
        engine.type("(")
        engine.tab()
        engine.newline()
        #expect(doc.text == "(\t\n")
    }

    @Test func pythonNewlineRespectsIndentAndColon() {
        let doc = MemoryDocument(text: "  if ready:")
        var settings = KeyboardSettings()
        settings.language = .python
        let engine = EditingEngine(document: doc, settings: settings)
        engine.newline()
        #expect(doc.text == "  if ready:\n      ")
    }

    @Test func missingHostContextDoesNotDeleteUnknownText() {
        let doc = MemoryDocument(text: "anything")
        doc.exposesContext = false
        let engine = EditingEngine(document: doc)
        engine.outdent()
        #expect(doc.text == "anything")
        engine.type("(")
        #expect(doc.text == "anything(")
    }

    @Test func suggestionsReplaceOnlyCurrentIdentifier() {
        let doc = MemoryDocument(text: "let value = pri")
        let engine = EditingEngine(document: doc)
        engine.complete("print")
        #expect(doc.text == "let value = print")
    }

    @Test func quoteInsideWordIsLiteral() {
        let doc = MemoryDocument(text: "can")
        EditingEngine(document: doc).type("'")
        #expect(doc.text == "can'")
    }

    @Test func jsonFormattingRejectsInvalidInput() throws {
        #expect(try CodeFormatter.format("{\"a\":1}", language: .json).contains("  \"a\" : 1"))
        #expect(throws: (any Error).self) { try CodeFormatter.format("{oops", language: .json) }
    }

    @Test func formattingIgnoresBracesInStringsAndComments() throws {
        let input = "func run() {\nprint(\"}\") // {\nif true {\nrun()\n}\n}"
        let result = try CodeFormatter.format(input, language: .swift)
        #expect(result == "func run() {\n    print(\"}\") // {\n    if true {\n        run()\n    }\n}")
    }

    @Test func preferencesRoundTrip() throws {
        var settings = KeyboardSettings()
        settings.indentation = .tabs
        settings.swipeTyping = true
        settings.compatibility = .remoteDesktop
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(KeyboardSettings.self, from: data) == settings)
    }

    @Test func layoutExpandsWithUsableSpace() {
        #expect(KeyboardLayout.resolve(width: 390) == .compact)
        #expect(KeyboardLayout.resolve(width: 700) == .expanded)
        #expect(KeyboardLayout.resolve(width: 1100) == .studio)
        #expect(KeyboardLayout.resolve(width: 320) == .compact)
        #expect(KeyboardLayout.resolve(width: 440) == .compact)
        #expect(KeyboardLayout.resolve(width: 480) == .widePhone)
        #expect(KeyboardLayout.resolve(width: 768) == .studio)
    }

    @Test func completionWorkIsBoundedForLargeDocuments() {
        let doc = MemoryDocument(text: String(repeating: "oldIdentifier ", count: 100_000) + "\nnearbyIdentifier nea")
        let engine = EditingEngine(document: doc)
        #expect(engine.completions.contains("nearbyIdentifier"))
        doc.insert(String(repeating: "a", count: 129))
        #expect(engine.completions.isEmpty)
    }

    @Test func formatterPreservesMultilineTemplateContent() throws {
        let input = "function run() {\nconst value = `first\n  second\n    third`;\n}"
        let result = try CodeFormatter.format(input, language: .javascript)
        #expect(result.contains("`first\n  second\n    third`"))
        #expect(throws: CodeFormatter.FormattingError.self) { try CodeFormatter.format("x = '''\n  keep me\n'''", language: .python) }
    }

    @Test func ansiBacktabAndApplicationCursor() {
        let doc = MemoryDocument()
        var settings = KeyboardSettings()
        settings.compatibility = .terminal
        settings.terminalApplicationCursor = true
        let engine = EditingEngine(document: doc, settings: settings)
        engine.outdent(); engine.navigate(.left)
        #expect(doc.text == "\u{1B}[Z\u{1B}OD")
    }

    @Test func swipeDecoderRecognizesCodeWords() {
        var centers: [Character: SwipePoint] = [:]
        for (row, letters) in ["qwertyuiop", "asdfghjkl", "zxcvbnm"].enumerated() {
            for (column, letter) in letters.enumerated() {
                centers[letter] = .init(x: Double(column) * 0.09 + Double(row) * 0.04, y: Double(row) * 0.12)
            }
        }
        let trace = Array("print").compactMap { centers[$0] }
        #expect(SwipeDecoder.candidates(trace: trace, centers: centers).first == "print")
        #expect(SwipeDecoder.candidates(trace: [], centers: centers).isEmpty)
    }
}
