import Foundation

/// Identifiers and words from the text around the cursor, used to rank
/// suggestions, to leave a document's own names alone, and to let swipe produce
/// them. It is rebuilt from the host's bounded context when needed, held only in
/// memory, and never saved.
public struct DocumentVocabulary: Sendable {
    public static let contextBefore = 4096
    public static let contextAfter = 1024
    static let maximumTokens = 2000

    /// Occurrences of each exact spelling.
    private var counts: [String: Int] = [:]
    /// Lowercase spelling → the most frequent exact spelling.
    private var folded: [String: String] = [:]
    /// Exact spellings in order of last appearance before the cursor.
    private var recency: [String: Int] = [:]

    public init() {}

    /// `before` and `after` are the text on each side of the cursor. A partial
    /// word touching the cursor is excluded, so a word being typed (or a typo
    /// about to be corrected) does not vouch for itself.
    public init(before: String, after: String = "") {
        let leading = before.reversed().prefix(while: Self.isIdentifierCharacter).count
        let trailing = after.prefix(while: Self.isIdentifierCharacter).count
        var position = 0
        for token in Self.tokens(in: before.dropLast(leading)) {
            add(token); position += 1; recency[token] = position
        }
        for token in Self.tokens(in: after.dropFirst(trailing)) { add(token) }
    }

    private mutating func add(_ token: String) {
        guard counts.count < Self.maximumTokens || counts[token] != nil else { return }
        let count = (counts[token] ?? 0) + 1
        counts[token] = count
        let key = token.lowercased()
        if let existing = folded[key], existing != token, counts[existing, default: 0] >= count { return }
        folded[key] = token
    }

    static func isIdentifierCharacter(_ character: Character) -> Bool {
        character == "_" || (character.isASCII && (character.isLetter || character.isNumber))
    }

    private static func tokens(in text: Substring) -> [String] {
        text.split(whereSeparator: { !isIdentifierCharacter($0) }).compactMap { token in
            guard (2...64).contains(token.count), token.first?.isNumber == false else { return nil }
            return String(token)
        }
    }

    public var isEmpty: Bool { counts.isEmpty }

    /// Whether the document uses this word, ignoring case.
    public func contains(_ word: String) -> Bool { folded[word.lowercased()] != nil }

    /// The document's own spelling of a word, such as `userName` for `username`.
    public func spelling(of word: String) -> String? { folded[word.lowercased()] }

    /// Words that extend `prefix` case-insensitively, most used first, then most recent.
    public func completions(prefix: String, limit: Int) -> [String] {
        let key = prefix.lowercased()
        return counts.keys
            .filter { $0.count > prefix.count && $0.lowercased().hasPrefix(key) }
            .sorted {
                let a = counts[$0]!, b = counts[$1]!
                if a != b { return a > b }
                let ra = recency[$0] ?? 0, rb = recency[$1] ?? 0
                return ra == rb ? $0 < $1 : ra > rb
            }
            .prefix(limit).map { $0 }
    }

    /// Spellings made only of ASCII letters, which a swipe can produce.
    var letterWords: [String] {
        folded.values.filter { word in word.count <= 32 && word.allSatisfy { $0.isASCII && $0.isLetter } }.sorted()
    }

    /// Words the document spells in lowercase letters only, as tap-correction
    /// targets. Mixed-case identifiers are left to suggestions and swipe.
    var lowercaseWords: [String] {
        folded.values.filter { word in
            (3...32).contains(word.count) && word.allSatisfy { $0.isASCII && $0.isLowercase }
        }.sorted()
    }
}
