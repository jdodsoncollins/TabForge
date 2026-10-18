import Testing
@testable import KeyboardCore

@Suite @MainActor
struct QuoteRegressionTests {
    @Test(arguments: ["\"", "'", "`"])
    func escapedQuoteBeforeClosingDelimiterIsInserted(_ quote: String) {
        for slashCount in [1, 3] {
            let prefix = "value = " + quote + String(repeating: "\\", count: slashCount)
            let document = MemoryDocument(text: prefix + quote, cursor: prefix.utf16.count)

            EditingEngine(document: document).type(quote)

            #expect(document.text == prefix + quote + quote)
            #expect(document.cursor == prefix.utf16.count + 1)
        }
    }

    @Test(arguments: ["\"", "'", "`"])
    func escapedQuoteWithoutClosingDelimiterIsNotPaired(_ quote: String) {
        for slashCount in [1, 3] {
            let prefix = "value = " + quote + String(repeating: "\\", count: slashCount)
            let document = MemoryDocument(text: prefix)

            EditingEngine(document: document).type(quote)

            #expect(document.text == prefix + quote)
            #expect(document.cursor == prefix.utf16.count + 1)
        }
    }

    @Test(arguments: ["\"", "'", "`"])
    func evenBackslashCountRetainsClosingDelimiterSkip(_ quote: String) {
        for slashCount in [0, 2, 4] {
            let prefix = "value = " + quote + String(repeating: "\\", count: slashCount)
            let document = MemoryDocument(text: prefix + quote, cursor: prefix.utf16.count)

            EditingEngine(document: document).type(quote)

            #expect(document.text == prefix + quote)
            #expect(document.cursor == prefix.utf16.count + 1)
        }
    }

    @Test(arguments: ["\"", "'", "`"])
    func evenBackslashCountRetainsAutomaticPairing(_ quote: String) {
        for slashCount in [2, 4] {
            let prefix = String(repeating: "\\", count: slashCount)
            let document = MemoryDocument(text: prefix)

            EditingEngine(document: document).type(quote)

            #expect(document.text == prefix + quote + quote)
            #expect(document.cursor == prefix.utf16.count + 1)
        }
    }

    @Test(arguments: [CompatibilityMode.terminal, .remoteDesktop])
    func literalProfilesNeverSkipAnExistingQuote(_ profile: CompatibilityMode) {
        var settings = KeyboardSettings()
        settings.compatibility = profile
        for quote in ["\"", "'", "`"] {
            for slashCount in [0, 1, 2, 3] {
                let prefix = "value = " + quote + String(repeating: "\\", count: slashCount)
                let document = MemoryDocument(text: prefix + quote, cursor: prefix.utf16.count)

                EditingEngine(document: document, settings: settings).type(quote)

                #expect(document.text == prefix + quote + quote)
                #expect(document.cursor == prefix.utf16.count + 1)
            }
        }
    }
}
