import UIKit
import KeyboardCore

@MainActor
final class TextViewDocument: TextDocument {
    weak var textView: UITextView?
    var onChange: (() -> Void)?
    var onSelectionChange: (() -> Void)?
    private let autocorrectionIdentity = UUID()
    init(_ textView: UITextView) { self.textView = textView }
    var hasCompleteContext: Bool { textView != nil }
    var autocorrectionContextIdentifier: UUID? { autocorrectionIdentity }
    var allowsAutocorrection: Bool {
        guard let view = textView, view.isEditable else { return false }
        return HostAutocorrectionTraits.allows(autocorrection: view.autocorrectionType,
            keyboardType: view.keyboardType, secure: view.isSecureTextEntry, contentType: view.textContentType)
    }
    var capitalizesSentences: Bool {
        guard let view = textView, view.isEditable else { return false }
        return HostProseTraits.capitalizesSentences(autocapitalization: view.autocapitalizationType,
            keyboardType: view.keyboardType, secure: view.isSecureTextEntry)
    }
    var returnKeyLabel: String? { HostProseTraits.label(for: textView?.returnKeyType) }
    var before: String? {
        guard let view = textView else { return nil }
        return (view.text as NSString).substring(to: view.selectedRange.location)
    }
    var after: String? {
        guard let view = textView else { return nil }
        return (view.text as NSString).substring(from: NSMaxRange(view.selectedRange))
    }
    var selectedText: String? {
        guard let view = textView, view.selectedRange.length > 0 else { return nil }
        return (view.text as NSString).substring(with: view.selectedRange)
    }
    func contextBeforeInput(maximumCharacters: Int) -> String? {
        guard let view = textView else { return nil }
        let source = view.text ?? ""
        guard let selection = Range(view.selectedRange, in: source),
              selection.lowerBound.samePosition(in: source) != nil, selection.upperBound.samePosition(in: source) != nil else { return nil }
        let start = source.index(selection.lowerBound, offsetBy: -max(0, maximumCharacters), limitedBy: source.startIndex) ?? source.startIndex
        return String(source[start..<selection.lowerBound])
    }
    func contextAfterInput(maximumCharacters: Int) -> String? {
        guard let view = textView else { return nil }
        let source = view.text ?? ""
        guard let selection = Range(view.selectedRange, in: source),
              selection.lowerBound.samePosition(in: source) != nil, selection.upperBound.samePosition(in: source) != nil else { return nil }
        let end = source.index(selection.upperBound, offsetBy: max(0, maximumCharacters), limitedBy: source.endIndex) ?? source.endIndex
        return String(source[selection.upperBound..<end])
    }
    func insert(_ text: String) { textView?.insertText(text); onChange?() }
    func replaceTextBeforeCursor(_ expected: String, with replacement: String) -> Bool {
        guard let view = textView, view.isEditable, !expected.isEmpty,
              expected.count <= 64, replacement.count <= 64,
              view.selectedRange.length == 0,
              contextBeforeInput(maximumCharacters: expected.count) == expected else { return false }
        let selection = view.selectedRange
        let originalLength = view.textStorage.length
        let range = NSRange(location: view.selectedRange.location - expected.utf16.count, length: expected.utf16.count)
        guard view.delegate?.textView?(view, shouldChangeTextIn: range, replacementText: replacement) ?? true else { return false }
        let undo = view.undoManager
        undo?.beginUndoGrouping()
        view.selectedRange = range
        view.insertText(replacement)
        let replaced = view.textStorage.length == originalLength - expected.utf16.count + replacement.utf16.count
            && view.selectedRange == NSRange(location: range.location + replacement.utf16.count, length: 0)
            && contextBeforeInput(maximumCharacters: replacement.count) == replacement
        if replaced { undo?.setActionName("Autocorrect") }
        else if view.selectedRange == range { view.selectedRange = selection }
        undo?.endUndoGrouping()
        if replaced { onChange?() }
        return replaced
    }
    func deleteBackward() { textView?.deleteBackward(); onChange?() }
    func move(by offset: Int) {
        guard let view = textView, let current = view.selectedTextRange,
              let position = view.position(from: current.start, offset: offset) else { return }
        view.selectedTextRange = view.textRange(from: position, to: position)
        onSelectionChange?()
    }
    func moveVertically(by lines: Int) -> Bool {
        guard let view = textView, let current = view.selectedTextRange else { return false }
        let position = view.position(from: current.start, in: lines < 0 ? .up : .down, offset: abs(lines))
        if let position { view.selectedTextRange = view.textRange(from: position, to: position) }
        onSelectionChange?()
        return true
    }
    func deleteSurroundingText(before prefix: String, after suffix: String) -> Bool {
        guard let view = textView, view.selectedRange.length == 0,
              before?.hasSuffix(prefix) == true, after?.hasPrefix(suffix) == true,
              !prefix.isEmpty || !suffix.isEmpty else { return false }
        let range = NSRange(location: view.selectedRange.location - prefix.utf16.count,
                            length: prefix.utf16.count + suffix.utf16.count)
        // Keep large lines fast and let UIKit register a single undoable edit.
        let undo = view.undoManager
        undo?.beginUndoGrouping()
        view.selectedRange = range
        view.deleteBackward()
        undo?.setActionName("Delete line")
        undo?.endUndoGrouping()
        onChange?()
        return true
    }
}

@MainActor
final class ProxyDocument: TextDocument {
    weak var controller: UIInputViewController?
    init(_ controller: UIInputViewController) { self.controller = controller }
    var autocorrectionContextIdentifier: UUID? { controller?.textDocumentProxy.documentIdentifier }
    var allowsAutocorrection: Bool {
        guard let proxy = controller?.textDocumentProxy,
              let autocorrection = proxy.autocorrectionType, let keyboardType = proxy.keyboardType,
              let secure = proxy.isSecureTextEntry else { return false }
        return HostAutocorrectionTraits.allows(autocorrection: autocorrection,
            keyboardType: keyboardType, secure: secure,
            contentType: proxy.textContentType ?? nil)
    }
    var capitalizesSentences: Bool {
        guard let proxy = controller?.textDocumentProxy else { return false }
        return HostProseTraits.capitalizesSentences(autocapitalization: proxy.autocapitalizationType,
            keyboardType: proxy.keyboardType, secure: proxy.isSecureTextEntry)
    }
    var returnKeyLabel: String? { HostProseTraits.label(for: controller?.textDocumentProxy.returnKeyType) }
    var before: String? { controller?.textDocumentProxy.documentContextBeforeInput }
    var after: String? { controller?.textDocumentProxy.documentContextAfterInput }
    var selectedText: String? { controller?.textDocumentProxy.selectedText }
    func insert(_ text: String) { controller?.textDocumentProxy.insertText(text) }
    func deleteBackward() { controller?.textDocumentProxy.deleteBackward() }
    func move(by offset: Int) { controller?.textDocumentProxy.adjustTextPosition(byCharacterOffset: offset) }
}

@MainActor
enum HostProseTraits {
    static func capitalizesSentences(autocapitalization: UITextAutocapitalizationType?, keyboardType: UIKeyboardType?, secure: Bool?) -> Bool {
        guard autocapitalization == .sentences, secure != true else { return false }
        return [.default, .asciiCapable, .twitter].contains(keyboardType ?? .default)
    }

    static func label(for returnKey: UIReturnKeyType?) -> String? {
        switch returnKey {
        case .go: "Go"
        case .google, .yahoo, .search: "Search"
        case .join: "Join"
        case .next: "Next"
        case .route: "Route"
        case .send: "Send"
        case .done: "Done"
        case .emergencyCall: "Call"
        case .continue: "Continue"
        default: nil
        }
    }
}

/// iOS plays `UIDevice.playInputClick()` only for an input view that adopts
/// `UIInputViewAudioFeedback`; the user's Keyboard Clicks setting still applies.
@MainActor
class KeyClickInputView: UIInputView, UIInputViewAudioFeedback {
    var clicksEnabled: () -> Bool = { false }
    var enableInputClicksWhenVisible: Bool { clicksEnabled() }
}
