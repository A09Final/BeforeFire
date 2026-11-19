import ActivityKit
import Foundation

nonisolated struct AlarmActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isSnoozed = false
        var isHubDisconnected: Bool?
        var pushEventID: String?
        var isHubOffline: Bool { isHubDisconnected ?? false }
        // Optional fields keep existing preview activities decodable after an app update.
        var snoozeEndsAt: Date?
        var snoozeDurationSeconds: Int?

        var durationSeconds: Int {
            min(max(snoozeDurationSeconds ?? AlarmActivityAttributes.defaultSnoozeSeconds,
                    AlarmActivityAttributes.minimumSnoozeSeconds), AlarmActivityAttributes.maximumSnoozeSeconds)
        }

        var snoozeInterval: ClosedRange<Date>? {
            guard isSnoozed, let end = snoozeEndsAt else { return nil }
            return end.addingTimeInterval(-TimeInterval(durationSeconds))...end
        }

        func snoozed(at date: Date) -> Self {
            var result = self
            result.isSnoozed = true
            result.snoozeEndsAt = date.addingTimeInterval(TimeInterval(durationSeconds))
            return result
        }

        func resumed() -> Self {
            var result = self
            result.isSnoozed = false
            result.snoozeEndsAt = nil
            return result
        }

        // The system marks the card stale at its snooze deadline.
        // The Lock Screen can then show Active Alarm without opening the app.
        func displayState(isStale: Bool, at date: Date) -> Self {
            guard isStale, isSnoozed, let snoozeEndsAt, date >= snoozeEndsAt else { return self }
            return resumed()
        }

        var snoozeDeadlineUnixSeconds: Int64 {
            guard isSnoozed, let snoozeEndsAt else { return 0 }
            // Do not ask the server to resume before the countdown reaches zero.
            return Int64(ceil(snoozeEndsAt.timeIntervalSince1970))
        }

        func presentingPushEvent(_ eventID: String) -> Self {
            // A repeated tap must not reset this event's snooze countdown.
            guard pushEventID != eventID else { return self }
            var result = resumed()
            result.pushEventID = eventID
            return result
        }

        func remainingSeconds(at date: Date) -> Int {
            guard isSnoozed, let snoozeEndsAt else { return 0 }
            return min(durationSeconds, max(0, Int(ceil(snoozeEndsAt.timeIntervalSince(date)))))
        }

        func remainingFraction(at date: Date) -> Double {
            guard isSnoozed, let snoozeEndsAt else { return 0 }
            return min(1, max(0, snoozeEndsAt.timeIntervalSince(date) / Double(durationSeconds)))
        }

        func remainingText(at date: Date) -> String {
            let seconds = remainingSeconds(at: date)
            return String(format: "%02d:%02d", seconds / 60, seconds % 60)
        }

        var activityTitle: String {
            if isHubOffline { return AlarmActivityAttributes.hubOfflineLabel }
            return isSnoozed ? KitchenGuidance.snoozedAlarmStatus : KitchenGuidance.alarmActivityInstruction
        }

        var activityMessage: String {
            if isHubOffline { return "Last known status: Alarm." }
            return isSnoozed ? "Check your kitchen now." : KitchenGuidance.alarmActivitySupportingInstruction
        }

        var title: String {
            isSnoozed ? KitchenGuidance.snoozedAlarmStatus : KitchenGuidance.alarmInstruction
        }

        var message: String {
            if isHubOffline {
                return "\(AlarmActivityAttributes.lastKnownAlarmStatus)\n\(AlarmActivityAttributes.liveStatusUnavailableMessage)"
            }
            return isSnoozed ? KitchenGuidance.snoozedInstruction : KitchenGuidance.alarmSupportingInstruction
        }

        var status: String { isHubOffline ? AlarmActivityAttributes.hubOfflineLabel : (isSnoozed ? KitchenGuidance.snoozedAlarmStatus : KitchenGuidance.activeAlarmStatus) }
        var symbol: String { isHubOffline ? "wifi.slash" : (isSnoozed ? "bell.slash.fill" : "light.beacon.max") }
    }

    let previewID: UUID
    var sensorDeviceID: String?
    var remoteEventID: String?
    var alarmIssuedAt: Int64?
    var alarmDate: Date? { alarmIssuedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) } }

    var openURL: URL {
        guard let sensorDeviceID else { return Self.previewURL }
        var url = URLComponents(url: Self.previewURL, resolvingAgainstBaseURL: false)
        url?.queryItems = [
            URLQueryItem(name: "deviceId", value: sensorDeviceID),
            URLQueryItem(name: "activityId", value: previewID.uuidString)
        ]
        return url?.url ?? Self.previewURL
    }
    static let hubOfflineLabel = "Hub offline"
    static let lastKnownAlarmStatus = "Last known status: Alarm active"
    static let liveStatusUnavailableMessage = "Live status unavailable"
    static let defaultSnoozeSeconds = 60
    static let minimumSnoozeSeconds = 5
    static let maximumSnoozeSeconds = 3600
    static let snoozeStepSeconds = 5
    static let snoozeSymbol = "bell.slash.fill"
    static let previewStateDidChange = Notification.Name("BeforeFire.alarmPreviewStateDidChange")
    static let previewURL = URL(string: "beforefire://alarm-preview")!

    static func matchesPreviewURL(_ url: URL) -> Bool {
        url.scheme == previewURL.scheme && url.host == previewURL.host
            && url.path.isEmpty && url.query == nil && url.fragment == nil
    }
}
