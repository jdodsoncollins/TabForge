import XCTest
import UIKit
import KeyboardCore
@testable import ScriptKeyboard

@MainActor
final class KeyboardPerformanceTests: XCTestCase {
    func testEditorHighlighting() throws {
        try withEditor { host in
            // About 80K UTF-16 units, including each of the highlighter's token
            // classes. Keep corpus and repeat count unchanged across comparisons.
            let source = String(repeating: "let value = 42\nlet text = \"hello\"\n// comment\n", count: 1_850)
            host.textView.text = source
            host.textView.selectedRange = NSRange(location: source.utf16.count, length: 0)
            host.highlight()
            let options = XCTMeasureOptions()
            options.iterationCount = 5
            measure(metrics: [XCTClockMetric()], options: options) {
                for _ in 0..<5 { host.highlight() }
            }
            XCTAssertEqual(host.textView.text, source)
            XCTAssertEqual(host.textView.selectedRange, NSRange(location: source.utf16.count, length: 0))
        }
    }

    func testEditorCursorMovement() throws {
        try withEditor { host in
            let source = String(repeating: "let item = 42\n", count: 10_000)
            host.textView.text = source
            host.textView.selectedRange = NSRange(location: source.utf16.count, length: 0)
            var label = ""
            host.onCursor = { label = $0 }
            host.cursorChanged()
            let options = XCTMeasureOptions()
            options.iterationCount = 5
            measure(metrics: [XCTClockMetric()], options: options) {
                for _ in 0..<100 { host.cursorChanged() }
            }
            XCTAssertEqual(label, "Ln 10001, Col 1")
            XCTAssertEqual(host.textView.text, source)
        }
    }

    func testUnchangedKeyboardSettings() throws {
        let suite = "TabForge.Performance.Settings.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let preferences = PreferencesStore(local: defaults)
        preferences.settings.haptics = false
        preferences.settings.keyClicks = false
        let document = MemoryDocument(text: String(repeating: "let item = 42\n", count: 100))
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        keyboard.frame = CGRect(x: 0, y: 0, width: 390, height: keyboard.desiredHeight)
        keyboard.layoutIfNeeded()
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<500 { keyboard.applySettings() }
        }
        XCTAssertEqual(document.text, String(repeating: "let item = 42\n", count: 100))
    }

    func testRepeatedKeyActions() throws {
        let suite = "TabForge.Performance.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let preferences = PreferencesStore(local: defaults)
        preferences.settings.haptics = false
        preferences.settings.keyClicks = false
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        keyboard.layoutIfNeeded()
        let q = try XCTUnwrap(keyboard.subviews.first { $0.accessibilityIdentifier == "key.q" } as? UIButton)
        let space = try XCTUnwrap(keyboard.subviews.first { $0.accessibilityIdentifier == "key.space" } as? UIButton)
        // Includes UIKit actions, text edits, and suggestion refreshes. It measures
        // the shared renderer in a host process, not the extension's RAM limit.
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            document.selection = NSRange(location: 0, length: document.text.utf16.count)
            document.insert("")
            for _ in 0..<500 {
                q.sendActions(for: .touchUpInside)
                space.sendActions(for: .touchUpInside)
            }
        }
        XCTAssertEqual(document.text.count, 1000)
    }

    private func withEditor(_ body: (EditorHostView) throws -> Void) throws {
        let suite = "TabForge.Performance.Editor.\(UUID().uuidString)"
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let preferences = PreferencesStore(local: defaults)
        preferences.settings.haptics = false
        preferences.settings.keyClicks = false
        let host = EditorHostView(preferences: preferences, openSettings: {})
        host.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host.layoutIfNeeded()
        try body(host)
    }
}
