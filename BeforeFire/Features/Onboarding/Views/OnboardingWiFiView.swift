import SwiftUI

/// Presents the existing provisioning model without the optional Home setup.
struct OnboardingWiFiView: View {
    let model: DeviceWiFiSetupModel
    let kind: ProvisioningDeviceKind
    let onContinue: () -> Void

    private var presentation: DeviceConnectionPresentation { DeviceConnectionPresentation(kind: kind) }

    private var passwordIsPresented: Binding<Bool> {
        Binding(get: { model.step == .password }, set: { isPresented in
            if !isPresented, model.step == .password { model.goBack() }
        })
    }

    var body: some View {
        Group {
            if case .connected(let wiFiName) = model.step {
                connected(wiFiName: wiFiName)
            } else {
                DeviceNetworkListStep(model: model, presentation: presentation,
                                      footer: kind == .alarm
                                      ? "Use the same Wi-Fi as the sensor. The alarm can connect only to 2.4 GHz networks."
                                      : nil)
            }
        }
        .navigationTitle(model.copy.networksHeader)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: passwordIsPresented) {
            NavigationStack {
                DeviceWiFiPasswordStep(model: model, presentation: presentation, automaticallyFocusPassword: false)
                    .navigationTitle(model.selectedNetwork?.ssid ?? model.copy.otherNetworkHeader)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(model.copy.cancelButton) { model.goBack() }
                                .disabled(model.isBusy)
                                .accessibilityIdentifier(presentation.setupIdentifier("cancelPassword"))
                        }
                    }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(model.isBusy)
        }
        .onDisappear {
            // Popping this screen must end its Bluetooth session. Presenting its sheet does not pop it.
            model.close()
            if model.step == .networks { model.goBack() }
        }
    }

    private func connected(wiFiName: String) -> some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wiFiName)
                        Text("\(model.copy.unitName) connected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
                .accessibilityIdentifier(presentation.setupIdentifier("wiFiConnected"))
            }
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingActionButton(title: OnboardingCopy.deviceContinueButton(kind), action: onContinue)
                .disabled(model.isBusy)
                .accessibilityIdentifier(presentation.setupIdentifier("continueButton"))
                .padding(24)
                .background(Color(.systemGroupedBackground))
        }
    }
}
