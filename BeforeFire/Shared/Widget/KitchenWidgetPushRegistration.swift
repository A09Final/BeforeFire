import Foundation
import OSLog

/// Saves the widget token and pending removals in the shared Keychain group.
@MainActor
final class KitchenWidgetPushRegistration {
    static let shared = KitchenWidgetPushRegistration()
    private static let account = "widgetPushRegistration"
    private static let logger = Logger(subsystem: "BeforeFire", category: "WidgetPush")

    struct Record: Codable {
        var installationID = UUID().uuidString
        var token: String?
        var isInstalled = false
        var registeredAccess: SensorReadingsAccess?
        var registeredToken: String?
        var pendingRemovals: [SensorReadingsAccess] = []
    }

    private let connection: KitchenStatusWidgetConnection?
    private let store: KeychainPasswordStore?
    private let session: URLSession
    private var work: Task<Void, Never>?

    init(bundle: Bundle = .main, service: String = "BeforeFire.widgetPush", connection: KitchenStatusWidgetConnection? = nil, session: URLSession = .shared) {
        self.session = session
        self.connection = connection ?? (try? KitchenStatusWidgetConnection(bundle: bundle))
        if let group = bundle.object(forInfoDictionaryKey: "KitchenStatusKeychainGroup") as? String, !group.isEmpty {
            store = KeychainPasswordStore(service: service, accessGroup: group)
        } else { store = nil }
    }

    func didChangeToken(_ token: Data, isInstalled: Bool) {
        do {
            var record = try load()
            record.token = token.map { String(format: "%02x", $0) }.joined()
            record.isInstalled = isInstalled
            record.registeredToken = nil
            try save(record)
            refresh()
        } catch { Self.logger.error("Cannot save the widget push token.") }
    }

    /// Retries failed uploads after a link change, app launch, or widget refresh.
    @discardableResult
    func refresh(force: Bool = false) -> Task<Void, Never> {
        let previous = work
        let next = Task {
            await previous?.value
            await synchronize(force: force)
        }
        work = next
        return next
    }

    private func synchronize(force: Bool) async {
        do {
            guard let connection else { throw RegistrationError.unavailable }
            var record = try load()
            let desired = record.isInstalled ? try connection.load() : nil
            if let old = record.registeredAccess, old != desired {
                if !record.pendingRemovals.contains(old) { record.pendingRemovals.append(old) }
                record.registeredAccess = nil
                record.registeredToken = nil
                try save(record)
            }
            for old in record.pendingRemovals {
                guard await send(to: old, installationID: record.installationID, token: nil) else { continue }
                var latest = try load()
                latest.pendingRemovals.removeAll { $0 == old }
                if latest.registeredAccess == old {
                    latest.registeredAccess = nil
                    latest.registeredToken = nil
                }
                try save(latest)
            }
            record = try load()
            guard let desired, let token = record.token, record.isInstalled,
                  try connection.load() == desired,
                  !record.pendingRemovals.contains(desired),
                  force || record.registeredAccess != desired || record.registeredToken != token else { return }
            // The server can store the token even when its response does not reach this process.
            record.registeredAccess = desired
            record.registeredToken = nil
            try save(record)
            if await send(to: desired, installationID: record.installationID, token: token) {
                var latest = try load()
                latest.registeredAccess = desired
                latest.registeredToken = token
                try save(latest)
            }
        } catch { Self.logger.error("Cannot update the widget push registration.") }
    }

    private func send(to access: SensorReadingsAccess, installationID: String, token: String?) async -> Bool {
        do {
            var request = try Self.request(access: access, installationID: installationID, token: token)
            request.timeoutInterval = 10
            for attempt in 0..<3 {
                do {
                    let (_, response) = try await session.data(for: request)
                    if let response = response as? HTTPURLResponse {
                        if response.statusCode == 204 { return true }
                        if response.statusCode == 400 || response.statusCode == 401 { break }
                    }
                } catch is CancellationError { return false }
                catch { if Task.isCancelled { return false } }
                if attempt < 2 { try await Task.sleep(for: .seconds(1)) }
            }
        } catch is CancellationError { return false }
        catch { Self.logger.error("Cannot create the widget token request.") }
        Self.logger.error("The server did not accept the widget push registration.")
        return false
    }

    nonisolated static func request(access: SensorReadingsAccess, installationID: String, token: String?) throws -> URLRequest {
        let endpoint = access.url.deletingLastPathComponent().appending(path: "widget-token")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(access.readKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["installationId": installationID]
        if let token { body["pushToken"] = token } else { body["remove"] = true }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func load() throws -> Record {
        guard let store else { throw RegistrationError.unavailable }
        guard let value = try store.readValue(account: Self.account) else { return Record() }
        return try JSONDecoder().decode(Record.self, from: Data(value.utf8))
    }

    private func save(_ record: Record) throws {
        guard let store else { throw RegistrationError.unavailable }
        try store.write(String(decoding: JSONEncoder().encode(record), as: UTF8.self), account: Self.account)
    }

    private enum RegistrationError: Error { case unavailable }
}
