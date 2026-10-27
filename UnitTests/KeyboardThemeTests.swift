import UIKit
import Testing
import KeyboardCore
@testable import ScriptKeyboard

@Suite @MainActor
struct KeyboardThemeTests {
    @Test func fourOverlappingKeysCommitOnceAndKeepTheirCapturedModifiers() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.compatibility = .terminal
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        func button(_ id: String) throws -> UIButton {
            try #require((toolbar.subviews + keyboard.subviews).first { $0.accessibilityIdentifier == id } as? UIButton)
        }
        let control = try button("keyboard.modifier.control")
        let option = try button("keyboard.modifier.option")
        let c = try button("key.c"), d = try button("key.d")
        control.sendActions(for: .touchDown)
        option.sendActions(for: .touchDown)
        c.sendActions(for: .touchDown)
        d.sendActions(for: .touchDown)
        #expect(document.text.isEmpty)
        c.sendActions(for: .touchUpInside)
        control.sendActions(for: .touchUpInside)
        option.sendActions(for: .touchUpInside)
        d.sendActions(for: .touchUpInside)
        #expect(document.text == "\u{1B}\u{03}\u{1B}\u{04}")
        #expect(!control.isSelected && !option.isSelected)
        c.sendActions(for: .touchUpInside)
        #expect(document.text.hasSuffix("c"))
        let keys = try ["key.q", "key.w", "key.e", "key.r"].map(button)
        keys.forEach { $0.sendActions(for: .touchDown) }
        keys.reversed().forEach { $0.sendActions(for: .touchUpInside) }
        #expect(document.text.hasSuffix("crewq"))
        #expect(!keys.contains { $0.isExclusiveTouch })
        let left = try button("keyboard.arrow.left")
        control.sendActions(for: .touchDown); left.sendActions(for: .touchDown)
        control.sendActions(for: .touchUpInside); left.sendActions(for: .touchUpInside)
        #expect(document.text.hasSuffix("\u{1B}[1;5D"))
    }

    @Test func overlappingShiftAndPageChangesDoNotReplacePressedKeys() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        func button(_ id: String) throws -> UIButton {
            try #require(keyboard.subviews.first { $0.accessibilityIdentifier == id } as? UIButton)
        }
        let shift = try button("key.Shift"), q = try button("key.q"), w = try button("key.w")
        shift.sendActions(for: .touchDown)
        q.sendActions(for: .touchDown); w.sendActions(for: .touchDown)
        shift.sendActions(for: .touchUpInside)
        #expect(q.superview === keyboard && w.superview === keyboard)
        q.sendActions(for: .touchUpInside); w.sendActions(for: .touchUpInside)
        #expect(document.text == "QW")
        let e = try button("key.e"), mode = try button("key.123")
        e.sendActions(for: .touchDown)
        mode.sendActions(for: .touchDown); mode.sendActions(for: .touchUpInside)
        #expect(e.superview === keyboard)
        e.sendActions(for: .touchUpInside)
        #expect(document.text == "QWe")
        #expect(e.superview == nil)
        let delete = try button("key.Delete")
        delete.sendActions(for: .touchDown); delete.sendActions(for: .touchCancel)
        #expect(document.text == "QWe")
    }

    @Test(arguments: [320.0, 390, 550, 768, 951, 1366])
    func gapHitTestingIsDeterministicAndDoesNotEscapeTheKeyboard(_ width: Double) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        keyboard.frame = CGRect(x: 0, y: 0, width: width, height: keyboard.desiredHeight)
        keyboard.layoutIfNeeded()
        let q = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "key.q" })
        let w = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "key.w" })
        let split = (q.frame.maxX + w.frame.minX) / 2
        #expect(keyboard.hitTest(CGPoint(x: split - 0.1, y: q.frame.midY), with: nil) === q)
        #expect(keyboard.hitTest(CGPoint(x: split + 0.1, y: q.frame.midY), with: nil) === w)
        #expect(keyboard.hitTest(CGPoint(x: q.frame.midX, y: q.frame.maxY + 1), with: nil) === q)
        #expect(keyboard.hitTest(CGPoint(x: -1, y: q.frame.midY), with: nil) == nil)
        #expect(keyboard.hitTest(CGPoint(x: width + 1, y: q.frame.midY), with: nil) == nil)
        #expect(keyboard.hitTest(CGPoint(x: q.frame.midX, y: keyboard.bounds.maxY + 1), with: nil) == nil)
    }

    @Test(arguments: [320.0, 375, 390, 440, 550, 630, 768, 834, 1024, 1366])
    func navigationToolbarFitsWithoutOverlapping(_ width: Double) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        keyboard.frame = CGRect(x: 0, y: 0, width: width, height: keyboard.desiredHeight)
        keyboard.layoutIfNeeded()
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        let controls = toolbar.subviews.compactMap { $0 as? UIButton }.sorted { $0.frame.minX < $1.frame.minX }
        #expect(controls.count == 10)
        #expect(controls.map(\.accessibilityIdentifier) == [
            "keyboard.escape", "keyboard.modifier.control", "keyboard.modifier.option", "keyboard.modifier.command",
            "keyboard.deleteLine", "keyboard.arrow.left", "keyboard.arrow.down", "keyboard.arrow.up", "keyboard.arrow.right",
            "keyboard.quickSettings"
        ])
        for button in controls {
            #expect(button.frame.width >= 30 && button.frame.height == 44)
            #expect(toolbar.bounds.contains(button.frame))
            #expect(!controls.contains { $0 !== button && $0.frame.intersects(button.frame) })
        }
        let gear = try #require(controls.first { $0.accessibilityIdentifier == "keyboard.quickSettings" })
        #expect(gear.menu?.children.contains { $0.title.hasPrefix("Language · ") } == true)
        #expect(gear.menu?.children.contains { $0.title == "Editing actions" } == true)
        #expect(gear.menu?.children.contains { $0.title == "Snippets" } == true)
        #expect(gear.menu?.children.contains { $0.title == "Code suggestions" } == true)
        #expect(gear.showsMenuAsPrimaryAction)
        #expect(!controls.contains { $0.accessibilityIdentifier == "keyboard.editingTools" })
    }

    @Test func escapeCommitsOnceAndDoesNotLoseHeldModifiersOnRelease() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.compatibility = .terminal
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        let escape = try #require(toolbar.subviews.first { $0.accessibilityIdentifier == "keyboard.escape" } as? UIButton)
        let control = try #require(toolbar.subviews.first { $0.accessibilityIdentifier == "keyboard.modifier.control" } as? UIButton)
        #expect(escape.accessibilityLabel == "Escape")
        #expect(escape.accessibilityTraits.contains(.keyboardKey))
        escape.sendActions(for: .touchDown)
        escape.sendActions(for: .touchCancel)
        #expect(document.text.isEmpty)
        escape.sendActions(for: .touchDown)
        escape.sendActions(for: .touchUpInside)
        #expect(document.text == "\u{1B}")
        // Ctrl-Escape has no portable text encoding. Releasing Ctrl first must
        // retain that chord and decline it, rather than emit a bare Escape.
        control.sendActions(for: .touchDown)
        escape.sendActions(for: .touchDown)
        control.sendActions(for: .touchUpInside)
        escape.sendActions(for: .touchUpInside)
        #expect(document.text == "\u{1B}")
        #expect(!control.isSelected)
        escape.sendActions(for: .touchDown)
        escape.sendActions(for: .touchUpInside)
        #expect(document.text == "\u{1B}\u{1B}")
    }

    @Test func modifierChordsAreOneShotAndResetOnProfileChangesAndDismissal() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.compatibility = .terminal
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        func button(_ id: String) throws -> UIButton {
            try #require((toolbar.subviews + keyboard.subviews).first { $0.accessibilityIdentifier == id } as? UIButton)
        }
        let control = try button("keyboard.modifier.control")
        control.sendActions(for: .touchUpInside)
        #expect(control.isSelected)
        try button("key.c").sendActions(for: .touchUpInside)
        #expect(document.text == "\u{03}" && !control.isSelected)
        try button("key.c").sendActions(for: .touchUpInside)
        #expect(document.text == "\u{03}c")
        control.sendActions(for: .touchUpInside)
        control.sendActions(for: .touchUpInside)
        #expect(!control.isSelected)
        control.sendActions(for: .touchUpInside)
        preferences.settings.compatibility = .editor; keyboard.applySettings()
        #expect(!control.isSelected)
        try button("keyboard.modifier.option").sendActions(for: .touchUpInside)
        keyboard.releaseTransientResources()
        #expect(!toolbar.subviews.compactMap { $0 as? UIButton }.contains { $0.isSelected })
    }

    @Test func commandAndOptionArrowsMoveTheCursorAndUnsupportedChordsShowStatus() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument(text: "let value = 1")
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        func tap(_ id: String) throws {
            let button = try #require((toolbar.subviews + keyboard.subviews).first { $0.accessibilityIdentifier == id } as? UIButton)
            button.sendActions(for: .touchUpInside)
        }
        try tap("keyboard.modifier.command"); try tap("keyboard.arrow.left")
        #expect(document.cursor == 0)
        try tap("keyboard.modifier.option"); try tap("keyboard.arrow.right")
        #expect(document.cursor == 3)
        try tap("keyboard.modifier.command"); try tap("key.c")
        #expect(document.text == "let value = 1" && document.cursor == 3)
        let status = try #require(toolbar.subviews.first { $0.accessibilityIdentifier == "keyboard.status" } as? UILabel)
        #expect(!status.isHidden && status.text?.contains("Shortcut unavailable") == true)
        try tap("key.q")
        #expect(document.text == "letq value = 1" && status.isHidden)
    }

    @Test func tabletopUsesOnlyTheLowerHorizontalPanel() {
        let screen = CGRect(x: 0, y: 0, width: 951, height: 669)
        #expect(KeyboardGeometry.tabletopHeight(in: screen, divisions: [CGRect(x: 0, y: 314, width: 951, height: 40)]) == 315)
        #expect(KeyboardGeometry.tabletopHeight(in: screen, divisions: [CGRect(x: 455, y: 0, width: 40, height: 669)]) == nil)
        #expect(KeyboardGeometry.tabletopHeight(in: screen, divisions: []) == nil)
        #expect(KeyboardGeometry.tabletopHeight(in: CGRect(x: 0, y: 0, width: 400, height: 600), divisions: [CGRect(x: 0, y: 280, width: 400, height: 40)]) == nil)
    }

    @Test(arguments: [650.0, 669, 768, 951, 1024, 1366], CompatibilityMode.allCases)
    func fullKeyboardRowFitsAndRetainsEditingKeys(_ width: Double, _ profile: CompatibilityMode) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.showNavigationRow = true
        preferences.settings.compatibility = profile
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        keyboard.frame = CGRect(x: 0, y: 0, width: width, height: 440)
        keyboard.layoutIfNeeded()
        keyboard.frame.size.height = keyboard.desiredHeight
        keyboard.layoutIfNeeded()
        for title in ["Esc", "Home", "End", "Tab", "Outdent", "Indent", "{", "}", "[", "]"] {
            let key = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "key.\(title)" })
            #expect(!key.isHidden && keyboard.bounds.contains(key.frame))
            #expect(key.frame.height >= 44 && key.frame.width >= 24)
        }
        #expect(keyboard.subviews.contains { $0.accessibilityIdentifier == "key.Up" } == (profile == .terminal))
        let line = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "key.Delete line" } as? UIButton)
        #expect(line.isEnabled == (profile != .remoteDesktop))
    }

    @Test func transientCleanupPreservesTypingAndAllowsReopening() async throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument(text: "let ")
        weak var released: CodingKeyboardView?
        autoreleasepool {
            let keyboard = CodingKeyboardView(document: document, preferences: preferences)
            released = keyboard
            keyboard.showStatus("Temporary")
            keyboard.releaseTransientResources()
            keyboard.applySettings()
            keyboard.engine.type("value")
            keyboard.refreshContext()
            #expect(document.text == "let value")
            #expect(preferences.settings.theme == .standard)
        }
        // UIKit defers some control cleanup until the main run loop drains.
        try await Task.sleep(for: .milliseconds(100))
        #expect(released == nil)
    }

    @Test func foldAndCameraRegionsLeaveOnlyUsableSegments() {
        let row = CGRect(x: 10, y: 50, width: 800, height: 44)
        let fold = CGRect(x: 390, y: 0, width: 40, height: 900)
        let camera = CGRect(x: 760, y: 60, width: 50, height: 30)
        let segments = KeyboardGeometry.horizontalSegments(in: row, excluding: [fold, camera])
        #expect(segments == [CGRect(x: 10, y: 50, width: 380, height: 44), CGRect(x: 430, y: 50, width: 330, height: 44)])
        #expect(segments.allSatisfy { !$0.intersects(fold) && !$0.intersects(camera) })
        #expect(KeyboardGeometry.horizontalSegments(in: row, excluding: []) == [row])
    }

    @Test(arguments: KeyboardTheme.allCases, [UIUserInterfaceStyle.light, .dark])
    func paletteTextHasReadableContrast(_ theme: KeyboardTheme, _ style: UIUserInterfaceStyle) {
        let palette = KeyboardPalette.resolve(theme)
        let traits = UITraitCollection(userInterfaceStyle: style)
        for (foreground, background) in [
            (palette.text, palette.key), (palette.text, palette.utility),
            (palette.secondary, palette.key), (palette.accent, palette.key),
            (palette.accent, palette.background)
        ] {
            #expect(contrast(foreground, background, traits: traits) >= 4.5)
        }
    }

    @Test(arguments: KeyboardTheme.allCases)
    func liveThemeChangesKeepInputAndSettings(_ theme: KeyboardTheme) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument(text: "keep this", cursor: 4)
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        preferences.settings.theme = theme
        keyboard.applySettings()
        keyboard.layoutIfNeeded()
        #expect(document.text == "keep this")
        #expect(document.cursor == 4)
        #expect(keyboard.overrideUserInterfaceStyle == (theme.usesDarkPalette ? .dark : .unspecified))
        #expect(keyboard.backgroundColor?.resolvedColor(with: keyboard.traitCollection)
                == KeyboardPalette.resolve(theme).background.resolvedColor(with: keyboard.traitCollection))
        let restored = PreferencesStore(local: try #require(UserDefaults(suiteName: suite)))
        #expect(restored.settings.theme == theme)
        preferences.settings.theme = .standard
        preferences.settings.appearance = .light
        keyboard.applySettings()
        #expect(keyboard.overrideUserInterfaceStyle == .light)
        preferences.settings.appearance = .system
        keyboard.applySettings()
        #expect(keyboard.overrideUserInterfaceStyle == .unspecified)
    }

    @Test(arguments: [320.0, 375, 390, 440, 550, 630, 768, 834, 1024, 1366], KeySize.allCases)
    func rowsFitPhoneDuoAndIPadWidths(_ width: Double, _ keySize: KeySize) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.keySize = keySize
        preferences.settings.showNumberRow = true
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        keyboard.frame = CGRect(x: 0, y: 0, width: width, height: keyboard.desiredHeight)
        keyboard.layoutIfNeeded()
        keyboard.frame.size.height = keyboard.desiredHeight
        keyboard.layoutIfNeeded()
        let keys = keyboard.subviews.filter { $0.accessibilityIdentifier?.hasPrefix("key.") == true }
        #expect(!keys.isEmpty)
        for key in keys where !key.isHidden {
            #expect(key.frame.width >= 20)
            #expect(key.frame.height >= 44)
            #expect(key.frame.minX >= 0 && key.frame.maxX <= keyboard.bounds.width)
            #expect(key.frame.minY >= 44 && key.frame.maxY <= keyboard.bounds.height)
            #expect(!keys.contains { $0 !== key && !$0.isHidden && $0.frame.intersects(key.frame) })
        }
    }

    private func store() throws -> (PreferencesStore, String) {
        let suite = "TabForge.ThemeTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (PreferencesStore(local: defaults), suite)
    }

    private func contrast(_ foreground: UIColor, _ background: UIColor, traits: UITraitCollection) -> Double {
        func luminance(_ color: UIColor) -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ channel: CGFloat) -> Double {
                let value = Double(channel)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
