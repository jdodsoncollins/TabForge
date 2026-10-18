import Foundation
import Testing
@testable import KeyboardCore

struct KeyboardHeightPolicyTests {
    @Test(arguments: [320.0, 375, 393, 440])
    func landscapePhonesUseCompactHeight(_ height: Double) {
        #expect(KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: height, compactVertical: true, tabletop: false
        ))
    }

    @Test(arguments: [669.0, 768, 951])
    func regularIPadAndOpenDuoKeepFullHeight(_ height: Double) {
        #expect(!KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: height, compactVertical: false, tabletop: false
        ))
    }

    @Test(arguments: [320.0, 375, 393, 440, 500])
    func shortHostWindowsUseCompactHeightWithoutCompactTraits(_ height: Double) {
        #expect(KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: height, compactVertical: false, tabletop: false
        ))
    }

    @Test func heightThresholdAndTraitFallback() {
        #expect(!KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: 500.1, compactVertical: false, tabletop: false
        ))
        #expect(KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: nil, compactVertical: true, tabletop: false
        ))
        #expect(!KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: nil, compactVertical: false, tabletop: false
        ))
        // A compact vertical trait remains useful when a window reports a large
        // screen-sized area instead of its current usable height.
        #expect(KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: 951, compactVertical: true, tabletop: false
        ))
    }

    @Test(arguments: [0.0, -1, Double.infinity, -Double.infinity, Double.nan])
    func invalidHostHeightsDoNotForceCompaction(_ height: Double) {
        #expect(!KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: height, compactVertical: false, tabletop: false
        ))
        #expect(KeyboardHeightPolicy.resolve(
            mode: .automatic, availableHeight: height, compactVertical: true, tabletop: false
        ))
    }

    @Test func explicitModesOverrideHostGeometry() {
        #expect(!KeyboardHeightPolicy.resolve(
            mode: .full, availableHeight: 320, compactVertical: true, tabletop: false
        ))
        #expect(KeyboardHeightPolicy.resolve(
            mode: .compact, availableHeight: 951, compactVertical: false, tabletop: false
        ))
    }

    @Test(arguments: KeyboardHeightMode.allCases)
    func dedicatedTabletopPanelAlwaysUsesFullLayout(_ mode: KeyboardHeightMode) {
        #expect(!KeyboardHeightPolicy.resolve(
            mode: mode, availableHeight: 320, compactVertical: true, tabletop: true
        ))
    }

    @Test(arguments: KeyboardHeightMode.allCases)
    func heightPreferenceRoundTrips(_ mode: KeyboardHeightMode) throws {
        var settings = KeyboardSettings()
        settings.heightMode = mode
        settings.language = .python
        settings.indentation = .tabs
        let restored = try JSONDecoder().decode(KeyboardSettings.self, from: JSONEncoder().encode(settings))
        #expect(restored == settings)
        #expect(restored.heightMode == mode)
        #expect(restored.language == .python)
        #expect(restored.indentation == .tabs)
        settings.heightMode = .automatic
        #expect(settings.heightMode == KeyboardSettings().heightMode)
    }

    @Test func legacyPreferencesDefaultToAutomaticWithoutLosingValues() throws {
        var settings = KeyboardSettings()
        settings.language = .shell
        settings.theme = .nord
        settings.swipeTyping = true
        settings.showNavigationRow = true
        settings.snippets = [CodeSnippet(name: "Keep me", text: "echo saved")]
        var record = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        record.removeValue(forKey: "selectedHeightMode")
        let restored = try JSONDecoder().decode(KeyboardSettings.self, from: JSONSerialization.data(withJSONObject: record))
        #expect(restored == settings)
        #expect(restored.heightMode == .automatic)
        #expect(restored.theme == .nord)
        #expect(restored.showNavigationRow)
    }
}
