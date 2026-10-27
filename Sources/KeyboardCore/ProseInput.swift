import Foundation

/// Sentence capitals and the double-space period. Both only change Shift or
/// replace a verified space, so unavailable context is treated conservatively.
public enum ProseInputPolicy {
    /// `before` is the bounded context before the cursor. An empty field
    /// (nil or empty context) starts a sentence: a wrong guess only sets Shift.
    public static func startsSentence(before: String?) -> Bool {
        guard let before, !before.isEmpty else { return true }
        if before.last?.isNewline == true { return true }
        guard before.last?.isWhitespace == true else { return false }
        let trimmed = before.reversed().drop { $0.isWhitespace && !$0.isNewline }
        guard let mark = trimmed.first else { return true }
        return mark.isNewline || ".!?".contains(mark)
    }

    /// A second Space right after a word becomes ". ".
    public static func doubleSpaceMakesPeriod(before: String?) -> Bool {
        guard let before, before.count >= 2, before.last == " " else { return false }
        let previous = before[before.index(before.endIndex, offsetBy: -2)]
        return previous.isLetter || previous.isNumber
    }
}

/// Characters offered when a key is held. The first entry is preselected.
public enum KeyAlternates {
    private static let digits = Dictionary(uniqueKeysWithValues: zip("qwertyuiop".map(String.init), "1234567890".map { [String($0)] }))
    private static let symbols: [String: [String]] = [
        ".": [",", "?", "!", "->", "=>", "..."],
        ",": [";", ":"],
        "=": ["==", "!=", "=>", "+=", "-=", "==="],
        "<": ["<=", "<<", "<-", "</"],
        ">": [">=", ">>", "->", "=>"],
        "-": ["->", "--", "-=", "_"],
        "+": ["++", "+="],
        "/": ["//", "/*", "\\", "|"],
        "|": ["||", "|>"],
        "&": ["&&"],
        ":": ["::", ":="],
        "!": ["!=", "!!"],
        "?": ["??", "?."],
        "'": ["\"", "`"],
        "\"": ["'", "`"],
        "_": ["__", "-"],
        "*": ["**", "*="],
        ";": [":"],
        "$": ["${", "$("]
    ]

    public static func alternates(for text: String) -> [String] {
        digits[text.lowercased()] ?? symbols[text] ?? []
    }
}
