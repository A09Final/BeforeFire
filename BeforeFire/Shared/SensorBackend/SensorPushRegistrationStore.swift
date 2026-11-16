import Foundation

struct SensorPushRegistration: Codable, Equatable {
    let deviceID: String
    let backendAddress: String
    let setupCode: String
    let token: String?

    init(link: SensorBackendLink, token: String?) {
        deviceID = link.deviceID
        backendAddress = link.backendAddress
        setupCode = link.setupCode
        self.token = token
    }

    func sensorLink() throws -> SensorBackendLink {
        try SensorBackendLink(backendAddress: backendAddress, deviceID: deviceID, setupCode: setupCode)
    }
}

/// Keeps the old setup code and token until the sensor confirms removal.
struct SensorPushRegistrationStore {
    private let keychain: KeychainPasswordStore
    private static let account = "registrations"

    init(keychainService: String = "BeforeFire.sensorBackend.pushRegistrations") {
        keychain = KeychainPasswordStore(service: keychainService)
    }

    func load() throws -> [SensorPushRegistration] {
        guard let value = try keychain.readValue(account: Self.account) else { return [] }
        return try JSONDecoder().decode([SensorPushRegistration].self, from: Data(value.utf8))
    }

    func save(_ registrations: [SensorPushRegistration]) throws {
        if registrations.isEmpty {
            try keychain.delete(account: Self.account)
        } else {
            let data = try JSONEncoder().encode(registrations)
            try keychain.write(String(decoding: data, as: UTF8.self), account: Self.account)
        }
    }
}
