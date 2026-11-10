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
    @ObservationIgnored private var liveAlarmDeviceID: String?
    @ObservationIgnored private var liveAlarmAt: Date?
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

    func open(_ url: URL, linkedDeviceID: String? = nil) {
        if let activity = activeActivities.first(where: {
            $0.attributes.sensorDeviceID == linkedDeviceID && $0.attributes.openURL == url
        }), let deviceID = activity.attributes.sensorDeviceID {
            liveAlarmDeviceID = deviceID
            liveAlarmAt = activity.attributes.alarmDate
            alarmState = activity.content.state
            resumeIfExpired()
        } else {
            guard AlarmActivityAttributes.matchesPreviewURL(url) else { return }
            synchronizeFromLiveActivity()
        }
        isAlarmPresented = true
    }

    private var activeActivities: [Activity<AlarmActivityAttributes>] {
        Activity<AlarmActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    private var sessionActivities: [Activity<AlarmActivityAttributes>] {
        activeActivities.filter { $0.attributes.sensorDeviceID == liveAlarmDeviceID }
    }

    func adoptRemoteActivity(_ activity: Activity<AlarmActivityAttributes>, linkedDeviceID: String?) async {
        guard let deviceID = activity.attributes.sensorDeviceID, deviceID == linkedDeviceID,
              let eventID = activity.attributes.remoteEventID,
              activity.activityState == .active || activity.activityState == .stale else { return }
        if liveAlarmDeviceID == deviceID { activityMessage = "Alarm Live Activity is running." }
        let localActivities = activeActivities.filter {
            $0.attributes.sensorDeviceID == deviceID && $0.attributes.remoteEventID == nil
        }
        guard !localActivities.isEmpty else { return }

        // The foreground reading can open a local activity before APNs arrives.
        let localState = liveAlarmDeviceID == deviceID ? alarmState : localActivities[0].content.state
        let state = localState.presentingPushEvent(eventID)
        if localState.pushEventID == nil && localState.isSnoozed {
            var snoozedState = localState
            snoozedState.pushEventID = eventID
            await activity.update(ActivityContent(state: snoozedState, staleDate: snoozedState.snoozeEndsAt))
            if liveAlarmDeviceID == deviceID { alarmState = snoozedState }
        } else {
            await activity.update(ActivityContent(state: state, staleDate: state.snoozeEndsAt))
            if liveAlarmDeviceID == deviceID { alarmState = state }
        }
        for local in localActivities {
            await local.end(nil, dismissalPolicy: .immediate)
        }
    }

    func handleLiveReading(_ snapshot: SensorReadingsSnapshot, linkedDeviceID: String) {
        guard isApplicationActive, !isEndingActivity, snapshot.deviceID == linkedDeviceID,
              snapshot.connection == .online, !snapshot.isStale,
              let condition = snapshot.assessment.validCondition else { return }

        if snapshot.confirmsNormal {
            recoverLiveAlarm(for: linkedDeviceID, measuredAt: snapshot.measuredAt)
            return
        }
        guard condition == .alarm, liveAlarmDeviceID != linkedDeviceID else { return }
        liveAlarmDeviceID = linkedDeviceID
        liveAlarmAt = snapshot.measuredAt
        synchronizeFromLiveActivity()
        isAlarmPresented = true
    }

    private func recoverLiveAlarm(for deviceID: String, measuredAt: Date?) {
        func measuredAfter(_ alarmDate: Date?) -> Bool {
            guard let alarmDate else { return true }
            return measuredAt.map { $0 > alarmDate } ?? false
        }
        let activities = activeActivities.filter {
            $0.attributes.sensorDeviceID == deviceID && measuredAfter($0.attributes.alarmDate)
        }
        if liveAlarmDeviceID == deviceID, measuredAfter(liveAlarmAt) {
            isAlarmPresented = false
            updateTask?.cancel()
            liveAlarmDeviceID = nil
            liveAlarmAt = nil
            alarmState = .init()
            activityMessage = nil
        }
        guard !activities.isEmpty else { return }
        isEndingActivity = true
        Task {
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            isEndingActivity = false
        }
    }

    func openPushAlarm(_ event: KitchenPushEvent) {
        guard event.assessment.validCondition == .alarm else { return }
        liveAlarmDeviceID = event.deviceID
        liveAlarmAt = Date(timeIntervalSince1970: TimeInterval(event.issuedAt))
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
        if let activity = sessionActivities.first(where: { $0.attributes.remoteEventID != nil }) ??
            sessionActivities.first {
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
        let activities = sessionActivities
        updateTask = Task {
            for activity in activities {
                guard !Task.isCancelled else { return }
                await activity.update(ActivityContent(state: state, staleDate: state.snoozeEndsAt))
            }
        }
    }

    func startLiveActivity(remoteDeviceID: String? = nil) {
        guard !isEndingActivity else { return }
        let shouldRestoreActivity = !shouldKeepLocalStateOnActivityStart
        shouldKeepLocalStateOnActivityStart = false
        guard sessionActivities.isEmpty else {
            if shouldRestoreActivity {
                synchronizeFromLiveActivity()
            } else {
                publishState()
            }
            activityMessage = "Live Activity preview is running."
            return
        }
        if let liveAlarmDeviceID, liveAlarmDeviceID == remoteDeviceID {
            // The server can also end this activity when the app is in the background.
            activityMessage = "Waiting for the alarm Live Activity."
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityMessage = "Live Activities are disabled. Allow them for BeforeFire in Settings, then try again."
            return
        }
        do {
            resumeIfExpired()
            if !alarmState.isSnoozed { alarmState.snoozeDurationSeconds = snoozeDurationSeconds }
            _ = try Activity.request(
                attributes: AlarmActivityAttributes(
                    previewID: UUID(),
                    sensorDeviceID: liveAlarmDeviceID,
                    alarmIssuedAt: liveAlarmAt.map { Int64($0.timeIntervalSince1970) }
                ),
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
