import SwiftUI

/// The Wi-Fi and Home setup sheet for one unit. The sensor and the alarm use the same steps.
struct DeviceWiFiSetupView: View {
    @State private var model: DeviceWiFiSetupModel
    @Environment(\.dismiss) private var dismiss
    private let presentation: DeviceConnectionPresentation
    private let onConnected: () -> Void

    init(
        device: DiscoveredDevice,
        kind: ProvisioningDeviceKind,
        connector: any DeviceProvisioningConnecting,
        homeSetup: any DeviceHomeSetupPerforming,
        savedSetupCode: DeviceSetupCode? = nil,
        onWiFiJoined: ((DiscoveredDevice, DeviceSetupCode) -> Void)? = nil,
        onSavedSetupCodeRejected: ((DiscoveredDevice) -> Void)? = nil,
        onConnected: @escaping () -> Void
    ) {
        _model = State(initialValue: DeviceWiFiSetupModel(
            device: device, kind: kind, connector: connector, homeSetup: homeSetup,
            savedSetupCode: savedSetupCode, onWiFiJoined: onWiFiJoined,
            onSavedSetupCodeRejected: onSavedSetupCodeRejected
        ))
        presentation = DeviceConnectionPresentation(kind: kind)
        self.onConnected = onConnected
    }

    private var copy: DeviceConnectionCopy { model.copy }

    var body: some View {
        NavigationStack {
            Group {
                switch model.step {
                case .setupCode:
                    DeviceSetupCodeStep(model: model, presentation: presentation)
                case .networks:
                    DeviceNetworkListStep(model: model, presentation: presentation)
                case .password:
                    DeviceWiFiPasswordStep(model: model, presentation: presentation)
                case .connected(let wiFiName):
                    DeviceHomeSetupStep(model: model, presentation: presentation, wiFiName: wiFiName)
                case .addedToHome:
                    ContentUnavailableView {
                        Label(copy.addedToHomeTitle, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } description: {
                        Text(copy.addedToHomeDescription(deviceName: model.device.name))
                    }
                    .accessibilityIdentifier(presentation.setupIdentifier("addedToHome"))
                }
            }
            .animation(.default, value: model.step)
            .navigationTitle(model.device.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .interactiveDismissDisabled(model.isBusy)
        .task { model.connectWithSavedSetupCode() }
        .onDisappear { model.close() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch model.step {
        case .connected, .addedToHome:
            // The unit has Wi-Fi in both steps, so Done also marks it as connected when the user skips Home.
            ToolbarItem(placement: .confirmationAction) {
                Button(copy.doneButton) {
                    onConnected()
                    dismiss()
                }
                .disabled(model.isBusy)
                .accessibilityIdentifier(presentation.setupIdentifier("doneButton"))
            }
        case .setupCode:
            ToolbarItem(placement: .cancellationAction) {
                cancelButton
            }
        case .networks, .password:
            ToolbarItem(placement: .cancellationAction) {
                Button(copy.backButton) { model.goBack() }
                    .disabled(!model.canGoBack)
                    .accessibilityIdentifier(presentation.setupIdentifier("backButton"))
            }
            ToolbarItem(placement: .confirmationAction) {
                cancelButton
            }
        }
    }

    private var cancelButton: some View {
        Button(copy.cancelButton) {
            model.close()
            dismiss()
        }
        .accessibilityIdentifier(presentation.setupIdentifier("cancelButton"))
    }
}

private struct DeviceSetupCodeStep: View {
    @Bindable var model: DeviceWiFiSetupModel
    let presentation: DeviceConnectionPresentation

    private var copy: DeviceConnectionCopy { model.copy }

    var body: some View {
        if model.isUsingSavedSetupCode {
            savedSetupCodeProgress
        } else {
            setupCodeForm
        }
    }

    /// The unit was set up before, so the app uses the saved code and shows no field.
    private var savedSetupCodeProgress: some View {
        Form {
            Section {
                DeviceSetupProgressRow(text: copy.connectingToDevice, presentation: presentation)
            } footer: {
                Text(copy.usingSavedSetupCode)
            }
        }
        .accessibilityIdentifier(presentation.setupIdentifier("savedSetupCodeProgress"))
    }

    private var setupCodeForm: some View {
        Form {
            Section {
                TextField(copy.setupCodePlaceholder, text: $model.setupCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .onSubmit { model.connect() }
                    .accessibilityIdentifier(presentation.setupIdentifier("setupCodeField"))
            } header: {
                Text(copy.setupCodeHeader)
            } footer: {
                Text(copy.setupCodeFooter)
            }

            Section {
                if model.activity == .connecting {
                    DeviceSetupProgressRow(text: copy.connectingToDevice, presentation: presentation)
                } else {
                    Button(copy.connectToDeviceButton) { model.connect() }
                        .disabled(!model.canConnect)
                        .accessibilityIdentifier(presentation.setupIdentifier("connectButton"))
                }
                DeviceSetupErrorRow(message: model.errorMessage, presentation: presentation)
            }
        }
        .disabled(model.isBusy)
    }
}

private struct DeviceNetworkListStep: View {
    let model: DeviceWiFiSetupModel
    let presentation: DeviceConnectionPresentation

    private var copy: DeviceConnectionCopy { model.copy }

    var body: some View {
        Form {
            Section {
                ForEach(model.networks) { network in
                    Button {
                        model.select(network)
                    } label: {
                        DeviceNetworkRow(network: network)
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel(copy.networkAccessibilityLabel(for: network))
                    .accessibilityIdentifier(presentation.setupIdentifier("network.\(network.ssid)"))
                }

                if model.activity == .scanning {
                    DeviceSetupProgressRow(text: copy.scanningNetworks, presentation: presentation)
                } else if model.networks.isEmpty, model.errorMessage == nil {
                    Text(copy.noNetworksFound)
                        .foregroundStyle(.secondary)
                }
                DeviceSetupErrorRow(message: model.errorMessage, presentation: presentation)

                Button(copy.otherNetworkButton) { model.chooseOtherNetwork() }
                    .accessibilityIdentifier(presentation.setupIdentifier("otherNetworkButton"))
            } header: {
                HStack {
                    Text(copy.networksHeader)
                    Spacer()
                    Button(copy.refreshNetworksButton, systemImage: "arrow.clockwise") {
                        model.refreshNetworks()
                    }
                    .labelStyle(.iconOnly)
                    .disabled(model.isBusy)
                    .accessibilityIdentifier(presentation.setupIdentifier("refreshButton"))
                }
            } footer: {
                Text(copy.networksFooter)
            }
        }
        // The model ignores a selection during a scan. A cancelled scan ends the Bluetooth session.
        .disabled(model.isBusy)
    }
}

private struct DeviceNetworkRow: View {
    let network: DeviceWiFiNetwork

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

private struct DeviceWiFiPasswordStep: View {
    @Bindable var model: DeviceWiFiSetupModel
    let presentation: DeviceConnectionPresentation
    @FocusState private var isPasswordFocused: Bool

    private var copy: DeviceConnectionCopy { model.copy }

    var body: some View {
        Form {
            Section {
                if model.isOtherNetwork {
                    TextField(copy.wiFiNamePlaceholder, text: $model.manualWiFiName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(presentation.setupIdentifier("nameField"))
                }
                if model.showsPasswordField {
                    SecureField(copy.passwordPlaceholder, text: $model.password)
                        .focused($isPasswordFocused)
                        .submitLabel(.join)
                        .onSubmit { model.join() }
                        .accessibilityIdentifier(presentation.setupIdentifier("passwordField"))
                }
            } header: {
                Text(model.selectedNetwork?.ssid ?? copy.otherNetworkHeader)
            } footer: {
                Text(model.showsPasswordField ? copy.passwordFooter : copy.openNetworkFooter)
            }

            Section {
                if model.activity == .joining {
                    DeviceSetupProgressRow(text: copy.joining, presentation: presentation)
                } else {
                    Button(copy.joinButton) { model.join() }
                        .disabled(!model.canJoin)
                        .accessibilityIdentifier(presentation.setupIdentifier("joinButton"))
                }
                DeviceSetupErrorRow(message: model.errorMessage, presentation: presentation)
            }
        }
        .disabled(model.isBusy)
        .onAppear {
            // A selected secured network needs only the password, so the keyboard opens at once.
            isPasswordFocused = model.requiresPassword
        }
    }
}

private struct DeviceHomeSetupStep: View {
    let model: DeviceWiFiSetupModel
    let presentation: DeviceConnectionPresentation
    let wiFiName: String

    private var copy: DeviceConnectionCopy { model.copy }

    var body: some View {
        ContentUnavailableView {
            Label(copy.wiFiConnectedTitle, systemImage: "wifi")
                .accessibilityIdentifier(presentation.setupIdentifier("wiFiConnected"))
        } description: {
            Text(copy.wiFiConnectedDescription(deviceName: model.device.name, wiFiName: wiFiName))
        } actions: {
            if model.activity == .addingToHome {
                DeviceSetupProgressRow(text: copy.addingToHome, presentation: presentation)
            } else {
                Button(copy.addToHomeButton, systemImage: "house.fill") { model.addToHome() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canAddToHome)
                    .accessibilityIdentifier(presentation.setupIdentifier("addToHomeButton"))
            }
            DeviceSetupErrorRow(message: model.errorMessage, presentation: presentation)
        }
    }
}

/// Shared with the sheet that links a sensor that already has Wi-Fi.
struct DeviceSetupProgressRow: View {
    let text: String
    let presentation: DeviceConnectionPresentation

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(presentation.setupIdentifier("progress"))
    }
}

/// Shared with the sheet that links a sensor that already has Wi-Fi.
struct DeviceSetupErrorRow: View {
    let message: String?
    let presentation: DeviceConnectionPresentation

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .accessibilityIdentifier(presentation.setupIdentifier("error"))
        }
    }
}

#Preview("Sensor") {
    DeviceWiFiSetupView(
        device: SimulatedDeviceScanner.sensors[0],
        kind: .sensor,
        connector: SimulatedDeviceConnector(),
        homeSetup: SimulatedDeviceHomeSetup()
    ) {}
}

#Preview("Alarm") {
    DeviceWiFiSetupView(
        device: SimulatedDeviceScanner.alarms[0],
        kind: .alarm,
        connector: SimulatedDeviceConnector(),
        homeSetup: SimulatedDeviceHomeSetup()
    ) {}
}
