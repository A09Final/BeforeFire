import ActivityKit
import Foundation

nonisolated struct AlarmActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isSnoozed = false

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
    static let previewURL = URL(string: "beforefire://alarm-preview")!

    static func matchesPreviewURL(_ url: URL) -> Bool {
        url.scheme == previewURL.scheme && url.host == previewURL.host
            && url.path.isEmpty && url.query == nil && url.fragment == nil
    }
}
