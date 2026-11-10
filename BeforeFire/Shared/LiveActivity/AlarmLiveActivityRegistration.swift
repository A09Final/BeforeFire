import ActivityKit
import Foundation
import OSLog

/// Sends ActivityKit tokens to the backend for the linked sensor.
@MainActor
final class AlarmLiveActivityRegistration {
    static let shared = AlarmLiveActivityRegistration()
    private static let installationKey = "alarmLiveActivity.installationId"

    private struct Registration: Encodable {
        let installationId: String
        var startToken: String?
        var eventId: String?
        var updateToken: String?
        var remove: Bool?
    }

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
        if let token = Activity<AlarmActivityAttributes>.pushToStartToken {
            uploadStartToken(token)
        }
        guard let link = store.load() else { return }
        for activity in Activity<AlarmActivityAttributes>.activities {
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
        refreshRegistration()
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
