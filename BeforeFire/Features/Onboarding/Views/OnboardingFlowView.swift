import SwiftUI

struct OnboardingFlowView: View {
    var isSimulated = false
    let onFinished: () -> Void
    @State private var path: [Destination] = []

    private enum Destination: Hashable {
        case permissions
        case placement
        case device(ProvisioningDeviceKind)
        case complete
    }

    var body: some View {
        NavigationStack(path: $path) {
            welcome
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .permissions:
                        OnboardingPermissionsView(isSimulated: isSimulated) {
                            path.append(.placement)
                        }
                    case .placement:
                        PlacementGuidelineView {
                            path.append(.device(.sensor))
                        }
                    case .device(let kind):
                        DeviceConnectionView(kind: kind, isSimulated: isSimulated, onSetupComplete: {
                            path.append(kind == .sensor ? .device(.alarm) : .complete)
                        })
                    case .complete:
                        completion
                    }
                }
        }
        .tint(.blue)
    }

    private var welcome: some View {
        OnboardingPage(title: OnboardingCopy.welcomeTitle,
                       description: OnboardingCopy.welcomeDescription,
                       footer: OnboardingCopy.nearbyReminder,
                       buttonTitle: "Get Started", buttonIdentifier: "onboarding.getStarted",
                       showsNavigationBar: false, onSkip: onFinished,
                       action: { path.append(.permissions) }) {
            OnboardingRequirementsView()
        }
    }

    private var completion: some View {
        VStack {
            Spacer()
            Image("Illustration-sensor-4")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300, maxHeight: 300)
                .clipShape(.rect(cornerRadius: 18))
                .padding(.bottom, 16)
                .accessibilityHidden(true)
            Text(OnboardingCopy.completionTitle)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("onboarding.complete")
            Spacer()
            OnboardingActionButton(title: OnboardingCopy.monitorButton, action: onFinished)
                .accessibilityIdentifier("onboarding.goToMonitor")
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Setup Complete")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    OnboardingFlowView(isSimulated: true) {}
        .environment(SensorBackendSettingsModel.preview())
}
