import SwiftUI

struct AlarmPreviewFlowView: View {
    @Environment(AlarmPreviewModel.self) private var alarmPreview

    var body: some View {
        Group {
            if alarmPreview.alarmState.isSnoozed {
                SnoozedAlarmView(state: alarmPreview.alarmState, guidance: alarmPreview.guidance) {
                    alarmPreview.resumeAlarm()
                }
            } else {
                AlarmView(isHubDisconnected: alarmPreview.isHubDisconnected, guidance: alarmPreview.guidance) {
                    alarmPreview.snooze()
                }
            }
        }
        .safeAreaInset(edge: .top) {
            if let message = alarmPreview.feedbackMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AlarmStyle.foreground)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AlarmStyle.snoozedBackground)
                    .accessibilityIdentifier("alarm.feedbackMessage")
            }
        }
        .background(AlarmStyle.snoozedBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
