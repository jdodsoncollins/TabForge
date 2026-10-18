import Testing
@testable import KeyboardCore

@Suite
struct FormatterRegressionTests {
    @Test(arguments: [CodeLanguage.javascript, .typescript])
    func templateOpeningLinePreservesTrailingWhitespace(language: CodeLanguage) throws {
        let input = "function run() {\n  const value = `first  \t\n  second\n    third`;\n}"
        let expected = "function run() {\n    const value = `first  \t\n  second\n    third`;\n}"

        #expect(try CodeFormatter.format(input, language: language) == expected)
    }
}
