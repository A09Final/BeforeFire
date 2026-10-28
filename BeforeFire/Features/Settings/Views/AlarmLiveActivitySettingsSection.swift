import SwiftUI

struct AlarmLiveActivitySettingsSection: View {
    @Environment(AlarmPreviewModel.self) private var alarmPreview
    @State private var endTask: Task<Void, Never>?

    var body: some View {
        Section {
            Button("Start Live Activity Preview") {
                alarmPreview.startLiveActivity()
            }
            .disabled(alarmPreview.isEndingActivity)
            .accessibilityIdentifier("settings.startAlarmActivity")

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
            Text("Mock alarm only. Snooze changes the preview state. It does not send a device command or start a timer. End the preview here when finished; it can remain after you close the app.")
        }
        .onDisappear { endTask?.cancel() }
    }
}
