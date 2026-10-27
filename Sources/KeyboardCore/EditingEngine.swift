import Foundation

public enum NavigationKey: String, Sendable { case left, right, up, down, home, end, escape, pageUp, pageDown }

@MainActor
public final class EditingEngine {
    public var settings: KeyboardSettings {
        didSet { if settings != oldValue { invalidateAutocorrection() } }
    }
    public let document: any TextDocument
    /// A local spelling service supplied by the platform layer. No service is
    /// consulted until both the user setting and the focused host allow it.
    public var correctionProvider: ((String) -> String?)? {
        didSet { invalidateAutocorrection() }
    }
    /// Tap points for the word being passed to `correctionProvider`, one per
    /// letter, or empty. Set only for the duration of that call.
    public internal(set) var correctionTouches: [SwipePoint?] = []
    /// Bundled words for English suggestions. Optional so the keyboard can run
    /// without it when memory is short.
    public var lexicon: Lexicon?
    var autocorrectionState = AutocorrectionState()
    private let pairs = ["{": "}", "[": "]", "(": ")", "\"": "\"", "'": "'", "`": "`"]
    public init(document: any TextDocument, settings: KeyboardSettings = .init()) {
        self.document = document; self.settings = settings
    }

    /// `touch` is where the key was tapped, in the platform layer's key
    /// coordinate space. It is kept only while the current word is tracked.
    public func type(_ text: String, touch: SwipePoint? = nil) {
        if text == " ", autocorrectBeforeSpace() { return }
        let trackedWord = prepareAutocorrectionTracking(for: text, touch: touch)
        defer { finishAutocorrectionTracking(trackedWord) }
        // Ordinary text never participates in delimiter pairing. In a native
        // editor, avoid requesting document-sized context for each letter.
        guard settings.smartEditingEnabled, settings.autoPair,
              pairs[text] != nil || pairs.values.contains(text) else { document.insert(text); return }
        let quote = ["\"", "'", "`"].contains(text)
        // Quotes need the complete trailing backslash run to preserve escape
        // parity. Other delimiters only inspect the immediately adjacent text.
        guard let before = quote ? document.before : document.contextBeforeInput(maximumCharacters: 1) else {
            document.insert(text); return
        }
        let previous = before.last
        let after = document.contextAfterInput(maximumCharacters: 1)
        let following = after?.first
        // An escaped quote belongs to the string, even when a closing quote follows it.
        if quote, before.reversed().prefix(while: { $0 == "\\" }).count % 2 == 1 {
            document.insert(text)
            return
        }
        if settings.autoPair, settings.skipClosingDelimiter,
           pairs.values.contains(text),
           document.selectedText == nil, after?.hasPrefix(text) == true {
            document.move(by: text.utf16.count)
            return
        }
        if settings.autoPair, let closing = pairs[text] {
            let inWord = quote && previous.map { $0.isLetter || $0.isNumber || $0 == "_" } == true
            let atBoundary = following == nil || following!.isWhitespace || ")]};,:".contains(following!)
            if !inWord && (document.selectedText != nil || atBoundary) {
                let selected = document.selectedText ?? ""
                document.insert(text + selected + closing)
                document.move(by: -closing.utf16.count)
                return
            }
        }
        document.insert(text)
    }

    public func backspace() {
        if undoAutocorrectionOnBackspace() { return }
        if settings.compatibility == .terminal {
            document.insert(settings.terminalDeleteIsDEL ? "\u{7F}" : "\u{08}")
            return
        }
        if settings.smartEditingEnabled, settings.autoPair, document.selectedText == nil,
           let last = document.contextBeforeInput(maximumCharacters: 1)?.last,
           let next = document.contextAfterInput(maximumCharacters: 1)?.first,
           pairs[String(last)] == String(next) {
            document.move(by: 1); document.deleteBackward(); document.deleteBackward()
            return
        }
        document.deleteBackward()
    }

    public var canDeleteLine: Bool { lineDeletion != nil }

    /// Deletes one logical line, including its following line break, or the
    /// preceding break for the final line. Selected text uses ordinary Delete.
    @discardableResult
    public func deleteLine() -> Bool {
        invalidateAutocorrection()
        guard let range = lineDeletion else { return false }
        return document.deleteSurroundingText(before: range.before, after: range.after)
    }

    private var lineDeletion: (before: String, after: String)? {
        guard settings.compatibility == .editor, document.selectedText == nil,
              let before = document.before, let after = document.after else { return nil }
        let prefix = String(before.reversed().prefix(while: { !$0.isNewline }).reversed())
        let suffix = String(after.prefix(while: { !$0.isNewline }))
        // A proxy's context may start halfway through a line. Do not treat that
        // edge as the start of the document or delete an unverified partial line.
        guard document.hasCompleteContext || prefix.count < before.count else { return nil }
        if let newline = after.dropFirst(suffix.count).first {
            return (prefix, suffix + String(newline))
        }
        guard document.hasCompleteContext else { return nil }
        let previousBreak = before.dropLast(prefix.count).last.map(String.init) ?? ""
        let left = previousBreak + prefix
        guard !left.isEmpty || !suffix.isEmpty else { return nil }
        return (left, suffix)
    }

    public func tab() {
        invalidateAutocorrection()
        guard settings.smartEditingEnabled else { document.insert("\t"); return }
        if let selected = document.selectedText, selected.contains("\n") { indent(); return }
        guard settings.indentation != .tabs else { document.insert("\t"); return }
        let line = document.before?.components(separatedBy: "\n").last ?? ""
        let column = line.reduce(0) { $1 == "\t" ? $0 + settings.indentation.width - ($0 % settings.indentation.width) : $0 + 1 }
        document.insert(String(repeating: " ", count: settings.indentation.width - column % settings.indentation.width))
    }

    public func indent() {
        invalidateAutocorrection()
        guard settings.smartEditingEnabled else { document.insert("\t"); return }
        if let selected = document.selectedText, !selected.isEmpty {
            document.insert(selected.components(separatedBy: "\n").map { settings.indentation.unit + $0 }.joined(separator: "\n"))
            return
        }
        guard let before = document.before else { return }
        let prefix = before.components(separatedBy: "\n").last ?? ""
        document.move(by: -prefix.utf16.count)
        document.insert(settings.indentation.unit)
        document.move(by: prefix.utf16.count)
    }

    public func outdent() {
        invalidateAutocorrection()
        if settings.compatibility == .terminal { document.insert("\u{1B}[Z"); return }
        guard settings.smartEditingEnabled else { return }
        func removal(_ line: String) -> Int {
            line.first == "\t" ? 1 : min(line.prefix(while: { $0 == " " }).count, settings.indentation.width)
        }
        if let selected = document.selectedText {
            document.insert(selected.components(separatedBy: "\n").map { String($0.dropFirst(removal($0))) }.joined(separator: "\n"))
            return
        }
        guard let before = document.before, let after = document.after else { return }
        let prefix = before.components(separatedBy: "\n").last ?? ""
        let suffix = after.components(separatedBy: "\n").first ?? ""
        let count = removal(prefix + suffix)
        guard count > 0 else { return }
        document.move(by: -prefix.utf16.count + count)
        for _ in 0..<count { document.deleteBackward() }
        document.move(by: max(0, prefix.utf16.count - count))
    }

    public func newline() {
        invalidateAutocorrection()
        guard settings.smartEditingEnabled else {
            document.insert(settings.compatibility == .terminal && settings.terminalReturnIsCR ? "\r" : "\n")
            return
        }
        guard settings.smartIndent, let before = document.before else { document.insert("\n"); return }
        let line = before.components(separatedBy: "\n").last ?? ""
        let indentation = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let opensBlock = trimmed.last.map { "{[(".contains($0) } == true || (settings.language == .python && trimmed.hasSuffix(":"))
        let nextIndent = indentation + (opensBlock ? settings.indentation.unit : "")
        if opensBlock, let opener = trimmed.last, let closer = pairs[String(opener)], document.after?.hasPrefix(closer) == true {
            document.insert("\n" + nextIndent + "\n" + indentation)
            document.move(by: -(indentation.utf16.count + 1))
        } else { document.insert("\n" + nextIndent) }
    }

    public func control(_ letter: String) {
        _ = sendShortcut(letter, modifiers: .control)
    }

    public var identifierPrefix: String {
        String((document.before ?? "").reversed().prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" }).reversed())
    }
    public var completions: [String] {
        guard settings.suggestions, settings.smartEditingEnabled else { return [] }
        // Bound work even when a host exposes an entire large source file. Never
        // offer a replacement for a truncated identifier.
        let context = document.contextBeforeInput(maximumCharacters: DocumentVocabulary.contextBefore) ?? ""
        let prefix = String(context.reversed().prefix(while: { $0.isLetter || $0.isNumber || $0 == "_" }).reversed())
        guard prefix.count <= 128 else { return [] }
        guard !prefix.isEmpty else { return Array(settings.language.keywords.prefix(3)) }
        // Keywords first, then the document's own names by use, then English
        // words when prose autocorrect is on and the bundled list is loaded.
        let local = DocumentVocabulary(before: context).completions(prefix: prefix, limit: 3)
        let english = settings.autocorrectProse && prefix.count >= 2 && prefix.allSatisfy({ $0.isASCII && $0.isLowercase })
            ? lexicon?.completions(prefix: prefix, limit: 3) ?? [] : []
        var seen = Set<String>()
        let foldedPrefix = prefix.lowercased()
        var result: [String] = []
        for word in settings.language.keywords + local + english {
            if word.count > prefix.count, word.lowercased().hasPrefix(foldedPrefix), seen.insert(word.lowercased()).inserted {
                result.append(word)
                if result.count == 3 { break }
            }
        }
        return result
    }

    /// Words around the cursor from bounded host context, for correction and
    /// swipe. Built on request and not retained by the engine.
    public func documentVocabulary() -> DocumentVocabulary {
        guard settings.smartEditingEnabled,
              let before = document.contextBeforeInput(maximumCharacters: DocumentVocabulary.contextBefore) else { return .init() }
        return DocumentVocabulary(
            before: before, after: document.contextAfterInput(maximumCharacters: DocumentVocabulary.contextAfter) ?? "")
    }
    public func complete(_ word: String) {
        invalidateAutocorrection()
        guard settings.smartEditingEnabled, document.before != nil else { return }
        for _ in identifierPrefix { document.deleteBackward() }
        document.insert(word)
    }
}
