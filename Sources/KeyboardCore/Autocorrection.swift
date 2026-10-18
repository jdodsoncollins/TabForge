import Foundation

/// A deliberately small prose policy: code, commands, identifiers, and unknown
/// host traits remain literal. The platform layer supplies the spelling data.
enum AutocorrectionPolicy {
    static let contextLimit = 256
    static let anchorLimit = 32
    private static let keywords = Set(CodeLanguage.allCases.flatMap(\.keywords).map { $0.lowercased() })
    private static let codePrefixWords: Set<String> = Set(CodeLanguage.shell.keywords).union([
        "let", "var", "const", "func", "function", "def", "class", "struct", "enum", "import", "export",
        "protocol", "interface", "typealias", "typedef", "namespace", "package", "using",
        "return", "if", "elif", "else", "for", "while", "switch", "case", "guard", "throw", "try", "catch",
        "break", "continue", "yield", "raise", "assert", "del", "with", "await"
    ])

    static func isASCIILetter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else { return false }
        return (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }

    static func candidate(before: String, after: String?, completeStart: Bool, trackedWord: String?) -> String? {
        guard after == nil || after?.isEmpty == true || after?.first?.isWhitespace == true else { return nil }
        let word = String(before.reversed().prefix(while: isASCIILetter).reversed())
        guard (3...32).contains(word.count), hasOrdinaryCase(word), !keywords.contains(word.lowercased()) else { return nil }
        // Some hosts omit the right context at EOF. Only a word observed being
        // typed by this keyboard can use that ambiguous, stable nil context.
        guard after != nil || trackedWord == word else { return nil }
        let prefix = before.dropLast(word.count)
        if let boundary = prefix.last {
            guard boundary.isWhitespace else { return nil }
        } else {
            // Proxy context can begin halfway through an identifier. Its edge
            // is safe only when we observed this entire word being typed.
            guard completeStart || trackedWord == word else { return nil }
        }
        let line = before.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).last ?? ""
        if let firstWord = line.split(whereSeparator: \.isWhitespace).first,
           codePrefixWords.contains(String(firstWord)) { return nil }
        // Sentence punctuation is safe; syntax punctuation, digits, quotes,
        // URLs, paths, interpolation, and underscore names opt the line out.
        guard line.allSatisfy({ $0.isLetter || $0.isWhitespace || ".,!?;:-".contains($0) }) else { return nil }
        return word
    }

    static func correction(_ proposed: String, for word: String) -> String? {
        guard (3...32).contains(proposed.count), proposed.allSatisfy(isASCIILetter), hasOrdinaryCase(proposed) else { return nil }
        let lower = proposed.lowercased()
        guard lower != word.lowercased(), !keywords.contains(lower),
              editDistance(word.lowercased(), lower) <= 1 else { return nil }
        if word.first?.isUppercase == true { return lower.prefix(1).uppercased() + lower.dropFirst() }
        return lower
    }

    private static func hasOrdinaryCase(_ word: String) -> Bool {
        word.allSatisfy(\.isLowercase) || (word.first?.isUppercase == true && word.dropFirst().allSatisfy(\.isLowercase))
    }

    /// Adjacent transpositions count as one edit, so common slips such as
    /// "teh" can be corrected without accepting unrelated spelling guesses.
    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs), right = Array(rhs)
        var rows = Array(repeating: Array(repeating: 0, count: right.count + 1), count: left.count + 1)
        for index in 0...left.count { rows[index][0] = index }
        for index in 0...right.count { rows[0][index] = index }
        for l in 1...left.count {
            for r in 1...right.count {
                rows[l][r] = min(rows[l - 1][r] + 1, rows[l][r - 1] + 1,
                                 rows[l - 1][r - 1] + (left[l - 1] == right[r - 1] ? 0 : 1))
                if l > 1, r > 1, left[l - 1] == right[r - 2], left[l - 2] == right[r - 1] {
                    rows[l][r] = min(rows[l][r], rows[l - 2][r - 2] + 1)
                }
            }
        }
        return rows[left.count][right.count]
    }
}

struct AutocorrectionState {
    struct Word {
        var original: String
        var corrected: String
        var leftAnchor: String
        var rightAnchor: String?
        var identifier: UUID?
    }
    var typedWord: Word?
    var undo: Word?
    var rejected: Word?
}

extension EditingEngine {
    public func invalidateAutocorrection() { autocorrectionState = AutocorrectionState() }

    /// External selection and text callbacks can arrive between key presses.
    /// Once a cursor leaves the verified context, returning to it does not
    /// resurrect an old correction or an observed typing sequence.
    public func validateAutocorrectionContext() {
        if let word = autocorrectionState.typedWord, !matches(word, suffix: word.original) {
            invalidateAutocorrection(); return
        }
        if let word = autocorrectionState.undo, !matches(word, suffix: word.corrected + " ") {
            invalidateAutocorrection(); return
        }
        if let word = autocorrectionState.rejected, !matches(word, suffix: word.original) {
            invalidateAutocorrection()
        }
    }

    private var canAutocorrect: Bool {
        settings.autocorrectProse && settings.compatibility == .editor &&
            document.allowsAutocorrection && document.selectedText == nil && correctionProvider != nil
    }

    func autocorrectBeforeSpace() -> Bool {
        let typedWord = autocorrectionState.typedWord
        let rejected = autocorrectionState.rejected
        autocorrectionState.undo = nil
        defer { autocorrectionState.typedWord = nil; autocorrectionState.rejected = nil }
        guard canAutocorrect,
              let before = document.contextBeforeInput(maximumCharacters: AutocorrectionPolicy.contextLimit) else { return false }
        let after = document.contextAfterInput(maximumCharacters: AutocorrectionPolicy.anchorLimit)
        let identifier = document.autocorrectionContextIdentifier
        let tracked = typedWord.flatMap { matches($0, suffix: $0.original) ? $0.original : nil }
        guard let word = AutocorrectionPolicy.candidate(
            before: before, after: after,
            completeStart: document.hasCompleteContext && before.count < AutocorrectionPolicy.contextLimit,
            trackedWord: tracked
        ) else { return false }
        if let rejected, rejected.original == word, matches(rejected, suffix: word) { return false }
        guard let proposed = correctionProvider?(word),
              let corrected = AutocorrectionPolicy.correction(proposed, for: word) else { return false }
        let record = AutocorrectionState.Word(
            original: word, corrected: corrected,
            leftAnchor: String(before.dropLast(word.count).suffix(AutocorrectionPolicy.anchorLimit)),
            rightAnchor: after, identifier: identifier
        )
        // Recheck after consulting the provider: adapters and services must not
        // cause a stale spelling result to replace a different selection.
        guard canAutocorrect, matches(record, suffix: word),
              document.replaceTextBeforeCursor(word, with: corrected) else { return false }
        // Commit the separator exactly once, even if a proxy supplies less
        // context after replacement or declines to expose an undo anchor.
        document.insert(" ")
        if matches(record, suffix: corrected + " ") { autocorrectionState.undo = record }
        return true
    }

    func undoAutocorrectionOnBackspace() -> Bool {
        let record = autocorrectionState.undo
        invalidateAutocorrection()
        guard let record, canAutocorrect, matches(record, suffix: record.corrected + " "),
              document.replaceTextBeforeCursor(record.corrected + " ", with: record.original) else { return false }
        // Backspacing a correction rejects that particular guess. A following
        // space keeps the spelling the user explicitly restored.
        if matches(record, suffix: record.original) { autocorrectionState.rejected = record }
        return true
    }

    func prepareAutocorrectionTracking(for text: String) -> AutocorrectionState.Word? {
        let previous = autocorrectionState.typedWord
        invalidateAutocorrection()
        guard canAutocorrect, text.count == 1, text.first.map(AutocorrectionPolicy.isASCIILetter) == true,
              let before = document.contextBeforeInput(maximumCharacters: AutocorrectionPolicy.anchorLimit + 32) else { return nil }
        let after = document.contextAfterInput(maximumCharacters: AutocorrectionPolicy.anchorLimit)
        if var previous, previous.original.count < 32, matches(previous, suffix: previous.original) {
            previous.original += text
            return previous
        }
        guard before.isEmpty || before.last?.isWhitespace == true else { return nil }
        return AutocorrectionState.Word(
            original: text, corrected: "", leftAnchor: String(before.suffix(AutocorrectionPolicy.anchorLimit)),
            rightAnchor: after, identifier: document.autocorrectionContextIdentifier
        )
    }

    func finishAutocorrectionTracking(_ word: AutocorrectionState.Word?) {
        if let word, matches(word, suffix: word.original) { autocorrectionState.typedWord = word }
    }

    private func matches(_ word: AutocorrectionState.Word, suffix: String) -> Bool {
        document.selectedText == nil && document.autocorrectionContextIdentifier == word.identifier &&
            document.contextBeforeInput(maximumCharacters: max(1, word.leftAnchor.count + suffix.count)) == word.leftAnchor + suffix &&
            document.contextAfterInput(maximumCharacters: AutocorrectionPolicy.anchorLimit) == word.rightAnchor
    }
}
