import SwiftUI
import UIKit

struct SensorConnectionView: View {
    @State private var model: SensorConnectionModel

    init(isSimulated: Bool) {
        _model = State(initialValue: isSimulated ? .simulated() : .live())
    }

    init(model: SensorConnectionModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Form {
            Section(SensorConnectionCopy.statusHeader) {
                LabeledContent(SensorConnectionCopy.sensorLabel,
                               value: model.connectedSensorName ?? SensorConnectionCopy.notConnected)
                    .accessibilityIdentifier("sensor.status")
            }

            Section {
                Button(model.isScanning ? SensorConnectionCopy.stopSearchButton : SensorConnectionCopy.connectButton) {
                    if model.isScanning {
                        model.stopScan()
                    } else {
                        model.startScan()
                    }
                }
                .accessibilityIdentifier("sensor.connectButton")
            } footer: {
                Text(model.isSimulated ? SensorConnectionCopy.simulationFooter : SensorConnectionCopy.connectFooter)
            }

            if model.scanStatus != .idle {
                SensorsFoundSection(model: model)
            }
        }
        .navigationTitle(SensorConnectionCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $model.selectedSensor) { sensor in
            SensorWiFiSetupView(sensor: sensor, connector: model.connector) {
                model.markConnected(sensor)
            }
        }
        .onDisappear { model.stopScan() }
    }
}

private struct SensorsFoundSection: View {
    let model: SensorConnectionModel

    var body: some View {
        Section {
            ForEach(model.discoveredSensors) { sensor in
                Button {
                    model.select(sensor)
                } label: {
                    HStack {
                        Label(sensor.name, systemImage: "sensor.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("sensor.found.\(sensor.name)")
            }

            scanStatusRow
        } header: {
            Text(SensorConnectionCopy.sensorsFoundHeader)
        } footer: {
            if !model.discoveredSensors.isEmpty {
                Text(SensorConnectionCopy.sensorsFoundFooter)
            }
        }
    }

    @ViewBuilder
    private var scanStatusRow: some View {
        switch model.scanStatus {
        case .scanning:
            HStack(spacing: 12) {
                ProgressView()
                Text(SensorConnectionCopy.searching)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("sensor.searching")
        case .finished where model.discoveredSensors.isEmpty:
            Text(SensorConnectionCopy.noSensorsFound)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("sensor.noneFound")
        case .failed(let error):
            Label(SensorConnectionCopy.message(for: error), systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityIdentifier("sensor.scanError")
            if error == .bluetoothUnauthorized, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link(SensorConnectionCopy.openSettingsButton, destination: settingsURL)
            }
        case .idle, .finished:
            EmptyView()
        }
    }
}

#Preview("Simulated") {
    NavigationStack {
        SensorConnectionView(isSimulated: true)
    }
}
