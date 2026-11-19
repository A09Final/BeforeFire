import Foundation
import Testing
@testable import BeforeFire

@MainActor
struct KitchenStatusTests {
    @Test(arguments: KitchenCondition.allCases)
    func usesTheMonitorStatusAndGuidance(condition: KitchenCondition) {
        let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", condition: condition)
        let status = KitchenStatus(snapshot: snapshot)
        let monitor = MonitorViewModel(content: MonitorReadingsFormatter().content(for: snapshot))

        #expect(status.condition == condition)
        #expect(status.title == monitor.displayedStatusValue)
        #expect(status.guidance == monitor.actionGuidance)
        #expect((status.condition?.usesAlarmColor == true) == monitor.showsAlarmStatus)
    }

    @Test func hidesAnUnavailableReading() {
        let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", condition: .alarm, isStale: true)
        let status = KitchenStatus(snapshot: snapshot)
        #expect(status == .offline)
        #expect(status.guidance == nil)
    }

    @Test func doesNotShowAnInvalidNormalReading() {
        let snapshot = SensorReadingsSnapshot(deviceID: "DAPUR_A1B2C3", condition: .normal, conditionIsValid: false)
        let status = KitchenStatus(snapshot: snapshot)
        #expect(status.title == KitchenGuidance.unknownStatus)
        #expect(status.condition == nil)
        #expect(status.guidance == nil)
    }

    #if DEBUG
    @Test func sharesPreviewChangesWithoutChangingTheSensorLink() throws {
        let connection = try KitchenStatusWidgetConnection(service: "BeforeFire.tests.kitchenStatusPreview")
        _ = try connection.updatePreviewCondition(nil)
        defer {
            _ = try? connection.updatePreviewCondition(nil)
            _ = try? connection.update(nil)
        }
        let url = try #require(URL(string: "https://example.com/readings"))
        let sensor = SensorReadingsAccess(url: url, deviceID: "DAPUR_A1B2C3", readKey: "test-value")
        _ = try connection.update(sensor)

        var monitor = MonitorViewModel.mock
        #expect(monitor.activePreviewCondition == nil)
        #expect(try connection.loadPreviewCondition() == nil)

        monitor.isActionGuidanceVisible = true
        for condition in MonitorPreviewCondition.allCases {
            monitor.previewCondition = condition
            #expect(try connection.updatePreviewCondition(monitor.activePreviewCondition))
            let savedCondition = try connection.loadPreviewCondition()
            let saved = try #require(savedCondition)
            #expect(saved == condition)
            let status = KitchenStatus.reported(saved.assessment)
            #expect(status.title == monitor.displayedStatusValue)
            #expect(status.guidance == monitor.actionGuidance)
        }

        #expect(try !connection.updatePreviewCondition(monitor.activePreviewCondition))
        monitor.isActionGuidanceVisible = false
        #expect(try connection.updatePreviewCondition(monitor.activePreviewCondition))
        #expect(try connection.loadPreviewCondition() == nil)
        #expect(try connection.load() == sensor)
    }
    #endif
}
