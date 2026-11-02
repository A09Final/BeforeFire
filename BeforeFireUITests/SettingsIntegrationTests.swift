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
    func testSimulatedSensorJoinsWiFi() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let status = openSimulatedSensorConnection(in: app)
        defer { app.terminate() }

        XCTAssertEqual(status.label, "Sensor, Not connected")
        selectSimulatedSensorAndEnterSetupCode(in: app)

        // The simulated sensor finds these networks. The secured network needs a password.
        let kitchenNetwork = app.buttons["sensorWiFi.network.Kitchen WiFi"]
        XCTAssertTrue(kitchenNetwork.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sensorWiFi.network.Guest"].exists)
        kitchenNetwork.tap()

        let joinButton = app.buttons["sensorWiFi.joinButton"]
        XCTAssertTrue(joinButton.waitForExistence(timeout: 5))
        XCTAssertFalse(joinButton.isEnabled)
        let password = app.secureTextFields["sensorWiFi.passwordField"]
        password.tap()
        password.typeText("password1")
        joinButton.tap()

        let success = app.descendants(matching: .any)["sensorWiFi.success"].firstMatch
        XCTAssertTrue(success.waitForExistence(timeout: 10))
        app.buttons["sensorWiFi.doneButton"].tap()

        expectSensorStatus(status, label: "Sensor, DAPUR_A1B2C3")
    }

    @MainActor
    func testSimulatedSensorJoinsOtherNetwork() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let status = openSimulatedSensorConnection(in: app)
        defer { app.terminate() }

        selectSimulatedSensorAndEnterSetupCode(in: app)

        // The button is disabled until the sensor completes its Wi-Fi scan.
        let otherNetworkButton = app.buttons["sensorWiFi.otherNetworkButton"]
        let isEnabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: otherNetworkButton)
        XCTAssertEqual(XCTWaiter.wait(for: [isEnabled], timeout: 5), .completed)
        otherNetworkButton.tap()

        let wiFiName = app.textFields["sensorWiFi.nameField"]
        XCTAssertTrue(wiFiName.waitForExistence(timeout: 5))
        wiFiName.tap()
        wiFiName.typeText("Hidden Kitchen")
        app.buttons["sensorWiFi.joinButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["sensorWiFi.success"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["sensorWiFi.doneButton"].tap()

        expectSensorStatus(status, label: "Sensor, DAPUR_A1B2C3")
    }

    @MainActor
    func testWrongLengthSetupCodeShowsError() {
        continueAfterFailure = false
        let app = XCUIApplication()
        _ = openSimulatedSensorConnection(in: app)
        defer { app.terminate() }

        selectSimulatedSensor(in: app)
        enterSetupCode("abc", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["sensorWiFi.error"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["sensorWiFi.setupCodeField"].exists)

        app.buttons["sensorWiFi.cancelButton"].tap()
        XCTAssertTrue(app.buttons["sensor.connectButton"].waitForExistence(timeout: 5))
    }

    // MARK: - Steps

    /// Turns on the sensor simulation and opens Sensor Connection. Returns the status row.
    @MainActor
    private func openSimulatedSensorConnection(in app: XCUIApplication) -> XCUIElement {
        app.launch()
        app.buttons["monitor.settings"].tap()

        // The simulation keeps the test independent of Bluetooth hardware and permission prompts.
        let simulationToggle = app.switches["settings.simulateSensorsToggle"]
        XCTAssertTrue(simulationToggle.waitForExistence(timeout: 5))
        simulationToggle.switches.firstMatch.tap()

        app.buttons["settings.sensorConnection"].tap()
        // LabeledContent exposes the label and value as one element.
        let status = app.staticTexts["sensor.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        return status
    }

    @MainActor
    private func selectSimulatedSensor(in app: XCUIApplication) {
        app.buttons["sensor.connectButton"].tap()
        let sensor = app.buttons["sensor.found.DAPUR_A1B2C3"]
        XCTAssertTrue(sensor.waitForExistence(timeout: 5))
        sensor.tap()
    }

    @MainActor
    private func enterSetupCode(_ setupCode: String, in app: XCUIApplication) {
        let setupCodeField = app.textFields["sensorWiFi.setupCodeField"]
        XCTAssertTrue(setupCodeField.waitForExistence(timeout: 5))
        setupCodeField.tap()
        setupCodeField.typeText(setupCode)
        app.buttons["sensorWiFi.connectButton"].tap()
    }

    @MainActor
    private func selectSimulatedSensorAndEnterSetupCode(in app: XCUIApplication) {
        selectSimulatedSensor(in: app)
        enterSetupCode("ab3d5fgh", in: app)
    }

    private func expectSensorStatus(_ status: XCUIElement, label: String) {
        let expectedStatus = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: expectedStatus, object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
