import XCTest
import UIKit
@testable import ScriptKeyboard

@MainActor
final class EditorAccessibilityTests: XCTestCase {
    func testAutocorrectionSurvivesOwnEditorCallbacksButNotHostCursorMovement() async throws {
        try await withEditor { host in
            host.textView.autocorrectionType = .yes
            host.keyboard.preferences.settings.autocorrectProse = true
            host.keyboard.applySettings()
            host.keyboard.engine.correctionProvider = { $0 == "teh" ? "the" : nil }
            host.synchronize(text: "This is teh", language: .swift)
            host.keyboard.engine.type(" ")
            host.keyboard.refreshContext()
            XCTAssertEqual(host.textView.text, "This is the ")
            host.keyboard.engine.backspace()
            XCTAssertEqual(host.textView.text, "This is teh")

            host.synchronize(text: "This is teh", language: .swift)
            host.textView.selectedRange = NSRange(location: host.textView.text.utf16.count, length: 0)
            host.keyboard.engine.invalidateAutocorrection()
            host.keyboard.engine.type(" ")
            let end = host.textView.selectedRange
            host.textView.selectedRange = NSRange(location: 0, length: 0)
            host.textViewDidChangeSelection(host.textView)
            host.textView.selectedRange = end
            host.textViewDidChangeSelection(host.textView)
            host.keyboard.engine.backspace()
            XCTAssertEqual(host.textView.text, "This is the")
        }
    }

    func testCursorIndexTracksExternalAndNativeEditsWithUnicodeSelections() async throws {
        try await withEditor { host in
            var label = ""
            host.onCursor = { label = $0 }
            let source = "head\r\n👩🏽‍💻e\u{301}z\nlast"
            host.textView.text = source
            host.textView.selectedRange = (source as NSString).range(of: "z")
            host.cursorChanged()
            XCTAssertEqual(label, "Ln 2, Col 3")

            host.textView.textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: "\n")
            let updated = host.textView.text as NSString
            host.textView.selectedRange = updated.range(of: "last")
            host.cursorChanged()
            XCTAssertEqual(label, "Ln 4, Col 1")

            // Equal-length replacements still invalidate the index, including
            // when the cursor remains at exactly the same UTF-16 offset.
            host.textView.text = "a\nbc"
            host.textView.selectedRange = NSRange(location: 4, length: 0)
            host.cursorChanged()
            XCTAssertEqual(label, "Ln 2, Col 3")
            host.textView.text = "ab\nc"
            host.textView.selectedRange = NSRange(location: 4, length: 0)
            host.cursorChanged()
            XCTAssertEqual(label, "Ln 2, Col 2")

            host.document.insert("\n")
            host.cursorChanged()
            XCTAssertEqual(label, "Ln 3, Col 1")
        }
    }

    func testCursorOnlyPublishesChangedLabels() async throws {
        try await withEditor { host in
            host.textView.text = "let value = 1"
            host.textView.selectedRange = NSRange(location: 4, length: 0)
            var labels: [String] = []
            host.onCursor = { labels.append($0) }
            host.cursorChanged()
            host.cursorChanged()
            host.changed()
            host.changed()
            XCTAssertEqual(labels, ["Ln 1, Col 5"])

            host.textView.selectedRange = NSRange(location: 5, length: 0)
            host.cursorChanged()
            XCTAssertEqual(labels, ["Ln 1, Col 5", "Ln 1, Col 6"])
        }
    }

    func testBoundLanguageChangeRehighlightsWithoutChangingSelection() async throws {
        try await withEditor { host in
            let source = "def value = 42\n# comment"
            host.synchronize(text: source, language: .swift)
            let selection = NSRange(location: 4, length: 5)
            host.textView.selectedRange = selection
            host.synchronize(text: source, language: .python)

            XCTAssertEqual(host.textView.text, source)
            XCTAssertEqual(host.textView.selectedRange, selection)
            let keyword = try XCTUnwrap(host.textView.textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
            let commentLocation = (source as NSString).range(of: "# comment").location
            let comment = try XCTUnwrap(host.textView.textStorage.attribute(.foregroundColor, at: commentLocation, effectiveRange: nil) as? UIColor)
            XCTAssertEqual(keyword, EditorSyntaxPalette.keyword)
            XCTAssertEqual(comment, EditorSyntaxPalette.comment)

            host.synchronize(text: source, language: .swift)
            let uncolored = try XCTUnwrap(host.textView.textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor)
            XCTAssertEqual(uncolored, UIColor.label)
            XCTAssertEqual(host.textView.selectedRange, selection)
        }
    }

    func testSameSelectionRefocusRestoresReleasedSuggestions() async throws {
        try await withEditor { host in
            host.synchronize(text: "pu", language: .swift)
            let selection = host.textView.selectedRange
            let toolbar = try XCTUnwrap(host.keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
            let toolsAndSettings = try XCTUnwrap(toolbar.subviews.first { $0.accessibilityIdentifier == "keyboard.quickSettings" } as? UIButton)
            @MainActor func suggestions() -> [String] {
                let submenu = toolsAndSettings.menu?.children.compactMap { $0 as? UIMenu }.first { $0.title == "Code suggestions" }
                return submenu?.children.map { $0.title } ?? []
            }
            XCTAssertTrue(suggestions().contains("public"))
            host.keyboard.releaseTransientResources()
            XCTAssertTrue(suggestions().isEmpty)
            // Exercise the focus delegate with unchanged settings and cursor,
            // exactly the path which otherwise skips redundant refreshes.
            host.keyboard.applySettings()
            host.textViewDidBeginEditing(host.textView)
            XCTAssertEqual(host.textView.selectedRange, selection)
            XCTAssertTrue(suggestions().contains("public"))
        }
    }

    func testAccessibilityTextSizeAppliesToExistingAndInsertedCode() async throws {
        try await withEditor { host in
            host.traitOverrides.preferredContentSizeCategory = .large
            host.updateTraitsIfNeeded()
            host.textView.text = "let value = 1"
            host.textView.selectedRange = NSRange(location: host.textView.text.utf16.count, length: 0)
            host.highlight()
            let regularSize = try XCTUnwrap(host.textView.font).pointSize
            let selection = host.textView.selectedRange

            host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
            host.updateTraitsIfNeeded()
            await Task.yield()

            let accessibilityFont = expectedFont(for: host)
            XCTAssertGreaterThan(accessibilityFont.pointSize, regularSize)
            XCTAssertEqual(host.textView.text, "let value = 1")
            XCTAssertEqual(host.textView.selectedRange, selection)
            XCTAssertTrue(host.textView.adjustsFontForContentSizeCategory)
            assertFont(accessibilityFont, throughout: host)

            host.document.insert("\nlet next = 2")
            XCTAssertEqual(host.textView.text, "let value = 1\nlet next = 2")
            assertFont(accessibilityFont, throughout: host)

            host.traitOverrides.preferredContentSizeCategory = .large
            host.updateTraitsIfNeeded()
            await Task.yield()
            assertFont(expectedFont(for: host), throughout: host)
        }
    }

    func testAccessibilityFontUpdatesBeyondSyntaxHighlightingLimit() async throws {
        try await withEditor { host in
            host.textView.text = String(repeating: "a", count: 120_001)
            host.textView.selectedRange = NSRange(location: 3, length: 0)
            host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraLarge
            host.updateTraitsIfNeeded()
            await Task.yield()

            XCTAssertEqual(host.textView.text.utf16.count, 120_001)
            XCTAssertEqual(host.textView.selectedRange, NSRange(location: 3, length: 0))
            assertFont(expectedFont(for: host), throughout: host)

            host.traitOverrides.legibilityWeight = .bold
            host.updateTraitsIfNeeded()
            await Task.yield()
            XCTAssertEqual(host.textView.selectedRange, NSRange(location: 3, length: 0))
            assertFont(expectedFont(for: host), throughout: host)
        }
    }

    func testBoldTextUpdatesExistingAndInsertedCodeWithoutMovingSelection() async throws {
        try await withEditor { host in
            host.traitOverrides.legibilityWeight = .regular
            host.updateTraitsIfNeeded()
            host.textView.text = "let value = 1"
            host.textView.selectedRange = NSRange(location: host.textView.text.utf16.count, length: 0)
            host.highlight()
            let regularName = try XCTUnwrap(host.textView.font).fontName
            let selection = host.textView.selectedRange

            host.traitOverrides.legibilityWeight = .bold
            host.updateTraitsIfNeeded()
            await Task.yield()

            XCTAssertNotEqual(try XCTUnwrap(host.textView.font).fontName, regularName)
            XCTAssertEqual(host.textView.text, "let value = 1")
            XCTAssertEqual(host.textView.selectedRange, selection)
            assertFont(expectedFont(for: host), throughout: host)
            host.document.insert("\nlet next = 2")
            assertFont(expectedFont(for: host), throughout: host)

            host.traitOverrides.legibilityWeight = .regular
            host.updateTraitsIfNeeded()
            await Task.yield()
            XCTAssertEqual(try XCTUnwrap(host.textView.font).fontName, regularName)
            assertFont(expectedFont(for: host), throughout: host)
        }
    }

    func testSyntaxColorsMeetBodyTextContrastInLightDarkAndIncreasedContrast() {
        let colors = [EditorSyntaxPalette.keyword, EditorSyntaxPalette.number,
                      EditorSyntaxPalette.string, EditorSyntaxPalette.comment, UIColor.label]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for contrast in [UIAccessibilityContrast.normal, .high] {
                let traits = UITraitCollection { mutable in
                    mutable.userInterfaceStyle = style
                    mutable.accessibilityContrast = contrast
                }
                for foreground in colors {
                    XCTAssertGreaterThanOrEqual(contrastRatio(foreground, .secondarySystemGroupedBackground, traits: traits), 4.5,
                                                "Syntax text must remain readable in \(style), contrast \(contrast)")
                }
            }
        }
    }

    func testSyntaxHighlightingRetainsReadableColorsWhenAppearanceChanges() async throws {
        try await withEditor { host in
            let source = "let number = 42\nlet text = \"hello\"\n// comment"
            host.textView.text = source
            host.textView.selectedRange = NSRange(location: 4, length: 0)
            let tokens: [(String, UIColor)] = [("let", EditorSyntaxPalette.keyword),
                                               ("42", EditorSyntaxPalette.number),
                                               ("\"hello\"", EditorSyntaxPalette.string),
                                               ("// comment", EditorSyntaxPalette.comment)]
            host.highlight()
            for (style, contrast) in [(UIUserInterfaceStyle.light, UIAccessibilityContrast.normal),
                                      (.dark, .normal), (.dark, .high), (.light, .high)] {
                host.traitOverrides.userInterfaceStyle = style
                host.traitOverrides.accessibilityContrast = contrast
                host.updateTraitsIfNeeded()
                await Task.yield()

                XCTAssertEqual(host.textView.text, source)
                XCTAssertEqual(host.textView.selectedRange, NSRange(location: 4, length: 0))
                for (token, expected) in tokens {
                    let location = (source as NSString).range(of: token).location
                    let actual = try XCTUnwrap(host.textView.textStorage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? UIColor)
                    XCTAssertEqual(actual.resolvedColor(with: host.traitCollection), expected.resolvedColor(with: host.traitCollection))
                    XCTAssertGreaterThanOrEqual(contrastRatio(actual, .secondarySystemGroupedBackground, traits: host.traitCollection), 4.5)
                }
            }
        }
    }

    private func expectedFont(for host: EditorHostView) -> UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(
            for: .monospacedSystemFont(ofSize: 15, weight: host.traitCollection.legibilityWeight == .bold ? .semibold : .regular),
            compatibleWith: host.traitCollection
        )
    }

    private func assertFont(_ expected: UIFont, throughout host: EditorHostView, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual((host.textView.typingAttributes[.font] as? UIFont)?.pointSize ?? 0, expected.pointSize, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual((host.textView.typingAttributes[.font] as? UIFont)?.fontName, expected.fontName, file: file, line: line)
        host.textView.textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: host.textView.text.utf16.count)) { value, _, _ in
            XCTAssertEqual((value as? UIFont)?.pointSize ?? 0, expected.pointSize, accuracy: 0.01, file: file, line: line)
            XCTAssertEqual((value as? UIFont)?.fontName, expected.fontName, file: file, line: line)
        }
    }

    private func contrastRatio(_ foreground: UIColor, _ background: UIColor, traits: UITraitCollection) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            XCTAssertTrue(color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            XCTAssertEqual(alpha, 1, accuracy: 0.001)
            let linear = [red, green, blue].map { value -> Double in
                let component = Double(value)
                return component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
            }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        let first = luminance(foreground), second = luminance(background)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }

    private func withEditor(_ body: @MainActor (EditorHostView) async throws -> Void) async throws {
        let suiteName = "TabForge.EditorAccessibilityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = PreferencesStore(local: defaults)
        let host = EditorHostView(preferences: preferences, openSettings: {})
        let controller = UIViewController()
        controller.view = host
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        window.layoutIfNeeded()
        try await body(host)
    }
}
