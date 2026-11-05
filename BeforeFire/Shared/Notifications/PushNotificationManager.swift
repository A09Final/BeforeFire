import Foundation
import Observation
import OSLog
import UserNotifications

@MainActor
@Observable
final class PushNotificationManager {
    static let shared = PushNotificationManager(client: SystemPushNotificationClient(),
                                                bundleIdentifier: Bundle.main.bundleIdentifier ?? "")

    enum RegistrationStatus: Equatable {
        case notRegistered
        case registering
        case registered
        case failed
    }

    let bundleIdentifier: String
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var registrationStatus: RegistrationStatus = .notRegistered
    private(set) var deviceRegistration: PushDeviceRegistration?
    private(set) var isUpdating = false
    private(set) var errorMessage: String?
    private(set) var pendingEvent: KitchenPushEvent?
    private(set) var payloadMessage: String?
    @ObservationIgnored private let client: any PushNotificationClient
    private let logger = Logger(subsystem: "com.ibnu.BeforeFire", category: "PushNotifications")

    init(client: any PushNotificationClient, bundleIdentifier: String) {
        self.client = client
        self.bundleIdentifier = bundleIdentifier
    }

    var canReceiveAlerts: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    var authorizationDescription: String {
        switch authorizationStatus {
        case .notDetermined: "Not requested"
        case .denied: "Not allowed"
        case .authorized: "Allowed"
        case .provisional: "Allowed quietly"
        case .ephemeral: "Allowed temporarily"
        @unknown default: "Unavailable"
        }
    }

    var registrationDescription: String {
        switch registrationStatus {
        case .notRegistered: "Not registered"
        case .registering: "Waiting for APNs"
        case .registered: "Registered with APNs"
        case .failed: "Registration failed"
        }
    }

    // This does not prompt. Existing authorization is checked when the app becomes active.
    func refreshAuthorization() async {
        await updateAuthorization(shouldRequestPermission: false)
    }

    func requestPermission() async {
        await updateAuthorization(shouldRequestPermission: true)
    }

    private func updateAuthorization(shouldRequestPermission: Bool) async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            let currentStatus = await client.authorizationStatus()
            try Task.checkCancellation()
            if shouldRequestPermission && currentStatus == .notDetermined {
                try await client.requestAuthorization()
                try Task.checkCancellation()
                let updatedStatus = await client.authorizationStatus()
                try Task.checkCancellation()
                authorizationStatus = updatedStatus
            } else {
                authorizationStatus = currentStatus
            }
            guard canReceiveAlerts else {
                deviceRegistration = nil
                registrationStatus = .notRegistered
                errorMessage = nil
                return
            }
            if shouldRequestPermission || registrationStatus == .notRegistered || registrationStatus == .failed {
                errorMessage = nil
                registrationStatus = .registering
                client.registerForRemoteNotifications()
            }
        } catch is CancellationError {
            // A closed screen must not start a new registration request.
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Could not request notification permission. Try again."
            logger.error("Notification authorization failed.")
        }
    }

    func didRegister(deviceToken: Data) {
        guard canReceiveAlerts else { return }
        guard let registration = PushDeviceRegistration(deviceToken: deviceToken, bundleIdentifier: bundleIdentifier) else {
            registrationStatus = .failed
            deviceRegistration = nil
            errorMessage = "APNs returned an invalid device registration. Try again."
            return
        }
        deviceRegistration = registration
        registrationStatus = .registered
        errorMessage = nil
        logger.info("APNs registration succeeded. The device token is not logged.")
        // TODO: Send this registration to an authenticated provider after its endpoint,
        // household association, and APNs environment contract are agreed. Do not bundle the .p8 key.
    }

    func didFailToRegister(error: Error) {
        guard canReceiveAlerts else { return }
        registrationStatus = .failed
        deviceRegistration = nil
        errorMessage = "Could not register for push notifications. Check your connection and try again."
        let systemError = error as NSError
        logger.error("APNs registration failed: \(systemError.domain, privacy: .public) \(systemError.code, privacy: .public)")
    }

    func receiveTappedEvent(_ event: KitchenPushEvent) {
        // Keep the last user-selected alarm until the scene is active, including a cold launch.
        pendingEvent = event
        payloadMessage = nil
    }

    func reportPayloadError(_ error: KitchenPushPayloadError) {
        guard error != .unrelatedNotification else { return }
        payloadMessage = error == .differentDevice
            ? "This notification belongs to a different sensor."
            : "This notification has an unsupported condition payload."
        logger.error("An alarm notification payload was rejected.")
    }

    func takePendingEvent() -> KitchenPushEvent? {
        defer { pendingEvent = nil }
        return pendingEvent
    }
}
