import SwiftUI

/// Links the sensor to the BeforeFire server, so the Monitor screen can show the live sensor values.
struct SensorBackendSettingsView: View {
    @Environment(SensorBackendSettingsModel.self) private var sensorBackend
    @Environment(MonitorLiveReadingsModel.self) private var liveReadings

    @State private var backendAddress = ""
    @State private var serial = ""
    @State private var setupCode = ""
    @State private var formMessage: String?
    @State private var isFormMessageError = false

    var body: some View {
        Form {
            Section {
                TextField(SensorBackendSettingsCopy.backendAddressLabel, text: $backendAddress,
                          prompt: Text(SensorBackendSettingsCopy.backendAddressPlaceholder))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sensorBackend.addressField")
            } header: {
                Text(SensorBackendSettingsCopy.serverHeader)
            } footer: {
                Text(SensorBackendSettingsCopy.serverFooter)
            }

            Section {
                TextField(SensorBackendSettingsCopy.serialLabel, text: $serial,
                          prompt: Text(SensorBackendSettingsCopy.serialPlaceholder))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sensorBackend.serialField")
                SecureField(SensorBackendSettingsCopy.setupCodeLabel, text: $setupCode,
                            prompt: Text(setupCodePlaceholder))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("sensorBackend.setupCodeField")
            } header: {
                Text(SensorBackendSettingsCopy.sensorHeader)
            } footer: {
                Text(SensorBackendSettingsCopy.sensorFooter)
            }

            Section {
                Button(SensorBackendSettingsCopy.saveButton, action: save)
                    .accessibilityIdentifier("sensorBackend.saveButton")
                if sensorBackend.link != nil {
                    Button(SensorBackendSettingsCopy.removeButton, role: .destructive, action: remove)
                        .accessibilityIdentifier("sensorBackend.removeButton")
                }
            } footer: {
                if let formMessage {
                    Text(formMessage)
                        .foregroundStyle(isFormMessageError ? Color.red : Color.secondary)
                        .accessibilityIdentifier("sensorBackend.formMessage")
                }
            }

            SensorBackendStatusSection(status: liveReadings.status, lastUpdatedAt: liveReadings.lastUpdatedAt)
        }
        .navigationTitle(SensorBackendSettingsCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: fillSavedValues)
    }

    private var setupCodePlaceholder: String {
        sensorBackend.link == nil
            ? SensorBackendSettingsCopy.setupCodePlaceholder
            : SensorBackendSettingsCopy.savedSetupCodePlaceholder
    }

    private func fillSavedValues() {
        guard let link = sensorBackend.link else { return }
        backendAddress = link.backendAddress
        serial = link.deviceID
    }

    private func save() {
        do {
            try sensorBackend.save(backendAddress: backendAddress, deviceID: serial, setupCode: setupCode)
            setupCode = ""
            fillSavedValues()
            show(SensorBackendSettingsCopy.savedMessage, isError: false)
        } catch let issue as SensorBackendLinkIssue {
            show(SensorBackendSettingsCopy.message(for: issue), isError: true)
        } catch {
            show(SensorBackendSettingsCopy.message(for: .storageFailed), isError: true)
        }
    }

    private func remove() {
        do {
            try sensorBackend.remove()
            backendAddress = ""
            serial = ""
            setupCode = ""
            formMessage = nil
        } catch {
            show(SensorBackendSettingsCopy.message(for: .storageFailed), isError: true)
        }
    }

    private func show(_ message: String, isError: Bool) {
        formMessage = message
        isFormMessageError = isError
    }
}

/// Shows whether the app receives values from the server.
private struct SensorBackendStatusSection: View {
    let status: MonitorLiveReadingsModel.Status
    let lastUpdatedAt: Date?

    var body: some View {
        Section {
            LabeledContent(SensorBackendSettingsCopy.readingsLabel) {
                Text(statusValue)
                    .multilineTextAlignment(.trailing)
            }
            .accessibilityIdentifier("sensorBackend.status")

            if let lastUpdatedAt {
                LabeledContent(SensorBackendSettingsCopy.lastUpdateLabel) {
                    Text(lastUpdatedAt, style: .relative)
                }
            }
        } header: {
            Text(SensorBackendSettingsCopy.statusHeader)
        } footer: {
            if status != .notConfigured {
                Text(SensorBackendSettingsCopy.monitorPausedNote)
            }
        }
    }

    private var statusValue: String {
        switch status {
        case .notConfigured:
            SensorBackendSettingsCopy.notLinked
        case .loading:
            SensorBackendSettingsCopy.loading
        case .failed(let error):
            SensorBackendSettingsCopy.message(for: error)
        case .updated(let snapshot):
            snapshot.isStale || snapshot.connection == .offline
                ? SensorBackendSettingsCopy.sensorOffline
                : SensorBackendSettingsCopy.receiving
        }
    }
}

#Preview {
    NavigationStack { SensorBackendSettingsView() }
        .environment(SensorBackendSettingsModel.preview())
        .environment(MonitorLiveReadingsModel.live())
}
