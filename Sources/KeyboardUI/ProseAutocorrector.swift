import UIKit

/// Host traits are independent of TabForge's opt-in preference. Never override
/// a code editor's explicit opt-out or a field intended for structured data.
@MainActor
enum HostAutocorrectionTraits {
    static func allows(autocorrection: UITextAutocorrectionType?, keyboardType: UIKeyboardType?,
                       secure: Bool?, contentType: UITextContentType?) -> Bool {
        guard let autocorrection, let keyboardType, let secure, autocorrection != .no, !secure else { return false }
        guard [.default, .asciiCapable, .twitter].contains(keyboardType) else { return false }
        // Semantic fields include names, addresses, credentials and codes.
        // Unstructured prose normally has no text content type.
        return contentType?.rawValue.isEmpty ?? true
    }
}

/// A small on-device spelling adapter, created only for an eligible word at a
/// Space boundary. It does not use Apple's private keyboard prediction engine.
@MainActor
final class ProseAutocorrector {
    private let checker = UITextChecker()
    private let language = UITextChecker.availableLanguages.first { $0.hasPrefix("en_") || $0 == "en" }
    var protectedWords: Set<String>

    init(protectedWords: Set<String> = []) {
        self.protectedWords = protectedWords
    }

    func correction(for word: String) -> String? {
        guard let language, (3...32).contains(word.count), Self.isASCIIWord(word),
              !protectedWords.contains(word.lowercased()) else { return nil }
        let range = NSRange(location: 0, length: word.utf16.count)
        guard checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: language) == range else { return nil }
        let folded = word.lowercased()
        guard let guess = checker.guesses(forWordRange: range, in: word, language: language)?.prefix(8).first(where: {
            Self.isASCIIWord($0) && $0.lowercased() != folded && Self.isSingleEdit(folded, $0.lowercased())
        }) else { return nil }
        let lower = guess.lowercased()
        return word.first?.isUppercase == true ? lower.prefix(1).uppercased() + lower.dropFirst() : lower
    }

    private static func isASCIIWord(_ word: String) -> Bool {
        !word.isEmpty && word.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) }
    }

    /// Accept only one insertion, deletion, substitution or adjacent swap.
    /// Bounded ASCII words keep dictionary filtering inexpensive and predictable.
    static func isSingleEdit(_ source: String, _ candidate: String) -> Bool {
        let a = Array(source.utf8), b = Array(candidate.utf8)
        guard abs(a.count - b.count) <= 1 else { return false }
        if a.count == b.count {
            let changed = a.indices.filter { a[$0] != b[$0] }
            if changed.count == 1 { return true }
            return changed.count == 2 && changed[1] == changed[0] + 1
                && a[changed[0]] == b[changed[1]] && a[changed[1]] == b[changed[0]]
        }
        let shorter = a.count < b.count ? a : b
        let longer = a.count < b.count ? b : a
        var offset = 0
        while offset < shorter.count, shorter[offset] == longer[offset] { offset += 1 }
        return shorter.dropFirst(offset).elementsEqual(longer.dropFirst(offset + 1))
    }
}
