import XCTest

/// The UI tour: launches a fixed career (`-UITour`), taps through every tab and the screens they
/// open in landscape and portrait, plays two matches with the ⏸ match centre, and saves a numbered
/// screenshot at every stop. `.github/workflows/ui-tour.yml` runs it on a Mac simulator and
/// publishes the screenshots to the `ui-tour-shots` branch. A missing button doesn't stop the
/// tour; it's listed in `notes.txt`.
final class TourTests: XCTestCase {
    private var app: XCUIApplication!
    private var count = 0
    private var notes: [String] = []
    private var tag = "L"

    /// Where the PNGs go on the Mac running the simulator (the workflow collects ~/ui-tour).
    private lazy var outDir: URL? = {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"] else { return nil }
        let dir = URL(fileURLWithPath: home).appendingPathComponent("ui-tour")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-UITour"]
        app.launch()
    }

    override func tearDown() {
        if let dir = outDir {
            try? notes.joined(separator: "\n").write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        }
    }

    func testTour() {
        for (orientation, t) in [(UIDeviceOrientation.landscapeLeft, "L"), (.portrait, "P")] {
            XCUIDevice.shared.orientation = orientation
            tag = t
            sleep(2)
            hub()
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        tag = "L"
        sleep(2)
        match()
        XCUIDevice.shared.orientation = .portrait
        tag = "P"
        sleep(2)
        match()

        // A play session: a few more rounds (line-ups, then straight to the result), then the
        // screens that fill up with stats, in landscape.
        XCUIDevice.shared.orientation = .landscapeLeft
        tag = "L"
        sleep(2)
        for _ in 0..<4 { quickMatch() }
        tag = "S"
        tab("Home"); shot("home-after-6")
        tab("League"); shot("table-after-6")
        for section in ["Stats", "Leaders"] {
            if tap(find(section), "League › \(section)") { shot("league-\(section.lowercased())-after-6") }
        }
        _ = tap(find("Table"), "League › Table")
        tab("Club")
        for screen in ["Club stats", "Squad report", "Development", "Money"] { visit(screen) }
        tab("Squad"); shot("squad-after-6")
        tab("Transfers"); shot("transfers-after-6")
        tab("Home")
    }

    /// Continue, start, skip straight to the result, next.
    private func quickMatch() {
        tab("Home")
        guard tap(app.buttons["continue"].firstMatch, "Continue") else { return }
        sleep(2)
        guard tap(find("Skip to result"), "Skip to result") else { return }
        sleep(2)
        _ = tap(find("Next"), "Next")
        sleep(2)
    }

    // MARK: The hub

    private func hub() {
        tab("Home"); shot("home")

        tab("Squad"); shot("squad")
        for screen in ["Pick XI", "Batting order", "Bowling plan", "Tactics", "Squad planner"] { visit(screen) }

        tab("Transfers"); shot("transfers")
        app.swipeUp(); shot("transfers-scrolled"); app.swipeDown()
        if tap(app.buttons.matching(identifier: "marketRow").firstMatch, "first market row") { shot("player"); back() }
        if tap(find(prefix: "Scouts"), "Scouts chip") { shot("scouting"); back() }

        tab("League"); shot("league-table")
        for section in ["Fixtures", "Stats", "Leaders", "World"] {
            if tap(find(section), "League › \(section)") { shot("league-\(section.lowercased())") }
        }
        _ = tap(find("Table"), "League › Table")

        tab("Club"); shot("club")
        for screen in ["Training", "Academy", "Development", "Club stats", "Squad report", "Money", "Ledger",
                       "Facilities", "Manager", "Store", "History", "News", "Settings"] {
            visit(screen)
        }
        tab("Home")
    }

    // MARK: A match

    private func match() {
        tab("Home")
        guard tap(app.buttons["continue"].firstMatch, "Continue") else { return }
        sleep(2)
        shot("match-teams")
        guard tap(find("Start match"), "Start match") else { return }
        sleep(4)
        shot("match-live-1")
        if tap(app.buttons["pause"].firstMatch, "Pause") {
            sleep(1)
            for t in ["Overview", "Ratings", "Around the league", "Scorecard", "Tactics", "Batting", "Bowling"] {
                if tap(app.buttons["centre.\(t)"].firstMatch, "Centre › \(t)", timeout: 2) {
                    shot("centre-\(t.lowercased().replacingOccurrences(of: " ", with: "-"))")
                }
            }
            _ = tap(find(prefix: "Resume"), "Resume")
        }
        sleep(6)
        shot("match-live-2")
        _ = tap(find(prefix: "Skip"), "Skip")
        sleep(3)
        shot("match-result")
        if tap(find("Full scorecard"), "Full scorecard") { shot("match-scorecard"); back() }
        _ = tap(find("Next"), "Next")
        sleep(2)
        shot("after-match")
    }

    // MARK: Helpers

    /// Opens a screen by its title, screenshots it, and goes back.
    private func visit(_ title: String) {
        guard tap(find(title), title, timeout: 2) else { return }
        sleep(1)
        shot(title.lowercased().replacingOccurrences(of: " ", with: "-"))
        back()
    }

    private func tab(_ name: String) {
        toRoot()
        _ = tap(app.buttons["tab.\(name)"].firstMatch, "tab \(name)")
        sleep(1)
    }

    /// Back to the hub (run 4 got stranded on a pushed screen and missed the matches).
    private func toRoot() {
        for _ in 0..<5 {
            if app.buttons["tab.Home"].firstMatch.exists { return }
            let bar = app.navigationBars.firstMatch
            var button = bar.buttons["BackButton"]
            if !button.exists { button = bar.buttons.element(boundBy: 0) }
            guard bar.exists, button.exists, button.isHittable, !button.label.contains("More") else { return }
            button.tap()
            sleep(1)
        }
    }

    /// The navigation bar's back button (run 3 tapped the hub's ⋯ menu instead and stopped).
    private func back() {
        let bar = app.navigationBars.firstMatch
        var button = bar.buttons["BackButton"]
        if !button.exists { button = bar.buttons.element(boundBy: 0) }
        if bar.exists, button.exists, button.isHittable, !button.label.contains("More") {
            button.tap()
        } else {
            notes.append("[\(tag)] no back button; edge swipe")
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        }
        sleep(1)
    }

    /// A button or text whose label is (or contains) `label`.
    private func find(_ label: String) -> XCUIElement {
        let exact = app.buttons[label].firstMatch
        if exact.exists { return exact }
        let contains = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        if contains.exists { return contains }
        return app.staticTexts[label].firstMatch
    }

    private func find(prefix: String) -> XCUIElement {
        let b = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        return b.exists ? b : app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    @discardableResult
    private func tap(_ e: XCUIElement, _ what: String, timeout: Double = 4) -> Bool {
        guard e.waitForExistence(timeout: timeout) else {
            notes.append("[\(tag)] missing: \(what)")
            return false
        }
        if !e.isHittable {
            app.swipeUp()   // below the fold in a scrolling column
            sleep(1)
            if !e.isHittable {
                notes.append("[\(tag)] not hittable: \(what)")
                return false
            }
        }
        e.tap()
        return true
    }

    private func shot(_ name: String) {
        sleep(1)   // let animations settle
        count += 1
        let screenshot = XCUIScreen.main.screenshot()
        let file = String(format: "%03d-%@-%@.png", count, tag, name)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = file
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = outDir { try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent(file)) }
    }
}
