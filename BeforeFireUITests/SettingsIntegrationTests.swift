import XCTest

final class SettingsIntegrationTests: XCTestCase {
    @MainActor
    func testPlacementGuideReturnsToExistingDeveloperControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        let settings = app.buttons["gearshape"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let guide = app.buttons["settings.placementGuideline"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        XCTAssertTrue(app.staticTexts["Sensor Placement Guide"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.hubConnection"].exists)
        XCTAssertTrue(app.buttons["settings.emergencyContact"].exists)
        XCTAssertTrue(app.switches["settings.actionGuidanceToggle"].exists)
        XCTAssertTrue(app.switches["settings.hubDisconnectedToggle"].exists)
        XCTAssertTrue(app.buttons["settings.previewAlarm"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "settings.snoozeDuration")
        ).firstMatch.exists)
        XCTAssertTrue(app.buttons["settings.endAlarmActivity"].exists)

        // SwiftUI exposes the row and its native switch as separate accessibility elements.
        app.switches["settings.actionGuidanceToggle"].switches.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.previewCondition"].waitForExistence(timeout: 5))
    }
}
