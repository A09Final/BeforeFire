import XCTest

final class OnboardingSkipTests: XCTestCase {
    @MainActor
    func testSkipAvailabilityMatchesBuildConfiguration() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding.completed", "NO"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 10))
        let skip = app.buttons["onboarding.skip"]

        #if DEBUG
        XCTAssertTrue(skip.exists)
        skip.tap()
        let settings = app.buttons["monitor.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(app.buttons["settings.sensorConnection"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.alarmConnection"].exists)

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["monitor.settings"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.getStarted"].exists)
        #else
        XCTAssertFalse(skip.exists)
        XCTAssertFalse(app.buttons["Skip"].exists)
        app.buttons["onboarding.getStarted"].tap()
        XCTAssertTrue(app.staticTexts["Allow Access"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
        #endif
    }
}
