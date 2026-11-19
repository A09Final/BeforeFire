import SwiftUI

/// Adds the sensor and the alarm to the Home app. Wi-Fi setup stays on the Sensor Connection and
/// Alarm Connection screens.
struct HomeConnectionView: View {
    @State private var model: HomeConnectionModel

    init(isSimulated: Bool) {
        _model = State(initialValue: isSimulated ? .simulated() : .live())
    }

    init(model: HomeConnectionModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        Form {
            Section {
            } footer: {
                Text(model.isSimulated ? HomeConnectionCopy.simulationFooter : HomeConnectionCopy.introduction)
            }

            ForEach(HomeConnectionModel.units, id: \.self) { kind in
                HomeConnectionUnitSection(model: model, kind: kind)
            }
        }
        .navigationTitle(HomeConnectionCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HomeConnectionUnitSection: View {
    let model: HomeConnectionModel
    let kind: ProvisioningDeviceKind

    private var copy: DeviceConnectionCopy { DeviceConnectionCopy(kind: kind) }
    private var presentation: DeviceConnectionPresentation { DeviceConnectionPresentation(kind: kind) }
    private var status: HomeConnectionModel.Status { model.status(for: kind) }

    var body: some View {
        Section {
            switch status {
            case .adding:
                HStack(spacing: 12) {
                    ProgressView()
                    Text(copy.addingToHome)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(presentation.homeIdentifier("progress"))
            case .added:
                Label {
                    Text(copy.addedToHomeTitle)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .accessibilityIdentifier(presentation.homeIdentifier("added"))
            case .idle, .failed:
                Button {
                    model.addToHome(kind)
                } label: {
                    Label(copy.addToHomeButton, systemImage: presentation.unitSymbolName)
                }
                .disabled(model.isBusy)
                .accessibilityIdentifier(presentation.homeIdentifier("addButton"))
            }

            if case .failed(let message) = status {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityIdentifier(presentation.homeIdentifier("error"))
            }
        } header: {
            Text(copy.unitName)
        } footer: {
            Text(copy.addToHomeFooter)
        }
    }
}

#Preview("Simulated") {
    NavigationStack {
        HomeConnectionView(isSimulated: true)
    }
}
