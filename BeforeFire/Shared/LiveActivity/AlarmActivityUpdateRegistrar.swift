import Foundation
import OSLog
import UIKit

/// Keeps an update token until the backend accepts it. Tokens stay in the app's Keychain.
@MainActor
final class AlarmActivityUpdateRegistrar {
    private struct Pending: Codable {
        let installationID: String
        let eventID: String
        let token: String
        let access: SensorReadingsAccess
    }
    private static let account = "pendingUpdates"
    private let keychain: KeychainPasswordStore
    private let links: any SensorBackendLinkStoring
    private let session: URLSession
    private let logger = Logger(subsystem: "BeforeFire", category: "ActivityUpdateToken")
    private var work: Task<Void, Never>?

    convenience init() {
        self.init(links: KeychainSensorBackendLinkStore())
    }

    init(links: any SensorBackendLinkStoring,
         session: URLSession = .shared, keychainService: String = "BeforeFire.activityUpdateTokens") {
        self.links = links
        self.session = session
        keychain = KeychainPasswordStore(service: keychainService)
    }

    @discardableResult
    func register(_ token: Data, installationID: String, eventID: String, link: SensorBackendLink) -> Task<Void, Never> {
        do {
            var pending = try load()
            pending.removeAll { $0.eventID == eventID && $0.access == link.readingsAccess }
            pending.append(Pending(installationID: installationID, eventID: eventID,
                                   token: token.map { String(format: "%02x", $0) }.joined(), access: link.readingsAccess))
            try save(pending)
        } catch {
            logger.error("Cannot save the pending Live Activity update token.")
        }
        return retryPending()
    }

    @discardableResult
    func retryPending() -> Task<Void, Never> {
        let previous = work
        let next = Task(priority: .high) {
            await previous?.value
            let lease = ActivityTokenBackgroundLease()
            defer { lease.finish() }
            await flush()
        }
        work = next
        return next
    }

    private func flush() async {
        do {
            guard let access = links.load()?.readingsAccess else { try save([]); return }
            let pending = try load().filter { $0.access == access }
            try save(pending)
            for entry in pending {
                guard !Task.isCancelled, links.load()?.readingsAccess == entry.access else { return }
                var request = URLRequest(url: entry.access.url.deletingLastPathComponent().appending(path: "live-activity-token"), timeoutInterval: 8)
                request.httpMethod = "PUT"
                request.setValue("Bearer \(entry.access.readKey)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["installationId": entry.installationID, "eventId": entry.eventID, "updateToken": entry.token])
                var accepted = false
                for attempt in 0..<3 {
                    do {
                        let (_, response) = try await session.data(for: request)
                        if (response as? HTTPURLResponse)?.statusCode == 204 { accepted = true; break }
                        if (response as? HTTPURLResponse)?.statusCode == 401 { break }
                    } catch is CancellationError { return }
                    catch { if Task.isCancelled { return } }
                    if attempt < 2 { try await Task.sleep(for: .seconds(1)) }
                }
                if accepted {
                    var latest = try load()
                    latest.removeAll { $0.eventID == entry.eventID && $0.access == entry.access && $0.token == entry.token }
                    try save(latest)
                    logger.info("Live Activity update token accepted by the backend.")
                } else { logger.error("Live Activity update token remains pending.") }
            }
        } catch is CancellationError { return }
        catch { logger.error("Cannot retry Live Activity update tokens.") }
    }

    private func load() throws -> [Pending] {
        guard let stored = try keychain.readValue(account: Self.account) else { return [] }
        return try JSONDecoder().decode([Pending].self, from: Data(stored.utf8))
    }
    private func save(_ entries: [Pending]) throws {
        if entries.isEmpty { try keychain.delete(account: Self.account) }
        else { try keychain.write(String(decoding: JSONEncoder().encode(entries), as: UTF8.self), account: Self.account) }
    }
}

/// Finishes token delivery during the finite background time that iOS permits.
@MainActor
private final class ActivityTokenBackgroundLease {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    init() {
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Register Live Activity token") { [weak self] in
            Task { @MainActor in self?.finish() }
        }
    }
    func finish() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
