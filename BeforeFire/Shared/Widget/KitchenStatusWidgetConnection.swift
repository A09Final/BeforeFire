import Foundation

/// Shares read access with the widget. The sensor setup code stays in the app's Keychain group.
struct KitchenStatusWidgetConnection {
    static let kind = "BeforeFire.KitchenStatus"
    static let monitorURL = URL(string: "beforefire://monitor")!

    private static let account = "linkedSensor"
    #if DEBUG
    private static let previewAccount = "previewCondition"
    #endif
    private let keychain: KeychainPasswordStore

    init(bundle: Bundle = .main, service: String = "BeforeFire.kitchenStatusWidget") throws {
        guard let accessGroup = bundle.object(forInfoDictionaryKey: "KitchenStatusKeychainGroup") as? String,
              !accessGroup.isEmpty else {
            throw ConnectionError.missingAccessGroup
        }
        keychain = KeychainPasswordStore(service: service, accessGroup: accessGroup)
    }

    func load() throws -> SensorReadingsAccess? {
        guard let storedValue = try keychain.readValue(account: Self.account) else { return nil }
        return try JSONDecoder().decode(SensorReadingsAccess.self, from: Data(storedValue.utf8))
    }

    /// Returns true when the widget must reload its timeline.
    func update(_ access: SensorReadingsAccess?) throws -> Bool {
        if let access {
            let encoded = try JSONEncoder().encode(access)
            guard (try? load()) != access else { return false }
            try keychain.write(String(decoding: encoded, as: UTF8.self), account: Self.account)
        } else {
            if case .success(nil) = Result(catching: load) { return false }
            try keychain.delete(account: Self.account)
        }
        return true
    }

    #if DEBUG
    func loadPreviewCondition() throws -> MonitorPreviewCondition? {
        try keychain.readValue(account: Self.previewAccount).flatMap(MonitorPreviewCondition.init(rawValue:))
    }

    /// Returns true when the widget must reload its timeline.
    func updatePreviewCondition(_ condition: MonitorPreviewCondition?) throws -> Bool {
        let savedValue = try keychain.readValue(account: Self.previewAccount)
        guard savedValue != condition?.rawValue else { return false }
        if let condition {
            try keychain.write(condition.rawValue, account: Self.previewAccount)
        } else {
            try keychain.delete(account: Self.previewAccount)
        }
        return true
    }
    #endif

    private enum ConnectionError: Error {
        case missingAccessGroup
    }
}
