import UIKit
import Testing
import KeyboardCore
@testable import ScriptKeyboard

@Suite @MainActor
struct SnippetDraftRoutingTests {
    private final class Host: TextDocument {
        let buffer = MemoryDocument(text: "private host\ntext")
        var accesses = 0
        var before: String? { accesses += 1; return buffer.before }
        var after: String? { accesses += 1; return buffer.after }
        var selectedText: String? { accesses += 1; return buffer.selectedText }
        var hasCompleteContext: Bool { accesses += 1; return true }
        var allowsAutocorrection: Bool { accesses += 1; return true }
        var autocorrectionContextIdentifier: UUID? { accesses += 1; return buffer.autocorrectionContextIdentifier }
        func insert(_ text: String) { accesses += 1; buffer.insert(text) }
        func deleteBackward() { accesses += 1; buffer.deleteBackward() }
        func move(by offset: Int) { accesses += 1; buffer.move(by: offset) }
    }
    private func make() -> (CodingKeyboardView, PreferencesStore, Host) {
        let store = PreferencesStore(local: nil)
        store.settings.compatibility = .terminal
        store.settings.autocorrectProse = true
        store.settings.indentation = .tabs
        let host = Host()
        let keyboard = CodingKeyboardView(document: host, preferences: store)
        keyboard.frame = CGRect(x: 0, y: 0, width: 390, height: keyboard.desiredHeight)
        keyboard.layoutIfNeeded()
        host.accesses = 0
        return (keyboard, store, host)
    }
    private func button(_ id: String, in view: UIView) throws -> UIButton {
        if let button = view as? UIButton, button.accessibilityIdentifier == id { return button }
        for child in view.subviews { if let found = try? button(id, in: child) { return found } }
        throw MissingButton()
    }
    private struct MissingButton: Error {}
    private func tap(_ id: String, in keyboard: CodingKeyboardView) throws {
        let key = try button(id, in: keyboard)
        key.sendActions(for: .touchDown); key.sendActions(for: .touchUpInside)
    }
    private func action(_ title: String, in elements: [UIMenuElement]) -> UIAction? {
        for element in elements {
            if let action = element as? UIAction, action.title == title { return action }
            if let menu = element as? UIMenu, let found = action(title, in: menu.children) { return found }
        }
        return nil
    }

    @Test func formattingAndLineActionsUseOnlyTheLocalDraft() throws {
        let (keyboard, store, host) = make()
        store.settings.compatibility = .editor; keyboard.applySettings()
        let gear = try button("keyboard.quickSettings", in: keyboard)
        let format = try #require(action("Reindent selection", in: gear.menu?.children ?? []))
        host.accesses = 0
        let original = host.buffer.text
        keyboard.beginSnippetEditing(nil)
        keyboard.engine.type("Name")
        keyboard.selectSnippetField(name: false)
        keyboard.engine.type("{\nprint(1)\n}")
        let router = try #require(keyboard.engine.document as? KeyboardDocumentRouter)
        let local = try #require(router.local)
        local.selection = NSRange(location: 0, length: local.text.utf16.count)
        let trigger = UIButton()
        trigger.addAction(format, for: .primaryActionTriggered)
        trigger.sendActions(for: .primaryActionTriggered)
        #expect(local.text == "{\n\tprint(1)\n}")
        #expect(keyboard.engine.deleteLine())
        #expect(local.text == "{\n\tprint(1)")
        #expect(host.accesses == 0)
        #expect(host.buffer.text == original)
        keyboard.finishSnippetEditing(save: false)
    }

    @Test func formerCompanionSettingsAreReachableFromTheGear() throws {
        let (keyboard, store, _) = make()
        let gear = try button("keyboard.quickSettings", in: keyboard)
        for (title, keyPath) in [
            ("Skip existing closing delimiter", \KeyboardSettings.skipClosingDelimiter),
            ("Show number row in full layouts", \KeyboardSettings.showNumberRow),
            ("Show number hints", \KeyboardSettings.showKeyHints),
            ("Key press previews", \KeyboardSettings.keyPreviews),
            ("Drag space to move cursor", \KeyboardSettings.cursorScrubbing),
            ("Hold Delete to repeat", \KeyboardSettings.repeatDelete),
            ("Haptic feedback", \KeyboardSettings.haptics),
            ("Return sends carriage return (CR)", \KeyboardSettings.terminalReturnIsCR),
            ("Delete sends DEL instead of BS", \KeyboardSettings.terminalDeleteIsDEL),
            ("Application cursor mode (SS3)", \KeyboardSettings.terminalApplicationCursor)
        ] {
            let original = store.settings[keyPath: keyPath]
            let option = try #require(action(title, in: gear.menu?.children ?? []))
            let trigger = UIButton()
            trigger.addAction(option, for: .primaryActionTriggered)
            trigger.sendActions(for: .primaryActionTriggered)
            #expect(store.settings[keyPath: keyPath] != original)
        }
        for title in ["Compact", "Balanced", "Comfortable", "Add snippet", "Reset keyboard preferences and snippets"] {
            #expect(action(title, in: gear.menu?.children ?? []) != nil)
        }
    }

    @Test func allDraftActionsStayLocalAndSavingDoesNotInsert() throws {
        let (keyboard, store, host) = make()
        let original = host.buffer.text
        keyboard.beginSnippetEditing(nil)
        #expect(keyboard.isEditingSnippet)
        #expect(keyboard.engine.settings.compatibility == .editor)
        try tap("key.q", in: keyboard)
        keyboard.selectSnippetField(name: false)
        keyboard.engine.type("👩🏽‍💻e\u{301}")
        keyboard.engine.backspace()
        keyboard.engine.tab()
        keyboard.engine.newline()
        keyboard.engine.type("{")
        #expect(keyboard.engine.document.before == "👩🏽‍💻\t\n{")
        _ = keyboard.engine.navigate(.left)
        _ = keyboard.engine.navigate(.right)
        keyboard.engine.control("u")
        keyboard.refreshContext()
        keyboard.applySettings()
        #expect(host.accesses == 0)
        #expect(host.buffer.text == original)
        keyboard.finishSnippetEditing(save: true)
        #expect(!keyboard.isEditingSnippet)
        #expect(store.settings.snippets.last?.name == "q")
        #expect(store.settings.snippets.last?.text == "👩🏽‍💻\t\n{")
        #expect(host.buffer.text == original)
        #expect(keyboard.engine.settings.compatibility == .terminal)
        #expect((keyboard.engine.document as? KeyboardDocumentRouter)?.local == nil)
    }

    @Test func saveAndCancelWaitForHeldGridAndToolbarKeys() throws {
        let (keyboard, store, host) = make()
        keyboard.beginSnippetEditing(nil)
        try tap("key.q", in: keyboard)
        keyboard.selectSnippetField(name: false)
        let w = try button("key.w", in: keyboard)
        let arrow = try button("keyboard.arrow.left", in: keyboard)
        w.sendActions(for: .touchDown); arrow.sendActions(for: .touchDown)
        keyboard.finishSnippetEditing(save: true)
        #expect(keyboard.isEditingSnippet)
        w.sendActions(for: .touchUpInside)
        #expect(keyboard.isEditingSnippet)
        arrow.sendActions(for: .touchUpInside)
        #expect(!keyboard.isEditingSnippet)
        #expect(store.settings.snippets.last?.text == "w")
        #expect(host.accesses == 0)
        keyboard.beginSnippetEditing(nil)
        let e = try button("key.e", in: keyboard)
        e.sendActions(for: .touchDown)
        keyboard.finishSnippetEditing(save: false)
        #expect(keyboard.isEditingSnippet)
        e.sendActions(for: .touchUpInside)
        #expect(!keyboard.isEditingSnippet)
        #expect(host.accesses == 0)
    }

    @Test(arguments: ["key.q", "keyboard.arrow.left", "keyboard.escape", "keyboard.deleteLine", "keyboard.modifier.control"])
    func dismissalSuppressesLateReleasesAndClearsDraft(_ id: String) throws {
        let (keyboard, _, host) = make()
        keyboard.beginSnippetEditing(nil)
        let key = try button(id, in: keyboard)
        key.sendActions(for: .touchDown)
        keyboard.releaseTransientResources()
        host.accesses = 0
        key.sendActions(for: .touchUpInside)
        #expect(host.accesses == 0)
        #expect(!keyboard.isEditingSnippet)
        #expect((keyboard.engine.document as? KeyboardDocumentRouter)?.local == nil)
        #expect(!key.isSelected)
    }

    @Test func localLimitsAndUnicodeNeverReadOrModifyHost() {
        let host = Host()
        let router = KeyboardDocumentRouter(host: host)
        let local = MemoryDocument(text: "e\u{301}👩🏽‍💻")
        router.local = local; router.localLimit = 2
        router.insert("x")
        #expect(local.text == "e\u{301}👩🏽‍💻")
        router.deleteBackward()
        #expect(local.text == "e\u{301}")
        #expect(!router.replaceTextBeforeCursor("e\u{301}", with: "abc"))
        #expect(host.accesses == 0)
    }

    @Test func oversizedLegacySnippetIsDeclinedWithoutTruncation() {
        let (keyboard, _, host) = make()
        let snippet = CodeSnippet(name: "Legacy", text: String(repeating: "x", count: 4097))
        keyboard.beginSnippetEditing(snippet)
        #expect(!keyboard.isEditingSnippet)
        #expect(host.accesses == 0)
        #expect(snippet.text.count == 4097)
    }

    @Test(arguments: [("é", "e\u{301}"), ("e\u{301}", "é"), ("e\u{301}", "\u{301}")])
    func canonicallyEquivalentOrPartialGraphemeReplacementIsDeclined(_ values: (String, String)) {
        let host = Host()
        let router = KeyboardDocumentRouter(host: host)
        let local = MemoryDocument(text: values.0)
        router.local = local
        #expect(!router.replaceTextBeforeCursor(values.1, with: "x"))
        #expect(local.text == values.0)
        #expect(host.accesses == 0)
    }

    @Test func toolbarModifierTapsCancelAndCombineWithoutLosingLatches() throws {
        let (keyboard, _, _) = make()
        let ctrl = try button("keyboard.modifier.control", in: keyboard)
        let option = try button("keyboard.modifier.option", in: keyboard)
        try tap("keyboard.modifier.control", in: keyboard)
        #expect(ctrl.isSelected)
        try tap("keyboard.modifier.control", in: keyboard)
        #expect(!ctrl.isSelected)
        try tap("keyboard.modifier.control", in: keyboard)
        try tap("keyboard.modifier.option", in: keyboard)
        #expect(ctrl.isSelected && option.isSelected)
        keyboard.releaseTransientResources()
        #expect(!ctrl.isSelected && !option.isSelected)
    }
}
