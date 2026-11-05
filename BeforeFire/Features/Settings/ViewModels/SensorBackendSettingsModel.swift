import Foundation
import Observation

/// The saved link between the app and the sensor on the backend. The Monitor screen reads it, and the settings screen changes it.
@MainActor
@Observable
final class SensorBackendSettingsModel {
    private(set) var link: SensorBackendLink?

    @ObservationIgnored private let store: any SensorBackendLinkStoring

    init(store: any SensorBackendLinkStoring) {
        self.store = store
        link = store.load()
    }

    static func live() -> SensorBackendSettingsModel {
        SensorBackendSettingsModel(store: KeychainSensorBackendLinkStore())
    }

    static func preview(link: SensorBackendLink? = nil) -> SensorBackendSettingsModel {
        SensorBackendSettingsModel(store: InMemorySensorBackendLinkStore(link: link))
    }

    /// An empty setup code keeps the saved code, so the user can change only the address.
    func save(backendAddress: String, deviceID: String, setupCode: String) throws {
        let typedSetupCode = setupCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSerial = deviceID.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let codeToSave: String
        if typedSetupCode.isEmpty, let link, link.deviceID == normalizedSerial {
            codeToSave = link.setupCode
        } else {
            codeToSave = typedSetupCode
        }

        let newLink = try SensorBackendLink(backendAddress: backendAddress, deviceID: deviceID, setupCode: codeToSave)
        do {
            try store.save(newLink)
        } catch {
            throw SensorBackendLinkIssue.storageFailed
        }
        link = newLink
    }

    func remove() throws {
        do {
            try store.remove()
        } catch {
            throw SensorBackendLinkIssue.storageFailed
        }
        link = nil
    }
}
