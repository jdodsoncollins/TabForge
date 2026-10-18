import UIKit
import Testing
import KeyboardCore
@testable import ScriptKeyboard

@Suite @MainActor
struct TextViewDocumentTests {
    @Test func boundedContextSlicesAroundUTF16SelectionWithoutSplittingCharacters() {
        let prefix = String(repeating: "source ", count: 20_000) + "🧑🏽‍💻e\u{301}"
        let selected = "selected"
        let view = textView(prefix + selected + "\r\n😀z",
                            selection: NSRange(location: prefix.utf16.count, length: selected.utf16.count))
        let document = TextViewDocument(view)

        #expect(document.contextBeforeInput(maximumCharacters: 2) == "🧑🏽‍💻e\u{301}")
        #expect(document.contextAfterInput(maximumCharacters: 2) == "\r\n😀")
        #expect(document.contextBeforeInput(maximumCharacters: 0) == "")
        #expect(document.contextAfterInput(maximumCharacters: -1) == "")
        #expect(document.before == prefix)
        #expect(document.after == "\r\n😀z")
        #expect(view.selectedRange == NSRange(location: prefix.utf16.count, length: selected.utf16.count))

        document.textView = nil
        #expect(document.contextBeforeInput(maximumCharacters: 2) == nil)
        #expect(document.contextAfterInput(maximumCharacters: 2) == nil)
    }

    @Test func verticalArrowsUseVisualLinesInAWrappedNativeEditor() {
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: 150, height: 300))
        view.font = .monospacedSystemFont(ofSize: 20, weight: .regular)
        view.text = "A long logical line with several words that wraps onto multiple visible lines."
        view.layoutIfNeeded()
        view.selectedRange = NSRange(location: view.text.utf16.count, length: 0)
        let engine = EditingEngine(document: TextViewDocument(view))
        let original = view.text
        let end = view.selectedRange.location
        #expect(engine.navigate(.up))
        let upper = view.selectedRange.location
        #expect(upper < end)
        #expect(engine.navigate(.down))
        #expect(view.selectedRange.location > upper)
        #expect(view.text == original)
    }

    private func textView(_ text: String, selection: NSRange? = nil) -> UITextView {
        let view = UITextView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        view.text = text
        view.selectedRange = selection ?? NSRange(location: text.utf16.count, length: 0)
        return view
    }

    @Test(arguments: ["😀", "e\u{301}", "🧑🏽‍💻"])
    func cursorKeysAndEditsPreserveComposedCharacters(_ character: String) {
        let view = textView("a\(character)b")
        let document = TextViewDocument(view)
        let engine = EditingEngine(document: document)
        let length = character.utf16.count

        engine.navigate(.left)
        #expect(view.selectedRange == NSRange(location: 1 + length, length: 0))
        engine.navigate(.left)
        #expect(view.selectedRange == NSRange(location: 1, length: 0))
        #expect(document.before == "a")
        #expect(document.after == "\(character)b")

        engine.type("X")
        #expect(view.text == "aX\(character)b")
        #expect(view.selectedRange == NSRange(location: 2, length: 0))
        engine.navigate(.right)
        #expect(view.selectedRange == NSRange(location: 2 + length, length: 0))
        engine.backspace()
        #expect(view.text == "aXb")
        #expect(view.selectedRange == NSRange(location: 2, length: 0))
    }

    @Test(arguments: ["😀", "e\u{301}", "🧑🏽‍💻"])
    func movingRightThenInsertingAndDeletingKeepsUTF16Selection(_ character: String) {
        let view = textView("a\(character)b", selection: NSRange(location: 1, length: 0))
        let document = TextViewDocument(view)
        let engine = EditingEngine(document: document)
        let length = character.utf16.count

        engine.navigate(.right)
        #expect(view.selectedRange == NSRange(location: 1 + length, length: 0))
        engine.type("X")
        #expect(view.text == "a\(character)Xb")
        #expect(view.selectedRange == NSRange(location: 2 + length, length: 0))
        engine.navigate(.left)
        #expect(view.selectedRange == NSRange(location: 1 + length, length: 0))
        engine.backspace()
        #expect(view.text == "aXb")
        #expect(view.selectedRange == NSRange(location: 1, length: 0))
    }

    @Test(arguments: ["😀", "e\u{301}", "🧑🏽‍💻"])
    func wrappingAUnicodeSelectionAndDeletingPreservesSurroundingText(_ character: String) {
        let length = character.utf16.count
        let view = textView("a\(character)b", selection: NSRange(location: 1, length: length))
        let document = TextViewDocument(view)
        let engine = EditingEngine(document: document)
        #expect(document.before == "a")
        #expect(document.selectedText == character)
        #expect(document.after == "b")

        engine.type("[")
        #expect(view.text == "a[\(character)]b")
        #expect(view.selectedRange == NSRange(location: 2 + length, length: 0))
        engine.backspace()
        #expect(view.text == "a[]b")
        #expect(view.selectedRange == NSRange(location: 2, length: 0))
        engine.backspace()
        #expect(view.text == "ab")
        #expect(view.selectedRange == NSRange(location: 1, length: 0))
    }

    @Test func multilineSelectionIndentAndOutdentPreserveUnicode() {
        let source = "  🧑🏽‍💻\n  e\u{301}"
        let view = textView(source, selection: NSRange(location: 0, length: source.utf16.count))
        let document = TextViewDocument(view)
        var settings = KeyboardSettings()
        settings.indentation = .twoSpaces
        let engine = EditingEngine(document: document, settings: settings)

        engine.indent()
        let indented = "    🧑🏽‍💻\n    e\u{301}"
        #expect(view.text == indented)
        #expect(view.selectedRange == NSRange(location: indented.utf16.count, length: 0))
        view.selectedRange = NSRange(location: 0, length: indented.utf16.count)
        engine.outdent()
        #expect(view.text == source)
        #expect(view.selectedRange == NSRange(location: source.utf16.count, length: 0))
    }

    @Test func currentLineOutdentKeepsCursorAfterUnicodeText() {
        let source = "    let name = \"🧑🏽‍💻 e\u{301}\""
        let view = textView(source)
        let document = TextViewDocument(view)
        let engine = EditingEngine(document: document)

        engine.outdent()

        let expected = "let name = \"🧑🏽‍💻 e\u{301}\""
        #expect(view.text == expected)
        #expect(view.selectedRange == NSRange(location: expected.utf16.count, length: 0))
    }

    @Test func deletingALargeUnicodeLineIsOneNativeEdit() {
        let source = "first\n" + String(repeating: "🧑🏽‍💻 e\u{301}", count: 2_000) + "\nlast"
        let view = textView(source, selection: NSRange(location: 6, length: 0))
        let document = TextViewDocument(view)
        var changes = 0
        document.onChange = { changes += 1 }

        #expect(EditingEngine(document: document).deleteLine())
        #expect(view.text == "first\nlast")
        #expect(view.selectedRange == NSRange(location: 6, length: 0))
        #expect(changes == 1)
    }

    @Test func nativeLineDeletionCanBeUndone() throws {
        let view = textView("first\nsecond\nlast", selection: NSRange(location: 8, length: 0))
        let document = TextViewDocument(view)
        #expect(EditingEngine(document: document).deleteLine())
        let undo = try #require(view.undoManager)
        #expect(undo.canUndo)
        undo.undo()
        #expect(view.text == "first\nsecond\nlast")
    }

    @Test(arguments: [CompatibilityMode.editor, .terminal, .remoteDesktop])
    func toolbarLineActionMatchesTheInputProfile(_ profile: CompatibilityMode) throws {
        let document = MemoryDocument(text: "first\nline\nlast", cursor: 8)
        let suite = "TabForge.LineButtonTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(local: defaults)
        preferences.settings.compatibility = profile
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        let button = try #require(toolbar.subviews.first { $0.accessibilityIdentifier == "keyboard.deleteLine" } as? UIButton)
        #expect(button.isEnabled == (profile != .remoteDesktop))
        if profile == .editor {
            #expect(button.accessibilityLabel == "Delete line")
            button.sendActions(for: .touchUpInside)
            #expect(document.text == "first\nlast")
        } else if profile == .terminal {
            #expect(button.accessibilityLabel == "Send Ctrl-U")
            button.sendActions(for: .touchUpInside)
            #expect(document.text == "first\nli\u{15}ne\nlast")
        }
    }
}
