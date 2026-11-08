import Foundation
import Testing
@testable import KeyboardCore

struct ProseInputTests {
    @Test(arguments: [
        (nil, true), ("", true), ("Hello.", false), ("Hello. ", true), ("Why?  ", true),
        ("Wow! ", true), ("line\n", true), ("word ", false), ("e.g ", false), ("3.5", false), ("\n  ", true)
    ] as [(String?, Bool)])
    func sentenceStarts(_ before: String?, _ expected: Bool) {
        #expect(ProseInputPolicy.startsSentence(before: before) == expected)
    }

    @Test(arguments: [
        ("word ", true), ("42 ", true), ("word", false), ("word. ", false), ("  ", false), (" ", false), (nil, false)
    ] as [(String?, Bool)])
    func doubleSpacePeriod(_ before: String?, _ expected: Bool) {
        #expect(ProseInputPolicy.doubleSpaceMakesPeriod(before: before) == expected)
    }

    @Test func heldKeysOfferHintedDigitsAndOperators() {
        #expect(KeyAlternates.alternates(for: "q") == ["1"])
        #expect(KeyAlternates.alternates(for: "P") == ["0"])
        #expect(KeyAlternates.alternates(for: "=").first == "==")
        #expect(KeyAlternates.alternates(for: ".").first == ",")
        #expect(KeyAlternates.alternates(for: "a").isEmpty)
        #expect(KeyAlternates.alternates(for: "{").isEmpty)
    }

    @Test func toolbarKeysKeepTheirFixedOrderAndOlderRecordsKeepDefaults() throws {
        var settings = KeyboardSettings()
        #expect(settings.toolbarKeys == ToolbarKey.defaults)
        settings.toolbarKeys = [.right, .tab, .escape]
        #expect(settings.toolbarKeys == [.escape, .tab, .right])
        let data = try JSONEncoder().encode(settings)
        var record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        record["selectedToolbarKeys"] = ["escape", "futureKey", "pipe"]
        let future = try JSONDecoder().decode(KeyboardSettings.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(future.toolbarKeys == [.escape, .pipe])
        record.removeValue(forKey: "selectedToolbarKeys")
        let older = try JSONDecoder().decode(KeyboardSettings.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(older.toolbarKeys == ToolbarKey.defaults)
        #expect(older.autoCapitalize && older.periodShortcut && older.tipsShown == 0)
        #expect(ToolbarKey.defaults.count < ToolbarKey.maximumCount)
    }

    @Test func toolbarGlobeIsOptionalAndSitsNextToSettings() throws {
        // The bottom row already has a globe; the toolbar's is an extra choice.
        #expect(!ToolbarKey.defaults.contains(.nextKeyboard))
        var settings = KeyboardSettings()
        settings.toolbarKeys = [.nextKeyboard] + ToolbarKey.defaults
        // The toolbar draws the gear after these, so the globe sits beside it.
        #expect(settings.toolbarKeys == ToolbarKey.defaults + [.nextKeyboard])
        #expect(settings.toolbarKeys.count <= ToolbarKey.maximumCount)
        let decoded = try JSONDecoder().decode(KeyboardSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.toolbarKeys.last == .nextKeyboard)
        #expect(ToolbarKey.nextKeyboard.text == nil)
    }
}
