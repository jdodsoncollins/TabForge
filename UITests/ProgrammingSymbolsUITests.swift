import XCTest

@MainActor
final class ProgrammingSymbolsUITests: XCTestCase {
    /// Run on compact iPhone, expanded Duo, and studio iPad destinations.
    func testAllASCIIPunctuationIsReachableAndOperatorsInsertLiterally() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()

        func key(_ title: String) -> XCUIElement {
            app.descendants(matching: .any)["key.\(title)"].firstMatch
        }
        func visibleLiterals() -> Set<String> {
            Set(app.keys.matching(NSPredicate(format: "identifier BEGINSWITH %@", "key.")).allElementsBoundByIndex.compactMap { element in
                let identifier = element.identifier
                guard identifier.hasPrefix("key."), element.isHittable else { return nil }
                let literal = String(identifier.dropFirst(4))
                return literal.count == 1 ? literal : nil
            })
        }

        XCTAssertTrue(key("123").waitForExistence(timeout: 10))
        var reachable = visibleLiterals()
        key("123").tap()
        XCTAssertTrue(key("#+=").waitForExistence(timeout: 5))
        reachable.formUnion(visibleLiterals())
        key("#+=").tap()
        XCTAssertTrue(key("_").waitForExistence(timeout: 5))
        reachable.formUnion(visibleLiterals())

        let punctuation = Set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~".map(String.init))
        XCTAssertEqual(punctuation.subtracting(reachable), [], "Every printable ASCII punctuation mark must have a reachable key.")

        let editor = app.textViews["playground.editor"]
        let before = editor.value as? String ?? ""
        for symbol in ["_", ";", "|", "*", "^"] { key(symbol).tap() }
        let after = editor.value as? String ?? ""
        XCTAssertTrue(after.contains("_;|*^"))
        XCTAssertEqual(after.utf16.count, before.utf16.count + 5)

        key("123").tap()
        XCTAssertTrue(key("#+=").waitForExistence(timeout: 5))
        key("ABC").tap()
        XCTAssertTrue(key("q").waitForExistence(timeout: 5))
        key("123").tap()
        XCTAssertTrue(key("#+=").waitForExistence(timeout: 5), "Returning from letters should open the number page.")
    }
}
