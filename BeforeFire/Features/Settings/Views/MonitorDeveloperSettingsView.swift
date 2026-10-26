import SwiftUI

struct MonitorDeveloperSettingsView: View {
    @Binding var isActionGuidanceVisible: Bool
    @Binding var previewCondition: MonitorPreviewCondition

    var body: some View {
        Form {
            Section {
                Toggle("Show action guidance", isOn: $isActionGuidanceVisible)
                    .accessibilityIdentifier("settings.actionGuidanceToggle")

                if isActionGuidanceVisible {
                    Picker("Preview condition", selection: $previewCondition) {
                        ForEach(MonitorPreviewCondition.allCases) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                    .accessibilityIdentifier("settings.previewCondition")
                }
            } header: {
                Text("Developer Settings")
            } footer: {
                Text("Preview the status and action text with mock readings. These settings reset when the app restarts.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
