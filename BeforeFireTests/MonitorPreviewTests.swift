import Testing
@testable import BeforeFire

@MainActor
struct MonitorPreviewTests {
    @Test func previewIsOffByDefault() {
        let model = MonitorViewModel.mock

        #expect(model.actionGuidance == nil)
        #expect(model.displayedStatusTitle == model.statusTitle)
        #expect(!model.isAlarmPreview)
    }

    @Test func previewChangesGuidanceWithoutChangingReadings() {
        var model = MonitorViewModel.mock
        let originalValues = model.readings.map(\.value)
        model.isActionGuidanceVisible = true

        #expect(model.displayedStatusTitle == "Your Kitchen Is\nUnsafe")
        #expect(model.actionGuidance == "Check your kitchen now.\nStay nearby while the stove is hot.")
        #expect(!model.isAlarmPreview)

        model.previewCondition = .dangerous

        #expect(model.displayedStatusTitle == "Your Kitchen Is\nDangerous")
        #expect(model.actionGuidance == "Check your kitchen now.\nCheck the stove and surrounding area.")
        #expect(model.isAlarmPreview)
        #expect(model.readings.map(\.value) == originalValues)
    }

    @Test func disablingPreviewRestoresStatusAndKeepsSelection() {
        var model = MonitorViewModel.mock
        model.isActionGuidanceVisible = true
        model.previewCondition = .dangerous
        model.isActionGuidanceVisible = false

        #expect(model.displayedStatusTitle == model.statusTitle)
        #expect(model.actionGuidance == nil)
        #expect(!model.isAlarmPreview)

        model.isActionGuidanceVisible = true
        #expect(model.isAlarmPreview)
        #expect(!MonitorViewModel.mock.isActionGuidanceVisible)
    }

    @Test func badgesOnlyMarkStoveHeatWhilePreviewIsEnabled() {
        var model = MonitorViewModel.mock
        #expect(model.badgeCondition(for: .stoveHeat) == nil)

        model.isActionGuidanceVisible = true
        for condition in MonitorPreviewCondition.allCases {
            model.previewCondition = condition
            for reading in model.readings {
                let expected: MonitorPreviewCondition? = reading.id == .stoveHeat ? condition : nil
                #expect(model.badgeCondition(for: reading.id) == expected)
            }
        }

        model.isActionGuidanceVisible = false
        #expect(model.badgeCondition(for: .stoveHeat) == nil)
    }
}
