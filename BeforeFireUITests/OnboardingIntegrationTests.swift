import XCTest

final class OnboardingIntegrationTests: XCTestCase {
    @MainActor
    func testOnboardingUsesSetupFlowAndCompletesWithoutHomeKit() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-onboarding.completed", "NO", "-simulateOnboarding"]
        app.launch()
        defer { app.terminate() }

        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["What You Need"].exists)
        capture("Welcome", in: app)
        app.buttons["onboarding.getStarted"].tap()
        XCTAssertTrue(app.staticTexts["Allow Access"].waitForExistence(timeout: 5))
        capture("Permissions", in: app)
        app.buttons["onboarding.continue"].tap()

        XCTAssertTrue(app.staticTexts["Sensor Placement Guide"].waitForExistence(timeout: 5))
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["Step 2"].waitForExistence(timeout: 5))
        // All slides share one pushed screen. Back returns to permissions.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Allow Access"].waitForExistence(timeout: 5))
        app.buttons["onboarding.continue"].tap()

        for title in ["Sensor Placement Guide", "Step 2", "Step 3"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            XCTAssertTrue(app.navigationBars.buttons.firstMatch.exists)
            capture("Placement - \(title)", in: app)
            app.buttons["placement.continue"].tap()
        }

        connect("sensor", name: "DAPUR_A1B2C3", in: app)
        let network = app.buttons["sensorWiFi.network.Kitchen WiFi"]
        XCTAssertTrue(network.waitForExistence(timeout: 5))
        waitForEnabled(network)
        capture("Sensor Wi-Fi networks", in: app)
        // A pop ends the Bluetooth session. Connect opens a new session with the same form.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.textFields["sensorWiFi.setupCodeField"].waitForExistence(timeout: 5))
        app.buttons["sensorWiFi.connectButton"].tap()
        XCTAssertTrue(network.waitForExistence(timeout: 5))
        waitForEnabled(network)
        network.tap()
        let password = app.secureTextFields["sensorWiFi.passwordField"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        assertHalfHeightSheet("sensor", in: app)
        capture("Wi-Fi password sheet", in: app)
        app.buttons["sensorWiFi.cancelPassword"].tap()
        XCTAssertTrue(network.waitForExistence(timeout: 5))
        network.tap()
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("password1")
        app.buttons["sensorWiFi.joinButton"].tap()
        expectConnected("sensor", in: app)
        capture("Sensor connected", in: app)
        app.buttons["sensorWiFi.continueButton"].tap()

        XCTAssertTrue(app.buttons["alarm.found.DAPUR_ALM_A1A2B3"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["sensorWiFi.continueButton"].waitForExistence(timeout: 5))
        app.buttons["sensorWiFi.continueButton"].tap()
        connect("alarm", name: "DAPUR_ALM_A1A2B3", in: app)
        let alarmNetwork = app.buttons["alarmWiFi.network.Guest"]
        XCTAssertTrue(alarmNetwork.waitForExistence(timeout: 5))
        waitForEnabled(alarmNetwork)
        capture("Alarm Wi-Fi networks", in: app)
        app.buttons["alarmWiFi.network.Kitchen WiFi"].tap()
        XCTAssertTrue(app.secureTextFields["alarmWiFi.passwordField"].waitForExistence(timeout: 5))
        assertHalfHeightSheet("alarm", in: app)
        capture("Alarm Wi-Fi password sheet", in: app)
        app.buttons["alarmWiFi.cancelPassword"].tap()
        XCTAssertTrue(alarmNetwork.waitForExistence(timeout: 5))
        alarmNetwork.tap()
        XCTAssertTrue(app.buttons["alarmWiFi.joinButton"].waitForExistence(timeout: 5))
        assertHalfHeightSheet("alarm", in: app)
        capture("Alarm open network", in: app)
        app.buttons["alarmWiFi.joinButton"].tap()
        expectConnected("alarm", in: app)
        capture("Alarm connected", in: app)
        app.buttons["alarmWiFi.continueButton"].tap()

        XCTAssertTrue(app.staticTexts["onboarding.complete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Notifications Allowed"].exists)
        capture("Setup complete", in: app)
        app.buttons["onboarding.goToMonitor"].tap()
        XCTAssertTrue(app.buttons["monitor.settings"].waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.buttons["monitor.settings"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.getStarted"].exists)
    }

    @MainActor
    private func connect(_ kind: String, name: String, in app: XCUIApplication) {
        let device = app.buttons["\(kind).found.\(name)"]
        XCTAssertTrue(device.waitForExistence(timeout: 8))
        capture("Discover \(kind)", in: app)
        device.tap()
        let code = app.textFields["\(kind)WiFi.setupCodeField"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        capture("Connect \(kind)", in: app)
        code.tap()
        code.typeText("ab3d5fgh")
        app.buttons["\(kind)WiFi.connectButton"].tap()
    }

    @MainActor
    private func expectConnected(_ kind: String, in app: XCUIApplication) {
        let status = app.descendants(matching: .any)["\(kind)WiFi.wiFiConnected"].firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["\(kind)WiFi.addToHomeButton"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["\(kind)WiFi.addedToHome"].firstMatch.exists)
    }

    @MainActor
    private func assertHalfHeightSheet(_ kind: String, in app: XCUIApplication) {
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let cancel = app.buttons["\(kind)WiFi.cancelPassword"]
        XCTAssertGreaterThan(cancel.frame.minY, app.frame.height * 0.4)
        XCTAssertLessThan(cancel.frame.minY, app.frame.height * 0.65)
    }

    @MainActor
    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForEnabled(_ element: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
