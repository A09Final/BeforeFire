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
                LabeledContent(copy.unitName, value: model.connectedDeviceName ?? copy.notConnected)
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
                DevicesFoundSection(model: model, presentation: presentation)
            }
        }
        .navigationTitle(copy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $model.selectedDevice) { device in
            DeviceWiFiSetupView(device: device, kind: model.kind, connector: model.connector, homeSetup: model.homeSetup,
                                onWiFiJoined: linkSensorToMonitor) {
                model.markConnected(device)
            }
        }
        .onDisappear { model.stopScan() }
    }

    /// `nil` for the alarm and for simulated units, so only a real sensor replaces the Monitor values.
    private var linkSensorToMonitor: ((DiscoveredDevice, DeviceSetupCode) -> Void)? {
        guard model.kind == .sensor, !model.isSimulated else { return nil }
        return { [sensorBackend] device, setupCode in
            sensorBackend.linkSensor(deviceID: device.name, setupCode: setupCode.value)
        }
    }
}

private struct DevicesFoundSection: View {
    let model: DeviceConnectionModel
    let presentation: DeviceConnectionPresentation

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
