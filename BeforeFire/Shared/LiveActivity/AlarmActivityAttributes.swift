import ActivityKit
import Foundation

nonisolated struct AlarmActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isSnoozed = false
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

        var title: String {
            isSnoozed ? "Alarm snoozed" : "Check your kitchen now"
        }

        var message: String {
            isSnoozed ? "Preview only. No alarm command was sent." : "Check the stove and surrounding area."
        }

        var status: String { isSnoozed ? "Snoozed" : "Alarm active" }
        var symbol: String { isSnoozed ? "bell.slash.fill" : "light.beacon.max" }
    }

    let previewID: UUID
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
