import ActivityKit
import Foundation
import OSLog

/// Sends ActivityKit tokens to the backend for the linked sensor.
@MainActor
final class AlarmLiveActivityRegistration {
    static let shared = AlarmLiveActivityRegistration()
    private static let pendingSnoozeKey = "alarmLiveActivity.pendingSnooze"
    private static let installationKey = "alarmLiveActivity.installationId"

    private struct Registration: Encodable {
        let installationId: String
        var startToken: String?
        var eventId: String?
        var updateToken: String?
        var remove: Bool?
        var pushToken: String?
        var snoozedUntil: Int64?
        var snoozeChangedAt: Int64?
    }

    private struct PendingSnooze: Codable {
        let deviceID: String
        let backendURL: URL
        let eventID: String?
        let deadline: Int64
        let changedAt: Int64
    }

    private var pushUpload: Task<Void, Never>?
    private var snoozeUpload: Task<Void, Never>?
    private let store = KeychainSensorBackendLinkStore()
    private let logger = Logger(subsystem: "BeforeFire", category: "AlarmLiveActivityRegistration")
    private let installationID: String
    private var startObservation: Task<Void, Never>?
    private var activityObservation: Task<Void, Never>?
    private var startUpload: Task<Void, Never>?
    private var registeredLink: SensorBackendLink?

    var registeredDeviceID: String? {
        guard let registeredLink, store.load() == registeredLink,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        return registeredLink.deviceID
    }
    private var activityObservations: [String: Task<Void, Never>] = [:]

    private init() {
        let defaults = UserDefaults.standard
        installationID = defaults.string(forKey: Self.installationKey) ?? UUID().uuidString
        defaults.set(installationID, forKey: Self.installationKey)
    }

    func startObserving() {
        guard startObservation == nil else { return }
        startObservation = Task {
            for await token in Activity<AlarmActivityAttributes>.pushToStartTokenUpdates {
                uploadStartToken(token)
            }
        }
        activityObservation = Task {
            for activity in Activity<AlarmActivityAttributes>.activities {
                observeUpdateToken(for: activity)
            }
            for await activity in Activity<AlarmActivityAttributes>.activityUpdates {
                observeUpdateToken(for: activity)
            }
        }
        refreshRegistration()
    }

    func refreshRegistration() {
        pushUpload?.cancel()
        if let link = store.load(), let token = PushNotificationManager.shared.deviceRegistration?.token {
            pushUpload = Task {
                let accepted = await upload(Registration(installationId: installationID, pushToken: token), to: link)
                if accepted { await uploadPendingSnooze() }
            }
        }
        if let token = Activity<AlarmActivityAttributes>.pushToStartToken {
            uploadStartToken(token)
        }
        guard let link = store.load() else { return }
        for activity in Activity<AlarmActivityAttributes>.activities {
            observeUpdateToken(for: activity)
            guard activity.attributes.sensorDeviceID == link.deviceID,
                  let eventID = activity.attributes.remoteEventID, let token = activity.pushToken else { continue }
            Task { await uploadUpdateToken(token, eventID: eventID, link: link) }
        }
    }

    func linkChanged(from oldLink: SensorBackendLink?, to newLink: SensorBackendLink?) {
        if let oldLink,
           oldLink.deviceID != newLink?.deviceID || oldLink.backendURL != newLink?.backendURL {
            Task { await upload(Registration(installationId: installationID, remove: true), to: oldLink) }
        }
        if oldLink != newLink { UserDefaults.standard.removeObject(forKey: Self.pendingSnoozeKey) }
        refreshRegistration()
    }

    /// The deadline uses Unix seconds. It affects this iPhone only.
    func reminderStateChanged(deviceID: String, state: AlarmActivityAttributes.ContentState) {
        snoozeUpload?.cancel()
        guard let link = store.load(), link.deviceID == deviceID else { return }
        let previous = pendingSnooze?.changedAt ?? 0
        let pending = PendingSnooze(deviceID: deviceID, backendURL: link.backendURL,
                                    eventID: state.pushEventID,
                                    deadline: state.snoozeDeadlineUnixSeconds,
                                    changedAt: max(Int64(Date.now.timeIntervalSince1970 * 1000), previous + 1))
        guard let encoded = try? JSONEncoder().encode(pending) else { return }
        UserDefaults.standard.set(encoded, forKey: Self.pendingSnoozeKey)
        snoozeUpload = Task {
            await pushUpload?.value
            await uploadPendingSnooze()
        }
    }

    // LiveActivityIntent runs in the app process, including from the Lock Screen.
    func syncReminderState(for activity: Activity<AlarmActivityAttributes>,
                           state: AlarmActivityAttributes.ContentState) async {
        guard let deviceID = activity.attributes.sensorDeviceID else { return }
        observeUpdateToken(for: activity)
        reminderStateChanged(deviceID: deviceID, state: state)
        // The snooze request must not wait for the separate token upload.
        await snoozeUpload?.value
        if let eventID = activity.attributes.remoteEventID, let token = activity.pushToken,
           let link = store.load(), link.deviceID == deviceID {
            await uploadUpdateToken(token, eventID: eventID, link: link)
        }
    }

    private var pendingSnooze: PendingSnooze? {
        guard let encoded = UserDefaults.standard.data(forKey: Self.pendingSnoozeKey) else { return nil }
        return try? JSONDecoder().decode(PendingSnooze.self, from: encoded)
    }

    private func uploadPendingSnooze() async {
        guard let pending = pendingSnooze, let link = store.load(), link.deviceID == pending.deviceID,
              link.backendURL == pending.backendURL else { return }
        // Old requests must not affect a later cooking session.
        let requestAge = Date.now.timeIntervalSince1970 - Double(pending.changedAt) / 1000
        guard requestAge < Double(AlarmActivityAttributes.maximumSnoozeSeconds) else {
            UserDefaults.standard.removeObject(forKey: Self.pendingSnoozeKey)
            return
        }
        let accepted = await upload(Registration(installationId: installationID, eventId: pending.eventID,
                                                snoozedUntil: pending.deadline, snoozeChangedAt: pending.changedAt), to: link)
        if accepted, pendingSnooze?.changedAt == pending.changedAt {
            UserDefaults.standard.removeObject(forKey: Self.pendingSnoozeKey)
        }
    }

    private func uploadStartToken(_ token: Data) {
        startUpload?.cancel()
        guard let link = store.load(), ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        startUpload = Task {
            let accepted = await upload(Registration(installationId: installationID, startToken: Self.hex(token)), to: link)
            if accepted, !Task.isCancelled, store.load() == link { registeredLink = link }
        }
    }

    private func observeUpdateToken(for activity: Activity<AlarmActivityAttributes>) {
        guard activityObservations[activity.id] == nil,
              let eventID = activity.attributes.remoteEventID,
              let link = store.load(),
              link.deviceID == activity.attributes.sensorDeviceID else { return }
        activityObservations[activity.id] = Task {
            defer { activityObservations[activity.id] = nil }
            var previousToken: Data?
            if let token = activity.pushToken {
                await uploadUpdateToken(token, eventID: eventID, link: link)
                previousToken = token
            }
            for await token in activity.pushTokenUpdates {
                guard store.load() == link else { return }
                if token != previousToken {
                    await uploadUpdateToken(token, eventID: eventID, link: link)
                    previousToken = token
                }
            }
        }
    }

    private func uploadUpdateToken(_ token: Data, eventID: String, link: SensorBackendLink) async {
        await upload(Registration(installationId: installationID, eventId: eventID, updateToken: Self.hex(token)), to: link)
    }

    @discardableResult
    private func upload(_ registration: Registration, to link: SensorBackendLink) async -> Bool {
        let endpoint = link.backendURL.appending(path: "v1/devices/\(link.deviceID)/live-activity-token")
        var request = URLRequest(url: endpoint, timeoutInterval: SensorBackendConfiguration.requestTimeout)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(link.readKey)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try JSONEncoder().encode(registration)
        } catch {
            logger.error("Could not encode the Live Activity registration.")
            return false
        }
        for attempt in 0..<3 {
            guard !Task.isCancelled, registration.remove == true || store.load() == link else { return false }
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let status = (response as? HTTPURLResponse)?.statusCode {
                    if status == 204 { return true }
                    if status == 400 || status == 401 { break }
                }
            } catch {
                if Task.isCancelled { return false }
            }
            if attempt < 2 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return false }
            }
        }
        logger.error("The server did not accept the Live Activity registration.")
        return false
    }

    private static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }
}
