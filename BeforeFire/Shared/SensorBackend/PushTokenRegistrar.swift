import Foundation
import os

/// Updates the APNs device tokens that sensors use to send notifications to this iPhone.
@MainActor
final class PushTokenRegistrar {
    static let shared = PushTokenRegistrar()

    private let store: any SensorBackendLinkStoring
    private let registrations: SensorPushRegistrationStore
    private let client: any SensorCommandSending
    private let logger = Logger(subsystem: "BeforeFire", category: "PushToken")
    private var token: String?
    private var work: Task<Void, Never>?
    private static let retryInterval: Duration = .seconds(30)

    init(store: any SensorBackendLinkStoring = KeychainSensorBackendLinkStore(),
         registrations: SensorPushRegistrationStore = SensorPushRegistrationStore(),
         client: any SensorCommandSending = URLSessionSensorCommandClient()) {
        self.store = store
        self.registrations = registrations
        self.client = client
    }

    @discardableResult
    func updateToken(_ token: String) -> Task<Void, Never> {
        self.token = token
        return register()
    }

    @discardableResult
    func register() -> Task<Void, Never> {
        schedule(registerCurrentToken: true)
    }

    @discardableResult
    func retryRevocations() -> Task<Void, Never> {
        schedule(registerCurrentToken: false)
    }

    func retryRevocationsWhileActive() async {
        while !Task.isCancelled {
            await retryRevocations().value
            do {
                try await Task.sleep(for: Self.retryInterval)
            } catch {
                return
            }
        }
    }

    /// Save the current connection details before Settings removes them.
    func prepareToUnlink(_ link: SensorBackendLink) throws {
        let saved = try registrations.load()
        let tokens = saved.filter { $0.deviceID == link.deviceID }.map(\.token)
        let remaining = saved.filter { $0.deviceID != link.deviceID }
        // Older installs can have a registered token before there is a Keychain record.
        let entries = (tokens.isEmpty ? [token] : tokens).map {
            SensorPushRegistration(link: link, token: $0)
        }
        try registrations.save(remaining + entries)
    }

    private func schedule(registerCurrentToken: Bool) -> Task<Void, Never> {
        // Keep a relink registration after any removal already sent to that sensor.
        let previousWork = work
        let nextWork = Task {
            await previousWork?.value
            if registerCurrentToken { await registerCurrent() }
            await revokeUnlinked()
        }
        work = nextWork
        return nextWork
    }

    private func registerCurrent() async {
        guard let token, let link = store.load() else { return }
        do {
            var saved = try registrations.load()
            saved.removeAll { $0.deviceID == link.deviceID && ($0.token == token || $0.token == nil) }
            saved.append(SensorPushRegistration(link: link, token: token))
            // The sensor can keep the token even if its reply does not reach the app.
            try registrations.save(saved)
            try await send(.registerPushToken, token: token, to: link)
        } catch {
            logger.error("Could not register the push token.")
        }
    }

    private func revokeUnlinked() async {
        let saved: [SensorPushRegistration]
        do {
            saved = try registrations.load()
        } catch {
            logger.error("Could not read push token registrations.")
            return
        }

        for registration in saved {
            guard store.load()?.deviceID != registration.deviceID,
                  let token = registration.token ?? token else { continue }
            do {
                let link = try registration.sensorLink()
                let resolved = SensorPushRegistration(link: link, token: token)
                if registration != resolved {
                    try replace(registration, with: resolved)
                }
                try await send(.unregisterPushToken, token: token, to: link)
                try replace(resolved, with: nil)
            } catch {
                logger.error("Push token removal is pending.")
            }
        }
    }

    private func replace(_ registration: SensorPushRegistration, with replacement: SensorPushRegistration?) throws {
        var saved = try registrations.load()
        saved.removeAll { $0 == registration }
        if let replacement { saved.append(replacement) }
        try registrations.save(saved)
    }

    private func send(_ action: SensorCommand.Action, token: String, to link: SensorBackendLink) async throws {
        let command = SensorCommand(action: action, pushToken: token, link: link)
        let ack = try await client.send(command, for: link)
        guard ack.requestId == command.requestId, ack.result == "done" else {
            throw SensorCommandError.unexpectedResponse
        }
    }
}
