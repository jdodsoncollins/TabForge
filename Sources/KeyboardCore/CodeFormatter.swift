import Foundation

public enum CodeFormatter {
    public enum FormattingError: LocalizedError {
        case requiresLanguageParser
        public var errorDescription: String? { "This code needs a language-aware formatter. Automatic newline indentation and the indent keys are still available." }
    }
    public static func format(_ source: String, language: CodeLanguage, indentation: Indentation = .fourSpaces) throws -> String {
        if language == .json {
            let object = try JSONSerialization.jsonObject(with: Data(source.utf8), options: .fragmentsAllowed)
            let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed, .withoutEscapingSlashes])
            return String(decoding: data, as: UTF8.self)
        }
        // Fail closed for indentation-sensitive languages, here-docs, and Swift multiline literals.
        guard language != .python, language != .shell, !source.contains("\"\"\"") else { throw FormattingError.requiresLanguageParser }
        var depth = 0
        var blockComment = false
        var quote: Character?
        return source.components(separatedBy: "\n").map { line in
            let content = String(line.drop(while: { $0 == " " || $0 == "\t" }))
            guard !content.isEmpty else { return quote != nil ? line : "" }
            let leadingClose = content.prefix(while: { "}])".contains($0) }).count
            let result = quote != nil || blockComment ? line : String(repeating: indentation.unit, count: max(0, depth - leadingClose)) + content
            var escaped = false
            let chars = Array(content)
            var i = 0
            while i < chars.count {
                let char = chars[i]
                let next = i + 1 < chars.count ? chars[i + 1] : nil
                if blockComment {
                    if char == "*", next == "/" { blockComment = false; i += 1 }
                } else if let currentQuote = quote {
                    if escaped { escaped = false }
                    else if char == "\\" { escaped = true }
                    else if char == currentQuote { quote = nil }
                } else if char == "/", next == "/" { break }
                else if char == "/", next == "*" { blockComment = true; i += 1 }
                else if "\"'`".contains(char) { quote = char }
                else if "{[(".contains(char) { depth += 1 }
                else if "}])".contains(char) { depth = max(0, depth - 1) }
                i += 1
            }
            return result
        }.joined(separator: "\n")
    }
}
