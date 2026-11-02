import SwiftUI

struct SensorWiFiSetupView: View {
    @State private var model: SensorWiFiSetupModel
    @Environment(\.dismiss) private var dismiss
    private let onConnected: () -> Void

    init(sensor: DiscoveredSensor, connector: any SensorProvisioningConnecting, onConnected: @escaping () -> Void) {
        _model = State(initialValue: SensorWiFiSetupModel(sensor: sensor, connector: connector))
        self.onConnected = onConnected
    }

    var body: some View {
        NavigationStack {
            Group {
                switch model.step {
                case .setupCode:
                    SensorSetupCodeStep(model: model)
                case .networks:
                    SensorNetworkListStep(model: model)
                case .password:
                    SensorWiFiPasswordStep(model: model)
                case .connected(let wiFiName):
                    ContentUnavailableView {
                        Label(SensorConnectionCopy.successTitle, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } description: {
                        Text(SensorConnectionCopy.successDescription(sensorName: model.sensor.name, wiFiName: wiFiName))
                    }
                    .accessibilityIdentifier("sensorWiFi.success")
                }
            }
            .animation(.default, value: model.step)
            .navigationTitle(model.sensor.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .interactiveDismissDisabled(model.isBusy)
        .onDisappear { model.close() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch model.step {
        case .connected:
            ToolbarItem(placement: .confirmationAction) {
                Button(SensorConnectionCopy.doneButton) {
                    onConnected()
                    dismiss()
                }
                .accessibilityIdentifier("sensorWiFi.doneButton")
            }
        case .setupCode:
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }
        case .networks, .password:
            ToolbarItem(placement: .cancellationAction) {
                Button(SensorConnectionCopy.backButton) { model.goBack() }
                    .disabled(!model.canGoBack)
                    .accessibilityIdentifier("sensorWiFi.backButton")
            }
            ToolbarItem(placement: .confirmationAction) {
                cancelButton
            }
        }
    }

    private var cancelButton: some View {
        Button(SensorConnectionCopy.cancelButton) {
            model.close()
            dismiss()
        }
        .accessibilityIdentifier("sensorWiFi.cancelButton")
    }
}

private struct SensorSetupCodeStep: View {
    @Bindable var model: SensorWiFiSetupModel

    var body: some View {
        Form {
            Section {
                TextField(SensorConnectionCopy.setupCodePlaceholder, text: $model.setupCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { model.connect() }
                    .accessibilityIdentifier("sensorWiFi.setupCodeField")
            } header: {
                Text(SensorConnectionCopy.setupCodeHeader)
            } footer: {
                Text(SensorConnectionCopy.setupCodeFooter)
            }

            Section {
                if model.activity == .connecting {
                    SensorSetupProgressRow(text: SensorConnectionCopy.connectingToSensor)
                } else {
                    Button(SensorConnectionCopy.connectToSensorButton) { model.connect() }
                        .disabled(!model.canConnect)
                        .accessibilityIdentifier("sensorWiFi.connectButton")
                }
                SensorSetupErrorRow(message: model.errorMessage)
            }
        }
        .disabled(model.isBusy)
    }
}

private struct SensorNetworkListStep: View {
    let model: SensorWiFiSetupModel

    var body: some View {
        Form {
            Section {
                ForEach(model.networks) { network in
                    Button {
                        model.select(network)
                    } label: {
                        SensorNetworkRow(network: network)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel(SensorConnectionCopy.networkAccessibilityLabel(for: network))
                    .accessibilityIdentifier("sensorWiFi.network.\(network.ssid)")
                }

                if model.activity == .scanning {
                    SensorSetupProgressRow(text: SensorConnectionCopy.scanningNetworks)
                } else if model.networks.isEmpty, model.errorMessage == nil {
                    Text(SensorConnectionCopy.noNetworksFound)
                        .foregroundStyle(.secondary)
                }
                SensorSetupErrorRow(message: model.errorMessage)

                Button(SensorConnectionCopy.otherNetworkButton) { model.chooseOtherNetwork() }
                    .accessibilityIdentifier("sensorWiFi.otherNetworkButton")
            } header: {
                HStack {
                    Text(SensorConnectionCopy.networksHeader)
                    Spacer()
                    Button(SensorConnectionCopy.refreshNetworksButton, systemImage: "arrow.clockwise") {
                        model.refreshNetworks()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(model.isBusy)
                    .accessibilityIdentifier("sensorWiFi.refreshButton")
                }
            } footer: {
                Text(SensorConnectionCopy.networksFooter)
            }
        }
        .disabled(model.isBusy && model.activity != .scanning)
    }
}

private struct SensorNetworkRow: View {
    let network: SensorWiFiNetwork

    var body: some View {
        HStack {
            Text(network.ssid)
            Spacer()
            if network.isSecured {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "wifi", variableValue: network.signalLevel)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SensorWiFiPasswordStep: View {
    @Bindable var model: SensorWiFiSetupModel
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        Form {
            Section {
                if model.isOtherNetwork {
                    TextField(SensorConnectionCopy.wiFiNamePlaceholder, text: $model.manualWiFiName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("sensorWiFi.nameField")
                }
                if model.showsPasswordField {
                    SecureField(SensorConnectionCopy.passwordPlaceholder, text: $model.password)
                        .focused($isPasswordFocused)
                        .submitLabel(.join)
                        .onSubmit { model.join() }
                        .accessibilityIdentifier("sensorWiFi.passwordField")
                }
            } header: {
                Text(model.selectedNetwork?.ssid ?? SensorConnectionCopy.otherNetworkHeader)
            } footer: {
                Text(model.showsPasswordField ? SensorConnectionCopy.passwordFooter : SensorConnectionCopy.openNetworkFooter)
            }

            Section {
                if model.activity == .joining {
                    SensorSetupProgressRow(text: SensorConnectionCopy.joining)
                } else {
                    Button(SensorConnectionCopy.joinButton) { model.join() }
                        .disabled(!model.canJoin)
                        .accessibilityIdentifier("sensorWiFi.joinButton")
                }
                SensorSetupErrorRow(message: model.errorMessage)
            }
        }
        .disabled(model.isBusy)
        .onAppear {
            // A selected secured network needs only the password, so the keyboard opens at once.
            isPasswordFocused = model.requiresPassword
        }
    }
}

private struct SensorSetupProgressRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sensorWiFi.progress")
    }
}

private struct SensorSetupErrorRow: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityIdentifier("sensorWiFi.error")
        }
    }
}

#Preview {
    SensorWiFiSetupView(sensor: SimulatedSensorScanner.sensors[0], connector: SimulatedSensorConnector()) {}
}
