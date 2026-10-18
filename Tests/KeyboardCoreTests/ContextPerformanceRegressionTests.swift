import Foundation
import Testing
@testable import KeyboardCore

@Suite @MainActor
struct ContextPerformanceRegressionTests {
    @Test func ordinaryTypingDoesNotReadContext() {
        let document = ContextReadSpy(text: "source")
        let engine = EditingEngine(document: document)
        for text in ["a", " ", ":", "=>", "🧑🏽‍💻"] { engine.type(text) }

        #expect(document.buffer.text == "sourcea :=>🧑🏽‍💻")
        #expect(document.fullBeforeReads == 0)
        #expect(document.fullAfterReads == 0)
        #expect(document.beforeLimits.isEmpty)
        #expect(document.afterLimits.isEmpty)
    }

    @Test func delimiterTypingReadsOnlyAdjacentCharacters() {
        let document = ContextReadSpy(text: String(repeating: "source ", count: 10_000))
        EditingEngine(document: document).type("[")

        #expect(document.buffer.text.hasSuffix("[]"))
        #expect(document.fullBeforeReads == 0)
        #expect(document.fullAfterReads == 0)
        #expect(document.beforeLimits == [1])
        #expect(document.afterLimits == [1])
    }

    @Test func completionsRequestABoundedWindowBeforeExtraction() {
        let document = ContextReadSpy(text: String(repeating: "oldIdentifier ", count: 100_000) + "\nnearbyIdentifier nea")

        #expect(EditingEngine(document: document).completions.contains("nearbyIdentifier"))
        #expect(document.fullBeforeReads == 0)
        #expect(document.fullAfterReads == 0)
        #expect(document.beforeLimits == [4096])
    }

    @Test func boundedContextPreservesCharactersAndUnavailableContext() {
        let prefix = "a🧑🏽‍💻e\u{301}"
        let selected = "selected"
        let document = MemoryDocument(text: prefix + selected + "\r\n😀z",
                                      selection: NSRange(location: prefix.utf16.count, length: selected.utf16.count))
        #expect(document.contextBeforeInput(maximumCharacters: 2) == "🧑🏽‍💻e\u{301}")
        #expect(document.contextAfterInput(maximumCharacters: 2) == "\r\n😀")
        #expect(document.contextBeforeInput(maximumCharacters: 0) == "")
        #expect(document.contextAfterInput(maximumCharacters: -1) == "")
        #expect(document.before == prefix)
        document.exposesContext = false
        #expect(document.contextBeforeInput(maximumCharacters: 0) == nil)
        #expect(document.contextAfterInput(maximumCharacters: 10) == nil)

        let splitCharacter = MemoryDocument(text: "e\u{301}z", cursor: 1)
        #expect(splitCharacter.contextBeforeInput(maximumCharacters: 1) == nil)
        #expect(splitCharacter.contextAfterInput(maximumCharacters: 1) == nil)
    }

    @Test func adjacentArrowNavigationUsesBoundedUnicodeContext() {
        let prefix = "prefix\n"
        let character = "🧑🏽‍💻"
        let document = ContextReadSpy(text: prefix + character + "e\u{301} suffix", cursor: prefix.utf16.count + character.utf16.count)
        let engine = EditingEngine(document: document)

        #expect(engine.navigate(.left))
        #expect(document.buffer.cursor == prefix.utf16.count)
        #expect(engine.navigate(.right))
        #expect(document.buffer.cursor == prefix.utf16.count + character.utf16.count)
        #expect(document.beforeLimits == [1])
        #expect(document.afterLimits == [1])
        #expect(document.fullBeforeReads == 0)
        #expect(document.fullAfterReads == 0)
    }

    @Test func wordAndLineNavigationRequestTheExistingBoundedWindow() {
        let prefix = String(repeating: "old line\n", count: 10_000)
        let identifier = "first_second"
        let document = ContextReadSpy(text: prefix + identifier + " tail\nsuffix", cursor: prefix.utf16.count + identifier.utf16.count)
        let engine = EditingEngine(document: document)

        #expect(engine.navigate(.left, modifiers: .option))
        #expect(document.buffer.cursor == prefix.utf16.count)
        #expect(engine.navigate(.right, modifiers: .option))
        #expect(document.buffer.cursor == prefix.utf16.count + identifier.utf16.count)
        #expect(engine.navigate(.home))
        #expect(document.buffer.cursor == prefix.utf16.count)
        #expect(engine.navigate(.end))
        #expect(document.buffer.cursor == prefix.utf16.count + identifier.utf16.count + " tail".utf16.count)
        #expect(document.beforeLimits == [4096, 4096])
        #expect(document.afterLimits == [4096, 4096])
        #expect(document.fullBeforeReads == 0)
        #expect(document.fullAfterReads == 0)
    }
}

@MainActor
private final class ContextReadSpy: TextDocument {
    let buffer: MemoryDocument
    var fullBeforeReads = 0
    var fullAfterReads = 0
    var beforeLimits: [Int] = []
    var afterLimits: [Int] = []

    init(text: String, cursor: Int? = nil) { buffer = MemoryDocument(text: text, cursor: cursor) }
    var before: String? { fullBeforeReads += 1; return buffer.before }
    var after: String? { fullAfterReads += 1; return buffer.after }
    var selectedText: String? { buffer.selectedText }
    var hasCompleteContext: Bool { true }
    func contextBeforeInput(maximumCharacters: Int) -> String? {
        beforeLimits.append(maximumCharacters)
        return buffer.contextBeforeInput(maximumCharacters: maximumCharacters)
    }
    func contextAfterInput(maximumCharacters: Int) -> String? {
        afterLimits.append(maximumCharacters)
        return buffer.contextAfterInput(maximumCharacters: maximumCharacters)
    }
    func insert(_ text: String) { buffer.insert(text) }
    func deleteBackward() { buffer.deleteBackward() }
    func move(by offset: Int) { buffer.move(by: offset) }
}
