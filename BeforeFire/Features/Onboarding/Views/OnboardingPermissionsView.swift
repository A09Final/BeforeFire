import SwiftUI

struct OnboardingPermissionsView: View {
    var isSimulated = false
    let onContinue: () -> Void
    @State private var notifications = PushNotificationManager.shared
    @State private var isRequesting = false

    var body: some View {
        OnboardingPage(title: OnboardingCopy.permissionsTitle,
                       description: OnboardingCopy.permissionsDescription,
                       footer: OnboardingCopy.permissionsFooter,
                       buttonTitle: OnboardingCopy.continueButton,
                       isBusy: isRequesting || (!isSimulated && notifications.isUpdating),
                       action: { isRequesting = true }) {
            VStack(alignment: .leading, spacing: 24) {
                OnboardingInfoRow(symbol: "antenna.radiowaves.left.and.right", title: "Bluetooth",
                                  description: OnboardingCopy.bluetoothDescription)
                OnboardingInfoRow(symbol: "bell.badge.fill", title: "Notifications",
                                  description: OnboardingCopy.notificationsDescription)
                if let message = notifications.errorMessage, !isSimulated {
                    Text(message).foregroundStyle(.red)
                    Button("Continue Without Notifications", action: onContinue)
                }
            }
        }
        .navigationTitle("Setup")
        .task(id: isRequesting) {
            guard isRequesting else { return }
            // Bluetooth permission stays with the working device scanner.
            if !isSimulated { await notifications.requestPermission() }
            guard !Task.isCancelled else { return }
            isRequesting = false
            if isSimulated || notifications.errorMessage == nil { onContinue() }
        }
    }

}
