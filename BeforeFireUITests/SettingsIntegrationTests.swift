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
        XCTAssertTrue(app.buttons["settings.alarmConnection"].exists)
        XCTAssertTrue(app.buttons["settings.emergencyContact"].exists)
        XCTAssertTrue(app.switches["settings.actionGuidanceToggle"].exists)
        // SwiftUI exposes the row and its native switch as separate accessibility elements.
        app.switches["settings.actionGuidanceToggle"].switches.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.previewCondition"].waitForExistence(timeout: 5))

        let durationControl = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "settings.snoozeDuration")
        ).firstMatch
        let controls = [
            app.switches["settings.hubDisconnectedToggle"],
            app.buttons["settings.previewAlarm"],
            durationControl,
            app.buttons["settings.endAlarmActivity"]
        ]
        for control in controls {
            // The form can load lower rows only after they enter the viewport.
            for _ in 0..<4 {
                if control.exists && control.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(control.isHittable, "Expected to reach the Settings control: \(control)")
        }
    }

    @MainActor
    func testSimulatedSensorJoinsWiFiAndHome() {
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

        // The Home setup starts at once after the sensor joins Wi-Fi.
        let addedToHome = app.descendants(matching: .any)["sensorWiFi.addedToHome"].firstMatch
        XCTAssertTrue(addedToHome.waitForExistence(timeout: 10))
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

        XCTAssertTrue(app.descendants(matching: .any)["sensorWiFi.addedToHome"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["sensorWiFi.doneButton"].tap()

        expectSensorStatus(status, label: "Sensor, DAPUR_A1B2C3")
    }

    @MainActor
    func testSimulatedAlarmJoinsWiFiAndHome() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let status = openSimulatedConnection(.alarm, in: app)
        defer { app.terminate() }

        XCTAssertEqual(status.label, "Alarm, Not connected")
        app.buttons["alarm.connectButton"].tap()
        let alarm = app.buttons["alarm.found.DAPUR_ALM_A1A2B3"]
        XCTAssertTrue(alarm.waitForExistence(timeout: 5))
        // The alarm search must not show sensor units.
        XCTAssertFalse(app.buttons["alarm.found.DAPUR_A1B2C3"].exists)
        alarm.tap()
        enterSetupCode("ab3d5fgh", for: .alarm, in: app)

        let guestNetwork = app.buttons["alarmWiFi.network.Guest"]
        XCTAssertTrue(guestNetwork.waitForExistence(timeout: 5))
        guestNetwork.tap()
        app.buttons["alarmWiFi.joinButton"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["alarmWiFi.addedToHome"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["alarmWiFi.doneButton"].tap()

        expectSensorStatus(status, label: "Alarm, DAPUR_ALM_A1A2B3")
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

    /// The accessibility identifier prefix of each connection screen.
    private enum UnitPrefix: String {
        case sensor
        case alarm
    }

    /// Turns on the sensor simulation and opens Sensor Connection. Returns the status row.
    @MainActor
    private func openSimulatedSensorConnection(in app: XCUIApplication) -> XCUIElement {
        openSimulatedConnection(.sensor, in: app)
    }

    /// Turns on the device simulation and opens the connection screen of the unit. Returns the status row.
    @MainActor
    private func openSimulatedConnection(_ unit: UnitPrefix, in app: XCUIApplication) -> XCUIElement {
        app.launch()
        app.buttons["monitor.settings"].tap()

        // The simulation keeps the test independent of Bluetooth, HomeKit, and permission prompts.
        let simulationToggle = app.switches["settings.simulateSensorsToggle"]
        XCTAssertTrue(simulationToggle.waitForExistence(timeout: 5))
        simulationToggle.switches.firstMatch.tap()

        app.buttons["settings.\(unit.rawValue)Connection"].tap()
        // LabeledContent exposes the label and value as one element.
        let status = app.staticTexts["\(unit.rawValue).status"]
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
    private func enterSetupCode(_ setupCode: String, for unit: UnitPrefix = .sensor, in app: XCUIApplication) {
        let setupCodeField = app.textFields["\(unit.rawValue)WiFi.setupCodeField"]
        XCTAssertTrue(setupCodeField.waitForExistence(timeout: 5))
        setupCodeField.tap()
        setupCodeField.typeText(setupCode)
        app.buttons["\(unit.rawValue)WiFi.connectButton"].tap()
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
