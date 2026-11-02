import ActivityKit
import AppIntents
import Foundation

struct SnoozeAlarmPreviewIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze Alarm Preview"
    static var description = IntentDescription("Changes the Live Activity preview. Does not control an alarm device.")
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
        // TODO: Define and verify hardware snooze commands before adding a real alarm action.
        let state = activity.content.state.snoozed(at: .now)
        await activity.update(ActivityContent(state: state, staleDate: state.snoozeEndsAt))
        NotificationCenter.default.post(name: AlarmActivityAttributes.previewStateDidChange, object: nil)
        return .result()
    }
}
