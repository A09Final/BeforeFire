import XCTest

final class SettingsIntegrationTests: XCTestCase {
    @MainActor
    func testPlacementGuideReturnsToExistingDeveloperControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        let settings = app.buttons["monitor.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let guide = app.buttons["settings.placementGuideline"]
        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        guide.tap()
        XCTAssertTrue(app.staticTexts["Sensor Placement Guide"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(guide.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.hubConnection"].exists)
        XCTAssertTrue(app.buttons["settings.sensorConnection"].exists)
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

    @MainActor
    func testSimulatedSensorReceivesWiFi() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        defer { app.terminate() }

        app.buttons["monitor.settings"].tap()

        // The simulation keeps the test independent of Bluetooth hardware and permission prompts.
        let simulationToggle = app.switches["settings.simulateSensorsToggle"]
        XCTAssertTrue(simulationToggle.waitForExistence(timeout: 5))
        simulationToggle.switches.firstMatch.tap()

        app.buttons["settings.sensorConnection"].tap()
        // LabeledContent exposes the label and value as one element.
        let status = app.staticTexts["sensor.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Sensor, Not connected")
        app.buttons["sensor.connectButton"].tap()

        let sensor = app.buttons["sensor.found.DAPUR_A1B2C3"]
        XCTAssertTrue(sensor.waitForExistence(timeout: 5))
        sensor.tap()

        let wiFiName = app.textFields["sensorWiFi.nameField"]
        XCTAssertTrue(wiFiName.waitForExistence(timeout: 5))
        wiFiName.tap()
        wiFiName.typeText("Kitchen")
        let password = app.secureTextFields["sensorWiFi.passwordField"]
        password.tap()
        password.typeText("password1")
        let setupCode = app.textFields["sensorWiFi.setupCodeField"]
        setupCode.tap()
        setupCode.typeText("ab3d5fgh")
        app.buttons["sensorWiFi.sendButton"].tap()

        let doneButton = app.buttons["sensorWiFi.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()

        let connectedStatus = NSPredicate(format: "label == %@", "Sensor, DAPUR_A1B2C3")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: connectedStatus, object: status)], timeout: 5), .completed)
    }
}
