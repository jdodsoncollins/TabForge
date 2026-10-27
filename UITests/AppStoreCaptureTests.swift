import XCTest
import UIKit

/// Captures the shipping interface using synthetic bundled examples only.
/// Opt in through the UI-test runner environment: TABFORGE_STORE_SHOTS=1.
@MainActor
final class AppStoreCaptureTests: XCTestCase {
    func testCaptureAppStoreScreenshots() throws {
        guard ProcessInfo.processInfo.environment["TABFORGE_STORE_SHOTS"] == "1" else {
            throw XCTSkip("Set TABFORGE_STORE_SHOTS=1 to produce listing captures.")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        var captures: [[String: Any]] = []
        defer {
            if !captures.isEmpty {
                do { try attachGeometry(captures) }
                catch { XCTFail("Could not preserve the capture manifest: \(error)") }
            }
            XCUIDevice.shared.orientation = .portrait
            app.terminate()
        }

        if ProcessInfo.processInfo.environment["TABFORGE_STORE_SHOTS_MODE"] == "compact" {
            XCUIDevice.shared.orientation = .portrait
            captureCompact(app, into: &captures)
            return
        }
        if ProcessInfo.processInfo.environment["TABFORGE_STORE_SHOTS_MODE"] == "standard" {
            XCUIDevice.shared.orientation = .portrait
            launch(app, appearance: "Light")
            capture("standard", app: app, profile: "Code editor", theme: "iOS Standard",
                    appearance: "Light", into: &captures)
            return
        }
        if ProcessInfo.processInfo.environment["TABFORGE_STORE_SHOTS_MODE"] == "settings" {
            XCUIDevice.shared.orientation = .portrait
            launch(app, appearance: "Dark")
            captureSourceSettings(app, into: &captures)
            return
        }

        XCUIDevice.shared.orientation = .portrait
        launch(app, appearance: "Light")
        capture("standard", app: app, profile: "Code editor", theme: "iOS Standard",
                appearance: "Light", into: &captures)

        // Select the real keyboard's appearance setting, preserving the app's
        // ordinary response to the simulator's system appearance.
        app.terminate()
        launch(app, appearance: "Dark")
        capture("dark", app: app, profile: "Code editor", theme: "iOS Standard",
                appearance: "Dark", into: &captures)

        chooseGearMenu("Keyboard theme", option: "Darcula", app: app)
        capture("darcula", app: app, profile: "Code editor", theme: "Darcula",
                appearance: "Dark", into: &captures)

        // Keep the bundled synthetic Swift draft. This shows an input profile,
        // not a fabricated shell or a connection to a remote computer.
        chooseGearMenu("Input profile", option: "Terminal · ANSI", app: app)
        XCTAssertEqual(app.buttons["keyboard.deleteLine"].label, "Send Ctrl-U")
        capture("terminal", app: app, profile: "Terminal · ANSI", theme: "Darcula",
                appearance: "Dark", into: &captures)

        captureSourceSettings(app, into: &captures)

        if ProcessInfo.processInfo.environment["TABFORGE_STORE_SHOTS_SKIP_COMPACT"] != "1" {
            captureCompact(app, into: &captures)
        }
    }

    private func captureSourceSettings(_ app: XCUIApplication, into captures: inout [[String: Any]]) {
        app.buttons["keyboard.quickSettings"].tap()
        tapMenuItem("Dismiss keyboard", app: app)
        let settings = app.buttons["Settings"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.staticTexts["Configure TabForge from the keyboard."].waitForExistence(timeout: 5))
        revealSourceLinks(app)
        capture("settings", app: app, profile: "Not applicable", theme: "Not applicable",
                appearance: "Dark", into: &captures, requiresKeyboard: false)
    }

    private func attachGeometry(_ captures: [[String: Any]]) throws {
        let manifest: [String: Any] = [
            "schemaVersion": 2,
            "coordinateSpace": "XCTest screen points; screenshotPixels records raster size",
            "content": "Bundled synthetic examples, captured through native app interactions",
            "terminalIsRemoteConnection": false,
            "captures": captures
        ]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        let geometry = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        geometry.name = "capture-geometry"
        geometry.lifetime = .keepAlways
        add(geometry)
    }

    private func captureCompact(_ app: XCUIApplication, into captures: inout [[String: Any]]) {
        app.terminate()
        launch(app, appearance: "Light")
        XCUIDevice.shared.orientation = .landscapeLeft
        let bounds = windowBounds(app)
        if min(bounds.width, bounds.height) < 650 {
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let currentBounds = self.windowBounds(app)
                return currentBounds.width > currentBounds.height
            }, object: nil)
            // A physically closed Duo may keep portrait window geometry even
            // after an XCTest orientation request. Its real Compact preference
            // below is the fallback; retain the observed orientation in JSON.
            _ = XCTWaiter.wait(for: [rotated], timeout: 5)
        }
        // A Duo's physical hinge pose is owned by Device Hub. Large windows may
        // retain their bounds after an orientation request, so use the real
        // Compact preference instead of changing a simulator's fold pose.
        if windowBounds(app).height > 500 {
            chooseGearMenu("Keyboard height", option: "Compact", app: app)
        }
        let function = key("Fn", app: app)
        XCTAssertTrue(function.waitForExistence(timeout: 5))
        XCTAssertTrue(function.isHittable)
        capture("compact", app: app, profile: "Code editor", theme: "iOS Standard",
                appearance: "Light", into: &captures)
    }

    private func launch(_ app: XCUIApplication, appearance: String) {
        app.launchArguments = ["--uitesting", "--show-keyboard"]
        app.launch()
        focusKeyboard(app)
        chooseGearMenu("Appearance", option: appearance, app: app)
    }

    private func key(_ title: String, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["key.\(title)"].firstMatch
    }

    private func focusKeyboard(_ app: XCUIApplication) {
        let surface = app.otherElements["keyboard.surface"].firstMatch
        let q = key("q", app: app)
        if !q.waitForExistence(timeout: 5) || !q.isHittable {
            let editor = app.textViews["playground.editor"]
            XCTAssertTrue(editor.waitForExistence(timeout: 5))
            editor.tap()
        }
        XCTAssertTrue(surface.waitForExistence(timeout: 10))
        XCTAssertTrue(q.waitForExistence(timeout: 5))
        XCTAssertTrue(q.isHittable)
    }

    private func chooseGearMenu(_ title: String, option: String, app: XCUIApplication) {
        let gear = app.buttons["keyboard.quickSettings"]
        XCTAssertTrue(gear.waitForExistence(timeout: 5))
        XCTAssertTrue(gear.isHittable)
        gear.tap()
        tapMenuItem(title, app: app)
        tapMenuItem(option, app: app)
        XCTAssertTrue(key("q", app: app).waitForExistence(timeout: 5))
    }

    private func tapMenuItem(_ title: String, app: XCUIApplication) {
        // iOS 27.2 appends a menu item's subtitle to its label.
        let item = app.buttons.matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", title, title + ", ")).firstMatch
        let menu = app.collectionViews.firstMatch
        _ = item.waitForExistence(timeout: 3)
        for attempt in 0..<10 {
            if item.exists && item.isHittable { break }
            XCTAssertTrue(menu.waitForExistence(timeout: 3), "No menu while finding \(title)")
            // Long UIKit menus can initially open at their bottom. These
            // bounded strokes follow the existing menu UI-test harness; their
            // collection frame can include content outside the visible menu.
            let towardBeginning = attempt < 5
            let start = menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardBeginning ? 0.15 : 0.4))
            let end = menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: towardBeginning ? 0.4 : 0.15))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(item.exists && item.isHittable, "Menu item is not visible: \(title)")
        // XCTest's native hit point handles menu clipping and window routing.
        // A window-relative edge coordinate can land in another menu window
        // when a wide Duo presents a side toolbar and overlapping popovers.
        item.tap()
    }

    private func revealSourceLinks(_ app: XCUIApplication) {
        let identifiers = ["settings.sourceCode", "settings.privacyPolicy", "settings.securityPolicy"]
        let links = identifiers.map { app.descendants(matching: .any)[$0].firstMatch }
        let form = app.collectionViews.firstMatch
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        for _ in 0..<14 {
            let bounds = windowBounds(app)
            if links.allSatisfy({ $0.exists && $0.isHittable && bounds.contains($0.frame) }) { break }
            // Stay away from an open Duo's central fold and side tab bar.
            let x: CGFloat = form.frame.midX <= bounds.midX ? 0.25 : 0.8
            let start = form.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.8))
            let end = form.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.35))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        for (identifier, link) in zip(identifiers, links) {
            XCTAssertTrue(link.exists && link.isHittable, identifier)
            XCTAssertTrue(windowBounds(app).contains(link.frame), "Capture must include the complete \(identifier) row")
        }
    }

    private func primaryWindow(_ app: XCUIApplication) -> XCUIElement {
        // The open Duo can omit the Application accessibility frame while its
        // real windows and child elements retain correct screen coordinates.
        // Anchor taps/crops to a window instead of inventing an app rectangle.
        let windows = app.windows.allElementsBoundByIndex.filter {
            let frame = $0.frame
            return !frame.isEmpty && !frame.isNull && !frame.isInfinite
        }
        guard let window = windows.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }) else {
            XCTFail("The app has no window with valid screen geometry")
            return app.windows.firstMatch
        }
        return window
    }

    private func windowBounds(_ app: XCUIApplication) -> CGRect {
        primaryWindow(app).frame
    }

    private func capture(_ name: String, app: XCUIApplication, profile: String, theme: String,
                         appearance: String, into captures: inout [[String: Any]],
                         requiresKeyboard: Bool = true) {
        let surface = app.otherElements["keyboard.surface"].firstMatch
        let bounds = windowBounds(app)
        if requiresKeyboard {
            XCTAssertTrue(surface.waitForExistence(timeout: 5))
            XCTAssertTrue(key("q", app: app).isHittable)
            XCTAssertFalse(surface.frame.intersection(bounds).isEmpty)
        }
        // Application screenshots can be malformed during landscape/folded
        // configurations. An open Duo can also expose an inactive first screen.
        // Capture its actual app window when the application root describes a
        // different display; ordinary phones use the active screen in landscape.
        let applicationFrame = app.frame
        let rootMatchesWindow = !applicationFrame.isEmpty && !applicationFrame.isNull && !applicationFrame.isInfinite
            && abs(applicationFrame.width - bounds.width) < 1
            && abs(applicationFrame.height - bounds.height) < 1
            && abs(applicationFrame.minX - bounds.minX) < 1
            && abs(applicationFrame.minY - bounds.minY) < 1
        let isCompactPhone = name == "compact" && min(bounds.width, bounds.height) < 650
        let useWindowScreenshot = !rootMatchesWindow && !isCompactPhone
        let screenshot = useWindowScreenshot ? primaryWindow(app).screenshot() : XCUIScreen.main.screenshot()
        let image = screenshot.image
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let toolbar = app.otherElements["keyboard.toolbar"].firstMatch
        var record: [String: Any] = [
            "name": name,
            "appBounds": rectangle(bounds),
            "appBoundsSource": "Largest application window",
            "screenshotSource": useWindowScreenshot ? "Largest application window" : "XCUIScreen.main",
            "screenshotPixels": ["width": image.cgImage?.width ?? Int(image.size.width * image.scale),
                                 "height": image.cgImage?.height ?? Int(image.size.height * image.scale)],
            "screenshotUIImageOrientation": String(describing: image.imageOrientation),
            "screenshotUIImageOrientationRawValue": image.imageOrientation.rawValue,
            "deviceOrientation": String(describing: XCUIDevice.shared.orientation),
            "deviceOrientationRawValue": XCUIDevice.shared.orientation.rawValue,
            "windowOrientation": bounds.width > bounds.height ? "landscape" : "portrait",
            "inputProfile": profile,
            "theme": theme,
            "keyboardAppearance": appearance,
            "companionAppearance": "Follows simulator system appearance",
            "terminalIsRemoteConnection": false,
            "keyboardVisible": requiresKeyboard
        ]
        if !applicationFrame.isNull && !applicationFrame.isInfinite {
            record["applicationElementFrame"] = rectangle(applicationFrame)
        }
        if requiresKeyboard && surface.exists && !surface.frame.isEmpty {
            record["keyboardSurface"] = rectangle(surface.frame)
            record["visibleKeyboardSurface"] = rectangle(surface.frame.intersection(bounds))
        }
        if toolbar.exists && toolbar.isHittable {
            record["toolbar"] = rectangle(toolbar.frame)
        }
        let editor = app.textViews["playground.editor"].firstMatch
        if editor.exists { record["editor"] = rectangle(editor.frame) }
        if name == "compact" {
            record["requestedOrientation"] = "landscapeLeft"
            record["compactFunctionKeyVisible"] = key("Fn", app: app).isHittable
        }
        captures.append(record)
        // Preserve each frame's own geometry even if a later optional menu
        // action fails before the complete manifest can be attached.
        if let data = try? JSONSerialization.data(withJSONObject: ["schemaVersion": 2, "capture": record], options: [.prettyPrinted, .sortedKeys]) {
            let geometry = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            geometry.name = "capture-geometry-\(name)"
            geometry.lifetime = .keepAlways
            add(geometry)
        } else {
            XCTFail("Could not preserve geometry for \(name)")
        }
    }

    private func rectangle(_ frame: CGRect) -> [String: Double] {
        ["x": Double(frame.minX), "y": Double(frame.minY),
         "width": Double(frame.width), "height": Double(frame.height)]
    }
}
