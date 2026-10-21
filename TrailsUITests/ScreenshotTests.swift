import XCTest

final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demo-data"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["run-list"].waitForExistence(timeout: 30))
        let firstRun = app.staticTexts["Nackareservatet"]
        XCTAssertTrue(firstRun.waitForExistence(timeout: 10), "Run list did not show the sample route")
        XCTAssertTrue(app.staticTexts["Djurgården"].waitForExistence(timeout: 5))
        try save("01-run-list")

        firstRun.tap()
        XCTAssertTrue(app.navigationBars["Nackareservatet"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["route-map"].waitForExistence(timeout: 10))
        waitForRendering()
        try save("02-run-route")

        var photo = app.descendants(matching: .any)["photo-0"]
        if !photo.waitForExistence(timeout: 3) {
            app.swipeUp()
            photo = app.descendants(matching: .any)["photo-0"]
        }
        XCTAssertTrue(photo.waitForExistence(timeout: 10), "Sample photo thumbnail was not on the run")
        photo.tap()
        XCTAssertTrue(app.descendants(matching: .any)["photo-detail"].waitForExistence(timeout: 10))
        waitForRendering(seconds: 1)
        try save("03-run-photos")

        let close = app.buttons["Stäng"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()

        let markedTab = app.tabBars.buttons["Markerade"].exists
            ? app.tabBars.buttons["Markerade"]
            : app.buttons["Markerade"]
        XCTAssertTrue(markedTab.waitForExistence(timeout: 10))
        markedTab.tap()
        XCTAssertTrue(app.staticTexts["Markerade rundor"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["marked-map"].waitForExistence(timeout: 10))
        waitForRendering()
        try save("04-marked-routes")
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
