import SwiftUI

struct AlarmPreviewFlowView: View {
    @Environment(AlarmPreviewModel.self) private var alarmPreview

    var body: some View {
        Group {
            if alarmPreview.alarmState.isSnoozed {
                SnoozedAlarmView(state: alarmPreview.alarmState) {
                    alarmPreview.resumeAlarm()
                }
            } else {
                AlarmView { alarmPreview.snooze() }
            }
        }
        .background(AlarmStyle.snoozedBackground.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
