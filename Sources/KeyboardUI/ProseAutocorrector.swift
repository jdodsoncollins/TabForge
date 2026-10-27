import UIKit
import Darwin
import os
import KeyboardCore

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

    /// Whether the system spelling checker flags this word. Protected words,
    /// such as contact names and text replacements, are never flagged.
    func isMisspelled(_ word: String) -> Bool {
        guard let language, (2...32).contains(word.count), Self.isASCIIWord(word),
              !protectedWords.contains(word.lowercased()) else { return false }
        let range = NSRange(location: 0, length: word.utf16.count)
        return checker.rangeOfMisspelledWord(in: word, range: range, startingAt: 0, wrap: false, language: language) == range
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

/// Reads this process's own memory figures. The keyboard runs in its own
/// process with its own limit, separate from the app being typed into.
enum MemoryProbe {
    /// Bytes this process may still allocate, or nil when the system does not say.
    static func available() -> UInt64? {
        let value = os_proc_available_memory()
        return value > 0 ? UInt64(value) : nil
    }

    /// This process's physical footprint, the figure the system limit applies to.
    static func footprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }

    /// The assumed-limit fallback applies only to the keyboard extension. The
    /// companion app's playground has an app's much larger allowance.
    private static let isExtension = Bundle.main.bundleURL.pathExtension == "appex"

    static func tier() -> LanguageFeatureTier {
        // Zero means the system gave no figure, which it documents for
        // processes that are not apps and for one already over its limit.
        MemoryBudget.tier(available: available(), footprint: isExtension ? footprint() : nil,
                          physicalMemory: ProcessInfo.processInfo.physicalMemory)
    }
}

/// Loads the bundled word list off the main thread and builds the swipe index
/// when memory allows. It holds no typed text and is dropped on dismissal.
@MainActor
final class LanguageResources {
    private(set) var lexicon: Lexicon?
    private var decoder: SwipeDecoder?
    private var loading: Task<Void, Never>?
    /// Memory warnings lower this for the rest of the process's life: the first
    /// turns off swipe, the second leaves only the system spelling checker.
    private(set) var ceiling = LanguageFeatureTier.full
    /// Called on the main actor when the word list loads or is dropped.
    var onChange: (() -> Void)?

    var tier: LanguageFeatureTier { min(ceiling, MemoryProbe.tier()) }

    /// Starts loading in the background if memory allows. Safe to call often.
    func prepare() {
        guard lexicon == nil, loading == nil, tier >= .standard else { return }
        let keywords = Array(Set(CodeLanguage.allCases.flatMap(\.keywords)))
        loading = Task { [weak self] in
            let loaded = await Task.detached(priority: .utility) { Lexicon.bundled(extraWords: keywords) }.value
            guard let self, !Task.isCancelled else { return }
            self.loading = nil
            guard self.tier >= .standard else { return }
            self.lexicon = loaded
            self.onChange?()
        }
    }

    /// The swipe decoder, built from the shared word list on first use. Nil
    /// while memory is short.
    func swipeDecoder() -> SwipeDecoder? {
        guard tier == .full else { decoder = nil; return nil }
        if let decoder { return decoder }
        if lexicon == nil {
            // A swipe before the background load finishes waits for the list once.
            loading?.cancel(); loading = nil
            lexicon = Lexicon.bundled(extraWords: Array(Set(CodeLanguage.allCases.flatMap(\.keywords))))
            onChange?()
        }
        decoder = lexicon.map { SwipeDecoder(lexicon: $0) }
        return decoder
    }

    /// Drops only the swipe index, when swipe is turned off.
    func dropSwipeIndex() { decoder = nil }

    /// Drops the word list and swipe index; the next use reloads them.
    func release() {
        loading?.cancel(); loading = nil
        let hadLexicon = lexicon != nil
        lexicon = nil; decoder = nil
        if hadLexicon { onChange?() }
    }

    func memoryWarning() {
        ceiling = ceiling == .full ? .standard : .minimal
        release()
    }
}
