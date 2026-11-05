import SwiftUI
import UIKit

/// The connection screen for one unit type. The sensor and the alarm use the same screen.
struct DeviceConnectionView: View {
    @State private var model: DeviceConnectionModel
    @Environment(SensorBackendSettingsModel.self) private var sensorBackend

    init(kind: ProvisioningDeviceKind, isSimulated: Bool) {
        _model = State(initialValue: isSimulated ? .simulated(kind: kind) : .live(kind: kind))
    }

    init(model: DeviceConnectionModel) {
        _model = State(initialValue: model)
    }

    private var copy: DeviceConnectionCopy { model.copy }
    private var presentation: DeviceConnectionPresentation { DeviceConnectionPresentation(kind: model.kind) }

    var body: some View {
        Form {
            Section(copy.statusHeader) {
                LabeledContent(copy.unitName, value: connectedDeviceName ?? copy.notConnected)
                    .accessibilityIdentifier(presentation.screenIdentifier("status"))
            }

            Section {
                Button(model.isScanning ? copy.stopSearchButton : copy.connectButton) {
                    if model.isScanning {
                        model.stopScan()
                    } else {
                        model.startScan()
                    }
                }
                .accessibilityIdentifier(presentation.screenIdentifier("connectButton"))
            } footer: {
                Text(model.isSimulated ? copy.simulationFooter : copy.connectFooter)
            }

            if model.scanStatus != .idle {
                DevicesFoundSection(model: model, presentation: presentation,
                                    isSaved: { savedSetupCode(for: $0) != nil })
            }
        }
        .navigationTitle(copy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $model.selectedDevice) { device in
            DeviceWiFiSetupView(device: device, kind: model.kind, connector: model.connector, homeSetup: model.homeSetup,
                                savedSetupCode: savedSetupCode(for: device),
                                onWiFiJoined: handleWiFiJoined,
                                onSavedSetupCodeRejected: handleSavedSetupCodeRejected) {
                model.markConnected(device)
            }
        }
        .onDisappear { model.stopScan() }
    }

    /// A sensor that the user linked on the Sensor Data screen, for example a sensor that already had Wi-Fi,
    /// is also connected.
    private var connectedDeviceName: String? {
        if let name = model.connectedDeviceName { return name }
        guard model.kind == .sensor, !model.isSimulated else { return nil }
        return sensorBackend.link?.deviceID
    }

    /// Only a real sensor uses the Monitor link, so the alarm and simulated units do not change it.
    private var usesSensorLink: Bool {
        model.kind == .sensor && !model.isSimulated
    }

    /// The code from an earlier setup. A sensor that the user linked on the Sensor Data screen also has a saved code.
    private func savedSetupCode(for device: DiscoveredDevice) -> DeviceSetupCode? {
        if let setupCode = model.savedSetupCode(for: device) { return setupCode }
        guard usesSensorLink, let link = sensorBackend.link, link.deviceID == device.name else { return nil }
        return try? DeviceSetupCode(link.setupCode)
    }

    /// Records the unit and its setup code as soon as it joins Wi-Fi, also when the user later closes the sheet
    /// with a swipe.
    private var handleWiFiJoined: (DiscoveredDevice, DeviceSetupCode) -> Void {
        let connectionModel = model
        let sensorBackend = sensorBackend
        let linksSensorToMonitor = usesSensorLink
        return { device, setupCode in
            connectionModel.rememberJoined(device, setupCode: setupCode)
            if linksSensorToMonitor {
                sensorBackend.linkSensor(deviceID: device.name, setupCode: setupCode.value)
            }
        }
    }

    private var handleSavedSetupCodeRejected: (DiscoveredDevice) -> Void {
        let connectionModel = model
        return { device in connectionModel.forgetSetupCode(for: device) }
    }
}

private struct DevicesFoundSection: View {
    let model: DeviceConnectionModel
    let presentation: DeviceConnectionPresentation
    /// `true` for a unit with a saved setup code. Tapping it goes to the Wi-Fi list with no typed code.
    let isSaved: (DiscoveredDevice) -> Bool

    private var copy: DeviceConnectionCopy { model.copy }

    var body: some View {
        Section {
            ForEach(model.discoveredDevices) { device in
                Button {
                    model.select(device)
                } label: {
                    HStack {
                        Label(device.name, systemImage: presentation.unitSymbolName)
                        Spacer()
                        if isSaved(device) {
                            Text(copy.savedDeviceLabel)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier(presentation.screenIdentifier("found.\(device.name)"))
            }

            scanStatusRow
        } header: {
            Text(copy.devicesFoundHeader)
        } footer: {
            if !model.discoveredDevices.isEmpty {
                Text(copy.devicesFoundFooter)
            }
        }
    }

    @ViewBuilder
    private var scanStatusRow: some View {
        switch model.scanStatus {
        case .scanning:
            HStack(spacing: 12) {
                ProgressView()
                Text(copy.searching)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(presentation.screenIdentifier("searching"))
        case .finished where model.discoveredDevices.isEmpty:
            Text(copy.noDevicesFound)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(presentation.screenIdentifier("noneFound"))
        case .failed(let error):
            Label(copy.message(for: error), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityIdentifier(presentation.screenIdentifier("scanError"))
            if error == .bluetoothUnauthorized, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link(copy.openSettingsButton, destination: settingsURL)
            }
        case .idle, .finished:
            EmptyView()
        }
    }
}

#Preview("Simulated sensor") {
    NavigationStack {
        DeviceConnectionView(kind: .sensor, isSimulated: true)
    }
    .environment(SensorBackendSettingsModel.preview())
}

#Preview("Simulated alarm") {
    NavigationStack {
        DeviceConnectionView(kind: .alarm, isSimulated: true)
    }
    .environment(SensorBackendSettingsModel.preview())
}
