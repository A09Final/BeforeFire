import SwiftUI

struct MonitorDeveloperSettingsView: View {
    @Binding var isActionGuidanceVisible: Bool
    @Binding var previewCondition: MonitorPreviewCondition
    @Environment(AlarmPreviewModel.self) private var alarmPreview
    @State private var showPlacementGuideline = false
    @State private var isDeviceSimulationEnabled = false
    
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
                    DeviceConnectionView(kind: .sensor, isSimulated: isDeviceSimulationEnabled)
                } label: {
                    Label(DeviceConnectionCopy(kind: .sensor).screenTitle, systemImage: "")
                }
                .accessibilityIdentifier("settings.sensorConnection")

                NavigationLink {
                    DeviceConnectionView(kind: .alarm, isSimulated: isDeviceSimulationEnabled)
                } label: {
                    Label(DeviceConnectionCopy(kind: .alarm).screenTitle, systemImage: "")
                }
                .accessibilityIdentifier("settings.alarmConnection")
                
                Button {
                    showPlacementGuideline = true
                } label: {
                    HStack {
                        Label("Placement Guideline", systemImage: "")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("settings.placementGuideline")
                
                NavigationLink {
                    EmergencyContactView()
                } label: {
                    Label("Emergency Contact", systemImage: "")
                }
                .accessibilityIdentifier("settings.emergencyContact")

                NavigationLink {
                    PushNotificationSettingsView(notifications: .shared)
                } label: {
                    Label("Notifications", systemImage: "bell.badge")
                }
                .accessibilityIdentifier("settings.notifications")
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

                Toggle("Hub disconnected", isOn: Binding(
                    get: { alarmPreview.isHubDisconnected },
                    set: { alarmPreview.isHubDisconnected = $0 }
                ))
                .accessibilityIdentifier("settings.hubDisconnectedToggle")

                // The identifier keeps its old name, so the UI tests stay stable. The toggle now also controls the alarm search.
                Toggle("Simulate sensor and alarm", isOn: $isDeviceSimulationEnabled)
                    .accessibilityIdentifier("settings.simulateSensorsToggle")

                // Sensor Connection links the sensor automatically. This screen is a fallback, for example for a
                // sensor that already has Wi-Fi or a network that blocks .local names.
                NavigationLink {
                    SensorBackendSettingsView()
                } label: {
                    Text(SensorBackendSettingsCopy.screenTitle)
                }
                .accessibilityIdentifier("settings.sensorData")

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
                Text("Preview only. Sound and vibration repeat while the alarm screen is open and the app is active. Silence stops both. Resume starts both again. No device command is sent. Duration changes apply to the next snooze and reset to 60 seconds when the app restarts.")
            }

            AlarmLiveActivitySettingsSection()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showPlacementGuideline) {
            PlacementGuidelineView()
        }
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
        .environment(SensorBackendSettingsModel.preview())
        .environment(MonitorLiveReadingsModel.live())
}
