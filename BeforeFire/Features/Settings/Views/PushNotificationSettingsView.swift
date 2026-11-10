import SwiftUI
import UIKit
import UserNotifications

struct PushNotificationSettingsView: View {
    let notifications: PushNotificationManager
    @Environment(\.openURL) private var openURL
    @State private var permissionTask: Task<Void, Never>?
    @State private var hasCopiedToken = false
    private static let clipboardLifetime: TimeInterval = 300

    var body: some View {
        Form {
            Section {
                LabeledContent("Permission", value: notifications.authorizationDescription)
                LabeledContent("Push registration", value: notifications.registrationDescription)

                if notifications.authorizationStatus == .notDetermined || notifications.canReceiveAlerts {
                    Button(notifications.canReceiveAlerts ? "Retry Registration" : "Enable Notifications") {
                        permissionTask?.cancel()
                        permissionTask = Task { await notifications.requestPermission() }
                    }
                    .disabled(notifications.isUpdating)
                    .accessibilityIdentifier("notifications.enable")
                }

                Button("Open Notification Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }

                if notifications.isUpdating {
                    ProgressView("Checking notification permission")
                }
                if let message = notifications.errorMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("notifications.error")
                }
            } footer: {
                Text("Allow notifications to receive alerts on this iPhone. Sound and banner settings are controlled in iOS Settings.")
            }

            #if DEBUG
            Section("APNs Testing") {
                LabeledContent("Bundle ID", value: notifications.bundleIdentifier)
                Button(hasCopiedToken ? "Token Copied" : "Copy Device Token") {
                    guard let registration = notifications.deviceRegistration else { return }
                    UIPasteboard.general.setItems([["public.utf8-plain-text": registration.token]], options: [
                        .expirationDate: Date.now.addingTimeInterval(Self.clipboardLifetime)
                    ])
                    hasCopiedToken = true
                }
                .disabled(notifications.deviceRegistration == nil)
                .accessibilityIdentifier("notifications.copyToken")

                Text("Use the displayed Bundle ID and the APNs environment from the signing profile. The app sends the token to the linked sensor through the server.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let message = notifications.payloadMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            #endif
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notifications.refreshAuthorization() }
        .onChange(of: notifications.deviceRegistration) { _, _ in hasCopiedToken = false }
        .onDisappear { permissionTask?.cancel() }
    }
}
