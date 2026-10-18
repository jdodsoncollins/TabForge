import Foundation
import Testing
@testable import KeyboardCore

@Suite @MainActor
struct ShortcutTests {
    @Test func terminalControlMetaAndCombinedChords() {
        let doc = MemoryDocument()
        var settings = KeyboardSettings(); settings.compatibility = .terminal
        let engine = EditingEngine(document: doc, settings: settings)
        #expect(engine.sendShortcut("c", modifiers: .control))
        #expect(engine.sendShortcut("b", modifiers: .option))
        #expect(engine.sendShortcut("a", modifiers: [.control, .option]))
        #expect(engine.sendShortcut(" ", modifiers: .control))
        #expect(engine.sendShortcut("?", modifiers: .control))
        #expect(doc.text == "\u{03}\u{1B}b\u{1B}\u{01}\u{00}\u{7F}")
    }

    @Test func modifiedTerminalArrowsUseXtermSequencesEvenInApplicationMode() {
        let doc = MemoryDocument()
        var settings = KeyboardSettings(); settings.compatibility = .terminal; settings.terminalApplicationCursor = true
        let engine = EditingEngine(document: doc, settings: settings)
        #expect(engine.navigate(.left))
        #expect(engine.navigate(.up, modifiers: .control))
        #expect(engine.navigate(.right, modifiers: .option))
        #expect(engine.navigate(.down, modifiers: [.control, .option]))
        #expect(engine.navigate(.pageUp, modifiers: .control))
        #expect(doc.text == "\u{1B}OD\u{1B}[1;5A\u{1B}[1;3C\u{1B}[1;7B\u{1B}[5;5~")
    }

    @Test(arguments: CompatibilityMode.allCases)
    func unsupportedShortcutsNeverInsertAnUnmodifiedCharacter(_ mode: CompatibilityMode) {
        let doc = MemoryDocument(text: "keep", cursor: 2)
        var settings = KeyboardSettings(); settings.compatibility = mode
        let engine = EditingEngine(document: doc, settings: settings)
        #expect(!engine.sendShortcut("c", modifiers: .command))
        #expect(!engine.sendShortcut("😀", modifiers: .control))
        #expect(!engine.sendShortcut("ß", modifiers: .control))
        if mode != .terminal { #expect(!engine.sendShortcut("c", modifiers: .control)) }
        #expect(doc.text == "keep" && doc.cursor == 2)
    }

    @Test func optionArrowsNavigateCodeIdentifiersAndUnicode() {
        let doc = MemoryDocument(text: "let café_value = 🧑🏽‍💻")
        let engine = EditingEngine(document: doc)
        #expect(engine.navigate(.left, modifiers: .option))
        #expect(doc.after == "🧑🏽‍💻")
        #expect(engine.navigate(.left, modifiers: .option))
        #expect(doc.after == "= 🧑🏽‍💻")
        #expect(engine.navigate(.left, modifiers: .option))
        #expect(doc.after == "café_value = 🧑🏽‍💻")
        #expect(engine.navigate(.right, modifiers: .option))
        #expect(doc.before == "let café_value")
    }

    @Test func commandArrowsMoveToLineAndDocumentBoundaries() {
        let doc = MemoryDocument(text: "one\ntwo\nthree", cursor: 6)
        let engine = EditingEngine(document: doc)
        #expect(engine.navigate(.left, modifiers: .command)); #expect(doc.cursor == 4)
        #expect(engine.navigate(.right, modifiers: .command)); #expect(doc.cursor == 7)
        #expect(engine.navigate(.up, modifiers: .command)); #expect(doc.cursor == 0)
        #expect(engine.navigate(.down, modifiers: .command)); #expect(doc.cursor == doc.text.utf16.count)
    }

    @Test(arguments: ["\n", "\r\n"])
    func verticalMovementUsesGraphemeColumnsWithoutSplittingEmoji(_ newline: String) {
        let text = "ab🧑🏽‍💻z" + newline + "xy" + newline + "e\u{301}123"
        let doc = MemoryDocument(text: text, cursor: ("ab🧑🏽‍💻z" + newline + "xy").utf16.count)
        let engine = EditingEngine(document: doc)
        #expect(engine.navigate(.up)); #expect(doc.before == "ab")
        #expect(engine.navigate(.down)); #expect(doc.before?.hasSuffix("xy") == true)
        #expect(engine.navigate(.down)); #expect(doc.before?.hasSuffix("e\u{301}1") == true)
        #expect(doc.text == text)
    }

    @Test func missingContextDeclinesVerticalAndWordMovement() {
        let doc = MemoryDocument(text: "private", cursor: 3); doc.exposesContext = false
        let engine = EditingEngine(document: doc)
        #expect(!engine.navigate(.up))
        #expect(!engine.navigate(.left, modifiers: .option))
        #expect(!engine.navigate(.up, modifiers: .command))
        #expect(doc.text == "private" && doc.cursor == 3)
    }
}
