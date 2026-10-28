import ActivityKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AlarmPreviewModel {
    var isAlarmPresented = false
    private(set) var activityMessage: String?
    private(set) var isEndingActivity = false
    private let logger = Logger(subsystem: "com.ibnu.BeforeFire", category: "AlarmPreview")

    func open(_ url: URL) {
        guard AlarmActivityAttributes.matchesPreviewURL(url) else { return }
        isAlarmPresented = true
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityMessage = "Live Activities are disabled. Allow them for BeforeFire in Settings, then try again."
            return
        }
        guard !Activity<AlarmActivityAttributes>.activities.contains(where: {
            $0.activityState == .active || $0.activityState == .stale
        }) else {
            activityMessage = "A preview is already running. End it before starting another."
            return
        }
        do {
            // Local preview only. No push token or sensor data is requested.
            _ = try Activity.request(
                attributes: AlarmActivityAttributes(previewID: UUID()),
                content: ActivityContent(state: AlarmActivityAttributes.ContentState(), staleDate: nil),
                pushType: nil
            )
            activityMessage = "Preview started. Check the Lock Screen or Dynamic Island."
        } catch {
            logger.error("Live Activity preview could not start: \(error.localizedDescription, privacy: .public)")
            activityMessage = "Could not start the Live Activity. Keep BeforeFire open and try again."
        }
    }

    func endLiveActivities() async {
        guard !isEndingActivity else { return }
        isEndingActivity = true
        defer { isEndingActivity = false }
        for activity in Activity<AlarmActivityAttributes>.activities {
            guard !Task.isCancelled else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard !Task.isCancelled else { return }
        activityMessage = "Live Activity previews ended."
    }
}
