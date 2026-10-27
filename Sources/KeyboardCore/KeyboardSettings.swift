import Foundation

public enum CodeLanguage: String, Codable, CaseIterable, Sendable {
    case swift = "Swift", python = "Python", javascript = "JavaScript"
    case typescript = "TypeScript", shell = "Shell", json = "JSON"

    public var fileExtension: String {
        switch self {
        case .swift: "swift"
        case .python: "py"
        case .javascript: "js"
        case .typescript: "ts"
        case .shell: "sh"
        case .json: "json"
        }
    }

    public var keywords: [String] { Self.keywordLists[self] ?? [] }

    private static let keywordLists = Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.makeKeywords()) })
    private func makeKeywords() -> [String] {
        switch self {
        case .swift: "let var func return import struct class enum protocol extension guard if else switch case for while async await throws try catch print public private static self nil true false some View String Int Double Bool Task actor override init deinit weak final where in is as break continue do defer set get typealias associatedtype mutating nonisolated".components(separatedBy: " ")
        case .python: "def class return import from as if elif else for while in is not and or try except finally with yield lambda async await print range self None True False pass break continue raise global nonlocal assert del enumerate len list dict str int float open super property".components(separatedBy: " ")
        case .javascript, .typescript: "const let var function return import export default class extends new this if else for while async await try catch throw finally console log typeof instanceof null undefined true false interface type enum implements public private readonly string number boolean Promise void never any unknown switch case break continue yield of in map filter reduce".components(separatedBy: " ")
        case .shell: "echo printf export source cd ls pwd mkdir touch cat grep find sed awk git ssh curl chmod chown sudo if then else elif fi for do done while case esac in function return exit read set unset alias local test true false pushd popd python swift node npm docker kubectl".components(separatedBy: " ")
        case .json: ["true", "false", "null"]
        }
    }

    public var sample: String {
        switch self {
        case .swift: "// A little less reaching. A lot more coding.\nimport Foundation\n\nfunc greet(_ name: String) {\n    let message = \"Hello, \\(name)!\"\n    print(message)\n}\n\ngreet(\"world\")\n"
        case .python: "# Small screen. Real code.\ndef greet(name):\n    message = f\"Hello, {name}!\"\n    print(message)\n\ngreet(\"world\")\n"
        case .javascript, .typescript: "// Your next idea starts here.\nasync function greet(name) {\n    const message = `Hello, ${name}!`;\n    console.log(message);\n}\n\ngreet(\"world\");\n"
        case .shell: "#!/bin/sh\n\nname=\"world\"\nprintf 'Hello, %s!\\n' \"$name\"\n\n# Try your next command below.\n"
        case .json: "{\n    \"name\": \"Script Keyboard\",\n    \"madeFor\": [\"code\", \"terminals\", \"you\"],\n    \"onDevice\": true\n}\n"
        }
    }
}

public enum Indentation: String, Codable, CaseIterable, Sendable {
    case twoSpaces = "2 spaces", fourSpaces = "4 spaces", tabs = "Tab character"
    public var unit: String { self == .tabs ? "\t" : String(repeating: " ", count: width) }
    public var width: Int { self == .twoSpaces ? 2 : 4 }
    public var shortLabel: String { self == .tabs ? "Tab" : "\(width) sp" }
}

public enum CompatibilityMode: String, Codable, CaseIterable, Sendable {
    case editor = "Code editor", terminal = "Terminal · ANSI", remoteDesktop = "Remote desktop"
    public var detail: String {
        switch self {
        case .editor: "Smart pairs, indentation, and local cursor movement for text fields and editors."
        case .terminal: "Literal Tab, CR return, ANSI arrows, Escape, and ASCII Control codes. Enable only in terminals that accept control text."
        case .remoteDesktop: "Literal characters and tabs with smart edits disabled. Shortcuts and navigation depend on your remote client’s text input support."
        }
    }
    public var shortLabel: String {
        switch self { case .editor: "Code"; case .terminal: "ANSI"; case .remoteDesktop: "Remote" }
    }
}

public enum KeyboardAppearance: String, Codable, CaseIterable, Sendable {
    case system = "System", light = "Light", dark = "Dark"
}

public enum KeyboardTheme: String, Codable, CaseIterable, Sendable {
    case standard = "iOS Standard", darcula = "Darcula", dracula = "Dracula", nord = "Nord"
    public var usesDarkPalette: Bool { self != .standard }
}

public enum KeySize: String, Codable, CaseIterable, Sendable {
    case compact = "Compact", balanced = "Balanced", comfortable = "Comfortable"
    public var height: Double {
        switch self { case .compact: 44; case .balanced: 48; case .comfortable: 54 }
    }
}

public enum HapticStrength: String, Codable, CaseIterable, Sendable {
    case light = "Light", medium = "Medium", strong = "Strong"
}

/// Keys the full-layout toolbar can show, in their fixed left-to-right order.
/// The tools and settings gear always follows them.
public enum ToolbarKey: String, CaseIterable, Sendable {
    case escape, tab, control, option, command, deleteLine, pipe, tilde, backtick, backslash, dollar, left, down, up, right
    public static let defaults: [Self] = [.escape, .control, .option, .command, .deleteLine, .left, .down, .up, .right]
    /// Keeps each toolbar target usable on the narrowest supported phone.
    public static let maximumCount = 10
    public var title: String {
        switch self {
        case .escape: "Esc"
        case .tab: "Tab"
        case .control: "Ctrl"
        case .option: "Option ⌥"
        case .command: "Command ⌘"
        case .deleteLine: "Delete-line key"
        case .pipe: "Pipe |"
        case .tilde: "Tilde ~"
        case .backtick: "Backtick `"
        case .backslash: "Backslash \\"
        case .dollar: "Dollar $"
        case .left: "Left arrow"
        case .down: "Down arrow"
        case .up: "Up arrow"
        case .right: "Right arrow"
        }
    }
    /// The literal text for character keys.
    public var text: String? {
        switch self {
        case .pipe: "|"
        case .tilde: "~"
        case .backtick: "`"
        case .backslash: "\\"
        case .dollar: "$"
        default: nil
        }
    }
}

public enum KeyboardHeightMode: String, Codable, CaseIterable, Sendable {
    case automatic = "Automatic", compact = "Compact", full = "Full"
}

public enum KeyboardHeightPolicy {
    /// `availableHeight` must describe the host's usable area, never the keyboard's
    /// own height. A dedicated tabletop panel has room for the full keyboard.
    public static func resolve(
        mode: KeyboardHeightMode,
        availableHeight: Double?,
        compactVertical: Bool,
        tabletop: Bool
    ) -> Bool {
        guard !tabletop else { return false }
        switch mode {
        case .full: return false
        case .compact: return true
        case .automatic:
            if compactVertical { return true }
            guard let availableHeight, availableHeight.isFinite, availableHeight > 0 else { return false }
            return availableHeight <= 500
        }
    }
}

public enum KeyboardLayout: String, CaseIterable, Sendable {
    case compact = "Compact", widePhone = "Wide phone", expanded = "Expanded", studio = "Studio", tabletop = "Tabletop"
    public static func resolve(width: Double) -> Self {
        // Capacity, rather than device names: also adapts to floating and split keyboards.
        width >= 768 ? .studio : width >= 650 ? .expanded : width >= 460 ? .widePhone : .compact
    }
    public var hasFullSymbolRow: Bool { self == .expanded || self == .studio || self == .tabletop }
}

public struct KeyboardSettings: Codable, Equatable, Sendable {
    public var language: CodeLanguage = .swift
    public var indentation: Indentation = .fourSpaces
    public var compatibility: CompatibilityMode = .editor
    public var appearance: KeyboardAppearance = .system
    // Optional storage lets existing preference records decode without losing
    // their settings when the theme field is absent.
    private var selectedTheme: KeyboardTheme?
    public var theme: KeyboardTheme {
        get { selectedTheme ?? .standard }
        set { selectedTheme = newValue == .standard ? nil : newValue }
    }
    public var keySize: KeySize = .balanced
    private var selectedHeightMode: KeyboardHeightMode?
    public var heightMode: KeyboardHeightMode {
        get { selectedHeightMode ?? .automatic }
        set { selectedHeightMode = newValue == .automatic ? nil : newValue }
    }
    public var autoPair = true
    public var skipClosingDelimiter = true
    public var smartIndent = true
    public var suggestions = true
    private var proseAutocorrection: Bool?
    /// Off by default for source code; the host must also permit correction.
    public var autocorrectProse: Bool {
        get { proseAutocorrection ?? false }
        set { proseAutocorrection = newValue ? true : nil }
    }
    public var swipeTyping = false
    public var cursorScrubbing = true
    public var haptics = true
    private var selectedHapticStrength: HapticStrength?
    public var hapticStrength: HapticStrength {
        get { selectedHapticStrength ?? .light }
        set { selectedHapticStrength = newValue == .light ? nil : newValue }
    }
    private var keyClickSounds: Bool?
    /// Plays the system keyboard click, which also follows the user's
    /// Sounds › Keyboard Clicks setting and needs no Full Access.
    public var keyClicks: Bool {
        get { keyClickSounds ?? true }
        set { keyClickSounds = newValue ? nil : false }
    }
    public var keyPreviews = true
    private var sentenceCapitalization: Bool?
    /// Applies only in prose fields whose host asks for sentence capitals.
    public var autoCapitalize: Bool {
        get { sentenceCapitalization ?? true }
        set { sentenceCapitalization = newValue ? nil : false }
    }
    private var doubleSpacePeriod: Bool?
    public var periodShortcut: Bool {
        get { doubleSpacePeriod ?? true }
        set { doubleSpacePeriod = newValue ? nil : false }
    }
    // Raw values keep a record readable if a later version adds a key.
    private var selectedToolbarKeys: [String]?
    public var toolbarKeys: [ToolbarKey] {
        get { selectedToolbarKeys.map { $0.compactMap(ToolbarKey.init(rawValue:)) } ?? ToolbarKey.defaults }
        set {
            let ordered = ToolbarKey.allCases.filter(newValue.contains)
            selectedToolbarKeys = ordered == ToolbarKey.defaults ? nil : ordered.map(\.rawValue)
        }
    }
    private var shownTips: Int?
    /// How many one-time keyboard tips have been shown.
    public var tipsShown: Int {
        get { shownTips ?? 0 }
        set { shownTips = newValue == 0 ? nil : newValue }
    }
    public var showNumberRow = false
    private var extraEditingRow: Bool?
    public var showNavigationRow: Bool {
        get { extraEditingRow ?? false }
        set { extraEditingRow = newValue ? true : nil }
    }
    public var showKeyHints = true
    public var repeatDelete = true
    public var terminalReturnIsCR = true
    public var terminalDeleteIsDEL = true
    public var terminalApplicationCursor = false
    public var snippets: [CodeSnippet] = CodeSnippet.defaults
    public init() {}
    public var smartEditingEnabled: Bool { compatibility == .editor }
}

public struct CodeSnippet: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var text: String
    public init(id: UUID = UUID(), name: String, text: String) {
        self.id = id; self.name = name; self.text = text
    }
    public static let defaults = [
        CodeSnippet(name: "Arrow", text: " => "),
        CodeSnippet(name: "Not equal", text: " != "),
        CodeSnippet(name: "Comment", text: "// "),
        CodeSnippet(name: "Pipe", text: " | "),
        CodeSnippet(name: "Home path", text: "~/")
    ]
}
