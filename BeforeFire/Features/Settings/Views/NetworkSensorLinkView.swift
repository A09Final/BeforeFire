import SwiftUI

/// Links a sensor that already has Wi-Fi. The user enters only the setup code, or nothing when a code is saved.
struct NetworkSensorLinkView: View {
    @State private var model: NetworkSensorLinkModel
    @Environment(\.dismiss) private var dismiss
    private let copy = DeviceConnectionCopy(kind: .sensor)
    private let presentation = DeviceConnectionPresentation(kind: .sensor)

    init(model: NetworkSensorLinkModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isUsingSavedSetupCode {
                    savedSetupCodeProgress
                } else {
                    setupCodeForm
                }
            }
            .navigationTitle(model.sensor.id)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(copy.cancelButton) { dismiss() }
                        .accessibilityIdentifier("networkSensor.cancelButton")
                }
            }
        }
        .task { model.linkWithSavedSetupCode() }
        .onChange(of: model.isLinked) { _, isLinked in
            if isLinked { dismiss() }
        }
        .onDisappear { model.cancel() }
    }

    private var savedSetupCodeProgress: some View {
        Form {
            Section {
                DeviceSetupProgressRow(text: copy.linkingSensor, presentation: presentation)
            } footer: {
                Text(copy.usingSavedSetupCodeToLink)
            }
        }
        .accessibilityIdentifier("networkSensor.savedSetupCodeProgress")
    }

    private var setupCodeForm: some View {
        Form {
            Section {
                SecureField(copy.setupCodePlaceholder, text: $model.setupCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { model.link() }
                    .accessibilityIdentifier("networkSensor.setupCodeField")
            } header: {
                Text(copy.setupCodeHeader)
            } footer: {
                Text(copy.linkSensorFooter)
            }

            Section {
                if model.isLinking {
                    DeviceSetupProgressRow(text: copy.linkingSensor, presentation: presentation)
                } else {
                    Button(copy.linkSensorButton) { model.link() }
                        .disabled(!model.canLink)
                        .accessibilityIdentifier("networkSensor.linkButton")
                }
                DeviceSetupErrorRow(message: model.errorMessage, presentation: presentation)
            }
        }
        .disabled(model.isLinking)
    }
}
