import SwiftUI

struct KitchenNotificationDetailsView: View {
    let event: KitchenPushEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Reported sensor condition") {
                    Text(event.assessment.validCondition?.displayName ?? KitchenGuidance.unknownStatus)
                        .font(.title.bold())
                    if let message = KitchenGuidance.notificationBody(for: event.assessment) {
                        Text(message)
                    } else if event.assessment.validCondition == nil {
                        Text("The sensor status could not be confirmed.")
                    }
                }
            }
            .navigationTitle("Notification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
