import Foundation
import Testing
@testable import KeyboardCore

@Suite @MainActor
struct LineDeletionTests {
    @Test(arguments: [
        ("first\nsecond\nthird", 9, "first\nthird", 6),
        ("first\nlast", 8, "first", 5),
        ("only", 2, "", 0),
        ("a\n\nb", 2, "a\nb", 2),
        ("a\n", 2, "a", 1),
        ("a\r\nb\r\nc", 4, "a\r\nc", 3),
        ("first\n🧑🏽‍💻 e\u{301}\nlast", 6, "first\nlast", 6)
    ])
    func deletesOneLogicalLine(_ example: (String, Int, String, Int)) {
        let (source, cursor, expected, expectedCursor) = example
        let document = MemoryDocument(text: source, cursor: cursor)
        let engine = EditingEngine(document: document)
        #expect(engine.canDeleteLine)
        #expect(engine.deleteLine())
        #expect(document.text == expected)
        #expect(document.cursor == expectedCursor)
    }

    @Test func selectionsEmptyBuffersAndMissingContextRemainUnchanged() {
        let selection = MemoryDocument(text: "selected", selection: NSRange(location: 0, length: 8))
        #expect(!EditingEngine(document: selection).deleteLine())
        #expect(selection.text == "selected")
        #expect(selection.selection == NSRange(location: 0, length: 8))
        let empty = MemoryDocument()
        #expect(!EditingEngine(document: empty).deleteLine())
        let hidden = MemoryDocument(text: "private\nline\nother")
        hidden.exposesContext = false
        #expect(!EditingEngine(document: hidden).deleteLine())
        #expect(hidden.text == "private\nline\nother")
    }

    @Test func proxyStyleDeletionRequiresBothVisibleBoundaries() {
        let completeLine = ContextWindowDocument("first\n🧑🏽‍💻 e\u{301}\nlast", cursor: 6)
        #expect(EditingEngine(document: completeLine).deleteLine())
        #expect(completeLine.memory.text == "first\nlast")
        #expect(completeLine.memory.cursor == 6)

        for (source, cursor) in [("a long prefix before the cursor\nnext", 30), ("previous\nlast line", 12), ("x\nabcdef\ny", 5)] {
            let limited = ContextWindowDocument(source, cursor: cursor, limit: 5)
            #expect(!EditingEngine(document: limited).deleteLine())
            #expect(limited.memory.text == source)
            #expect(limited.memory.cursor == cursor)
        }
    }

    @Test func ignoredCursorMovementDoesNotDeleteText() {
        for (source, cursor) in [("first\ntarget\nlast", 8), ("first\n\n\nlast", 6), ("same\nsame\nlast", 5)] {
            let document = ContextWindowDocument(source, cursor: cursor)
            document.allowsMovement = false
            #expect(!EditingEngine(document: document).deleteLine())
            #expect(document.memory.text == source)
            #expect(document.memory.cursor == cursor)
        }
    }

    @Test func ambiguousContextIsDeclinedBeforeMoving() {
        let document = ContextWindowDocument("same\nsame\nlast", cursor: 5)
        #expect(!EditingEngine(document: document).deleteLine())
        #expect(document.memory.text == "same\nsame\nlast")
        #expect(document.memory.cursor == 5)
    }

    @Test func terminalAndRemoteDoNotPerformContextDeletion() {
        for profile in [CompatibilityMode.terminal, .remoteDesktop] {
            let document = MemoryDocument(text: "first\nline\nlast", cursor: 8)
            var settings = KeyboardSettings()
            settings.compatibility = profile
            let engine = EditingEngine(document: document, settings: settings)
            #expect(!engine.canDeleteLine)
            #expect(!engine.deleteLine())
            #expect(document.text == "first\nline\nlast")
            #expect(document.cursor == 8)
        }
        let terminal = MemoryDocument()
        var settings = KeyboardSettings()
        settings.compatibility = .terminal
        let engine = EditingEngine(document: terminal, settings: settings)
        engine.control("u"); engine.control("k")
        #expect(terminal.text == "\u{15}\u{0B}")
    }
}

@MainActor
private final class ContextWindowDocument: TextDocument {
    let memory: MemoryDocument
    let limit: Int
    var allowsMovement = true
    init(_ source: String, cursor: Int, limit: Int = 100) {
        memory = MemoryDocument(text: source, cursor: cursor)
        self.limit = limit
    }
    var before: String? { memory.before.map { String($0.suffix(limit)) } }
    var after: String? { memory.after.map { String($0.prefix(limit)) } }
    var selectedText: String? { memory.selectedText }
    func insert(_ text: String) { memory.insert(text) }
    func deleteBackward() { memory.deleteBackward() }
    func move(by offset: Int) { if allowsMovement { memory.move(by: offset) } }
}
