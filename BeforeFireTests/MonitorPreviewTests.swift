import Testing
@testable import BeforeFire

@MainActor
struct MonitorPreviewTests {
    @Test func previewIsOffByDefault() {
        let model = MonitorViewModel.mock

        #expect(model.actionGuidance == nil)
        #expect(model.statusHeading == "Your Kitchen Is")
        #expect(model.displayedStatusValue == "Safe")
        #expect(model.displayedStatusTitle == model.statusTitle)
        #expect(!model.isAlarmPreview)
        #expect(model.readings.map(\.value) == [
            "80", "Good", "Detected", "30", "60", "1,013"
        ])
    }

    @Test func previewChangesGuidanceAndReadings() {
        var model = MonitorViewModel.mock
        model.isActionGuidanceVisible = true

        #expect(model.displayedStatusTitle == "Your Kitchen Is\nUnsafe")
        #expect(model.displayedStatusValue == "Unsafe")
        #expect(model.actionGuidance == MonitorPreviewCondition.unsafe.actionGuidance)
        #expect(!model.isAlarmPreview)
        #expect(model.readings.map(\.value) == [
            "180", "Lightly Polluted", "Not Detected", "30", "60", "1,013"
        ])
        let unsafeAirQuality = model.readings.first { $0.id == .airQuality }
        #expect(unsafeAirQuality?.unit == nil)
        #expect(unsafeAirQuality?.spokenValue == "Lightly Polluted")

        model.previewCondition = .dangerous

        #expect(model.displayedStatusTitle == "Your Kitchen Is\nDangerous")
        #expect(model.displayedStatusValue == "Dangerous")
        #expect(model.actionGuidance == MonitorPreviewCondition.dangerous.actionGuidance)
        #expect(model.isAlarmPreview)
        #expect(model.readings.map(\.value) == [
            "180", "Heavily Polluted", "Not Detected", "30", "60", "1,013"
        ])
        let dangerousAirQuality = model.readings.first { $0.id == .airQuality }
        #expect(dangerousAirQuality?.unit == nil)
        #expect(dangerousAirQuality?.spokenValue == "Heavily Polluted")
        #expect(MonitorPreviewCondition.unsafe.actionGuidance
                != MonitorPreviewCondition.dangerous.actionGuidance)
    }

    @Test func disablingPreviewRestoresStatusAndReadingsAndKeepsSelection() {
        var model = MonitorViewModel.mock
        let originalReadings = model.readings
        model.isActionGuidanceVisible = true
        model.previewCondition = .dangerous
        model.isActionGuidanceVisible = false

        #expect(model.displayedStatusTitle == model.statusTitle)
        #expect(model.actionGuidance == nil)
        #expect(!model.isAlarmPreview)
        #expect(model.readings.map(\.value) == originalReadings.map(\.value))
        #expect(model.readings.map(\.unit) == originalReadings.map(\.unit))
        #expect(model.readings.map(\.spokenValue) == originalReadings.map(\.spokenValue))

        model.isActionGuidanceVisible = true
        #expect(model.isAlarmPreview)
        #expect(model.readings.first { $0.id == .airQuality }?.value == "Heavily Polluted")
        #expect(!MonitorViewModel.mock.isActionGuidanceVisible)
        #expect(MonitorViewModel.mock.readings.map(\.value) == originalReadings.map(\.value))
    }

    @Test func readingIndicatorsFollowPreviewAndClearWhenDisabled() {
        var model = MonitorViewModel.mock
        #expect(model.readingAlertCondition == nil)

        model.isActionGuidanceVisible = true
        for condition in MonitorPreviewCondition.allCases {
            model.previewCondition = condition
            #expect(model.readingAlertCondition == condition)
        }

        model.isActionGuidanceVisible = false
        #expect(model.readingAlertCondition == nil)

        model.isActionGuidanceVisible = true
        #expect(model.readingAlertCondition == model.previewCondition)
    }
}
