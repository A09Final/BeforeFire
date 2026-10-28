import SwiftUI

struct MonitorDeveloperSettingsView: View {
    @Binding var isActionGuidanceVisible: Bool
    @Binding var previewCondition: MonitorPreviewCondition
    @Environment(AlarmPreviewModel.self) private var alarmPreview
    
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    HubConnectionView()
                } label: {
                    Label("Hub Connection", systemImage: "")
                    //If systemImage is deleted, it breaks
                    //PLS DONT DELETE
                }
                .accessibilityIdentifier("settings.hubConnection")
                
                NavigationLink {
                    PlacementGuidelineView()
                } label: {
                    Label("Placement Guideline", systemImage: "")
                }
                .accessibilityIdentifier("settings.placementGuideline")
                
                NavigationLink {
                    EmergencyContactView()
                } label: {
                    Label("Emergency Contact", systemImage: "")
                }
                .accessibilityIdentifier("settings.emergencyContact")
            } header: {
                Text("General")
            }
            
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

                Button("Preview Alarm") {
                    alarmPreview.resumeIfExpired()
                    alarmPreview.isAlarmPresented = true
                }
                .disabled(alarmPreview.isEndingActivity)
                .accessibilityIdentifier("settings.previewAlarm")

                Stepper(value: Binding(
                    get: { alarmPreview.snoozeDurationSeconds },
                    set: { alarmPreview.updateSnoozeDuration($0) }
                ), in: AlarmActivityAttributes.minimumSnoozeSeconds...AlarmActivityAttributes.maximumSnoozeSeconds,
                        step: AlarmActivityAttributes.snoozeStepSeconds) {
                    LabeledContent("Snooze duration", value: "\(alarmPreview.snoozeDurationSeconds) seconds")
                }
                .accessibilityIdentifier("settings.snoozeDuration")
            } header: {
                Text("Developer Settings")
            } footer: {
                Text("Mock alarm only, with no sound or device connection. Slide to start the snooze countdown. Duration changes apply to the next snooze and reset to 60 seconds when the app restarts.")
            }

            AlarmLiveActivitySettingsSection()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
    
}

// MARK: - Placeholder destination screens

struct HubConnectionView: View {
    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Hub", value: "Not connected")
            }
            Section {
                Button("Connect to Hub") {
                    // TODO: start pairing / connection flow
                }
                .accessibilityIdentifier("hub.connectButton")
            }
        }
        .navigationTitle("Hub Connection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PlacementGuidelineView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Where to place the monitor")
                    .font(.headline)
                Text("Add your placement instructions here.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
        }
    }
}

struct EmergencyContactView: View {
    @State private var name = ""
    @State private var phone = ""
    
    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Phone number", text: $phone)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.phonePad)
            } footer: {
                Text("This person will be contacted in an emergency.")
            }
        }
        .navigationTitle("Emergency Contact")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    @Previewable @State var isTrue = false
    @Previewable @State var mock = MonitorPreviewCondition.dangerous
    MonitorDeveloperSettingsView(isActionGuidanceVisible: $isTrue, previewCondition: $mock)
        .environment(AlarmPreviewModel())
}
