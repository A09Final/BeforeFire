import ActivityKit
import AppIntents
import Foundation

struct ResumeAlarmPreviewIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume Alarm Preview"
    static var description = IntentDescription("Restores the active alarm preview. Does not control an alarm device.")
    static var isDiscoverable = false

    @Parameter(title: "Activity ID") var activityID: String

    init() {}

    init(activityID: String) {
        self.activityID = activityID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let activity = Activity<AlarmActivityAttributes>.activities.first(where: { $0.id == activityID }),
              activity.activityState == .active || activity.activityState == .stale else {
            return .result()
        }
        let state = activity.content.state.resumed()
        await activity.update(ActivityContent(state: state, staleDate: nil))
        NotificationCenter.default.post(name: AlarmActivityAttributes.previewStateDidChange, object: nil)
        return .result()
    }
}
