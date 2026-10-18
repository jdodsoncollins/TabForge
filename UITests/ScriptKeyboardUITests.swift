import XCTest

@MainActor
final class ScriptKeyboardUITests: XCTestCase {
    func testGapTapsAndCancelledKeyDrags() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let editor = app.textViews["playground.editor"]
        let q = app.descendants(matching: .any)["key.q"].firstMatch
        XCTAssertTrue(q.waitForExistence(timeout: 10))
        let initial = editor.value as? String ?? ""
        // The accessibility frame includes the expanded hit region. Its last
        // point lies beyond the visible key cap, inside this key’s half-gap.
        q.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -1, dy: 0)).tap()
        XCTAssertEqual(editor.value as? String, initial + "q")
        let start = q.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let outside = q.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -3))
        start.press(forDuration: 0.1, thenDragTo: outside)
        XCTAssertEqual(editor.value as? String, initial + "q")
    }

    func testNavigationToolbarAndMergedToolsSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let editor = app.textViews["playground.editor"]
        let command = app.buttons["keyboard.modifier.command"]
        XCTAssertTrue(command.waitForExistence(timeout: 10))
        for id in ["arrow.left", "arrow.down", "arrow.up", "arrow.right", "modifier.control", "modifier.option", "modifier.command", "escape"] {
            XCTAssertTrue(app.buttons["keyboard." + id].isHittable, id)
        }
        let initial = editor.value as? String ?? ""
        app.descendants(matching: .any)["key.q"].firstMatch.tap()
        command.tap()
        XCTAssertEqual(command.value as? String, "On for next key")
        app.buttons["keyboard.arrow.left"].tap()
        XCTAssertEqual(command.value as? String, "Off")
        app.descendants(matching: .any)["key.w"].firstMatch.tap()
        XCTAssertEqual(editor.value as? String, initial + "wq")
        XCTAssertFalse(app.buttons["keyboard.editingTools"].exists)
        app.buttons["keyboard.quickSettings"].tap()
        XCTAssertTrue(app.buttons["Editing actions"].waitForExistence(timeout: 5))
        app.buttons["Editing actions"].tap()
        XCTAssertTrue(app.buttons["Reindent selection"].waitForExistence(timeout: 5))
        // Dismiss the menu without selecting an editing operation, then confirm
        // that language settings are reachable from the same gear control.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
        app.buttons["keyboard.quickSettings"].tap()
        let language = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Language · ")).firstMatch
        XCTAssertTrue(language.waitForExistence(timeout: 5))
        language.tap()
        app.buttons["Python"].tap()
        XCTAssertTrue(app.staticTexts["playground.py"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Navigation-toolbar"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExtraEditingRowOnWideLayout() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let surface = app.otherElements["keyboard.surface"]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        guard surface.frame.width >= 650 else { throw XCTSkip("Requires a wide keyboard viewport.") }
        app.buttons["keyboard.quickSettings"].tap()
        app.buttons["Layout & keys"].tap()
        app.buttons["Extra editing row on wide layouts"].tap()
        let escape = app.descendants(matching: .any)["key.Esc"].firstMatch
        XCTAssertTrue(escape.waitForExistence(timeout: 5))
        for title in ["Esc", "Home", "End", "Tab", "Return", "Outdent", "Indent", "{"] {
            XCTAssertTrue(app.descendants(matching: .any)["key.\(title)"].firstMatch.isHittable)
        }
        app.descendants(matching: .any)["key.q"].firstMatch.tap()
        XCTAssertTrue((app.textViews["playground.editor"].value as? String)?.hasSuffix("q") == true)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Full-editing-keyboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDuoTabletopLowerPanel() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["TABFORGE_TABLETOP"] == "1" else {
            throw XCTSkip("Run with TABFORGE_TABLETOP=1 on a partially open Duo.")
        }
        // Device Hub controls the physical fold axis. An XCTest orientation
        // request can rotate content without changing the simulated hinge.
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard", "--layout-diagnostics"]
        app.launch()
        let surface = app.otherElements["keyboard.surface"]
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        guard (surface.value as? String)?.contains("horizontalDivision=true") == true else {
            throw XCTSkip("The simulator still reports a vertical book fold. Set a horizontal fold in Device Hub before running this pose check.")
        }
        let escape = app.descendants(matching: .any)["key.Esc"].firstMatch
        XCTAssertTrue(escape.waitForExistence(timeout: 10), surface.value as? String ?? "No surface")
        XCTAssertTrue(escape.isHittable)
        XCTAssertTrue((surface.value as? String)?.hasPrefix("Tabletop") == true)
        XCTAssertGreaterThan(surface.frame.minY, app.frame.height * 0.4)
        XCTAssertGreaterThan(surface.frame.height, app.frame.height * 0.3)
        let q = app.descendants(matching: .any)["key.q"].firstMatch
        q.tap()
        XCTAssertTrue((app.textViews["playground.editor"].value as? String)?.hasSuffix("q") == true)
        for title in ["Home", "End", "Tab", "Return", "Outdent", "Indent"] {
            XCTAssertTrue(app.descendants(matching: .any)["key.\(title)"].firstMatch.isHittable)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Duo-tabletop"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOptInSwipeTypesACodeWord() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let editor = app.textViews["playground.editor"]
        let a = app.descendants(matching: .any)["key.a"].firstMatch
        let s = app.descendants(matching: .any)["key.s"].firstMatch
        XCTAssertTrue(a.waitForExistence(timeout: 10))
        let initial = editor.value as? String ?? ""
        app.buttons["keyboard.quickSettings"].tap()
        app.buttons["Editing preferences"].tap()
        app.buttons["Swipe code words · beta"].tap()
        a.press(forDuration: 0.05, thenDragTo: s)
        XCTAssertEqual(editor.value as? String, initial + "as")
    }

    func testThemeSettingsPreviewAndSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let gear = app.buttons["keyboard.quickSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        app.buttons["Keyboard theme"].tap()
        app.buttons["Darcula"].tap()
        let q = app.descendants(matching: .any)["key.q"].firstMatch
        XCTAssertTrue(q.waitForExistence(timeout: 5))
        q.tap()
        XCTAssertTrue((app.textViews["playground.editor"].value as? String)?.hasSuffix("q") == true)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Keyboard-theme-preview"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLargestAccessibilityTextKeepsSettingsThemesAndLayoutGuideUsable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let gear = app.buttons["keyboard.quickSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        tapMenuOption("Keyboard theme", app: app)
        tapMenuOption("Darcula", app: app)
        gear.tap()
        tapMenuOption("Keyboard height", app: app)
        tapMenuOption("Compact", app: app)
        XCTAssertTrue(app.descendants(matching: .any)["key.Fn"].firstMatch.waitForExistence(timeout: 5))
        app.open(URL(string: "tabforge://settings")!)
        XCTAssertTrue(app.staticTexts["Configure TabForge from the keyboard."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["settings.keyboardTheme"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.heightMode"].exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Largest-text-companion-help"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAllThemesAndLandscapeTyping() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let key = app.descendants(matching: .any)["key.q"].firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 10))
        for theme in ["Darcula", "Dracula", "Nord", "iOS Standard"] {
            app.buttons["keyboard.quickSettings"].tap()
            app.buttons["Keyboard theme"].tap()
            app.buttons[theme].tap()
            XCTAssertTrue(key.waitForExistence(timeout: 5))
            key.tap()
            XCTAssertTrue((app.textViews["playground.editor"].value as? String)?.hasSuffix("q") == true)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Theme-\(theme)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(key.waitForExistence(timeout: 5))
        let enter = app.descendants(matching: .any)["key.Return"].firstMatch
        let tab = app.descendants(matching: .any)["key.Tab"].firstMatch
        XCTAssertTrue(enter.waitForExistence(timeout: 5))
        XCTAssertTrue(enter.isHittable)
        XCTAssertTrue(tab.isHittable)
        key.tap()
        XCTAssertTrue((app.textViews["playground.editor"].value as? String)?.hasSuffix("qqqqq") == true)
        enter.tap()
        XCTAssertTrue((app.textViews["playground.editor"].value as? String)?.hasSuffix("qqqqq\n") == true)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Landscape-keyboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCompactLandscapePreservesTypingFunctionToolsAndSettings() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard", "--layout-diagnostics"]
        app.launch()
        let key: (String) -> XCUIElement = { app.descendants(matching: .any)["key.\($0)"].firstMatch }
        XCTAssertTrue(key("q").waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        if min(app.frame.width, app.frame.height) < 650 {
            let landscape = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.frame.width > app.frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [landscape], timeout: 5), .completed)
        }
        // Duo's physical pose is controlled in Device Hub. A large window can
        // retain its geometry despite an XCTest orientation request; exercise
        // its explicit Compact override here and its fold in the pose test.

        // A short landscape phone must compact automatically. Larger iPad and
        // open-Duo windows retain their full layout until explicitly requested.
        if app.frame.height > 500 {
            app.buttons["keyboard.quickSettings"].tap()
            app.buttons["Keyboard height"].tap()
            app.buttons["Compact"].tap()
        }
        let function = key("Fn")
        XCTAssertTrue(function.waitForExistence(timeout: 5))
        let surface = app.otherElements["keyboard.surface"]
        XCTAssertFalse(app.otherElements["keyboard.toolbar"].isHittable)
        let height = surface.frame.height
        XCTAssertGreaterThanOrEqual(height, 170)
        XCTAssertLessThanOrEqual(height, 260, surface.value as? String ?? "") // Allows the host's bottom safe area.
        let rowOrigins = ["q", "a", "z", "space"].map { key($0).frame.minY.rounded() }
        XCTAssertEqual(Set(rowOrigins).count, 4)
        for title in ["q", "Tab", "Return", "Fn"] { XCTAssertTrue(key(title).isHittable, title) }
        let editor = app.textViews["playground.editor"]
        let initial = editor.value as? String ?? ""
        key("q").tap()
        key("Return").tap()
        key("Tab").tap()
        XCTAssertEqual(editor.value as? String, initial + "q\n    ")

        function.tap()
        let settings = key("Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        XCTAssertEqual(surface.frame.height, height, accuracy: 1)
        settings.tap()
        XCTAssertTrue(app.buttons["Keyboard height"].waitForExistence(timeout: 5))
        app.buttons["Keyboard height"].tap()
        XCTAssertTrue(app.buttons["Automatic"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Compact"].exists)
        app.buttons["Compact"].tap()
        XCTAssertEqual(surface.frame.height, height, accuracy: 1)
        if !key("q").isHittable { function.tap() }
        XCTAssertTrue(key("q").waitForExistence(timeout: 5))
        key("q").tap()
        XCTAssertEqual(editor.value as? String, initial + "q\n    q")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Compact-landscape-keyboard"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPlaygroundPairsAndQuickSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let editor = app.textViews["playground.editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10))
        let initial = editor.value as? String ?? ""
        let brace = app.descendants(matching: .any)["key.{"]
        XCTAssertTrue(brace.waitForExistence(timeout: 10))
        brace.tap()
        XCTAssertEqual(editor.value as? String, initial + "{}")
        app.buttons["keyboard.quickSettings"].tap()
        XCTAssertTrue(app.buttons["Editing preferences"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Open app settings"].exists)
        XCTAssertFalse(app.buttons["App settings help"].exists)
        app.buttons["Editing preferences"].tap()
        XCTAssertTrue(app.buttons["Pair brackets & quotes"].waitForExistence(timeout: 5))
        app.buttons["Pair brackets & quotes"].tap()
        brace.tap()
        XCTAssertEqual(editor.value as? String, initial + "{{}")
    }

    func testSettingsAndDeepLink() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.open(URL(string: "tabforge://settings")!)
        XCTAssertTrue(app.staticTexts["Configure TabForge from the keyboard."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.switches["Pair brackets and quotes"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.compatibility"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["settings.keyboardTheme"].exists)
        XCTAssertFalse(app.buttons["Reset keyboard preferences"].exists)
    }

    func testLocalSnippetEditorSavesSeparatelyFromInsertion() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let editor = app.textViews["playground.editor"]
        XCTAssertTrue(app.buttons["keyboard.quickSettings"].waitForExistence(timeout: 10))
        let initial = editor.value as? String ?? ""
        app.buttons["keyboard.quickSettings"].tap()
        app.buttons["Snippets"].tap()
        app.buttons["Manage snippets"].tap()
        app.buttons["Add snippet"].tap()
        let key: (String) -> XCUIElement = { app.descendants(matching: .any)["key.\($0)"].firstMatch }
        XCTAssertTrue(app.segmentedControls["snippet.field"].waitForExistence(timeout: 5))
        key("q").tap()
        app.segmentedControls["snippet.field"].buttons["Text"].tap()
        key("w").tap()
        key("Return").tap()
        key("e").tap()
        XCTAssertEqual(editor.value as? String, initial)
        let draft = XCTAttachment(screenshot: app.screenshot())
        draft.name = "Keyboard-local-snippet-editor"
        draft.lifetime = .keepAlways
        add(draft)
        app.buttons["snippet.save"].tap()
        XCTAssertFalse(app.segmentedControls["snippet.field"].exists)
        XCTAssertEqual(editor.value as? String, initial)
        app.buttons["keyboard.quickSettings"].tap()
        app.buttons["Snippets"].tap()
        app.collectionViews.buttons["q"].firstMatch.tap()
        XCTAssertEqual(editor.value as? String, initial + "w\ne")
    }

    func testAttributionsAndOtherAppsNavigation() {
        checkAttributionsAndOtherApps(accessibilityText: false)
    }

    func testAttributionsAndOtherAppsAtLargestText() {
        checkAttributionsAndOtherApps(accessibilityText: true)
    }

    private func checkAttributionsAndOtherApps(accessibilityText: Bool) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        if accessibilityText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        app.open(URL(string: "tabforge://settings")!)
        let scroller = app.collectionViews.firstMatch
        let element: (String) -> XCUIElement = { app.descendants(matching: .any)[$0].firstMatch }
        let firstCredit = element("settings.attribution.swiftui")
        scrollToFooter(firstCredit, in: scroller, app: app)
        XCTAssertTrue(firstCredit.label.contains("SwiftUI"))
        let credits = XCTAttachment(screenshot: app.screenshot())
        credits.name = accessibilityText ? "Built-with-largest-text" : "Built-with"
        credits.lifetime = .keepAlways
        add(credits)
        for id in ["uikit", "speech"] {
            scrollToVisible(element("settings.attribution.\(id)"), in: scroller, app: app)
        }
        let creator = element("settings.creator")
        scrollToVisible(creator, in: scroller, app: app)
        XCTAssertTrue(creator.label.contains("Jeremy Collins"))
        let otherApps = element("settings.otherApps")
        scrollToVisible(otherApps, in: scroller, app: app)
        let footer = XCTAttachment(screenshot: app.screenshot())
        footer.name = accessibilityText ? "Settings-footer-largest-text" : "Settings-footer"
        footer.lifetime = .keepAlways
        add(footer)
        otherApps.tap()
        XCTAssertTrue(app.navigationBars["Other Apps"].waitForExistence(timeout: 5))
        let codable = element("otherApps.codable")
        let taktung = element("otherApps.taktung")
        let appsList = app.collectionViews.firstMatch
        scrollToVisible(codable, in: appsList, app: app)
        XCTAssertTrue(codable.label.contains("Codable"))
        scrollToVisible(taktung, in: appsList, app: app)
        XCTAssertTrue(taktung.label.contains("Taktung"))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = accessibilityText ? "Other-apps-largest-text" : "Other-apps"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testDeleteLineAndTabOutdent() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        let editor = app.textViews["playground.editor"]
        let key: (String) -> XCUIElement = { app.descendants(matching: .any)["key.\($0)"].firstMatch }
        XCTAssertTrue(key("q").waitForExistence(timeout: 10))
        let initial = editor.value as? String ?? ""
        XCTAssertTrue(initial.hasSuffix("\n"))
        key("q").tap()
        XCTAssertEqual(editor.value as? String, initial + "q")
        app.buttons["keyboard.deleteLine"].tap()
        XCTAssertEqual(editor.value as? String, String(initial.dropLast()))
        key("Return").tap()
        key("Tab").tap()
        XCTAssertEqual(editor.value as? String, initial + "    ")
        key("Outdent").tap()
        XCTAssertEqual(editor.value as? String, initial)
    }

    private func tapMenuOption(_ title: String, app: XCUIApplication) {
        let option = app.buttons[title].firstMatch
        let menu = app.collectionViews.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            if option.exists && option.isHittable { option.tap(); return }
            let visible = menu.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
                .map { $0.frame.intersection(app.frame) }.filter { !$0.isEmpty }.sorted { $0.minY < $1.minY }
            guard visible.count >= 2 else { break }
            let lower = visible[visible.count - 1]
            // The top item can be clipped under the menu's rounded edge.
            // Start on an interior visible row, away from the status bar.
            let upper = visible[visible.count >= 3 ? 1 : 0]
            let point = app.coordinate(withNormalizedOffset: .zero)
            // UIKit anchors this long keyboard menu at its bottom. Its initial
            // visible actions are Editing actions and Snippets; preferences
            // above them are revealed by dragging the menu content downward.
            point.withOffset(CGVector(dx: upper.midX - app.frame.minX, dy: upper.midY - app.frame.minY))
                .press(forDuration: 0.05, thenDragTo: point.withOffset(CGVector(dx: lower.midX - app.frame.minX, dy: lower.midY - app.frame.minY)))
        }
        XCTFail("Keyboard menu option could not be reached: \(title)")
    }

    private enum ScrollDirection { case towardBeginning, towardEnd }

    private func scrollToFooter(_ element: XCUIElement, in scroller: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(scroller.waitForExistence(timeout: 5))
        // This flow starts at the top of Settings. At accessibility sizes the
        // footer needs more swipes than other settings destinations; keep
        // moving toward it while SwiftUI materializes the lazy rows.
        for _ in 0..<64 {
            if element.exists && element.isHittable { return }
            let horizontal: CGFloat = scroller.frame.midX <= app.frame.midX ? 0.2 : 0.8
            let start = scroller.coordinate(withNormalizedOffset: CGVector(dx: horizontal, dy: 0.8))
            let end = scroller.coordinate(withNormalizedOffset: CGVector(dx: horizontal, dy: 0.25))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("The Settings footer could not be reached.")
    }

    private func scrollToVisible(_ element: XCUIElement, in scroller: XCUIElement, app: XCUIApplication,
                                 initialDirection: ScrollDirection = .towardEnd,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scroller.waitForExistence(timeout: 5), file: file, line: line)
        var towardEnd = initialDirection == .towardEnd
        for attempt in 0..<32 {
            // Testing isHittable on a nonexistent lazy element causes repeated
            // XCTest lookup retries; exists is a single snapshot check.
            let exists = element.exists
            if exists && element.isHittable { break }
            if exists && !element.frame.isEmpty {
                if element.frame.maxY <= scroller.frame.minY { towardEnd = false }
                else if element.frame.minY >= scroller.frame.maxY { towardEnd = true }
            } else if attempt == 16 {
                // A retained scroll position can put an unmaterialized target
                // above us. Search the other direction if it has not appeared.
                towardEnd.toggle()
            }
            // Keep the gesture on the outer part of the content, away from a
            // Duo book fold or a side tab bar. No orientation changes required.
            let horizontal: CGFloat = scroller.frame.midX <= app.frame.midX ? 0.2 : 0.8
            let start = scroller.coordinate(withNormalizedOffset: CGVector(dx: horizontal, dy: towardEnd ? 0.8 : 0.25))
            let end = scroller.coordinate(withNormalizedOffset: CGVector(dx: horizontal, dy: towardEnd ? 0.25 : 0.8))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, file: file, line: line)
    }

    private func tapVisibleEdge(_ element: XCUIElement, app: XCUIApplication, within container: XCUIElement? = nil,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.isHittable, file: file, line: line)
        if app.frame.width < 650 {
            // UIKit's hittable point accounts for clipping inside large rows.
            // An ordinary phone has no central fold to work around.
            element.tap()
            return
        }
        let visible = element.frame.intersection(app.frame).intersection(container?.frame ?? app.frame)
        XCTAssertFalse(visible.isEmpty, file: file, line: line)
        let horizontal: CGFloat = visible.midX <= app.frame.midX ? 0.2 : 0.8
        let vertical: CGFloat = visible.midY <= app.frame.midY ? 0.25 : 0.75
        let point = CGPoint(x: visible.minX + visible.width * horizontal,
                            y: visible.minY + visible.height * vertical)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: point.x - app.frame.minX, dy: point.y - app.frame.minY)).tap()
    }
}
