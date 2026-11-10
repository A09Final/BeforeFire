import SwiftUI

struct AlarmLiveActivitySettingsSection: View {
    @Environment(AlarmPreviewModel.self) private var alarmPreview
    @State private var endTask: Task<Void, Never>?

    var body: some View {
        Section {
            Button("End Live Activity Preview", role: .destructive) {
                endTask?.cancel()
                endTask = Task { await alarmPreview.endLiveActivities() }
            }
            .disabled(alarmPreview.isEndingActivity)
            .accessibilityIdentifier("settings.endAlarmActivity")

            if let message = alarmPreview.activityMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.alarmActivityMessage")
            }
        } header: {
            Text("Developer Settings · Live Activity")
        } footer: {
            Text("The Live Activity starts when you open Preview Alarm. Snooze stops preview sound and vibration. Feedback plays only while the app is active and the alarm screen is open. No device command is sent. End the Live Activity here when finished.")
        }
        .onDisappear { endTask?.cancel() }
    }
}
