import XCTest

final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["map-ready"].waitForExistence(timeout: 30), "Map did not finish loading")
        XCTAssertTrue(app.descendants(matching: .any)["sheet-peek"].waitForExistence(timeout: 20), "Bottom sheet did not appear")
        XCTAssertTrue(app.staticTexts["4 rutter"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Välj"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rutter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Filter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Statistik"].waitForExistence(timeout: 5))
        waitForRendering()
        try save("01-map-small")

        tap("tab-rutter", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["routes-list"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Nackareservatet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Djurgården"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Södermalm"].waitForExistence(timeout: 5))
        waitForRendering(seconds: 2)
        try save("02-routes-list")

        tap("run-Nackareservatet", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["route-detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Foton från passet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["photo-0"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Ta bort markering"].waitForExistence(timeout: 5)
                || app.buttons["Ta bort markering"].waitForExistence(timeout: 5)
        )
        waitForRendering(seconds: 2)
        try save("03-route-detail")

        tap("tab-filter", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["filter-screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Endast markerade"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Visa endast valda"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Datumintervall"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Distans"].waitForExistence(timeout: 5))
        waitForRendering(seconds: 1)
        try save("04-filter")

        tap("tab-statistik", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["stats-screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Total distans"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Total tid"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Snittempo"].waitForExistence(timeout: 5))
        waitForRendering(seconds: 1)
        try save("05-statistik")

        tap("tab-rutter", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["routes-list"].waitForExistence(timeout: 10))
        tap("select-button", in: app)
        XCTAssertTrue(app.staticTexts["Välj rutter"].waitForExistence(timeout: 10))
        tap("choose-Nackareservatet", in: app)
        tap("choose-Djurgården", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["summarize-button"].waitForExistence(timeout: 10))
        waitForRendering(seconds: 2)
        try save("06-selection")

        tap("summarize-button", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["summary-screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Sammanfattning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 valda rutter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nackareservatet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Djurgården"].waitForExistence(timeout: 5))
        waitForRendering(seconds: 3)
        try save("07-summary")
    }

    private func tap(_ identifier: String, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), identifier)
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    private func waitForRendering(seconds: TimeInterval = 4) {
        let rendered = expectation(description: "screen rendered")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            rendered.fulfill()
        }
        wait(for: [rendered], timeout: seconds + 4)
    }

    private func save(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory = screenshotDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: url)
        let size = try Data(contentsOf: url).count
        XCTAssertGreaterThan(size, 10_000, "\(name) looks empty")
        print("Saved screenshot \(url.path) (\(size) bytes)")
    }

    private func screenshotDirectory() -> URL {
        if let override = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("ci-screenshots", isDirectory: true)
    }
}
