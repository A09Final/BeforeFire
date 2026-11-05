import Foundation
import Observation
import os

/// The saved link between the app and the sensor on the backend. The Monitor screen reads it, and the settings screen changes it.
@MainActor
@Observable
final class SensorBackendSettingsModel {
    private(set) var link: SensorBackendLink?

    @ObservationIgnored private let store: any SensorBackendLinkStoring
    @ObservationIgnored private let logger = Logger(subsystem: "BeforeFire", category: "SensorBackend")

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

    /// Links a sensor after its Wi-Fi setup, so the Monitor screen shows its values with no typed values.
    /// It keeps the saved server address, or it uses the default server.
    /// A failure does not stop the Wi-Fi setup. The user can link the sensor on the Sensor Data screen.
    func linkSensor(deviceID: String, setupCode: String) {
        do {
            try save(backendAddress: link?.backendAddress ?? "", deviceID: deviceID, setupCode: setupCode)
        } catch {
            logger.error("Automatic sensor link failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// An empty server address uses the default server.
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

        let typedAddress = backendAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let addressToSave = typedAddress.isEmpty ? SensorBackendConfiguration.defaultBackendAddress : typedAddress

        let newLink = try SensorBackendLink(backendAddress: addressToSave, deviceID: deviceID, setupCode: codeToSave)
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
