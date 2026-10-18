import XCTest
import UIKit
import KeyboardCore
@testable import ScriptKeyboard

@MainActor
final class ProseAutocorrectionTests: XCTestCase {
    func testRequiredLexiconKeepsTypingLiteralUntilLoadedAndRetriesAfterCleanup() throws {
        let suite = "TabForge.LexiconReadiness.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PreferencesStore(local: defaults)
        preferences.settings.autocorrectProse = true
        let document = MemoryDocument(text: "teh")
        document.allowsAutocorrection = true
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        keyboard.requiresSupplementaryLexicon = true
        var requests = 0
        keyboard.onPrepareAutocorrection = { requests += 1 }

        keyboard.engine.type(" ")
        XCTAssertEqual(document.text, "teh ", "Pending lexicon must not delay or change ordinary typing")
        XCTAssertEqual(requests, 1)

        // An empty completed lexicon is still ready. An ineligible dictionary
        // word avoids depending on a particular installed English dictionary.
        keyboard.useSupplementaryLexicon(EmptyLexicon())
        XCTAssertNil(keyboard.engine.correctionProvider?("foo_bar"))
        XCTAssertEqual(requests, 1, "A completed empty lexicon must not request another load")

        keyboard.releaseTransientResources()
        document.selection = NSRange(location: 0, length: document.text.utf16.count)
        document.insert("teh")
        keyboard.engine.type(" ")
        XCTAssertEqual(document.text, "teh ")
        XCTAssertEqual(requests, 2, "Visible keyboards must reload protection after memory cleanup")
    }

    func testHostTraitsOptOutAndStructuredFieldsStayLiteral() {
        XCTAssertFalse(HostAutocorrectionTraits.allows(autocorrection: nil, keyboardType: .default, secure: false, contentType: nil))
        XCTAssertFalse(HostAutocorrectionTraits.allows(autocorrection: .default, keyboardType: nil, secure: false, contentType: nil))
        XCTAssertFalse(HostAutocorrectionTraits.allows(autocorrection: .default, keyboardType: .default, secure: nil, contentType: nil))
        let view = UITextView()
        let document = TextViewDocument(view)
        XCTAssertTrue(document.allowsAutocorrection)
        view.autocorrectionType = .no
        XCTAssertFalse(document.allowsAutocorrection)
        view.autocorrectionType = .yes
        XCTAssertTrue(document.allowsAutocorrection)
        for type in [UIKeyboardType.URL, .emailAddress, .numberPad, .decimalPad, .phonePad,
                     .namePhonePad, .numbersAndPunctuation, .asciiCapableNumberPad, .webSearch] {
            view.keyboardType = type
            XCTAssertFalse(document.allowsAutocorrection, "\(type)")
        }
        view.keyboardType = .default
        for type in [UITextContentType.URL, .emailAddress, .username, .password, .newPassword, .oneTimeCode, .name] {
            view.textContentType = type
            XCTAssertFalse(document.allowsAutocorrection, type.rawValue)
        }
        view.textContentType = nil
        view.isSecureTextEntry = true
        XCTAssertFalse(document.allowsAutocorrection)
        view.isSecureTextEntry = false
        view.isEditable = false
        XCTAssertFalse(document.allowsAutocorrection)
    }

    func testNativeCorrectionAndImmediateBackspaceRestoreOriginal() {
        let view = UITextView()
        view.autocorrectionType = .yes
        view.text = "This is teh"
        view.selectedRange = NSRange(location: view.text.utf16.count, length: 0)
        let document = TextViewDocument(view)
        var settings = KeyboardSettings()
        settings.autocorrectProse = true
        let engine = EditingEngine(document: document, settings: settings)
        engine.correctionProvider = { $0 == "teh" ? "the" : nil }
        engine.type(" ")
        XCTAssertEqual(view.text, "This is the ")
        engine.backspace()
        XCTAssertEqual(view.text, "This is teh")
        engine.type(" ")
        XCTAssertEqual(view.text, "This is teh ")
    }

    func testNativeReplacementIsOneUndoableEditAndRequiresExactSuffix() throws {
        let view = UITextView()
        view.text = "A teh"
        view.selectedRange = NSRange(location: view.text.utf16.count, length: 0)
        let document = TextViewDocument(view)
        XCTAssertFalse(document.replaceTextBeforeCursor("other", with: "the"))
        XCTAssertTrue(document.replaceTextBeforeCursor("teh", with: "the"))
        XCTAssertEqual(view.text, "A the")
        let undo = try XCTUnwrap(view.undoManager)
        XCTAssertTrue(undo.canUndo)
        undo.undo()
        XCTAssertEqual(view.text, "A teh")
    }

    func testRejectedNativeReplacementRestoresSelectionWithoutChangingText() {
        let view = UITextView()
        let delegate = RejectingEdits()
        view.delegate = delegate
        view.text = "A teh"
        let selected = NSRange(location: view.text.utf16.count, length: 0)
        view.selectedRange = selected
        XCTAssertFalse(TextViewDocument(view).replaceTextBeforeCursor("teh", with: "the"))
        XCTAssertEqual(view.text, "A teh")
        XCTAssertEqual(view.selectedRange, selected)
    }

    func testSingleEditFilterSupportsTranspositionsWithoutBroadGuesses() {
        XCTAssertTrue(ProseAutocorrector.isSingleEdit("teh", "the"))
        XCTAssertTrue(ProseAutocorrector.isSingleEdit("hellp", "hello"))
        XCTAssertTrue(ProseAutocorrector.isSingleEdit("helo", "hello"))
        XCTAssertFalse(ProseAutocorrector.isSingleEdit("hello", "hello"))
        XCTAssertFalse(ProseAutocorrector.isSingleEdit("cfg", "cat"))
    }

    func testAppleSpellingServiceKeepsKnownWordsAndCorrectsAnEnglishSlip() async throws {
        guard UITextChecker.availableLanguages.contains(where: { $0.hasPrefix("en") }) else {
            throw XCTSkip("English spelling dictionary is not installed")
        }
        let checker = ProseAutocorrector()
        XCTAssertNil(checker.correction(for: "hello"))
        XCTAssertNil(checker.correction(for: "foo_bar"))
        checker.protectedWords = ["teh", "hellp", "recieve"]
        XCTAssertNil(checker.correction(for: "teh"))
        checker.protectedWords = []
        var corrections = ["teh", "hellp", "recieve"].compactMap { checker.correction(for: $0) }
        // A freshly booted simulator can advertise a language before its
        // spelling service responds. Production leaves that word literal;
        // this integration test permits bounded asynchronous service warmup.
        for _ in 0..<10 where corrections.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
            corrections = ["teh", "hellp", "recieve"].compactMap { checker.correction(for: $0) }
        }
        guard corrections.isEmpty else { return }
        let service = UITextChecker()
        let diagnostics = UITextChecker.availableLanguages.filter { $0.hasPrefix("en") }.map { language in
            let range = NSRange(location: 0, length: 3)
            let misspelled = service.rangeOfMisspelledWord(in: "teh", range: range, startingAt: 0, wrap: false, language: language)
            let guesses = service.guesses(forWordRange: range, in: "teh", language: language) ?? []
            return "\(language): range=\(misspelled), guesses=\(guesses.prefix(4))"
        }
        XCTAssertFalse(corrections.isEmpty, "System spelling service: \(diagnostics)")
    }
}

@MainActor
private final class EmptyLexicon: UILexicon {
    override var entries: [UILexiconEntry] { [] }
}

@MainActor
private final class RejectingEdits: NSObject, UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool { false }
}
