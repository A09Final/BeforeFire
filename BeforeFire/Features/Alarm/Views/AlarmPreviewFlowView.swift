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
        .background(AlarmStyle.snoozedBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
