import UIKit
import Testing
import KeyboardCore
@testable import ScriptKeyboard

@Suite @MainActor
struct KeyboardCompactLayoutTests {
    @Test(arguments: [
        CGSize(width: 568, height: 320), CGSize(width: 667, height: 375),
        CGSize(width: 852, height: 393), CGSize(width: 956, height: 440),
        CGSize(width: 951, height: 440), CGSize(width: 650, height: 500),
        CGSize(width: 1024, height: 440), CGSize(width: 1366, height: 375)
    ])
    func shortHostsRetainFourUsableTypingRows(_ host: CGSize) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        // These regular-height preferences must not grow a short host keyboard.
        preferences.settings.showNumberRow = true
        preferences.settings.showNavigationRow = true
        preferences.settings.keySize = .comfortable
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        layout(keyboard, in: host)

        #expect(keyboard.isCompactHeight)
        #expect(abs(keyboard.desiredHeight - 200) < 0.5)
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        #expect(toolbar.isHidden)
        try assertFourRowsFit(keyboard)
        for name in ["q", "a", "z", "Tab", "Return", "Fn"] {
            _ = try button(name, in: keyboard)
        }
        #expect(!visibleKeys(in: keyboard).contains { ["key.1", "key.{", "key.Outdent"].contains($0.accessibilityIdentifier ?? "") })
    }

    @Test(arguments: [
        CGSize(width: 390, height: 844), CGSize(width: 669, height: 951),
        CGSize(width: 951, height: 669), CGSize(width: 768, height: 1024)
    ])
    func roomyHostKeepsFullHeightRequestWhenItsBoundsAreTemporarilyClipped(_ host: CGSize) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        keyboard.availableHostSize = host
        keyboard.frame = CGRect(x: 0, y: 0, width: host.width, height: 200)
        keyboard.layoutIfNeeded()
        #expect(keyboard.isCompactHeight)
        #expect(keyboard.desiredHeight > 200)
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        #expect(toolbar.isHidden)
        let requestedHeight = keyboard.desiredHeight
        keyboard.frame.size.height = requestedHeight
        keyboard.layoutIfNeeded()
        #expect(!keyboard.isCompactHeight)
        #expect(keyboard.desiredHeight == requestedHeight)
        #expect(!toolbar.isHidden)
    }

    @Test(arguments: [160.0, 180, 200])
    func forcedShortBoundsKeepBothLayersInsideTheirHost(_ height: Double) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .full
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        keyboard.availableHostSize = CGSize(width: 320, height: 844)
        keyboard.frame = CGRect(x: 0, y: 0, width: 320, height: height)
        keyboard.layoutIfNeeded()
        #expect(keyboard.isCompactHeight)
        #expect(keyboard.desiredHeight > 200)
        for _ in 0..<2 {
            let keys = visibleKeys(in: keyboard)
            #expect(Set(keys.map { Int(($0.frame.midY * 10).rounded()) }).count == 4)
            for key in keys {
                #expect(key.frame.height >= 28 && key.frame.width >= 20)
                #expect(keyboard.bounds.contains(key.frame))
                #expect(!keys.contains { $0 !== key && $0.frame.intersects(key.frame) })
            }
            try tap("Fn", in: keyboard)
            keyboard.layoutIfNeeded()
        }
    }

    @Test func resizingAndUserOverridesUpdateHeightWithoutLosingText() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument(text: "keep this")
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 834, height: 1194))
        #expect(!keyboard.isCompactHeight)
        layout(keyboard, in: CGSize(width: 834, height: 440))
        #expect(keyboard.isCompactHeight)
        #expect(abs(keyboard.desiredHeight - 200) < 0.5)
        layout(keyboard, in: CGSize(width: 834, height: 1194))
        #expect(!keyboard.isCompactHeight)

        preferences.settings.heightMode = .compact
        keyboard.applySettings()
        layout(keyboard, in: CGSize(width: 834, height: 1194))
        #expect(keyboard.isCompactHeight)
        #expect(abs(keyboard.desiredHeight - 200) < 0.5)
        preferences.settings.heightMode = .full
        keyboard.applySettings()
        layout(keyboard, in: CGSize(width: 834, height: 375))
        #expect(!keyboard.isCompactHeight)
        #expect(keyboard.desiredHeight > 200)
        #expect(document.text == "keep this")
    }

    @Test func functionLayerExposesEditingControlsAtTheSameHeight() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .compact
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 667, height: 375))
        let initialHeight = keyboard.desiredHeight
        try tap("Fn", in: keyboard)
        keyboard.layoutIfNeeded()
        #expect(keyboard.desiredHeight == initialHeight)
        try assertFourRowsFit(keyboard)
        for name in ["Ctrl", "Option", "Command", "Left", "Down", "Up", "Right", "Outdent", "Indent", "Delete line", "{", "}", "[", "]", "<", ">", "(", ")", "Esc", "Settings"] {
            let key = try button(name, in: keyboard)
            #expect(key.isAccessibilityElement)
            #expect(key.accessibilityLabel?.isEmpty == false)
            #expect(key.accessibilityTraits.contains(.keyboardKey))
        }
        #expect(!visibleKeys(in: keyboard).contains { $0.accessibilityIdentifier == "key.Tools" })
        let settings = try button("Settings", in: keyboard)
        #expect(settings.showsMenuAsPrimaryAction)
        #expect(settings.menu?.children.contains { $0.title == "Editing actions" } == true)
        #expect(settings.menu?.children.contains { $0.title == "Snippets" } == true)
        let functionKey = try button("Fn", in: keyboard)
        #expect(functionKey.accessibilityTraits.contains(.selected))
        #expect(functionKey.accessibilityValue?.isEmpty == false)
        try tap("Fn", in: keyboard)
        keyboard.layoutIfNeeded()
        #expect(keyboard.desiredHeight == initialHeight)
        try tap("q", in: keyboard)
        #expect(document.text == "q")
        let restoredFunctionKey = try button("Fn", in: keyboard)
        #expect(!restoredFunctionKey.accessibilityTraits.contains(.selected))
    }

    @Test func terminalControlLatchSurvivesReturningFromFunctionLayer() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .compact
        preferences.settings.compatibility = .terminal
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 852, height: 393))
        try tap("Fn", in: keyboard)
        let control = try button("Ctrl", in: keyboard)
        control.sendActions(for: .touchDown)
        control.sendActions(for: .touchUpInside)
        #expect(control.isSelected)
        #expect(control.accessibilityTraits.contains(.selected))
        #expect(control.accessibilityValue?.isEmpty == false)
        try tap("Fn", in: keyboard)
        try tap("c", in: keyboard)
        #expect(document.text == "\u{03}")
        try tap("c", in: keyboard)
        #expect(document.text == "\u{03}c")
        try tap("Fn", in: keyboard)
        let restoredControl = try button("Ctrl", in: keyboard)
        #expect(!restoredControl.isSelected)
    }

    @Test func functionPageWaitsForOverlappingLetterPressToFinish() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .compact
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 667, height: 375))
        let q = try button("q", in: keyboard)
        q.sendActions(for: .touchDown)
        try tap("Fn", in: keyboard)
        #expect(q.superview === keyboard)
        q.sendActions(for: .touchUpInside)
        #expect(document.text == "q")
        #expect(q.superview == nil)
        _ = try button("Settings", in: keyboard)
        #expect(abs(keyboard.desiredHeight - 200) < 0.5)
    }

    @Test func shiftAccessibilityActivationWorksAfterAHeldChordAndCapsLockHasAnAction() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .compact
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 667, height: 375))
        let shift = try button("Shift", in: keyboard)
        #expect(shift.accessibilityValue == "Off")
        #expect(!shift.accessibilityTraits.contains(.selected))
        shift.sendActions(for: .touchDown)
        #expect(shift.accessibilityValue == "On for next key")
        let q = try button("q", in: keyboard)
        q.sendActions(for: .touchDown)
        q.sendActions(for: .touchUpInside)
        shift.sendActions(for: .touchUpInside)
        #expect(document.text == "Q")
        let releasedShift = try button("Shift", in: keyboard)
        #expect(releasedShift.accessibilityValue == "Off")
        // Assistive activation can arrive without a physical touch-down event.
        releasedShift.sendActions(for: .touchUpInside)
        let activatedShift = try button("Shift", in: keyboard)
        #expect(activatedShift.accessibilityTraits.contains(.selected))
        #expect(activatedShift.accessibilityValue == "On for next key")
        let capsAction = try #require(activatedShift.accessibilityCustomActions?.first { $0.name == "Turn Caps Lock on" })
        let handler = try #require(capsAction.actionHandler)
        #expect(handler(capsAction))
        let capsKey = try button("Caps lock", in: keyboard)
        #expect(capsKey.accessibilityValue == "Caps lock")
        #expect(capsKey.accessibilityTraits.contains(.selected))
        #expect(capsKey.accessibilityCustomActions?.contains { $0.name == "Turn Caps Lock off" } == true)
    }

    @Test func previewsStayOutOfAccessibilityAndFocusFramesMatchExpandedHitAreas() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .compact
        preferences.settings.keyPreviews = true
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        layout(keyboard, in: CGSize(width: 667, height: 375))
        let q = try button("q", in: keyboard)
        #expect(q.accessibilityFrame.width >= q.frame.width)
        #expect(q.accessibilityFrame.height >= q.frame.height)
        let gapPoint = CGPoint(x: q.frame.midX, y: q.frame.maxY + 1)
        #expect(keyboard.hitTest(gapPoint, with: nil) === q)
        #expect(q.point(inside: q.convert(gapPoint, from: keyboard), with: nil))
        q.sendActions(for: .touchDown)
        let preview = try #require(keyboard.subviews.compactMap { $0 as? UILabel }.first { $0.accessibilityElementsHidden })
        #expect(!preview.isAccessibilityElement && !preview.isUserInteractionEnabled)
        #expect(keyboard.accessibilityElements?.contains { ($0 as AnyObject) === preview } == false)
        #expect(q.subviews.allSatisfy { !$0.isAccessibilityElement })
        q.sendActions(for: .touchCancel)
        #expect(preview.superview == nil)
    }

    @Test func boldTextAndLargerTextUpdateExistingKeyLabels() async throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .compact
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        layout(keyboard, in: CGSize(width: 667, height: 375))
        keyboard.traitOverrides.legibilityWeight = .regular
        keyboard.traitOverrides.preferredContentSizeCategory = .large
        keyboard.updateTraitsIfNeeded()
        await Task.yield()
        let q = try button("q", in: keyboard)
        let legend = try #require(q.subviews.compactMap { $0 as? UILabel }.first { $0.text == "q" })
        let regularFont = try #require(legend.font)
        keyboard.traitOverrides.legibilityWeight = .bold
        keyboard.updateTraitsIfNeeded()
        await Task.yield()
        #expect(legend.font.fontName != regularFont.fontName)
        #expect(legend.font.fontDescriptor.symbolicTraits.contains(.traitBold))
        keyboard.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        keyboard.updateTraitsIfNeeded()
        await Task.yield()
        #expect(legend.font.pointSize > regularFont.pointSize)
        #expect(abs(keyboard.desiredHeight - 200) < 0.5)
        try assertFourRowsFit(keyboard)
    }

    @Test(arguments: KeyboardTheme.allCases)
    func selectedModifierLabelKeepsReadableContrast(_ theme: KeyboardTheme) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.heightMode = .compact
        preferences.settings.theme = theme
        let keyboard = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        layout(keyboard, in: CGSize(width: 667, height: 375))
        try tap("Fn", in: keyboard)
        try tap("Ctrl", in: keyboard)
        let control = try button("Ctrl", in: keyboard)
        let legend = try #require(control.subviews.compactMap { $0 as? UILabel }.first { $0.text == "Ctrl" })
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: theme.usesDarkPalette ? .dark : style)
            let background = try #require(control.backgroundColor)
            let underlying = try #require(keyboard.backgroundColor)
            let foreground = try #require(legend.textColor)
            #expect(contrast(foreground, over: background, backing: underlying, traits: traits) >= 4.5)
        }
    }

    @Test func wideButShortHostsSkipTheAutomaticNumberRow() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let short = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        // A closed Duo's outer display: wide enough for the wide-phone layout.
        layout(short, in: CGSize(width: 466, height: 678))
        #expect(!short.isCompactHeight)
        #expect(!visibleKeys(in: short).contains { $0.accessibilityIdentifier == "key.1" })
        #expect(try button("q", in: short).subviews.compactMap { ($0 as? UILabel)?.text }.contains("1"))
        let tall = CodingKeyboardView(document: MemoryDocument(), preferences: preferences)
        layout(tall, in: CGSize(width: 466, height: 1000))
        _ = try button("1", in: tall)
        #expect(try !button("q", in: tall).subviews.compactMap { ($0 as? UILabel)?.text }.contains("1"))
        #expect(tall.desiredHeight > short.desiredHeight)
        let shortRow = try button("q", in: short).frame.height
        let tallRow = try button("q", in: tall).frame.height
        #expect(shortRow >= 40 && shortRow < tallRow)
    }

    @Test func holdingATopRowLetterTypesItsHintedDigit() async throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.haptics = false
        preferences.settings.keyClicks = false
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 390, height: 844))
        let q = try button("q", in: keyboard)
        q.sendActions(for: .touchDown)
        try await Task.sleep(for: .milliseconds(700))
        #expect(keyboard.subviews.contains { $0.accessibilityIdentifier == "keyboard.alternates" })
        q.sendActions(for: .touchUpInside)
        #expect(document.text == "1")
        #expect(!keyboard.subviews.contains { $0.accessibilityIdentifier == "keyboard.alternates" })
        try tap("q", in: keyboard)
        #expect(document.text == "1q")
        #expect(q.accessibilityCustomActions?.map(\.name) == ["Type 1"])
    }

    @Test func compactSymbolRowHasAnOperatorPage() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 375, height: 667))
        #expect(!keyboard.isCompactHeight)
        _ = try button("{", in: keyboard)
        try tap("symbolPage", in: keyboard)
        keyboard.layoutIfNeeded()
        for name in ["=", "\"", "'", ";", ":", "/", "-", "_"] { _ = try button(name, in: keyboard) }
        #expect(!visibleKeys(in: keyboard).contains { $0.accessibilityIdentifier == "key.{" })
        let equals = try button("=", in: keyboard)
        let row = visibleKeys(in: keyboard).filter { abs($0.frame.midY - equals.frame.midY) < 1 }
        #expect(row.count == 11)
        #expect(row.allSatisfy { $0.frame.width >= 24 })
        try tap(";", in: keyboard)
        #expect(document.text == ";")
        try tap("symbolPage", in: keyboard)
        _ = try button("{", in: keyboard)
    }

    @Test func sentenceCapitalsAndDoubleSpacePeriodFollowTheHost() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument()
        document.capitalizesSentences = true
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 390, height: 844))
        keyboard.hostContextDidChange()
        try tap("H", in: keyboard)
        try tap("i", in: keyboard)
        try tap("space", in: keyboard)
        try tap("space", in: keyboard)
        #expect(document.text == "Hi. ")
        try tap("O", in: keyboard)
        #expect(document.text == "Hi. O")

        let (codePreferences, codeSuite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: codeSuite) }
        let code = MemoryDocument()
        let literal = CodingKeyboardView(document: code, preferences: codePreferences)
        layout(literal, in: CGSize(width: 390, height: 844))
        literal.hostContextDidChange()
        try tap("h", in: literal)
        try tap("space", in: literal)
        try tap("space", in: literal)
        #expect(code.text == "h  ")
    }

    @Test func returnKeyShowsTheHostTitle() throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        let document = MemoryDocument()
        document.returnKeyLabel = "Send"
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: 390, height: 844))
        let send = try button("Return", in: keyboard)
        #expect(send.accessibilityLabel == "Send")
        document.returnKeyLabel = nil
        keyboard.refreshContext()
        #expect(try button("Return", in: keyboard).accessibilityLabel == "Return")
    }

    @Test(arguments: [375.0, 440, 1024])
    func chosenToolbarKeysAppearInOrder(_ width: Double) throws {
        let (preferences, suite) = try store()
        defer { UserDefaults.standard.removePersistentDomain(forName: suite) }
        preferences.settings.toolbarKeys = [.escape, .tab, .control, .pipe, .left, .right]
        let document = MemoryDocument()
        let keyboard = CodingKeyboardView(document: document, preferences: preferences)
        layout(keyboard, in: CGSize(width: width, height: 1000))
        let toolbar = try #require(keyboard.subviews.first { $0.accessibilityIdentifier == "keyboard.toolbar" })
        let controls = toolbar.subviews.compactMap { $0 as? UIButton }.filter { !$0.isHidden }.sorted { $0.frame.minX < $1.frame.minX }
        #expect(controls.map(\.accessibilityIdentifier) == ["keyboard.escape", "keyboard.toolbar.tab", "keyboard.modifier.control",
            "keyboard.toolbar.pipe", "keyboard.arrow.left", "keyboard.arrow.right", "keyboard.quickSettings"])
        let pipe = try #require(controls.first { $0.accessibilityIdentifier == "keyboard.toolbar.pipe" })
        pipe.sendActions(for: .touchDown); pipe.sendActions(for: .touchUpInside)
        #expect(document.text == "|")
    }

    private func store() throws -> (PreferencesStore, String) {
        let suite = "TabForge.CompactLayoutTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (PreferencesStore(local: defaults), suite)
    }

    private func layout(_ keyboard: CodingKeyboardView, in host: CGSize) {
        keyboard.availableHostSize = host
        keyboard.frame = CGRect(x: 0, y: 0, width: host.width, height: keyboard.desiredHeight)
        keyboard.layoutIfNeeded()
        keyboard.frame.size.height = keyboard.desiredHeight
        keyboard.layoutIfNeeded()
    }

    private func visibleKeys(in keyboard: CodingKeyboardView) -> [UIButton] {
        keyboard.subviews.compactMap { $0 as? UIButton }
            .filter { !$0.isHidden && $0.accessibilityIdentifier?.hasPrefix("key.") == true }
    }

    private func button(_ name: String, in keyboard: CodingKeyboardView) throws -> UIButton {
        try #require(visibleKeys(in: keyboard).first { $0.accessibilityIdentifier == "key.\(name)" })
    }

    private func tap(_ name: String, in keyboard: CodingKeyboardView) throws {
        let key = try button(name, in: keyboard)
        key.sendActions(for: .touchDown)
        key.sendActions(for: .touchUpInside)
    }

    private func assertFourRowsFit(_ keyboard: CodingKeyboardView) throws {
        let keys = visibleKeys(in: keyboard)
        #expect(!keys.isEmpty)
        #expect(Set(keys.map { Int(($0.frame.midY * 10).rounded()) }).count == 4)
        for key in keys {
            #expect(key.frame.height >= 44)
            #expect(key.frame.width >= 20)
            #expect(keyboard.bounds.contains(key.frame))
            #expect(!keys.contains { $0 !== key && $0.frame.intersects(key.frame) })
            #expect(!key.isExclusiveTouch)
        }
    }

    private func contrast(_ text: UIColor, over fill: UIColor, backing: UIColor, traits: UITraitCollection) -> Double {
        func components(_ color: UIColor) -> (Double, Double, Double, Double) {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b), Double(a))
        }
        let fg = components(text), bg = components(fill), base = components(backing)
        func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
            func linear(_ value: Double) -> Double { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let first = luminance(fg.0, fg.1, fg.2)
        let second = luminance(bg.0 * bg.3 + base.0 * (1 - bg.3), bg.1 * bg.3 + base.1 * (1 - bg.3), bg.2 * bg.3 + base.2 * (1 - bg.3))
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
