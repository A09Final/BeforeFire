import ActivityKit
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class AlarmPreviewModel {
    let guidance = AlarmGuidance.mock
    var isAlarmPresented = false {
        didSet { updateFeedback() }
    }
    var isHubDisconnected: Bool {
        get { alarmState.isHubOffline }
        set {
            hubDisconnectedOverride = newValue
            alarmState.isHubDisconnected = newValue
            publishState()
        }
    }
    private(set) var activityMessage: String?
    private(set) var feedbackMessage: String?
    private(set) var isEndingActivity = false
    var snoozeDurationSeconds = AlarmActivityAttributes.defaultSnoozeSeconds
    private(set) var alarmState = AlarmActivityAttributes.ContentState() {
        didSet { updateFeedback() }
    }
    @ObservationIgnored private let feedback: any AlarmFeedbackPlaying
    @ObservationIgnored private var isApplicationActive = false
    @ObservationIgnored private var isFeedbackRequested = false
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var hubDisconnectedOverride: Bool?
    @ObservationIgnored private var shouldKeepLocalStateOnActivityStart = false
    private let logger = Logger(subsystem: "com.ibnu.BeforeFire", category: "AlarmPreview")

    convenience init() {
        self.init(feedback: AlarmFeedbackPlayer())
    }

    init(feedback: any AlarmFeedbackPlaying) {
        self.feedback = feedback
        feedback.onFailure = { [weak self] failure in
            self?.feedbackMessage = failure?.message
        }
    }

    func setApplicationActive(_ isActive: Bool) {
        isApplicationActive = isActive
        updateFeedback()
    }

    private func updateFeedback() {
        let shouldPlay = isApplicationActive && isAlarmPresented && !alarmState.isSnoozed
        guard shouldPlay != isFeedbackRequested else { return }
        isFeedbackRequested = shouldPlay
        feedbackMessage = nil
        feedback.setPlaying(shouldPlay)
    }

    func open(_ url: URL) {
        guard AlarmActivityAttributes.matchesPreviewURL(url) else { return }
        synchronizeFromLiveActivity()
        isAlarmPresented = true
    }

    func openPushAlarm(_ event: KitchenPushEvent) {
        guard event.assessment.validCondition == .alarm else { return }
        synchronizeFromLiveActivity()
        alarmState = alarmState.presentingPushEvent(event.id)
        publishState()
        shouldKeepLocalStateOnActivityStart = !isAlarmPresented
        isAlarmPresented = true
    }

    func snooze(at date: Date = .now) {
        alarmState.snoozeDurationSeconds = snoozeDurationSeconds
        alarmState = alarmState.snoozed(at: date)
        publishState()
    }

    func resumeAlarm() {
        alarmState = alarmState.resumed()
        alarmState.snoozeDurationSeconds = snoozeDurationSeconds
        publishState()
    }

    func resumeIfExpired(at date: Date = .now) {
        guard alarmState.isSnoozed, let end = alarmState.snoozeEndsAt, date >= end else { return }
        resumeAlarm()
    }

    func synchronizeFromLiveActivity(at date: Date = .now) {
        if let activity = Activity<AlarmActivityAttributes>.activities.first(where: {
            $0.activityState == .active || $0.activityState == .stale
        }) {
            alarmState = activity.content.state
            // A pending ActivityKit update must not undo the current developer setting.
            if let hubDisconnectedOverride, hubDisconnectedOverride != alarmState.isHubOffline {
                alarmState.isHubDisconnected = hubDisconnectedOverride
                publishState()
            }
            // Older previews did not include a deadline.
            if alarmState.isSnoozed && alarmState.snoozeEndsAt == nil {
                alarmState = alarmState.snoozed(at: date)
                publishState()
            }
        }
        resumeIfExpired(at: date)
    }

    func updateSnoozeDuration(_ seconds: Int) {
        snoozeDurationSeconds = min(max(seconds, AlarmActivityAttributes.minimumSnoozeSeconds),
                                   AlarmActivityAttributes.maximumSnoozeSeconds)
        // A running countdown keeps its original duration. The change applies to the next snooze.
        guard !alarmState.isSnoozed else { return }
        alarmState.snoozeDurationSeconds = snoozeDurationSeconds
        publishState()
    }

    private func publishState() {
        updateTask?.cancel()
        let state = alarmState
        updateTask = Task {
            for activity in Activity<AlarmActivityAttributes>.activities {
                guard !Task.isCancelled else { return }
                await activity.update(ActivityContent(state: state, staleDate: state.snoozeEndsAt))
            }
        }
    }

    func startLiveActivity() {
        guard !isEndingActivity else { return }
        let shouldRestoreActivity = !shouldKeepLocalStateOnActivityStart
        shouldKeepLocalStateOnActivityStart = false
        guard !Activity<AlarmActivityAttributes>.activities.contains(where: {
            $0.activityState == .active || $0.activityState == .stale
        }) else {
            if shouldRestoreActivity {
                synchronizeFromLiveActivity()
            } else {
                publishState()
            }
            activityMessage = "Live Activity preview is running."
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityMessage = "Live Activities are disabled. Allow them for BeforeFire in Settings, then try again."
            return
        }
        do {
            resumeIfExpired()
            if !alarmState.isSnoozed { alarmState.snoozeDurationSeconds = snoozeDurationSeconds }
            // Local preview only. No push token or sensor data is requested.
            _ = try Activity.request(
                attributes: AlarmActivityAttributes(previewID: UUID()),
                content: ActivityContent(state: alarmState, staleDate: alarmState.snoozeEndsAt),
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
        isAlarmPresented = false
        isEndingActivity = true
        updateTask?.cancel()
        defer { isEndingActivity = false }
        for activity in Activity<AlarmActivityAttributes>.activities {
            guard !Task.isCancelled else { return }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        guard !Task.isCancelled else { return }
        activityMessage = "Live Activity previews ended."
    }
}
