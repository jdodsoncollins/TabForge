import Foundation
import Testing
@testable import KeyboardCore

@Suite @MainActor
struct AutocorrectionTests {
    private func engine(_ document: any TextDocument) -> EditingEngine {
        var settings = KeyboardSettings()
        settings.autocorrectProse = true
        let result = EditingEngine(document: document, settings: settings)
        result.correctionProvider = { word in ["teh": "the", "Teh": "the", "recieve": "receive", "pritn": "print", "helo": "hello"][word] }
        return result
    }

    @Test func defaultAndHostOptOutNeverConsultSpellingService() {
        let document = MemoryDocument(text: "teh")
        document.allowsAutocorrection = true
        let editor = EditingEngine(document: document)
        var calls = 0
        editor.correctionProvider = { _ in calls += 1; return "the" }
        editor.type(" ")
        #expect(document.text == "teh ")
        #expect(calls == 0)
        document.insert("teh")
        editor.settings.autocorrectProse = true
        document.allowsAutocorrection = false
        editor.type(" ")
        #expect(document.text == "teh teh ")
        #expect(calls == 0)
    }

    @Test(arguments: [CompatibilityMode.terminal, .remoteDesktop])
    func terminalAndRemoteStayLiteral(_ profile: CompatibilityMode) {
        let document = MemoryDocument(text: "teh")
        document.allowsAutocorrection = true
        let editor = engine(document)
        editor.settings.compatibility = profile
        editor.type(" ")
        #expect(document.text == "teh ")
    }

    @Test(arguments: [("teh", "the "), ("Teh", "The "), ("Please recieve", "Please receive "), ("This is teh", "This is the ")])
    func correctsOrdinaryEnglishAtSpace(_ example: (String, String)) {
        let document = MemoryDocument(text: example.0)
        document.allowsAutocorrection = true
        engine(document).type(" ")
        #expect(document.text == example.1)
    }

    @Test(arguments: ["let value = teh", "let teh", "var teh", "  func teh", "def teh", "const value teh", "return teh", "if teh", "throw teh", "git teh", "sudo teh", "echo teh", "some_teh", "someTeh", "TEH", "value2teh", "https://teh", "/usr/teh", "name@teh", "\"teh", "'teh", "`teh", "teh-value", "pritn", "teh[0]", String(repeating: "a", count: 33)])
    func unsafeTokensRemainLiteral(_ source: String) {
        let document = MemoryDocument(text: source)
        document.allowsAutocorrection = true
        engine(document).type(" ")
        #expect(document.text == source + " ")
    }

    @Test func selectionUnavailableContextAndAdjacentWordStayLiteral() {
        let selected = MemoryDocument(text: "teh", selection: NSRange(location: 0, length: 3))
        selected.allowsAutocorrection = true
        engine(selected).type(" ")
        #expect(selected.text == " ")
        let hidden = MemoryDocument(text: "teh")
        hidden.allowsAutocorrection = true
        hidden.exposesContext = false
        engine(hidden).type(" ")
        #expect(hidden.text == "teh ")
        let middle = MemoryDocument(text: "tehsuffix", cursor: 3)
        middle.allowsAutocorrection = true
        engine(middle).type(" ")
        #expect(middle.text == "teh suffix")
    }

    @Test(arguments: ["other", "teh value", "🧑🏽‍💻", "theValue", "TEH", "print", "there"])
    func unexpectedProviderResultsCannotReplaceText(_ proposed: String) {
        let document = MemoryDocument(text: "teh")
        document.allowsAutocorrection = true
        let editor = engine(document)
        editor.correctionProvider = { _ in proposed }
        editor.type(" ")
        #expect(document.text == "teh ")
    }

    @Test func immediateBackspaceRestoresOriginalAndRejectsTheGuessOnce() {
        let document = MemoryDocument(text: "Please teh")
        document.allowsAutocorrection = true
        let editor = engine(document)
        editor.type(" ")
        #expect(document.text == "Please the ")
        editor.backspace()
        #expect(document.text == "Please teh")
        editor.type(" ")
        #expect(document.text == "Please teh ")
        editor.backspace()
        #expect(document.text == "Please teh")
        editor.type(" ")
        #expect(document.text == "Please the ")
    }

    @Test func laterTypingNavigationAndFocusChangesInvalidateCorrectionUndo() {
        for change in 0..<4 {
            let document = MemoryDocument(text: "teh")
            document.allowsAutocorrection = true
            let editor = engine(document)
            editor.type(" ")
            switch change {
            case 0: editor.type("a")
            case 1: _ = editor.navigate(.left); _ = editor.navigate(.right)
            case 2: document.autocorrectionContextIdentifier = UUID()
            default: editor.invalidateAutocorrection()
            }
            editor.backspace()
            #expect(document.text == (change == 0 ? "the " : "the"))
        }
    }

    @Test func changedAnchorsPreventUndoOfAnUnrelatedWord() {
        let document = MemoryDocument(text: "first teh second", cursor: 9)
        document.allowsAutocorrection = true
        let editor = engine(document)
        editor.type(" ")
        document.insert("changed")
        editor.backspace()
        #expect(document.text == "first the change second")
    }

    @Test func staleProviderResultsCannotEditAnotherDocument() {
        let document = MemoryDocument(text: "teh")
        document.allowsAutocorrection = true
        let editor = engine(document)
        editor.correctionProvider = { _ in document.autocorrectionContextIdentifier = UUID(); return "the" }
        editor.type(" ")
        #expect(document.text == "teh ")
    }

    @Test func proxyContextEdgeNeedsObservedTyping() {
        let existing = AutocorrectionProxy("prefixteh", limit: 3)
        engine(existing).type(" ")
        #expect(existing.memory.text == "prefixteh ")
        let ownWord = AutocorrectionProxy("")
        let editor = engine(ownWord)
        for letter in "teh" { editor.type(String(letter)) }
        editor.type(" ")
        #expect(ownWord.memory.text == "the ")
        editor.backspace()
        #expect(ownWord.memory.text == "teh")
        let partial = AutocorrectionProxy("t")
        let partialEditor = engine(partial)
        partialEditor.type("e"); partialEditor.type("h"); partialEditor.type(" ")
        #expect(partial.memory.text == "teh ")
    }

    @Test func slidingContextCommitsOneSeparatorAndDeclinesUnverifiedUndo() {
        let document = AutocorrectionProxy("a teh", limit: 4)
        let editor = engine(document)
        editor.type(" ")
        #expect(document.memory.text == "a the ")
        // The old left anchor no longer fits; ordinary Backspace removes space.
        editor.backspace()
        #expect(document.memory.text == "a the")
    }

    @Test func declinedDeletionRollsBackOnlyVerifiedEdits() {
        for failure in 1...3 {
            let document = AutocorrectionProxy("Please teh")
            document.ignoreDeleteAt = failure
            engine(document).type(" ")
            #expect(document.memory.text == "Please teh ")
        }
    }

    @Test func declinedReplacementRestoresTheOriginalSpelling() {
        let document = AutocorrectionProxy("Please teh")
        document.ignoredInsertion = "the"
        engine(document).type(" ")
        #expect(document.memory.text == "Please teh ")
    }

    @Test func nilRightContextRequiresAnEntireObservedWord() {
        for existing in ["teh", "Please teh"] {
            let document = AutocorrectionProxy(existing)
            document.omitsRightContext = true
            engine(document).type(" ")
            #expect(document.memory.text == existing + " ")
        }
        let document = AutocorrectionProxy("")
        document.omitsRightContext = true
        let editor = engine(document)
        for character in "teh" { editor.type(String(character)) }
        editor.type(" ")
        #expect(document.memory.text == "the ")
        editor.backspace()
        #expect(document.memory.text == "teh")
        editor.type(" ")
        #expect(document.memory.text == "teh ")
    }

    @Test func externalCursorCallbacksInvalidateUndoEvenAfterReturning() {
        let document = MemoryDocument(text: "Please teh")
        document.allowsAutocorrection = true
        let editor = engine(document)
        editor.type(" ")
        document.move(by: -1)
        editor.validateAutocorrectionContext()
        document.move(by: 1)
        editor.validateAutocorrectionContext()
        editor.backspace()
        #expect(document.text == "Please the")
    }

    @Test func externalCursorCallbacksInvalidateObservedTyping() {
        let document = AutocorrectionProxy("")
        document.omitsRightContext = true
        let editor = engine(document)
        for character in "teh" { editor.type(String(character)) }
        document.move(by: -1)
        editor.validateAutocorrectionContext()
        document.move(by: 1)
        editor.validateAutocorrectionContext()
        editor.type(" ")
        #expect(document.memory.text == "teh ")
    }

    @Test func partiallyAcceptedReplacementRollsBackVerifiedInsertedText() {
        let document = AutocorrectionProxy("Please helo")
        document.maximumInsertionLength = 4
        engine(document).type(" ")
        #expect(document.memory.text == "Please helo ")
        #expect(document.deletionCount == 8)
    }

    @Test func fieldCapacityCannotTurnAnAttemptedCorrectionIntoLostSpelling() {
        let document = AutocorrectionProxy("")
        document.capacity = 4
        let editor = engine(document)
        for character in "helo" { editor.type(String(character)) }
        editor.type(" ")
        #expect(document.memory.text == "helo")
        #expect(document.deletionCount == 8)
    }

    @Test func transformedReplacementRollsBackOnlyTheObservedInsertedSegment() {
        let document = AutocorrectionProxy("Please teh")
        document.transformedInsertion = ("the", "THE")
        engine(document).type(" ")
        #expect(document.memory.text == "Please teh ")
        #expect(document.deletionCount == 6)
    }

    @Test func transformedWhitespaceCannotBecomeAFakeRollbackBoundary() {
        let document = AutocorrectionProxy(" teh")
        document.transformedInsertion = ("the", "the ")
        #expect(!document.replaceTextBeforeCursor("teh", with: "the"))
        #expect(document.memory.text == " the ")
        #expect(document.deletionCount == 3)
        let typing = AutocorrectionProxy(" teh")
        typing.transformedInsertion = ("the", "the ")
        engine(typing).type(" ")
        #expect(typing.memory.text == " the  ")
        #expect(typing.deletionCount == 3)
    }

    @Test(arguments: [(" the teh", "next the ", " the next the "), ("  teh", " y", "   y"), ("tehteh", "tehVALUE", "tehtehVALUE")])
    func repeatedAndOverlappingAnchorsDeclineRollback(_ example: (String, String, String)) {
        let document = AutocorrectionProxy(example.0)
        document.transformedInsertion = ("the", example.1)
        #expect(!document.replaceTextBeforeCursor("teh", with: "the"))
        #expect(document.memory.text == example.2)
        #expect(document.deletionCount == 3)
    }

    @Test func ignoredInsertionWithShrinkingContextCannotClaimSuccess() {
        let document = AutocorrectionProxy("theteh")
        document.ignoredInsertion = "the"
        document.shrunkenLimitAfterIgnoredInsertion = 2
        #expect(!document.replaceTextBeforeCursor("teh", with: "the"))
        // The host hid the full original anchor after the edit. Do not delete
        // or blindly add text to the unverified cursor after that point.
        #expect(document.memory.text == "the")
        #expect(document.deletionCount == 3)
    }

    @Test func ignoredInsertionAtTheStartCanRestoreOriginalWithStableNilRightContext() {
        let document = AutocorrectionProxy("")
        document.omitsRightContext = true
        let editor = engine(document)
        for character in "teh" { editor.type(String(character)) }
        document.ignoredInsertion = "the"
        document.shrunkenLimitAfterIgnoredInsertion = 2
        editor.type(" ")
        #expect(document.memory.text == "teh ")
    }

    @Test func preferenceRecordsWithoutAutocorrectKeepExistingChoices() throws {
        var settings = KeyboardSettings()
        settings.language = .python
        settings.indentation = .tabs
        settings.autocorrectProse = true
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(KeyboardSettings.self, from: data).autocorrectProse)
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "proseAutocorrection")
        let restored = try JSONDecoder().decode(KeyboardSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(!restored.autocorrectProse)
        #expect(restored.language == .python)
        #expect(restored.indentation == .tabs)
    }
}

@MainActor
private final class AutocorrectionProxy: TextDocument {
    let memory: MemoryDocument
    var limit: Int
    var ignoreDeleteAt: Int?
    var ignoredInsertion: String?
    var shrunkenLimitAfterIgnoredInsertion: Int?
    var maximumInsertionLength: Int?
    var capacity: Int?
    var transformedInsertion: (String, String)?
    var omitsRightContext = false
    private var deletions = 0
    var deletionCount: Int { deletions }
    var allowsAutocorrection: Bool { true }
    var autocorrectionContextIdentifier: UUID? { memory.autocorrectionContextIdentifier }
    init(_ text: String, limit: Int = 64) {
        memory = MemoryDocument(text: text)
        self.limit = limit
    }
    var before: String? { memory.before.map { String($0.suffix(limit)) } }
    var after: String? { omitsRightContext ? nil : memory.after.map { String($0.prefix(limit)) } }
    var selectedText: String? { memory.selectedText }
    func insert(_ text: String) {
        if text == ignoredInsertion {
            if let shrunkenLimitAfterIgnoredInsertion { limit = shrunkenLimitAfterIgnoredInsertion }
            return
        }
        var output = transformedInsertion.flatMap { text == $0.0 ? $0.1 : nil } ?? text
        if let maximumInsertionLength { output = String(output.prefix(maximumInsertionLength)) }
        if let capacity { output = String(output.prefix(max(0, capacity - memory.text.count))) }
        memory.insert(output)
    }
    func deleteBackward() {
        deletions += 1
        if deletions != ignoreDeleteAt { memory.deleteBackward() }
    }
    func move(by offset: Int) { memory.move(by: offset) }
}
